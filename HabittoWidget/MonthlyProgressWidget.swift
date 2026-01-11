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
                colorHex: nil,
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
        
        print("🟢 WIDGET: Loading data for habit '\(habitData.name)'")
        print("   Habit ID: \(habitData.id)")
        print("   completionHistory: \(habitData.completionHistory.count) entries")
        print("   completionStatus: \(habitData.completionStatus.count) entries")
        print("   monthlyCompletions: \(completions.count) entries")
        
        // Print recent completion data
        let recentKeys = habitData.completionStatus.keys.sorted().suffix(7)
        for key in recentKeys {
            let status = habitData.completionStatus[key] ?? false
            print("   \(key): \(status ? "✅ completed" : "❌ not completed")")
        }
        
        // Also log what's in UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.habitto.widget") {
            let keys = defaults.dictionaryRepresentation().keys.filter { $0.contains("widget") }
            print("🟢 WIDGET: App Group keys: \(Array(keys).sorted())")
            
            if let savedData = defaults.data(forKey: "widgetHabit_\(habitData.id.uuidString)") {
                print("🟢 WIDGET: Found saved data for this habit (\(savedData.count) bytes)")
            } else {
                print("⚠️ WIDGET: No saved data found for habit ID: \(habitData.id.uuidString)")
            }
        }
        
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
        guard let habitId = habitId else {
            print("🟡 WIDGET: No habit ID provided, returning placeholder")
            return HabitWidgetData(
                id: UUID(),
                name: "Select a habit",
                icon: "circle.fill",
                colorHex: nil,
                completionHistory: [:],
                completionStatus: [:]
            )
        }
        
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") else {
            print("⚠️ WIDGET: Failed to access App Group UserDefaults")
            return HabitWidgetData(
                id: habitId,
                name: "Select a habit",
                icon: "circle.fill",
                colorHex: nil,
                completionHistory: [:],
                completionStatus: [:]
            )
        }
        
        let key = "widgetHabit_\(habitId.uuidString)"
        guard let data = sharedDefaults.data(forKey: key) else {
            print("⚠️ WIDGET: No data found for key '\(key)'")
            // Check if widgetHabits array exists as fallback
            if let arrayData = sharedDefaults.data(forKey: "widgetHabits"),
               let habits = try? JSONDecoder().decode([HabitWidgetData].self, from: arrayData),
               let foundHabit = habits.first(where: { $0.id == habitId }) {
                print("🟢 WIDGET: Found habit in widgetHabits array: '\(foundHabit.name)'")
                return foundHabit
            }
            print("⚠️ WIDGET: Habit not found in widgetHabits array either")
            return HabitWidgetData(
                id: habitId,
                name: "Select a habit",
                icon: "circle.fill",
                colorHex: nil,
                completionHistory: [:],
                completionStatus: [:]
            )
        }
        
        guard let habitData = try? JSONDecoder().decode(HabitWidgetData.self, from: data) else {
            print("⚠️ WIDGET: Failed to decode habit data from key '\(key)'")
            return HabitWidgetData(
                id: habitId,
                name: "Select a habit",
                icon: "circle.fill",
                colorHex: nil,
                completionHistory: [:],
                completionStatus: [:]
            )
        }
        
        print("🟢 WIDGET: Successfully loaded habit '\(habitData.name)' from key '\(key)' (\(data.count) bytes)")
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
        case .systemMedium:
            MonthlyProgressMediumView(entry: entry)
        default:
            MonthlyProgressSmallView(entry: entry)
        }
    }
}

// MARK: - Habit Icon Inline View (Widget)
@available(iOS 17.0, *)
struct HabitIconInlineWidgetView: View {
    let icon: String
    
    var body: some View {
        Group {
            if icon.hasPrefix("Icon-") {
                // Asset icon
                Image(icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(Color("appText01"))
            } else if icon == "None" {
                // No icon selected - show small colored circle
                Circle()
                    .fill(Color("appText01").opacity(0.3))
                    .frame(width: 14, height: 14)
            } else if isEmoji(icon) {
                // Emoji
                Text(icon)
                    .font(.system(size: 14))
            } else {
                // System icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("appText01"))
            }
        }
        .frame(width: 18, height: 18)
    }
    
    private func isEmoji(_ string: String) -> Bool {
        // Check if the string contains emoji characters
        return string.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji || scalar.properties.isEmojiPresentation
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
            HStack(spacing: 6) {
                HabitIconInlineWidgetView(icon: entry.habitData.icon)
                
                Text(entry.habitData.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("appText01"))
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Days of week labels
            HStack(spacing: 2) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color("appText05"))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            CalendarGridView(
                completions: entry.monthlyCompletions,
                color: habitColor(from: entry.habitData.colorHex)
            )
        }
        .padding(6)
    }
    
    private func habitColor(from hex: String?) -> Color {
        guard let hex = hex, !hex.isEmpty else {
            return Color.blue // Default fallback
        }
        return colorFromHex(hex)
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Monthly Progress Medium View
@available(iOS 17.0, *)
struct MonthlyProgressMediumView: View {
    let entry: MonthlyProgressEntry
    private let dayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    
    private var streakCount: Int {
        calculateStreak(from: entry.habitData)
    }
    
    private var weeklyProgress: [Bool] {
        getWeeklyProgress(from: entry.habitData)
    }
    
    private var todayDayIndex: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Convert to Monday = 0, Sunday = 6
        return (weekday + 5) % 7
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Streak section at top
            HStack(spacing: 8) {
                Text("\(streakCount) day streak")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("appText03"))
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color("appText01"))
                
                Spacer()
            }
            
            // Weekly progress tracker
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 12) {
                        // Day label
                        Text(dayLabels[index])
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(Color("appText05"))
                        
                        // Completion circle
                        ZStack {
                            if weeklyProgress[index] {
                                // Filled circle with lightning bolt icon
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 24, height: 24)
                                
                                Image("Icon-Bolt_Filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .frame(width: 14, height: 14)
                            } else {
                                // Empty circle with stroke
                                Circle()
                                    .stroke(Color("appText07"), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(4)
                    .background(index == todayDayIndex ? Color("appPrimaryOpacity10") : Color.clear)
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Helper Functions
    
    private func calculateStreak(from habitData: HabitWidgetData) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // Check completionStatus first, then fall back to completionHistory
        while true {
            let dateKey = formatDateKey(for: checkDate)
            let isCompleted = habitData.completionStatus[dateKey] ?? ((habitData.completionHistory[dateKey] ?? 0) > 0)
            
            if isCompleted {
                streak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func getWeeklyProgress(from habitData: HabitWidgetData) -> [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        // Convert to Monday = 0, Sunday = 6
        // Sunday = 1 -> 6, Monday = 2 -> 0, Tuesday = 3 -> 1, etc.
        let daysFromMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            print("⚠️ WIDGET: Failed to calculate week start")
            return Array(repeating: false, count: 7)
        }
        
        var weeklyProgress: [Bool] = Array(repeating: false, count: 7)
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        // Fill in the current week (Monday to Sunday)
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekStart) {
                // Normalize to start of day to ensure correct date key matching
                let normalizedDate = calendar.startOfDay(for: date)
                let dateKey = formatDateKey(for: normalizedDate)
                let statusCompleted = habitData.completionStatus[dateKey] ?? false
                let historyCompleted = (habitData.completionHistory[dateKey] ?? 0) > 0
                let isCompleted = statusCompleted || historyCompleted
                weeklyProgress[i] = isCompleted
                
                if isCompleted {
                    print("   🟢 WIDGET: \(dayLabels[i]) (\(dateKey)): ✅ completed (status: \(statusCompleted), history: \(historyCompleted))")
                }
            }
        }
        
        let completedCount = weeklyProgress.filter { $0 }.count
        print("🟢 WIDGET: Weekly progress: \(completedCount)/7 days completed")
        
        return weeklyProgress
    }
    
    private func formatDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Grid View
@available(iOS 17.0, *)
struct CalendarGridView: View {
    let completions: [Date: Bool]
    let color: Color
    
    private let calendar = Calendar.current
    
    var body: some View {
        let gridItems = generateGridItems()
        
        VStack(spacing: 4) {
            ForEach(0..<gridItems.count, id: \.self) { weekIndex in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if weekIndex < gridItems.count && dayIndex < gridItems[weekIndex].count {
                            DayCircle(isCompleted: gridItems[weekIndex][dayIndex], color: color)
                                .frame(maxWidth: .infinity)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 12, height: 12)
                                .frame(maxWidth: .infinity)
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
    let color: Color
    
    var body: some View {
        Circle()
            .fill(isCompleted ? color.opacity(0.7) : Color("appOutline02"))
            .frame(width: 12, height: 12)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
