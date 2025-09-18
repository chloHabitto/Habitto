import Foundation

// MARK: - Habit Model Improvements
// This file contains improvements to the existing Habit model without breaking changes

// MARK: - Typed Schedule System (Non-Breaking)

/// Typed schedule system that can work alongside the existing string-based system
enum HabitScheduleType: String, CaseIterable, Codable {
    case daily = "daily"
    case everyNDays = "everyNDays"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .everyNDays: return "Every N days"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
    
    /// Parse from existing string schedule
    static func from(string: String) -> HabitScheduleType {
        let lowercased = string.lowercased()
        
        if lowercased.contains("daily") || lowercased.contains("every day") {
            return .daily
        } else if lowercased.contains("every") && lowercased.contains("day") {
            return .everyNDays
        } else if lowercased.contains("weekly") {
            return .weekly
        } else if lowercased.contains("monthly") {
            return .monthly
        } else {
            return .custom
        }
    }
}

// MARK: - Typed Goal System (Non-Breaking)

/// Typed goal system that can work alongside the existing string-based system
enum HabitGoalType: String, CaseIterable, Codable {
    case count = "count"
    case duration = "duration"
    case frequency = "frequency"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .count: return "Count"
        case .duration: return "Duration"
        case .frequency: return "Frequency"
        case .custom: return "Custom"
        }
    }
    
    /// Parse from existing string goal
    static func from(string: String) -> HabitGoalType {
        let lowercased = string.lowercased()
        
        if lowercased.contains("times") || lowercased.contains("x") {
            return .count
        } else if lowercased.contains("minute") || lowercased.contains("hour") {
            return .duration
        } else if lowercased.contains("per") || lowercased.contains("frequency") {
            return .frequency
        } else {
            return .custom
        }
    }
}

// MARK: - Normalized Day Log System (Non-Breaking)

/// Normalized day log that can work alongside existing dictionary-based system
struct NormalizedDayLog: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let value: Int
    let metadata: [String: String]
    
    init(date: Date, value: Int, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.date = date
        self.value = value
        self.metadata = metadata
    }
    
    /// Create from old string-based format
    static func from(dateKey: String, value: Int) -> NormalizedDayLog? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return nil }
        return NormalizedDayLog(date: date, value: value)
    }
    
    /// Convert to old string-based format
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Habit Extensions (Non-Breaking)

extension Habit {
    /// Get typed schedule information
    var scheduleType: HabitScheduleType {
        return HabitScheduleType.from(string: schedule)
    }
    
    /// Get typed goal information
    var goalType: HabitGoalType {
        return HabitGoalType.from(string: goal)
    }
    
    /// Get normalized completion logs
    var normalizedCompletionLog: [NormalizedDayLog] {
        return completionHistory.compactMap { dateKey, value in
            NormalizedDayLog.from(dateKey: dateKey, value: value)
        }
    }
    
    /// Get normalized difficulty logs
    var normalizedDifficultyLog: [NormalizedDayLog] {
        return difficultyHistory.compactMap { dateKey, value in
            NormalizedDayLog.from(dateKey: dateKey, value: value)
        }
    }
    
    /// Get normalized usage logs
    var normalizedUsageLog: [NormalizedDayLog] {
        return actualUsage.compactMap { dateKey, value in
            NormalizedDayLog.from(dateKey: dateKey, value: value)
        }
    }
    
    /// Set completion count for a specific date (using normalized logs)
    mutating func setCompletionCount(_ count: Int, for date: Date) {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        
        // Remove existing entry
        completionHistory.removeValue(forKey: dateKey)
        
        // Add new entry
        if count > 0 {
            completionHistory[dateKey] = count
        }
    }
    
    /// Get completion count for a specific date
    func completionCount(for date: Date) -> Int {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        return completionHistory[dateKey] ?? 0
    }
    
    /// Set difficulty for a specific date
    mutating func setDifficulty(_ difficulty: Int, for date: Date) {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        
        // Remove existing entry
        difficultyHistory.removeValue(forKey: dateKey)
        
        // Add new entry
        if difficulty > 0 {
            difficultyHistory[dateKey] = difficulty
        }
    }
    
    /// Get difficulty for a specific date
    func difficulty(for date: Date) -> Int {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        return difficultyHistory[dateKey] ?? 0
    }
    
    /// Set usage for a specific date
    mutating func setUsage(_ usage: Int, for date: Date) {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        
        // Remove existing entry
        actualUsage.removeValue(forKey: dateKey)
        
        // Add new entry
        if usage > 0 {
            actualUsage[dateKey] = usage
        }
    }
    
    /// Get usage for a specific date
    func usage(for date: Date) -> Int {
        let dateKey = NormalizedDayLog(date: date, value: 0).dateKey
        return actualUsage[dateKey] ?? 0
    }
    
    /// Check if habit is completed for a specific date (improved logic)
    func isCompletedImproved(for date: Date) -> Bool {
        let count = completionCount(for: date)
        
        // Parse goal to determine completion criteria
        switch goalType {
        case .count:
            // Extract number from goal string
            let numbers = goal.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            let targetCount = numbers.first ?? 1
            return count >= targetCount
        case .duration:
            // For duration goals, assume 1 completion = goal met
            return count > 0
        case .frequency:
            // For frequency goals, assume 1 completion = goal met
            return count > 0
        case .custom:
            // For custom goals, assume 1 completion = goal met
            return count > 0
        }
    }
    
    /// Calculate true streak using improved logic
    func calculateTrueStreakImproved() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        // Count consecutive completed days backwards from today
        while isCompletedImproved(for: currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    /// Update streak with proper reset logic
    mutating func updateStreakWithResetImproved() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        if isCompletedImproved(for: today) {
            if isCompletedImproved(for: yesterday) {
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
    
    /// Get schedule display name (improved)
    var scheduleDisplayName: String {
        switch scheduleType {
        case .daily:
            return "Daily"
        case .everyNDays:
            // Try to extract number from schedule string
            let numbers = schedule.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let number = numbers.first {
                return "Every \(number) days"
            }
            return "Every N days"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .custom:
            return schedule
        }
    }
    
    /// Get goal display name (improved)
    var goalDisplayName: String {
        switch goalType {
        case .count:
            // Try to extract number from goal string
            let numbers = goal.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let number = numbers.first {
                return "\(number) times"
            }
            return goal
        case .duration:
            return goal
        case .frequency:
            return goal
        case .custom:
            return goal
        }
    }
}

// MARK: - Data Validation Helpers

extension Habit {
    /// Validate habit data integrity
    func validateData() -> [String] {
        var errors: [String] = []
        
        // Validate name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Habit name cannot be empty")
        }
        
        // Validate start date
        if startDate > Date() {
            errors.append("Start date cannot be in the future")
        }
        
        // Validate end date
        if let endDate = endDate, endDate <= startDate {
            errors.append("End date must be after start date")
        }
        
        // Validate streak
        if streak < 0 {
            errors.append("Streak cannot be negative")
        }
        
        // Validate completion history
        for (dateKey, value) in completionHistory {
            if value < 0 {
                errors.append("Completion count cannot be negative for \(dateKey)")
            }
        }
        
        // Validate difficulty history
        for (dateKey, value) in difficultyHistory {
            if value < 1 || value > 10 {
                errors.append("Difficulty must be between 1-10 for \(dateKey)")
            }
        }
        
        // Validate usage history
        for (dateKey, value) in actualUsage {
            if value < 0 {
                errors.append("Usage count cannot be negative for \(dateKey)")
            }
        }
        
        return errors
    }
    
    /// Clean up invalid data
    mutating func cleanupInvalidData() {
        // Remove negative completion counts
        completionHistory = completionHistory.filter { $0.value >= 0 }
        
        // Remove invalid difficulty values
        difficultyHistory = difficultyHistory.filter { $0.value >= 1 && $0.value <= 10 }
        
        // Remove negative usage counts
        actualUsage = actualUsage.filter { $0.value >= 0 }
        
        // Ensure streak is not negative
        if streak < 0 {
            streak = 0
        }
    }
}

// MARK: - Performance Helpers

extension Habit {
    /// Get recent completion data (last 30 days) for performance
    func getRecentCompletionData(days: Int = 30) -> [String: Int] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        var recentData: [String: Int] = [:]
        
        for (dateKey, value) in completionHistory {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateKey),
               date >= startDate && date <= endDate {
                recentData[dateKey] = value
            }
        }
        
        return recentData
    }
    
    /// Get completion rate for a specific period
    func getCompletionRate(for startDate: Date, to endDate: Date) -> Double {
        let calendar = Calendar.current
        var totalDays = 0
        var completedDays = 0
        
        var currentDate = startDate
        while currentDate <= endDate {
            totalDays += 1
            if isCompleted(for: currentDate) {
                completedDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0.0
    }
}
