import Compression
import CryptoKit
import Foundation
import OSLog
import SwiftData
import UIKit

// MARK: - BackupError

enum BackupError: Error, LocalizedError {
  case vacationModeActive
  case backupFailed(Error)
  case restoreFailed(Error)
  case invalidBackup
  case fileNotFound
  case dataExportFailed(String)
  case fileCreationFailed(String)
  case compressionFailed(String)
  case serializationFailed(String)
  case networkError(String)
  case storageError(String)
  case validationFailed(String)
  case permissionDenied(String)
  case insufficientStorage(String)
  case userNotAuthenticated
  case timeout(String)
  case retryLimitExceeded(Int)
  case corruptedData(String)
  case checksumMismatch(String)
  case versionIncompatible(String)
  case quotaExceeded(String)
  case rateLimited(String)
  case serviceUnavailable(String)
  case authenticationExpired
  case encryptionFailed(String)
  case decryptionFailed(String)
  case unknown(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .vacationModeActive:
      "Backup operations are paused during vacation mode"
    case .backupFailed(let error):
      "Backup failed: \(error.localizedDescription)"
    case .restoreFailed(let error):
      "Restore failed: \(error.localizedDescription)"
    case .invalidBackup:
      "Invalid backup file"
    case .fileNotFound:
      "Backup file not found"
    case .dataExportFailed(let message):
      "Data export failed: \(message)"
    case .fileCreationFailed(let message):
      "File creation failed: \(message)"
    case .compressionFailed(let message):
      "Compression failed: \(message)"
    case .serializationFailed(let message):
      "Serialization failed: \(message)"
    case .networkError(let message):
      "Network error: \(message)"
    case .storageError(let message):
      "Storage error: \(message)"
    case .validationFailed(let message):
      "Validation failed: \(message)"
    case .permissionDenied(let message):
      "Permission denied: \(message)"
    case .insufficientStorage(let message):
      "Insufficient storage: \(message)"
    case .userNotAuthenticated:
      "User must be authenticated to create backups"
    case .timeout(let message):
      "Operation timed out: \(message)"
    case .retryLimitExceeded(let attempts):
      "Retry limit exceeded after \(attempts) attempts"
    case .corruptedData(let message):
      "Data corruption detected: \(message)"
    case .checksumMismatch(let message):
      "Checksum validation failed: \(message)"
    case .versionIncompatible(let message):
      "Version incompatibility: \(message)"
    case .quotaExceeded(let message):
      "Storage quota exceeded: \(message)"
    case .rateLimited(let message):
      "Rate limit exceeded: \(message)"
    case .serviceUnavailable(let message):
      "Service unavailable: \(message)"
    case .authenticationExpired:
      "Authentication has expired"
    case .encryptionFailed(let message):
      "Encryption failed: \(message)"
    case .decryptionFailed(let message):
      "Decryption failed: \(message)"
    case .unknown(let message):
      "Unknown error: \(message)"
    }
  }

  /// Determine if this error is retryable
  var isRetryable: Bool {
    switch self {
    case .networkError,
         .rateLimited,
         .serviceUnavailable,
         .storageError,
         .timeout:
      return true

    case .authenticationExpired,
         .checksumMismatch,
         .corruptedData,
         .insufficientStorage,
         .invalidBackup,
         .permissionDenied,
         .quotaExceeded,
         .userNotAuthenticated,
         .vacationModeActive,
         .versionIncompatible:
      return false

    case .backupFailed(let error),
         .restoreFailed(let error):
      if let backupError = error as? BackupError {
        return backupError.isRetryable
      }
      return true

    default:
      return false
    }
  }

  /// Get suggested retry delay in seconds
  var retryDelay: TimeInterval {
    switch self {
    case .rateLimited:
      60.0 // 1 minute for rate limits
    case .networkError,
         .timeout:
      5.0 // 5 seconds for network issues
    case .serviceUnavailable:
      30.0 // 30 seconds for service issues
    case .storageError:
      10.0 // 10 seconds for storage issues
    default:
      1.0 // 1 second default
    }
  }
}

// MARK: - BackupManager

/// Manages automatic and manual backups with rotating snapshots
@MainActor
class BackupManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Create user-specific backup directory
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let userId = authManager.currentUser?.uid ?? "guest"
    self.backupDirectory = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent(userId)

    // Ensure backup directory exists
    try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

    loadBackupInfo()
    loadAvailableBackups()
  }

  // MARK: Internal

  static let shared = BackupManager()

  @Published var isBackingUp = false
  @Published var lastBackupDate: Date?
  @Published var backupCount = 0
  @Published var availableBackups: [BackupSnapshot] = []
  @Published private(set) var corruptedBackupCount = 0

  let backupDirectory: URL
  
  private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  // MARK: - Public Methods

  /// Create a backup snapshot of current data
  func createBackup() async throws -> BackupSnapshot {
    // Skip backup operations during vacation mode
    if VacationManager.shared.isActive {
      logger.info("Skipping backup creation during vacation mode")
      throw BackupError.vacationModeActive
    }

    logger.info("Starting backup creation")
    isBackingUp = true
    defer { isBackingUp = false }

    // Use retry mechanism for backup creation
    let snapshot = try await performBackupWithRetry(maxAttempts: 3)

    // Update metadata
    lastBackupDate = snapshot.createdAt
    backupCount += 1

    let userLastBackupKey = getUserSpecificKey(lastBackupKey)
    let userBackupCountKey = getUserSpecificKey(backupCountKey)

    userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
    userDefaults.set(backupCount, forKey: userBackupCountKey)

    // Clean up old backups
    try await cleanupOldBackups()

    // Reload available backups
    loadAvailableBackups()

    logger.info("Backup created successfully: \(snapshot.id)")
    return snapshot
  }

  /// Restore from a specific backup
  func restore(from snapshot: BackupSnapshot) async throws {
    logger.info("Starting restore from backup: \(snapshot.id)")

    try await performRestore(snapshot)

    logger.info("Restore completed successfully")
  }

  /// Delete a specific backup
  func deleteBackup(_ snapshot: BackupSnapshot) async throws {
    logger.info("Deleting backup: \(snapshot.id)")

    let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
    
    // Check if file exists before attempting deletion
    guard fileManager.fileExists(atPath: backupURL.path) else {
      logger.info("Backup file already removed or doesn't exist: \(snapshot.id)")
      loadAvailableBackups()
      return
    }
    
    do {
      try fileManager.removeItem(at: backupURL)
      loadAvailableBackups()
      logger.info("Backup deleted successfully")
    } catch {
      logger.error("Failed to delete backup \(snapshot.id): \(error.localizedDescription)")
      throw error
    }
  }

  /// Check if backup is needed based on interval
  func shouldCreateBackup() -> Bool {
    guard let lastBackup = lastBackupDate else { return true }
    return Date().timeIntervalSince(lastBackup) >= backupInterval
  }

  /// Create backup if needed
  func createBackupIfNeeded() async {
    // Skip automatic backups during vacation mode
    if VacationManager.shared.isActive {
      logger.info("Skipping automatic backup during vacation mode")
      return
    }

    guard shouldCreateBackup() else { return }

    do {
      _ = try await createBackup()
      logger.info("Automatic backup created")
    } catch {
      logger.error("Automatic backup failed: \(error.localizedDescription)")
    }
  }

  /// Verify backup integrity with comprehensive validation
  func verifyBackup(_ snapshot: BackupSnapshot) async throws -> Bool {
    let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)

    // Check if backup file exists
    guard fileManager.fileExists(atPath: backupURL.path) else {
      throw BackupError.fileNotFound
    }

    let rawData = try Data(contentsOf: backupURL)
    _ = try decodeBackupPayload(from: rawData)

    let attributes = try fileManager.attributesOfItem(atPath: backupURL.path)
    let fileSize = attributes[.size] as? Int64 ?? 0

    logger.debug("Backup verification passed: \(snapshot.id) (size: \(fileSize) bytes)")
    return true
  }

  /// Perform backup operation with retry logic
  func performBackupWithRetry(maxAttempts: Int = 3) async throws -> BackupSnapshot {
    for attempt in 1 ... maxAttempts {
      do {
        logger.info("Backup attempt \(attempt)/\(maxAttempts)")
        let snapshot = try await performBackup()
        logger.info("Backup succeeded on attempt \(attempt)")
        return snapshot
      } catch let error as BackupError {
        if !error.isRetryable || attempt == maxAttempts {
          logger
            .error(
              "Backup failed (non-retryable or max attempts reached): \(error.localizedDescription)")
          throw error
        }

        logger
          .warning(
            "Backup attempt \(attempt) failed, retrying in \(error.retryDelay) seconds: \(error.localizedDescription)")
        try await Task.sleep(nanoseconds: UInt64(error.retryDelay * 1_000_000_000))

      } catch {
        if attempt == maxAttempts {
          throw BackupError.backupFailed(error)
        }

        logger
          .warning(
            "Backup attempt \(attempt) failed with unknown error, retrying: \(error.localizedDescription)")
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds default delay
      }
    }

    throw BackupError.retryLimitExceeded(maxAttempts)
  }

  // MARK: - Public Wrapper Methods

  /// Public method to create backup data for storage coordinators
  func createBackupData() async throws -> Data {
    // Create comprehensive backup data directly
    let backupData = try await createComprehensiveBackupData(metadata: BackupMetadata(
      version: "1.0",
      createdDate: Date(),
      appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
      deviceModel: UIDevice.current.model,
      osVersion: UIDevice.current.systemVersion,
      userId: authManager.currentUser?.uid ?? "guest",
      backupId: UUID().uuidString), habits: HabitStore.shared.loadHabits())

    return try JSONEncoder().encode(backupData)
  }

  /// Public method to restore from backup data with comprehensive restoration
  func restoreFromData(_ data: Data) async throws -> RestoreResult {
    // Validate and decode backup data
    let backupData = try JSONDecoder().decode(BackupData.self, from: data)

    // Perform pre-restoration validation
    try await validateBackupData(backupData, fileSize: data.count)

    // Verify user compatibility
    guard let currentUser = authManager.currentUser else {
      throw BackupError.userNotAuthenticated
    }

    // Check if backup is from the same user (unless restoring to guest)
    if backupData.metadata.userId != "guest", backupData.metadata.userId != currentUser.uid {
      throw BackupError.validationFailed("Backup is from a different user account")
    }

    // Check version compatibility
    try validateVersionCompatibility(backupData.metadata.appVersion)

    var restoredCount = 0
    var restoredItems: [String] = []

    // Restore habits - handle both legacy and new format
    if let legacyHabits = backupData.habitsLegacy, !legacyHabits.isEmpty {
      // Restore legacy format
      let habitStore = HabitStore.shared
      try await habitStore.saveHabits(legacyHabits)
      restoredCount += legacyHabits.count
      restoredItems.append("\(legacyHabits.count) habits (legacy format)")
    } else if !backupData.habits.isEmpty {
      // Restore new format from SwiftData
      restoredCount += try await restoreSwiftDataBackup(backupData)
      restoredItems.append("\(backupData.habits.count) habits (SwiftData format)")
    }

    // Restore user settings
    try await restoreUserSettings(backupData.userSettings)
    restoredItems.append("User settings")

    // Restore legacy data if present
    if let legacyData = backupData.legacyData {
      try await restoreLegacyData(legacyData)
      restoredItems.append("Legacy migration data")
    }

    logger.info("Restore completed successfully: \(restoredItems.joined(separator: ", "))")

    return RestoreResult(
      success: true,
      restoredItems: restoredCount,
      details: restoredItems,
      backupVersion: backupData.metadata.appVersion,
      restoredAt: Date())
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "BackupManager")
  private let fileManager = FileManager.default
  private let userDefaults = UserDefaults.standard
  private let authManager = AuthenticationManager.shared

  // MARK: - Configuration

  private let maxBackups = 10 // Keep last 10 backups
  private let backupInterval: TimeInterval = 24 * 60 * 60 // 24 hours

  // MARK: - Keys

  private let lastBackupKey = "LastBackupDate"
  private let backupCountKey = "BackupCount"

  // MARK: - User-Specific Keys

  private func getUserSpecificKey(_ baseKey: String) -> String {
    let userId = getCurrentUserId()
    return "\(userId)_\(baseKey)"
  }

  private func getCurrentUserId() -> String {
    if let user = authManager.currentUser {
      return user.uid
    }
    return "" // Empty string for guest users (consistent with SwiftDataStorage)
  }

  /// Validate backup data integrity
  private func validateBackupData(_ backupData: BackupData, fileSize: Int) async throws {
    // Validate metadata
    guard !backupData.metadata.userId.isEmpty else {
      throw BackupError.validationFailed("Missing user ID in metadata")
    }

    // Validate data consistency
    let habitCount = backupData.habits.count
    let completionCount = backupData.completions.count
    let noteCount = backupData.habitNotes.count
    let usageCount = backupData.usageRecords.count

    logger
      .info(
        "Backup validation: \(habitCount) habits, \(completionCount) completions, \(noteCount) notes, \(usageCount) usage records")

    // Validate file size is reasonable
    guard fileSize > 0, fileSize < 100 * 1024 * 1024 else { // 100MB limit
      throw BackupError.validationFailed("Invalid file size: \(fileSize) bytes")
    }

    // Validate habit data integrity
    for habit in backupData.habits {
      guard !habit.id.isEmpty, !habit.name.isEmpty else {
        throw BackupError.corruptedData("Invalid habit data: missing ID or name")
      }

      guard habit.userId == backupData.metadata.userId else {
        throw BackupError.corruptedData("User ID mismatch in habit data")
      }
    }

    // Validate completion records have valid habit references
    let habitIds = Set(backupData.habits.map { $0.id })
    for completion in backupData.completions {
      if let habitId = completion.habitId, !habitIds.contains(habitId) {
        throw BackupError
          .corruptedData("Completion record references non-existent habit: \(habitId)")
      }
    }

    // Validate notes have valid habit references
    for note in backupData.habitNotes {
      if let habitId = note.habitId, !habitIds.contains(habitId) {
        throw BackupError.corruptedData("Note references non-existent habit: \(habitId)")
      }
    }

    // Validate usage records have valid habit references
    for usage in backupData.usageRecords {
      if let habitId = usage.habitId, !habitIds.contains(habitId) {
        throw BackupError.corruptedData("Usage record references non-existent habit: \(habitId)")
      }
    }

    logger.info("Backup validation completed successfully")
  }

  /// Generate checksum for backup data
  private func generateChecksum(for data: Data) -> String {
    let hash = data.withUnsafeBytes { bytes in
      var hasher = SHA256()
      hasher.update(bufferPointer: bytes)
      return hasher.finalize()
    }
    return Data(hash).map { String(format: "%02hhx", $0) }.joined()
  }

  /// Verify checksum for backup data
  private func verifyChecksum(for data: Data, expectedChecksum: String) throws {
    let actualChecksum = generateChecksum(for: data)
    guard actualChecksum == expectedChecksum else {
      throw BackupError.checksumMismatch("Expected: \(expectedChecksum), Actual: \(actualChecksum)")
    }
  }

  /// Restore SwiftData backup format
  private func restoreSwiftDataBackup(_ backupData: BackupData) async throws -> Int {
    let context = SwiftDataContainer.shared.modelContext
    let userId = authManager.currentUser?.uid ?? "guest"

    // Clear existing data for the current user
    try await clearUserData(userId: userId)

    // Restore habits
    var restoredHabits: [HabitData] = []
    for backupHabit in backupData.habits {
      let habitData = HabitData(
        id: UUID(uuidString: backupHabit.id) ?? UUID(),
        userId: userId, // Ensure current user ID
        name: backupHabit.name,
        habitDescription: backupHabit.habitDescription ?? "",
        icon: backupHabit.icon ?? "star",
        color: backupHabit.colorData != nil ? HabitData.decodeColor(backupHabit.colorData!) : .blue,
        habitType: HabitType(rawValue: backupHabit.habitType) ?? .formation,
        schedule: backupHabit.schedule,
        goal: backupHabit.goal,
        reminder: backupHabit.reminder ?? "",
        startDate: backupHabit.startDate,
        endDate: backupHabit.endDate)

      // Set creation and update dates
      habitData.createdAt = backupHabit.createdAt
      habitData.updatedAt = backupHabit.updatedAt

      context.insert(habitData)
      restoredHabits.append(habitData)
    }

    // Restore completion records
    for backupCompletion in backupData.completions {
      if let habitId = backupCompletion.habitId,
         let habit = restoredHabits.first(where: { $0.id.uuidString == habitId })
      {
        let completion = CompletionRecord(
          userId: "legacy",
          habitId: habit.id,
          date: backupCompletion.date,
          dateKey: Habit.dateKey(for: backupCompletion.date),
          isCompleted: backupCompletion.isCompleted,
          progress: backupCompletion.isCompleted ? 1 : 0)  // ✅ Legacy backup compatibility
        habit.completionHistory.append(completion)
      }
    }

    // Restore difficulty records
    for backupDifficulty in backupData.difficulties {
      if let habitId = backupDifficulty.habitId,
         let habit = restoredHabits.first(where: { $0.id.uuidString == habitId })
      {
        let difficulty = DifficultyRecord(
          userId: userId,
          habitId: habit.id,
          dateKey: DateUtils.dateKey(for: backupDifficulty.date),
          difficulty: backupDifficulty.difficulty)
        habit.difficultyHistory.append(difficulty)
      }
    }

    // Restore usage records
    for backupUsage in backupData.usageRecords {
      if let habitId = backupUsage.habitId,
         let habit = restoredHabits.first(where: { $0.id.uuidString == habitId })
      {
        let usage = UsageRecord(
          userId: userId,
          habitId: habit.id,
          key: backupUsage.key,
          value: backupUsage.value)
        habit.usageHistory.append(usage)
      }
    }

    // Restore habit notes
    for backupNote in backupData.habitNotes {
      if let habitId = backupNote.habitId,
         let habit = restoredHabits.first(where: { $0.id.uuidString == habitId })
      {
        let note = HabitNote(
          userId: userId,
          habitId: habit.id,
          content: backupNote.content)
        habit.notes.append(note)
      }
    }

    // Save all changes
    try context.save()

    return restoredHabits.count
  }

  /// Clear existing user data before restoration
  private func clearUserData(userId: String) async throws {
    let context = SwiftDataContainer.shared.modelContext

    // Fetch and delete all user data
    let habits = try context.fetch(FetchDescriptor<HabitData>(
      predicate: #Predicate { $0.userId == userId }))

    for habit in habits {
      context.delete(habit)
    }

    try context.save()
    logger.info("Cleared existing data for user: \(userId)")
  }

  /// Restore user settings from backup
  private func restoreUserSettings(_ settings: BackupUserSettings) async throws {
    let defaults = UserDefaults.standard

    // Restore notification settings
    for (key, value) in settings.notificationSettings {
      defaults.set(value, forKey: key)
    }

    // Restore theme settings (feature flag protected)
    if FeatureFlags.themePersistence {
      for (key, value) in settings.themeSettings {
        defaults.set(value, forKey: key)
      }
      print("🚩 BackupManager: Theme persistence restored")
    } else {
      print("🚩 BackupManager: Theme persistence disabled by feature flag")
    }

    // Restore privacy settings
    for (key, value) in settings.privacySettings {
      defaults.set(value, forKey: key)
    }

    // Restore backup settings
    for (key, value) in settings.backupSettings {
      defaults.set(value, forKey: key)
    }

    // Restore app settings
    for (key, value) in settings.appSettings {
      defaults.set(value, forKey: key)
    }

    logger.info("User settings restored successfully")
  }

  /// Restore legacy data
  private func restoreLegacyData(_ legacyData: LegacyBackupData) async throws {
    let defaults = UserDefaults.standard

    // Restore legacy habits data
    if !legacyData.legacyHabitsData.isEmpty {
      let habitsArray = legacyData.legacyHabitsData.map { dict in
        dict.mapValues { $0.value }
      }
      defaults.set(habitsArray, forKey: "habits")
    }

    // Restore legacy completion data
    if !legacyData.legacyCompletionData.isEmpty {
      defaults.set(legacyData.legacyCompletionData, forKey: "completionHistory")
    }

    // Restore legacy difficulty data
    if !legacyData.legacyDifficultyData.isEmpty {
      defaults.set(legacyData.legacyDifficultyData, forKey: "difficultyHistory")
    }

    // Restore legacy usage data
    if !legacyData.legacyUsageData.isEmpty {
      defaults.set(legacyData.legacyUsageData, forKey: "actualUsage")
    }

    // Restore migration history
    if !legacyData.migrationHistory.isEmpty {
      let migrationArray = legacyData.migrationHistory.map { dict in
        dict.mapValues { $0.value }
      }
      defaults.set(migrationArray, forKey: "migrationHistory")
    }

    // Restore app statistics
    defaults.set(legacyData.totalAppLaunches, forKey: "totalAppLaunches")
    defaults.set(legacyData.totalHabitsCreated, forKey: "totalHabitsCreated")
    defaults.set(legacyData.totalCompletions, forKey: "totalCompletions")

    logger.info("Legacy data restored successfully")
  }

  /// Validate version compatibility
  private func validateVersionCompatibility(_ backupVersion: String) throws {
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    // Simple version check - could be enhanced with semantic versioning
    if backupVersion != currentVersion {
      logger
        .warning(
          "Backup version (\(backupVersion)) differs from current app version (\(currentVersion))")
      // For now, we'll allow restoration but log the difference
      // In the future, we could implement more sophisticated version handling
    }
  }

  // MARK: - Private Methods

  private func performBackup() async throws -> BackupSnapshot {
    let snapshotId = UUID()
    let createdAt = Date()

    // Check if user is authenticated
    guard let currentUser = authManager.currentUser else {
      throw BackupError.userNotAuthenticated
    }

    // Load current habits data
    let habitStore = HabitStore.shared
    let habits = try await habitStore.loadHabits()

    // Create comprehensive backup data
    let metadata = BackupMetadata(userId: currentUser.uid)
    let backupData = try await createComprehensiveBackupData(metadata: metadata, habits: habits)

    // Save backup to file with compression
    let backupURL = backupDirectory.appendingPathComponent(snapshotId.uuidString)
    let fileInfo = try await saveBackupDataWithCompression(backupData, to: backupURL)

    // Create snapshot metadata
    let snapshot = BackupSnapshot(
      id: snapshotId,
      createdAt: createdAt,
      habitCount: habits.count,
      fileSize: Int(fileInfo.fileSize),
      appVersion: backupData.appVersion)

    return snapshot
  }

  /// Create comprehensive backup data from SwiftData
  private func createComprehensiveBackupData(
    metadata: BackupMetadata,
    habits: [Habit]) async throws -> BackupData
  {
    let context = SwiftDataContainer.shared.modelContext
    let userId = metadata.userId

    // Fetch all data for the current user
    let habitData = try context.fetch(FetchDescriptor<HabitData>(
      predicate: #Predicate { $0.userId == userId }))

    // Note: CompletionRecord, DifficultyRecord, UsageRecord, and HabitNote
    // are accessed through relationships, not directly queried
    // We'll collect them from the habit relationships
    var allCompletions: [CompletionRecord] = []
    var allDifficulties: [DifficultyRecord] = []
    var allUsageRecords: [UsageRecord] = []
    var allHabitNotes: [HabitNote] = []

    for habit in habitData {
      allCompletions.append(contentsOf: habit.completionHistory)
      allDifficulties.append(contentsOf: habit.difficultyHistory)
      allUsageRecords.append(contentsOf: habit.usageHistory)
      allHabitNotes.append(contentsOf: habit.notes)
    }

    // Convert to backup models
    let backupHabits = habitData.map { BackupHabitData(from: $0) }

    // Create mappings for related records
    var habitIdMapping: [ObjectIdentifier: String] = [:]
    for habit in habitData {
      habitIdMapping[ObjectIdentifier(habit)] = habit.id.uuidString
    }

    let backupCompletions: [BackupCompletionRecord] = allCompletions.compactMap { completion in
      // Find the habit this completion belongs to
      guard let habitId = habitData.first(where: { $0.completionHistory.contains(completion) })?.id
        .uuidString else
      {
        return nil
      }
      return BackupCompletionRecord(from: completion, habitId: habitId)
    }

    let backupDifficulties: [BackupDifficultyRecord] = allDifficulties.compactMap { difficulty in
      // Find the habit this difficulty belongs to
      guard let habitId = habitData.first(where: { $0.difficultyHistory.contains(difficulty) })?.id
        .uuidString else
      {
        return nil
      }
      return BackupDifficultyRecord(from: difficulty, habitId: habitId)
    }

    let backupUsageRecords: [BackupUsageRecord] = allUsageRecords.compactMap { usage in
      // Find the habit this usage belongs to
      guard let habitId = habitData.first(where: { $0.usageHistory.contains(usage) })?.id
        .uuidString else
      {
        return nil
      }
      return BackupUsageRecord(from: usage, habitId: habitId)
    }

    let backupHabitNotes: [BackupHabitNote] = allHabitNotes.compactMap { note in
      // Find the habit this note belongs to
      guard let habitId = habitData.first(where: { $0.notes.contains(note) })?.id.uuidString else {
        return nil
      }
      return BackupHabitNote(from: note, habitId: habitId)
    }

    // Get user settings and legacy data
    let userSettings = getUserSettings()
    let legacyData = try await getLegacyData()

    return BackupData(
      metadata: metadata,
      habits: backupHabits,
      completions: backupCompletions,
      difficulties: backupDifficulties,
      usageRecords: backupUsageRecords,
      habitNotes: backupHabitNotes,
      userSettings: userSettings,
      legacyData: legacyData,
      habitsLegacy: habits)
  }

  /// Get legacy data from UserDefaults and other sources
  private func getLegacyData() async throws -> LegacyBackupData {
    let defaults = UserDefaults.standard

    // Get legacy habit data from UserDefaults
    let legacyHabitsData = defaults.object(forKey: "habits") as? [[String: Any]] ?? []
    let legacyCompletionData = defaults
      .object(forKey: "completionHistory") as? [String: [String: Int]] ?? [:]
    let legacyDifficultyData = defaults
      .object(forKey: "difficultyHistory") as? [String: [String: Int]] ?? [:]
    let legacyUsageData = defaults.object(forKey: "actualUsage") as? [String: [String: Int]] ?? [:]

    // Get migration status and history
    let migrationHistory = defaults.object(forKey: "migrationHistory") as? [[String: Any]] ?? []
    let hasCompletedMigration = defaults.bool(forKey: "CoreDataMigrationCompleted")
    let lastMigrationDate = defaults.object(forKey: "LastMigrationDate") as? Date

    // Get app statistics
    let totalAppLaunches = defaults.integer(forKey: "totalAppLaunches")
    let totalHabitsCreated = defaults.integer(forKey: "totalHabitsCreated")
    let totalCompletions = defaults.integer(forKey: "totalCompletions")

    return LegacyBackupData(
      legacyHabitsData: legacyHabitsData,
      legacyCompletionData: legacyCompletionData,
      legacyDifficultyData: legacyDifficultyData,
      legacyUsageData: legacyUsageData,
      migrationHistory: migrationHistory,
      hasCompletedMigration: hasCompletedMigration,
      lastMigrationDate: lastMigrationDate,
      totalAppLaunches: totalAppLaunches,
      totalHabitsCreated: totalHabitsCreated,
      totalCompletions: totalCompletions)
  }

  /// Save backup data with optional compression and checksum
  private func saveBackupDataWithCompression(
    _ backupData: BackupData,
    to filePath: URL,
    compressionEnabled: Bool = true) async throws -> BackupFileInfo
  {
    let backupEncoder = JSONEncoder()
    backupEncoder.dateEncodingStrategy = .iso8601
    backupEncoder.outputFormatting = .prettyPrinted

    let jsonData = try backupEncoder.encode(backupData)

    let payloadData: Data
    let isCompressed: Bool

    if compressionEnabled {
      payloadData = try compressData(jsonData)
      isCompressed = true
    } else {
      payloadData = jsonData
      isCompressed = false
    }

    // Generate checksum for integrity verification
    let checksum = generateChecksum(for: payloadData)

    // Wrap payload in envelope so we can detect compression and validate checksum later
    let envelope = BackupFileEnvelope(
      version: 1,
      createdAt: backupData.createdAt,
      appVersion: backupData.appVersion,
      isCompressed: isCompressed,
      checksum: checksum,
      payload: payloadData)

    let envelopeEncoder = JSONEncoder()
    envelopeEncoder.dateEncodingStrategy = .iso8601
    let envelopeData = try envelopeEncoder.encode(envelope)

    // Atomic write to avoid partial/corrupted files
    try envelopeData.write(to: filePath, options: .atomic)

    let attributes = try fileManager.attributesOfItem(atPath: filePath.path)
    let fileSize = attributes[.size] as? Int64 ?? 0

    return BackupFileInfo(
      fileName: filePath.lastPathComponent,
      filePath: filePath.path,
      fileSize: fileSize,
      backupId: backupData.metadata.backupId,
      isCompressed: isCompressed,
      checksum: checksum)
  }

  /// Compress data using compression framework
  private func compressData(_ data: Data) throws -> Data {
    try data.compressed(algorithm: COMPRESSION_LZFSE)
  }

  /// Decompress data using compression framework
  private func decompressData(_ compressedData: Data) throws -> Data {
    try compressedData.decompressed(algorithm: COMPRESSION_LZFSE)
  }

  /// Decode backup payload, supporting both envelope-based and legacy formats
  private func decodeBackupPayload(from rawData: Data) throws -> (BackupData, BackupFileEnvelope?) {
    let envelopeDecoder = JSONDecoder()
    envelopeDecoder.dateDecodingStrategy = .iso8601

    if let envelope = try? envelopeDecoder.decode(BackupFileEnvelope.self, from: rawData) {
      if !envelope.checksum.isEmpty {
        try verifyChecksum(for: envelope.payload, expectedChecksum: envelope.checksum)
      }
      let payload = envelope.isCompressed ? try decompressData(envelope.payload) : envelope.payload
      let backupDecoder = JSONDecoder()
      backupDecoder.dateDecodingStrategy = .iso8601
      let backupData = try backupDecoder.decode(BackupData.self, from: payload)
      return (backupData, envelope)
    }

    let backupDecoder = JSONDecoder()
    backupDecoder.dateDecodingStrategy = .iso8601
    if let legacyBackup = try? backupDecoder.decode(BackupData.self, from: rawData) {
      return (legacyBackup, nil)
    }

    if let decompressed = try? decompressData(rawData),
       let decompressedBackup = try? backupDecoder.decode(BackupData.self, from: decompressed)
    {
      return (decompressedBackup, nil)
    }

    throw BackupError.corruptedData("Unable to decode backup file payload")
  }

  /// Get user settings from UserDefaults
  private func getUserSettings() -> BackupUserSettings {
    let defaults = UserDefaults.standard

    let notificationSettings: [String: Bool] = [
      "dailyReminders": defaults.bool(forKey: "dailyReminders"),
      "weeklyReports": defaults.bool(forKey: "weeklyReports"),
      "streakReminders": defaults.bool(forKey: "streakReminders"),
      "pushNotifications": defaults.bool(forKey: "pushNotifications"),
      "emailNotifications": defaults.bool(forKey: "emailNotifications")
    ]

    // Feature flag protection: Only backup theme settings if feature is enabled
    let themeSettings: [String: String] = FeatureFlags.themePersistence
      ? [
        "selectedTheme": defaults.string(forKey: "selectedTheme") ?? "default",
        "colorScheme": defaults.string(forKey: "colorScheme") ?? "system",
        "accentColor": defaults.string(forKey: "accentColor") ?? "blue"
      ]
      : [:]

    let privacySettings: [String: Bool] = [
      "analyticsEnabled": defaults.bool(forKey: "analyticsEnabled"),
      "crashReportingEnabled": defaults.bool(forKey: "crashReportingEnabled"),
      "dataSharingEnabled": defaults.bool(forKey: "dataSharingEnabled"),
      "locationTrackingEnabled": defaults.bool(forKey: "locationTrackingEnabled")
    ]

    let backupSettings: [String: String] = [
      "automaticBackup": defaults.bool(forKey: "automaticBackup") ? "true" : "false",
      "backupFrequency": defaults.string(forKey: "backupFrequency") ?? "daily",
      "wifiOnlyBackup": defaults.bool(forKey: "wifiOnlyBackup") ? "true" : "false",
      "preferredStorageProvider": defaults.string(forKey: "preferredStorageProvider") ?? "automatic"
    ]

    let appSettings: [String: String] = [
      "language": defaults.string(forKey: "language") ?? "en",
      "timezone": defaults.string(forKey: "timezone") ?? TimeZone.current.identifier,
      "dateFormat": defaults.string(forKey: "dateFormat") ?? "MM/dd/yyyy",
      "firstLaunchDate": defaults.object(forKey: "firstLaunchDate") as? Date != nil
        ? ISO8601DateFormatter().string(from: defaults.object(forKey: "firstLaunchDate") as! Date)
        : "",
      "lastActiveDate": defaults.object(forKey: "lastActiveDate") as? Date != nil
        ? ISO8601DateFormatter().string(from: defaults.object(forKey: "lastActiveDate") as! Date)
        : ""
    ]

    return BackupUserSettings(
      notificationSettings: notificationSettings,
      themeSettings: themeSettings,
      privacySettings: privacySettings,
      backupSettings: backupSettings,
      appSettings: appSettings)
  }

  private func performRestore(_ snapshot: BackupSnapshot) async throws {
    let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
    let rawData = try Data(contentsOf: backupURL)
    let (backupData, _) = try decodeBackupPayload(from: rawData)

    // Restore habits to storage - handle both legacy and new format
    let habitStore = HabitStore.shared
    if let legacyHabits = backupData.habitsLegacy, !legacyHabits.isEmpty {
      // Restore legacy format
      try await habitStore.saveHabits(legacyHabits)
    } else {
      // For new format, we would need to convert BackupHabitData back to Habit
      // For now, we'll just log that new format restoration is not yet implemented
      logger.info("New backup format restoration not yet implemented")
      throw BackupError.restoreFailed(NSError(
        domain: "BackupManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "New backup format restoration not yet implemented"]))
    }

    // Update backup info
    lastBackupDate = snapshot.createdAt
    let userLastBackupKey = getUserSpecificKey(lastBackupKey)
    userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
  }

  private func cleanupOldBackups() async throws {
    let sortedBackups = availableBackups.sorted { $0.createdAt > $1.createdAt }

    if sortedBackups.count > maxBackups {
      let backupsToDelete = Array(sortedBackups.dropFirst(maxBackups))

      for backup in backupsToDelete {
        do {
          try await deleteBackup(backup)
        } catch {
          // Log but don't fail backup creation if cleanup fails
          logger.warning("⚠️ Failed to delete old backup \(backup.id): \(error.localizedDescription)")
          // Continue with other backups even if one fails
        }
      }
    }
  }

  private func loadBackupInfo() {
    let userLastBackupKey = getUserSpecificKey(lastBackupKey)
    let userBackupCountKey = getUserSpecificKey(backupCountKey)

    lastBackupDate = userDefaults.object(forKey: userLastBackupKey) as? Date
    backupCount = userDefaults.integer(forKey: userBackupCountKey)
  }

  private func loadAvailableBackups() {
    do {
      let backupFiles = try fileManager.contentsOfDirectory(
        at: backupDirectory,
        includingPropertiesForKeys: [.creationDateKey])

      var backups: [BackupSnapshot] = []

      for fileURL in backupFiles {
        do {
          let data = try Data(contentsOf: fileURL)
          let (backupData, _) = try decodeBackupPayload(from: data)

          let snapshot = BackupSnapshot(
            id: backupData.id,
            createdAt: backupData.createdAt,
            habitCount: backupData.habits.count,
            fileSize: data.count,
            appVersion: backupData.appVersion)

          backups.append(snapshot)
        } catch {
          // ✅ FIX: Delete corrupted/incompatible backup files
          logger
            .warning(
              "Failed to load backup file \(fileURL.lastPathComponent): \(error.localizedDescription) - Deleting corrupted file")
          let rawData = try? Data(contentsOf: fileURL)
          recordCorruptedBackupTelemetry(for: fileURL, error: error, rawData: rawData)
          do {
            try fileManager.removeItem(at: fileURL)
            logger.info("✅ Deleted corrupted backup file: \(fileURL.lastPathComponent)")
          } catch {
            logger.error("❌ Failed to delete corrupted backup file: \(error.localizedDescription)")
          }
        }
      }

      availableBackups = backups.sorted { $0.createdAt > $1.createdAt }
    } catch {
      logger.error("Failed to load available backups: \(error.localizedDescription)")
      availableBackups = []
    }
  }
  
  private func recordCorruptedBackupTelemetry(for fileURL: URL, error: Error, rawData: Data?) {
    corruptedBackupCount += 1
    
    var telemetryData: [String: Any] = [
      "file": fileURL.lastPathComponent,
      "sessionCount": corruptedBackupCount,
      "error": error.localizedDescription
    ]
    
    if
      let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
      let fileCreationDate = resourceValues.creationDate
    {
      telemetryData["fileCreatedAt"] = iso8601Formatter.string(from: fileCreationDate)
    }
    
    if let rawData {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      if let envelope = try? decoder.decode(BackupFileEnvelope.self, from: rawData) {
        telemetryData["backupCreatedAt"] = iso8601Formatter.string(from: envelope.createdAt)
        telemetryData["appVersion"] = envelope.appVersion
      } else if let metadataProbe = try? decoder.decode(BackupMetadataProbe.self, from: rawData) {
        if let backupCreatedAt = metadataProbe.createdAt {
          telemetryData["backupCreatedAt"] = iso8601Formatter.string(from: backupCreatedAt)
        }
        if let version = metadataProbe.appVersion {
          telemetryData["appVersion"] = version
        }
      }
    }
    
    if telemetryData["appVersion"] == nil {
      telemetryData["appVersion"] = "unknown"
    }
    
    TelemetryService.shared.logEvent("backup.corruption.detected", data: telemetryData)
  }
}

private struct BackupMetadataProbe: Decodable {
  let appVersion: String?
  let createdAt: Date?
}

/// Wrapper written to disk for each backup file so we can detect compression
private struct BackupFileEnvelope: Codable {
  let version: Int
  let createdAt: Date
  let appVersion: String
  let isCompressed: Bool
  let checksum: String
  let payload: Data
}

// MARK: - BackupData

/// Main backup data structure containing all app data
struct BackupData: Codable {
  // MARK: Lifecycle

  init(
    metadata: BackupMetadata,
    habits: [BackupHabitData] = [],
    completions: [BackupCompletionRecord] = [],
    difficulties: [BackupDifficultyRecord] = [],
    usageRecords: [BackupUsageRecord] = [],
    habitNotes: [BackupHabitNote] = [],
    userSettings: BackupUserSettings = BackupUserSettings(),
    legacyData: LegacyBackupData? = nil,
    id: UUID = UUID(),
    createdAt: Date = Date(),
    habitsLegacy: [Habit]? = nil,
    appVersion: String = Bundle.main
      .infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
    dataVersion: String = "1.0")
  {
    self.metadata = metadata
    self.habits = habits
    self.completions = completions
    self.difficulties = difficulties
    self.usageRecords = usageRecords
    self.habitNotes = habitNotes
    self.userSettings = userSettings
    self.legacyData = legacyData
    self.id = id
    self.createdAt = createdAt
    self.habitsLegacy = habitsLegacy
    self.appVersion = appVersion
    self.dataVersion = dataVersion
  }

  // MARK: Internal

  let metadata: BackupMetadata
  let habits: [BackupHabitData]
  let completions: [BackupCompletionRecord]
  let difficulties: [BackupDifficultyRecord]
  let usageRecords: [BackupUsageRecord]
  let habitNotes: [BackupHabitNote]
  let userSettings: BackupUserSettings
  let legacyData: LegacyBackupData?

  // Legacy support for existing backups
  let id: UUID
  let createdAt: Date
  let habitsLegacy: [Habit]?
  let appVersion: String
  let dataVersion: String

  var isValid: Bool {
    !habits
      .isEmpty || (habitsLegacy?.isEmpty == false) ||
      (habits.isEmpty && (habitsLegacy?.isEmpty ?? true))
  }
}

// MARK: - BackupMetadata

/// Backup metadata containing version and timestamp information
struct BackupMetadata: Codable {
  // MARK: Lifecycle

  init(
    version: String = "1.0",
    createdDate: Date = Date(),
    appVersion: String = Bundle.main
      .infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
    deviceModel: String = UIDevice.current.model,
    osVersion: String = UIDevice.current.systemVersion,
    userId: String,
    backupId: String = UUID().uuidString)
  {
    self.version = version
    self.createdDate = createdDate
    self.appVersion = appVersion
    self.deviceModel = deviceModel
    self.osVersion = osVersion
    self.userId = userId
    self.backupId = backupId
  }

  // MARK: Internal

  let version: String
  let createdDate: Date
  let appVersion: String
  let deviceModel: String
  let osVersion: String
  let userId: String
  let backupId: String
}

// MARK: - BackupHabitData

/// Backup representation of habit data
struct BackupHabitData: Codable {
  // MARK: Lifecycle

  init(from habitData: HabitData) {
    self.id = habitData.id.uuidString
    self.name = habitData.name
    self.habitDescription = habitData.habitDescription
    self.colorData = habitData.colorData
    self.icon = habitData.icon
    self.goal = habitData.goal
    self.schedule = habitData.schedule
    self.habitType = habitData.habitType
    self.reminder = habitData.reminder
    self.startDate = habitData.startDate
    self.endDate = habitData.endDate
    self.isCompleted = habitData.isCompletedForDate(Date())
    self.streak = habitData.calculateTrueStreak()
    self.createdAt = habitData.createdAt
    self.updatedAt = habitData.updatedAt
    self.userId = habitData.userId
  }

  // MARK: Internal

  let id: String
  let name: String
  let habitDescription: String?
  let colorData: Data?
  let icon: String?
  let goal: String
  let schedule: String
  let habitType: String
  let reminder: String?
  let startDate: Date
  let endDate: Date?
  let isCompleted: Bool
  let streak: Int
  let createdAt: Date
  let updatedAt: Date
  let userId: String
}

// MARK: - BackupCompletionRecord

/// Backup representation of completion records
struct BackupCompletionRecord: Codable {
  // MARK: Lifecycle

  init(from completion: CompletionRecord, habitId: String? = nil) {
    self.id = UUID().uuidString // Generate new ID since CompletionRecord doesn't have one
    self.habitId = habitId
    self.date = completion.date
    self.isCompleted = completion.isCompleted
    self.createdAt = completion.createdAt
  }

  // MARK: Internal

  let id: String
  let habitId: String?
  let date: Date
  let isCompleted: Bool
  let createdAt: Date
}

// MARK: - BackupDifficultyRecord

/// Backup representation of difficulty records
struct BackupDifficultyRecord: Codable {
  // MARK: Lifecycle

  init(from difficulty: DifficultyRecord, habitId: String? = nil) {
    self.id = UUID().uuidString // Generate new ID since DifficultyRecord doesn't have one
    self.habitId = habitId
    self.date = difficulty.date
    self.difficulty = difficulty.difficulty
    self.createdAt = difficulty.createdAt
  }

  // MARK: Internal

  let id: String
  let habitId: String?
  let date: Date
  let difficulty: Int
  let createdAt: Date
}

// MARK: - BackupUsageRecord

/// Backup representation of usage records
struct BackupUsageRecord: Codable {
  // MARK: Lifecycle

  init(from usage: UsageRecord, habitId: String? = nil) {
    self.id = UUID().uuidString // Generate new ID since UsageRecord doesn't have one
    self.habitId = habitId
    self.key = usage.key
    self.value = usage.value
    self.createdAt = usage.createdAt
  }

  // MARK: Internal

  let id: String
  let habitId: String?
  let key: String
  let value: Int
  let createdAt: Date
}

// MARK: - BackupHabitNote

/// Backup representation of habit notes
struct BackupHabitNote: Codable {
  // MARK: Lifecycle

  init(from note: HabitNote, habitId: String? = nil) {
    self.id = UUID().uuidString // Generate new ID since HabitNote doesn't have one
    self.habitId = habitId
    self.content = note.content
    self.createdAt = note.createdAt
    self.updatedAt = note.updatedAt
  }

  // MARK: Internal

  let id: String
  let habitId: String?
  let content: String
  let createdAt: Date
  let updatedAt: Date
}

// MARK: - BackupUserSettings

/// Backup representation of user settings
struct BackupUserSettings: Codable {
  // MARK: Lifecycle

  init(
    notificationSettings: [String: Bool] = [:],
    themeSettings: [String: String] = [:],
    privacySettings: [String: Bool] = [:],
    backupSettings: [String: String] = [:],
    appSettings: [String: String] = [:])
  {
    self.notificationSettings = notificationSettings
    self.themeSettings = themeSettings
    self.privacySettings = privacySettings
    self.backupSettings = backupSettings
    self.appSettings = appSettings
  }

  // MARK: Internal

  let notificationSettings: [String: Bool]
  let themeSettings: [String: String]
  let privacySettings: [String: Bool]
  let backupSettings: [String: String]
  let appSettings: [String: String]
}

// MARK: - LegacyBackupData

/// Legacy data from UserDefaults and migration history
struct LegacyBackupData: Codable {
  // MARK: Lifecycle

  init(
    legacyHabitsData: [[String: Any]] = [],
    legacyCompletionData: [String: [String: Int]] = [:],
    legacyDifficultyData: [String: [String: Int]] = [:],
    legacyUsageData: [String: [String: Int]] = [:],
    migrationHistory: [[String: Any]] = [],
    hasCompletedMigration: Bool = false,
    lastMigrationDate: Date? = nil,
    totalAppLaunches: Int = 0,
    totalHabitsCreated: Int = 0,
    totalCompletions: Int = 0)
  {
    self.legacyHabitsData = legacyHabitsData.map { dict in
      dict.mapValues { AnyCodable($0) }
    }
    self.legacyCompletionData = legacyCompletionData
    self.legacyDifficultyData = legacyDifficultyData
    self.legacyUsageData = legacyUsageData
    self.migrationHistory = migrationHistory.map { dict in
      dict.mapValues { AnyCodable($0) }
    }
    self.hasCompletedMigration = hasCompletedMigration
    self.lastMigrationDate = lastMigrationDate
    self.totalAppLaunches = totalAppLaunches
    self.totalHabitsCreated = totalHabitsCreated
    self.totalCompletions = totalCompletions
  }

  // MARK: Internal

  let legacyHabitsData: [[String: AnyCodable]]
  let legacyCompletionData: [String: [String: Int]]
  let legacyDifficultyData: [String: [String: Int]]
  let legacyUsageData: [String: [String: Int]]
  let migrationHistory: [[String: AnyCodable]]
  let hasCompletedMigration: Bool
  let lastMigrationDate: Date?
  let totalAppLaunches: Int
  let totalHabitsCreated: Int
  let totalCompletions: Int
}

// MARK: - BackupFileInfo

/// Backup file information for tracking and management
struct BackupFileInfo: Codable {
  // MARK: Lifecycle

  init(
    fileName: String,
    filePath: String,
    fileSize: Int64,
    createdDate: Date = Date(),
    backupId: String,
    isCompressed: Bool = false,
    checksum: String? = nil)
  {
    self.fileName = fileName
    self.filePath = filePath
    self.fileSize = fileSize
    self.createdDate = createdDate
    self.backupId = backupId
    self.isCompressed = isCompressed
    self.checksum = checksum
  }

  // MARK: Internal

  let fileName: String
  let filePath: String
  let fileSize: Int64
  let createdDate: Date
  let backupId: String
  let isCompressed: Bool
  let checksum: String?
}

// MARK: - BackupResult

/// Backup operation result
struct BackupResult {
  // MARK: Lifecycle

  init(
    success: Bool,
    fileInfo: BackupFileInfo? = nil,
    error: BackupError? = nil,
    duration: TimeInterval = 0)
  {
    self.success = success
    self.fileInfo = fileInfo
    self.error = error
    self.duration = duration
  }

  // MARK: Internal

  let success: Bool
  let fileInfo: BackupFileInfo?
  let error: BackupError?
  let duration: TimeInterval
}

// MARK: - BackupSnapshot

struct BackupSnapshot: Identifiable, Codable {
  let id: UUID
  let createdAt: Date
  let habitCount: Int
  let fileSize: Int
  let appVersion: String

  var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: createdAt)
  }

  var formattedSize: String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(fileSize))
  }
}

// MARK: - RestoreResult

/// Result of a backup restoration operation
struct RestoreResult: Codable {
  let success: Bool
  let restoredItems: Int
  let details: [String]
  let backupVersion: String
  let restoredAt: Date

  var summary: String {
    if success {
      "Successfully restored \(restoredItems) items from backup (v\(backupVersion))"
    } else {
      "Restoration failed"
    }
  }

  var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: restoredAt)
  }
}

// MARK: - BackupMetadataTracker

/// Enhanced backup metadata for comprehensive tracking
struct BackupMetadataTracker: Codable {
  // MARK: Lifecycle

  init(
    backupId: String = UUID().uuidString,
    createdAt: Date = Date(),
    userId: String,
    appVersion: String = Bundle.main
      .infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
    dataVersion: String = "1.0",
    deviceModel: String = UIDevice.current.model,
    osVersion: String = UIDevice.current.systemVersion,
    totalHabits: Int,
    totalCompletions: Int,
    totalNotes: Int,
    totalUsageRecords: Int,
    fileSize: Int64,
    compressionRatio: Double? = nil,
    backupDuration: TimeInterval = 0,
    storageProvider: String = "local",
    isCompressed: Bool = false,
    checksum: String? = nil,
    backupType: BackupType = .manual,
    success: Bool = true,
    errorMessage: String? = nil)
  {
    self.backupId = backupId
    self.createdAt = createdAt
    self.userId = userId
    self.appVersion = appVersion
    self.dataVersion = dataVersion
    self.deviceModel = deviceModel
    self.osVersion = osVersion
    self.totalHabits = totalHabits
    self.totalCompletions = totalCompletions
    self.totalNotes = totalNotes
    self.totalUsageRecords = totalUsageRecords
    self.fileSize = fileSize
    self.compressionRatio = compressionRatio
    self.backupDuration = backupDuration
    self.storageProvider = storageProvider
    self.isCompressed = isCompressed
    self.checksum = checksum
    self.backupType = backupType
    self.success = success
    self.errorMessage = errorMessage
  }

  // MARK: Internal

  enum BackupType: String, Codable {
    case automatic
    case manual
    case scheduled
    case migration
  }

  let backupId: String
  let createdAt: Date
  let userId: String
  let appVersion: String
  let dataVersion: String
  let deviceModel: String
  let osVersion: String
  let totalHabits: Int
  let totalCompletions: Int
  let totalNotes: Int
  let totalUsageRecords: Int
  let fileSize: Int64
  let compressionRatio: Double?
  let backupDuration: TimeInterval
  let storageProvider: String
  let isCompressed: Bool
  let checksum: String?
  let backupType: BackupType
  let success: Bool
  let errorMessage: String?
}

// MARK: - Data Compression Extensions

extension Data {
  func compressed(algorithm: compression_algorithm) throws -> Data {
    try withUnsafeBytes { bytes in
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count)
      defer { buffer.deallocate() }

      let compressedSize = compression_encode_buffer(
        buffer, self.count,
        bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
        nil, algorithm)

      guard compressedSize > 0 else {
        throw BackupError.compressionFailed("Compression failed")
      }

      return Data(bytes: buffer, count: compressedSize)
    }
  }

  func decompressed(algorithm: compression_algorithm) throws -> Data {
    try withUnsafeBytes { bytes in
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count * 4) // Estimate
      defer { buffer.deallocate() }

      let decompressedSize = compression_decode_buffer(
        buffer, self.count * 4,
        bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
        nil, algorithm)

      guard decompressedSize > 0 else {
        throw BackupError.compressionFailed("Decompression failed")
      }

      return Data(bytes: buffer, count: decompressedSize)
    }
  }
}
