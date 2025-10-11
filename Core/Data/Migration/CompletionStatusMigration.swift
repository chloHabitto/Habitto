import Foundation

/// Migration service to convert completion history from count-based to boolean-based system
/// This fixes the issue where changing habit goals affects past completion status
class CompletionStatusMigration {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = CompletionStatusMigration()

  /// Checks if migration is needed and performs it if necessary
  func performMigrationIfNeeded() async {
    guard !isMigrationCompleted() else {
      print("🔄 MIGRATION: Completion status migration already completed")
      return
    }

    print("🔄 MIGRATION: Starting completion status migration...")

    // Load existing habits
    let habits = Habit.loadHabits()
    print("🔄 MIGRATION: Found \(habits.count) habits to migrate")

    var migratedHabits: [Habit] = []

    for var habit in habits {
      // Only migrate if the habit has completion history but no completion status
      if !habit.completionHistory.isEmpty, habit.completionStatus.isEmpty {
        print("🔄 MIGRATION: Migrating habit '\(habit.name)'")
        habit.migrateCompletionHistory()
      }
      migratedHabits.append(habit)
    }

    // Save migrated habits
    Habit.saveHabits(migratedHabits, immediate: true)

    // Mark migration as completed
    markMigrationCompleted()

    print("🔄 MIGRATION: Completion status migration completed successfully")
  }

  /// Resets migration status (for testing purposes)
  func resetMigrationStatus() {
    userDefaults.removeObject(forKey: migrationKey)
    userDefaults.synchronize()
    print("🔄 MIGRATION: Migration status reset")
  }

  // MARK: Private

  private let migrationKey = "completion_status_migration_completed"
  private let userDefaults = UserDefaults.standard

  /// Checks if the migration has already been completed
  private func isMigrationCompleted() -> Bool {
    userDefaults.bool(forKey: migrationKey)
  }

  /// Marks the migration as completed
  private func markMigrationCompleted() {
    userDefaults.set(true, forKey: migrationKey)
    userDefaults.synchronize()
  }
}
