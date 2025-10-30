import Foundation
import OSLog
import SwiftData

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
          existingHabitData.updateFromHabit(habit)
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
    let currentUserId = await getCurrentUserId()
    logger.info("Loading habits from SwiftData for user: \(currentUserId ?? "guest")")

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      // Create user-specific fetch descriptor
      var descriptor = FetchDescriptor<HabitData>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)])

      // Filter by current user ID if authenticated, otherwise show guest data
      if let userId = currentUserId {
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == userId
        }
      } else {
        // For guest users, show data with empty userId
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == ""
        }
      }

      let habitDataArray = try container.modelContext.fetch(descriptor)
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
        existingHabitData.updateFromHabit(habit)

        // ✅ CRITICAL FIX: Do NOT create CompletionRecords from legacy completionHistory
        // Same issue as in saveHabits - completionHistory stores progress counts, not completion status
        // Let the UI create CompletionRecords when users actually complete habits
        
        existingHabitData.completionHistory.removeAll()
        logger.info("🚨 SWIFTDATA_DEBUG: Skipping CompletionRecord update for habit '\(habit.name)' - will be created by UI")
        
        // Old code that created phantom records:
        /*
        for (dateString, isCompleted) in habit.completionHistory {
          if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            let completionRecord = CompletionRecord(
              userId: "legacy",
              habitId: existingHabitData.id,
              date: date,
              dateKey: Habit.dateKey(for: date),
              isCompleted: isCompleted == 1)  // ❌ WRONG! progress count != completion status
            existingHabitData.completionHistory.append(completionRecord)
          }
        }
        */

        // Update difficulty history
        existingHabitData.difficultyHistory.removeAll()
        for (dateString, difficulty) in habit.difficultyHistory {
          if let date = ISO8601DateHelper.shared.dateWithFallback(from: dateString) {
            let difficultyRecord = await DifficultyRecord(
              userId: getCurrentUserId() ?? "",
              habitId: existingHabitData.id,
              date: date,
              difficulty: difficulty)
            existingHabitData.difficultyHistory.append(difficultyRecord)
          }
        }

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
    logger.info("Clearing all habits from SwiftData for user: \(currentUserId ?? "guest")")

    do {
      // Create user-specific fetch descriptor
      var descriptor = FetchDescriptor<HabitData>()

      // Filter by current user ID if authenticated, otherwise clear guest data
      if let userId = currentUserId {
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == userId
        }
      } else {
        // For guest users, clear data with empty userId
        descriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == ""
        }
      }

      let habitDataArray = try container.modelContext.fetch(descriptor)

      for habitData in habitDataArray {
        container.modelContext.delete(habitData)
      }

      try container.modelContext.save()
      logger
        .info(
          "Successfully cleared \(habitDataArray.count) habits for user: \(currentUserId ?? "guest")")

    } catch {
      logger.error("Failed to clear all habits: \(error.localizedDescription)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Failed to clear all habits: \(error.localizedDescription)",
        underlyingError: error))
    }
  }

  // MARK: Private

  private lazy var container = SwiftDataContainer.shared
  private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftDataStorage")

  /// Helper method to get current user ID for data isolation
  private func getCurrentUserId() async -> String? {
    await MainActor.run {
      AuthenticationManager.shared.currentUser?.uid
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
