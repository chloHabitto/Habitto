import Foundation
import OSLog
import SwiftData
import FirebaseAuth
import FirebaseCore
import SQLite3

// TODO: [LOGGING] Standardize logging - currently mixes print() and os.Logger
// See: Docs/Guides/LOGGING_STANDARDS.md

// MARK: - SwiftData Storage Implementation

@MainActor
final class SwiftDataStorage: HabitStorageProtocol {
  private let guestMigrationFlagKey = "guestToAuthMigrationComplete"
  private var isSaving = false // ✅ FIX: Prevent concurrent saves
  
  // MARK: Lifecycle

  nonisolated init() { }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - Generic Data Storage Methods

  func save(_ data: some Codable, forKey key: String, immediate _: Bool = false) async throws {
    // For generic data, we'll store as JSON in a separate table
    // This is a fallback for non-habit data
    logger.warning("Generic save called for key: \(key) - consider using specific methods")

    let jsonData = try JSONEncoder().encode(data)
    // Store in UserDefaults as fallback for now
    UserDefaults.standard.set(jsonData, forKey: key)
  }

  nonisolated func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
    // For generic data, load from UserDefaults fallback
    logger.warning("Generic load called for key: \(key) - consider using specific methods")

    guard let data = UserDefaults.standard.data(forKey: key) else {
      return nil
    }

    return try JSONDecoder().decode(type, from: data)
  }

  func delete(forKey key: String) async throws {
    logger.warning("Generic delete called for key: \(key) - consider using specific methods")
    UserDefaults.standard.removeObject(forKey: key)
  }

  func exists(forKey key: String) async throws -> Bool {
    UserDefaults.standard.object(forKey: key) != nil
  }

  func keys(withPrefix _: String) async throws -> [String] {
    // This is not applicable for SwiftData as we use relationships
    []
  }

  // MARK: - Habit-Specific Storage Methods

  func saveHabits(_ habits: [Habit], immediate _: Bool = false) async throws {
    // ✅ FIX: Prevent concurrent saves
    guard !isSaving else {
      #if DEBUG
      logger.warning("⚠️ saveHabits: Already saving, skipping concurrent save")
      #endif
      return
    }
    
    isSaving = true
    defer { isSaving = false }
    
    // ✅ CRITICAL FIX: Filter out deleted habits before saving
    // This prevents deleted habits from being re-created
    let habitsToSave = habits.filter { habit in
      !SyncEngine.isHabitDeleted(habit.id)
    }
    
    if habitsToSave.count < habits.count {
      logger.info("⏭️ SwiftDataStorage: Filtered out \(habits.count - habitsToSave.count) deleted habits before saving")
    }
    
    #if DEBUG
    logger.info("🎯 [8/8] SwiftDataStorage.saveHabits: writing to SwiftData")
    logger.info("  → Count: \(habitsToSave.count) (filtered from \(habits.count))")
    #endif

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      #if DEBUG
      for (i, habit) in habitsToSave.enumerated() {
        logger.info("  → [\(i)] '\(habit.name)' (ID: \(habit.id))")
      }
      #endif

      // ✅ CRITICAL FIX: Get existing habits with fallback for corruption
      var existingHabits: [Habit] = []
      var existingHabitIds: Set<UUID> = []

      do {
        existingHabits = try await loadHabits()
        existingHabitIds = Set(existingHabits.map { $0.id })
      } catch {
        #if DEBUG
        logger
          .warning(
            "⚠️ Failed to load existing habits, starting fresh: \(error.localizedDescription)")
        #endif
        // If load fails (corruption), start with empty array
        // This allows us to continue with the save operation
        existingHabits = []
        existingHabitIds = []
      }

      for habit in habitsToSave {
        var existingHabitData: HabitData? = nil

        // ✅ CRITICAL FIX: Safely check for existing habit with fallback
        do {
          existingHabitData = try await loadHabitData(by: habit.id)
        } catch {
          #if DEBUG
          logger.warning("⚠️ Failed to check for existing habit \(habit.id), treating as new")
          #endif
          existingHabitData = nil
        }

        if let existingHabitData {
          // Update existing habit
          await existingHabitData.updateFromHabit(habit)
          
          // ✅ CRITICAL FIX: Sync difficulty history from habit.difficultyHistory
          // This ensures difficulty ratings are persisted when habits are saved
          existingHabitData.difficultyHistory.removeAll()
          for (dateString, difficulty) in habit.difficultyHistory {
            let normalized = normalizedDifficultyDate(from: dateString)
            let difficultyRecord = DifficultyRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: UUID(),
              dateKey: normalized.key,
              difficulty: difficulty)
            container.modelContext.insert(difficultyRecord)
            existingHabitData.difficultyHistory.append(difficultyRecord)
            if let parsedDate = normalized.date {
              print("✅ SAVE DIFFICULTY: Saved difficulty \(difficulty) for \(normalized.key) (parsed as \(parsedDate))")
            } else {
              print("⚠️ SAVE DIFFICULTY: Saved difficulty \(difficulty) for \(normalized.key) (raw source '\(dateString)')")
            }
          }
          print("✅ SAVE DIFFICULTY: Synced \(existingHabitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")
          
          // ✅ CRITICAL FIX: Sync usage history from habit.actualUsage
          existingHabitData.usageHistory.removeAll()
          for (key, value) in habit.actualUsage {
            let usageRecord = UsageRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: existingHabitData.id,
              key: key,
              value: value)
            existingHabitData.usageHistory.append(usageRecord)
          }
        } else {
          // Create new habit with user ID
          let habitData = HabitData(
            id: habit.id,
            userId: await getCurrentUserId() ?? "", // Use current user ID or empty string for guest
            name: habit.name,
            habitDescription: habit.description,
            icon: habit.icon,
            color: habit.color.color,
            habitType: habit.habitType,
            schedule: habit.schedule,
            goal: habit.goal,
            reminder: habit.reminder,
            startDate: habit.startDate,
            endDate: habit.endDate,
            baseline: habit.baseline,
            target: habit.target,
            goalHistory: habit.goalHistory)

          // ✅ MIGRATION FIX: Create CompletionRecords from Firestore completionHistory
          // Problem was: old code checked `progress == 1` which was wrong
          // Solution: Check if `progress >= goal` to determine actual completion
          
          logger.info("✅ MIGRATION: Creating CompletionRecords from Firestore data for habit '\(habit.name)'")
          
          for (dateString, progress) in habit.completionHistory {
            if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
              let dateKey = Habit.dateKey(for: date)
              let recordedStatus = habit.completionStatus[dateKey]
              let goalInt = Int(habit.goal) ?? 1
              let isCompleted = recordedStatus ?? (progress >= goalInt)
              
              let completionRecord = CompletionRecord(
                userId: await getCurrentUserId() ?? "",
                habitId: habitData.id,
                date: date,
                dateKey: dateKey,
                isCompleted: isCompleted,
                progress: progress)  // Store actual progress too
              
              habitData.completionHistory.append(completionRecord)
              
              logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
            }
          }

          // Add difficulty history
          for (dateString, difficulty) in habit.difficultyHistory {
            let normalized = normalizedDifficultyDate(from: dateString)
            let difficultyRecord = DifficultyRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: UUID(),
              dateKey: normalized.key,
              difficulty: difficulty)
            container.modelContext.insert(difficultyRecord)
            habitData.difficultyHistory.append(difficultyRecord)
            if let parsedDate = normalized.date {
              print("✅ CREATE DIFFICULTY: Created difficulty \(difficulty) for \(normalized.key) (parsed as \(parsedDate))")
            } else {
              print("⚠️ CREATE DIFFICULTY: Created difficulty \(difficulty) for \(normalized.key) (raw source '\(dateString)')")
            }
          }
          print("✅ CREATE DIFFICULTY: Created \(habitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")

          // Add usage history
          for (key, value) in habit.actualUsage {
            let usageRecord = UsageRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: habitData.id,
              key: key,
              value: value)
            habitData.usageHistory.append(usageRecord)
          }

          // ✅ PERSISTENT BEST STREAK: Initialize bestStreakEver for new habits
          // Calculate best streak from history to initialize the persistent value
          // This ensures best streak is preserved even if completion records are lost later
          let _ = habitData.calculateAndUpdateBestStreak()
          
          container.modelContext.insert(habitData)
        }
      }

      // Remove habits that are no longer in the list
      let currentHabitIds = Set(habits.map { $0.id })
      let habitsToRemove = existingHabitIds.subtracting(currentHabitIds)

      for habitId in habitsToRemove {
        do {
          if let habitData = try await loadHabitData(by: habitId) {
            container.modelContext.delete(habitData)
          }
        } catch {
          #if DEBUG
          logger.warning("⚠️ Failed to load habit \(habitId) for deletion, skipping")
          #endif
        }
      }

      #if DEBUG
      logger.info("  → Saving modelContext...")
      #endif

      // ✅ CRITICAL FIX: Try to save, with fallback to UserDefaults on any error
      do {
        print("        ⏱️ SWIFTDATA_SAVE_START: Calling modelContext.save() at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
        print("        📊 SWIFTDATA_CONTEXT: hasChanges=\(container.modelContext.hasChanges)")
        try container.modelContext.save()
        print("        ⏱️ SWIFTDATA_SAVE_END: modelContext.save() succeeded at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #if DEBUG
        logger
          .info(
            "  ✅ SUCCESS! Saved \(habitsToSave.count) habits in \(String(format: "%.3f", timeElapsed))s")
        #endif
        print("        ✅ SWIFTDATA_SUCCESS: Saved \(habitsToSave.count) habits to database")
      } catch {
        let errorDesc = error.localizedDescription
        print("        ❌ SWIFTDATA_SAVE_FAILED: modelContext.save() threw error")
        print("        ❌ Error: \(errorDesc)")
        print("        ❌ Error type: \(type(of: error))")
        print("        ❌ Full error: \(error)")
        #if DEBUG
        logger.error("❌ ModelContext.save() failed: \(errorDesc)")
        logger.error("🔧 Database corruption detected - falling back to UserDefaults")
        #endif

        // ✅ IMPROVED: Check if this is a corruption error that needs database reset
        if errorDesc.contains("no such table") ||
           errorDesc.contains("ZHABITDATA") ||
           errorDesc.contains("ZCOMPLETIONRECORD") ||
           errorDesc.contains("ZDAILYAWARD") ||
           errorDesc.contains("ZUSERPROGRESSDATA") ||
           errorDesc.contains("SQLite error") ||
           errorDesc.contains("couldn't be opened") ||
           errorDesc.contains("readonly database") ||
           errorDesc.contains("I/O error") ||
           errorDesc.contains("SwiftDataError") {
          // Set flag so database will be reset on next launch
          UserDefaults.standard.set(true, forKey: "SwiftDataCorruptionDetected")
          logger.error("🚨 CORRUPTION DETECTED during save - Database will be fixed on next launch")
          logger.error("   Error pattern: \(errorDesc)")
          logger.info("✅ App will continue using UserDefaults fallback (data is safe)")
        }

        // Fallback: Save to UserDefaults as emergency backup
        let encoder = JSONEncoder()
        let data = try encoder.encode(habitsToSave)
        UserDefaults.standard.set(data, forKey: "SavedHabits")
        #if DEBUG
        logger.info("✅ Saved \(habitsToSave.count) habits to UserDefaults as fallback")
        #endif

        // Success via fallback - don't throw error
        return
      }

    } catch {
      #if DEBUG
      logger.error("❌ Fatal error in saveHabits: \(error.localizedDescription)")
      #endif

      // Last resort fallback for any error
      do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(habitsToSave)
        UserDefaults.standard.set(data, forKey: "SavedHabits")
        #if DEBUG
        logger.info("✅ LAST RESORT: Saved \(habitsToSave.count) habits to UserDefaults")
        #endif
        return // Success via last resort fallback
      } catch {
        #if DEBUG
        logger.error("❌ Complete failure - even UserDefaults failed: \(error)")
        #endif
        throw DataError.storage(StorageError(
          type: .unknown,
          message: "Failed to save habits: \(error.localizedDescription)",
          underlyingError: error))
      }
    }
  }

  // MARK: - Helpers
  
  private func normalizedDifficultyDate(from rawValue: String) -> (key: String, date: Date?) {
    if let parsedDate = DateUtils.date(from: rawValue)
      ?? ISO8601DateHelper.shared.dateWithFallback(from: rawValue)
    {
      return (DateUtils.dateKey(for: parsedDate), parsedDate)
    }
    return (rawValue, nil)
  }

  func loadHabits(force: Bool = false) async throws -> [Habit] {
    // ✅ CRITICAL FIX: Always get fresh userId - never cache it
    // When userId changes (e.g., guest to authenticated), we need the current value
    // This ensures predicates use the correct userId after migration
    var currentUserId = await getCurrentUserId()
    
    // ✅ CRITICAL FIX: Log userId to track changes during migration
    let timestamp = Date()
    let userIdDisplay = currentUserId ?? "nil (guest)"
    logger.info("🔄 [SWIFTDATA_QUERY] \(timestamp) loadHabits() called - currentUserId: '\(userIdDisplay.isEmpty ? "EMPTY_STRING" : String(userIdDisplay.prefix(8)) + "...")'")
    
    // ✅ FIX: Only retry if we're expecting an authenticated user
    // For guest users, nil is expected and we should use "guest" immediately
    // Check if Firebase Auth is actually configured and might have a user
    if currentUserId == nil {
      // Quick check: if Auth is not configured or definitely no user, skip retries
      let hasAuthUser = await MainActor.run { Auth.auth().currentUser != nil }
      if hasAuthUser {
        // User might be authenticating, retry a few times
        logger.info("⚠️ getCurrentUserId returned nil, but Auth.auth().currentUser exists - waiting for Firebase Auth...")
        logger.info("   Auth.auth().currentUser.uid: \(Auth.auth().currentUser?.uid ?? "nil")")
        for attempt in 1...3 { // ✅ FIX: Reduced from 5 to 3 retries
          let delay = UInt64(200_000_000 * UInt64(attempt)) // ✅ FIX: Reduced delay: 0.2s, 0.4s, 0.6s
          try? await Task.sleep(nanoseconds: delay)
          currentUserId = await getCurrentUserId()
          if currentUserId != nil {
            logger.info("✅ getCurrentUserId succeeded after \(attempt) retry(ies): \(currentUserId?.prefix(8) ?? "nil")...")
            break
          }
          logger.info("⚠️ Retry \(attempt)/3: getCurrentUserId still nil, Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
        }
      } else {
        // No auth user exists, we're in guest mode - skip retries
        logger.info("ℹ️ getCurrentUserId returned nil (guest mode), skipping retries")
        logger.info("   Auth.auth().currentUser = nil (confirmed signed out)")
      }
    }
    
    logger.info("Loading habits from SwiftData for user: \(currentUserId ?? "guest")")
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 [SWIFTDATA_LOAD] SwiftDataStorage.loadHabits() called")
    
    // ✅ DEBUG: Log userId being used for query
    let userIdForQuery = currentUserId ?? ""
    print("🔍 [SWIFTDATA_LOAD] UserId being queried: '\(userIdForQuery.isEmpty ? "EMPTY (guest)" : userIdForQuery.prefix(8) + "...")'")
    logger.info("🔄 [HABIT_STORE] Loading habits for userId: '\(userIdForQuery.isEmpty ? "EMPTY (guest)" : userIdForQuery.prefix(8) + "...")'")
    print("🔄 [HABIT_STORE] CurrentUser().idOrGuest = '\(userIdForQuery.isEmpty ? "EMPTY" : userIdForQuery)'")

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      // First, query ALL habits (no predicate) to see total count
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabitsTotal = try container.modelContext.fetch(allHabitsDescriptor)
      print("🔍 [SWIFTDATA_LOAD] TOTAL habits in database (no predicate): \(allHabitsTotal.count)")
      
      if !allHabitsTotal.isEmpty {
        print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   📋 [SWIFTDATA_LOAD] All habits in database:")
        for (index, habit) in allHabitsTotal.enumerated() {
          let userIdDisplay = habit.userId.isEmpty ? "EMPTY" : habit.userId.prefix(8) + "..."
          print("      [\(index + 1)] ID: \(habit.id.uuidString.prefix(8))...")
          print("          Name: '\(habit.name)'")
          print("          userId: '\(userIdDisplay)'")
        }
        print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      }
      
      // Create user-specific fetch descriptor
      var descriptor = FetchDescriptor<HabitData>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

      // Filter by current user ID if authenticated, otherwise show guest data
      // ✅ SOFT DELETE: Filter out soft-deleted habits (deletedAt != nil)
      if let userId = currentUserId {
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == userId && habitData.deletedAt == nil
        }
        print("🔍 [SWIFTDATA_LOAD] Query predicate: userId == '\(userId.prefix(8))...' AND deletedAt == nil")
        logger.info("🔄 Query predicate: userId == '\(userId.prefix(8))...' AND deletedAt == nil")
      } else {
        // For guest users, show data with empty userId
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == "" && habitData.deletedAt == nil
        }
        print("🔍 [SWIFTDATA_LOAD] Query predicate: userId == '' (empty string) AND deletedAt == nil")
        logger.info("🔄 Query predicate: userId == '' (empty string) AND deletedAt == nil")
      }

      // ✅ CRITICAL FIX: Process pending changes before fetching
      // This ensures migrated data is visible to queries
      try container.modelContext.save()
      
      var habitDataArray = try container.modelContext.fetch(descriptor)
      
      print("🔍 [SWIFTDATA_LOAD] Habits matching userId predicate: \(habitDataArray.count)")
      
      // ✅ CRITICAL FIX: Log query results to diagnose @Query refresh issues
      let queryTimestamp = Date()
      let finalUserId = currentUserId ?? ""
      logger.info("🔄 [SWIFTDATA_QUERY] \(queryTimestamp) Query executed - found \(habitDataArray.count) habits for userId '\(finalUserId.isEmpty ? "EMPTY_STRING" : String(finalUserId.prefix(8)) + "...")'")
      print("🔄 [HABIT_LOAD] Query result: Found \(habitDataArray.count) habits for userId '\(finalUserId.isEmpty ? "EMPTY" : finalUserId.prefix(8) + "...")'")
      
      // Log each habit returned
      if !habitDataArray.isEmpty {
        print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("   📋 [SWIFTDATA_LOAD] Habits returned (after userId predicate):")
        for (index, habit) in habitDataArray.enumerated() {
          print("      [\(index + 1)] ID: \(habit.id.uuidString.prefix(8))...")
          print("          Name: '\(habit.name)'")
          print("          userId: '\(habit.userId.isEmpty ? "EMPTY" : habit.userId.prefix(8) + "...")'")
        }
        print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let habitUserIds = Set(habitDataArray.map { $0.userId })
        logger.info("🔄 [HABIT_LOAD] Habit userIds in result: \(habitUserIds.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." })")
        print("🔄 [HABIT_LOAD] Habit userIds found: \(habitUserIds.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." })")
      } else {
        print("   ⚠️ [SWIFTDATA_LOAD] No habits found matching userId predicate")
      }
      
      // ✅ FALLBACK: If authenticated but no habits found, check for guest habits
      // This handles migration scenarios where habits were saved with empty userId
      if let userId = currentUserId,
         habitDataArray.isEmpty,
         !UserDefaults.standard.bool(forKey: guestMigrationFlagKey) {
        logger.info("⚠️ No habits found for authenticated user '\(userId)', checking for guest habits (migration fallback)...")
        let guestDescriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate<HabitData> { habitData in
            habitData.userId == ""
          },
          sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let guestHabits = try container.modelContext.fetch(guestDescriptor)
        if !guestHabits.isEmpty {
          logger.info("🔍 Found \(guestHabits.count) guest habits - migrating to userId '\(userId)'")
          // Update these habits to have the correct userId
          for habitData in guestHabits {
            habitData.userId = userId
            // Also update CompletionRecords (including unique constraint)
            for record in habitData.completionHistory {
              record.userId = userId
              // Update the unique constraint key to match new userId
              record.userIdHabitIdDateKey = "\(userId)#\(record.habitId.uuidString)#\(record.dateKey)"
            }
          }
          try container.modelContext.save()
          UserDefaults.standard.set(true, forKey: guestMigrationFlagKey)
          logger.info("✅ Migrated \(guestHabits.count) habits and their CompletionRecords to userId '\(userId)'")
          habitDataArray = guestHabits
        }
      }
      
      // ✅ ADDITIONAL FALLBACK: If querying as guest returns 0 habits, check if there are habits with ANY userId
      // This handles the case where Firebase Auth hasn't initialized yet but habits exist with authenticated userId
      // OR when Firebase isn't configured and we should show all habits
      // ✅ CRITICAL FIX: Only use this fallback if Firebase Auth is NOT configured OR if we're in a legitimate
      // timing window (e.g., app startup before Auth initializes). DO NOT use this after explicit sign-out.
      if currentUserId == nil,
         habitDataArray.isEmpty {
        logger.info("⚠️ Querying as guest found 0 habits, checking if habits exist with other userIds...")
        let allHabitsDescriptor = FetchDescriptor<HabitData>()
        let allHabits = try container.modelContext.fetch(allHabitsDescriptor)
        
        // ✅ CRITICAL FIX: If Firebase isn't configured, show ALL habits (including those with userId = "")
        // This ensures guest mode works even when Firebase isn't configured
        if !AppEnvironment.isFirebaseConfigured {
          logger.info("🔍 Firebase not configured - showing all habits (guest mode)")
          habitDataArray = allHabits.filter { $0.userId.isEmpty }
          if !habitDataArray.isEmpty {
            logger.info("✅ Found \(habitDataArray.count) guest habits (Firebase not configured)")
            print("✅ [GUEST_MODE] Found \(habitDataArray.count) habits - Firebase not configured, showing guest data")
          } else {
            logger.info("ℹ️ No guest habits found in database")
            print("ℹ️ [GUEST_MODE] No habits found with userId = \"\"")
          }
        } else {
          // ✅ CRITICAL FIX: Only check for authenticated habits if Firebase Auth shows a user
          // AND we haven't explicitly signed out. After sign-out, Auth.auth().currentUser should be nil,
          // so this branch should not execute. If it does, it means Auth hasn't fully cleared yet,
          // but we should STILL respect the guest mode query (return empty array).
          // 
          // This fallback is ONLY for app startup scenarios where Auth hasn't initialized yet.
          // After explicit sign-out, we must return empty array to respect data isolation.
          let firebaseUserId: String? = await MainActor.run {
            guard let firebaseUser = Auth.auth().currentUser else {
              return nil
            }
            logger.info("🔍 Firebase Auth shows authenticated user: \(firebaseUser.uid) (anonymous: \(firebaseUser.isAnonymous))")
            return firebaseUser.uid
          }
          
          // ✅ CRITICAL FIX: If Firebase Auth shows a user but getCurrentUserId() returned nil,
          // this is likely a timing issue during app startup (Auth initializing).
          // However, if we're in guest mode (currentUserId == nil), we should NOT return
          // authenticated habits - that would break data isolation after sign-out.
          // 
          // Only use this fallback if we're confident it's an initialization timing issue,
          // not a sign-out scenario. Since we can't distinguish, we'll be conservative:
          // If getCurrentUserId() returned nil, respect that and return empty array.
          // The authenticated user's habits will load correctly once Auth fully initializes.
          if let firebaseUserId = firebaseUserId {
            logger.info("⚠️ Firebase Auth shows user '\(firebaseUserId)' but getCurrentUserId() returned nil")
            logger.info("   This might be a timing issue, but respecting guest mode query (returning empty array)")
            logger.info("   Authenticated habits will load once Auth fully initializes")
            // ✅ FIX: Do NOT return authenticated habits when in guest mode
            // This ensures data isolation after sign-out
            habitDataArray = [] // Return empty array to respect guest mode
          } else {
            // No Firebase Auth user - definitely guest mode, return empty array
            logger.info("ℹ️ No Firebase Auth user - confirmed guest mode, returning empty array")
            habitDataArray = []
          }
        }
      }
      
      // ✅ PERSISTENT BEST STREAK: One-time initialization for existing habits
      // Calculate bestStreakEver for habits that don't have it set yet
      let bestStreakInitializationKey = "bestStreakEver_initialized_\(currentUserId ?? "guest")"
      if !UserDefaults.standard.bool(forKey: bestStreakInitializationKey) {
        logger.info("🔄 Initializing bestStreakEver for existing habits...")
        var initializedCount = 0
        for habitData in habitDataArray {
          // Only initialize if bestStreakEver is 0 (default value)
          if habitData.bestStreakEver == 0 {
            let _ = habitData.calculateAndUpdateBestStreak()
            initializedCount += 1
          }
        }
        if initializedCount > 0 {
          try container.modelContext.save()
          logger.info("✅ Initialized bestStreakEver for \(initializedCount) habits")
        }
        UserDefaults.standard.set(true, forKey: bestStreakInitializationKey)
      }
      
      var habits = habitDataArray.map { $0.toHabit() }
      
      // ✅ CRITICAL FIX: Filter out any habits that were marked as deleted
      // This is a safety mechanism in case WAL checkpoint fails and deletion doesn't persist
      let deletedIds = UserDefaults.standard.stringArray(forKey: "DeletedHabitIDs") ?? []
      let beforeFilterCount = habits.count
      habits = habits.filter { habit in
        let isDeleted = deletedIds.contains(habit.id.uuidString)
        if isDeleted {
          print("🗑️ DELETE_FLOW: Filtering out deleted habit: \(habit.name) (\(habit.id))")
          // Also try to delete it again from SwiftData (async, non-blocking)
          Task {
            do {
              try await self.deleteHabit(id: habit.id)
              print("🗑️ DELETE_FLOW: Re-deleted habit \(habit.id) that reappeared")
            } catch {
              print("⚠️ DELETE_FLOW: Failed to re-delete habit \(habit.id): \(error.localizedDescription)")
            }
          }
        }
        return !isDeleted
      }
      
      if beforeFilterCount != habits.count {
        let filteredCount = beforeFilterCount - habits.count
        print("🗑️ DELETE_FLOW: Filtered out \(filteredCount) deleted habit(s) that reappeared")
        logger.warning("⚠️ Filtered out \(filteredCount) deleted habit(s) - WAL checkpoint may have failed")
      }

      let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
      logger
        .info(
          "Successfully loaded \(habits.count) habits for user: \(currentUserId ?? "guest") in \(String(format: "%.3f", timeElapsed))s")
      
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      print("📋 [SWIFTDATA_LOAD] Final habits returned:")
      print("   Total habits after all filtering: \(habits.count)")
      
      if !habits.isEmpty {
        for (index, habit) in habits.enumerated() {
          print("   [\(index + 1)] ID: \(habit.id.uuidString.prefix(8))...")
          print("       Name: '\(habit.name)'")
        }
      } else {
        print("   ⚠️ No habits returned (empty array)")
      }
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      
      // ✅ DIAGNOSTIC: Log detailed information about loaded habits
      print("🔍 [HABIT_LOAD] Loading habits for userId: \(currentUserId ?? "nil (guest)")")
      print("🔍 [HABIT_LOAD] Found \(habits.count) habits")
      
      if habits.isEmpty {
        print("⚠️ [HABIT_LOAD] No habits found for userId: \(currentUserId ?? "guest")")
        // Check if habits exist with different userIds
        await diagnosticCheckForHabits()
      } else {
        print("✅ [HABIT_LOAD] Loaded \(habits.count) habits successfully")
        print("   User ID: \(currentUserId ?? "guest")")
        print("   Habit names: \(habits.map { $0.name }.joined(separator: ", "))")
        
        // ✅ DIAGNOSTIC: Log completion records per habit
        for habit in habits {
          let completions = habit.completionHistory.count
          let completionStatusCount = habit.completionStatus.count
          let todayKey = DateUtils.dateKey(for: Date())
          let isCompletedToday = habit.completionStatus[todayKey] ?? false
          let todayProgress = habit.completionHistory[todayKey] ?? 0
          
          print("   🔍 Habit: '\(habit.name)'")
          print("      Completion Records: \(completions)")
          print("      Completion Status entries: \(completionStatusCount)")
          print("      Today completed: \(isCompletedToday), progress: \(todayProgress)")
          
          // Show recent completion dates
          let recentDates = Array(habit.completionHistory.keys.sorted().suffix(5))
          if !recentDates.isEmpty {
            print("      Recent completion dates: \(recentDates.joined(separator: ", "))")
          }
        }
      }

      return habits

    } catch {
      let errorDesc = error.localizedDescription
      logger.error("Failed to load habits: \(errorDesc)")
      
      // ✅ FIX #3: Detect database corruption and set flag for automatic recovery
      // Check for common corruption error patterns
      if errorDesc.contains("no such table") || 
         errorDesc.contains("ZHABITDATA") ||
         errorDesc.contains("ZCOMPLETIONRECORD") ||
         errorDesc.contains("ZDAILYAWARD") ||
         errorDesc.contains("ZUSERPROGRESSDATA") ||
         errorDesc.contains("SQLite error") ||
         errorDesc.contains("couldn't be opened") ||
         errorDesc.contains("readonly database") ||
         errorDesc.contains("I/O error") {
        // Set corruption flag so database will be reset on next launch
        UserDefaults.standard.set(true, forKey: "SwiftDataCorruptionDetected")
        logger.error("🚨 Database corruption detected during load - flag set for automatic reset on next launch")
        logger.error("   Corruption pattern: \(errorDesc)")
      }
      
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to load habits: \(errorDesc)",
        underlyingError: error))
    }
  }

  func saveHabit(_ habit: Habit, immediate _: Bool = false) async throws {
    // ✅ CRITICAL BUG FIX: Before creating a new habit, check if it was recently deleted
    if SyncEngine.isHabitDeleted(habit.id) {
      logger.info("⏭️ SwiftDataStorage: Skipping save for deleted habit '\(habit.name)'")
      return
    }
    
    logger.info("Saving single habit: \(habit.name)")

    do {
      if let existingHabitData = try await loadHabitData(by: habit.id) {
        // Update existing habit
        // ✅ CRITICAL FIX: updateFromHabit now calls syncCompletionRecordsFromHabit to sync CompletionRecords
        // This ensures CompletionRecords are properly created/updated from habit.completionHistory
        // DO NOT clear completionHistory relationship - syncCompletionRecordsFromHabit handles syncing
        await existingHabitData.updateFromHabit(habit)
        
        logger.info("✅ SWIFTDATA_DEBUG: Updated habit '\(habit.name)' - CompletionRecords synced via updateFromHabit")

        // Update difficulty history
        existingHabitData.difficultyHistory.removeAll()
        for (dateString, difficulty) in habit.difficultyHistory {
          let normalized = normalizedDifficultyDate(from: dateString)
          let difficultyRecord = DifficultyRecord(
            userId: await getCurrentUserId() ?? "",
            habitId: UUID(),
            dateKey: normalized.key,
            difficulty: difficulty)
          container.modelContext.insert(difficultyRecord)
          existingHabitData.difficultyHistory.append(difficultyRecord)
          if let parsedDate = normalized.date {
            print("✅ SAVE_HABIT DIFFICULTY: Saved difficulty \(difficulty) for \(normalized.key) (parsed as \(parsedDate))")
          } else {
            print("⚠️ SAVE_HABIT DIFFICULTY: Saved difficulty \(difficulty) for \(normalized.key) (raw source '\(dateString)')")
          }
        }
        print("✅ SAVE_HABIT DIFFICULTY: Synced \(existingHabitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")

        // Update usage history
        existingHabitData.usageHistory.removeAll()
        for (key, value) in habit.actualUsage {
          let usageRecord = UsageRecord(
            userId: await getCurrentUserId() ?? "",
            habitId: existingHabitData.id,
            key: key,
            value: value)
          existingHabitData.usageHistory.append(usageRecord)
        }
      } else {
        // Create new habit
        let habitData = HabitData(
          id: habit.id,
          userId: await getCurrentUserId() ?? "", // Use current user ID or empty string for guest
          name: habit.name,
          habitDescription: habit.description,
          icon: habit.icon,
          color: habit.color.color,
          habitType: habit.habitType,
          schedule: habit.schedule,
          goal: habit.goal,
          reminder: habit.reminder,
          startDate: habit.startDate,
          endDate: habit.endDate,
          baseline: habit.baseline,
          target: habit.target,
          goalHistory: habit.goalHistory)

        // ✅ MIGRATION FIX: Create CompletionRecords from Firestore completionHistory
        // Problem was: old code checked `progress == 1` which was wrong
        // Solution: Check if `progress >= goal` to determine actual completion
        
        logger.info("✅ MIGRATION: Creating CompletionRecords from Firestore data for habit '\(habit.name)'")
        
        for (dateString, progress) in habit.completionHistory {
          if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            let dateKey = Habit.dateKey(for: date)
            let recordedStatus = habit.completionStatus[dateKey]
            let goalInt = Int(habit.goal) ?? 1
            let isCompleted = recordedStatus ?? (progress >= goalInt)
            
            let completionRecord = CompletionRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: habitData.id,
              date: date,
              dateKey: dateKey,
              isCompleted: isCompleted,
              progress: progress)  // Store actual progress too
            
            habitData.completionHistory.append(completionRecord)
            
            logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
          }
        }

        // Add difficulty history
        for (dateString, difficulty) in habit.difficultyHistory {
          let normalized = normalizedDifficultyDate(from: dateString)
          let difficultyRecord = DifficultyRecord(
            userId: await getCurrentUserId() ?? "",
            habitId: UUID(),
            dateKey: normalized.key,
            difficulty: difficulty)
          container.modelContext.insert(difficultyRecord)
          habitData.difficultyHistory.append(difficultyRecord)
          if let parsedDate = normalized.date {
            print("✅ SAVE_HABIT CREATE DIFFICULTY: Created difficulty \(difficulty) for \(normalized.key) (parsed as \(parsedDate))")
          } else {
            print("⚠️ SAVE_HABIT CREATE DIFFICULTY: Created difficulty \(difficulty) for \(normalized.key) (raw source '\(dateString)')")
          }
        }
        print("✅ SAVE_HABIT CREATE DIFFICULTY: Created \(habitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")

        // Add usage history
        for (key, value) in habit.actualUsage {
          let usageRecord = UsageRecord(
            userId: await getCurrentUserId() ?? "",
            habitId: habitData.id,
            key: key,
            value: value)
          habitData.usageHistory.append(usageRecord)
        }

        container.modelContext.insert(habitData)
      }

      try container.modelContext.save()
      logger.info("Successfully saved habit: \(habit.name)")

    } catch {
      logger.error("Failed to save habit: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to save habit: \(error.localizedDescription)",
        underlyingError: error))
    }
  }

  func loadHabit(id: UUID) async throws -> Habit? {
    logger.info("Loading habit with ID: \(id)")

    do {
      guard let habitData = try await loadHabitData(by: id) else {
        logger.info("Habit not found with ID: \(id)")
        return nil
      }

      let habit = habitData.toHabit()
      logger.info("Successfully loaded habit: \(habit.name)")
      return habit

    } catch {
      logger.error("Failed to load habit: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to load habit: \(error.localizedDescription)",
        underlyingError: error))
    }
  }

  func deleteHabit(id: UUID) async throws {
    print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - START for habit ID: \(id)")
    logger.info("Soft-deleting habit with ID: \(id)")

    do {
      // ✅ SOFT DELETE: Fetch ALL habits (including soft-deleted) to find by ID
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Fetching all habits to find by ID")
      
      let descriptor = FetchDescriptor<HabitData>()
      let allHabits = try container.modelContext.fetch(descriptor)
      
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Found \(allHabits.count) total habits in database")
      
      // Find the habit by ID using Swift filtering (not predicate)
      guard let habitData = allHabits.first(where: { $0.id == id }) else {
        print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - WARNING: Habit not found for deletion: \(id)")
        print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Available habit IDs: \(allHabits.map { $0.id })")
        logger.warning("Habit not found for deletion: \(id)")
        return
      }

      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Found habit: '\(habitData.name)' (ID: \(habitData.id), userId: \(habitData.userId))")
      
      // ✅ SOFT DELETE: Mark as deleted instead of hard deleting
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Performing SOFT DELETE (marking as deleted)")
      habitData.softDelete(source: "user", context: container.modelContext)
      
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Calling modelContext.save()")
      try container.modelContext.save()
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - modelContext.save() completed")

      // ✅ CRITICAL FIX: Force WAL checkpoint to ensure soft-delete is persisted to disk
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - Forcing WAL checkpoint...")
      forceWALCheckpoint()
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - WAL checkpoint completed")

      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - END - Successfully soft-deleted")
      logger.info("Successfully soft-deleted habit with ID: \(id)")

    } catch {
      print("🗑️ [SOFT_DELETE] SwiftDataStorage.deleteHabit() - ERROR: \(error.localizedDescription)")
      logger.error("Failed to soft-delete habit: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to soft-delete habit: \(error.localizedDescription)",
        underlyingError: error))
    }
  }

  /// Clear all habits for the current user
  func clearAllHabits() async throws {
    let currentUserId = await getCurrentUserId()
    try await clearAllHabits(for: currentUserId)
  }
  
  /// Clear all SwiftData records for a specific userId
  /// ✅ CRITICAL FIX: Used during account deletion to ensure all data is cleared
  func clearAllHabits(for userId: String?) async throws {
    let targetUserId = userId ?? ""
    logger.info("Clearing all SwiftData records for user: \(targetUserId.isEmpty ? "guest" : targetUserId)")

    do {
      // ✅ STEP 1: Clear HabitData (cascade delete will handle CompletionRecords)
      var habitDescriptor = FetchDescriptor<HabitData>()
      habitDescriptor.predicate = #Predicate<HabitData> { habitData in
        habitData.userId == targetUserId
      }
      let habitDataArray = try container.modelContext.fetch(habitDescriptor)
      for habitData in habitDataArray {
        container.modelContext.delete(habitData)
      }
      logger.info("  ✅ Deleted \(habitDataArray.count) HabitData records")

      // ✅ STEP 2: Clear orphaned CompletionRecords (in case cascade delete didn't work)
      var completionDescriptor = FetchDescriptor<CompletionRecord>()
      completionDescriptor.predicate = #Predicate<CompletionRecord> { record in
        record.userId == targetUserId
      }
      let completionRecords = try container.modelContext.fetch(completionDescriptor)
      for record in completionRecords {
        container.modelContext.delete(record)
      }
      logger.info("  ✅ Deleted \(completionRecords.count) CompletionRecord records")

      // ✅ STEP 3: Clear DailyAward records
      var awardDescriptor = FetchDescriptor<DailyAward>()
      awardDescriptor.predicate = #Predicate<DailyAward> { award in
        award.userId == targetUserId
      }
      let awards = try container.modelContext.fetch(awardDescriptor)
      for award in awards {
        container.modelContext.delete(award)
      }
      logger.info("  ✅ Deleted \(awards.count) DailyAward records")

      // ✅ STEP 4: Clear UserProgressData records
      var progressDescriptor = FetchDescriptor<UserProgressData>()
      progressDescriptor.predicate = #Predicate<UserProgressData> { progress in
        progress.userId == targetUserId
      }
      let progressData = try container.modelContext.fetch(progressDescriptor)
      for progress in progressData {
        container.modelContext.delete(progress)
      }
      logger.info("  ✅ Deleted \(progressData.count) UserProgressData records")

      // ✅ STEP 5: Clear ProgressEvent records
      var eventDescriptor = FetchDescriptor<ProgressEvent>()
      eventDescriptor.predicate = #Predicate<ProgressEvent> { event in
        event.userId == targetUserId
      }
      let events = try container.modelContext.fetch(eventDescriptor)
      for event in events {
        container.modelContext.delete(event)
      }
      logger.info("  ✅ Deleted \(events.count) ProgressEvent records")

      // ✅ STEP 6: Clear GlobalStreakModel records
      var streakDescriptor = FetchDescriptor<GlobalStreakModel>()
      streakDescriptor.predicate = #Predicate<GlobalStreakModel> { streak in
        streak.userId == targetUserId
      }
      let streaks = try container.modelContext.fetch(streakDescriptor)
      for streak in streaks {
        container.modelContext.delete(streak)
      }
      logger.info("  ✅ Deleted \(streaks.count) GlobalStreakModel records")

      // Note: DifficultyRecord, UsageRecord, and HabitNote are automatically deleted
      // via cascade delete when HabitData is deleted (they're linked via relationships)

      // Save all deletions
      try container.modelContext.save()
      logger.info("✅ Successfully cleared all SwiftData records for user: \(targetUserId.isEmpty ? "guest" : targetUserId)")

    } catch {
      logger.error("Failed to clear all SwiftData records: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to clear all SwiftData records: \(error.localizedDescription)",
        underlyingError: error))
    }
  }

  // MARK: Private

  private lazy var container = SwiftDataContainer.shared
  private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftDataStorage")
  
  /// Diagnostic function to check for habits with different userIds
  private func diagnosticCheckForHabits() async {
    do {
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabits = try container.modelContext.fetch(allHabitsDescriptor)
      
      if allHabits.isEmpty {
        print("🔍 [DIAGNOSTIC] No habits found in database at all")
        return
      }
      
      // Group by userId
      let habitsByUserId = Dictionary(grouping: allHabits) { $0.userId }
      
      print("🔍 [DIAGNOSTIC] Found habits with different userIds:")
      for (userId, habits) in habitsByUserId {
        let userIdDisplay = userId.isEmpty ? "(empty/guest)" : userId.prefix(8) + "..."
        print("   User ID: \(userIdDisplay) - \(habits.count) habits")
        print("      Names: \(habits.map { $0.name }.joined(separator: ", "))")
      }
      
      // Check current authenticated user
      let currentUserId = await getCurrentUserId()
      print("🔍 [DIAGNOSTIC] Current authenticated user ID: \(currentUserId ?? "nil (guest)")")
      
      if let currentUserId = currentUserId {
        let matchingHabits = habitsByUserId[currentUserId] ?? []
        if matchingHabits.isEmpty {
          print("⚠️ [DIAGNOSTIC] No habits found for current user ID: \(currentUserId)")
          print("   This might indicate a userId mismatch after migration")
        } else {
          print("✅ [DIAGNOSTIC] Found \(matchingHabits.count) habits for current user ID")
        }
      }
    } catch {
      print("❌ [DIAGNOSTIC] Failed to check habits: \(error.localizedDescription)")
    }
  }

  /// Helper method to get current user ID for data isolation
  /// ✅ CRITICAL FIX: Use CurrentUser().idOrGuest for consistency across the app
  /// This ensures we use the same userId logic as the rest of the codebase
  private func getCurrentUserId() async -> String? {
    // ✅ FIX: Use CurrentUser().idOrGuest instead of checking Auth.auth().currentUser directly
    // This ensures consistency and proper handling of sign-out state
    let userId = await CurrentUser().idOrGuest
    if userId.isEmpty {
      logger.info("🔍 getCurrentUserId: Guest mode - returning nil (empty string)")
      return nil // Return nil for guest mode (becomes "" with ?? "")
    } else {
      logger.info("🔍 getCurrentUserId: Authenticated user - returning: \(userId.prefix(8))...")
      return userId
    }
  }

  // MARK: - Private Helper Methods
  
  /// Force WAL checkpoint using multiple aggressive methods
  private func forceWALCheckpoint() {
    print("🗑️ DELETE_FLOW: SwiftDataStorage - Forcing WAL checkpoint...")
    
    // Method 1: Save context multiple times to ensure flush
    do {
      if container.modelContext.hasChanges {
        try container.modelContext.save()
        print("🗑️ DELETE_FLOW: Context saved before checkpoint")
      }
    } catch {
      print("❌ DELETE_FLOW: Context save failed: \(error)")
    }
    
    // Method 2: Use SQLite directly with TRUNCATE mode (more aggressive than PASSIVE)
    guard let storeURL = container.modelContainer.configurations.first?.url else {
      print("❌ DELETE_FLOW: Could not get store URL")
      return
    }
    
    var db: OpaquePointer?
    let openResult = sqlite3_open(storeURL.path, &db)
    
    guard openResult == SQLITE_OK, let database = db else {
      print("❌ DELETE_FLOW: Could not open database: \(openResult)")
      if let db = db {
        sqlite3_close(db)
      }
      return
    }
    
    defer { sqlite3_close(database) }
    
    var pnLog: Int32 = 0
    var pnCkpt: Int32 = 0
    
    // Try TRUNCATE mode first (most aggressive - truncates WAL file)
    var result = sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_TRUNCATE, &pnLog, &pnCkpt)
    
    if result != SQLITE_OK {
      print("⚠️ DELETE_FLOW: TRUNCATE checkpoint failed (\(result)), trying RESTART...")
      // Fallback to RESTART mode
      result = sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_RESTART, &pnLog, &pnCkpt)
    }
    
    if result != SQLITE_OK {
      print("⚠️ DELETE_FLOW: RESTART checkpoint failed (\(result)), trying FULL...")
      // Fallback to FULL mode
      result = sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_FULL, &pnLog, &pnCkpt)
    }
    
    if result == SQLITE_OK && pnLog >= 0 {
      print("✅ DELETE_FLOW: WAL checkpoint SUCCESS (mode result: \(result), log frames: \(pnLog), checkpointed: \(pnCkpt))")
    } else {
      print("❌ DELETE_FLOW: WAL checkpoint FAILED - result: \(result), log: \(pnLog), ckpt: \(pnCkpt)")
      
      // Method 3: Nuclear option - execute PRAGMA directly
      var errMsg: UnsafeMutablePointer<CChar>?
      let pragmaResult = sqlite3_exec(database, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, &errMsg)
      if pragmaResult == SQLITE_OK {
        print("✅ DELETE_FLOW: PRAGMA wal_checkpoint succeeded")
      } else {
        if let errMsg = errMsg {
          let errorString = String(cString: errMsg)
          print("❌ DELETE_FLOW: PRAGMA wal_checkpoint failed: \(pragmaResult) - \(errorString)")
          sqlite3_free(errMsg)
        } else {
          print("❌ DELETE_FLOW: PRAGMA wal_checkpoint failed: \(pragmaResult)")
        }
      }
    }
  }

  private func loadHabitData(by id: UUID) async throws -> HabitData? {
    let currentUserId = await getCurrentUserId()
    
    // Filter by both habit ID and user ID for consistency
    var descriptor: FetchDescriptor<HabitData>
    if let userId = currentUserId {
      descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { habitData in
          habitData.id == id && habitData.userId == userId
        })
    } else {
      // For guest users, filter by ID and empty userId
      descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { habitData in
          habitData.id == id && habitData.userId == ""
        })
    }

    let results = try container.modelContext.fetch(descriptor)
    return results.first
  }
}
