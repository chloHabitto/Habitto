import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import OSLog
import SwiftData
import SwiftUI

// TODO: [LOGGING] Standardize logging - currently mixes print() and os.Logger
// See: Docs/Guides/LOGGING_STANDARDS.md

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
  private var scheduledHabitsCache: (dateKey: String, habits: [Habit])?
  
  // ✅ FIX #18: Track cleanup per app session to prevent excessive runs
  private static var hasRunCleanupThisSession = false
  
  // ✅ CRITICAL FIX: Track deleted habit IDs to prevent restoration
  private static let deletedHabitsKey = "DeletedHabitIDs"
  
  // MARK: - ProgressEvent Failure Tracking
  
  /// Track ProgressEvent creation failures for observability
  /// Reset on app launch, used to detect systemic issues
  private var eventCreationFailureCount: Int = 0
  private var lastEventCreationFailure: Date? = nil

  // MARK: - Load Habits

  func loadHabits(force: Bool = false) async throws -> [Habit] {
    let startTime = CFAbsoluteTimeGetCurrent()

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
    
    // ✅ CRITICAL FIX: Log current userId before loading to verify filtering
    let currentUserId = await CurrentUser().idOrGuest
    
    var habits = try await activeStorage.loadHabits(force: force)
    
    // ✅ FIX: Only warn if actually in guest mode (userId is empty)
    if !habits.isEmpty && currentUserId.isEmpty {
      logger.warning("⚠️ [HABIT_STORE] Expected 0 habits in guest mode but found \(habits.count) - filtering may have failed!")
    }

    // If no habits found in SwiftData, check for habits in UserDefaults (migration scenario)
    if habits.isEmpty {
      // ✅ CRITICAL FIX: Skip UserDefaults migration in guest mode
      // When signed out, we should NOT migrate account data from UserDefaults
      // This prevents account data from being re-imported as guest data after sign-out
      if currentUserId.isEmpty {
        logger.info("🛑 Skipping UserDefaults migration in guest mode - account data should not be imported")
        return habits // Return empty array for guest mode
      }
      
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

      // ✅ CRITICAL FIX: Before migrating, check if habits exist for other userIds
      // If habits exist for authenticated users, DON'T migrate from UserDefaults
      // This prevents importing account data when user is signed out
      let hasHabitsForOtherUsers = await MainActor.run {
        let modelContext = SwiftDataContainer.shared.modelContext
        let allHabitsDescriptor = FetchDescriptor<HabitData>()
        do {
          let allHabits = try modelContext.fetch(allHabitsDescriptor)
          // Check if any habits have non-empty userId (authenticated user data)
          let authenticatedHabits = allHabits.filter { !$0.userId.isEmpty }
          if !authenticatedHabits.isEmpty {
            let userIds = Set(authenticatedHabits.map { $0.userId })
            logger.info("🛑 Skipping UserDefaults migration - account data exists in SwiftData")
            return true
          }
        } catch {
          logger.warning("⚠️ Failed to check for existing habits: \(error.localizedDescription)")
        }
        return false
      }
      
      if hasHabitsForOtherUsers {
        return habits // Return empty array - don't migrate from UserDefaults
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

    // Cap history data to prevent unlimited growth
    let capper = await historyCapper
    let retentionMgr = await retentionManager
    let cappedHabits = capper.capAllHabits(habits, using: retentionMgr.currentPolicy)
    logger.debug("History capping applied to \(habits.count) habits")

    // ✅ FIX: Auto-clear end dates that are in the past to prevent validation warnings
    // BUT preserve recent end dates (within last 7 days) as they may be intentionally set
    // to mark habits as inactive
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? Date.distantPast
    
    func clearEndDate(_ habit: Habit) -> Habit {
      Habit(
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
        endDate: nil,
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

    func latestActivityDate(for habit: Habit) -> Date? {
      var dateKeys = Set<String>()
      dateKeys.formUnion(habit.completionHistory.keys)
      dateKeys.formUnion(habit.completionStatus.filter { $0.value }.map(\.key))
      dateKeys.formUnion(habit.completionTimestamps.keys)
      dateKeys.formUnion(habit.difficultyHistory.keys)
      guard let latestKey = dateKeys.max(),
            let date = DateUtils.date(from: latestKey) else {
        return nil
      }
      return date
    }

    let sanitizedHabits = cappedHabits.map { habit -> Habit in
      guard let endDate = habit.endDate, endDate < Date() else {
        return habit
      }
      
      let startOfEndDate = calendar.startOfDay(for: endDate)
      
      if endDate < sevenDaysAgo {
        return clearEndDate(habit)
      }
      
      if let latestActivityDate = latestActivityDate(for: habit),
         latestActivityDate > startOfEndDate {
        return clearEndDate(habit)
      }
      
      // Preserve recent end dates (within last 7 days) - these are intentionally set
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
    
    // ✅ CLOUD BACKUP: Backup habits to Firestore (non-blocking)
    // Only backup if user is authenticated (anonymous or otherwise)
    // ✅ CRITICAL BUG FIX: Filter out deleted habits before backing up
    await MainActor.run {
      for habit in sanitizedHabits {
        // Skip backup for deleted habits to prevent resurrection
        if !SyncEngine.isHabitDeleted(habit.id) {
          FirebaseBackupService.shared.backupHabit(habit)
        } else {
          logger.info("⏭️ HabitStore: Skipping backup for deleted habit '\(habit.name)'")
        }
      }
    }

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
    logger.info("Soft-deleting habit: \(habit.name)")

    // ✅ CRITICAL FIX: Mark habit as deleted FIRST (before any deletion operations)
    // This ensures we can filter it out even if soft-delete fails
    markHabitAsDeleted(habit.id)  // Store in UserDefaults (legacy)
    SyncEngine.markHabitAsDeleted(habit.id)  // Store in SyncEngine for sync prevention

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

    // TODO: Update Firestore to support soft delete (mark as deleted instead of hard delete)
    // For now, we still hard-delete from Firestore but soft-delete locally for audit trail
    await FirebaseBackupService.shared.deleteHabitBackupAwait(habitId: habit.id)
    
    // Delete completion records from Firestore
    await FirebaseBackupService.shared.deleteCompletionRecordsForHabitAwait(habitId: habit.id)
    
    // ✅ SOFT DELETE: This now soft-deletes (marks as deleted) instead of hard deleting
    try await activeStorage.deleteHabit(id: habit.id)

    // ✅ SOFT DELETE: Clean up UserDefaults (legacy system)
    // Note: This is less critical with soft delete, but still good for cleanup
    do {
      try await userDefaultsStorage.deleteHabit(id: habit.id)
      
      // Also ensure the SavedHabits array is updated
      var userDefaultsHabits = try await userDefaultsStorage.loadHabits()
      userDefaultsHabits.removeAll { $0.id == habit.id }
      if userDefaultsHabits.count != currentHabits.count {
        try await userDefaultsStorage.saveHabits(userDefaultsHabits, immediate: true)
      }
    } catch {
      // Don't fail the soft-delete if UserDefaults cleanup fails
    }

    // THEN save the updated array (without the soft-deleted habit)
    try await saveHabits(currentHabits)
    
    logger.info("Successfully soft-deleted habit: \(habit.name)")
  }

  func scheduledHabits(for date: Date) async throws -> [Habit] {
    let dateKey = DateUtils.dateKey(for: date)
    if let cache = scheduledHabitsCache, cache.dateKey == dateKey {
      return cache.habits
    }
    let allHabits = try await loadHabits()
    let filtered = allHabits.filter { habit in
      StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
    }
    scheduledHabitsCache = (dateKey: dateKey, habits: filtered)
    return filtered
  }

  // MARK: - Set Progress

  func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = DateUtils.dateKey(for: date)
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
      let goalAmount = currentHabits[index].goalAmount(for: date)
      
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
          logger.info("✅ setProgress: Created ProgressEvent successfully")
          logger.info("   → Event ID: \(event.id.prefix(20))...")
          logger.info("   → Event Type: \(eventType.rawValue)")
          logger.info("   → Progress Delta: \(progressDelta)")
          logger.info("   → Operation ID: \(event.operationId.prefix(20))...")
        } catch {
          // Track failure for monitoring (actor-isolated - update directly)
          self.eventCreationFailureCount += 1
          self.lastEventCreationFailure = Date()
          
          // Capture values for use in MainActor closure (actor isolation fix)
          let failureCount = self.eventCreationFailureCount
          let habitName = habit.name
          let habitIdString = habit.id.uuidString
          
          // Log detailed error
          logger.error("❌ setProgress: Failed to create ProgressEvent")
          logger.error("   Habit: \(habitName) (\(habit.id))")
          logger.error("   Date: \(dateKey)")
          logger.error("   Error: \(error.localizedDescription)")
          logger.error("   Failure count this session: \(failureCount)")
          
          // Track in Crashlytics for production monitoring
          // Must run on MainActor, use captured values to avoid actor isolation issues
          await MainActor.run {
            CrashlyticsService.shared.recordError(error, additionalInfo: [
              "operation": "createProgressEvent",
              "habitId": habitIdString,
              "dateKey": dateKey,
              "progressValue": String(progress),
              "failureCount": String(failureCount)
            ])
          }
          
          // Warn if seeing repeated failures (potential systemic issue)
          if failureCount >= 3 {
            logger.warning("⚠️ ALERT: Multiple ProgressEvent failures this session (\(failureCount))")
            logger.warning("   This may indicate a systemic issue with event creation")
          }
          
          // Continue with legacy path (backward compatibility)
        }
      }
      
      // ⚠️ DEPRECATED: Direct state update - kept for backward compatibility
      // TODO: [PHASE-5] Remove this once all code paths use event replay
      // See: Docs/Implementation/DEPRECATION_TRACKING.md for migration status
      // Progress should be calculated from ProgressEvents using calculateProgressFromEvents()
      currentHabits[index].completionHistory[dateKey] = progress
      let isComplete = progress >= goalAmount
      currentHabits[index].completionStatus[dateKey] = isComplete
      
      // Store completion status for backup call
      let completionStatusForBackup = isComplete
      
      // Logging with habit type info
      if habitType == .breaking {
        logger.info("   📊 Display-only: Target: \(currentHabits[index].target) | Baseline: \(currentHabits[index].baseline)")
      } else {
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

      // ✅ SYNC METADATA: Mark habit as needing re-sync whenever progress changes
      currentHabits[index].lastSyncedAt = nil
      currentHabits[index].syncStatus = .pending

      // ✅ PHASE 4: Streaks are now computed-only, no need to update them

      // ✅ FIX: Create CompletionRecord entries for SwiftData queries
      await createCompletionRecordIfNeeded(
        habit: currentHabits[index],
        date: date,
        dateKey: dateKey,
        progress: progress)

      try await saveHabits(currentHabits)
      logger.info("Successfully updated progress for habit '\(habit.name)' on \(dateKey)")
      
      // ✅ CLOUD BACKUP: Backup completion record to Firestore (non-blocking)
      await MainActor.run {
        FirebaseBackupService.shared.backupCompletionRecord(
          habitId: habit.id,
          date: date,
          dateKey: dateKey,
          isCompleted: completionStatusForBackup,
          progress: progress
        )
      }

      // ✅ FIX: Check daily completion and award/revoke XP AFTER all SwiftData saves are complete
      // This ensures checkDailyCompletionAndAwardXP queries fresh data, not stale CompletionRecords
      // ✅ PRIORITY 2: Check daily completion and award/revoke XP atomically
      // Reuse userId variable declared above
      do {
        try await checkDailyCompletionAndAwardXP(dateKey: dateKey, userId: userId)
      } catch {
        logger.error("❌ setProgress: Failed to check daily completion and award XP: \(error.localizedDescription)")
      }

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
    let dateKey = DateUtils.dateKey(for: date)
    let goalAmount = habit.goalAmount(for: date)
    
    // Get legacy progress from completionHistory (fallback)
    let legacyProgress = habit.completionHistory[dateKey] ?? 0
    
    // Calculate progress from events (event sourcing)
    // Note: ProgressEventService is @MainActor and accesses ModelContext internally
    let result = await ProgressEventService.shared.calculateProgressFromEvents(
      habitId: habit.id,
      dateKey: dateKey,
      goalAmount: goalAmount,
      legacyProgress: legacyProgress
    )
    
    return result.progress
  }

  // MARK: - Save Difficulty Rating

  func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) async throws {
    logger.info("Saving difficulty \(difficulty) for habit \(habitId) on \(date)")

    // Load current habits
    var currentHabits = try await loadHabits()

    if let index = currentHabits.firstIndex(where: { $0.id == habitId }) {
      currentHabits[index].recordDifficulty(Int(difficulty), for: date)
      
      // ✅ CRITICAL FIX: Save the specific habit immediately to ensure difficulty is persisted
      // Using saveHabit instead of saveHabits ensures difficulty history is properly synced
      try await activeStorage.saveHabit(currentHabits[index], immediate: true)
      
      // Also update all habits to keep them in sync
      try await saveHabits(currentHabits)
      
      logger.info("✅ Successfully saved difficulty \(difficulty) for habit \(habitId) on \(date)")
      logger.info("   Difficulty history now has \(currentHabits[index].difficultyHistory.count) entries")
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
      guard let date = DateUtils.date(from: dateString) else { continue }
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
        guard let date = DateUtils.date(from: dateString) else { continue }
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
  
  /// Clear the storage cache (e.g., after migration when data changes but userId doesn't)
  /// ✅ CRITICAL FIX: This ensures fresh data is loaded after migration completes
  func clearStorageCache() {
    // Clear UserAwareStorage cache to force fresh load
    // Access swiftDataStorage directly since it's a UserAwareStorage wrapper
    swiftDataStorage.clearCache()
    logger.info("✅ HabitStore: Cleared UserAwareStorage cache")
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
  
  // MARK: - Active Storage (Guest-Only Mode)
  
  /// Returns SwiftData storage for guest-only mode (no cloud sync)
  /// ✅ GUEST-ONLY MODE: Using SwiftData only, no Firestore sync
  private var activeStorage: any HabitStorageProtocol {
    get {
      return swiftDataStorage
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

  // CloudKit sync is disabled - infrastructure archived
  // private var cloudKitSyncManager: CloudKitSyncManager {
  //   get async {
  //     await MainActor.run { CloudKitSyncManager.shared }
  //   }
  // }

  // Conflict resolution disabled - infrastructure archived
  // private var conflictResolver: ConflictResolutionManager {
  //   get async {
  //     await MainActor.run { ConflictResolutionManager.shared }
  //   }
  // }

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

  /// Mark a habit as deleted in UserDefaults (safety mechanism)
  private func markHabitAsDeleted(_ habitId: UUID) {
    var deletedIds = UserDefaults.standard.stringArray(forKey: Self.deletedHabitsKey) ?? []
    let idString = habitId.uuidString
    if !deletedIds.contains(idString) {
      deletedIds.append(idString)
      UserDefaults.standard.set(deletedIds, forKey: Self.deletedHabitsKey)
      UserDefaults.standard.synchronize()
    }
  }
  
  /// Check if a habit is marked as deleted
  private func isHabitMarkedAsDeleted(_ habitId: UUID) -> Bool {
    let deletedIds = UserDefaults.standard.stringArray(forKey: Self.deletedHabitsKey) ?? []
    return deletedIds.contains(habitId.uuidString)
  }
  
  /// Unmark a habit as deleted (for restore/undo operations)
  func unmarkHabitAsDeleted(_ habitId: UUID) {
    var deletedIds = UserDefaults.standard.stringArray(forKey: Self.deletedHabitsKey) ?? []
    let idString = habitId.uuidString
    if let index = deletedIds.firstIndex(of: idString) {
      deletedIds.remove(at: index)
      UserDefaults.standard.set(deletedIds, forKey: Self.deletedHabitsKey)
      UserDefaults.standard.synchronize()
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
    
    do {
      // Perform all SwiftData operations on the main actor to avoid concurrency issues
      try await MainActor.run {
        let modelContext = SwiftDataContainer.shared.modelContext

        // ✅ CRITICAL FIX: Removed database health check to prevent corruption
        // Health check was deleting database while in use
        // Database corruption is now handled gracefully with UserDefaults fallback

        // Check if CompletionRecord already exists
        let predicate = #Predicate<CompletionRecord> { record in
          record.userId == userId &&
            record.habitId == habit.id &&
            record.dateKey == dateKey
        }
        let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
        let existingRecords: [CompletionRecord] = try modelContext.fetch(request)

        // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
        // Prefer the recorded completion status for this date to avoid retroactively changing history.
        let recordedStatus = habit.completionStatus[dateKey]
        let goalAmount = habit.goalAmount(for: date)
        let isCompleted = recordedStatus ?? (progress >= goalAmount)
        
        // Debug logging with habit type
        let habitTypeStr = habit.habitType == .breaking ? "breaking" : "formation"
        if habit.habitType == .breaking {
          logger.info("🔍 BREAKING HABIT CHECK - '\(habit.name)' (id=\(habit.id)) | Progress: \(progress) | Goal: \(goalAmount) | Complete: \(isCompleted)")
          logger.info("   📊 Display-only fields: Target: \(habit.target) | Baseline: \(habit.baseline)")
        } else {
        }
        
        logger.info("🎯 CREATE_RECORD: habitType=\(habitTypeStr), progress=\(progress), goal=\(goalAmount), isCompleted=\(isCompleted)")

        // ✅ FIX: Handle duplicate CompletionRecords by deleting all and creating fresh one
        // This ensures exactly ONE CompletionRecord per habit/date/user, preventing XP calculation bugs
        if !existingRecords.isEmpty {
          if existingRecords.count > 1 {
            logger.warning("⚠️ createCompletionRecordIfNeeded: Found \(existingRecords.count) duplicate CompletionRecords for habit '\(habit.name)' on \(dateKey) - deleting duplicates")
          }
          
          // Delete ALL existing records (handles duplicates)
          for existingRecord in existingRecords {
            modelContext.delete(existingRecord)
          }
        }
        
        // Always create a fresh record with current state (ensures exactly one record)
        // Create new record (or recreate after deletion)
        let completionRecord = CompletionRecord(
          userId: userId,
          habitId: habit.id,
          date: date,
          dateKey: dateKey,
          isCompleted: isCompleted,
          progress: progress)  // ✅ CRITICAL FIX: Store progress count
        
        // ✅ CRITICAL FIX: Always insert CompletionRecord first, then link to HabitData
        // This ensures the record exists even if HabitData lookup fails
        modelContext.insert(completionRecord)
        
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

        // Save the context
        try modelContext.save()
        
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
          "❌ Failed to create/update CompletionRecord: \(error)")
      logger.error("❌ Error details: \(error.localizedDescription)")

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
          logger.info("🔧 HabitStore: Resetting corrupted database for next app launch")
          
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
    // ✅ CRITICAL: Clear cache to avoid stale progress values
    scheduledHabitsCache = nil
    
    // Parse date from dateKey
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    guard let date = dateFormatter.date(from: dateKey) else {
      logger.error("❌ XP_CHECK: Invalid dateKey format: \(dateKey)")
      return
    }
    
    // ✅ FIX: Force reload habits from storage to get fresh data after save
    let freshHabits = try await loadHabits(force: true)
    
    // Get scheduled habits from fresh data
    let scheduledHabits = freshHabits.filter { habit in
      StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
    }
    
    // Clear cache since we just loaded fresh
    scheduledHabitsCache = (dateKey: dateKey, habits: scheduledHabits)
    
    guard !scheduledHabits.isEmpty else {
      return
    }
    
    // ✅ SKIP FEATURE: Filter out skipped habits from daily completion check
    let activeHabits = scheduledHabits.filter { !$0.isSkipped(for: date) }
    let skippedCount = scheduledHabits.count - activeHabits.count
    
    if skippedCount > 0 {
      for habit in scheduledHabits where habit.isSkipped(for: date) {
        _ = habit.skipReason(for: date)?.shortLabel ?? "unknown"
      }
    }
    
    guard !activeHabits.isEmpty else {
      // All habits were skipped - treat as complete day
      
      // Check for existing award and process accordingly
      let (awardExists, _): (Bool, Int) = await MainActor.run {
        let modelContext = SwiftDataContainer.shared.modelContext
        
        let awardPredicate = #Predicate<DailyAward> { award in
          award.userId == userId && award.dateKey == dateKey
        }
        var awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
        awardDescriptor.includePendingChanges = true
        let awards = (try? modelContext.fetch(awardDescriptor)) ?? []
        let exists = !awards.isEmpty
        let xpAmount = awards.first?.xpGranted ?? 50
        
        return (exists, xpAmount)
      }
      
      if !awardExists {
        // Award XP for all-skipped day
        let xpAmount = 50
        do {
          let awardReason = "All habits skipped on \(dateKey) - day complete"
          try await DailyAwardService.shared.awardXP(
            delta: xpAmount,
            dateKey: dateKey,
            reason: awardReason
          )
          
          await MainActor.run {
            FirebaseBackupService.shared.backupDailyAward(
              dateKey: dateKey,
              xpGranted: xpAmount,
              allHabitsCompleted: true
            )
          }
        } catch {
          logger.error("❌ XP_CHECK: Failed to award XP: \(error.localizedDescription)")
        }
      }
      return
    }
    
    // ✅ STREAK MODE: Use meetsStreakCriteria to check completion for XP purposes
    let (allCompleted, _): (Bool, [String]) = await MainActor.run {
      // Check each active (non-skipped) habit using meetsStreakCriteria (respects Streak Mode)
      let incompleteHabits = activeHabits
        .filter { !$0.meetsStreakCriteria(for: date) }
        .map(\.name)
      let allDone = incompleteHabits.isEmpty
      return (allDone, incompleteHabits)
    }
    
    // Check if award already exists (synchronous MainActor work)
    // ✅ FIX: Only return Sendable types (Bool, Int) to avoid concurrency warnings
    // ✅ FIX: Include pending changes to see DailyAward that was just created/deleted
    let (awardExists, xpToReverse): (Bool, Int) = await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      let awardPredicate = #Predicate<DailyAward> { award in
        award.userId == userId && award.dateKey == dateKey
      }
      var awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
      awardDescriptor.includePendingChanges = true  // ✅ FIX: See just-saved/deleted awards
      let awards = (try? modelContext.fetch(awardDescriptor)) ?? []
      let exists = !awards.isEmpty
      let xpAmount = awards.first?.xpGranted ?? 50  // Extract value on MainActor
      
      return (exists, xpAmount)  // Return Sendable types only
    }
    
    if allCompleted && !awardExists {
      // All habits complete AND award doesn't exist → award XP
      
      // ✅ FIX: DailyAwardService creates DailyAward record and recalculates XP
      // DailyAward is the immutable ledger entry (source of truth)
      // UserProgressData is derived from sum(DailyAward.xpGranted)
      let xpAmount = 50 // Standard daily completion bonus
      do {
        let awardReason = "All habits completed on \(dateKey)"
        try await DailyAwardService.shared.awardXP(
          delta: xpAmount,
          dateKey: dateKey,
          reason: awardReason
        )
        
        // ✅ CLOUD BACKUP: Backup daily award to Firestore (non-blocking)
        await MainActor.run {
          FirebaseBackupService.shared.backupDailyAward(
            dateKey: dateKey,
            xpGranted: xpAmount,
            allHabitsCompleted: true
          )
        }
      } catch {
        logger.error("❌ XP_CHECK: Failed to award XP: \(error.localizedDescription)")
        // XP award failed - don't proceed (maintain consistency)
        // User can retry by completing habits again
        return
      }
      
    } else if !allCompleted && awardExists {
      // NOT all complete AND award exists → reverse XP
      
      // ✅ FIX: DailyAwardService deletes DailyAward record and recalculates XP
      // This ensures ledger and state stay in sync
      do {
        let reversalReason = "Habit uncompleted on \(dateKey) - reversing daily completion bonus"
        try await DailyAwardService.shared.awardXP(
          delta: -xpToReverse,
          dateKey: dateKey,
          reason: reversalReason
        )
        
        // ✅ FIX: Delete invalid award from Firestore so it doesn't get re-imported
        // This prevents the flickering issue where invalid awards are re-imported during sync
        Task.detached(priority: .utility) { [self] in
          await self.deleteInvalidAwardFromFirestore(dateKey: dateKey, userId: userId)
          logger.info("✅ XP_CHECK: Invalid award deleted from Firestore - will not be re-imported")
        }
      } catch {
        logger.error("❌ XP_CHECK: Failed to reverse XP: \(error.localizedDescription)")
        // XP reversal failed - log but don't block (better than losing both)
        // User can repair integrity later via DailyAwardService.checkAndRepairIntegrity()
      }
      
      // ✅ REMOVED: DailyAward deletion - handled by DailyAwardService.awardXP() now
      
    }
  }
  
  /// Delete an invalid DailyAward from Firestore
  /// This prevents invalid awards from being re-imported on future syncs
  private func deleteInvalidAwardFromFirestore(dateKey: String, userId: String) async {
    // Skip if guest user (no Firestore)
    guard !CurrentUser.isGuestId(userId) else {
      return
    }
    
    let userIdDateKey = "\(userId)#\(dateKey)"
    let db = Firestore.firestore()
    let awardRef = db.collection("users")
      .document(userId)
      .collection("daily_awards")
      .document(userIdDateKey)
    
    do {
      try await awardRef.delete()
    } catch {
      logger.warning("⚠️ Failed to delete invalid DailyAward from Firestore: \(error.localizedDescription)")
      // Don't throw - this is cleanup, not critical
    }
  }
  
  // MARK: - ProgressEvent Failure Diagnostics
  
  /// Get the number of ProgressEvent creation failures this session
  /// Useful for diagnostics and debugging
  func getEventCreationFailureCount() -> Int {
    eventCreationFailureCount
  }
  
  /// Get the last time an event creation failed
  func getLastEventCreationFailure() -> Date? {
    lastEventCreationFailure
  }
  
  // MARK: - Soft Delete Recovery Methods
  
  /// Load soft-deleted habits for the current user (for Recently Deleted view)
  func loadSoftDeletedHabits() async throws -> [Habit] {
    logger.info("Loading soft-deleted habits from storage...")
    let habits = try await activeStorage.loadSoftDeletedHabits()
    logger.info("Loaded \(habits.count) soft-deleted habits")
    return habits
  }
  
  /// Count soft-deleted habits for the current user
  func countSoftDeletedHabits() async throws -> Int {
    let count = try await activeStorage.countSoftDeletedHabits()
    return count
  }
  
  /// Permanently delete a habit (hard delete from SwiftData)
  func permanentlyDeleteHabit(id: UUID) async throws {
    logger.info("Permanently deleting habit with ID: \(id)")
    try await activeStorage.permanentlyDeleteHabit(id: id)
    logger.info("Successfully permanently deleted habit with ID: \(id)")
  }
}
