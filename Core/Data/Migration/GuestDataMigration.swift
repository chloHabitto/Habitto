import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftData

// MARK: - GuestDataMigration

/// Manages migration of guest user data to authenticated user accounts
@MainActor
final class GuestDataMigration: ObservableObject {
  // MARK: Internal

  // MARK: - Published Properties

  @Published var isMigrating = false
  @Published var migrationProgress = 0.0
  @Published var migrationStatus = ""

  // MARK: - Public Methods

  /// Check if there's guest data that can be migrated
  /// ✅ FIX: Only checks SwiftData for habits with userId = "" (real guest data)
  /// Does NOT check UserDefaults 'SavedHabits' - that's stale backup data, not guest data
  func hasGuestData() -> Bool {
    print("🔍 GuestDataMigration.hasGuestData() - Starting check...")

    // ✅ CRITICAL FIX: ONLY check SwiftData for guest habits (current storage)
    // Guest data = habits with userId == "" (empty string)
    // Do NOT check UserDefaults 'SavedHabits' - that's a backup mechanism, not guest data detection
    let container = SwiftDataContainer.shared.modelContainer
    let context = container.mainContext
    
    do {
      // Only check for habits with empty userId (true guest data)
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { habit in
          habit.userId == ""
        }
      )
      let guestHabits = try context.fetch(descriptor)
      
      if !guestHabits.isEmpty {
        print("🔍 GuestDataMigration: Found \(guestHabits.count) guest habits in SwiftData (userId = '')")
        return true
      }
    } catch {
      print("❌ GuestDataMigration: Error checking SwiftData: \(error.localizedDescription)")
    }

    print("🔍 GuestDataMigration: No guest data found (no habits with userId = '')")
    return false
  }

  /// Check if guest data has already been migrated for the current user
  func hasMigratedGuestData() -> Bool {
    guard let currentUser = authManager.currentUser else {
      print("🔍 GuestDataMigration.hasMigratedGuestData() - No authenticated user")
      return false
    }
    let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
    let hasMigrated = userDefaults.bool(forKey: migrationKey)
    print(
      "🔍 GuestDataMigration.hasMigratedGuestData() - User: \(currentUser.uid), Key: \(migrationKey), Migrated: \(hasMigrated)")
    return hasMigrated
  }

  /// Migrate guest data to the current authenticated user
  /// This replaces cloud data with local guest data (used for "Keep Local Data" option)
  func migrateGuestData() async throws {
    let timestamp = Date()
    print("🔄 [MIGRATION] \(timestamp) GuestDataMigration.migrateGuestData() - START")
    
    guard let currentUser = authManager.currentUser else {
      print("❌ [MIGRATION] \(timestamp) No authenticated user")
      throw GuestDataMigrationError.noAuthenticatedUser
    }

    guard hasGuestData() else {
      print("❌ [MIGRATION] \(timestamp) No guest data found")
      throw GuestDataMigrationError.noGuestData
    }

    guard !hasMigratedGuestData() else {
      print("ℹ️ [MIGRATION] \(timestamp) Guest data already migrated for user \(currentUser.uid)")
      return
    }

    isMigrating = true
    migrationProgress = 0.0
    migrationStatus = "Starting migration..."
    print("🔄 [MIGRATION] \(timestamp) Migration started - isMigrating = true")

    do {
      // Step 0: Delete existing cloud data (for "Keep Local Data" option)
      let step0Timestamp = Date()
      migrationStatus = "Replacing account data..."
      migrationProgress = 0.1
      print("🔄 [MIGRATION] \(step0Timestamp) Step 0: Deleting existing cloud data...")
      try await deleteCloudHabits(for: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 0: Cloud data deleted")

      // Step 1: Create pre-migration safety backup
      let step1Timestamp = Date()
      migrationStatus = "Creating safety backup..."
      migrationProgress = 0.2
      print("🔄 [MIGRATION] \(step1Timestamp) Step 1: Creating safety backup...")
      try await createPreMigrationBackup(for: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 1: Safety backup created")

      // Step 2: Migrate SwiftData (habits, CompletionRecords, streaks, etc.)
      let step2Timestamp = Date()
      migrationStatus = "Migrating habits and progress..."
      migrationProgress = 0.4
      print("🔄 [MIGRATION] \(step2Timestamp) Step 2: Migrating SwiftData...")
      try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(from: "", to: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 2: SwiftData migration completed")
      
      // Step 3: Migrate legacy UserDefaults habits (for backward compatibility)
      let step3Timestamp = Date()
      migrationStatus = "Migrating legacy data..."
      migrationProgress = 0.5
      print("🔄 [MIGRATION] \(step3Timestamp) Step 3: Migrating legacy UserDefaults...")
      let migratedHabits = try await migrateGuestHabits(to: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 3: Legacy data migration completed - \(migratedHabits.count) habits")

      // Step 4: Migrate backup files
      let step4Timestamp = Date()
      migrationStatus = "Migrating backups..."
      migrationProgress = 0.7
      print("🔄 [MIGRATION] \(step4Timestamp) Step 4: Migrating backup files...")
      try await migrateGuestBackups(to: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 4: Backup migration completed")

      // Step 5: Save to cloud storage for cross-device sync
      let step5Timestamp = Date()
      migrationStatus = "Syncing to cloud..."
      migrationProgress = 0.9
      print("🔄 [MIGRATION] \(step5Timestamp) Step 5: Syncing to cloud...")
      try await syncMigratedDataToCloud(migratedHabits)
      print("✅ [MIGRATION] \(Date()) Step 5: Cloud sync completed")

      // Step 6: Mark migration as complete
      let step6Timestamp = Date()
      migrationStatus = "Finalizing migration..."
      migrationProgress = 0.95
      print("🔄 [MIGRATION] \(step6Timestamp) Step 6: Finalizing migration...")
      let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
      userDefaults.set(true, forKey: migrationKey)
      print("✅ [MIGRATION] \(Date()) Step 6: Migration marked as complete in UserDefaults")

      // Step 7: Migration complete
      migrationStatus = "Migration complete!"
      migrationProgress = 1.0

      let completeTimestamp = Date()
      let totalDuration = completeTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION] \(completeTimestamp) GuestDataMigration.migrateGuestData() - COMPLETE")
      print("   Successfully migrated guest data for user \(currentUser.uid)")
      print("   Total duration: \(String(format: "%.2f", totalDuration))s")

    } catch {
      let errorTimestamp = Date()
      migrationStatus = "Migration failed: \(error.localizedDescription)"
      print("❌ [MIGRATION] \(errorTimestamp) Migration failed: \(error.localizedDescription)")

      // Inform user about safety backup location
      let backupLocationKey = "pre_migration_backup_\(currentUser.uid)"
      if let backupPath = userDefaults.string(forKey: backupLocationKey) {
        print("❌ GuestDataMigration: Migration failed, but your data is safe!")
        print("   Pre-migration backup available at: \(backupPath)")
        print("   You can restore from this backup if needed")
      }

      isMigrating = false
      throw error
    }

    isMigrating = false
    print("🔄 [MIGRATION] \(Date()) Migration state reset - isMigrating = false")
  }

  /// Get a preview of guest data that would be migrated
  /// ✅ FIX: Only checks SwiftData for habits with userId = "" (real guest data)
  func getGuestDataPreview() -> GuestDataPreview? {
    guard hasGuestData() else { return nil }

    // ✅ CRITICAL FIX: Count habits from SwiftData (current storage) with userId = ""
    let container = SwiftDataContainer.shared.modelContainer
    let context = container.mainContext
    
    let guestHabits: [Habit] = {
      do {
        // Fetch guest habits from SwiftData (userId == "" only)
        let descriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate<HabitData> { habit in
            habit.userId == ""
          }
        )
        let habitDataList = try context.fetch(descriptor)
        return habitDataList.map { $0.toHabit() }
      } catch {
        print("❌ GuestDataMigration: Error fetching guest habits from SwiftData: \(error)")
        return []
      }
    }()

    // Get guest backup count
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let guestBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent("guest_user")
    var backupCount = 0

    if fileManager.fileExists(atPath: guestBackupDir.path) {
      do {
        let contents = try fileManager.contentsOfDirectory(atPath: guestBackupDir.path)
        backupCount = contents.count
      } catch {
        print("❌ GuestDataMigration: Error counting guest backups: \(error)")
      }
    }

    print("🔍 GuestDataMigration: Preview - \(guestHabits.count) habits, \(backupCount) backups")
    return GuestDataPreview(
      habitCount: guestHabits.count,
      backupCount: backupCount,
      habits: guestHabits)
  }

  /// Get a preview of cloud data from Firestore
  func getCloudDataPreview() async -> CloudDataPreview? {
    guard let currentUser = authManager.currentUser else {
      print("🔍 GuestDataMigration: No authenticated user for cloud preview")
      return nil
    }

    let db = Firestore.firestore()
    
    do {
      // Fetch habits from Firestore
      let habitsSnapshot = try await db.collection("users")
        .document(currentUser.uid)
        .collection("habits")
        .whereField("isActive", isEqualTo: true)
        .getDocuments()
      
      let habitCount = habitsSnapshot.documents.count
      
      // Fetch user progress (XP, level) from Firestore
      let progressDoc = try await db.collection("users")
        .document(currentUser.uid)
        .collection("xp")
        .document("state")
        .getDocument()
      
      var totalXP = 0
      var level = 1
      
      if progressDoc.exists, let data = progressDoc.data() {
        totalXP = data["totalXP"] as? Int ?? 0
        level = data["level"] as? Int ?? 1
      }
      
      print("🔍 GuestDataMigration: Cloud preview - \(habitCount) habits, Level \(level), \(totalXP) XP")
      
      return CloudDataPreview(
        habitCount: habitCount,
        totalXP: totalXP,
        level: level)
    } catch {
      print("❌ GuestDataMigration: Error fetching cloud data preview: \(error.localizedDescription)")
      // If error, assume no cloud data exists
      return nil
    }
  }

  /// Clear stale guest data that might be causing repeated migration prompts
  /// ✅ FIX: Also removes stale 'SavedHabits' UserDefaults key
  func clearStaleGuestData() {
    print("🧹 GuestDataMigration: Clearing stale guest data...")

    // Remove guest habits
    userDefaults.removeObject(forKey: guestHabitsKey)

    // Remove guest backup flag
    userDefaults.removeObject(forKey: guestBackupKey)
    
    // ✅ FIX: Remove stale 'SavedHabits' UserDefaults key (backup mechanism, not guest data)
    userDefaults.removeObject(forKey: "SavedHabits")
    print("🧹 GuestDataMigration: Removed stale 'SavedHabits' UserDefaults key")

    // Remove guest backup directory
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let guestBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent("guest_user")

    if fileManager.fileExists(atPath: guestBackupDir.path) {
      do {
        try fileManager.removeItem(at: guestBackupDir)
        print("🧹 GuestDataMigration: Removed guest backup directory")
      } catch {
        print("❌ GuestDataMigration: Failed to remove guest backup directory: \(error)")
      }
    }

    print("🧹 GuestDataMigration: Stale guest data cleared")
  }

  /// Force mark migration as completed for current user (emergency fix)
  func forceMarkMigrationCompleted() {
    guard let currentUser = authManager.currentUser else {
      print("❌ GuestDataMigration: Cannot mark migration completed - no authenticated user")
      return
    }

    let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
    userDefaults.set(true, forKey: migrationKey)
    print("✅ GuestDataMigration: Force marked migration as completed for user: \(currentUser.uid)")
  }

  /// Merge guest data with cloud data (Keep Both option)
  /// This keeps cloud data and adds local guest data to the account
  func mergeGuestDataWithCloud() async throws {
    let timestamp = Date()
    print("🔄 [MIGRATION] \(timestamp) GuestDataMigration.mergeGuestDataWithCloud() - START")
    
    guard let currentUser = authManager.currentUser else {
      print("❌ [MIGRATION] \(timestamp) No authenticated user")
      throw GuestDataMigrationError.noAuthenticatedUser
    }

    guard hasGuestData() else {
      print("❌ [MIGRATION] \(timestamp) No guest data found")
      throw GuestDataMigrationError.noGuestData
    }

    isMigrating = true
    migrationProgress = 0.0
    migrationStatus = "Merging your data..."
    print("🔄 [MIGRATION] \(timestamp) Merge started - isMigrating = true")

    do {
      // Step 1: Migrate SwiftData (habits, CompletionRecords, streaks, etc.)
      // This will add guest habits to the authenticated user without replacing cloud data
      let step1Timestamp = Date()
      migrationStatus = "Adding your local habits..."
      migrationProgress = 0.3
      print("🔄 [MIGRATION] \(step1Timestamp) Step 1: Migrating SwiftData...")
      try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(from: "", to: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 1: SwiftData migration completed")
      
      // Step 2: Migrate legacy UserDefaults habits (for backward compatibility)
      // For merge, keep all habits even if names match
      let step2Timestamp = Date()
      migrationStatus = "Adding legacy data..."
      migrationProgress = 0.5
      print("🔄 [MIGRATION] \(step2Timestamp) Step 2: Migrating legacy UserDefaults...")
      let migratedHabits = try await migrateGuestHabits(to: currentUser.uid, keepDuplicates: true)
      print("✅ [MIGRATION] \(Date()) Step 2: Legacy data migration completed - \(migratedHabits.count) habits")

      // Step 3: Migrate backup files
      let step3Timestamp = Date()
      migrationStatus = "Migrating backups..."
      migrationProgress = 0.7
      print("🔄 [MIGRATION] \(step3Timestamp) Step 3: Migrating backup files...")
      try await migrateGuestBackups(to: currentUser.uid)
      print("✅ [MIGRATION] \(Date()) Step 3: Backup migration completed")

      // Step 4: Save to cloud storage for cross-device sync
      let step4Timestamp = Date()
      migrationStatus = "Syncing to cloud..."
      migrationProgress = 0.9
      print("🔄 [MIGRATION] \(step4Timestamp) Step 4: Syncing to cloud...")
      try await syncMigratedDataToCloud(migratedHabits)
      print("✅ [MIGRATION] \(Date()) Step 4: Cloud sync completed")

      // Step 5: Mark migration as complete
      let step5Timestamp = Date()
      migrationStatus = "Finalizing..."
      migrationProgress = 1.0
      print("🔄 [MIGRATION] \(step5Timestamp) Step 5: Finalizing...")
      let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
      userDefaults.set(true, forKey: migrationKey)
      print("✅ [MIGRATION] \(Date()) Step 5: Migration marked as complete in UserDefaults")

      migrationStatus = "Merge complete!"
      
      let completeTimestamp = Date()
      let totalDuration = completeTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION] \(completeTimestamp) GuestDataMigration.mergeGuestDataWithCloud() - COMPLETE")
      print("   Successfully merged guest data with cloud data for user \(currentUser.uid)")
      print("   Total duration: \(String(format: "%.2f", totalDuration))s")

    } catch {
      let errorTimestamp = Date()
      migrationStatus = "Merge failed: \(error.localizedDescription)"
      print("❌ [MIGRATION] \(errorTimestamp) Merge failed: \(error.localizedDescription)")

      isMigrating = false
      throw error
    }

    isMigrating = false
    print("🔄 [MIGRATION] \(Date()) Merge state reset - isMigrating = false")
  }

  /// Clear guest data only (Keep Account Data option)
  /// This keeps cloud data and removes local guest data
  func clearGuestDataOnly() async throws {
    let timestamp = Date()
    print("🔄 [MIGRATION] \(timestamp) GuestDataMigration.clearGuestDataOnly() - START")
    
    guard let currentUser = authManager.currentUser else {
      print("❌ [MIGRATION] \(timestamp) No authenticated user")
      throw GuestDataMigrationError.noAuthenticatedUser
    }

    isMigrating = true
    migrationProgress = 0.0
    migrationStatus = "Clearing local data..."
    print("🔄 [MIGRATION] \(timestamp) Clear started - isMigrating = true")

    do {
      // Step 1: Clear SwiftData guest habits
      let step1Timestamp = Date()
      migrationProgress = 0.3
      print("🔄 [MIGRATION] \(step1Timestamp) Step 1: Clearing SwiftData guest habits...")
      
      let container = SwiftDataContainer.shared.modelContainer
      let context = container.mainContext
      
      do {
        let descriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate<HabitData> { habit in
            habit.userId == "" || habit.userId == "guest"
          }
        )
        let guestHabits = try context.fetch(descriptor)
        for habit in guestHabits {
          context.delete(habit)
        }
        try context.save()
        print("✅ [MIGRATION] \(Date()) Step 1: Cleared \(guestHabits.count) guest habits from SwiftData")
      } catch {
        print("⚠️ [MIGRATION] Error clearing SwiftData guest habits: \(error)")
      }

      // Step 2: Clear UserDefaults guest data
      let step2Timestamp = Date()
      migrationProgress = 0.6
      print("🔄 [MIGRATION] \(step2Timestamp) Step 2: Clearing UserDefaults guest data...")
      userDefaults.removeObject(forKey: guestHabitsKey)
      userDefaults.removeObject(forKey: guestBackupKey)
      print("✅ [MIGRATION] \(Date()) Step 2: Cleared UserDefaults guest data")

      // Step 3: Clear guest backup directory
      let step3Timestamp = Date()
      migrationProgress = 0.8
      print("🔄 [MIGRATION] \(step3Timestamp) Step 3: Clearing guest backup directory...")
      let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
      let guestBackupDir = documentsPath.appendingPathComponent("Backups")
        .appendingPathComponent("guest_user")

      if fileManager.fileExists(atPath: guestBackupDir.path) {
        try? fileManager.removeItem(at: guestBackupDir)
        print("✅ [MIGRATION] \(Date()) Step 3: Cleared guest backup directory")
      }

      // Step 4: Mark migration as complete (so we don't prompt again)
      let step4Timestamp = Date()
      migrationProgress = 1.0
      print("🔄 [MIGRATION] \(step4Timestamp) Step 4: Finalizing...")
      let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
      userDefaults.set(true, forKey: migrationKey)
      print("✅ [MIGRATION] \(Date()) Step 4: Migration marked as complete")

      migrationStatus = "Complete!"
      
      let completeTimestamp = Date()
      let totalDuration = completeTimestamp.timeIntervalSince(timestamp)
      print("✅ [MIGRATION] \(completeTimestamp) GuestDataMigration.clearGuestDataOnly() - COMPLETE")
      print("   Successfully cleared guest data for user \(currentUser.uid)")
      print("   Total duration: \(String(format: "%.2f", totalDuration))s")

    } catch {
      let errorTimestamp = Date()
      migrationStatus = "Clear failed: \(error.localizedDescription)"
      print("❌ [MIGRATION] \(errorTimestamp) Clear failed: \(error.localizedDescription)")

      isMigrating = false
      throw error
    }

    isMigrating = false
    print("🔄 [MIGRATION] \(Date()) Clear state reset - isMigrating = false")
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let fileManager = FileManager.default
  private let authManager = AuthenticationManager.shared
  private let backupManager = BackupManager.shared

  // Keys for guest data
  private let guestHabitsKey = "guest_habits"
  private let guestBackupKey = "guest_backup_created"
  private let guestDataMigratedKey = "guest_data_migrated"

  // MARK: - Private Methods

  /// Create a safety backup before migration starts
  /// This ensures guest data can be recovered if migration fails
  private func createPreMigrationBackup(for userId: String) async throws {
    print("🔐 GuestDataMigration: Creating pre-migration safety backup...")

    // Check if guest data exists
    guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
          let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else
    {
      print("ℹ️ GuestDataMigration: No guest habits to backup")
      return
    }

    // Create backup directory for guest user if it doesn't exist
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let guestBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent("guest_user")

    if !fileManager.fileExists(atPath: guestBackupDir.path) {
      try fileManager.createDirectory(at: guestBackupDir, withIntermediateDirectories: true)
    }

    // Generate backup filename with timestamp
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [
      .withFullDate,
      .withTime,
      .withDashSeparatorInDate,
      .withColonSeparatorInTime
    ]
    let timestamp = dateFormatter.string(from: Date())
    let backupFilename = "pre_migration_\(timestamp).json"
    let backupURL = guestBackupDir.appendingPathComponent(backupFilename)

    // Create backup metadata
    let backupMetadata: [String: Any] = [
      "type": "pre_migration_safety",
      "timestamp": timestamp,
      "userId": userId,
      "habitCount": guestHabits.count,
      "automatic": true,
      "description": "Automatic safety backup created before guest data migration to user \(userId)"
    ]

    // Create backup data structure
    let backupData: [String: Any] = try [
      "metadata": backupMetadata,
      "habits": JSONSerialization.jsonObject(with: guestHabitsData)
    ]

    // Write backup to file with atomic operation
    let backupJSONData = try JSONSerialization.data(
      withJSONObject: backupData,
      options: [.prettyPrinted, .sortedKeys])
    try backupJSONData.write(to: backupURL, options: [.atomic])

    // Store backup location in UserDefaults for recovery
    let backupLocationKey = "pre_migration_backup_\(userId)"
    userDefaults.set(backupURL.path, forKey: backupLocationKey)

    print("✅ GuestDataMigration: Pre-migration safety backup created at \(backupURL.path)")
    print("   Backed up \(guestHabits.count) habits")
    print("   Backup can be restored if migration fails")
  }

  private func migrateGuestHabits(to userId: String, keepDuplicates: Bool = false) async throws -> [Habit] {
    guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
          let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else
    {
      print("ℹ️ GuestDataMigration: No guest habits to migrate")
      return []
    }

    print("🔄 GuestDataMigration: Migrating \(guestHabits.count) guest habits to user \(userId) (keepDuplicates: \(keepDuplicates))")

    // Load existing user habits
    let userHabitsKey = "\(userId)_habits"
    let existingHabits: [Habit] = {
      guard let userHabitsData = userDefaults.data(forKey: userHabitsKey),
            let habits = try? JSONDecoder().decode([Habit].self, from: userHabitsData) else
      {
        return []
      }
      return habits
    }()

    // Merge guest habits with existing user habits
    var mergedHabits = existingHabits
    var migratedCount = 0

    for guestHabit in guestHabits {
      if keepDuplicates {
        // For merge scenario: keep all habits even if names match
        mergedHabits.append(guestHabit)
        migratedCount += 1
      } else {
        // For replace scenario: skip habits with duplicate names
        let existingHabit = existingHabits
          .first { $0.name.lowercased() == guestHabit.name.lowercased() }

        if existingHabit == nil {
          // No conflict, add the guest habit
          mergedHabits.append(guestHabit)
          migratedCount += 1
        } else {
          // Conflict exists, skip to avoid data loss
          print("⚠️ GuestDataMigration: Skipping conflicting habit: \(guestHabit.name)")
        }
      }
    }

    // Save merged habits to UserDefaults (for backward compatibility)
    let mergedHabitsData = try JSONEncoder().encode(mergedHabits)
    userDefaults.set(mergedHabitsData, forKey: userHabitsKey)

    print("✅ GuestDataMigration: Migrated \(migratedCount) habits to user \(userId)")

    // Return the newly migrated habits for cloud sync
    return Array(mergedHabits.suffix(migratedCount))
  }

  private func migrateGuestBackups(to userId: String) async throws {
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let guestBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent("guest_user")
    let userBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent(userId)

    guard fileManager.fileExists(atPath: guestBackupDir.path) else {
      print("ℹ️ GuestDataMigration: No guest backups to migrate")
      return
    }

    // Ensure user backup directory exists
    try fileManager.createDirectory(at: userBackupDir, withIntermediateDirectories: true)

    // Get all guest backup files
    let guestBackupFiles = try fileManager.contentsOfDirectory(
      at: guestBackupDir,
      includingPropertiesForKeys: nil)

    print(
      "🔄 GuestDataMigration: Migrating \(guestBackupFiles.count) guest backups to user \(userId)")

    for guestBackupFile in guestBackupFiles {
      let fileName = guestBackupFile.lastPathComponent
      let userBackupFile = userBackupDir.appendingPathComponent(fileName)

      // Copy the backup file to user directory
      try fileManager.copyItem(at: guestBackupFile, to: userBackupFile)
    }

    // Migrate backup metadata
    let guestLastBackupKey = "guest_last_backup_date"
    let guestBackupCountKey = "guest_backup_count"
    let userLastBackupKey = "\(userId)_last_backup_date"
    let userBackupCountKey = "\(userId)_backup_count"

    if let lastBackupDate = userDefaults.object(forKey: guestLastBackupKey) as? Date {
      userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
    }

    let guestBackupCount = userDefaults.integer(forKey: guestBackupCountKey)
    let userBackupCount = userDefaults.integer(forKey: userBackupCountKey)
    userDefaults.set(userBackupCount + guestBackupCount, forKey: userBackupCountKey)

    print("✅ GuestDataMigration: Migrated guest backups to user \(userId)")
  }

  /// Delete all cloud habits from Firestore for the given user
  private func deleteCloudHabits(for userId: String) async throws {
    let db = Firestore.firestore()
    
    do {
      print("🔄 GuestDataMigration: Deleting cloud habits for user \(userId)...")
      
      // Get all habits for the user from Firestore
      let snapshot = try await db.collection("users")
        .document(userId)
        .collection("habits")
        .getDocuments()
      
      if snapshot.documents.isEmpty {
        print("ℹ️ GuestDataMigration: No cloud habits to delete")
        return
      }
      
      // Delete in batches
      let batch = db.batch()
      for document in snapshot.documents {
        batch.deleteDocument(document.reference)
      }
      
      try await batch.commit()
      print("✅ GuestDataMigration: Deleted \(snapshot.documents.count) cloud habits")
      
      // Also delete XP state if it exists
      let xpStateRef = db.collection("users")
        .document(userId)
        .collection("xp")
        .document("state")
      
      try? await xpStateRef.delete()
      print("✅ GuestDataMigration: Deleted XP state")
      
    } catch {
      print("❌ GuestDataMigration: Error deleting cloud habits: \(error.localizedDescription)")
      throw error
    }
  }

  /// Sync migrated habits to cloud storage for cross-device access
  private func syncMigratedDataToCloud(_ migratedHabits: [Habit]) async throws {
    guard !migratedHabits.isEmpty else {
      print("ℹ️ GuestDataMigration: No habits to sync to cloud")
      return
    }

    print(
      "🔄 GuestDataMigration: Syncing \(migratedHabits.count) migrated habits to cloud storage...")

    // Use SwiftDataStorage to save habits to cloud storage
    let swiftDataStorage = SwiftDataStorage()
    try await swiftDataStorage.saveHabits(migratedHabits, immediate: true)

    print("✅ GuestDataMigration: Successfully synced migrated habits to cloud storage")
  }
}

// MARK: - GuestDataPreview

struct GuestDataPreview {
  let habitCount: Int
  let backupCount: Int
  let habits: [Habit]
}

// MARK: - CloudDataPreview

struct CloudDataPreview {
  let habitCount: Int
  let totalXP: Int
  let level: Int
}

// MARK: - GuestDataMigrationError

enum GuestDataMigrationError: LocalizedError {
  case noAuthenticatedUser
  case noGuestData
  case migrationFailed(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noAuthenticatedUser:
      "No authenticated user found"
    case .noGuestData:
      "No guest data found to migrate"
    case .migrationFailed(let message):
      "Migration failed: \(message)"
    }
  }
}
