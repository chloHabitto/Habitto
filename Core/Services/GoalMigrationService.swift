import Foundation

/// Service for migrating legacy habit goals to Firestore goal versioning
///
/// This service handles the one-time migration from the legacy single-goal String field
/// to Firestore's date-effective goal versioning system.
///
/// Migration preserves historical accuracy by creating goal versions effective from
/// each habit's creation date.
@MainActor
class GoalMigrationService {
    // MARK: - Dependencies
    
    private let goalService: GoalVersioningService
    private let dateFormatter: LocalDateFormatter
    
    // Migration state tracking
    private let migrationKey = "GoalVersioning_MigrationComplete_v1"
    
    // MARK: - Initialization
    
    init(
        goalService: GoalVersioningService? = nil,
        dateFormatter: LocalDateFormatter? = nil
    ) {
        self.goalService = goalService ?? .shared
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
    }
    
    // MARK: - Migration Status
    
    /// Check if goal migration has already been completed
    var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    /// Mark migration as complete
    func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ GoalMigrationService: Migration marked as complete")
    }
    
    /// Reset migration flag (for testing)
    func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 GoalMigrationService: Migration flag reset")
    }
    
    // MARK: - Migration Methods
    
    /// Parse legacy goal string to extract numeric value
    ///
    /// Supports formats:
    /// - "1 time" → 1
    /// - "3 times" → 3
    /// - "5 times per day" → 5
    /// - "2 times per week" → 2
    ///
    /// - Parameter goalString: The legacy goal string
    /// - Returns: Parsed goal value, or 1 if parsing fails
    func parseLegacyGoalString(_ goalString: String) -> Int {
        // Extract first number from goal string
        let components = goalString.components(separatedBy: " ")
        
        for component in components {
            if let number = Int(component) {
                return max(0, number)  // Ensure non-negative
            }
        }
        
        // Default to 1 if no number found
        return 1
    }
    
    /// Migrate a single habit's goal
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - legacyGoalString: The legacy goal string (e.g., "3 times")
    ///   - createdAt: When the habit was created
    ///
    /// - Returns: The migrated goal value
    @discardableResult
    func migrateHabitGoal(
        habitId: String,
        legacyGoalString: String,
        createdAt: Date
    ) async throws -> Int {
        print("🔄 GoalMigrationService: Migrating habit \(habitId)")
        print("   Legacy goal string: '\(legacyGoalString)'")
        print("   Created at: \(createdAt)")
        
        // Parse legacy goal string
        let goalValue = parseLegacyGoalString(legacyGoalString)
        print("   Parsed goal value: \(goalValue)")
        
        // Migrate via goal versioning service
        try await goalService.migrateLegacyGoal(
            habitId: habitId,
            legacyGoal: goalValue,
            habitCreatedAt: createdAt
        )
        
        print("✅ GoalMigrationService: Habit \(habitId) migrated successfully")
        return goalValue
    }
    
    /// Migrate all habits from the legacy Habit model
    ///
    /// - Parameter habits: Array of Habit objects with legacy goals
    /// - Returns: Migration summary
    func migrateAllHabits(habits: [Habit]) async throws -> MigrationSummary {
        guard !isMigrationComplete else {
            print("ℹ️ GoalMigrationService: Migration already complete, skipping")
            return MigrationSummary(
                totalHabits: 0,
                successCount: 0,
                errorCount: 0,
                skippedCount: habits.count,
                errors: []
            )
        }
        
        print("🔄 GoalMigrationService: Starting migration for \(habits.count) habits")
        
        var successCount = 0
        var errorCount = 0
        var errors: [(habitId: String, error: String)] = []
        
        for habit in habits {
            do {
                try await migrateHabitGoal(
                    habitId: habit.id.uuidString,
                    legacyGoalString: habit.goal,
                    createdAt: habit.createdAt
                )
                successCount += 1
            } catch {
                print("❌ GoalMigrationService: Failed to migrate habit \(habit.id): \(error)")
                errorCount += 1
                errors.append((habitId: habit.id.uuidString, error: error.localizedDescription))
            }
        }
        
        let summary = MigrationSummary(
            totalHabits: habits.count,
            successCount: successCount,
            errorCount: errorCount,
            skippedCount: 0,
            errors: errors
        )
        
        print("✅ GoalMigrationService: Migration complete")
        print("   Total: \(summary.totalHabits)")
        print("   Success: \(summary.successCount)")
        print("   Errors: \(summary.errorCount)")
        
        // Mark migration complete if no errors
        if errorCount == 0 {
            markMigrationComplete()
        }
        
        return summary
    }
    
    /// Perform migration check and migrate if needed
    ///
    /// Call this on app startup after loading habits.
    ///
    /// - Parameter habits: Current habits from repository
    /// - Returns: Migration summary (or nil if already complete)
    func performMigrationIfNeeded(habits: [Habit]) async throws -> MigrationSummary? {
        guard !isMigrationComplete else {
            return nil
        }
        
        print("🔄 GoalMigrationService: Migration needed, starting...")
        return try await migrateAllHabits(habits: habits)
    }
}

// MARK: - Migration Summary

struct MigrationSummary {
    let totalHabits: Int
    let successCount: Int
    let errorCount: Int
    let skippedCount: Int
    let errors: [(habitId: String, error: String)]
    
    var isSuccess: Bool {
        errorCount == 0
    }
    
    var summary: String {
        """
        Goal Migration Summary:
        - Total habits: \(totalHabits)
        - Migrated: \(successCount)
        - Errors: \(errorCount)
        - Skipped: \(skippedCount)
        """
    }
}

// MARK: - Helper Extension for Habit

extension Habit {
    /// Extract numeric goal value from legacy goal string
    nonisolated var numericGoal: Int {
        // Parse goal string directly without service
        let components = goal.components(separatedBy: " ")
        for component in components {
            if let number = Int(component) {
                return max(0, number)
            }
        }
        return 1  // Default
    }
}

