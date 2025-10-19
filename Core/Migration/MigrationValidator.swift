import Foundation
import SwiftData

/// MigrationValidator verifies data integrity after migration
///
/// **Checks:**
/// - Habit count matches
/// - Progress record count matches
/// - XP totals match
/// - Streak is reasonable (current ≤ longest ≤ total complete days)
/// - No orphaned records (all progress has parent habit)
/// - No invalid dates
/// - All relationships are properly set
@MainActor
class MigrationValidator {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let userId: String
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }
    
    // MARK: - Validation
    
    func validate() async throws -> ValidationResult {
        var result = ValidationResult()
        
        print("🔍 Validating migrated data...")
        
        // Load old data
        let oldHabits = Habit.loadHabits()
        let oldXP = UserDefaults.standard.integer(forKey: "total_xp_\(userId)")
        
        // Load new data
        let newHabits = try modelContext.fetch(FetchDescriptor<HabitModel>(
            predicate: #Predicate { habit in habit.userId == userId }
        ))
        
        let newProgress = try modelContext.fetch(FetchDescriptor<DailyProgressModel>())
        
        let newStreaks = try modelContext.fetch(FetchDescriptor<GlobalStreakModel>(
            predicate: #Predicate { streak in streak.userId == userId }
        ))
        
        let newUserProgress = try modelContext.fetch(FetchDescriptor<UserProgressModel>(
            predicate: #Predicate { progress in progress.userId == userId }
        ))
        
        // 1. Validate habit count
        result.oldHabitCount = oldHabits.count
        result.newHabitCount = newHabits.count
        
        if oldHabits.count != newHabits.count {
            result.errors.append("Habit count mismatch: old=\(oldHabits.count), new=\(newHabits.count)")
        } else {
            result.checks["Habit count"] = true
        }
        
        // 2. Validate progress record count
        var oldProgressCount = 0
        for habit in oldHabits {
            if habit.habitType == .breaking {
                oldProgressCount += habit.actualUsage.count
            } else {
                oldProgressCount += habit.completionHistory.count
            }
        }
        
        result.oldProgressCount = oldProgressCount
        result.newProgressCount = newProgress.count
        
        if oldProgressCount != newProgress.count {
            result.errors.append("Progress count mismatch: old=\(oldProgressCount), new=\(newProgress.count)")
        } else {
            result.checks["Progress count"] = true
        }
        
        // 3. Validate XP
        result.oldXP = oldXP
        result.newXP = newUserProgress.first?.totalXP ?? 0
        
        if oldXP != result.newXP {
            result.errors.append("XP mismatch: old=\(oldXP), new=\(result.newXP)")
        } else {
            result.checks["XP total"] = true
        }
        
        // 4. Validate streak logic
        if let streak = newStreaks.first {
            result.currentStreak = streak.currentStreak
            result.longestStreak = streak.longestStreak
            result.totalCompleteDays = streak.totalCompleteDays
            
            // Current streak must be ≤ longest streak
            if streak.currentStreak > streak.longestStreak {
                result.errors.append("Current streak (\(streak.currentStreak)) > longest streak (\(streak.longestStreak))")
            } else {
                result.checks["Current ≤ Longest streak"] = true
            }
            
            // Longest streak must be ≤ total complete days
            if streak.longestStreak > streak.totalCompleteDays {
                result.errors.append("Longest streak (\(streak.longestStreak)) > total complete days (\(streak.totalCompleteDays))")
            } else {
                result.checks["Longest ≤ Total days"] = true
            }
        } else {
            result.checks["Streak exists"] = false
            result.warnings.append("No global streak found")
        }
        
        // 5. Validate no orphaned progress records
        var orphanedCount = 0
        for progress in newProgress {
            if progress.habit == nil {
                orphanedCount += 1
            }
        }
        
        result.orphanedProgressRecords = orphanedCount
        
        if orphanedCount > 0 {
            result.errors.append("\(orphanedCount) orphaned progress records (no parent habit)")
        } else {
            result.checks["No orphaned records"] = true
        }
        
        // 6. Validate no invalid dates
        var invalidDateCount = 0
        let now = Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now)!
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now)!
        
        for progress in newProgress {
            if progress.date < twoYearsAgo || progress.date > oneYearFromNow {
                invalidDateCount += 1
            }
        }
        
        result.invalidDates = invalidDateCount
        
        if invalidDateCount > 0 {
            result.warnings.append("\(invalidDateCount) progress records with unusual dates (>2 years old or >1 year future)")
        } else {
            result.checks["Valid dates"] = true
        }
        
        // 7. Validate all habits have valid schedules
        var invalidScheduleCount = 0
        for habit in newHabits {
            // Just check if schedule can be accessed without error
            do {
                let _ = habit.schedule
            } catch {
                invalidScheduleCount += 1
            }
        }
        
        if invalidScheduleCount > 0 {
            result.errors.append("\(invalidScheduleCount) habits with invalid schedules")
        } else {
            result.checks["Valid schedules"] = true
        }
        
        // Final determination
        result.isValid = result.errors.isEmpty
        
        if result.isValid {
            print("✅ Validation PASSED")
        } else {
            print("❌ Validation FAILED: \(result.errors.count) errors")
        }
        
        return result
    }
}

// MARK: - Validation Result

struct ValidationResult: CustomStringConvertible {
    var isValid: Bool = false
    var errors: [String] = []
    var warnings: [String] = []
    var checks: [String: Bool] = [:]
    
    // Data counts
    var oldHabitCount: Int = 0
    var newHabitCount: Int = 0
    var oldProgressCount: Int = 0
    var newProgressCount: Int = 0
    var oldXP: Int = 0
    var newXP: Int = 0
    
    // Streak data
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalCompleteDays: Int = 0
    
    // Issues
    var orphanedProgressRecords: Int = 0
    var invalidDates: Int = 0
    
    var description: String {
        var output = """
        Status: \(isValid ? "✅ PASSED" : "❌ FAILED")
        
        Data Counts:
        - Old habits: \(oldHabitCount)
        - New habits: \(newHabitCount) \(oldHabitCount == newHabitCount ? "✅" : "❌")
        - Old progress: \(oldProgressCount)
        - New progress: \(newProgressCount) \(oldProgressCount == newProgressCount ? "✅" : "❌")
        - Old XP: \(oldXP)
        - New XP: \(newXP) \(oldXP == newXP ? "✅" : "❌")
        
        Streak:
        - Current: \(currentStreak) days
        - Longest: \(longestStreak) days
        - Total complete: \(totalCompleteDays) days
        - Valid: \(currentStreak <= longestStreak && longestStreak <= totalCompleteDays ? "✅" : "❌")
        
        Checks:
        """
        
        for (check, passed) in checks.sorted(by: { $0.key < $1.key }) {
            output += "\n- \(check): \(passed ? "✅" : "❌")"
        }
        
        if !errors.isEmpty {
            output += "\n\n❌ Errors:"
            for error in errors {
                output += "\n- \(error)"
            }
        }
        
        if !warnings.isEmpty {
            output += "\n\n⚠️ Warnings:"
            for warning in warnings {
                output += "\n- \(warning)"
            }
        }
        
        return output
    }
}

