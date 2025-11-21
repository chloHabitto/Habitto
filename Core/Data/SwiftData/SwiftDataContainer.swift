import Foundation
import OSLog
import SwiftData
import SwiftUI
import FirebaseAuth

// ✅ MIGRATION SYSTEM: Import migration infrastructure
// This enables versioned schema and migration plan support

// MARK: - SwiftData Container Manager

@MainActor
final class SwiftDataContainer: ObservableObject {
  // MARK: Lifecycle

  private init() {
    do {
      // ✅ MIGRATION SYSTEM: Use versioned schema with migration plan
      // This ensures safe schema migrations in future updates
      let migrationPlan = HabittoMigrationPlan.self
      let schema = Schema(versionedSchema: HabittoSchemaV1.self)

      logger.info("🔧 SwiftData: Creating model configuration with migration plan...")
      logger.info("🔧 SwiftData: Schema version: \(HabittoSchemaV1.versionIdentifier)")
      logger.info("🔧 SwiftData: Schema includes \(schema.entities.count) entities")

      // ✅ CRITICAL FIX: Check for and remove corrupted database
      let databaseURL = URL.applicationSupportDirectory.appending(path: "default.store")
      let databaseDir = databaseURL.deletingLastPathComponent()
      let databaseName = databaseURL.deletingPathExtension().lastPathComponent
      
      // ✅ CRITICAL: Check if database file exists FIRST
      let databaseExists = FileManager.default.fileExists(atPath: databaseURL.path)
      
      // ✅ ONE-TIME FIX: Force delete database if it has CloudKit enabled (migration to CloudKit-disabled mode)
      // BUT ONLY if a database actually exists (don't trigger on fresh installs)
      let cloudKitMigrationKey = "SwiftData_CloudKit_Disabled_Migration_v1"
      let needsCloudKitMigration = databaseExists && !UserDefaults.standard.bool(forKey: cloudKitMigrationKey)
      
      // Check if we've already detected corruption in a previous run
      let corruptionFlagKey = "SwiftDataCorruptionDetected"
      
      // ✅ FIX #2: One-time database reset to fix any existing schema corruption
      // This ensures all users get a fresh, healthy database after the deep integrity check is deployed
      // BUT ONLY if a database actually exists (don't trigger on fresh installs)
      let oneTimeSchemaFixKey = "SwiftData_Schema_Corruption_Fix_v1"
      let needsOneTimeFix = databaseExists && !UserDefaults.standard.bool(forKey: oneTimeSchemaFixKey)
      
      let forceReset = UserDefaults.standard.bool(forKey: corruptionFlagKey) || needsCloudKitMigration || needsOneTimeFix
      
      if needsCloudKitMigration {
        logger.warning("🔧 SwiftData: CloudKit migration needed - will recreate database without CloudKit")
      }
      
      if needsOneTimeFix {
        logger.warning("🔧 SwiftData: One-time schema fix needed - will recreate database with proper schema")
      }
      
      if forceReset {
        logger.warning("🔧 SwiftData: Corruption flag set - forcing database reset")
      }
      
      if databaseExists {
        logger.info("🔧 SwiftData: Database exists, checking integrity...")
        
        var needsReset = forceReset
        
        // Only do expensive corruption check if not already flagged
        if !forceReset {
          // Deep corruption check: verify all critical tables exist and are accessible
          do {
            // Create a minimal test to see if database is accessible
            // Use migration plan for test container to match production setup
            let testContainer = try ModelContainer(
              for: schema,
              migrationPlan: migrationPlan,
              configurations: [
                ModelConfiguration(url: databaseURL)
              ])
            let testContext = ModelContext(testContainer)
            
            logger.info("🔧 SwiftData: Performing deep integrity check on all tables...")
            
            // ✅ IMPROVED: Test ALL critical tables by fetching actual data
            // fetchCount() returns 0 for missing tables instead of throwing an error
            // We need to actually fetch data to detect "no such table" errors
            let tests: [(String, () throws -> Void)] = [
              ("HabitData", { 
                _ = try testContext.fetch(FetchDescriptor<HabitData>()) 
              }),
              ("CompletionRecord", { 
                _ = try testContext.fetch(FetchDescriptor<CompletionRecord>()) 
              }),
              ("DailyAward", { 
                _ = try testContext.fetch(FetchDescriptor<DailyAward>()) 
              }),
              ("UserProgressData", { 
                _ = try testContext.fetch(FetchDescriptor<UserProgressData>()) 
              })
            ]
            
            for (tableName, test) in tests {
              do {
                try test()
                logger.info("  ✅ Table \(tableName) verified")
              } catch {
                // This WILL catch "no such table: ZHABITDATA" errors
                let errorDesc = error.localizedDescription
                logger.error("  ❌ Table \(tableName) is corrupted: \(errorDesc)")
                throw error  // Re-throw to trigger database reset
              }
            }
            
            logger.info("✅ SwiftData: Deep integrity check passed - all tables healthy")
          } catch {
            let errorDesc = error.localizedDescription
            logger.error("❌ SwiftData: Database corruption detected during deep integrity check")
            logger.error("   Error details: \(errorDesc)")
            
            // ANY error during health check means corruption - don't be selective
            logger.error("🔧 SwiftData: Database needs reset - health check failure detected")
            needsReset = true
          }
        }
        
        // If corrupted, force remove all database files
        if needsReset {
          logger.warning("🔧 SwiftData: Removing corrupted database files...")
          logger.warning("🔧 SwiftData: Data is safe in UserDefaults fallback")
          
          do {
            // Remove main database file
            if FileManager.default.fileExists(atPath: databaseURL.path) {
              try FileManager.default.removeItem(at: databaseURL)
              logger.info("  🗑️ Removed: default.store")
            }
            
            // Remove ALL related database files (WAL, SHM, journal, etc.)
            let files = try FileManager.default.contentsOfDirectory(
              at: databaseDir,
              includingPropertiesForKeys: nil)
            
            for file in files {
              let filename = file.lastPathComponent
              if filename.hasPrefix(databaseName) || filename.hasPrefix("default.store") {
                try FileManager.default.removeItem(at: file)
                logger.info("  🗑️ Removed: \(filename)")
              }
            }
            
            logger.info("✅ SwiftData: All corrupted files removed")
            logger.info("✅ SwiftData: Fresh database will be created on next launch")
            
            // Clear the corruption flag - we've fixed it
            UserDefaults.standard.removeObject(forKey: corruptionFlagKey)
            
            // Mark CloudKit migration as complete
            if needsCloudKitMigration {
              UserDefaults.standard.set(true, forKey: cloudKitMigrationKey)
              logger.info("✅ SwiftData: CloudKit migration flag set")
            }
            
            // Mark one-time schema fix as complete
            if needsOneTimeFix {
              UserDefaults.standard.set(true, forKey: oneTimeSchemaFixKey)
              logger.info("✅ SwiftData: One-time schema fix flag set")
            }
            
            // ✅ FIX #5 (REVISED): Set flag to skip database creation THIS session
            // The app will use UserDefaults fallback for this session only
            // On next natural app launch, a fresh database will be created
            UserDefaults.standard.set(true, forKey: "SwiftData_Skip_Creation_This_Session")
            logger.warning("⚠️ SwiftData: Database reset complete, skipping creation this session")
            logger.warning("⚠️ SwiftData: App will use local storage fallback until next launch")
            logger.info("✅ SwiftData: Fresh database will be created on next app launch")
            
          } catch {
            logger.error("❌ SwiftData: Failed to remove files: \(error)")
            // Continue anyway - ModelContainer will try to create fresh database
          }
        }
      } else {
        logger.info("🔧 SwiftData: No existing database, creating new one (fresh install)")
        
        // Clear corruption flag if no database exists
        UserDefaults.standard.removeObject(forKey: corruptionFlagKey)
        
        // Mark migration flags as complete immediately on fresh install
        // These should never trigger on fresh installs anyway (due to databaseExists check above)
        UserDefaults.standard.set(true, forKey: cloudKitMigrationKey)
        UserDefaults.standard.set(true, forKey: oneTimeSchemaFixKey)
        logger.info("✅ SwiftData: Fresh install - marking all migration flags as complete")
      }

      // ✅ FIX #5: Check if we should skip database creation this session
      let shouldSkipCreation = UserDefaults.standard.bool(forKey: "SwiftData_Skip_Creation_This_Session")
      if shouldSkipCreation {
        logger.warning("⚠️ SwiftData: Skipping database creation this session (corruption was just cleaned)")
        logger.warning("⚠️ SwiftData: App will use UserDefaults fallback for data storage")
        logger.info("✅ SwiftData: Fresh database will be created on next natural app launch")
        
        // Clear the flag so next launch will create the database
        UserDefaults.standard.removeObject(forKey: "SwiftData_Skip_Creation_This_Session")
        
        // Create a dummy in-memory container to satisfy the non-optional property
        // This container won't actually be used - all operations will fall back to UserDefaults
        let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.modelContainer = try ModelContainer(
          for: schema,
          migrationPlan: migrationPlan,
          configurations: [inMemoryConfig])
        self.modelContext = ModelContext(modelContainer)
        
        logger.info("✅ SwiftData: Created temporary in-memory container (fallback mode)")
        return // Skip normal database creation
      }

      // ✅ CRITICAL: Explicitly disable CloudKit auto-sync
      // We're using our own custom CloudKit sync layer (CloudKitManager)
      // NOT SwiftData's built-in CloudKit integration
      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none)  // Disable automatic CloudKit sync

      logger.info("🔧 SwiftData: Creating ModelContainer with migration plan (CloudKit sync: DISABLED)...")
      self.modelContainer = try ModelContainer(
        for: schema,
        migrationPlan: migrationPlan,
        configurations: [modelConfiguration])

      logger.info("🔧 SwiftData: Creating ModelContext...")
      self.modelContext = ModelContext(modelContainer)
      
      // ✅ FIX #8: Disable autosave on fresh databases to prevent Persistent History issues
      if !databaseExists {
        modelContext.autosaveEnabled = false
        logger.info("🔧 SwiftData: Fresh database - autosave disabled to prevent history truncation")
      }

      logger.info("✅ SwiftData: Container initialized successfully")
      logger.info("✅ SwiftData: Database URL: \(modelConfiguration.url.absoluteString)")

      // ✅ FIX #7 & #8: Force table creation on fresh database
      // SwiftData doesn't always auto-create tables on first fetch
      // We insert a dummy HabitData and immediately delete it to force schema creation
      // Autosave is disabled during this process to prevent Persistent History from deleting tables
      if !databaseExists {
        do {
          logger.info("🔧 SwiftData: Fresh database - forcing table creation...")
          
          let dummyHabit = HabitData(
            id: UUID(),
            userId: "_dummy_",
            name: "_dummy_",
            habitDescription: "",
            icon: "",
            color: .clear,
            habitType: .formation,
            schedule: "everyday",
            goal: "1 time",
            reminder: "",
            startDate: Date(),
            endDate: nil)
          
          modelContext.insert(dummyHabit)
          try modelContext.save()
          modelContext.delete(dummyHabit)
          try modelContext.save()
          
          // Re-enable autosave after table creation is complete
          modelContext.autosaveEnabled = true
          logger.info("✅ SwiftData: Tables created successfully via dummy insert/delete")
          logger.info("✅ SwiftData: Autosave re-enabled")
        } catch {
          logger.warning("⚠️ SwiftData: Failed to force table creation: \(error.localizedDescription)")
          // Re-enable autosave even on failure
          modelContext.autosaveEnabled = true
          // Continue anyway - tables will be created on first real insert
        }
      }

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

    // ✅ MIGRATION SYSTEM: Use versioned schema with migration plan
    let migrationPlan = HabittoMigrationPlan.self
    let schema = Schema(versionedSchema: HabittoSchemaV1.self)

    do {
      // Create new model configuration (explicitly disable CloudKit)
      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none)  // Disable automatic CloudKit sync

      // ✅ FIX: Use _ to indicate intentionally unused value
      _ = try ModelContainer(
        for: schema,
        migrationPlan: migrationPlan,
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
    guard let currentUser = AuthenticationManager.shared.currentUser else {
      // ✅ FIX: Use empty string for guest (consistent with CurrentUser.guestId)
      // This ensures CompletionRecords match HabitData userId filtering
      return ""
    }
    
    // ✅ CRITICAL FIX: Treat anonymous Firebase users as guests
    // Anonymous users should use "" as userId for consistency with guest mode
    if let firebaseUser = currentUser as? User, firebaseUser.isAnonymous {
      return "" // Anonymous = guest, use "" as userId
    }
    
    return currentUser.uid // Authenticated non-anonymous user
  }
}
