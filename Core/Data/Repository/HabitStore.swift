import Foundation
import SwiftData
import OSLog

// MARK: - Habit Store Actor
// This actor handles all data operations off the main thread
// The HabitRepository will act as a @MainActor facade for UI compatibility

final actor HabitStore {
    static let shared = HabitStore()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "HabitStore")
    private lazy var validationService = DataValidationService()
    
    // Storage implementations
    private let userDefaultsStorage = UserDefaultsStorage()
    private let swiftDataStorage = SwiftDataStorage()
    
    // Migration and retention
    private let migrationManager = DataMigrationManager.shared
    private let retentionManager = DataRetentionManager.shared
    private let historyCapper = HistoryCapper.shared
    
    // CloudKit and conflict resolution
    private let cloudKitSyncManager = CloudKitSyncManager.shared
    private let conflictResolver = ConflictResolutionManager.shared
    
    // Backup and recovery
    private let backupManager = BackupManager.shared
    
    // Performance monitoring - these are safe to use from any context
    private let performanceMetrics = PerformanceMetrics.shared
    private let dataUsageAnalytics = DataUsageAnalytics.shared
    private let userAnalytics = UserAnalytics.shared
    
    private init() {
        logger.info("HabitStore initialized")
    }
    
    // MARK: - Load Habits
    
    func loadHabits() async throws -> [Habit] {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Loading habits from storage")
        
        // Check if migration is needed
        if await migrationManager.needsMigration() {
            try await migrationManager.executeMigrations()
        }
        
        // Check if data retention cleanup is needed
        if retentionManager.currentPolicy.autoCleanupEnabled {
            try? await retentionManager.performCleanup()
        }
        
        // Use UserDefaults directly since SwiftData/CoreData is not working
        logger.info("HabitStore: Using UserDefaults storage directly...")
        let habits = try await userDefaultsStorage.loadHabits()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Successfully loaded \(habits.count) habits from UserDefaults in \(String(format: "%.3f", timeElapsed))s")
        
        // Record performance metrics
        await performanceMetrics.recordTiming("dataLoad", duration: timeElapsed)
        await performanceMetrics.recordEvent(PerformanceEvent(
            type: .dataLoad,
            description: "Loaded \(habits.count) habits",
            metadata: ["habit_count": "\(habits.count)"]
        ))
        
        // Record data usage analytics
        await dataUsageAnalytics.recordDataOperation(.habitLoad, size: Int64(habits.count * 1000))
        
        return habits
    }
    
    // MARK: - Save Habits
    
    func saveHabits(_ habits: [Habit]) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Saving \(habits.count) habits to storage")
        
        // Cap history data to prevent unlimited growth
        let cappedHabits = historyCapper.capAllHabits(habits, using: retentionManager.currentPolicy)
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
        
        // Use UserDefaults directly since SwiftData/CoreData is not working
        try await userDefaultsStorage.saveHabits(cappedHabits, immediate: true)
        logger.info("Successfully saved to UserDefaults")
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Successfully saved \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")
        
        // Record performance metrics
        await performanceMetrics.recordTiming("dataSave", duration: timeElapsed)
        await performanceMetrics.recordEvent(PerformanceEvent(
            type: .dataSave,
            description: "Saved \(habits.count) habits",
            metadata: [
                "habit_count": "\(habits.count)",
                "validation_errors": "\(validationResult.errors.count)"
            ]
        ))
        
        // Record data usage analytics
        await dataUsageAnalytics.recordDataOperation(.habitSave, size: Int64(habits.count * 1000))
        
        // Create backup if needed (run in background)
        Task {
            await backupManager.createBackupIfNeeded()
        }
    }
    
    // MARK: - Create Habit
    
    func createHabit(_ habit: Habit) async throws {
        logger.info("Creating habit: \(habit.name)")
        logger.info("Habit details - name: '\(habit.name)', goal: '\(habit.goal)', schedule: '\(habit.schedule)'")
        
        // Record user analytics
        await userAnalytics.recordEvent(.habitCreated, metadata: [
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
            
            // If there are critical errors, don't update the habit
            let criticalErrors = validationResult.errors.filter { $0.severity == .critical }
            if !criticalErrors.isEmpty {
                logger.error("Critical validation errors found, aborting habit update")
                throw DataError.validation(ValidationError(
                    field: "habit",
                    message: "Critical validation errors found",
                    severity: .critical
                ))
            }
        }
        
        // Record user analytics
        await userAnalytics.recordEvent(.featureUsed, metadata: [
            "action": "habit_edited",
            "habit_name": habit.name,
            "habit_id": habit.id.uuidString
        ])
        
        // Load current habits
        var currentHabits = try await loadHabits()
        
        if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
            currentHabits[index] = habit
            try await saveHabits(currentHabits)
            logger.info("Successfully updated habit: \(habit.name)")
        } else {
            logger.warning("No matching habit found for ID: \(habit.id), creating new habit")
            currentHabits.append(habit)
            try await saveHabits(currentHabits)
            logger.info("Successfully created new habit: \(habit.name)")
        }
    }
    
    // MARK: - Delete Habit
    
    func deleteHabit(_ habit: Habit) async throws {
        logger.info("Deleting habit: \(habit.name)")
        
        // Record user analytics
        await userAnalytics.recordEvent(.featureUsed, metadata: [
            "action": "habit_deleted",
            "habit_name": habit.name,
            "habit_id": habit.id.uuidString
        ])
        
        // Load current habits
        var currentHabits = try await loadHabits()
        currentHabits.removeAll { $0.id == habit.id }
        
        // Save updated habits (complete array)
        try await saveHabits(currentHabits)
        
        // Also delete the individual habit item from UserDefaults
        try await userDefaultsStorage.deleteHabit(id: habit.id)
        
        logger.info("Successfully deleted habit: \(habit.name)")
    }
    
    // MARK: - Set Progress
    
    func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
        let dateKey = CoreDataManager.dateKey(for: date)
        logger.info("Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
        
        // Record user analytics for habit completion
        if progress > 0 {
            await userAnalytics.recordEvent(.habitCompleted, metadata: [
                "habit_name": habit.name,
                "habit_id": habit.id.uuidString,
                "date": dateKey
            ])
        }
        
        // Load current habits
        var currentHabits = try await loadHabits()
        
        if let index = currentHabits.firstIndex(where: { $0.id == habit.id }) {
            currentHabits[index].completionHistory[dateKey] = progress
            try await saveHabits(currentHabits)
            logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")
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
            guard let date = await ISO8601DateHelper.shared.date(from: dateString) else { continue }
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
                guard let date = await ISO8601DateHelper.shared.date(from: dateString) else { continue }
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
        
        do {
            // Try SwiftData validation first
            if let swiftDataContainer = SwiftDataContainer.shared as? SwiftDataContainer {
                return await MainActor.run {
                    swiftDataContainer.validateDataIntegrity()
                }
            }
        } catch {
            logger.warning("SwiftData validation failed: \(error.localizedDescription)")
        }
        
        // Fallback to basic validation
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
        
        do {
            // Try SwiftData cleanup first
            if let swiftDataContainer = SwiftDataContainer.shared as? SwiftDataContainer {
                await MainActor.run {
                    swiftDataContainer.cleanupOrphanedRecords()
                }
                logger.info("SwiftData cleanup completed")
            }
        } catch {
            logger.warning("SwiftData cleanup failed: \(error.localizedDescription)")
        }
        
        // Fallback to basic cleanup
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
    func getRetentionPolicy() -> DataRetentionPolicy {
        return retentionManager.currentPolicy
    }
    
    /// Gets data size information for all habits
    func getDataSizeInfo() async throws -> [UUID: DataSizeInfo] {
        let habits = try await loadHabits()
        var sizeInfo: [UUID: DataSizeInfo] = [:]
        
        for habit in habits {
            sizeInfo[habit.id] = historyCapper.getHabitDataSize(habit)
        }
        
        return sizeInfo
    }
    
    /// Caps history for a specific habit
    func capHabitHistory(_ habit: Habit) -> Habit {
        return historyCapper.capHabitHistory(habit, using: retentionManager.currentPolicy)
    }
    
    // MARK: - CloudKit Conflict Resolution
    
    /// Performs CloudKit sync with conflict resolution
    func performCloudKitSync() async throws -> SyncResult {
        logger.info("Starting CloudKit sync with conflict resolution")
        
        // Check if CloudKit is available
        guard cloudKitSyncManager.isCloudKitAvailable() else {
            logger.warning("CloudKit not available, skipping sync")
            throw CloudKitError.notConfigured
        }
        
        return try await cloudKitSyncManager.performFullSync()
    }
    
    /// Resolves conflicts between two habits using field-level resolution
    func resolveHabitConflict(_ localHabit: Habit, _ remoteHabit: Habit) -> Habit {
        logger.info("Resolving conflict between local and remote habit: \(localHabit.name)")
        return conflictResolver.resolveHabitConflict(localHabit, remoteHabit)
    }
    
    /// Gets conflict resolution rules summary
    func getConflictResolutionRules() -> String {
        return conflictResolver.getRulesSummary()
    }
    
    /// Adds a custom conflict resolution rule
    func addConflictResolutionRule(_ rule: FieldConflictRule) {
        conflictResolver.addCustomRule(rule)
        logger.info("Added custom conflict resolution rule for field: \(rule.fieldName)")
    }
    
    /// Removes a custom conflict resolution rule
    func removeConflictResolutionRule(for fieldName: String) {
        conflictResolver.removeCustomRule(for: fieldName)
        logger.info("Removed custom conflict resolution rule for field: \(fieldName)")
    }
    
    /// Validates conflict resolution rules
    func validateConflictResolutionRules() -> [String] {
        return conflictResolver.validateRules()
    }
}
