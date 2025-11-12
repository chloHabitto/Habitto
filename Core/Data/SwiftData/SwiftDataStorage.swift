import Foundation
import OSLog
import SwiftData
import FirebaseAuth

// MARK: - SwiftData Storage Implementation

@MainActor
final class SwiftDataStorage: HabitStorageProtocol {
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
    #if DEBUG
    logger.info("🎯 [8/8] SwiftDataStorage.saveHabits: writing to SwiftData")
    logger.info("  → Count: \(habits.count)")
    #endif

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      #if DEBUG
      for (i, habit) in habits.enumerated() {
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

      for habit in habits {
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
            // ✅ CRITICAL FIX: Use DateUtils.date() to parse "yyyy-MM-dd" format (dateKey format)
            // difficultyHistory uses dateKey format, not ISO8601
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current
            
            if let date = dateFormatter.date(from: dateString) ?? ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
              let difficultyRecord = await DifficultyRecord(
                userId: getCurrentUserId() ?? "",
                habitId: existingHabitData.id,
                date: date,
                difficulty: difficulty)
              existingHabitData.difficultyHistory.append(difficultyRecord)
              print("✅ SAVE DIFFICULTY: Saved difficulty \(difficulty) for \(dateString) (parsed as \(date))")
            } else {
              print("❌ SAVE DIFFICULTY: Failed to parse dateString '\(dateString)' for habit '\(habit.name)'")
            }
          }
          print("✅ SAVE DIFFICULTY: Synced \(existingHabitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")
          
          // ✅ CRITICAL FIX: Sync usage history from habit.actualUsage
          existingHabitData.usageHistory.removeAll()
          for (key, value) in habit.actualUsage {
            let usageRecord = await UsageRecord(
              userId: getCurrentUserId() ?? "",
              habitId: existingHabitData.id,
              key: key,
              value: value)
            existingHabitData.usageHistory.append(usageRecord)
          }
        } else {
          // Create new habit with user ID
          let habitData = await HabitData(
            id: habit.id,
            userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
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
            target: habit.target)

          // ✅ MIGRATION FIX: Create CompletionRecords from Firestore completionHistory
          // Problem was: old code checked `progress == 1` which was wrong
          // Solution: Check if `progress >= goal` to determine actual completion
          
          logger.info("✅ MIGRATION: Creating CompletionRecords from Firestore data for habit '\(habit.name)'")
          
          for (dateString, progress) in habit.completionHistory {
            if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
              // ✅ CORRECT: Check if progress >= goal for completion
              let goalInt = Int(habit.goal) ?? 1
              let isCompleted = progress >= goalInt
              
              let completionRecord = CompletionRecord(
                userId: await getCurrentUserId() ?? "",
                habitId: habitData.id,
                date: date,
                dateKey: Habit.dateKey(for: date),
                isCompleted: isCompleted,
                progress: progress)  // Store actual progress too
              
              habitData.completionHistory.append(completionRecord)
              
              logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
            }
          }

          // Add difficulty history
          // ✅ CRITICAL FIX: Use DateUtils.date() to parse "yyyy-MM-dd" format (dateKey format)
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd"
          dateFormatter.timeZone = TimeZone.current
          
          for (dateString, difficulty) in habit.difficultyHistory {
            if let date = dateFormatter.date(from: dateString) ?? ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
              let difficultyRecord = await DifficultyRecord(
                userId: getCurrentUserId() ?? "",
                habitId: habitData.id,
                date: date,
                difficulty: difficulty)
              habitData.difficultyHistory.append(difficultyRecord)
              print("✅ CREATE DIFFICULTY: Created difficulty \(difficulty) for \(dateString) (parsed as \(date))")
            } else {
              print("❌ CREATE DIFFICULTY: Failed to parse dateString '\(dateString)' for habit '\(habit.name)'")
            }
          }
          print("✅ CREATE DIFFICULTY: Created \(habitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")

          // Add usage history
          for (key, value) in habit.actualUsage {
            let usageRecord = await UsageRecord(
              userId: getCurrentUserId() ?? "",
              habitId: habitData.id,
              key: key,
              value: value)
            habitData.usageHistory.append(usageRecord)
          }

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
            "  ✅ SUCCESS! Saved \(habits.count) habits in \(String(format: "%.3f", timeElapsed))s")
        #endif
        print("        ✅ SWIFTDATA_SUCCESS: Saved \(habits.count) habits to database")
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
        let data = try encoder.encode(habits)
        UserDefaults.standard.set(data, forKey: "SavedHabits")
        #if DEBUG
        logger.info("✅ Saved \(habits.count) habits to UserDefaults as fallback")
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
        let data = try encoder.encode(habits)
        UserDefaults.standard.set(data, forKey: "SavedHabits")
        #if DEBUG
        logger.info("✅ LAST RESORT: Saved \(habits.count) habits to UserDefaults")
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

  func loadHabits() async throws -> [Habit] {
    // ✅ CRITICAL FIX: Wait for Firebase Auth to be ready before getting user ID
    // This ensures we use the correct user ID even if called during app initialization
    var currentUserId = await getCurrentUserId()
    
    // ✅ IMPROVED: More aggressive retry logic with exponential backoff
    // Retry up to 5 times with increasing delays (up to 2.5 seconds total)
    if currentUserId == nil {
      logger.info("⚠️ getCurrentUserId returned nil, waiting for Firebase Auth...")
      let initialAuthUserId = await MainActor.run { Auth.auth().currentUser?.uid }
      logger.info("🔍 DEBUG: Auth.auth().currentUser = \(initialAuthUserId ?? "nil")")
      for attempt in 1...5 {
        let delay = UInt64(500_000_000 * UInt64(attempt)) // 0.5s, 1s, 1.5s, 2s, 2.5s
        try? await Task.sleep(nanoseconds: delay)
        currentUserId = await getCurrentUserId()
        let retryAuthUserId = await MainActor.run { Auth.auth().currentUser?.uid }
        logger.info("🔍 DEBUG: Retry \(attempt)/5: Auth.auth().currentUser = \(retryAuthUserId ?? "nil"), currentUserId = \(currentUserId ?? "nil")")
        if currentUserId != nil {
          logger.info("✅ getCurrentUserId succeeded after \(attempt) retry(ies)")
          break
        }
        logger.info("⚠️ Retry \(attempt)/5: getCurrentUserId still nil")
      }
    }
    
    logger.info("Loading habits from SwiftData for user: \(currentUserId ?? "guest")")
    
    // 🔍 DEBUG: Log what's actually in the database
    do {
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabits = try container.modelContext.fetch(allHabitsDescriptor)
      logger.info("🔍 DEBUG: Total habits in database: \(allHabits.count)")
      for habit in allHabits.prefix(5) {
        logger.info("🔍 DEBUG: Habit '\(habit.name)' has userId: '\(habit.userId)' (empty=\(habit.userId.isEmpty))")
      }
    } catch {
      logger.warning("⚠️ Failed to fetch all habits for debugging: \(error.localizedDescription)")
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      // Create user-specific fetch descriptor
      var descriptor = FetchDescriptor<HabitData>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

      // Filter by current user ID if authenticated, otherwise show guest data
      if let userId = currentUserId {
        logger.info("🔍 DEBUG: Querying for habits with userId: '\(userId)'")
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == userId
        }
      } else {
        logger.info("🔍 DEBUG: Querying for guest habits (userId == '')")
        // For guest users, show data with empty userId
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == ""
        }
      }

      var habitDataArray = try container.modelContext.fetch(descriptor)
      logger.info("🔍 DEBUG: Found \(habitDataArray.count) habits matching query for userId: '\(currentUserId ?? "guest")'")
      
      // ✅ FALLBACK: If authenticated but no habits found, check for guest habits
      // This handles migration scenarios where habits were saved with empty userId
      if let userId = currentUserId, habitDataArray.isEmpty {
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
          logger.info("✅ Migrated \(guestHabits.count) habits and their CompletionRecords to userId '\(userId)'")
          habitDataArray = guestHabits
        }
      }
      
      // ✅ ADDITIONAL FALLBACK: If querying as guest returns 0 habits, check if there are habits with ANY userId
      // This handles the case where Firebase Auth hasn't initialized yet but habits exist with authenticated userId
      if currentUserId == nil, habitDataArray.isEmpty {
        logger.info("⚠️ Querying as guest found 0 habits, checking if habits exist with other userIds...")
        let allHabitsDescriptor = FetchDescriptor<HabitData>()
        let allHabits = try container.modelContext.fetch(allHabitsDescriptor)
        logger.info("🔍 DEBUG: Total habits in database: \(allHabits.count)")
        
        // Check if any habits have non-empty userId (likely authenticated user)
        let authenticatedHabits = allHabits.filter { !$0.userId.isEmpty }
        if !authenticatedHabits.isEmpty {
          let userIds = Set(authenticatedHabits.map { $0.userId })
          logger.info("🔍 Found \(authenticatedHabits.count) habits with userIds: \(userIds)")
          logger.info("⚠️ Habits exist but query returned 0 - likely Firebase Auth timing issue")
          
          // Try one more time to get the authenticated user ID directly from Firebase Auth
          // This handles the case where Auth.auth().currentUser is available but getCurrentUserId() returned nil
          let firebaseUserId: String? = await MainActor.run {
            guard let firebaseUser = Auth.auth().currentUser, !firebaseUser.isAnonymous else {
              return nil
            }
            logger.info("🔍 Firebase Auth shows authenticated user: \(firebaseUser.uid)")
            return firebaseUser.uid
          }
          
          if let firebaseUserId = firebaseUserId {
            // Re-query with the authenticated user ID
            let authDescriptor = FetchDescriptor<HabitData>(
              predicate: #Predicate<HabitData> { habitData in
                habitData.userId == firebaseUserId
              },
              sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let authHabits: [HabitData] = try container.modelContext.fetch(authDescriptor)
            if !authHabits.isEmpty {
              logger.info("✅ Found \(authHabits.count) habits for authenticated user '\(firebaseUserId)' - using them")
              habitDataArray = authHabits
              // Update currentUserId for logging purposes
              currentUserId = firebaseUserId
            }
          }
        }
      }
      
      let habits = habitDataArray.map { $0.toHabit() }

      let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
      logger
        .info(
          "Successfully loaded \(habits.count) habits for user: \(currentUserId ?? "guest") in \(String(format: "%.3f", timeElapsed))s")

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
        // ✅ CRITICAL FIX: Use DateUtils.date() to parse "yyyy-MM-dd" format (dateKey format)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        
        existingHabitData.difficultyHistory.removeAll()
        for (dateString, difficulty) in habit.difficultyHistory {
          if let date = dateFormatter.date(from: dateString) ?? ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            let difficultyRecord = await DifficultyRecord(
              userId: getCurrentUserId() ?? "",
              habitId: existingHabitData.id,
              date: date,
              difficulty: difficulty)
            existingHabitData.difficultyHistory.append(difficultyRecord)
            print("✅ SAVE_HABIT DIFFICULTY: Saved difficulty \(difficulty) for \(dateString) (parsed as \(date))")
          } else {
            print("❌ SAVE_HABIT DIFFICULTY: Failed to parse dateString '\(dateString)' for habit '\(habit.name)'")
          }
        }
        print("✅ SAVE_HABIT DIFFICULTY: Synced \(existingHabitData.difficultyHistory.count) difficulty records for habit '\(habit.name)'")

        // Update usage history
        existingHabitData.usageHistory.removeAll()
        for (key, value) in habit.actualUsage {
          let usageRecord = await UsageRecord(
            userId: getCurrentUserId() ?? "",
            habitId: existingHabitData.id,
            key: key,
            value: value)
          existingHabitData.usageHistory.append(usageRecord)
        }
      } else {
        // Create new habit
        let habitData = await HabitData(
          id: habit.id,
          userId: getCurrentUserId() ?? "", // Use current user ID or empty string for guest
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
          target: habit.target)

        // ✅ MIGRATION FIX: Create CompletionRecords from Firestore completionHistory
        // Problem was: old code checked `progress == 1` which was wrong
        // Solution: Check if `progress >= goal` to determine actual completion
        
        logger.info("✅ MIGRATION: Creating CompletionRecords from Firestore data for habit '\(habit.name)'")
        
        for (dateString, progress) in habit.completionHistory {
          if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            // ✅ CORRECT: Check if progress >= goal for completion
            let goalInt = Int(habit.goal) ?? 1
            let isCompleted = progress >= goalInt
            
            let completionRecord = CompletionRecord(
              userId: await getCurrentUserId() ?? "",
              habitId: habitData.id,
              date: date,
              dateKey: Habit.dateKey(for: date),
              isCompleted: isCompleted,
              progress: progress)  // Store actual progress too
            
            habitData.completionHistory.append(completionRecord)
            
            logger.info("  📝 Created CompletionRecord for \(dateString): progress=\(progress), goal=\(goalInt), completed=\(isCompleted)")
          }
        }

        // Add difficulty history
        for (dateString, difficulty) in habit.difficultyHistory {
          if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            let difficultyRecord = await DifficultyRecord(
              userId: getCurrentUserId() ?? "",
              habitId: habitData.id,
              date: date,
              difficulty: difficulty)
            habitData.difficultyHistory.append(difficultyRecord)
          }
        }

        // Add usage history
        for (key, value) in habit.actualUsage {
          let usageRecord = await UsageRecord(
            userId: getCurrentUserId() ?? "",
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
    logger.info("Deleting habit with ID: \(id)")

    do {
      guard let habitData = try await loadHabitData(by: id) else {
        logger.warning("Habit not found for deletion: \(id)")
        return
      }

      container.modelContext.delete(habitData)
      try container.modelContext.save()

      logger.info("Successfully deleted habit with ID: \(id)")

    } catch {
      logger.error("Failed to delete habit: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to delete habit: \(error.localizedDescription)",
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

  /// Helper method to get current user ID for data isolation
  /// Returns nil for guest users (empty string when used with ?? "")
  /// ✅ FIX: Use Auth.auth().currentUser directly to avoid timing issues with AuthenticationManager
  private func getCurrentUserId() async -> String? {
    await MainActor.run {
      // Use Firebase Auth directly - it's synchronous and doesn't depend on AuthenticationManager initialization
      guard let firebaseUser = Auth.auth().currentUser else {
        logger.info("🔍 getCurrentUserId: No Firebase user found, returning nil (guest)")
        return nil // Guest user - will use "" when used with ?? ""
      }
      
      // ✅ CRITICAL FIX: Treat anonymous Firebase users as guests
      // Anonymous users should use "" as userId for consistency with guest mode
      if firebaseUser.isAnonymous {
        logger.info("🔍 getCurrentUserId: Anonymous user detected, returning nil (guest)")
        return nil // Anonymous = guest, use "" as userId
      }
      
      logger.info("🔍 getCurrentUserId: Authenticated user found: \(firebaseUser.uid)")
      return firebaseUser.uid // Authenticated non-anonymous user
    }
  }

  // MARK: - Private Helper Methods

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
