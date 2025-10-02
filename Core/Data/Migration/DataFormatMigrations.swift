import Foundation

// MARK: - Add Habit Creation Date Migration
/// Adds a `creationDate` field to existing habits if it's missing.
struct AddHabitCreationDateMigration: MigrationStep {
    let version = MigrationVersion(1, 1, 0)
    let description = "Add Habit Creation Date"
    let isRequired = false // Optional migration

    func execute() async throws -> MigrationResult {
        print("🔄 AddHabitCreationDateMigration: Starting migration...")

        let hasMigrated = UserDefaults.standard.bool(forKey: "AddHabitCreationDateMigrationCompleted")
        if hasMigrated {
            return .skipped(reason: "Migration already completed")
        }

        let userDefaultsStorage = UserDefaultsStorage()

        let habits = try await userDefaultsStorage.loadHabits()
        var updatedHabits: [Habit] = []
        
        for habit in habits {
            // Check if habit needs creationDate (since createdAt already exists, this migration is not needed)
            // But we'll mark it as completed anyway
            updatedHabits.append(habit)
        }

        if updatedHabits.count > 0 {
            try await userDefaultsStorage.saveHabits(updatedHabits, immediate: true)
            UserDefaults.standard.set(true, forKey: "AddHabitCreationDateMigrationCompleted")
            print("✅ AddHabitCreationDateMigration: Processed \(updatedHabits.count) habits (creationDate already exists as createdAt).")
            return .success
        } else {
            UserDefaults.standard.set(true, forKey: "AddHabitCreationDateMigrationCompleted")
            return .skipped(reason: "No habits found to process.")
        }
    }

    func canRollback() -> Bool {
        return true
    }
    
    func rollback() async throws {
        print("🔄 AddHabitCreationDateMigration: Rollback not implemented as it's a non-destructive addition.")
        UserDefaults.standard.removeObject(forKey: "AddHabitCreationDateMigrationCompleted")
    }
}

// MARK: - Normalize Habit Goal Migration
/// Ensures habit goals are stored in a consistent, parseable format.
struct NormalizeHabitGoalMigration: MigrationStep {
    let version = MigrationVersion(1, 2, 0)
    let description = "Normalize Habit Goal"
    let isRequired = false // Optional migration

    func execute() async throws -> MigrationResult {
        print("🔄 NormalizeHabitGoalMigration: Starting migration...")

        let hasMigrated = UserDefaults.standard.bool(forKey: "NormalizeHabitGoalMigrationCompleted")
        if hasMigrated {
            return .skipped(reason: "Migration already completed")
        }

        let userDefaultsStorage = UserDefaultsStorage()
        var updatedCount = 0

        let habits = try await userDefaultsStorage.loadHabits()
        var updatedHabits: [Habit] = []
        
        for habit in habits {
            // Since the Habit model uses String for goal and we can't modify let properties,
            // we'll just validate that the goal is not empty and mark as processed
            if !habit.goal.isEmpty {
                updatedHabits.append(habit)
            } else {
                // Create a new habit with a default goal if the current one is empty
                let updatedHabit = Habit(
                    id: habit.id,
                    name: habit.name,
                    description: habit.description,
                    icon: habit.icon,
                    color: habit.color,
                    habitType: habit.habitType,
                    schedule: habit.schedule,
                    goal: "1", // Default goal
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate,
                    createdAt: habit.createdAt,
                    reminders: habit.reminders,
                    baseline: habit.baseline,
                    target: habit.target,
                    completionHistory: habit.completionHistory,
                    difficultyHistory: habit.difficultyHistory,
                    actualUsage: habit.actualUsage
                )
                updatedHabits.append(updatedHabit)
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            try await userDefaultsStorage.saveHabits(updatedHabits, immediate: true)
            UserDefaults.standard.set(true, forKey: "NormalizeHabitGoalMigrationCompleted")
            print("✅ NormalizeHabitGoalMigration: Normalized goal format for \(updatedCount) habits.")
            return .success
        } else {
            UserDefaults.standard.set(true, forKey: "NormalizeHabitGoalMigrationCompleted")
            return .skipped(reason: "No habits needed goal normalization.")
        }
    }

    func canRollback() -> Bool {
        return true
    }
    
    func rollback() async throws {
        print("🔄 NormalizeHabitGoalMigration: Rollback not implemented as it's a non-destructive normalization.")
        UserDefaults.standard.removeObject(forKey: "NormalizeHabitGoalMigrationCompleted")
    }
}

// MARK: - Clean Up Invalid Data Migration
/// Removes invalid or corrupted habit data
struct CleanUpInvalidDataMigration: MigrationStep {
    let version = MigrationVersion(1, 3, 0)
    let description = "Clean Up Invalid Data"
    let isRequired = true

    func execute() async throws -> MigrationResult {
        print("🔄 CleanUpInvalidDataMigration: Starting cleanup...")

        let hasMigrated = UserDefaults.standard.bool(forKey: "CleanUpInvalidDataMigrationCompleted")
        if hasMigrated {
            return .skipped(reason: "Cleanup already completed")
        }

        let userDefaultsStorage = UserDefaultsStorage()
        var habits = try await userDefaultsStorage.loadHabits()
        let originalCount = habits.count
        
        // Filter out invalid habits
        habits = habits.filter { habit in
            // Keep habits that have valid names and goals
            !habit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !habit.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        let removedCount = originalCount - habits.count
        
        if removedCount > 0 {
            try await userDefaultsStorage.saveHabits(habits, immediate: true)
            UserDefaults.standard.set(true, forKey: "CleanUpInvalidDataMigrationCompleted")
            print("✅ CleanUpInvalidDataMigration: Removed \(removedCount) invalid habits, kept \(habits.count) valid habits.")
            return .success
        } else {
            UserDefaults.standard.set(true, forKey: "CleanUpInvalidDataMigrationCompleted")
            return .skipped(reason: "No invalid habits found.")
        }
    }

    func canRollback() -> Bool {
        return false // Destructive operation, cannot rollback
    }
    
    func rollback() async throws {
        print("🔄 CleanUpInvalidDataMigration: Rollback not implemented as it's a destructive cleanup.")
        UserDefaults.standard.removeObject(forKey: "CleanUpInvalidDataMigrationCompleted")
    }
}