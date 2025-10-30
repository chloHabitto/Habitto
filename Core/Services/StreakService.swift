import Foundation
import SwiftData

/// Service for managing global habit streak
/// **Responsibilities:**
/// - Track single global streak across ALL habits
/// - Increment only when ALL scheduled habits complete
/// - Handle vacation days (pause streak, don't break)
/// - Recalculate streak from historical data
@MainActor
class StreakService {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let progressService: ProgressService
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, progressService: ProgressService) {
        self.modelContext = modelContext
        self.progressService = progressService
        print("✅ StreakService: Initialized")
    }
    
    // MARK: - Streak Queries
    
    /// Get or create global streak for a user
    /// **Returns:** GlobalStreakModel for the user
    func getOrCreateStreak(for userId: String) throws -> GlobalStreakModel {
        // Try to find existing streak
        let descriptor = FetchDescriptor<GlobalStreakModel>(
            predicate: #Predicate { streak in
                streak.userId == userId
            }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            print("🔥 StreakService: Found existing streak for user '\(userId)'")
            return existing
        }
        
        // Create new streak
        let streak = GlobalStreakModel(userId: userId)
        modelContext.insert(streak)
        try modelContext.save()
        
        print("✨ StreakService: Created new streak for user '\(userId)'")
        return streak
    }
    
    // MARK: - Completion Checking
    
    /// Check if all scheduled habits are complete for a date
    /// **Logic:**
    /// - Only counts habits that should appear on this date
    /// - ALL must be complete for day to be "complete"
    /// - Empty list = false (no habits scheduled)
    func areAllHabitsComplete(
        on date: Date,
        habits: [HabitModel]
    ) throws -> Bool {
        let normalizedDate = DateUtils.startOfDay(for: date)
        
        // Filter to habits scheduled for this date
        let scheduledHabits = habits.filter { habit in
            habit.schedule.shouldAppear(on: normalizedDate, habitStartDate: habit.startDate)
        }
        
        guard !scheduledHabits.isEmpty else {
            print("ℹ️ StreakService: No habits scheduled on \(DateUtils.dateKey(for: normalizedDate))")
            return false
        }
        
        // Check if each scheduled habit is complete
        for habit in scheduledHabits {
            let isComplete = try progressService.isComplete(habit: habit, on: normalizedDate)
            if !isComplete {
                print("⏸️ StreakService: '\(habit.name)' incomplete on \(DateUtils.dateKey(for: normalizedDate))")
                return false
            }
        }
        
        print("✅ StreakService: All \(scheduledHabits.count) habits complete on \(DateUtils.dateKey(for: normalizedDate))")
        return true
    }
    
    /// Check if a date is a vacation day
    /// **Note:** For now, returns false. Vacation logic will be added later.
    private func isVacationDay(_ date: Date) -> Bool {
        // TODO: Implement vacation day checking from UserDefaults or database
        return false
    }
    
    // MARK: - Streak Updates
    
    /// Update streak after a progress change
    /// **Call this after:**
    /// - Incrementing progress (habit becomes complete)
    /// - Decrementing progress (day becomes incomplete)
    func updateStreakIfNeeded(
        on date: Date,
        habits: [HabitModel],
        userId: String
    ) throws {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        let streak = try getOrCreateStreak(for: userId)
        let allComplete = try areAllHabitsComplete(on: normalizedDate, habits: habits)
        
        // Check if this is the most recent date
        let today = DateUtils.startOfDay(for: Date())
        let isToday = normalizedDate == today
        let isPast = normalizedDate < today
        
        if allComplete {
            // Day is complete
            if isToday {
                // Today just became complete - increment streak
                let oldStreak = streak.currentStreak
                streak.incrementStreak(on: normalizedDate)
                let newStreak = streak.currentStreak
                
                try modelContext.save()
                print("🔥 StreakService: Streak incremented \(oldStreak) → \(newStreak) on \(dateKey)")
            } else if isPast {
                // Past day became complete - recalculate entire streak
                print("🔄 StreakService: Past day (\(dateKey)) completed - recalculating streak")
                try recalculateStreak(for: userId, habits: habits)
            }
        } else {
            // Day is incomplete
            if isToday {
                // Today became incomplete - may break streak
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
                let yesterdayComplete = try areAllHabitsComplete(on: yesterday, habits: habits)
                
                if yesterdayComplete && streak.currentStreak > 0 {
                    // We had a streak going, but today broke it
                    let oldStreak = streak.currentStreak
                    streak.breakStreak()
                    try modelContext.save()
                    print("💔 StreakService: Streak broken \(oldStreak) → 0 (today incomplete)")
                }
            } else if isPast {
                // Past day became incomplete - recalculate entire streak
                print("🔄 StreakService: Past day (\(dateKey)) became incomplete - recalculating streak")
                try recalculateStreak(for: userId, habits: habits)
            }
        }
    }
    
    // MARK: - Recalculation
    
    /// Recalculate streak from scratch based on historical data
    /// **Use cases:**
    /// - After migration
    /// - When past data changes
    /// - When streak seems incorrect
    func recalculateStreak(
        for userId: String,
        habits: [HabitModel]
    ) throws {
        print("🔄 StreakService: Starting full streak recalculation for user '\(userId)'")
        
        let streak = try getOrCreateStreak(for: userId)
        
        // Find date range to check
        let today = DateUtils.startOfDay(for: Date())
        
        // Get earliest habit start date
        guard let earliestStart = habits.map({ $0.startDate }).min() else {
            print("ℹ️ StreakService: No habits found - resetting streak to 0")
            streak.currentStreak = 0
            streak.lastCompleteDate = nil
            try modelContext.save()
            return
        }
        
        let startDate = DateUtils.startOfDay(for: earliestStart)
        
        // Walk through each day from earliest start to today
        var currentStreakCount = 0
        var longestStreakCount = 0
        var totalCompleteDays = 0
        var lastCompleteDate: Date? = nil
        
        var checkDate = startDate
        while checkDate <= today {
            let isVacation = isVacationDay(checkDate)
            
            if isVacation {
                // Vacation day: don't break streak, don't increment
                print("🏖️ StreakService: Vacation day on \(DateUtils.dateKey(for: checkDate))")
            } else {
                let isComplete = try areAllHabitsComplete(on: checkDate, habits: habits)
                
                if isComplete {
                    // Day complete: increment streak
                    currentStreakCount += 1
                    totalCompleteDays += 1
                    lastCompleteDate = checkDate
                    
                    if currentStreakCount > longestStreakCount {
                        longestStreakCount = currentStreakCount
                    }
                } else {
                    // ✅ CRITICAL FIX: Day incomplete - break streak only if it's BEFORE today
                    // Today's incomplete state should NOT break the streak until the day is over
                    if checkDate < today {
                        currentStreakCount = 0
                    }
                }
            }
            
            checkDate = Calendar.current.date(byAdding: .day, value: 1, to: checkDate)!
        }
        
        // Update streak model
        streak.currentStreak = currentStreakCount
        streak.longestStreak = max(streak.longestStreak, longestStreakCount)
        streak.totalCompleteDays = totalCompleteDays
        streak.lastCompleteDate = lastCompleteDate
        streak.lastUpdated = Date()
        
        try modelContext.save()
        
        print("✅ StreakService: Recalculation complete")
        print("   Current: \(currentStreakCount) days")
        print("   Longest: \(longestStreakCount) days")
        print("   Total: \(totalCompleteDays) days")
    }
    
    // MARK: - Manual Adjustments
    
    /// Manually break the streak (for testing or user request)
    func breakStreak(for userId: String) throws {
        let streak = try getOrCreateStreak(for: userId)
        let oldStreak = streak.currentStreak
        
        streak.breakStreak()
        try modelContext.save()
        
        print("💔 StreakService: Manually broke streak \(oldStreak) → 0")
    }
    
    /// Manually increment streak (for testing or data correction)
    func incrementStreak(for userId: String, on date: Date) throws {
        let streak = try getOrCreateStreak(for: userId)
        let oldStreak = streak.currentStreak
        
        streak.incrementStreak(on: date)
        try modelContext.save()
        
        print("🔥 StreakService: Manually incremented streak \(oldStreak) → \(streak.currentStreak)")
    }
    
    // MARK: - Analytics
    
    /// Get streak statistics for display
    func getStreakStats(for userId: String) throws -> StreakStats {
        let streak = try getOrCreateStreak(for: userId)
        
        return StreakStats(
            currentStreak: streak.currentStreak,
            longestStreak: streak.longestStreak,
            totalCompleteDays: streak.totalCompleteDays,
            lastCompleteDate: streak.lastCompleteDate,
            isOnStreak: streak.currentStreak > 0
        )
    }
    
    /// Check if user maintained their streak today
    func didMaintainStreakToday(
        for userId: String,
        habits: [HabitModel]
    ) throws -> Bool {
        let today = DateUtils.startOfDay(for: Date())
        return try areAllHabitsComplete(on: today, habits: habits)
    }
}

// MARK: - Result Types

/// Streak statistics for display
struct StreakStats {
    let currentStreak: Int
    let longestStreak: Int
    let totalCompleteDays: Int
    let lastCompleteDate: Date?
    let isOnStreak: Bool
    
    var description: String {
        if isOnStreak {
            return "🔥 \(currentStreak) day streak! (Best: \(longestStreak))"
        } else {
            return "Best streak: \(longestStreak) days"
        }
    }
}

// MARK: - Errors

enum StreakError: LocalizedError {
    case userNotFound
    case noHabitsScheduled
    case invalidDate
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .noHabitsScheduled:
            return "No habits scheduled for this date"
        case .invalidDate:
            return "Invalid date provided"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
