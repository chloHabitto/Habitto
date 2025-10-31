import Combine
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
  func hasGuestData() -> Bool {
    print("🔍 GuestDataMigration.hasGuestData() - Starting check...")

    // ✅ CRITICAL FIX: Check SwiftData for guest habits (current storage)
    let container = SwiftDataContainer.shared.modelContainer
    let context = container.mainContext
    
    // Check for habits with empty userId or "guest" userId (from anonymous sessions)
    do {
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabits = try context.fetch(allHabitsDescriptor)
      
      // Check for guest/anonymous habits (userId == "" or userId != current authenticated user)
      let currentUserId = AuthenticationManager.shared.currentUser?.uid ?? ""
      let guestHabits = allHabits.filter { habitData in
        habitData.userId.isEmpty || habitData.userId == "guest" || 
        (habitData.userId != currentUserId && !currentUserId.isEmpty)
      }
      
      if !guestHabits.isEmpty {
        print("🔍 GuestDataMigration: Found \(guestHabits.count) guest habits in SwiftData")
        return true
      }
    } catch {
      print("❌ GuestDataMigration: Error checking SwiftData: \(error.localizedDescription)")
    }

    // Check if there are guest habits (new guest key) in UserDefaults
    if let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
       let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData),
       !guestHabits.isEmpty
    {
      print("🔍 GuestDataMigration: Found \(guestHabits.count) guest habits in UserDefaults")
      return true
    }

    // Check for legacy cached habits stored under "SavedHabits"
    if let legacyData = userDefaults.data(forKey: "SavedHabits"),
       let legacyHabits = try? JSONDecoder().decode([Habit].self, from: legacyData),
       !legacyHabits.isEmpty
    {
      print("🔍 GuestDataMigration: Found \(legacyHabits.count) legacy habits in UserDefaults key 'SavedHabits'")
      return true
    }

    // Check if there are guest backup files
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let guestBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent("guest_user")

    if fileManager.fileExists(atPath: guestBackupDir.path) {
      do {
        let contents = try fileManager.contentsOfDirectory(atPath: guestBackupDir.path)
        if !contents.isEmpty {
          print("🔍 GuestDataMigration: Found \(contents.count) guest backup files")
          return true
        }
      } catch {
        print("❌ GuestDataMigration: Error checking guest backup directory: \(error)")
      }
    }

    print("🔍 GuestDataMigration: No guest data found")
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
  func migrateGuestData() async throws {
    guard let currentUser = authManager.currentUser else {
      throw GuestDataMigrationError.noAuthenticatedUser
    }

    guard hasGuestData() else {
      throw GuestDataMigrationError.noGuestData
    }

    guard !hasMigratedGuestData() else {
      print("ℹ️ GuestDataMigration: Guest data already migrated for user \(currentUser.uid)")
      return
    }

    isMigrating = true
    migrationProgress = 0.0
    migrationStatus = "Starting migration..."

    do {
      // Step 0: Create pre-migration safety backup
      migrationStatus = "Creating safety backup..."
      migrationProgress = 0.1
      try await createPreMigrationBackup(for: currentUser.uid)

      // Step 1: Migrate habits data
      migrationStatus = "Migrating habits..."
      migrationProgress = 0.3
      let migratedHabits = try await migrateGuestHabits(to: currentUser.uid)

      // Step 2: Migrate backup files
      migrationStatus = "Migrating backups..."
      migrationProgress = 0.5
      try await migrateGuestBackups(to: currentUser.uid)

      // Step 3: Save to cloud storage for cross-device sync
      migrationStatus = "Syncing to cloud..."
      migrationProgress = 0.7
      try await syncMigratedDataToCloud(migratedHabits)

      // Step 4: Mark migration as complete
      migrationStatus = "Finalizing migration..."
      migrationProgress = 0.9
      let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
      userDefaults.set(true, forKey: migrationKey)

      // Step 5: Migration complete
      migrationStatus = "Migration complete!"
      migrationProgress = 1.0

      print("✅ GuestDataMigration: Successfully migrated guest data for user \(currentUser.uid)")

    } catch {
      migrationStatus = "Migration failed: \(error.localizedDescription)"

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
  }

  /// Get a preview of guest data that would be migrated
  func getGuestDataPreview() -> GuestDataPreview? {
    guard hasGuestData() else { return nil }

    // Get guest habits
    let guestHabits: [Habit] = {
      guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
            let habits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else
      {
        return []
      }
      return habits
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

    return GuestDataPreview(
      habitCount: guestHabits.count,
      backupCount: backupCount,
      habits: guestHabits)
  }

  /// Clear stale guest data that might be causing repeated migration prompts
  func clearStaleGuestData() {
    print("🧹 GuestDataMigration: Clearing stale guest data...")

    // Remove guest habits
    userDefaults.removeObject(forKey: guestHabitsKey)

    // Remove guest backup flag
    userDefaults.removeObject(forKey: guestBackupKey)

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

  private func migrateGuestHabits(to userId: String) async throws -> [Habit] {
    guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
          let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else
    {
      print("ℹ️ GuestDataMigration: No guest habits to migrate")
      return []
    }

    print("🔄 GuestDataMigration: Migrating \(guestHabits.count) guest habits to user \(userId)")

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
    // We'll add guest habits that don't conflict with existing ones
    var mergedHabits = existingHabits
    var migratedCount = 0

    for guestHabit in guestHabits {
      // Check if a habit with the same name already exists
      let existingHabit = existingHabits
        .first { $0.name.lowercased() == guestHabit.name.lowercased() }

      if existingHabit == nil {
        // No conflict, add the guest habit
        mergedHabits.append(guestHabit)
        migratedCount += 1
      } else {
        // Conflict exists, we could either skip or merge data
        // For now, we'll skip conflicting habits to avoid data loss
        print("⚠️ GuestDataMigration: Skipping conflicting habit: \(guestHabit.name)")
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
