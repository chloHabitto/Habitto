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
        let schedule = HabitSchedule.fromLegacyString(oldHabit.schedule)
        
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
            habitDescription: oldHabit.description,
            icon: oldHabit.icon,
            color: oldHabit.color.color, // Extract Color from CodableColor
            habitType: habitType,
            goalCount: goalCount,
            goalUnit: goalUnit,
            schedule: schedule,
            baselineCount: baselineCount,
            baselineUnit: baselineUnit,
            startDate: oldHabit.startDate,
            endDate: oldHabit.endDate
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
                guard let date = DateUtils.date(from: dateString) else {
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
                guard let date = DateUtils.date(from: dateString) else {
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
    
    /// Parse goal string like "5 times", "30 minutes", "6 times per day"
    /// - Returns: (count, unit)
    ///
    /// **Examples:**
    /// - "5 times" → (5, "times")
    /// - "30 minutes" → (30, "minutes")
    /// - "10000 steps" → (10000, "steps")
    /// - "6 times per day" → (6, "times per day")
    /// - "5" → (5, "time")
    private func parseGoal(_ goalString: String) -> (Int, String) {
        let trimmed = goalString.trimmingCharacters(in: .whitespaces)
        
        // Extract the first number from the string
        let scanner = Scanner(string: trimmed)
        var count: Int = 0
        
        // Try to scan an integer
        if scanner.scanInt(&count), count > 0 {
            // Extract the rest as the unit
            let remainingString = String(trimmed.dropFirst(scanner.currentIndex.utf16Offset(in: trimmed)))
            let unit = remainingString.trimmingCharacters(in: .whitespaces)
            
            // If no unit, default to "time" or "times"
            if unit.isEmpty {
                return (count, count == 1 ? "time" : "times")
            }
            
            return (count, unit)
        }
        
        // If parsing fails, log warning and return default
        print("⚠️ Could not parse goal: '\(goalString)' - defaulting to (1, 'time')")
        return (1, "time")
    }
    
    /// Get human-readable schedule type for reporting
    private func getScheduleType(_ schedule: HabitSchedule) -> String {
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
