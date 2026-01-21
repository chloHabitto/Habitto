import Foundation
import SwiftData

/// GlobalStreakModel tracks ONE streak per user across ALL habits
///
/// **Design Philosophy:**
/// - Streak counts consecutive days where ALL scheduled habits were completed
/// - Replaces per-habit streaks (which were confusing and inconsistent)
/// - Vacation days DON'T break streak but DON'T increment it either
///
/// **Examples:**
/// - Day 1: All habits complete → currentStreak = 1
/// - Day 2: All habits complete → currentStreak = 2
/// - Day 3: One habit incomplete → currentStreak = 0 (broken!)
/// - Day 4: All habits complete → currentStreak = 1 (restart)
@Model
final class GlobalStreakModel {
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    
    /// User ID for multi-user support
    var userId: String
    
    // MARK: - Streak Data
    
    /// Current consecutive days with ALL habits complete
    var currentStreak: Int
    
    /// Best streak ever achieved
    var longestStreak: Int
    
    /// Total number of complete days (not necessarily consecutive)
    /// **Use case:** "You've completed all habits 47 times!"
    var totalCompleteDays: Int
    
    /// History of completed streaks (streaks that ended)
    /// **Use case:** Calculate average streak length
    /// **Note:** Only includes completed streaks, not the current ongoing streak
    /// **Example:** [5, 3, 7, 1] means you had 4 streaks that ended with lengths 5, 3, 7, and 1 days
    /// ✅ MIGRATION FIX: Default value prevents CoreData migration errors when adding this field
    var streakHistory: [Int] = []
    
    /// Last date where all habits were complete
    /// **Use case:** Detect streak breaks (if today > lastCompleteDate + 1 day)
    var lastCompleteDate: Date?
    
    // MARK: - Metadata
    
    /// Last time streak was calculated
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        userId: String,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalCompleteDays: Int = 0,
        streakHistory: [Int] = [],
        lastCompleteDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalCompleteDays = totalCompleteDays
        self.streakHistory = streakHistory
        self.lastCompleteDate = lastCompleteDate
        self.lastUpdated = Date()
    }
    
    // MARK: - Streak Mutations
    
    /// Increment streak for a complete day
    /// **Logic:**
    /// - If yesterday was complete → increment streak
    /// - If gap between lastCompleteDate and today → reset streak to 1
    /// - Update longestStreak if needed
    func incrementStreak(on date: Date) {
        let calendar = Calendar.current
        let dateNormalized = calendar.startOfDay(for: date)
        
        // Check if this is the next day after last complete date
        if let lastDate = lastCompleteDate {
            let lastDateNormalized = calendar.startOfDay(for: lastDate)
            
            // Calculate days between
            let components = calendar.dateComponents([.day], from: lastDateNormalized, to: dateNormalized)
            let daysDiff = components.day ?? 0
            
            if daysDiff == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
            } else if daysDiff > 1 {
                // Gap in streak - save old streak to history and reset to 1
                if currentStreak > 0 {
                    streakHistory.append(currentStreak)
                }
                currentStreak = 1
            } else if daysDiff == 0 {
                // Same day - don't increment (shouldn't happen, but handle gracefully)
                print("⚠️ Attempted to increment streak for same day: \(dateNormalized)")
                return
            } else {
                // daysDiff < 0 means trying to increment for past date (shouldn't happen)
                print("⚠️ Attempted to increment streak for past date: \(dateNormalized) before \(lastDateNormalized)")
                return
            }
        } else {
            // First complete day ever
            currentStreak = 1
        }
        
        // Update longest streak if needed
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        // Update totals
        totalCompleteDays += 1
        lastCompleteDate = dateNormalized
        lastUpdated = Date()
    }
    
    /// Break/reset streak (user failed to complete all habits)
    func breakStreak() {
        // Save current streak to history before breaking
        if currentStreak > 0 {
            streakHistory.append(currentStreak)
        }
        currentStreak = 0
        lastUpdated = Date()
    }
    
    /// Decrement streak (for undo scenarios)
    /// **Use case:** User completes all habits, gets reward, then uncompletes one habit
    func decrementStreak() {
        if currentStreak > 0 {
            currentStreak -= 1
        }
        
        if totalCompleteDays > 0 {
            totalCompleteDays -= 1
        }
        
        lastUpdated = Date()
    }
    
    // MARK: - Full Recalculation
    
    /// Recalculate streak from scratch using all progress records
    /// **Use case:** Migration, data repair, integrity checks
    /// **Note:** This is expensive! Only call when necessary
    func recalculateFrom(
        progressRecords: [DailyProgressModel],
        habits: [HabitModel],
        vacationManager: VacationManager = .shared
    ) {
        // Get all unique dates with progress, sorted chronologically
        let allDates = Set(progressRecords.map { $0.date }).sorted()
        
        var streak = 0
        var longest = 0
        var totalComplete = 0
        var lastComplete: Date? = nil
        
        for date in allDates {
            // Get habits scheduled for this date
            let habitsForDate = habits.filter { habit in
                habit.shouldAppear(on: date)
            }
            
            // Skip if no habits scheduled for this date
            guard !habitsForDate.isEmpty else { continue }
            
            // Get progress records for this date
            let progressForDate = progressRecords.filter { progress in
                Calendar.current.isDate(progress.date, inSameDayAs: date)
            }
            
            // Check if ALL scheduled habits are complete
            let allComplete = habitsForDate.allSatisfy { habit in
                progressForDate.contains { progress in
                    progress.habit?.id == habit.id && progress.isComplete
                }
            }
            
            // Check if vacation day
            let isVacation = vacationManager.isActive && vacationManager.isVacationDay(date)
            
            if allComplete {
                // Day is complete
                if let last = lastComplete {
                    let daysDiff = Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0
                    
                    if daysDiff == 1 {
                        // Consecutive day
                        streak += 1
                    } else if daysDiff > 1 {
                        // Gap (but check for vacation days in between)
                        let hasVacationGap = hasOnlyVacationDaysBetween(start: last, end: date, vacationManager: vacationManager)
                        
                        if hasVacationGap {
                            // Vacation days only - continue streak
                            streak += 1
                        } else {
                            // Real gap - reset streak
                            streak = 1
                        }
                    }
                } else {
                    // First complete day
                    streak = 1
                }
                
                if streak > longest {
                    longest = streak
                }
                
                totalComplete += 1
                lastComplete = date
                
            } else if !isVacation {
                // Day is incomplete and not vacation - break streak
                streak = 0
            }
            // If vacation day, skip (don't increment or break streak)
        }
        
        // ✅ HIGH-WATER MARK: Preserve longestStreak as a high-water mark that never decreases
        let storedLongestBefore = self.longestStreak
        let newlyCalculatedLongest = longest
        
        // Update all fields
        self.currentStreak = streak
        // Only update longestStreak if the newly calculated value is GREATER than the stored value
        // This ensures longestStreak never decreases, even if historical data has issues
        if newlyCalculatedLongest > storedLongestBefore {
            self.longestStreak = newlyCalculatedLongest
        }
        self.totalCompleteDays = totalComplete
        self.lastCompleteDate = lastComplete
        self.lastUpdated = Date()
    }
    
    /// Check if only vacation days exist between two dates
    private func hasOnlyVacationDaysBetween(
        start: Date,
        end: Date,
        vacationManager: VacationManager
    ) -> Bool {
        guard vacationManager.isActive else { return false }
        
        let calendar = Calendar.current
        var currentDate = calendar.date(byAdding: .day, value: 1, to: start)!
        
        while currentDate < end {
            if !vacationManager.isVacationDay(currentDate) {
                return false  // Found a non-vacation day in the gap
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return true  // All days in gap are vacation days
    }
}

// MARK: - Validation

extension GlobalStreakModel {
    /// Validate streak data
    func validate() -> [String] {
        var errors: [String] = []
        
        if currentStreak < 0 {
            errors.append("Current streak cannot be negative")
        }
        
        if longestStreak < 0 {
            errors.append("Longest streak cannot be negative")
        }
        
        if longestStreak < currentStreak {
            errors.append("Longest streak must be >= current streak")
        }
        
        if totalCompleteDays < 0 {
            errors.append("Total complete days cannot be negative")
        }
        
        if currentStreak > 0 && lastCompleteDate == nil {
            errors.append("Current streak > 0 but no last complete date")
        }
        
        return errors
    }
    
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Computed Statistics

extension GlobalStreakModel {
    /// Calculate average streak length from all streaks (completed + current)
    /// **Logic:**
    /// - Includes both completed streaks (streakHistory) and current ongoing streak
    /// - Provides a more accurate and intuitive average that includes all streak activity
    /// - Returns 0 only if no streaks exist at all
    /// **Example:** streakHistory = [5, 3, 7], currentStreak = 2 → average = (5+3+7+2)/4 = 4.25 ≈ 4 days
    /// **Example:** streakHistory = [], currentStreak = 2 → average = 2 (first streak)
    var averageStreak: Int {
        var allStreaks = streakHistory
        
        // Include current streak if it exists
        if currentStreak > 0 {
            allStreaks.append(currentStreak)
        }
        
        guard !allStreaks.isEmpty else { return 0 }
        
        // Calculate average from all streaks (completed + current)
        let total = allStreaks.reduce(0, +)
        let average = Double(total) / Double(allStreaks.count)
        return Int(average.rounded())
    }
}

