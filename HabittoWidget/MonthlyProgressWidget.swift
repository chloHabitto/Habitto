//
//  MonthlyProgressWidget.swift
//  HabittoWidget
//
//  Created by Chloe Lee on 2026-01-11.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Habit Selection Intent
@available(iOS 17.0, *)
struct SelectHabitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Habit"
    static var description = IntentDescription("Choose a habit to display monthly progress")
    
    @Parameter(title: "Habit")
    var habit: HabitSelectionEntity?
    
    init() {}
    
    init(habit: HabitSelectionEntity?) {
        self.habit = habit
    }
}

// MARK: - Habit Selection Entity
@available(iOS 17.0, *)
struct HabitSelectionEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitQuery()
    
    var id: UUID
    var displayRepresentation: DisplayRepresentation
    
    init(id: UUID, name: String) {
        self.id = id
        self.displayRepresentation = DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Habit Query
@available(iOS 17.0, *)
struct HabitQuery: EntityQuery {
    func entities(for identifiers: [HabitSelectionEntity.ID]) async throws -> [HabitSelectionEntity] {
        let habits = loadHabitsFromWidgetStorage()
        return habits
            .filter { identifiers.contains($0.id) }
            .map { HabitSelectionEntity(id: $0.id, name: $0.name) }
    }
    
    func entities(matching string: String) async throws -> [HabitSelectionEntity] {
        let habits = loadHabitsFromWidgetStorage()
        return habits
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map { HabitSelectionEntity(id: $0.id, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [HabitSelectionEntity] {
        let habits = loadHabitsFromWidgetStorage()
        return habits.map { HabitSelectionEntity(id: $0.id, name: $0.name) }
    }
    
    private func loadHabitsFromWidgetStorage() -> [HabitWidgetData] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
              let data = sharedDefaults.data(forKey: "widgetHabits"),
              let habits = try? JSONDecoder().decode([HabitWidgetData].self, from: data) else {
            return []
        }
        return habits
    }
}

// MARK: - Monthly Progress Provider
@available(iOS 17.0, *)
struct MonthlyProgressProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonthlyProgressEntry {
        MonthlyProgressEntry(
            date: Date(),
            habitData: HabitWidgetData(
                id: UUID(),
                name: "Wim hof brathing",
                icon: "cloud.fill",
                completionHistory: [:],
                completionStatus: [:]
            ),
            monthlyCompletions: generatePlaceholderCompletions()
        )
    }
    
    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> MonthlyProgressEntry {
        let habitData = loadHabitData(for: configuration.habit?.id)
        let completions = getMonthlyCompletions(for: habitData)
        return MonthlyProgressEntry(
            date: Date(),
            habitData: habitData,
            monthlyCompletions: completions
        )
    }
    
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<MonthlyProgressEntry> {
        let habitData = loadHabitData(for: configuration.habit?.id)
        let completions = getMonthlyCompletions(for: habitData)
        
        let entry = MonthlyProgressEntry(
            date: Date(),
            habitData: habitData,
            monthlyCompletions: completions
        )
        
        // Update every 6 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func loadHabitData(for habitId: UUID?) -> HabitWidgetData {
        guard let habitId = habitId,
              let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
              let data = sharedDefaults.data(forKey: "widgetHabit_\(habitId.uuidString)"),
              let habitData = try? JSONDecoder().decode(HabitWidgetData.self, from: data) else {
            // Return placeholder if no habit selected or data not found
            return HabitWidgetData(
                id: UUID(),
                name: "Select a habit",
                icon: "circle.fill",
                completionHistory: [:],
                completionStatus: [:]
            )
        }
        return habitData
    }
    
    private func getMonthlyCompletions(for habitData: HabitWidgetData) -> [Date: Bool] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return [:]
        }
        
        var date = startOfMonth
        var completions: [Date: Bool] = [:]
        
        while date <= endOfMonth {
            let dateKey = formatDateKey(for: date)
            let normalizedDate = calendar.startOfDay(for: date)
            // Check completionStatus first, then fall back to completionHistory
            let isCompleted = habitData.completionStatus[dateKey] ?? ((habitData.completionHistory[dateKey] ?? 0) > 0)
            completions[normalizedDate] = isCompleted
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        return completions
    }
    
    private func formatDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func generatePlaceholderCompletions() -> [Date: Bool] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return [:]
        }
        
        var completions: [Date: Bool] = [:]
        var date = startOfMonth
        
        while date <= endOfMonth {
            // Placeholder: randomly mark some days as completed for demo
            completions[date] = Int.random(in: 0...100) > 30
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endOfMonth
        }
        
        return completions
    }
}

// MARK: - Monthly Progress Entry
@available(iOS 17.0, *)
struct MonthlyProgressEntry: TimelineEntry {
    let date: Date
    let habitData: HabitWidgetData
    let monthlyCompletions: [Date: Bool]
}

// MARK: - Monthly Progress Widget View
@available(iOS 17.0, *)
struct MonthlyProgressWidgetView: View {
    var entry: MonthlyProgressProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            MonthlyProgressSmallView(entry: entry)
        default:
            MonthlyProgressSmallView(entry: entry)
        }
    }
}

// MARK: - Monthly Progress Small View
@available(iOS 17.0, *)
struct MonthlyProgressSmallView: View {
    let entry: MonthlyProgressEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon and name
            HStack(spacing: 8) {
                Image(systemName: entry.habitData.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("appText01"))
                    .frame(width: 20, height: 20)
                
                Text(entry.habitData.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("appText01"))
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Days of week labels
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("appText05"))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            CalendarGridView(completions: entry.monthlyCompletions)
        }
        .padding(12)
    }
}

// MARK: - Calendar Grid View
@available(iOS 17.0, *)
struct CalendarGridView: View {
    let completions: [Date: Bool]
    
    private let calendar = Calendar.current
    
    var body: some View {
        let gridItems = generateGridItems()
        
        VStack(spacing: 4) {
            ForEach(0..<gridItems.count, id: \.self) { weekIndex in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if weekIndex < gridItems.count && dayIndex < gridItems[weekIndex].count {
                            DayCircle(isCompleted: gridItems[weekIndex][dayIndex])
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }
    
    private func generateGridItems() -> [[Bool]] {
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        // Convert to our grid format (0 = Monday, 6 = Sunday)
        // Sunday = 1 -> 6, Monday = 2 -> 0, Tuesday = 3 -> 1, etc.
        let firstDayOffset = (firstWeekday + 5) % 7
        
        var gridItems: [[Bool]] = []
        var currentWeek: [Bool?] = Array(repeating: nil, count: 7)
        
        var date = startOfMonth
        var dayIndex = firstDayOffset
        
        while date <= endOfMonth {
            let dateKey = calendar.startOfDay(for: date)
            let isCompleted = completions[dateKey] ?? false
            currentWeek[dayIndex] = isCompleted
            
            dayIndex += 1
            if dayIndex >= 7 {
                // Convert optional array to non-optional, filling nil with false
                gridItems.append(currentWeek.map { $0 ?? false })
                currentWeek = Array(repeating: nil, count: 7)
                dayIndex = 0
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        // Add the last week if it has any days
        if currentWeek.contains(where: { $0 != nil }) {
            gridItems.append(currentWeek.map { $0 ?? false })
        }
        
        return gridItems
    }
}

// MARK: - Day Circle
@available(iOS 17.0, *)
struct DayCircle: View {
    let isCompleted: Bool
    
    var body: some View {
        Circle()
            .fill(isCompleted ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
            .frame(width: 8, height: 8)
    }
}

// MARK: - Monthly Progress Widget
@available(iOS 17.0, *)
struct MonthlyProgressWidget: Widget {
    let kind: String = "MonthlyProgressWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectHabitIntent.self, provider: MonthlyProgressProvider()) { entry in
            MonthlyProgressWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Monthly Progress")
        .description("Display monthly progress for a selected habit")
        .supportedFamilies([.systemSmall])
    }
}
