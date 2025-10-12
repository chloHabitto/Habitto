import Foundation

/// Service for managing date-effective goal versioning
/// 
/// Goals are never retroactively changed. When a new goal is set, it applies
/// from the specified effectiveLocalDate forward, leaving all past data unchanged.
///
/// Key principles:
/// - Past days are immutable (never rewritten)
/// - New goals apply from local midnight of effectiveLocalDate (Europe/Amsterdam)
/// - Multiple goal changes per day are supported (latest version wins)
/// - If today already has completions, existing progress is preserved
@MainActor
class GoalVersioningService {
    // MARK: - Singleton
    
    static let shared = GoalVersioningService()
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let dateFormatter: LocalDateFormatter
    
    // MARK: - Initialization
    
    init(
        repository: FirestoreRepository? = nil,
        dateFormatter: LocalDateFormatter? = nil
    ) {
        // Default to shared instance inside init body (main actor context)
        self.repository = repository ?? FirestoreRepository.shared
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
    }
    
    // MARK: - Public Methods
    
    /// Set a new goal effective from the specified local date
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - effectiveLocalDate: Date from which the goal applies (YYYY-MM-DD in Europe/Amsterdam)
    ///   - goal: The goal value (must be >= 0)
    ///
    /// - Note: Past days remain unchanged. The new goal applies from `effectiveLocalDate` forward.
    ///         If setting a goal for today and completions already exist, existing progress is preserved.
    func setGoal(habitId: String, effectiveLocalDate: String, goal: Int) async throws {
        // Validate goal value
        guard goal >= 0 else {
            throw GoalVersioningError.invalidGoal("Goal must be >= 0, got \(goal)")
        }
        
        // Validate date format
        guard dateFormatter.stringToDate(effectiveLocalDate) != nil else {
            throw GoalVersioningError.invalidDate("Invalid date format: \(effectiveLocalDate). Expected YYYY-MM-DD")
        }
        
        print("📊 GoalVersioningService: Setting goal for habit \(habitId) effective \(effectiveLocalDate): \(goal)")
        
        // Delegate to repository
        try await repository.setGoal(habitId: habitId, effectiveLocalDate: effectiveLocalDate, goal: goal)
        
        print("✅ GoalVersioningService: Goal set successfully")
    }
    
    /// Get the effective goal for a habit on a specific date
    ///
    /// - Parameters:
    ///   - date: The date to query
    ///   - habitId: The habit identifier
    ///
    /// - Returns: The goal value effective on that date, or 1 if no goal version exists
    ///
    /// - Note: Returns the most recent goal version whose effectiveLocalDate <= the query date
    func goal(on date: Date, habitId: String) async throws -> Int {
        let localDateString = dateFormatter.dateToString(date)
        
        do {
            let goalValue = try await repository.getGoal(habitId: habitId, on: localDateString)
            print("📊 GoalVersioningService: Goal for habit \(habitId) on \(localDateString): \(goalValue)")
            return goalValue
        } catch {
            // Default to 1 if no goal version exists
            print("⚠️ GoalVersioningService: No goal found for habit \(habitId) on \(localDateString), defaulting to 1")
            return 1
        }
    }
    
    /// Get the effective goal for a habit on a specific date string
    ///
    /// - Parameters:
    ///   - localDateString: The date string (YYYY-MM-DD)
    ///   - habitId: The habit identifier
    ///
    /// - Returns: The goal value effective on that date, or 1 if no goal version exists
    func goal(on localDateString: String, habitId: String) async throws -> Int {
        guard let date = dateFormatter.stringToDate(localDateString) else {
            throw GoalVersioningError.invalidDate("Invalid date string: \(localDateString)")
        }
        
        return try await goal(on: date, habitId: habitId)
    }
    
    /// Get the current goal for a habit (as of today)
    ///
    /// - Parameter habitId: The habit identifier
    /// - Returns: The current goal value
    func currentGoal(habitId: String) async throws -> Int {
        let today = dateFormatter.todayDate()
        return try await goal(on: today, habitId: habitId)
    }
    
    // MARK: - Migration Support
    
    /// Migrate a legacy single-goal field to goal versioning
    ///
    /// Creates an initial goal version effective from the habit's creation date.
    /// This preserves historical accuracy when migrating from single-goal to versioned goals.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - legacyGoal: The legacy goal value
    ///   - habitCreatedAt: When the habit was created
    ///
    /// - Note: If a goal version already exists for this habit, this is a no-op
    func migrateLegacyGoal(habitId: String, legacyGoal: Int, habitCreatedAt: Date) async throws {
        print("🔄 GoalVersioningService: Migrating legacy goal for habit \(habitId): \(legacyGoal)")
        
        // Convert habit creation date to local date string
        let effectiveLocalDate = dateFormatter.dateToString(habitCreatedAt)
        
        // Check if a goal version already exists
        let existingGoal = try? await repository.getGoal(habitId: habitId, on: effectiveLocalDate)
        
        if existingGoal != nil {
            print("ℹ️ GoalVersioningService: Goal version already exists for \(habitId), skipping migration")
            return
        }
        
        // Create initial goal version
        try await setGoal(habitId: habitId, effectiveLocalDate: effectiveLocalDate, goal: legacyGoal)
        
        print("✅ GoalVersioningService: Legacy goal migrated for habit \(habitId)")
    }
    
    /// Batch migrate multiple habits from legacy goals
    ///
    /// - Parameter habits: Array of (habitId, legacyGoal, createdAt) tuples
    func migrateLegacyGoals(habits: [(id: String, goal: Int, createdAt: Date)]) async throws {
        print("🔄 GoalVersioningService: Starting batch migration for \(habits.count) habits")
        
        var successCount = 0
        var errorCount = 0
        
        for habit in habits {
            do {
                try await migrateLegacyGoal(
                    habitId: habit.id,
                    legacyGoal: habit.goal,
                    habitCreatedAt: habit.createdAt
                )
                successCount += 1
            } catch {
                print("❌ GoalVersioningService: Failed to migrate habit \(habit.id): \(error)")
                errorCount += 1
            }
        }
        
        print("✅ GoalVersioningService: Batch migration complete - Success: \(successCount), Errors: \(errorCount)")
        
        if errorCount > 0 {
            throw GoalVersioningError.migrationFailed("Failed to migrate \(errorCount) habits")
        }
    }
}

// MARK: - Errors

enum GoalVersioningError: LocalizedError {
    case invalidGoal(String)
    case invalidDate(String)
    case migrationFailed(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidGoal(let message):
            return "Invalid goal: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        }
    }
}

