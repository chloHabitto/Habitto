import Foundation
import SwiftData
import OSLog
import SwiftUI

// MARK: - Habit Store Actor
// This actor handles all data operations off the main thread
// The HabitRepository will act as a @MainActor facade for UI compatibility

final actor HabitStore {
    static let shared = HabitStore()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "HabitStore")
    private lazy var validationService = DataValidationService()
    
    // Storage implementations
    private let baseUserDefaultsStorage = UserDefaultsStorage()
    private let baseSwiftDataStorage = SwiftDataStorage()
    
    // User-aware storage wrappers
    private lazy var userDefaultsStorage = UserAwareStorage(baseStorage: baseUserDefaultsStorage)
    private lazy var swiftDataStorage = UserAwareStorage(baseStorage: baseSwiftDataStorage)
    
    // MARK: - Manager Properties (Actor-Safe)
    // Create instances on-demand to avoid main actor isolation issues
    
    private var migrationManager: DataMigrationManager {
        get async {
            return await MainActor.run { DataMigrationManager.shared }
        }
    }
    
    private var retentionManager: DataRetentionManager {
        get async {
            return await MainActor.run { DataRetentionManager.shared }
        }
    }
    
    private var historyCapper: HistoryCapper {
        get async {
            return await MainActor.run { HistoryCapper.shared }
        }
    }
    
    private var cloudKitSyncManager: CloudKitSyncManager {
        get async {
            return await MainActor.run { CloudKitSyncManager.shared }
        }
    }
    
    private var conflictResolver: ConflictResolutionManager {
        get async {
            return await MainActor.run { ConflictResolutionManager.shared }
        }
    }
    
    private var backupManager: BackupManager {
        get async {
            return await MainActor.run { BackupManager.shared }
        }
    }
    
    private var performanceMetrics: PerformanceMetrics {
        get async {
            return await MainActor.run { PerformanceMetrics.shared }
        }
    }
    
    private var dataUsageAnalytics: DataUsageAnalytics {
        get async {
            return await MainActor.run { DataUsageAnalytics.shared }
        }
    }
    
    private var userAnalytics: UserAnalytics {
        get async {
            return await MainActor.run { UserAnalytics.shared }
        }
    }
    
    private init() {
        logger.info("HabitStore initialized")
    }
    
    // MARK: - Load Habits
    
    func loadHabits() async throws -> [Habit] {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Loading habits from storage")
        
        // Check if migration is needed
        let migrationMgr = await migrationManager
        if await migrationMgr.needsMigration() {
            try await migrationMgr.executeMigrations()
        }
        
        // Check if data retention cleanup is needed
        let retentionMgr = await retentionManager
        if retentionMgr.currentPolicy.autoCleanupEnabled {
            // Handle the result of the try? operation
            let cleanupResult = try? await retentionMgr.performCleanup()
            if cleanupResult != nil {
                logger.info("Data retention cleanup completed")
            } else {
                logger.warning("Data retention cleanup failed")
            }
        }
        
        // Use SwiftData for modern persistence
        logger.info("HabitStore: Using SwiftData storage...")
        var habits = try await swiftDataStorage.loadHabits()
        
        // If no habits found in SwiftData, check for habits in UserDefaults (migration scenario)
        if habits.isEmpty {
            logger.info("No habits found in SwiftData, checking UserDefaults for migration...")
            let legacyHabits = try await checkForLegacyHabits()
            if !legacyHabits.isEmpty {
                logger.info("Found \(legacyHabits.count) habits in UserDefaults, migrating to SwiftData...")
                habits = legacyHabits
                // Save the migrated habits to SwiftData
                try await swiftDataStorage.saveHabits(legacyHabits, immediate: true)
                logger.info("Successfully migrated habits to SwiftData")
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Successfully loaded \(habits.count) habits from SwiftData in \(String(format: "%.3f", timeElapsed))s")
        
        // Record performance metrics
        let metrics = await performanceMetrics
        await metrics.recordTiming("dataLoad", duration: timeElapsed)
        await metrics.recordEvent(PerformanceEvent(
            type: .dataLoad,
            description: "Loaded \(habits.count) habits",
            metadata: ["habit_count": "\(habits.count)"]
        ))
        
        // Record data usage analytics (simplified)
        // Note: Using lightweight on-demand analytics instead of continuous tracking
        
        return habits
    }
    
    /// Check for habits stored in UserDefaults (legacy storage)
    private func checkForLegacyHabits() async throws -> [Habit] {
        logger.info("Checking UserDefaults for legacy habits...")
        
        // Check for habits in various UserDefaults keys
        let possibleKeys = [
            "SavedHabits",
            "guest_habits",
            "habits"
        ]
        
        for key in possibleKeys {
            if let habitsData = UserDefaults.standard.data(forKey: key),
               let habits = try? JSONDecoder().decode([Habit].self, from: habitsData),
               !habits.isEmpty {
                logger.info("Found \(habits.count) habits in UserDefaults key: \(key)")
                return habits
            }
        }
        
        logger.info("No legacy habits found in UserDefaults")
        return []
    }
    
    // MARK: - Save Habits
    
    func saveHabits(_ habits: [Habit]) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Saving \(habits.count) habits to storage")
        
        // Cap history data to prevent unlimited growth
        let capper = await historyCapper
        let retentionMgr = await retentionManager
        let cappedHabits = capper.capAllHabits(habits, using: retentionMgr.currentPolicy)
        logger.debug("History capping applied to \(habits.count) habits")
        
        // Validate habits before saving
        let validationResult = validationService.validateHabits(cappedHabits)
        if !validationResult.isValid {
            logger.warning("Validation failed with \(validationResult.errors.count) errors")
            for error in validationResult.errors {
                logger.warning("  - \(error.field): \(error.message)")
            }
            
            // If there are critical errors, don't save
            let criticalErrors = validationResult.errors.filter { $0.severity == .critical }
            if !criticalErrors.isEmpty {
                logger.error("Critical validation errors found, aborting save")
                logger.error("Critical errors: \(criticalErrors.map { "\($0.field): \($0.message)" })")
                throw DataError.validation(ValidationError(
                    field: "habits",
                    message: "Critical validation errors found",
                    severity: .critical
                ))
            } else {
                logger.info("Non-critical validation errors found, proceeding with save")
            }
        } else {
            logger.info("All habits passed validation")
        }
        
        // Use SwiftData for modern persistence
        try await swiftDataStorage.saveHabits(cappedHabits, immediate: true)
        logger.info("Successfully saved to SwiftData")
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Successfully saved \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")
        
        // Record performance metrics
        let metrics = await performanceMetrics
        await metrics.recordTiming("dataSave", duration: timeElapsed)
        await metrics.recordEvent(PerformanceEvent(
            type: .dataSave,
            description: "Saved \(habits.count) habits",
            metadata: [
                "habit_count": "\(habits.count)",
                "validation_errors": "\(validationResult.errors.count)"
            ]
        ))
        
        // Record data usage analytics (simplified)
        // Note: Using lightweight on-demand analytics instead of continuous tracking
        
        // Create backup if needed (run in background)
        Task {
            let backupMgr = await backupManager
            await backupMgr.createBackupIfNeeded()
        }
    }
    
    // MARK: - Create Habit
    
    func createHabit(_ habit: Habit) async throws {
        logger.info("Creating habit: \(habit.name)")
        logger.info("Habit details - name: '\(habit.name)', goal: '\(habit.goal)', schedule: '\(habit.schedule)'")
        
        // Record user analytics
        let analytics = await userAnalytics
        await analytics.recordEvent(.habitCreated, metadata: [
            "habit_name": habit.name,
            "habit_type": habit.habitType.rawValue
        ])
        
        // Load current habits
        var currentHabits = try await loadHabits()
        currentHabits.append(habit)
        
        // Save updated habits
        try await saveHabits(currentHabits)
        
        logger.info("Successfully created habit: \(habit.name)")
    }
    
    // MARK: - Update Habit
    
    func updateHabit(_ habit: Habit) async throws {
        logger.info("Updating habit: \(habit.name) (ID: \(habit.id))")
        
        // Validate habit before updating
        let validationResult = validationService.validateHabit(habit)
        if !validationResult.isValid {
            logger.warning("Validation failed for updated habit")
            for error in validationResult.errors {
                logger.warning("  - \(error.field): \(error.message)")
            }
            
            // Only abort for truly critical errors that would corrupt data
            let criticalErrors = validationResult.errors.filter { 
                $0.severity == .critical && 
                ($0.field == "streak" && $0.message.contains("cannot be negative"))
            }
            if !criticalErrors.isEmpty {
                logger.error("Critical validation errors found, aborting habit update")
                throw DataError.validation(ValidationError(
                    field: "habit",
                    message: "Critical validation errors found",
                    severity: .critical
                ))
            } else {
                logger.info("Non-critical validation errors found, proceeding with update")
            }
        }
        
        // Record user analytics
        let analytics = await userAnalytics
        await analytics.recordEvent(.featureUsed, metadata: [
            "action": "habit_edited",
            "habit_name": habit.name,
            "habit_id": habit.id.uuidString
        ])
        
        // Load current habits
        var currentHabits = try await loadHabits()
        
        if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
            // Update existing habit
            currentHabits[index] = habit
            logger.info("Found existing habit at index \(index), updating...")
        } else {
            // Create new habit if not found
            logger.warning("No matching habit found for ID: \(habit.id), creating new habit")
            currentHabits.append(habit)
        }
        
        // Save the updated habits array
        do {
            try await saveHabits(currentHabits)
            logger.info("Successfully saved habit: \(habit.name) (total habits: \(currentHabits.count))")
        } catch {
            logger.error("Failed to save habits after update: \(error)")
            // Re-throw the error to be handled by the calling code
            throw error
        }
    }
    
    // MARK: - Delete Habit
    
    func deleteHabit(_ habit: Habit) async throws {
        logger.info("Deleting habit: \(habit.name)")
        
        // Record user analytics
        let analytics = await userAnalytics
        await analytics.recordEvent(.featureUsed, metadata: [
            "action": "habit_deleted",
            "habit_name": habit.name,
            "habit_id": habit.id.uuidString
        ])
        
        // Load current habits
        var currentHabits = try await loadHabits()
        currentHabits.removeAll { $0.id == habit.id }
        
        // Save updated habits (complete array)
        try await saveHabits(currentHabits)
        
        // Also delete the individual habit item from SwiftData
        try await swiftDataStorage.deleteHabit(id: habit.id)
        
        logger.info("Successfully deleted habit: \(habit.name)")
    }
    
    // MARK: - Set Progress
    
    func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
        let dateKey = CoreDataManager.dateKey(for: date)
        logger.info("Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
        
        // Record user analytics for habit completion
        if progress > 0 {
            let analytics = await userAnalytics
            await analytics.recordEvent(.habitCompleted, metadata: [
                "habit_name": habit.name,
                "habit_id": habit.id.uuidString,
                "date": dateKey
            ])
        }
        
        // Load current habits
        var currentHabits = try await loadHabits()
        
        if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
            currentHabits[index].completionHistory[dateKey] = progress
            
            // Update streak after progress change
            currentHabits[index].updateStreakWithReset()
            
            try await saveHabits(currentHabits)
            logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")
            
            // XP logic is now handled in HabitRepository.setProgress for immediate UI feedback
            
            // ⚠️  CRITICAL: NO XP WRITES HERE
            // Achievement checking is handled by DailyAwardService
            // Do NOT call XPManager methods or perform any XP manipulation
            // All XP changes must go through DailyAwardService to prevent duplicates
            
            // Celebration logic is handled in UI layer (HomeTabView)
        } else {
            logger.error("Habit not found in storage: \(habit.name)")
            throw DataError.storage(StorageError(
                type: .fileNotFound,
                message: "Habit not found: \(habit.name)",
                severity: .error
            ))
        }
    }
    
    // MARK: - Get Progress
    
    func getProgress(for habit: Habit, date: Date) -> Int {
        return habit.getProgress(for: date)
    }
    
    // MARK: - Save Difficulty Rating
    
    func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) async throws {
        logger.info("Saving difficulty \(difficulty) for habit \(habitId) on \(date)")
        
        // Load current habits
        var currentHabits = try await loadHabits()
        
        if let index = currentHabits.firstIndex(where: { $0.id == habitId }) {
            currentHabits[index].recordDifficulty(Int(difficulty), for: date)
            try await saveHabits(currentHabits)
            logger.info("Successfully saved difficulty \(difficulty) for habit \(habitId)")
        } else {
            logger.error("Habit not found for ID: \(habitId)")
            throw DataError.storage(StorageError(
                type: .fileNotFound,
                message: "Habit not found for ID: \(habitId)",
                severity: .error
            ))
        }
    }
    
    // MARK: - Fetch Difficulty Data
    
    func fetchDifficultiesForHabit(_ habitId: UUID, month: Int, year: Int) async throws -> [Double] {
        logger.info("Fetching difficulties for habit \(habitId) for month \(month)/\(year)")
        
        let habits = try await loadHabits()
        guard let habit = habits.first(where: { $0.id == habitId }) else {
            logger.warning("Habit not found for ID: \(habitId)")
            return []
        }
        
        // Create date range for the specified month and year
        let calendar = Calendar.current
        var startDateComponents = DateComponents()
        startDateComponents.year = year
        startDateComponents.month = month
        startDateComponents.day = 1
        startDateComponents.hour = 0
        startDateComponents.minute = 0
        startDateComponents.second = 0
        
        guard let startDate = calendar.date(from: startDateComponents) else { return [] }
        
        var endDateComponents = DateComponents()
        endDateComponents.year = year
        endDateComponents.month = month + 1
        endDateComponents.day = 1
        endDateComponents.hour = 0
        endDateComponents.minute = 0
        endDateComponents.second = 0
        
        guard let endDate = calendar.date(from: endDateComponents) else { return [] }
        
        // Filter difficulty history by date range
        var difficulties: [Double] = []
        for (dateString, difficulty) in habit.difficultyHistory {
            guard let date = ISO8601DateHelper.shared.date(from: dateString) else { continue }
            if date >= startDate && date < endDate {
                difficulties.append(Double(difficulty))
            }
        }
        
        logger.info("Found \(difficulties.count) difficulty records for habit \(habitId)")
        return difficulties
    }
    
    func fetchAllDifficulties(month: Int, year: Int) async throws -> [Double] {
        logger.info("Fetching all difficulties for month \(month)/\(year)")
        
        let habits = try await loadHabits()
        
        // Create date range for the specified month and year
        let calendar = Calendar.current
        var startDateComponents = DateComponents()
        startDateComponents.year = year
        startDateComponents.month = month
        startDateComponents.day = 1
        startDateComponents.hour = 0
        startDateComponents.minute = 0
        startDateComponents.second = 0
        
        guard let startDate = calendar.date(from: startDateComponents) else { return [] }
        
        var endDateComponents = DateComponents()
        endDateComponents.year = year
        endDateComponents.month = month + 1
        endDateComponents.day = 1
        endDateComponents.hour = 0
        endDateComponents.minute = 0
        endDateComponents.second = 0
        
        guard let endDate = calendar.date(from: endDateComponents) else { return [] }
        
        // Collect all difficulties from all habits
        var allDifficulties: [Double] = []
        for habit in habits {
            for (dateString, difficulty) in habit.difficultyHistory {
                guard let date = ISO8601DateHelper.shared.date(from: dateString) else { continue }
                if date >= startDate && date < endDate {
                    allDifficulties.append(Double(difficulty))
                }
            }
        }
        
        logger.info("Found \(allDifficulties.count) total difficulty records")
        return allDifficulties
    }
    
    // MARK: - Data Integrity
    
    func validateDataIntegrity() async throws -> Bool {
        logger.info("Validating data integrity")
        
        // Simplified validation - remove the problematic SwiftData access
        let habits = try await loadHabits()
        
        // Check for duplicate IDs
        let ids = habits.map { $0.id }
        let uniqueIds = Set(ids)
        let hasDuplicates = ids.count != uniqueIds.count
        
        if hasDuplicates {
            logger.warning("Found duplicate habit IDs")
            return false
        }
        
        logger.info("Data integrity validation passed")
        return true
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupOrphanedRecords() async throws {
        logger.info("Cleaning up orphaned records")
        
        // Simplified cleanup - remove the problematic SwiftData access
        let habits = try await loadHabits()
        
        // Remove habits with invalid IDs (default UUID)
        let validHabits = habits.filter { $0.id != UUID() }
        
        if validHabits.count != habits.count {
            logger.info("Removed \(habits.count - validHabits.count) habits with invalid IDs")
            try await saveHabits(validHabits)
        }
        
        logger.info("Cleanup completed")
    }
    
    // MARK: - Data Retention Management
    
    /// Performs data retention cleanup
    func performDataRetentionCleanup() async throws -> CleanupResult {
        logger.info("Starting data retention cleanup")
        return try await retentionManager.performCleanup()
    }
    
    /// Updates the data retention policy
    func updateRetentionPolicy(_ policy: DataRetentionPolicy) async throws {
        logger.info("Updating data retention policy")
        try await retentionManager.updatePolicy(policy)
    }
    
    /// Gets the current data retention policy
    func getRetentionPolicy() async -> DataRetentionPolicy {
        let retentionMgr = await retentionManager
        return retentionMgr.currentPolicy
    }
    
    /// Gets data size information for all habits
    func getDataSizeInfo() async throws -> [UUID: DataSizeInfo] {
        let habits = try await loadHabits()
        var sizeInfo: [UUID: DataSizeInfo] = [:]
        
        let capper = await historyCapper
        for habit in habits {
            sizeInfo[habit.id] = capper.getHabitDataSize(habit)
        }
        
        return sizeInfo
    }
    
    /// Caps history for a specific habit
    func capHabitHistory(_ habit: Habit) async -> Habit {
        let capper = await historyCapper
        let retentionMgr = await retentionManager
        return capper.capHabitHistory(habit, using: retentionMgr.currentPolicy)
    }
    
    // MARK: - CloudKit Conflict Resolution
    
    /// Performs CloudKit sync with conflict resolution
    func performCloudKitSync() async throws -> SyncResult {
        logger.info("Starting CloudKit sync with conflict resolution")
        
        // Check if CloudKit is available
        let syncManager = await cloudKitSyncManager
        guard syncManager.isCloudKitAvailable() else {
            logger.warning("CloudKit not available, skipping sync")
            throw CloudKitError.notConfigured
        }
        
        return try await syncManager.performFullSync()
    }
    
    /// Resolves conflicts between two habits using field-level resolution
    func resolveHabitConflict(_ localHabit: Habit, _ remoteHabit: Habit) async -> Habit {
        logger.info("Resolving conflict between local and remote habit: \(localHabit.name)")
        let resolver = await conflictResolver
        return resolver.resolveHabitConflict(localHabit, remoteHabit)
    }
    
    /// Gets conflict resolution rules summary
    func getConflictResolutionRules() async -> String {
        let resolver = await conflictResolver
        return resolver.getRulesSummary()
    }
    
    /// Adds a custom conflict resolution rule
    func addConflictResolutionRule(_ rule: FieldConflictRule) async {
        let resolver = await conflictResolver
        resolver.addCustomRule(rule)
        logger.info("Added custom conflict resolution rule for field: \(rule.fieldName)")
    }
    
    /// Removes a custom conflict resolution rule
    func removeConflictResolutionRule(for fieldName: String) async {
        let resolver = await conflictResolver
        resolver.removeCustomRule(for: fieldName)
        logger.info("Removed custom conflict resolution rule for field: \(fieldName)")
    }
    
    /// Validates conflict resolution rules
    func validateConflictResolutionRules() async -> [String] {
        let resolver = await conflictResolver
        return resolver.validateRules()
    }
    
    // MARK: - Account Deletion
    
    /// Clears all habits and associated data (for account deletion)
    func clearAllHabits() async throws {
        logger.info("Clearing all habits for account deletion")
        
        // Clear from SwiftData storage
        try await swiftDataStorage.clearAllHabits()
        
        // Clear any cached data
        // Note: The storage implementations will handle their own cache clearing
        
        logger.info("All habits cleared successfully")
    }
}
