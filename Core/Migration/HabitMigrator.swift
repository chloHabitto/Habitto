import Foundation
import SwiftData

/// HabitMigrator converts old Habit structs to new HabitModel + DailyProgressModel
///
/// **Handles:**
/// - Formation habits (habit building)
/// - Breaking habits (habit breaking)
/// - Goal string parsing ("5 times", "30 minutes")
/// - Schedule string parsing ("Everyday", "3 days a week", "Monday, Wednesday")
/// - CompletionHistory → DailyProgressModel conversion
/// - ActualUsage → DailyProgressModel conversion (breaking habits)
@MainActor
class HabitMigrator {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let userId: String
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }
    
    // MARK: - Migration
    
    struct HabitMigrationResult {
        var habitsCreated: Int = 0
        var progressRecordsCreated: Int = 0
        var scheduleParsing: [String: Int] = [:] // Type → count
    }
    
    func migrate(dryRun: Bool) async throws -> HabitMigrationResult {
        var result = HabitMigrationResult()
        
        // Load old habits
        let oldHabits = Habit.loadHabits()
        print("📦 Found \(oldHabits.count) old habits to migrate")
        
        for oldHabit in oldHabits {
            do {
                // Convert habit
                let newHabit = try convertHabit(oldHabit)
                
                if !dryRun {
                    modelContext.insert(newHabit)
                }
                
                result.habitsCreated += 1
                
                // Track schedule parsing
                let scheduleType = getScheduleType(newHabit.schedule)
                result.scheduleParsing[scheduleType, default: 0] += 1
                
                // Convert progress history
                let progressRecords = try convertProgressHistory(
                    oldHabit: oldHabit,
                    newHabit: newHabit
                )
                
                if !dryRun {
                    for progress in progressRecords {
                        modelContext.insert(progress)
                    }
                }
                
                result.progressRecordsCreated += progressRecords.count
                
                print("✅ Migrated: \(oldHabit.name) (\(progressRecords.count) progress records)")
                
            } catch {
                print("⚠️ Failed to migrate habit '\(oldHabit.name)': \(error)")
                // Continue with other habits
            }
        }
        
        return result
    }
    
    // MARK: - Habit Conversion
    
    private func convertHabit(_ oldHabit: Habit) throws -> HabitModel {
        // Parse habit type (old Habit uses HabitType enum)
        let habitType: HabitType = oldHabit.habitType == .breaking ? .breaking : .formation
        
        // Parse goal
        let (goalCount, goalUnit) = parseGoal(oldHabit.goal)
        
        // Parse schedule
        let schedule = Schedule.fromLegacyString(oldHabit.schedule)
        
        // Parse baseline (for breaking habits)
        // Old Habit stores baseline as Int, we need to convert to string unit
        let baselineCount = oldHabit.baseline
        let baselineUnit = goalUnit // Use same unit as goal
        
        // Create new habit
        // Note: oldHabit.color is CodableColor, need to access .color property
        let newHabit = HabitModel(
            id: oldHabit.id,
            userId: userId,
            name: oldHabit.name,
            description: oldHabit.description,
            icon: oldHabit.icon,
            color: oldHabit.color.color, // Extract Color from CodableColor
            habitType: habitType,
            goalCount: goalCount,
            goalUnit: goalUnit,
            schedule: schedule,
            baselineCount: baselineCount,
            baselineUnit: baselineUnit,
            startDate: oldHabit.startDate,
            endDate: oldHabit.endDate,
            createdAt: oldHabit.createdAt, // Fixed: createdAt not createdDate
            updatedAt: Date()
        )
        
        return newHabit
    }
    
    // MARK: - Progress History Conversion
    
    private func convertProgressHistory(
        oldHabit: Habit,
        newHabit: HabitModel
    ) throws -> [DailyProgressModel] {
        var progressRecords: [DailyProgressModel] = []
        
        if oldHabit.habitType == .breaking {
            // Breaking habits use actualUsage
            for (dateString, usageCount) in oldHabit.actualUsage {
                guard let date = DateUtils.parseDate(dateString) else {
                    print("⚠️ Invalid date string: \(dateString)")
                    continue
                }
                
                let progress = DailyProgressModel(
                    date: date,
                    habit: newHabit,
                    progressCount: usageCount,
                    goalCount: newHabit.goalCount
                )
                
                progressRecords.append(progress)
            }
        } else {
            // Formation habits use completionHistory
            for (dateString, completionCount) in oldHabit.completionHistory {
                guard let date = DateUtils.parseDate(dateString) else {
                    print("⚠️ Invalid date string: \(dateString)")
                    continue
                }
                
                let progress = DailyProgressModel(
                    date: date,
                    habit: newHabit,
                    progressCount: completionCount,
                    goalCount: newHabit.goalCount
                )
                
                progressRecords.append(progress)
            }
        }
        
        return progressRecords
    }
    
    // MARK: - Parsing Helpers
    
    /// Parse goal string like "5 times", "30 minutes", "1 time"
    /// - Returns: (count, unit)
    private func parseGoal(_ goalString: String) -> (Int, String) {
        let trimmed = goalString.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Try to extract number and unit
        let components = trimmed.components(separatedBy: " ")
        
        guard components.count >= 2 else {
            print("⚠️ Invalid goal format: '\(goalString)' - defaulting to (1, 'time')")
            return (1, "time")
        }
        
        // First component should be the number
        guard let count = Int(components[0]) else {
            print("⚠️ Invalid goal count: '\(goalString)' - defaulting to (1, 'time')")
            return (1, "time")
        }
        
        // Rest is the unit
        let unit = components.dropFirst().joined(separator: " ")
        
        return (count, unit)
    }
    
    /// Get human-readable schedule type for reporting
    private func getScheduleType(_ schedule: Schedule) -> String {
        switch schedule {
        case .daily:
            return "Daily"
        case .everyNDays(let n):
            return "Every \(n) days"
        case .specificWeekdays(let weekdays):
            return "Specific weekdays (\(weekdays.count) days)"
        case .frequencyWeekly(let count):
            return "\(count) days a week"
        case .frequencyMonthly(let count):
            return "\(count) days a month"
        }
    }
}

// MARK: - Date Parsing Extension

private extension DateUtils {
    /// Parse date string from old format
    /// Old format uses "yyyy-MM-dd" as keys
    static func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
}

