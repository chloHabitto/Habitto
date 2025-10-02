import Foundation
import SwiftData

// MARK: - Habit Computed Properties
/// Read-only computed helpers for Habit that derive data from Completion/DailyAward
extension Habit {
    
    /// Computed completion status for a specific date
    /// Derives from Completion records, not stored denormalized field
    func isCompleted(for date: Date, userId: String? = nil) -> Bool {
        // For now, use the existing completion history
        // In Phase 5, this will read from Completion records in SwiftData
        let dateKey = Self.dateKey(for: date)
        let completionCount = completionHistory[dateKey] ?? 0
        return completionCount > 0
    }
    
    /// Computed current completion status (today)
    /// Derives from Completion records, not stored denormalized field
    var currentCompletionStatus: Bool {
        return isCompleted(for: Date())
    }
    
    /// Computed streak for this habit
    /// Derives from consecutive completion history, not stored denormalized field
    func computedStreak() -> Int {
        // Use the existing calculateTrueStreak method which already computes from history
        return calculateTrueStreak()
    }
    
    /// Computed streak for a specific user (when user-scoped)
    /// This will be the primary method once fully migrated to SwiftData
    func computedStreak(for userId: String) -> Int {
        // For now, return the computed streak
        // In Phase 5, this will compute from Completion records
        return computedStreak()
    }
}

// MARK: - Habit SwiftData Integration
/// Extensions for HabitData model with computed properties
extension HabitData {
    
    /// Computed completion status for a specific date
    /// Reads from CompletionRecord relationships
    func isCompleted(for date: Date) -> Bool {
        let dateKey = DateKey.key(for: date)
        return completionHistory.contains { record in
            record.dateKey == dateKey && record.isCompleted
        }
    }
    
    /// Computed current completion status (today)
    /// Reads from CompletionRecord relationships
    var currentCompletionStatus: Bool {
        return isCompleted(for: Date())
    }
    
    /// Computed streak for this habit
    /// Reads from CompletionRecord relationships
    func computedStreak() -> Int {
        // Get all completion records, sorted by date
        let sortedCompletions = completionHistory
            .filter { $0.isCompleted }
            .sorted { $0.date < $1.date }
        
        // Calculate consecutive streak from most recent backwards
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        // Go backwards day by day
        while true {
            let dateKey = DateKey.key(for: currentDate)
            
            // Check if this date has a completion record
            let hasCompletion = sortedCompletions.contains { record in
                record.dateKey == dateKey
            }
            
            if hasCompletion {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
}

// MARK: - Legacy Compatibility
/// Temporary compatibility layer for existing code
extension Habit {
    
    /// Legacy computed property for backward compatibility
    /// This replaces the stored `isCompleted` field
    @available(*, deprecated, message: "Use isCompleted(for:) instead")
    var isCompleted: Bool {
        get {
            return currentCompletionStatus
        }
        set {
            // No-op - this field is now read-only
            // Use markCompleted/markIncomplete methods instead
        }
    }
    
    /// Legacy computed property for backward compatibility  
    /// This replaces the stored `streak` field
    @available(*, deprecated, message: "Use computedStreak() instead")
    var streak: Int {
        get {
            return computedStreak()
        }
        set {
            // No-op - this field is now read-only
            // Streak is computed from completion history
        }
    }
}
