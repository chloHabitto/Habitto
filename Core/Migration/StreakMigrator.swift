import Foundation
import SwiftData

/// StreakMigrator calculates GlobalStreakModel from progress history
///
/// **Algorithm:**
/// 1. Get all habits for the user
/// 2. Get all progress records sorted by date
/// 3. For each date, check if ALL scheduled habits were completed
/// 4. Calculate current streak (consecutive complete days until today)
/// 5. Calculate longest streak (max consecutive complete days)
/// 6. Handle vacation days (don't break streak, don't increment)
@MainActor
class StreakMigrator {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let userId: String
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }
    
    // MARK: - Migration
    
    struct StreakMigrationResult {
        var streakCreated: Bool = false
        var currentStreak: Int = 0
        var longestStreak: Int = 0
        var totalCompleteDays: Int = 0
    }
    
    func migrate(dryRun: Bool) async throws -> StreakMigrationResult {
        var result = StreakMigrationResult()
        
        // Get all habits
        let habits = try modelContext.fetch(FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in habit.userId == userId }
        ))
        
        guard !habits.isEmpty else {
            print("⚠️ No habits found - skipping streak calculation")
            return result
        }
        
        print("🔥 Calculating global streak from \(habits.count) habits...")
        
        // Recalculate streak from scratch
        let streakData = try calculateStreakFromHistory(habits: habits)
        
        // Create GlobalStreakModel
        let globalStreak = GlobalStreakModel(
            userId: userId,
            currentStreak: streakData.currentStreak,
            longestStreak: streakData.longestStreak,
            totalCompleteDays: streakData.totalCompleteDays,
            lastCompleteDate: streakData.lastCompleteDate
        )
        
        if !dryRun {
            modelContext.insert(globalStreak)
        }
        
        result.streakCreated = true
        result.currentStreak = streakData.currentStreak
        result.longestStreak = streakData.longestStreak
        result.totalCompleteDays = streakData.totalCompleteDays
        
        print("✅ Streak calculated: Current=\(result.currentStreak), Longest=\(result.longestStreak), Total=\(result.totalCompleteDays)")
        
        return result
    }
    
    // MARK: - Streak Calculation
    
    private struct StreakData {
        var currentStreak: Int = 0
        var longestStreak: Int = 0
        var totalCompleteDays: Int = 0
        var lastCompleteDate: Date?
    }
    
    /// Recalculate streak from complete history
    private func calculateStreakFromHistory(habits: [HabitModel]) throws -> StreakData {
        var streakData = StreakData()
        
        // Get all progress records
        var allProgress: [DailyProgressModel] = []
        for habit in habits {
            let habitProgress = try modelContext.fetch(FetchDescriptor<DailyProgressModel>(
                predicate: #Predicate { progress in progress.habit?.id == habit.id }
            ))
            allProgress.append(contentsOf: habitProgress)
        }
        
        // Group by date
        let progressByDate = Dictionary(grouping: allProgress) { progress in
            DateUtils.startOfDay(progress.date)
        }
        
        // Get date range (oldest to today)
        guard let oldestProgress = allProgress.min(by: { $0.date < $1.date }) else {
            return streakData // No progress yet
        }
        
        let startDate = DateUtils.startOfDay(oldestProgress.date)
        let today = DateUtils.startOfDay(Date())
        
        // Check each day from oldest to today
        var currentStreakCount = 0
        var tempStreakCount = 0
        var longestStreakCount = 0
        var totalCompleteDays = 0
        var lastCompleteDateFound: Date?
        
        var date = startDate
        while date <= today {
            // Check if this date is a vacation day
            if isVacationDay(date) {
                // Vacation days don't break streak, but don't increment either
                date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
                continue
            }
            
            // Get habits scheduled for this date
            let scheduledHabits = habits.filter { habit in
                habit.schedule.shouldAppear(on: date, habitStartDate: habit.startDate)
            }
            
            // Skip if no habits scheduled
            if scheduledHabits.isEmpty {
                date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
                continue
            }
            
            // Check if ALL scheduled habits were completed
            let allCompleted = scheduledHabits.allSatisfy { habit in
                guard let progress = progressByDate[date]?.first(where: { $0.habit?.id == habit.id }) else {
                    return false
                }
                return progress.isComplete
            }
            
            if allCompleted {
                // Day is complete
                tempStreakCount += 1
                totalCompleteDays += 1
                lastCompleteDateFound = date
                
                // Update longest streak
                if tempStreakCount > longestStreakCount {
                    longestStreakCount = tempStreakCount
                }
                
                // If this is today or yesterday, update current streak
                if date == today || date == Calendar.current.date(byAdding: .day, value: -1, to: today)! {
                    currentStreakCount = tempStreakCount
                }
            } else {
                // Day is incomplete - streak breaks
                tempStreakCount = 0
                
                // If this is today or yesterday, current streak is broken
                if date >= Calendar.current.date(byAdding: .day, value: -1, to: today)! {
                    currentStreakCount = 0
                }
            }
            
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
        
        streakData.currentStreak = currentStreakCount
        streakData.longestStreak = longestStreakCount
        streakData.totalCompleteDays = totalCompleteDays
        streakData.lastCompleteDate = lastCompleteDateFound
        
        return streakData
    }
    
    // MARK: - Vacation Days
    
    /// Check if date is a vacation day
    /// Vacation days are stored in UserDefaults as an array of date strings
    private func isVacationDay(_ date: Date) -> Bool {
        let vacationDates = UserDefaults.standard.stringArray(forKey: "vacation_dates_\(userId)") ?? []
        let dateString = DateUtils.formatDate(date)
        return vacationDates.contains(dateString)
    }
}

// MARK: - DateUtils Extension

private extension DateUtils {
    /// Format date as "yyyy-MM-dd"
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

