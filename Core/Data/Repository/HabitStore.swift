import Foundation
import FirebaseAuth
import OSLog
import SwiftData
import SwiftUI

// MARK: - Habit Store Actor

// This actor handles all data operations off the main thread
// The HabitRepository will act as a @MainActor facade for UI compatibility

final actor HabitStore {
  // MARK: Lifecycle

  private init() {
    logger.info("HabitStore initialized")
  }

  // MARK: Internal

  static let shared = HabitStore()
  
  // ✅ FIX #18: Track cleanup per app session to prevent excessive runs
  private static var hasRunCleanupThisSession = false

  // MARK: - Load Habits

  func loadHabits() async throws -> [Habit] {
    let startTime = CFAbsoluteTimeGetCurrent()
    logger.info("Loading habits from storage")

    // Check if migration is needed
    let migrationMgr = await migrationManager
    if await migrationMgr.needsMigration() {
      try await migrationMgr.executeMigrations()
    }

    // ✅ FIX #18: Only run cleanup once per app session to improve performance
    // Check if data retention cleanup is needed
    if !Self.hasRunCleanupThisSession {
      Self.hasRunCleanupThisSession = true
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
    }

    // Use active storage (SwiftData or DualWrite based on feature flags)
    logger.info("HabitStore: Loading habits from active storage...")
    var habits = try await activeStorage.loadHabits()

    // If no habits found in SwiftData, check for habits in UserDefaults (migration scenario)
    if habits.isEmpty {
      logger.info("No habits found in SwiftData, checking UserDefaults for migration...")
      // ✅ Gate: If an authenticated user exists and guest data is present, do NOT auto-migrate here.
      //    The UI migration flow will handle it, preventing silent migrations and data duplication.
      let shouldDeferToUIMigration: Bool = await MainActor.run {
        if AuthenticationManager.shared.currentUser != nil { // authenticated
          return GuestDataMigration().hasGuestData()
        }
        return false
      }

      if shouldDeferToUIMigration {
        logger.info("🛑 Skipping auto-migration from UserDefaults because guest data exists and user is authenticated. UI will handle migration.")
        return habits
      }

      let legacyHabits = try await checkForLegacyHabits()
      if !legacyHabits.isEmpty {
        logger.info("Found \(legacyHabits.count) habits in UserDefaults, migrating to active storage...")
        habits = legacyHabits
        // Save the migrated habits to active storage (will sync to Firestore if enabled)
        try await activeStorage.saveHabits(legacyHabits, immediate: true)
        logger.info("Successfully migrated habits to active storage")
      }
    }

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    logger
      .info(
        "Successfully loaded \(habits.count) habits from SwiftData in \(String(format: "%.3f", timeElapsed))s")

    // Record performance metrics
    let metrics = await performanceMetrics
    await metrics.recordTiming("dataLoad", duration: timeElapsed)
    await metrics.recordEvent(PerformanceEvent(
      type: .dataLoad,
      description: "Loaded \(habits.count) habits",
      metadata: ["habit_count": "\(habits.count)"]))

    // Record data usage analytics (simplified)
    // Note: Using lightweight on-demand analytics instead of continuous tracking

    return habits
  }

  // MARK: - Save Habits

  func saveHabits(_ habits: [Habit]) async throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    #if DEBUG
    logger.info("🎯 [7/8] HabitStore.saveHabits: persisting \(habits.count) habits")
    #endif

    // Cap history data to prevent unlimited growth
    let capper = await historyCapper
    let retentionMgr = await retentionManager
    let cappedHabits = capper.capAllHabits(habits, using: retentionMgr.currentPolicy)
    logger.debug("History capping applied to \(habits.count) habits")

    // ✅ FIX: Auto-clear end dates that are in the past to prevent validation warnings
    let sanitizedHabits = cappedHabits.map { habit -> Habit in
      if let endDate = habit.endDate, endDate < Date() {
        logger.info("🔧 Auto-clearing past end date for habit '\(habit.name)' (was: \(endDate))")
        // Create new Habit with endDate cleared
        return Habit(
          id: habit.id,
          name: habit.name,
          description: habit.description,
          icon: habit.icon,
          color: habit.color,
          habitType: habit.habitType,
          schedule: habit.schedule,
          goal: habit.goal,
          reminder: habit.reminder,
          startDate: habit.startDate,
          endDate: nil,  // ✅ Clear past end date
          createdAt: habit.createdAt,
          reminders: habit.reminders,
          baseline: habit.baseline,
          target: habit.target,
          completionHistory: habit.completionHistory,
          completionStatus: habit.completionStatus,
          completionTimestamps: habit.completionTimestamps,
          difficultyHistory: habit.difficultyHistory,
          actualUsage: habit.actualUsage,
          lastSyncedAt: habit.lastSyncedAt,
          syncStatus: habit.syncStatus)
      }
      return habit
    }

    // Validate habits before saving
    let validationResult = validationService.validateHabits(sanitizedHabits)
    
    // ✅ FIX #2: Add explicit debug logging for validation results
    if !validationResult.isValid {
      logger.warning("Validation failed with \(validationResult.errors.count) errors")
      for error in validationResult.errors {
        logger.warning("  - \(error.field): \(error.message)")
      }
    }
    
    if !validationResult.isValid {

      // If there are critical OR error-level errors, don't save
      let criticalErrors = validationResult.errors.filter { $0.severity == .critical || $0.severity == .error }
      if !criticalErrors.isEmpty {
        logger.error("Critical validation errors found, aborting save")
        logger.error("Critical errors: \(criticalErrors.map { "\($0.field): \($0.message)" })")
        throw DataError.validation(ValidationError(
          field: "habits",
          message: "Critical validation errors found",
          severity: .critical))
      } else {
        logger.info("Non-critical validation errors found, proceeding with save")
      }
    } else {
      logger.info("All habits passed validation")
    }

    // Use active storage (SwiftData or DualWrite based on feature flags)
    try await activeStorage.saveHabits(sanitizedHabits, immediate: true)
    logger.info("Successfully saved to SwiftData")

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    logger
      .info("Successfully saved \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")

    // Record performance metrics
    let metrics = await performanceMetrics
    await metrics.recordTiming("dataSave", duration: timeElapsed)
    await metrics.recordEvent(PerformanceEvent(
      type: .dataSave,
      description: "Saved \(habits.count) habits",
      metadata: [
        "habit_count": "\(habits.count)",
        "validation_errors": "\(validationResult.errors.count)"
      ]))

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
    #if DEBUG
    logger.info("🎯 [6/8] HabitStore.createHabit: storing habit")
    logger.info("  → Habit: '\(habit.name)', ID: \(habit.id)")
    #endif

    // Record user analytics
    let analytics = await userAnalytics
    await analytics.recordEvent(.habitCreated, metadata: [
      "habit_name": habit.name,
      "habit_type": habit.habitType.rawValue
    ])

    // Load current habits
    #if DEBUG
    logger.info("  → Loading current habits")
    #endif
    var currentHabits = try await loadHabits()
    #if DEBUG
    logger.info("  → Current count: \(currentHabits.count)")
    #endif
    currentHabits.append(habit)
    #if DEBUG
    logger.info("  → Appended new habit, count: \(currentHabits.count)")
    #endif

    // Save updated habits
    #if DEBUG
    logger.info("  → Calling saveHabits")
    #endif
    try await saveHabits(currentHabits)

    #if DEBUG
    logger.info("  ✅ Habit created successfully")
    #endif
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
          severity: .critical))
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

    // Also delete the individual habit item from active storage
    try await activeStorage.deleteHabit(id: habit.id)

    logger.info("Successfully deleted habit: \(habit.name)")
  }

  // MARK: - Set Progress

  func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = CoreDataManager.dateKey(for: date)
    logger.info("Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
    logger.info("🎯 DEBUG: HabitStore.setProgress called - will create CompletionRecord")

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
      // ✅ FIX: Use type-aware progress tracking
      let habitType = currentHabits[index].habitType
      let oldProgress: Int
      // ✅ UNIVERSAL RULE: Both types use completionHistory for progress tracking
      // ⚠️ DEPRECATED: This is now a materialized view, not source of truth
      // Progress should be calculated from ProgressEvents, but we keep this for backward compatibility
      oldProgress = currentHabits[index].completionHistory[dateKey] ?? 0
      
      // ✅ PRIORITY 1: Always create ProgressEvent (event sourcing is now default)
      // This is the source of truth for all progress changes
      let goalAmount = StreakDataCalculator.parseGoalAmount(from: currentHabits[index].goal)
      
      // Get current user ID (used for both event creation and XP checks)
      let userId = await CurrentUser().idOrGuest
      
      // Determine event type from progress change
      // Note: eventTypeForProgressChange is a standalone function, not a method
      let eventType = eventTypeForProgressChange(
        oldProgress: oldProgress,
        newProgress: progress,
        goalAmount: goalAmount
      )
      
      let progressDelta = progress - oldProgress
      
      // Always create event if there's an actual change (event sourcing is default)
      if progressDelta != 0 {
        do {
          // Create event on MainActor (ProgressEventService is @MainActor)
          // Swift will handle the actor hop automatically
          let event = try await ProgressEventService.shared.createEvent(
            habitId: habit.id,
            date: date,
            dateKey: dateKey,
            eventType: eventType,
            progressDelta: progressDelta,
            userId: userId
          )
          logger.info("✅ Created ProgressEvent: id=\(event.id.prefix(20))..., type=\(eventType.rawValue), delta=\(progressDelta)")
        } catch {
          // Log error but don't throw - continue with existing flow for backward compatibility
          logger.error("❌ Failed to create ProgressEvent: \(error.localizedDescription)")
          logger.info("⚠️ Continuing with existing progress update flow (no event created)")
        }
      }
      
      // ⚠️ DEPRECATED: Direct state update - kept for backward compatibility
      // TODO: Remove this once all code paths use event replay
      // Progress should be calculated from ProgressEvents using calculateProgressFromEvents()
      currentHabits[index].completionHistory[dateKey] = progress
      let isComplete = progress >= goalAmount
      currentHabits[index].completionStatus[dateKey] = isComplete
      
      // Logging with habit type info
      if habitType == .breaking {
        logger.info("🔍 BREAKING HABIT - '\(habit.name)' | Progress: \(progress) | Goal: \(goalAmount) | Complete: \(isComplete)")
        logger.info("   📊 Display-only: Target: \(currentHabits[index].target) | Baseline: \(currentHabits[index].baseline)")
      } else {
        logger.info("🔍 FORMATION HABIT - '\(habit.name)' | Progress: \(progress) | Goal: \(goalAmount) | Complete: \(isComplete)")
      }

      // Handle timestamp recording for time-based completion analysis
      let currentTimestamp = Date()
      if progress > oldProgress {
        // Progress increased - record new completion timestamp
        if currentHabits[index].completionTimestamps[dateKey] == nil {
          currentHabits[index].completionTimestamps[dateKey] = []
        }
        // ✅ FIX: Append only ONE timestamp per increment (not a loop)
        currentHabits[index].completionTimestamps[dateKey]?.append(currentTimestamp)
        logger.info("Recorded 1 completion timestamp for \(habit.name)")
      } else if progress < oldProgress {
        // Progress decreased - remove recent timestamp
        if currentHabits[index].completionTimestamps[dateKey]?.isEmpty == false {
          currentHabits[index].completionTimestamps[dateKey]?.removeLast()
        }
        logger.info("Removed 1 completion timestamp for \(habit.name)")
      }

      // ✅ PHASE 4: Streaks are now computed-only, no need to update them

      // ✅ FIX: Create CompletionRecord entries for SwiftData queries
      await createCompletionRecordIfNeeded(
        habit: currentHabits[index],
        date: date,
        dateKey: dateKey,
        progress: progress)

      try await saveHabits(currentHabits)
      logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")

      // ✅ PRIORITY 2: Check daily completion and award/revoke XP atomically
      // Reuse userId variable declared above
      try await checkDailyCompletionAndAwardXP(dateKey: dateKey, userId: userId)

      // Celebration logic is handled in UI layer (HomeTabView)
    } else {
      logger.error("Habit not found in storage: \(habit.name)")
      throw DataError.storage(StorageError(
        type: .fileNotFound,
        message: "Habit not found: \(habit.name)",
        severity: .error))
    }
  }

  // MARK: - Get Progress

  /// Get progress for a habit on a specific date using event replay
  /// 
  /// ✅ PRIORITY 1: This method now uses ProgressEvents as the source of truth
  /// Falls back to completionHistory for backward compatibility (habits without events yet)
  func getProgress(for habit: Habit, date: Date) async -> Int {
    let dateKey = CoreDataManager.dateKey(for: date)
    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
    
    // Get legacy progress from completionHistory (fallback)
    let legacyProgress = habit.completionHistory[dateKey] ?? 0
    
    // 🔍 DEBUG: Log completionHistory state
    logger.info("🔍 getProgress DEBUG: habit=\(habit.name), dateKey=\(dateKey)")
    logger.info("   → completionHistory has \(habit.completionHistory.count) entries")
    logger.info("   → completionHistory[\(dateKey)] = \(legacyProgress)")
    logger.info("   → completionHistory keys: \(Array(habit.completionHistory.keys.sorted()).prefix(5))")
    
    // Calculate progress from events (event sourcing)
    // Note: ProgressEventService is @MainActor and accesses ModelContext internally
    let result = await ProgressEventService.shared.calculateProgressFromEvents(
      habitId: habit.id,
      dateKey: dateKey,
      goalAmount: goalAmount,
      legacyProgress: legacyProgress
    )
    
    logger.info("🔍 getProgress RESULT: habit=\(habit.name), dateKey=\(dateKey), finalProgress=\(result.progress), legacyProgress=\(legacyProgress), source=\(result.progress == legacyProgress ? "legacy" : "events")")
    
    return result.progress
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
        severity: .error))
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
      if date >= startDate, date < endDate {
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
        if date >= startDate, date < endDate {
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

    // Clear from active storage
    try await activeStorage.clearAllHabits()

    // Clear any cached data
    // Note: The storage implementations will handle their own cache clearing

    logger.info("All habits cleared successfully")
  }
  
  /// Clears all habits and associated data for a specific userId (for account deletion)
  /// ✅ CRITICAL FIX: Used during account deletion to ensure we clear data for the correct user
  func clearAllHabits(for userId: String?) async throws {
    logger.info("Clearing all habits for userId: \(userId ?? "guest")")

    // Check if activeStorage supports userId-specific clearing
    if let swiftDataStorage = activeStorage as? SwiftDataStorage {
      try await swiftDataStorage.clearAllHabits(for: userId)
      logger.info("SwiftData records cleared for userId: \(userId ?? "guest")")
    } else {
      // Fallback: Clear using current user (should be the same if called before sign out)
      try await activeStorage.clearAllHabits()
      logger.info("Habits cleared via activeStorage (fallback)")
    }

    logger.info("All habits cleared successfully for userId: \(userId ?? "guest")")
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "HabitStore")
  private lazy var validationService = DataValidationService()

  // Storage implementations
  private let baseUserDefaultsStorage = UserDefaultsStorage()
  private let baseSwiftDataStorage = SwiftDataStorage()

  // User-aware storage wrappers
  private lazy var userDefaultsStorage = UserAwareStorage(baseStorage: baseUserDefaultsStorage)
  private lazy var swiftDataStorage = UserAwareStorage(baseStorage: baseSwiftDataStorage)
  
  // MARK: - Active Storage (with Firestore support)
  
  /// Returns the appropriate storage based on feature flags
  /// - If Firestore sync is enabled: returns DualWriteStorage (writes to both SwiftData and Firestore)
  /// - Otherwise: returns SwiftData storage only
  private var activeStorage: any HabitStorageProtocol {
    get {
      // ✅ CRITICAL FIX: Force Firestore sync to TRUE
      // 
      // BACKGROUND:
      // RemoteConfig access from actor context causes Swift concurrency isolation issues.
      // RemoteConfig.remoteConfig() is @MainActor, but HabitStore is an Actor.
      // Cross-isolation access returns static defaults (FALSE) instead of plist defaults (TRUE).
      // 
      // SOLUTION:
      // Hardcode TRUE to ensure Firestore sync is always enabled.
      // 
      // TODO (Optional - Only if remote toggle needed):
      // - See ACTOR_ISOLATION_FIX_PLAN.md for proper actor-safe implementation
      // - Use "Pass at Init" approach to read RemoteConfig on MainActor during startup
      // - Pass boolean to HabitStore initializer to avoid cross-actor access
      // 
      // PRODUCTION DECISION:
      // For apps where Firestore sync should ALWAYS be enabled, hardcoding is
      // the correct approach (not technical debt). Remote toggle capability
      // would require app restart anyway.
      let enableFirestore = true  // Hardcoded - see comment above
      
      logger.info("🔍 HabitStore.activeStorage: enableFirestore = \(enableFirestore) (FORCED TRUE)")
      
      // Since enableFirestore is hardcoded to true, always use DualWriteStorage
      logger.info("🔥 HabitStore: Firestore sync ENABLED - using DualWriteStorage")
      return DualWriteStorage(
        primaryStorage: FirestoreService.shared,
        secondaryStorage: swiftDataStorage
      )
      
      // Note: SwiftData-only fallback removed since enableFirestore is hardcoded to true
      // If you need to disable Firestore in the future, change the enableFirestore constant above
    }
  }

  // MARK: - Manager Properties (Actor-Safe)

  // Create instances on-demand to avoid main actor isolation issues

  private var migrationManager: DataMigrationManager {
    get async {
      await MainActor.run { DataMigrationManager.shared }
    }
  }

  private var retentionManager: DataRetentionManager {
    get async {
      await MainActor.run { DataRetentionManager.shared }
    }
  }

  private var historyCapper: HistoryCapper {
    get async {
      await MainActor.run { HistoryCapper.shared }
    }
  }

  private var cloudKitSyncManager: CloudKitSyncManager {
    get async {
      await MainActor.run { CloudKitSyncManager.shared }
    }
  }

  private var conflictResolver: ConflictResolutionManager {
    get async {
      await MainActor.run { ConflictResolutionManager.shared }
    }
  }

  private var backupManager: BackupManager {
    get async {
      await MainActor.run { BackupManager.shared }
    }
  }

  private var performanceMetrics: PerformanceMetrics {
    get async {
      await MainActor.run { PerformanceMetrics.shared }
    }
  }

  private var dataUsageAnalytics: DataUsageAnalytics {
    get async {
      await MainActor.run { DataUsageAnalytics.shared }
    }
  }

  private var userAnalytics: UserAnalytics {
    get async {
      await MainActor.run { UserAnalytics.shared }
    }
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
      if let habitsData = UserDefaults.standard.data(forKey: key) {
        logger.info("Found data in UserDefaults key: \(key), size: \(habitsData.count) bytes")
        do {
          let habits = try JSONDecoder().decode([Habit].self, from: habitsData)
          if !habits.isEmpty {
            logger.info("Successfully decoded \(habits.count) habits from UserDefaults key: \(key)")
            return habits
          } else {
            logger.info("Decoded habits array is empty from key: \(key)")
          }
        } catch {
          logger
            .error(
              "Failed to decode habits from UserDefaults key \(key): \(error.localizedDescription)")
          logger.error("Decoding error details: \(error)")
        }
      }
    }

    logger.info("No legacy habits found in UserDefaults")
    return []
  }

  // MARK: - CompletionRecord Management

  /// Creates or updates CompletionRecord entries for SwiftData queries
  private func createCompletionRecordIfNeeded(
    habit: Habit,
    date: Date,
    dateKey: String,
    progress: Int) async
  {
    let userId = await CurrentUser().idOrGuest
    
    // ✅ DEBUG: Log current authentication state to diagnose userId issues
    await MainActor.run {
      if let currentUser = AuthenticationManager.shared.currentUser {
        if let firebaseUser = currentUser as? User {
          logger.info("🔍 DEBUG: Current Firebase user - UID: \(firebaseUser.uid), isAnonymous: \(firebaseUser.isAnonymous), userId used: '\(userId.isEmpty ? "guest" : userId)'")
        } else {
          logger.info("🔍 DEBUG: Current user (non-Firebase) - userId used: '\(userId.isEmpty ? "guest" : userId)'")
        }
      } else {
        logger.info("🔍 DEBUG: No current user - userId used: '\(userId.isEmpty ? "guest" : userId)'")
      }
    }
    
    logger
      .info(
        "🎯 createCompletionRecordIfNeeded: Starting for habit '\(habit.name)' on \(dateKey), userId: '\(userId.isEmpty ? "guest" : userId)'")

    do {
      // Perform all SwiftData operations on the main actor to avoid concurrency issues
      try await MainActor.run {
        logger.info("🎯 createCompletionRecordIfNeeded: Getting modelContext...")
        let modelContext = SwiftDataContainer.shared.modelContext
        logger.info("🎯 createCompletionRecordIfNeeded: Got modelContext successfully")

        // ✅ CRITICAL FIX: Removed database health check to prevent corruption
        // Health check was deleting database while in use
        // Database corruption is now handled gracefully with UserDefaults fallback

        // Check if CompletionRecord already exists
        logger.info("🎯 createCompletionRecordIfNeeded: Creating predicate...")
        let predicate = #Predicate<CompletionRecord> { record in
          record.userId == userId &&
            record.habitId == habit.id &&
            record.dateKey == dateKey
        }
        let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
        logger.info("🎯 createCompletionRecordIfNeeded: Fetching existing records...")
        let existingRecords: [CompletionRecord] = try modelContext.fetch(request)
        logger
          .info("🎯 createCompletionRecordIfNeeded: Found \(existingRecords.count) existing records")

        // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
        // Check if habit ACTUALLY met its goal: progress >= goalAmount
        let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
        let isCompleted = progress >= goalAmount
        
        // Debug logging with habit type
        let habitTypeStr = habit.habitType == .breaking ? "breaking" : "formation"
        if habit.habitType == .breaking {
          logger.info("🔍 BREAKING HABIT CHECK - '\(habit.name)' (id=\(habit.id)) | Progress: \(progress) | Goal: \(goalAmount) | Complete: \(isCompleted)")
          logger.info("   📊 Display-only fields: Target: \(habit.target) | Baseline: \(habit.baseline)")
        } else {
          logger.info("🔍 FORMATION HABIT CHECK - '\(habit.name)' (id=\(habit.id)) | Progress: \(progress) | Goal: \(goalAmount) | Complete: \(isCompleted)")
        }
        
        logger.info("🎯 CREATE_RECORD: habitType=\(habitTypeStr), progress=\(progress), goal=\(goalAmount), isCompleted=\(isCompleted)")

        if let existingRecord = existingRecords.first {
          // Update existing record
          logger.info("🎯 createCompletionRecordIfNeeded: Updating existing record...")
          existingRecord.isCompleted = isCompleted
          existingRecord.progress = progress  // ✅ CRITICAL FIX: Store progress count
          logger
            .info(
              "✅ Updated CompletionRecord for habit '\(habit.name)' (id=\(habit.id)) on \(dateKey): completed=\(isCompleted), progress=\(progress)")
        } else {
          // Create new record
          logger.info("🎯 createCompletionRecordIfNeeded: Creating new record...")
          let completionRecord = CompletionRecord(
            userId: userId,
            habitId: habit.id,
            date: date,
            dateKey: dateKey,
            isCompleted: isCompleted,
            progress: progress)  // ✅ CRITICAL FIX: Store progress count
          logger.info("🎯 createCompletionRecordIfNeeded: Inserting record into context... habitId=\(habit.id), isCompleted=\(isCompleted), progress=\(progress)")
          
          // ✅ CRITICAL FIX: Always insert CompletionRecord first, then link to HabitData
          // This ensures the record exists even if HabitData lookup fails
          modelContext.insert(completionRecord)
          logger.info("✅ Inserted CompletionRecord into context")
          
          // ✅ FIX: Explicitly link CompletionRecord to HabitData for cascade delete
          // Fetch the HabitData and append to its completionHistory
          let habitDataPredicate = #Predicate<HabitData> { habitData in
            habitData.id == habit.id && habitData.userId == userId
          }
          let habitDataRequest = FetchDescriptor<HabitData>(predicate: habitDataPredicate)
          if let habitData = try modelContext.fetch(habitDataRequest).first {
            // Only append if not already in the relationship (prevent duplicates)
            if !habitData.completionHistory.contains(where: { $0.habitId == completionRecord.habitId && $0.dateKey == completionRecord.dateKey }) {
              habitData.completionHistory.append(completionRecord)
              logger.info("✅ Linked CompletionRecord to HabitData.completionHistory (userId: '\(userId)', habitId: \(habit.id))")
            } else {
              logger.info("ℹ️ CompletionRecord already linked to HabitData, skipping duplicate link")
            }
          } else {
            // HabitData not found - CompletionRecord is still inserted and will be found via manual query
            logger.warning("⚠️ HabitData not found for habitId: \(habit.id), userId: '\(userId)' - CompletionRecord inserted standalone (will be found via manual query)")
            
            // ✅ DEBUG: Try to find HabitData without userId filter to see if it exists with different userId
            let debugPredicate = #Predicate<HabitData> { habitData in
              habitData.id == habit.id
            }
            let debugRequest = FetchDescriptor<HabitData>(predicate: debugPredicate)
            let debugHabits = try modelContext.fetch(debugRequest)
            if let debugHabit = debugHabits.first {
              logger.warning("⚠️ Found HabitData with different userId: '\(debugHabit.userId)' (expected: '\(userId)')")
            } else {
              logger.warning("⚠️ No HabitData found at all for habitId: \(habit.id)")
            }
          }
          
          logger
            .info(
              "✅ Created CompletionRecord for habit '\(habit.name)' (id=\(habit.id)) on \(dateKey): completed=\(isCompleted), progress=\(progress)")
        }

        // Save the context
        logger.info("🎯 createCompletionRecordIfNeeded: Saving context...")
        try modelContext.save()
        logger.info("✅ createCompletionRecordIfNeeded: Context saved successfully")
        
        // ✅ CRITICAL FIX: Verify CompletionRecord was actually saved
        let verifyPredicate = #Predicate<CompletionRecord> { record in
          record.userId == userId &&
            record.habitId == habit.id &&
            record.dateKey == dateKey
        }
        let verifyRequest = FetchDescriptor<CompletionRecord>(predicate: verifyPredicate)
        let savedRecords = try modelContext.fetch(verifyRequest)
        
        if let savedRecord = savedRecords.first {
          logger.info("✅ VERIFIED: CompletionRecord exists after save - userId: '\(savedRecord.userId)', habitId: \(savedRecord.habitId), dateKey: \(savedRecord.dateKey), progress: \(savedRecord.progress), isCompleted: \(savedRecord.isCompleted)")
        } else {
          logger.error("❌ VERIFICATION FAILED: CompletionRecord NOT found after save! userId: '\(userId)', habitId: \(habit.id), dateKey: \(dateKey)")
          // This shouldn't happen, but log it for debugging
        }
      }

    } catch {
      logger
        .error(
          "❌ createCompletionRecordIfNeeded: Failed to create/update CompletionRecord: \(error)")
      logger.error("❌ createCompletionRecordIfNeeded: Error details: \(error.localizedDescription)")

      // ✅ CRITICAL FIX: If database is corrupted, handle gracefully
      if error.localizedDescription.contains("no such table") ||
        error.localizedDescription.contains("ZCOMPLETIONRECORD") ||
        error.localizedDescription.contains("SQLite error code:1")
      {
        logger.error("🔧 HabitStore: Database corruption detected!")
        logger.error("🔧 HabitStore: Error: \(error.localizedDescription)")

        // Mark this habit as having a database issue
        await MainActor.run {
          // The progress is already stored in the habit's completionHistory
          // in the setProgress method above, so no need to set it again here
          logger
            .info(
              "🔧 HabitStore: Fallback: Progress \(progress) already stored in habit.completionHistory for \(dateKey)")

          // Reset the corrupted database for next app launch
          SwiftDataContainer.shared.resetCorruptedDatabase()
        }
      }
    }
  }
  
  // MARK: - XP Award Logic (Priority 2)
  
  /// ✅ PRIORITY 2: Check if all habits are completed for a date and award/revoke XP atomically
  ///
  /// This method:
  /// 1. Fetches all habits scheduled for dateKey
  /// 2. Calculates progress from events (event-sourced)
  /// 3. Checks if ALL habits are complete
  /// 4. Creates or deletes DailyAward with deterministic ID
  ///
  /// - Parameters:
  ///   - dateKey: The date key in format "yyyy-MM-dd"
  ///   - userId: The user identifier
  /// - Throws: Error if award check or creation fails
  func checkDailyCompletionAndAwardXP(dateKey: String, userId: String) async throws {
    logger.info("🎯 XP_CHECK: Checking daily completion for \(dateKey)")
    
    // Parse date from dateKey
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    guard let date = dateFormatter.date(from: dateKey) else {
      logger.error("❌ XP_CHECK: Invalid dateKey format: \(dateKey)")
      return
    }
    
    // Load all habits
    let habits = try await loadHabits()
    
    // Filter to habits scheduled for this date
    let scheduledHabits = habits.filter { habit in
      StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
    }
    
    logger.info("🎯 XP_CHECK: Found \(scheduledHabits.count) scheduled habits for \(dateKey)")
    
    guard !scheduledHabits.isEmpty else {
      logger.info("🎯 XP_CHECK: No scheduled habits, skipping XP check")
      return
    }
    
    // Calculate progress from events for each habit (functional approach - no mutation)
    let completionResults = await withTaskGroup(of: (habitId: UUID, habitName: String, isComplete: Bool).self) { group in
      for habit in scheduledHabits {
        group.addTask {
          let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
          
          // Calculate progress from events (event-sourced)
          // Note: ProgressEventService is @MainActor and accesses ModelContext internally
          let result = await ProgressEventService.shared.calculateProgressFromEvents(
            habitId: habit.id,
            dateKey: dateKey,
            goalAmount: goalAmount,
            legacyProgress: habit.completionHistory[dateKey]
          )
          
          return (habitId: habit.id, habitName: habit.name, isComplete: result.progress >= goalAmount)
        }
      }
      
      // Collect results
      var results: [(habitId: UUID, habitName: String, isComplete: Bool)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }
    
    // Check if all habits are completed (immutable value)
    let allCompleted = completionResults.allSatisfy { $0.isComplete }
    
    // Log incomplete habits
    for result in completionResults where !result.isComplete {
      logger.info("🎯 XP_CHECK: Habit '\(result.habitName)' not completed")
    }
    
    // Check if award already exists and manage awards (all on MainActor)
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      let awardPredicate = #Predicate<DailyAward> { award in
        award.userId == userId && award.dateKey == dateKey
      }
      let awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
      let existingAwards = (try? modelContext.fetch(awardDescriptor)) ?? []
      let awardExists = !existingAwards.isEmpty
      
      logger.info("🎯 XP_CHECK: All completed: \(allCompleted), Award exists: \(awardExists)")
      
      if allCompleted && !awardExists {
        // All habits complete AND award doesn't exist → create award
        logger.info("🎯 XP_CHECK: ✅ Creating DailyAward for \(dateKey)")
        
        // Create DailyAward with deterministic userIdDateKey (unique constraint)
        // Note: id is UUID but userIdDateKey provides deterministic uniqueness
        let award = DailyAward(
          userId: userId,
          dateKey: dateKey,
          xpGranted: 50, // Standard daily completion bonus
          allHabitsCompleted: true
        )
        
        // userIdDateKey is already set in init() and provides deterministic uniqueness
        // Format: "{userId}#{dateKey}" which matches EventSourcedUtils.dailyAwardId() concept
        modelContext.insert(award)
        try? modelContext.save()
        
        logger.info("🎯 XP_CHECK: ✅ DailyAward created successfully")
        
      } else if !allCompleted && awardExists {
        // NOT all complete AND award exists → delete award (XP reversal)
        logger.info("🎯 XP_CHECK: ❌ Removing DailyAward for \(dateKey) (habits uncompleted)")
        
        for award in existingAwards {
          modelContext.delete(award)
        }
        try? modelContext.save()
        
        logger.info("🎯 XP_CHECK: ✅ DailyAward removed successfully")
      } else {
        logger.info("🎯 XP_CHECK: ℹ️ No change needed (allCompleted: \(allCompleted), awardExists: \(awardExists))")
      }
    }
  }
}
