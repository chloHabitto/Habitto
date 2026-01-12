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
            monthlyCompletions: generatePlaceholderCompletions(),
            globalStreak: 7,  // ✅ MEDIUM WIDGET: Global streak
            weeklyProgress: [true, true, true, true, true, true, true]  // ✅ MEDIUM WIDGET: Weekly progress (placeholder)
        )
    }
    
    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> MonthlyProgressEntry {
        let habitId = getHabitId(from: configuration)
        let habitData = loadHabitData(for: habitId)
        let completions = getMonthlyCompletions(for: habitData)
        // ✅ MEDIUM WIDGET: Load global streak and calculate weekly progress from all habits
        let globalStreak = loadGlobalStreak()
        let weeklyProgress = calculateWeeklyProgressFromAllHabits()
        return MonthlyProgressEntry(
            date: Date(),
            habitData: habitData,
            monthlyCompletions: completions,
            globalStreak: globalStreak,
            weeklyProgress: weeklyProgress
        )
    }
    
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<MonthlyProgressEntry> {
        // ✅ BUG FIX 1: Check configuration.habit?.id exists before loading
        let habitId = getHabitId(from: configuration)
        
        // ✅ CRITICAL: Verify habit ID was found
        if let habitId = habitId {
            print("🟢 WIDGET timeline: Found habit ID: \(habitId.uuidString)")
        } else {
            print("⚠️ WIDGET timeline: No habit ID found in configuration or UserDefaults")
            if let configHabitId = configuration.habit?.id {
                print("   configuration.habit?.id: \(configHabitId.uuidString)")
            } else {
                print("   configuration.habit?.id: nil")
            }
        }
        
        let habitData = loadHabitData(for: habitId)
        let completions = getMonthlyCompletions(for: habitData)
        
        // ✅ CRITICAL: Verify we loaded the correct habit, not placeholder
        if habitData.name == "Wim hof brathing" || habitData.name == "Select a habit" {
            print("⚠️ WIDGET timeline: WARNING - Loaded placeholder habit '\(habitData.name)' instead of user's habit!")
            print("   This means the widget couldn't find the selected habit in UserDefaults")
            print("   Check that WidgetDataSync.syncHabitsToWidget() is being called from the main app")
        }
        
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
        
        // 🔍 CRITICAL DEBUG: Verify data before creating entry
        print("🔍 WIDGET timeline: Creating entry with habitData:")
        print("   Habit ID: \(habitData.id)")
        print("   Habit name: '\(habitData.name)'")
        print("   completionStatus.count: \(habitData.completionStatus.count)")
        print("   completionHistory.count: \(habitData.completionHistory.count)")
        print("   completionStatus sample keys: \(Array(habitData.completionStatus.keys).sorted().prefix(5))")
        print("   completionHistory sample keys: \(Array(habitData.completionHistory.keys).sorted().prefix(5))")
        
        // ✅ MEDIUM WIDGET: Load global streak and calculate weekly progress from all habits
        let globalStreak = loadGlobalStreak()
        let weeklyProgress = calculateWeeklyProgressFromAllHabits()
        
        print("🟢 WIDGET timeline: Global streak = \(globalStreak)")
        print("🟢 WIDGET timeline: Weekly progress = \(weeklyProgress)")
        
        let entry = MonthlyProgressEntry(
            date: Date(),
            habitData: habitData,
            monthlyCompletions: completions,
            globalStreak: globalStreak,
            weeklyProgress: weeklyProgress
        )
        
        // 🔍 CRITICAL DEBUG: Verify entry after creation
        print("🔍 WIDGET timeline: Entry created, verifying entry.habitData:")
        print("   entry.habitData.completionStatus.count: \(entry.habitData.completionStatus.count)")
        print("   entry.habitData.completionHistory.count: \(entry.habitData.completionHistory.count)")
        print("   entry.globalStreak: \(entry.globalStreak)")
        print("   entry.weeklyProgress: \(entry.weeklyProgress)")
        
        // Update every 6 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    /// Get habit ID from configuration, falling back to stored UserDefaults value if nil
    private func getHabitId(from configuration: SelectHabitIntent) -> UUID? {
        if let configHabitId = configuration.habit?.id {
            print("🟢 WIDGET timeline/snapshot: Configuration has habit ID: \(configHabitId)")
            // Store this as the selected habit for future fallback
            if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
                sharedDefaults.set(configHabitId.uuidString, forKey: "selectedMonthlyWidgetHabitId")
                sharedDefaults.synchronize()
            }
            return configHabitId
        } else {
            print("🟡 WIDGET timeline/snapshot: No habit ID in configuration, attempting to load from UserDefaults fallback")
            // Try to load from UserDefaults fallback
            if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
               let storedIdString = sharedDefaults.string(forKey: "selectedMonthlyWidgetHabitId"),
               let storedId = UUID(uuidString: storedIdString) {
                print("🟢 WIDGET timeline/snapshot: Found stored habit ID in UserDefaults: \(storedId)")
                return storedId
            } else {
                print("🟡 WIDGET timeline/snapshot: No stored habit ID found, attempting to load first available habit")
                // Last resort: try to load the first available habit from widgetHabits array
                if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
                   let arrayData = sharedDefaults.data(forKey: "widgetHabits"),
                   let habits = try? JSONDecoder().decode([HabitWidgetData].self, from: arrayData),
                   let firstHabit = habits.first {
                    print("🟢 WIDGET timeline/snapshot: Using first available habit: '\(firstHabit.name)' (ID: \(firstHabit.id))")
                    // Store this as the selected habit for future use
                    sharedDefaults.set(firstHabit.id.uuidString, forKey: "selectedMonthlyWidgetHabitId")
                    sharedDefaults.synchronize()
                    return firstHabit.id
                }
                print("⚠️ WIDGET timeline/snapshot: No habit ID available from any source")
                return nil
            }
        }
    }
    
    private func loadHabitData(for habitId: UUID?) -> HabitWidgetData {
        guard let habitId = habitId else {
            print("⚠️ WIDGET: No habit ID provided, attempting to load first available habit")
            // Try to load first available habit instead of returning placeholder
            if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
               let arrayData = sharedDefaults.data(forKey: "widgetHabits"),
               let habits = try? JSONDecoder().decode([HabitWidgetData].self, from: arrayData),
               let firstHabit = habits.first {
                print("🟢 WIDGET: Loaded first available habit: '\(firstHabit.name)' (ID: \(firstHabit.id))")
                return firstHabit
            }
            print("🟡 WIDGET: No habit ID provided and no habits available, returning placeholder")
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
    
    /// Test to demonstrate timezone mismatch between app (TimeZone.current) and widget (UTC)
    private func testTimezoneMismatch(for date: Date) {
        print()
        print("🔍 TIMEZONE MISMATCH TEST")
        print("   Testing date: \(date)")
        print()
        
        // Generate date key using APP's method (TimeZone.current)
        let appFormatter = DateFormatter()
        appFormatter.dateFormat = "yyyy-MM-dd"
        appFormatter.timeZone = TimeZone.current
        let appDateKey = appFormatter.string(from: date)
        
        // Generate date key using WIDGET's method (UTC)
        let widgetFormatter = DateFormatter()
        widgetFormatter.dateFormat = "yyyy-MM-dd"
        widgetFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let widgetDateKey = widgetFormatter.string(from: date)
        
        print("   📱 APP (TimeZone.current):")
        print("      Timezone: \(TimeZone.current.identifier)")
        print("      Date Key: '\(appDateKey)'")
        print()
        
        print("   📦 WIDGET (UTC):")
        print("      Timezone: UTC")
        print("      Date Key: '\(widgetDateKey)'")
        print()
        
        if appDateKey != widgetDateKey {
            print("   ⚠️  MISMATCH DETECTED!")
            print("      App would store:    completionStatus['\(appDateKey)'] = true")
            print("      Widget would look:  completionStatus['\(widgetDateKey)'] → NOT FOUND ❌")
            print("      Result: Widget will show incomplete day even though app marked it complete!")
        } else {
            print("   ✅ Keys match for this timestamp")
        }
        print()
    }
    
    private func formatDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // ✅ FIX: Use local timezone to match app's date key format (DateUtils.dateKey uses TimeZone.current)
        formatter.timeZone = TimeZone.current
        let key = formatter.string(from: date)
        print("      formatDateKey: date=\(date) -> key='\(key)' (local timezone)")
        return key
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
    
    // ✅ MEDIUM WIDGET: Load global streak from UserDefaults (same as small widget)
    private func loadGlobalStreak() -> Int {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") else {
            print("⚠️ WIDGET: Failed to access App Group UserDefaults for global streak")
            return 0
        }
        
        sharedDefaults.synchronize()
        let streak = sharedDefaults.integer(forKey: "widgetCurrentStreak")
        print("🟢 WIDGET: Loaded global streak = \(streak)")
        return streak
    }
    
    // ✅ MEDIUM WIDGET: Calculate weekly progress from ALL habits
    // Returns array of 7 booleans (Monday to Sunday) indicating if ALL habits were completed each day
    private func calculateWeeklyProgressFromAllHabits() -> [Bool] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget"),
              let arrayData = sharedDefaults.data(forKey: "widgetHabits"),
              let allHabits = try? JSONDecoder().decode([HabitWidgetData].self, from: arrayData) else {
            print("⚠️ WIDGET: Failed to load all habits for weekly progress calculation")
            return Array(repeating: false, count: 7)
        }
        
        print("🟢 WIDGET: Calculating weekly progress from \(allHabits.count) habits")
        
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart) else {
            print("⚠️ WIDGET: Failed to calculate week start")
            return Array(repeating: false, count: 7)
        }
        
        var weeklyProgress: [Bool] = Array(repeating: false, count: 7)
        
        // For each day of the week (Monday to Sunday)
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dateKey = formatDateKey(for: date)
            
            // Check if ALL habits were completed on this day
            // A day is complete if ALL habits have either completionStatus=true OR completionHistory > 0
            let allComplete = allHabits.allSatisfy { habit in
                let statusCompleted = habit.completionStatus[dateKey] ?? false
                let historyValue = habit.completionHistory[dateKey] ?? 0
                let historyCompleted = historyValue > 0
                return statusCompleted || historyCompleted
            }
            
            weeklyProgress[i] = allComplete
            
            let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            print("   \(dayLabels[i]) (\(dateKey)): \(allComplete ? "✅ all habits completed" : "❌ incomplete")")
        }
        
        let completedCount = weeklyProgress.filter { $0 }.count
        print("🟢 WIDGET: Weekly progress: \(completedCount)/7 days with all habits completed")
        
        return weeklyProgress
    }
}

// MARK: - Monthly Progress Entry
@available(iOS 17.0, *)
struct MonthlyProgressEntry: TimelineEntry {
    let date: Date
    let habitData: HabitWidgetData  // For small widget (monthly calendar view)
    let monthlyCompletions: [Date: Bool]  // For small widget
    // ✅ MEDIUM WIDGET: Global streak and weekly progress
    let globalStreak: Int  // Global streak (same as small widget)
    let weeklyProgress: [Bool]  // Weekly progress (all habits completed each day)
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
    
    // ✅ MEDIUM WIDGET: Use global streak and weekly progress from entry
    // No need to calculate from habitData anymore - it's already calculated from all habits
    
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
                Text("\(entry.globalStreak) day streak")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("appText03"))
                
                Image("Widget-Icon-Fire")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
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
                            if entry.weeklyProgress[index] {
                                // Filled circle with lightning bolt icon
                                Circle()
                                    .fill(Color("appPrimary"))
                                    .frame(width: 24, height: 24)
                                
                                Image("Icon-Bolt_Filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(Color("appOnPrimary"))
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
                    .cornerRadius(24)
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
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        print("🟡 WIDGET getWeeklyProgress: Starting weekly progress calculation")
        NSLog("🟡 WIDGET getWeeklyProgress: Starting weekly progress calculation")
        
        // 🔍 CRITICAL DEBUG: Log the habitData being passed in
        print("🔍 WIDGET getWeeklyProgress: Received habitData:")
        print("   Habit ID: \(habitData.id)")
        print("   Habit name: '\(habitData.name)'")
        print("   completionStatus.count: \(habitData.completionStatus.count)")
        print("   completionHistory.count: \(habitData.completionHistory.count)")
        print("   completionStatus keys: \(Array(habitData.completionStatus.keys).sorted())")
        print("   completionHistory keys: \(Array(habitData.completionHistory.keys).sorted())")
        
        print("   Today: \(today)")
        NSLog("   Today: \(today)")
        print("   Today (start of day): \(todayStart)")
        NSLog("   Today (start of day): \(todayStart)")
        print("   TimeZone: \(TimeZone.current.identifier)")
        NSLog("   TimeZone: \(TimeZone.current.identifier)")
        
        // Get the start of the current week (Monday)
        let weekday = calendar.component(.weekday, from: today)
        print("   Weekday (1=Sun, 2=Mon, etc.): \(weekday)")
        
        // Convert to Monday = 0, Sunday = 6
        // Sunday = 1 -> 6, Monday = 2 -> 0, Tuesday = 3 -> 1, etc.
        let daysFromMonday = (weekday + 5) % 7
        print("   Days from Monday: \(daysFromMonday)")
        
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart) else {
            print("⚠️ WIDGET: Failed to calculate week start")
            return Array(repeating: false, count: 7)
        }
        
        print("   Week start (Monday): \(weekStart)")
        
        // Print all available date keys in completionStatus and completionHistory
        print("   Available completionStatus keys: \(habitData.completionStatus.keys.sorted())")
        print("   Available completionHistory keys: \(habitData.completionHistory.keys.sorted())")
        
        var weeklyProgress: [Bool] = Array(repeating: false, count: 7)
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        // Fill in the current week (Monday to Sunday)
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekStart) {
                // Normalize to start of day to ensure correct date key matching
                let normalizedDate = calendar.startOfDay(for: date)
                let dateKey = formatDateKey(for: normalizedDate)
                
                // Check if key exists in dictionaries
                let statusExists = habitData.completionStatus[dateKey] != nil
                let historyExists = habitData.completionHistory[dateKey] != nil
                let statusCompleted = habitData.completionStatus[dateKey] ?? false
                let historyValue = habitData.completionHistory[dateKey] ?? 0
                let historyCompleted = historyValue > 0
                let isCompleted = statusCompleted || historyCompleted
                
                weeklyProgress[i] = isCompleted
                
                // Always print for debugging
                print("   \(dayLabels[i]) (day \(i)): date=\(date), normalized=\(normalizedDate), dateKey='\(dateKey)'")
                print("      statusExists=\(statusExists), statusValue=\(statusCompleted)")
                print("      historyExists=\(historyExists), historyValue=\(historyValue)")
                print("      isCompleted=\(isCompleted) \(isCompleted ? "✅" : "❌")")
            }
        }
        
        let completedCount = weeklyProgress.filter { $0 }.count
        print("🟢 WIDGET: Weekly progress result: \(completedCount)/7 days completed")
        
        return weeklyProgress
    }
    
    private func formatDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // ✅ FIX: Use local timezone to match app's date key format (DateUtils.dateKey uses TimeZone.current)
        formatter.timeZone = TimeZone.current
        let key = formatter.string(from: date)
        // Debug logging for date key generation
        #if DEBUG
        print("      formatDateKey: date=\(date) -> key='\(key)' (local timezone)")
        #endif
        return key
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
