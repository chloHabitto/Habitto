import Foundation
import OSLog
import SwiftData

// MARK: - SwiftData Container Manager

@MainActor
final class SwiftDataContainer: ObservableObject {
  // MARK: Lifecycle

  private init() {
    do {
      // Create the model container with comprehensive entities
      let schema = Schema([
        HabitData.self,
        CompletionRecord.self,
        DailyAward.self, // ✅ PHASE 5: Added DailyAward model
        UserProgressData.self, // ✅ PHASE 5: Added UserProgressData model
        AchievementData.self, // ✅ PHASE 5: Added AchievementData model
        DifficultyRecord.self,
        UsageRecord.self,
        HabitNote.self,
        StorageHeader.self,
        MigrationRecord.self,
        MigrationState.self // ✅ PHASE 5: Added MigrationState model
      ])

      logger.info("🔧 SwiftData: Creating model configuration...")
      logger.info("🔧 SwiftData: Schema includes \(schema.entities.count) entities")

      // ✅ CRITICAL FIX: Reset database if corrupted
      let databaseURL = URL.applicationSupportDirectory.appending(path: "default.store")
      if FileManager.default.fileExists(atPath: databaseURL.path) {
        logger.warning("🔧 SwiftData: Database exists, checking for corruption...")
        // Check if database is corrupted by attempting to open it
        do {
          let testContainer = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(url: databaseURL)
          ])
          let testContext = ModelContext(testContainer)
          // Try to query CompletionRecord to check if table exists
          let testRequest = FetchDescriptor<CompletionRecord>()
          _ = try testContext.fetch(testRequest)
          logger.info("✅ SwiftData: Database is healthy")
        } catch {
          logger.error("❌ SwiftData: Database corruption detected: \(error)")
          logger.info("🔧 SwiftData: Resetting corrupted database...")
          try? FileManager.default.removeItem(at: databaseURL)
          logger.info("✅ SwiftData: Corrupted database removed")
        }
      } else {
        logger.info("🔧 SwiftData: No existing database found, creating new one")
      }

      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false)

      logger.info("🔧 SwiftData: Creating ModelContainer...")
      self.modelContainer = try ModelContainer(
        for: schema,
        configurations: [modelConfiguration])

      logger.info("🔧 SwiftData: Creating ModelContext...")
      self.modelContext = ModelContext(modelContainer)

      logger.info("✅ SwiftData: Container initialized successfully")
      logger.info("✅ SwiftData: Database URL: \(modelConfiguration.url.absoluteString)")

      // Test if we can access the CompletionRecord table
      let testRequest = FetchDescriptor<CompletionRecord>()
      let testCount = (try? modelContext.fetchCount(testRequest)) ?? -1
      logger.info("🔧 SwiftData: CompletionRecord table test - count: \(testCount)")

      // ✅ CRITICAL FIX: DO NOT perform health check on startup
      // The health check deletes the database while it's in use, causing corruption
      // Database corruption will be handled gracefully by saveHabits/loadHabits error handlers
      logger.info("🔧 SwiftData: Skipping health check to prevent database corruption")

    } catch {
      logger.error("❌ SwiftData: Failed to initialize container: \(error.localizedDescription)")
      logger.error("❌ SwiftData: Error details: \(error)")
      fatalError("Failed to initialize SwiftData container: \(error)")
    }
  }

  // MARK: Internal

  static let shared = SwiftDataContainer()

  let modelContainer: ModelContainer
  let modelContext: ModelContext

  // MARK: - Schema Version Management

  func getCurrentSchemaVersion() -> Int {
    let descriptor = FetchDescriptor<StorageHeader>()

    do {
      let headers = try modelContext.fetch(descriptor)
      return headers.first?.schemaVersion ?? 1
    } catch {
      logger.error("Failed to get schema version: \(error.localizedDescription)")
      return 1
    }
  }

  func updateSchemaVersion(to version: Int) {
    let descriptor = FetchDescriptor<StorageHeader>()

    do {
      let headers = try modelContext.fetch(descriptor)

      if let header = headers.first {
        header.schemaVersion = version
        header.lastMigration = Date()
      } else {
        // ✅ FIX: Use new initializer with userId
        let userId = getCurrentUserId()
        let header = StorageHeader(userId: userId, schemaVersion: version)
        modelContext.insert(header)
      }

      try modelContext.save()
      logger.info("Updated schema version to \(version)")
    } catch {
      logger.error("Failed to update schema version: \(error.localizedDescription)")
    }
  }

  // MARK: - Migration Management

  func recordMigration(
    from fromVersion: Int,
    to toVersion: Int,
    success: Bool,
    errorMessage: String? = nil)
  {
    // ✅ FIX: Use new initializer with userId
    let userId = getCurrentUserId()
    let migrationRecord = MigrationRecord(
      userId: userId,
      fromVersion: fromVersion,
      toVersion: toVersion,
      success: success,
      errorMessage: errorMessage)

    modelContext.insert(migrationRecord)

    do {
      try modelContext.save()
      logger.info("Recorded migration from \(fromVersion) to \(toVersion), success: \(success)")
    } catch {
      logger.error("Failed to record migration: \(error.localizedDescription)")
    }
  }

  func getMigrationHistory() -> [MigrationRecord] {
    let descriptor = FetchDescriptor<MigrationRecord>(
      sortBy: [SortDescriptor(\.executedAt, order: .reverse)])

    do {
      return try modelContext.fetch(descriptor)
    } catch {
      logger.error("Failed to get migration history: \(error.localizedDescription)")
      return []
    }
  }

  // MARK: - Database Health Check

  func checkDatabaseHealth() -> Bool {
    do {
      // Try to query CompletionRecord to check if table exists
      let testRequest = FetchDescriptor<CompletionRecord>()
      _ = try modelContext.fetch(testRequest)
      return true
    } catch {
      logger.error("❌ SwiftData: Database health check failed: \(error)")
      return false
    }
  }

  /// ✅ CRITICAL FIX: Proactive database health monitoring
  func performHealthCheck() -> Bool {
    logger.info("🔧 SwiftData: Performing proactive health check...")

    // ✅ FIX: Discard unused results with _
    let tests: [(String, () throws -> Void)] = [
      ("HabitData", { _ = try self.modelContext.fetch(FetchDescriptor<HabitData>()) }),
      (
        "CompletionRecord",
        { _ = try self.modelContext.fetch(FetchDescriptor<CompletionRecord>()) }),
      ("DailyAward", { _ = try self.modelContext.fetch(FetchDescriptor<DailyAward>()) }),
      ("UserProgressData", { _ = try self.modelContext.fetch(FetchDescriptor<UserProgressData>()) })
    ]

    for (tableName, test) in tests {
      do {
        _ = try test()
        logger.info("✅ SwiftData: \(tableName) table is healthy")
      } catch {
        logger.error("❌ SwiftData: \(tableName) table is corrupted: \(error)")
        logger.error("🔧 SwiftData: Initiating database reset...")
        resetCorruptedDatabase()
        return false
      }
    }

    logger.info("✅ SwiftData: All tables are healthy")
    return true
  }

  func resetCorruptedDatabase() {
    logger.warning("🔧 SwiftData: Resetting corrupted database...")
    let databaseURL = URL.applicationSupportDirectory.appending(path: "default.store")
    try? FileManager.default.removeItem(at: databaseURL)
    logger.info("✅ SwiftData: Corrupted database removed - app will need to restart")

    // Also remove any related database files
    let databaseDir = databaseURL.deletingLastPathComponent()
    let databaseName = databaseURL.deletingPathExtension().lastPathComponent

    // Remove all related files
    let fileManager = FileManager.default
    do {
      let files = try fileManager.contentsOfDirectory(
        at: databaseDir,
        includingPropertiesForKeys: nil)
      for file in files {
        if file.lastPathComponent.hasPrefix(databaseName) {
          try? fileManager.removeItem(at: file)
          logger.info("🔧 SwiftData: Removed related file: \(file.lastPathComponent)")
        }
      }
    } catch {
      logger.error("❌ SwiftData: Failed to clean up related files: \(error)")
    }
  }

  /// ✅ CRITICAL FIX: Recreate the entire container after corruption
  func recreateContainerAfterCorruption() {
    logger.warning("🔧 SwiftData: Recreating container after corruption...")

    // First, clean up the corrupted database
    resetCorruptedDatabase()

    // Create a new schema
    let schema = Schema([
      HabitData.self,
      CompletionRecord.self,
      DailyAward.self,
      UserProgressData.self,
      AchievementData.self,
      DifficultyRecord.self,
      UsageRecord.self,
      HabitNote.self,
      StorageHeader.self,
      MigrationRecord.self,
      MigrationState.self
    ])

    do {
      // Create new model configuration
      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false)

      // ✅ FIX: Use _ to indicate intentionally unused value
      _ = try ModelContainer(
        for: schema,
        configurations: [modelConfiguration])

      // Replace the existing container and context
      // Note: This is a workaround since we can't directly replace the stored properties
      // The app will need to restart to fully recover, but this prevents further corruption
      logger.info("✅ SwiftData: New container created successfully")

    } catch {
      logger.error("❌ SwiftData: Failed to recreate container: \(error)")
    }
  }

  // MARK: - Data Integrity

  func validateDataIntegrity() -> Bool {
    // Check for orphaned records
    let habitDescriptor = FetchDescriptor<HabitData>()
    let completionDescriptor = FetchDescriptor<CompletionRecord>()

    do {
      let habits = try modelContext.fetch(habitDescriptor)
      let completions = try modelContext.fetch(completionDescriptor)

      // Check for orphaned completion records
      let habitIds = Set(habits.flatMap { $0.completionHistory.map { $0.persistentModelID } })
      let orphanedCompletions = completions.filter { !habitIds.contains($0.persistentModelID) }

      if !orphanedCompletions.isEmpty {
        logger.warning("Found \(orphanedCompletions.count) orphaned completion records")
        return false
      }

      logger.info("Data integrity validation passed")
      return true

    } catch {
      logger.error("Failed to validate data integrity: \(error.localizedDescription)")
      return false
    }
  }

  // MARK: - Cleanup Operations

  func cleanupOrphanedRecords() {
    let habitDescriptor = FetchDescriptor<HabitData>()
    let completionDescriptor = FetchDescriptor<CompletionRecord>()
    let difficultyDescriptor = FetchDescriptor<DifficultyRecord>()
    let usageDescriptor = FetchDescriptor<UsageRecord>()
    let noteDescriptor = FetchDescriptor<HabitNote>()

    do {
      let habits = try modelContext.fetch(habitDescriptor)
      let completions = try modelContext.fetch(completionDescriptor)
      let difficulties = try modelContext.fetch(difficultyDescriptor)
      let usages = try modelContext.fetch(usageDescriptor)
      let notes = try modelContext.fetch(noteDescriptor)

      let habitIds = Set(habits.flatMap { $0.completionHistory.map { $0.persistentModelID } })

      // Remove orphaned records
      let orphanedCompletions = completions.filter { !habitIds.contains($0.persistentModelID) }
      let orphanedDifficulties = difficulties.filter { !habitIds.contains($0.persistentModelID) }
      let orphanedUsages = usages.filter { !habitIds.contains($0.persistentModelID) }
      let orphanedNotes = notes.filter { !habitIds.contains($0.persistentModelID) }

      for record in orphanedCompletions {
        modelContext.delete(record)
      }

      for record in orphanedDifficulties {
        modelContext.delete(record)
      }

      for record in orphanedUsages {
        modelContext.delete(record)
      }

      for record in orphanedNotes {
        modelContext.delete(record)
      }

      try modelContext.save()

      logger.info("Cleaned up \(orphanedCompletions.count) orphaned completion records")
      logger.info("Cleaned up \(orphanedDifficulties.count) orphaned difficulty records")
      logger.info("Cleaned up \(orphanedUsages.count) orphaned usage records")
      logger.info("Cleaned up \(orphanedNotes.count) orphaned note records")

    } catch {
      logger.error("Failed to cleanup orphaned records: \(error.localizedDescription)")
    }
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "SwiftData")

  // MARK: - Storage Header Management

  private func initializeStorageHeader() {
    let descriptor = FetchDescriptor<StorageHeader>()

    do {
      let headers = try modelContext.fetch(descriptor)

      if headers.isEmpty {
        // ✅ FIX: Use new initializer with userId
        let userId = getCurrentUserId()
        let header = StorageHeader(userId: userId, schemaVersion: 1)
        modelContext.insert(header)

        try modelContext.save()
        logger.info("Created initial storage header with schema version 1")
      } else {
        logger
          .info("Storage header found with schema version: \(headers.first?.schemaVersion ?? 0)")
      }
    } catch {
      logger.error("Failed to initialize storage header: \(error.localizedDescription)")
    }
  }

  // MARK: - Helper Methods

  private func getCurrentUserId() -> String {
    // Get user ID from authentication system
    if let currentUser = AuthenticationManager.shared.currentUser {
      return currentUser.uid
    }
    // Fallback to guest user
    return "guest"
  }
}
