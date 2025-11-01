import Foundation
import OSLog
import SwiftData
import SwiftUI

// MARK: - MigrationRunner

/// Handles migration from legacy storage to normalized SwiftData
@MainActor
final class MigrationRunner {
  // MARK: Lifecycle

  private init() {
    self.featureFlags = FeatureFlagManager.shared.provider
  }

  init(featureFlags: FeatureFlagProvider) {
    self.featureFlags = featureFlags
  }

  // MARK: Internal

  static let shared = MigrationRunner()

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

    if migrationState.isCompleted, !featureFlags.forceMigration {
      logger.info("MigrationRunner: Migration already completed for user \(userId)")
      return
    }

    // Run the migration
    try await runMigration(userId: userId, context: context, state: migrationState)
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationRunner")
  private let featureFlags: FeatureFlagProvider

  // MARK: - Private Migration Logic

  private func runMigration(
    userId: String,
    context: ModelContext,
    state: MigrationState) async throws
  {
    logger.info("MigrationRunner: Starting migration for user \(userId)")

    // Log migration start
    let startTime = Date()
    ObservabilityLogger.shared.logMigrationStart(userId: userId, version: state.migrationVersion)

    // Mark migration as in progress
    let migrationState = state
    migrationState.markInProgress()
    try context.save()

    do {
      // Step 1: Migrate habits from UserDefaults
      let habits = try await migrateHabits(userId: userId, context: context)

      // Step 2: Migrate completion records
      let completionCount = try await migrateCompletionRecords(
        habits: habits,
        userId: userId,
        context: context)

      // Step 3: Migrate daily awards
      let awardCount = try await migrateDailyAwards(userId: userId, context: context)

      // Step 4: Migrate user progress
      try await migrateUserProgress(userId: userId, context: context)

      // Mark migration as completed
      migrationState.markCompleted(recordsCount: completionCount + awardCount)
      try context.save()

      logger
        .info(
          "MigrationRunner: Migration completed for user \(userId) - \(completionCount + awardCount) records migrated")

      // Log migration end
      let duration = Date().timeIntervalSince(startTime)
      ObservabilityLogger.shared.logMigrationEnd(
        userId: userId,
        version: migrationState.migrationVersion,
        success: true,
        recordsCount: completionCount + awardCount,
        duration: duration)

    } catch {
      // Mark migration as failed
      migrationState.markFailed(error: error)
      try context.save()

      logger
        .error(
          "MigrationRunner: Migration failed for user \(userId): \(error.localizedDescription)")

      // Log migration error
      ObservabilityLogger.shared.logMigrationError(
        userId: userId,
        version: migrationState.migrationVersion,
        error: error)

      throw error
    }
  }

  private func migrateHabits(userId: String, context: ModelContext) async throws -> [Habit] {
    logger.info("MigrationRunner: Migrating habits for user \(userId)")

    // Try loading habits from UserDefaults first (legacy storage)
    var habits = try await loadLegacyHabits()
    
    // If no habits found in UserDefaults, load from SwiftData (habits already migrated)
    if habits.isEmpty {
      logger.info("MigrationRunner: No habits in UserDefaults, loading from SwiftData for completionHistory migration")
      habits = try await loadHabitsFromSwiftData(userId: userId, context: context)
    }

    var migratedCount = 0
    var reassignedCount = 0

    for habit in habits {
      // Check if habit already exists in SwiftData with the correct userId
      let existingRequest = FetchDescriptor<HabitData>(
        predicate: #Predicate { $0.id == habit.id && $0.userId == userId })
      let existing = try context.fetch(existingRequest)

      if existing.isEmpty {
        // Check if habit exists with a different userId (guest habits that need reassignment)
        let anyExistingRequest = FetchDescriptor<HabitData>(
          predicate: #Predicate { $0.id == habit.id })
        let anyExisting = try context.fetch(anyExistingRequest)
        
        if let existingHabitData = anyExisting.first {
          // Habit exists but with wrong userId - reassign it
          let oldUserId = existingHabitData.userId
          existingHabitData.userId = userId
          reassignedCount += 1
          logger.info("MigrationRunner: Reassigned habit '\(habit.name)' from userId '\(oldUserId)' to '\(userId)'")
        } else {
          // Create new HabitData from legacy Habit
          let habitData = HabitData(
            id: habit.id,
            userId: userId,
            name: habit.name,
            habitDescription: habit.description,
            icon: habit.icon,
            color: habit.color.color,
            habitType: habit.habitType,
            schedule: habit.schedule,
            goal: habit.goal,
            reminder: habit.reminder,
            startDate: habit.startDate,
            endDate: habit.endDate
            // isCompleted: habit.isCompleted,  // ❌ DEPRECATED: Use isCompleted(for:) instead
            // streak: habit.streak  // ❌ DEPRECATED: Use computedStreak() instead
          )

          context.insert(habitData)
          migratedCount += 1
        }
      }
    }

    if migratedCount > 0 || reassignedCount > 0 {
      try context.save()
      if migratedCount > 0 {
        logger.info("MigrationRunner: Migrated \(migratedCount) new habits for user \(userId)")
      }
      if reassignedCount > 0 {
        logger.info("MigrationRunner: Reassigned \(reassignedCount) existing habits to user \(userId)")
      }
    } else {
      logger.info("MigrationRunner: All habits already exist in SwiftData for user \(userId)")
    }

    return habits
  }
  
  /// Load habits from SwiftData (for migration scenarios where habits are already in SwiftData)
  /// Also checks for habits stored under guest/empty userId to handle data migration scenarios
  private func loadHabitsFromSwiftData(userId: String, context: ModelContext) async throws -> [Habit] {
    logger.info("MigrationRunner: Loading habits from SwiftData for user \(userId)")
    
    // First try to load habits for the current userId
    var descriptor = FetchDescriptor<HabitData>(
      predicate: #Predicate { $0.userId == userId }
    )
    
    var habitDataArray = try context.fetch(descriptor)
    logger.info("MigrationRunner: Found \(habitDataArray.count) habits for userId '\(userId)'")
    
    // If no habits found for current user, also check for guest/empty userId habits
    // This handles scenarios where habits were created before authentication
    if habitDataArray.isEmpty {
      logger.info("MigrationRunner: No habits found for current userId, checking for guest/empty userId habits")
      
      // Check for empty userId (guest habits)
      descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { $0.userId == "" }
      )
      let guestHabits = try context.fetch(descriptor)
      logger.info("MigrationRunner: Found \(guestHabits.count) habits with empty userId (guest)")
      
      // Also check for "guest" userId
      descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { $0.userId == "guest" }
      )
      let guestIdHabits = try context.fetch(descriptor)
      logger.info("MigrationRunner: Found \(guestIdHabits.count) habits with userId 'guest'")
      
      // Combine all guest habits
      habitDataArray = guestHabits + guestIdHabits
      
      if !habitDataArray.isEmpty {
        logger.info("MigrationRunner: ⚠️ Found \(habitDataArray.count) guest habits - these will be migrated to userId '\(userId)'")
      }
    }
    
    let habits = habitDataArray.map { $0.toHabit() }
    
    logger.info("MigrationRunner: Loaded \(habits.count) total habits from SwiftData")
    return habits
  }

  private func migrateCompletionRecords(
    habits: [Habit],
    userId: String,
    context: ModelContext) async throws -> Int
  {
    logger.info("MigrationRunner: Migrating completionHistory to ProgressEvent records for user \(userId)")
    
    var migratedCount = 0
    let deviceId = DeviceIdProvider.shared.currentDeviceId
    
    // Parse dateKey format (yyyy-MM-dd)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    
    for habit in habits {
      guard !habit.completionHistory.isEmpty else {
        logger.info("MigrationRunner: Habit '\(habit.name)' has no completion history, skipping")
        continue
      }
      
      logger.info("MigrationRunner: Migrating \(habit.completionHistory.count) completion entries for habit '\(habit.name)'")
      
      for (dateKeyString, progress) in habit.completionHistory {
        // Skip zero progress (no event needed)
        guard progress > 0 else {
          continue
        }
        
        // Parse date from dateKey
        guard let date = dateFormatter.date(from: dateKeyString) else {
          logger.warning("MigrationRunner: Invalid dateKey format: \(dateKeyString), skipping")
          continue
        }
        
        // Check if event already exists for this habit+date (idempotency)
        let existingEventDescriptor = ProgressEvent.eventsForHabitDate(
          habitId: habit.id,
          dateKey: dateKeyString
        )
        let existingEvents = (try? context.fetch(existingEventDescriptor)) ?? []
        
        // Skip if events already exist (already migrated or user has been creating events)
        if !existingEvents.isEmpty {
          logger.info("MigrationRunner: Events already exist for habit '\(habit.name)' on \(dateKeyString), skipping")
          continue
        }
        
        // Generate deterministic operationId for migration events
        let operationId = "migration_\(habit.id.uuidString)_\(dateKeyString)"
        
        // Check if event with this operationId already exists
        let operationIdDescriptor = ProgressEvent.eventByOperationId(operationId)
        let existingByOperationId = (try? context.fetch(operationIdDescriptor)) ?? []
        
        if !existingByOperationId.isEmpty {
          logger.info("MigrationRunner: Migration event already exists with operationId \(operationId), skipping")
          continue
        }
        
        // Calculate UTC day boundaries for timezone safety
        let calendar = Calendar.current
        let timezone = TimeZone.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
          logger.warning("MigrationRunner: Failed to calculate day end for \(dateKeyString), skipping")
          continue
        }
        
        let utcDayStart = dayStart.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayStart)))
        let utcDayEnd = dayEnd.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayEnd)))
        
        // Get deterministic sequence number for migration events
        // MigrationRunner is @MainActor, so can call EventSequenceCounter directly
        let sequenceNumber = EventSequenceCounter.shared.nextSequence(deviceId: deviceId, dateKey: dateKeyString)
        
        // Create synthetic ProgressEvent for migration
        // Use .bulkAdjust event type to indicate this is a migration event
        let event = ProgressEvent(
          habitId: habit.id,
          dateKey: dateKeyString,
          eventType: .bulkAdjust,
          progressDelta: progress, // Set to absolute progress value
          userId: userId,
          deviceId: deviceId,
          timezoneIdentifier: timezone.identifier,
          utcDayStart: utcDayStart,
          utcDayEnd: utcDayEnd,
          sequenceNumber: sequenceNumber,
          note: "Migrated from completionHistory",
          metadata: "{\"migration\": true, \"source\": \"completionHistory\"}",
          operationId: operationId // Use deterministic migration ID for idempotency
        )
        
        // Mark as unsynced so SyncEngine will upload it
        event.synced = false
        event.isRemote = false
        
        // Insert event
        context.insert(event)
        migratedCount += 1
        
        logger.info("MigrationRunner: Created ProgressEvent for habit '\(habit.name)' on \(dateKeyString) with progress \(progress)")
      }
    }
    
    // Save all events
    try context.save()
    logger.info("MigrationRunner: ✅ Migrated \(migratedCount) completionHistory entries to ProgressEvent records")
    logger.info("MigrationRunner: ⚠️ completionHistory fields preserved for rollback safety")

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

    if legacyProgress.totalXP > 0 {
      // Create a daily award for today with the total XP
      let today = Date()
      let dateKey = DateKey.key(for: today)

      // Check if daily award already exists
      let existingRequest = FetchDescriptor<DailyAward>(
        predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey })
      let existing = try context.fetch(existingRequest)

      if existing.isEmpty {
        let dailyAward = DailyAward(
          userId: userId,
          dateKey: dateKey,
          xpGranted: legacyProgress.totalXP,
          allHabitsCompleted: true)

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
    let existingRequest = FetchDescriptor<UserProgressData>(
      predicate: #Predicate { $0.userId == userId })
    let existing = try context.fetch(existingRequest)

    if existing.isEmpty {
      // Load legacy progress from UserDefaults
      let userDefaults = UserDefaults.standard
      if let progressData = userDefaults.data(forKey: "user_progress"),
         let legacyProgress = try? JSONDecoder().decode(UserProgress.self, from: progressData)
      {
        // Create new UserProgress with migrated data
        let userProgress = UserProgressData(userId: userId)
        userProgress.xpTotal = legacyProgress.totalXP
        userProgress.level = legacyProgress.currentLevel
        userProgress.xpForCurrentLevel = legacyProgress.xpForCurrentLevel
        userProgress.xpForNextLevel = legacyProgress.xpForNextLevel
        userProgress.dailyXP = legacyProgress.dailyXP
        userProgress.lastCompletedDate = legacyProgress.lastCompletedDate
        userProgress.streakDays = legacyProgress.streakDays

        context.insert(userProgress)
        try context.save()

        logger.info("MigrationRunner: Migrated user progress for user \(userId)")
      } else {
        // Create default user progress
        let userProgress = UserProgressData(userId: userId)
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
          logger
            .error(
              "MigrationRunner: Failed to decode habits from key \(key): \(error.localizedDescription)")
        }
      }
    }

    logger.info("MigrationRunner: No legacy habits found")
    return []
  }

  private func encodeColor(_: Color) throws -> Data {
    // This is a simplified implementation
    // In a real app, you'd need proper color encoding
    Data()
  }

  private func getModelContext(for _: String) async throws -> ModelContext {
    // For now, use the shared container
    // In Phase 3, this will be user-scoped
    ModelContext(SwiftDataContainer.shared.modelContainer)
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
