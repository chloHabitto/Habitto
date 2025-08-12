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
    var isCompleted: Bool = false
    var streak: Int = 0
    let createdAt: Date
    var completionHistory: [String: Int] = [:] // Track daily progress: "yyyy-MM-dd" -> Int (count of completions)
    
    // Habit Breaking specific properties
    var baseline: Int = 0 // Current average usage
    var target: Int = 0 // Target reduced amount
    var actualUsage: [String: Int] = [:] // Track actual usage: "yyyy-MM-dd" -> Int
    
    // MARK: - Designated Initializer
    init(id: UUID = UUID(), name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, streak: Int = 0, createdAt: Date = Date(), reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0, completionHistory: [String: Int] = [:], actualUsage: [String: Int] = [:]) {
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
        self.isCompleted = isCompleted
        self.streak = streak
        self.createdAt = createdAt
        self.baseline = baseline
        self.target = target
        self.completionHistory = completionHistory
        self.actualUsage = actualUsage
    }
    
    // MARK: - Convenience Initializers
    init(name: String, description: String, icon: String, color: Color, habitType: HabitType, schedule: String, goal: String, reminder: String, startDate: Date, endDate: Date? = nil, isCompleted: Bool = false, streak: Int = 0, reminders: [ReminderItem] = [], baseline: Int = 0, target: Int = 0) {
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
            isCompleted: isCompleted,
            streak: streak,
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
    mutating func markCompleted(for date: Date) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = currentProgress + 1
        updateCurrentCompletionStatus()
        
        // Debug: Print completion tracking
        print("🔍 COMPLETION DEBUG - Habit '\(name)' marked completed for \(dateKey) | Old: \(currentProgress) | New: \(completionHistory[dateKey] ?? 0)")
    }
    
    mutating func markIncomplete(for date: Date) {
        let dateKey = Self.dateKey(for: date)
        let currentProgress = completionHistory[dateKey] ?? 0
        completionHistory[dateKey] = max(0, currentProgress - 1)
        updateCurrentCompletionStatus()
    }
    
    func isCompleted(for date: Date) -> Bool {
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
    
    private mutating func updateCurrentCompletionStatus() {
        let today = Calendar.current.startOfDay(for: Date())
        isCompleted = isCompleted(for: today)
    }
    
    // MARK: - Improved Streak Tracking Methods
    /// Calculates the true consecutive day streak by checking actual completion history
    func calculateTrueStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        // Count consecutive completed days backwards from today
        while isCompleted(for: currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    /// Updates streak with proper reset logic based on consecutive day completion
    mutating func updateStreakWithReset() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        if isCompleted(for: today) {
            if isCompleted(for: yesterday) {
                // Continue streak - increment
                streak += 1
            } else {
                // Start new streak - reset to 1
                streak = 1
            }
        } else {
            // Reset streak if not completed today
            streak = 0
        }
    }
    
    /// Validates if the current streak matches actual consecutive completions
    func validateStreak() -> Bool {
        let actualStreak = calculateTrueStreak()
        return streak == actualStreak
    }
    
    /// Corrects the streak to match actual consecutive completions
    mutating func correctStreak() {
        streak = calculateTrueStreak()
    }
    
    /// Debug function to print streak information
    func debugStreakInfo() {
        let trueStreak = calculateTrueStreak()
        let isValid = validateStreak()
        print("🔍 Habit '\(name)': stored streak=\(streak), true streak=\(trueStreak), valid=\(isValid)")
    }
    
    static func dateKey(for date: Date) -> String {
        return DateUtils.dateKey(for: date)
    }
    
    // MARK: - Persistence Methods (Optimized)
    static func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        HabitStorageManager.shared.saveHabits(habits, immediate: immediate)
    }
    
    static func loadHabits() -> [Habit] {
        return HabitStorageManager.shared.loadHabits()
    }
    
    static func clearCache() {
        HabitStorageManager.shared.clearCache()
    }
}

enum HabitType: String, CaseIterable, Codable {
    case formation = "Habit Building"
    case breaking = "Habit Breaking"
}

 