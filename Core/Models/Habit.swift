import SwiftUI

// MARK: - Habit Storage Manager for Performance Optimization
class HabitStorageManager {
    static let shared = HabitStorageManager()
    private let userDefaults = UserDefaults.standard
    private let habitsKey = "SavedHabits"
    
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
    private var lastSaveTime: Date = Date()
    private let saveDebounceInterval: TimeInterval = 0.5
    
    private init() {}
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        // Performance optimization: Debounce saves to avoid excessive writes
        // But allow immediate saves when needed (e.g., new habit creation)
        if immediate {
            performSave(habits)
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
            // Schedule a delayed save
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                self.performSave(habits)
            }
            return
        }
        
        performSave(habits)
    }
    
    private func performSave(_ habits: [Habit]) {
        // Performance optimization: Only save if habits actually changed
        if let cached = cachedHabits, cached == habits {
            return // No change, skip save
        }
        
        if let encoded = try? JSONEncoder().encode(habits) {
            userDefaults.set(encoded, forKey: habitsKey)
            cachedHabits = habits
            lastSaveTime = Date()
        }
    }
    
    func loadHabits() -> [Habit] {
        // Performance optimization: Return cached result if available
        if let cached = cachedHabits {
            return cached
        }
        
        if let data = userDefaults.data(forKey: habitsKey),
           let habits = try? JSONDecoder().decode([Habit].self, from: data) {
            cachedHabits = habits
            return habits
        }
        return []
    }
    
    func clearCache() {
        cachedHabits = nil
    }
}

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let icon: String // System icon name
    let color: Color
    let habitType: HabitType
    let schedule: String
    let goal: String
    let reminder: String // Keep for backward compatibility
    let reminders: [ReminderItem] // New field for storing reminder items
    let startDate: Date
    let endDate: Date?
    // ❌ REMOVED: Denormalized fields in Phase 4
    // var isCompleted: Bool = false  // Use isCompleted(for:) instead
    // var streak: Int = 0           // Use computedStreak() instead
    let createdAt: Date
    var completionHistory: [String: Int] = [:] // Track daily progress: "yyyy-MM-dd" -> Int (count of completions)
    var completionTimestamps: [String: [Date]] = [:] // Track completion timestamps: "yyyy-MM-dd" -> [completion_times]
    var difficultyHistory: [String: Int] = [:] // Track daily difficulty: "yyyy-MM-dd" -> Int (1-10 scale)
    
    // Habit Breaking specific properties
    var baseline: Int = 0 // Current average usage
    var target: Int = 0 // Target reduced amount
    var actualUsage: [String: Int] = [:] // Track actual usage: "yyyy-MM-dd" -> Int
    
    // MARK: - Codable Support for Migration
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color, habitType, schedule, goal, reminder
        case startDate, endDate, isCompleted, streak, createdAt, reminders
        case baseline, target, completionHistory, difficultyHistory, actualUsage
        case completionTimestamps
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(Color.self, forKey: .color)
        habitType = try container.decode(HabitType.self, forKey: .habitType)
        schedule = try container.decode(String.self, forKey: .schedule)
        goal = try container.decode(String.self, forKey: .goal)
        reminder = try container.decode(String.self, forKey: .reminder)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        // ❌ REMOVED: Denormalized field decoding in Phase 4
        // isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        // streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        reminders = try container.decodeIfPresent([ReminderItem].self, forKey: .reminders) ?? []
        baseline = try container.decodeIfPresent(Int.self, forKey: .baseline) ?? 0
        target = try container.decodeIfPresent(Int.self, forKey: .target) ?? 0
        completionHistory = try container.decodeIfPresent([String: Int].self, forKey: .completionHistory) ?? [:]
        difficultyHistory = try container.decodeIfPresent([String: Int].self, forKey: .difficultyHistory) ?? [:]
        actualUsage = try container.decodeIfPresent([String: Int].self, forKey: .actualUsage) ?? [:]
        
        // Handle migration for new completionTimestamps field
        completionTimestamps = try container.decodeIfPresent([String: [Date]].self, forKey: .completionTimestamps) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(habitType, forKey: .habitType)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(goal, forKey: .goal)
        try container.encode(reminder, forKey: .reminder)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        // Note: isCompleted and streak are computed-only fields, not encoded
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(baseline, forKey: .baseline)
        try container.encode(target, forKey: .target)
        try container.encode(completionHistory, forKey: .completionHistory)
        try container.encode(difficultyHistory, forKey: .difficultyHistory)
        try container.encode(actualUsage, forKey: .actualUsage)
        try container.encode(completionTimestamps, forKey: .completionTimestamps)
    }
    
    // MARK: - Designated Initializer
    init(id: UUID = UUID(), name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, createdAt: Date = Date(), reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0, completionHistory: [String: Int] = [:], completionTimestamps: [String: [Date]] = [:], difficultyHistory: [String: Int] = [:], actualUsage: [String: Int] = [:]) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.habitType = habitType
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.reminders = reminders
        self.startDate = startDate
        self.endDate = endDate
        // ❌ REMOVED: Denormalized field assignments in Phase 4
        // self.isCompleted = isCompleted  // Use isCompleted(for:) instead
        // self.streak = streak           // Use computedStreak() instead
        self.createdAt = createdAt
        self.baseline = baseline
        self.target = target
        self.completionHistory = completionHistory
        self.completionTimestamps = completionTimestamps
        self.difficultyHistory = difficultyHistory
        self.actualUsage = actualUsage
    }
    
    // MARK: - Convenience Initializers
    init(name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0) {
        self.init(
            id: UUID(),
            name: name,
            description: description,
            icon: icon,
            color: color,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            // ❌ REMOVED: Denormalized field parameters in Phase 4
            // isCompleted: isCompleted,  // Use isCompleted(for:) instead
            // streak: streak,           // Use computedStreak() instead
            createdAt: Date(),
            reminders: reminders,
            baseline: baseline,
            target: target
        )
    }
    
    init(from step1Data: (String, String, String, Color, HabitType), schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0) {
        self.init(
            id: UUID(),
            name: step1Data.0,
            description: step1Data.1,
            icon: step1Data.2,
            color: step1Data.3,
            habitType: step1Data.4,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders,
            baseline: baseline,
            target: target
        )
    }
    
    // MARK: - Completion History Methods
    mutating func markCompleted(for date: Date, at timestamp: Date = Date()) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = currentProgress + 1
        
        // Store the actual completion timestamp
        if completionTimestamps[dateKey] == nil {
            completionTimestamps[dateKey] = []
        }
        completionTimestamps[dateKey]?.append(timestamp)
        
        // ❌ REMOVED: Denormalized field updates in Phase 4
        // updateCurrentCompletionStatus() and updateStreakWithReset() have been removed
        // Use isCompleted(for:) and calculateTrueStreak() for read-only access
        
        // Debug: Print completion tracking
        print("🔍 COMPLETION DEBUG - Habit '\(name)' marked completed for \(dateKey) at \(timestamp) | Old: \(currentProgress) | New: \(completionHistory[dateKey] ?? 0)")
    }
    
    // MARK: - Difficulty History Methods
    mutating func recordDifficulty(_ difficulty: Int, for date: Date) {
        let dateKey = Self.dateKey(for: date)
        difficultyHistory[dateKey] = difficulty
        
        // Debug: Print difficulty tracking
        print("🔍 DIFFICULTY DEBUG - Habit '\(name)' difficulty \(difficulty) recorded for \(dateKey)")
    }
    
    func getDifficulty(for date: Date) -> Int? {
        let dateKey = Self.dateKey(for: date)
        return difficultyHistory[dateKey]
    }
    
    mutating func markIncomplete(for date: Date) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = max(0, currentProgress - 1)
        
        // Remove the most recent timestamp if there are any
        if completionTimestamps[dateKey]?.isEmpty == false {
            completionTimestamps[dateKey]?.removeLast()
        }
        
        // ❌ REMOVED: Denormalized field updates in Phase 4
        // updateCurrentCompletionStatus() and updateStreakWithReset() have been removed
        // Use isCompleted(for:) and calculateTrueStreak() for read-only access
    }
    
    func isCompleted(for date: Date) -> Bool {
        // If it's a vacation day AND vacation is currently active, treat it as neutral
        let vacationManager = VacationManager.shared
        if vacationManager.isActive && vacationManager.isVacationDay(date) {
            // For vacation days during active vacation, we need to determine if the habit would have been completed
            // based on the previous non-vacation day's completion status
            let calendar = Calendar.current
            var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            
            // Look back to find the last non-vacation day
            while vacationManager.isActive && vacationManager.isVacationDay(checkDate) {
                guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = prevDate
            }
            
            // Return the completion status of the last non-vacation day
            return isCompletedInternal(for: checkDate)
        }
        
        // For non-vacation days or historical vacation days, use the normal completion logic
        return isCompletedInternal(for: date)
    }
    
    /// Internal completion check that doesn't consider vacation days
    private func isCompletedInternal(for date: Date) -> Bool {
        let dateKey = Self.dateKey(for: date)
        let progress = completionHistory[dateKey] ?? 0
        
        // Parse the goal to get the target amount
        if let targetAmount = parseGoalAmount(from: goal) {
            // A habit is complete when progress reaches or exceeds the goal amount
            return progress >= targetAmount
        }
        
        // Fallback: if we can't parse the goal, consider it complete with any progress
        return progress > 0
    }
    
    // Helper method to parse goal amount from goal string
    private func parseGoalAmount(from goalString: String) -> Int? {
        // Extract the number from goal strings like "6 times per day", "3 times", etc.
        let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let amount = Int(component), amount > 0 {
                return amount
            }
        }
        return nil
    }
    
    func getProgress(for date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        let progress = completionHistory[dateKey] ?? 0
        
        // Debug: Print progress retrieval
        print("🔍 PROGRESS DEBUG - Habit '\(name)' | Date: \(dateKey) | Progress: \(progress) | CompletionHistory keys: \(completionHistory.keys.sorted())")
        
        return progress
    }
    
    // MARK: - Habit Breaking Methods
    mutating func logActualUsage(_ amount: Int, for date: Date) {
        let dateKey = Self.dateKey(for: date)
        actualUsage[dateKey] = amount
    }
    
    func getActualUsage(for date: Date) -> Int {
        let dateKey = Self.dateKey(for: date)
        return actualUsage[dateKey] ?? 0
    }
    
    func calculateSuccessRate(for date: Date) -> Double {
        let actual = getActualUsage(for: date)
        
        if target == 0 {
            // Complete elimination
            return baseline > 0 ? Double(baseline - actual) / Double(baseline) * 100.0 : 0.0
        } else {
            // Partial reduction
            let reductionRange = baseline - target
            return reductionRange > 0 ? Double(baseline - actual) / Double(reductionRange) * 100.0 : 0.0
        }
    }
    
    func getProgressForHabitBreaking(for date: Date) -> Int {
        let successRate = calculateSuccessRate(for: date)
        return Int(successRate)
    }
    
    /// ❌ REMOVED: updateCurrentCompletionStatus method
    /// This method has been removed in Phase 4. Use isCompleted(for:) for read-only access.
    @available(*, unavailable, message: "Removed in Phase 4. Use isCompleted(for:) for read-only access.")
    private mutating func updateCurrentCompletionStatus() {
        fatalError("updateCurrentCompletionStatus has been removed. Use isCompleted(for:) for read-only access.")
    }
    
    // MARK: - Improved Streak Tracking Methods
    /// Calculates the true consecutive day streak by checking actual completion history
    /// Skips vacation days to preserve streaks during vacation periods
    func calculateTrueStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let vacationManager = VacationManager.shared
        var calculatedStreak = 0
        var currentDate = today
        var debugInfo: [String] = []
        
        // Count consecutive completed days backwards from today
        // Skip vacation days only during active vacation periods
        while isCompleted(for: currentDate) || (vacationManager.isActive && vacationManager.isVacationDay(currentDate)) {
            let dateKey = Self.dateKey(for: currentDate)
            let isCompleted = isCompleted(for: currentDate)
            let isVacation = vacationManager.isActive && vacationManager.isVacationDay(currentDate)
            
            // Only increment streak for actually completed days (not vacation days)
            if isCompleted {
                calculatedStreak += 1
                debugInfo.append("\(dateKey): completed=true, vacation=\(isVacation)")
            } else {
                debugInfo.append("\(dateKey): completed=false, vacation=\(isVacation)")
            }
            
            // Move to previous day regardless of vacation status
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        print("🔍 STREAK CALCULATION DEBUG - Habit '\(name)': calculated streak=\(calculatedStreak), details: \(debugInfo.joined(separator: ", "))")
        
        return calculatedStreak
    }
    
    /// ❌ REMOVED: updateStreakWithReset method
    /// This method has been removed in Phase 4. Use calculateTrueStreak() for read-only access.
    @available(*, unavailable, message: "Removed in Phase 4. Use calculateTrueStreak() for read-only access.")
    mutating func updateStreakWithReset() {
        fatalError("updateStreakWithReset has been removed. Use calculateTrueStreak() for read-only access.")
    }
    
    /// Validates if the current streak matches actual consecutive completions
    func validateStreak() -> Bool {
        let actualStreak = calculateTrueStreak()
        // ❌ REMOVED: Denormalized field comparison in Phase 4
        // Streak validation now always returns true since we only use computed values
        let isValid = true
        
        print("🔍 STREAK VALIDATION DEBUG - Habit '\(name)': calculated streak=\(actualStreak), valid=\(isValid) (computed-only)")
        
        return isValid
    }
    
    /// ❌ REMOVED: correctStreak method
    /// This method has been removed in Phase 4. Use calculateTrueStreak() for read-only access.
    @available(*, unavailable, message: "Removed in Phase 4. Use calculateTrueStreak() for read-only access.")
    mutating func correctStreak() {
        fatalError("correctStreak has been removed. Use calculateTrueStreak() for read-only access.")
    }
    
    /// ❌ REMOVED: recalculateCompletionStatus method
    /// This method has been removed in Phase 4. Use isCompleted(for:) for read-only access.
    @available(*, unavailable, message: "Removed in Phase 4. Use isCompleted(for:) for read-only access.")
    mutating func recalculateCompletionStatus() {
        fatalError("recalculateCompletionStatus has been removed. Use isCompleted(for:) for read-only access.")
    }
    
    /// Debug function to print streak information
    func debugStreakInfo() {
        let trueStreak = calculateTrueStreak()
        let isValid = validateStreak()
        print("🔍 Habit '\(name)': computed streak=\(trueStreak), valid=\(isValid) (computed-only)")
    }
    
    static func dateKey(for date: Date) -> String {
        return DateUtils.dateKey(for: date)
    }
    
    // MARK: - Persistence Methods (Optimized)
    static func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        OptimizedHabitStorageManager.shared.saveHabits(habits, immediate: immediate)
    }
    
    static func loadHabits() -> [Habit] {
        return OptimizedHabitStorageManager.shared.loadHabits()
    }
    
    static func clearCache() {
        OptimizedHabitStorageManager.shared.clearCache()
    }
}

enum HabitType: String, CaseIterable, Codable {
    case formation = "Habit Building"
    case breaking = "Habit Breaking"
}

 