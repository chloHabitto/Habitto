import Foundation
import SwiftData
import OSLog

// MARK: - Migration Runner
/// Handles migration from legacy storage to normalized SwiftData
@MainActor
final class MigrationRunner {
    static let shared = MigrationRunner()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationRunner")
    private let featureFlags: FeatureFlagProvider
    
    private init() {
        self.featureFlags = FeatureFlagManager.shared.provider
    }
    
    init(featureFlags: FeatureFlagProvider) {
        self.featureFlags = featureFlags
    }
    
    // MARK: - Public Migration Interface
    
    /// Runs migration if needed for the specified user
    /// This method is idempotent - running it multiple times is safe
    func runIfNeeded(userId: String) async throws {
        logger.info("MigrationRunner: Checking if migration needed for user \(userId)")
        
        // Check if migration is enabled
        guard featureFlags.isMigrationEnabled else {
            logger.info("MigrationRunner: Migration disabled by feature flag")
            return
        }
        
        // Get or create model context
        let context = try await getModelContext(for: userId)
        
        // Check if migration is already completed
        let migrationState = try MigrationState.findOrCreateForUser(userId: userId, in: context)
        
        if migrationState.isCompleted && !featureFlags.forceMigration {
            logger.info("MigrationRunner: Migration already completed for user \(userId)")
            return
        }
        
        // Run the migration
        try await runMigration(userId: userId, context: context, state: migrationState)
    }
    
    // MARK: - Private Migration Logic
    
    private func runMigration(userId: String, context: ModelContext, state: MigrationState) async throws {
        logger.info("MigrationRunner: Starting migration for user \(userId)")
        
        // Mark migration as in progress
        var migrationState = state
        migrationState.markInProgress()
        try context.save()
        
        do {
            // Step 1: Migrate habits from UserDefaults
            let habits = try await migrateHabits(userId: userId, context: context)
            
            // Step 2: Migrate completion records
            let completionCount = try await migrateCompletionRecords(habits: habits, userId: userId, context: context)
            
            // Step 3: Migrate daily awards
            let awardCount = try await migrateDailyAwards(userId: userId, context: context)
            
            // Step 4: Migrate user progress
            try await migrateUserProgress(userId: userId, context: context)
            
            // Mark migration as completed
            migrationState.markCompleted(recordsCount: completionCount + awardCount)
            try context.save()
            
            logger.info("MigrationRunner: Migration completed for user \(userId) - \(completionCount + awardCount) records migrated")
            
        } catch {
            // Mark migration as failed
            migrationState.markFailed(error: error)
            try context.save()
            
            logger.error("MigrationRunner: Migration failed for user \(userId): \(error.localizedDescription)")
            throw error
        }
    }
    
    private func migrateHabits(userId: String, context: ModelContext) async throws -> [Habit] {
        logger.info("MigrationRunner: Migrating habits for user \(userId)")
        
        // Load habits from UserDefaults (legacy storage)
        let habits = try await loadLegacyHabits()
        
        var migratedCount = 0
        
        for habit in habits {
            // Check if habit already exists in SwiftData
            let existingRequest = FetchDescriptor<HabitData>(
                predicate: #Predicate { $0.id == habit.id && $0.userId == userId }
            )
            let existing = try context.fetch(existingRequest)
            
            if existing.isEmpty {
                // Create new HabitData from legacy Habit
                let habitData = HabitData(
                    id: habit.id,
                    userId: userId,
                    name: habit.name,
                    habitDescription: habit.habitDescription,
                    icon: habit.icon,
                    colorData: try encodeColor(habit.color),
                    habitType: habit.habitType.rawValue,
                    schedule: habit.schedule,
                    goal: habit.goal,
                    reminder: habit.reminder,
                    startDate: habit.startDate,
                    endDate: habit.endDate,
                    isCompleted: habit.isCompleted,
                    streak: habit.streak
                )
                
                context.insert(habitData)
                migratedCount += 1
            }
        }
        
        try context.save()
        logger.info("MigrationRunner: Migrated \(migratedCount) habits for user \(userId)")
        
        return habits
    }
    
    private func migrateCompletionRecords(habits: [Habit], userId: String, context: ModelContext) async throws -> Int {
        logger.info("MigrationRunner: Migrating completion records for user \(userId)")
        
        var migratedCount = 0
        
        for habit in habits {
            // Migrate completion history
            for (dateString, completionCount) in habit.completionHistory {
                guard let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) else {
                    logger.warning("MigrationRunner: Invalid date string: \(dateString)")
                    continue
                }
                
                let dateKey = DateKey.key(for: date)
                let isCompleted = completionCount > 0
                
                // Check if completion record already exists
                let existingRequest = FetchDescriptor<CompletionRecord>(
                    predicate: #Predicate { 
                        $0.userId == userId && 
                        $0.habitId == habit.id && 
                        $0.dateKey == dateKey 
                    }
                )
                let existing = try context.fetch(existingRequest)
                
                if existing.isEmpty {
                    let completionRecord = CompletionRecord(
                        userId: userId,
                        habitId: habit.id,
                        date: date,
                        dateKey: dateKey,
                        isCompleted: isCompleted
                    )
                    
                    context.insert(completionRecord)
                    migratedCount += 1
                }
            }
        }
        
        try context.save()
        logger.info("MigrationRunner: Migrated \(migratedCount) completion records for user \(userId)")
        
        return migratedCount
    }
    
    private func migrateDailyAwards(userId: String, context: ModelContext) async throws -> Int {
        logger.info("MigrationRunner: Migrating daily awards for user \(userId)")
        
        // Load legacy XP data from UserDefaults
        let userDefaults = UserDefaults.standard
        guard let progressData = userDefaults.data(forKey: "user_progress"),
              let legacyProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData) else {
            logger.info("MigrationRunner: No legacy XP data found for user \(userId)")
            return 0
        }
        
        // For now, we'll create a single daily award for the total XP
        // In a real implementation, this would analyze historical completion data
        var migratedCount = 0
        
        if legacyProgress.xpTotal > 0 {
            // Create a daily award for today with the total XP
            let today = Date()
            let dateKey = DateKey.key(for: today)
            
            // Check if daily award already exists
            let existingRequest = FetchDescriptor<DailyAward>(
                predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey }
            )
            let existing = try context.fetch(existingRequest)
            
            if existing.isEmpty {
                let dailyAward = DailyAward(
                    userId: userId,
                    dateKey: dateKey,
                    xpGranted: legacyProgress.xpTotal,
                    allHabitsCompleted: true
                )
                
                context.insert(dailyAward)
                migratedCount += 1
            }
        }
        
        try context.save()
        logger.info("MigrationRunner: Migrated \(migratedCount) daily awards for user \(userId)")
        
        return migratedCount
    }
    
    private func migrateUserProgress(userId: String, context: ModelContext) async throws {
        logger.info("MigrationRunner: Migrating user progress for user \(userId)")
        
        // Check if UserProgress already exists
        let existingRequest = FetchDescriptor<UserProgress>(
            predicate: #Predicate { $0.userId == userId }
        )
        let existing = try context.fetch(existingRequest)
        
        if existing.isEmpty {
            // Load legacy progress from UserDefaults
            let userDefaults = UserDefaults.standard
            if let progressData = userDefaults.data(forKey: "user_progress"),
               let legacyProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData) {
                
                // Create new UserProgress with migrated data
                let userProgress = UserProgress(
                    userId: userId,
                    xpTotal: legacyProgress.xpTotal,
                    level: legacyProgress.level,
                    levelProgress: legacyProgress.levelProgress,
                    lastCompletedDate: legacyProgress.lastCompletedDate
                )
                
                context.insert(userProgress)
                try context.save()
                
                logger.info("MigrationRunner: Migrated user progress for user \(userId)")
            } else {
                // Create default user progress
                let userProgress = UserProgress(userId: userId)
                context.insert(userProgress)
                try context.save()
                
                logger.info("MigrationRunner: Created default user progress for user \(userId)")
            }
        } else {
            logger.info("MigrationRunner: User progress already exists for user \(userId)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadLegacyHabits() async throws -> [Habit] {
        let userDefaults = UserDefaults.standard
        let possibleKeys = ["SavedHabits", "Habits", "UserHabits", "LegacyHabits"]
        
        for key in possibleKeys {
            if let habitsData = userDefaults.data(forKey: key) {
                do {
                    let habits = try JSONDecoder().decode([Habit].self, from: habitsData)
                    if !habits.isEmpty {
                        logger.info("MigrationRunner: Loaded \(habits.count) habits from key: \(key)")
                        return habits
                    }
                } catch {
                    logger.error("MigrationRunner: Failed to decode habits from key \(key): \(error.localizedDescription)")
                }
            }
        }
        
        logger.info("MigrationRunner: No legacy habits found")
        return []
    }
    
    private func encodeColor(_ color: Color) throws -> Data {
        // This is a simplified implementation
        // In a real app, you'd need proper color encoding
        return Data()
    }
    
    private func getModelContext(for userId: String) async throws -> ModelContext {
        // For now, use the shared container
        // In Phase 3, this will be user-scoped
        return ModelContext(SwiftDataContainer.shared.modelContainer)
    }
}

// MARK: - Migration Runner Extensions
extension MigrationRunner {
    /// Check if migration is needed for a user
    func isMigrationNeeded(userId: String) async throws -> Bool {
        guard featureFlags.isMigrationEnabled else { return false }
        
        let context = try await getModelContext(for: userId)
        let migrationState = try MigrationState.findForUser(userId: userId, in: context)
        
        return migrationState?.isCompleted != true || featureFlags.forceMigration
    }
    
    /// Get migration status for a user
    func getMigrationStatus(userId: String) async throws -> MigrationStatus? {
        let context = try await getModelContext(for: userId)
        let migrationState = try MigrationState.findForUser(userId: userId, in: context)
        return migrationState?.status
    }
    
    /// Force migration for testing
    func forceMigration(userId: String) async throws {
        let context = try await getModelContext(for: userId)
        let migrationState = try MigrationState.findOrCreateForUser(userId: userId, in: context)
        
        // Reset migration state
        migrationState.status = .pending
        migrationState.completedAt = nil
        migrationState.errorMessage = nil
        migrationState.migratedRecordsCount = 0
        
        try context.save()
        
        // Run migration
        try await runMigration(userId: userId, context: context, state: migrationState)
    }
}
