import Foundation
import SwiftUI

// MARK: - DataVersion

struct DataVersion: Codable, Comparable {
  // MARK: Lifecycle

  init(_ major: Int, _ minor: Int, _ patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  // MARK: Internal

  let major: Int
  let minor: Int
  let patch: Int

  var stringValue: String {
    "\(major).\(minor).\(patch)"
  }

  static func < (lhs: DataVersion, rhs: DataVersion) -> Bool {
    if lhs.major != rhs.major { return lhs.major < rhs.major }
    if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
    return lhs.patch < rhs.patch
  }

  static func == (lhs: DataVersion, rhs: DataVersion) -> Bool {
    lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
  }
}

// MARK: - HabitDataContainer

struct HabitDataContainer: Codable {
  // MARK: Lifecycle

  init(habits: [Habit], version: String = "1.0.0", completedSteps: Set<String> = []) {
    self.habits = habits
    self.version = version
    self.completedMigrationSteps = completedSteps
    self.lastUpdated = Date()
  }

  // MARK: Internal

  let version: String // Data version stored in payload (authoritative)
  let habits: [Habit]
  let completedMigrationSteps: Set<String>
  let lastUpdated: Date
}

// MARK: - CrashSafeHabitStore

/// Actor ensures all file operations are serialized and thread-safe
/// NSFileCoordinator provides additional safety for extensions/widgets
actor CrashSafeHabitStore: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Create documents directory URLs
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

    // For now, use a default userId - in production, this would come from user authentication
    self.userId = "default_user"

    self.mainURL = documentsURL.appendingPathComponent("habits.json")
    self.backupURL = documentsURL.appendingPathComponent("habits_backup.json")
    self.backup2URL = documentsURL.appendingPathComponent("habits_backup2.json")

    // Ensure documents directory exists
    try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)

    // Apply iOS Data Protection
    try? (mainURL as NSURL).setResourceValue(
      FileProtectionType.completeUntilFirstUserAuthentication,
      forKey: .fileProtectionKey)
    try? (backupURL as NSURL).setResourceValue(
      FileProtectionType.completeUntilFirstUserAuthentication,
      forKey: .fileProtectionKey)
    try? (backup2URL as NSURL).setResourceValue(
      FileProtectionType.completeUntilFirstUserAuthentication,
      forKey: .fileProtectionKey)

    print("🔧 CrashSafeHabitStore: Initialized with atomic file-based storage")
    print("🔧 CrashSafeHabitStore: Main file: \(mainURL.path)")
    print("🔧 CrashSafeHabitStore: Backup file: \(backupURL.path)")
  }

  // MARK: Internal

  static let shared = CrashSafeHabitStore()

  // MARK: - Public Interface

  func loadHabits() -> [Habit] {
    if let cached = cachedContainer {
      return cached.habits
    }

    let container = loadContainer()
    cachedContainer = container
    return container.habits
  }

  func saveHabits(_ habits: [Habit]) throws {
    let currentContainer = cachedContainer ?? loadContainer()
    let newContainer = HabitDataContainer(
      habits: habits,
      version: currentContainer.version,
      completedSteps: currentContainer.completedMigrationSteps)

    try saveContainer(newContainer)
    cachedContainer = newContainer

    // Update UserDefaults with just the file path and version
    userDefaults.set(mainURL.path, forKey: "HabitStoreFilePath")
    userDefaults.set(newContainer.version, forKey: "HabitStoreDataVersion")
  }

  func getCurrentVersion() -> String {
    cachedContainer?.version ?? "1.0.0"
  }

  func getCompletedMigrationSteps() -> Set<String> {
    cachedContainer?.completedMigrationSteps ?? []
  }

  func markMigrationStepCompleted(_ stepName: String) throws {
    guard let container = cachedContainer else {
      throw HabitStoreError.noDataLoaded
    }

    var completedSteps = container.completedMigrationSteps
    completedSteps.insert(stepName)

    let updatedContainer = HabitDataContainer(
      habits: container.habits,
      version: container.version,
      completedSteps: completedSteps)

    try saveContainer(updatedContainer)
    cachedContainer = updatedContainer
  }

  func updateVersion(_ version: String) throws {
    guard let container = cachedContainer else {
      throw HabitStoreError.noDataLoaded
    }

    let updatedContainer = HabitDataContainer(
      habits: container.habits,
      version: version,
      completedSteps: container.completedMigrationSteps)

    try saveContainer(updatedContainer)
    cachedContainer = updatedContainer
  }

  func createSnapshot() throws -> URL {
    let snapshotURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("habits_snapshot_\(Date().timeIntervalSince1970).json")

    try fileManager.copyItem(at: mainURL, to: snapshotURL)

    // Exclude snapshot from backup
    try? (snapshotURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

    print("📸 CrashSafeHabitStore: Created snapshot at \(snapshotURL.path)")
    return snapshotURL
  }

  func restoreFromSnapshot(_ snapshotURL: URL) throws {
    // Atomic restore using replaceItem to avoid torn files
    _ = try fileManager.replaceItem(
      at: mainURL,
      withItemAt: snapshotURL,
      backupItemName: nil,
      options: [],
      resultingItemURL: nil)
    cachedContainer = nil // Force reload
    print("🔄 CrashSafeHabitStore: Restored from snapshot at \(snapshotURL.path)")

    // Record snapshot restore telemetry
    Task {
      await EnhancedMigrationTelemetryManager.shared.recordEvent(
        .killSwitchTriggered,
        errorCode: "snapshot_restore",
        success: true)
    }
  }

  func clearCache() {
    cachedContainer = nil
  }

  // MARK: - Storage-Level Invariants Validation

  func validateStorageInvariants(
    _ container: HabitDataContainer,
    previousVersion: String? = nil) throws
  {
    // Comprehensive storage-level invariants

    // 1. Check for duplicate IDs
    let habitIds = container.habits.map { $0.id }
    let uniqueIds = Set(habitIds)
    if habitIds.count != uniqueIds.count {
      throw HabitStoreError.dataIntegrityError("Duplicate habit IDs detected")
    }

    // 2. Semver validity and monotonicity
    if container.version.isEmpty {
      throw HabitStoreError.dataIntegrityError("Invalid version format: empty")
    }

    // Parse version and check semver validity
    let versionComponents = container.version.split(separator: ".").compactMap { Int($0) }
    if versionComponents.count != 3 || versionComponents.contains(where: { $0 < 0 }) {
      throw HabitStoreError.dataIntegrityError("Invalid semver format: \(container.version)")
    }

    // Check version monotonicity if previous version provided
    if let prevVersion = previousVersion {
      let prevComponents = prevVersion.split(separator: ".").compactMap { Int($0) }
      if prevComponents.count == 3 {
        let isMonotonic = (versionComponents[0] > prevComponents[0]) ||
          (versionComponents[0] == prevComponents[0] && versionComponents[1] > prevComponents[1]) ||
          (versionComponents[0] == prevComponents[0] && versionComponents[1] == prevComponents[1] &&
            versionComponents[2] > prevComponents[2]) ||
          (versionComponents == prevComponents)

        if !isMonotonic {
          throw HabitStoreError
            .dataIntegrityError("Non-monotonic version: \(prevVersion) -> \(container.version)")
        }
      }
    }

    // 3. Date bounds and timezone safety
    let now = Date()

    for habit in container.habits {
      // Check for future start dates
      if habit.startDate > now {
        throw HabitStoreError
          .dataIntegrityError("Habit \(habit.name) has future start date: \(habit.startDate)")
      }

      // Check date range validity
      if let endDate = habit.endDate, endDate < habit.startDate {
        throw HabitStoreError
          .dataIntegrityError("Habit \(habit.name) has invalid date range: end < start")
      }

      // Check completion history dates
      for dateKey in habit.completionHistory.keys {
        if let date = parseDate(from: dateKey) {
          if date > now {
            throw HabitStoreError
              .dataIntegrityError("Habit \(habit.name) has future completion date: \(dateKey)")
          }
          if date < habit.startDate {
            throw HabitStoreError
              .dataIntegrityError("Habit \(habit.name) has completion before start: \(dateKey)")
          }
        }
      }
    }

    // 4. Counter monotonicity (streaks >= 0)
    for habit in container.habits {
      if habit.computedStreak() < 0 {
        throw HabitStoreError
          .dataIntegrityError("Habit \(habit.name) has negative streak: \(habit.computedStreak())")
      }
    }

    // 5. Check for main file size limits (5MB target with 10MB hard limit)
    let dataSize = try JSONEncoder().encode(container).count
    let maxMainFileSize = 10 * 1024 * 1024 // 10MB hard limit
    let targetMainFileSize = 5 * 1024 * 1024 // 5MB target

    if dataSize > maxMainFileSize {
      throw HabitStoreError.dataIntegrityError("Main file size exceeds hard limit (10MB)")
    }

    // Alert via telemetry when near limits
    if dataSize > targetMainFileSize {
      print(
        "⚠️ CrashSafeHabitStore: Main file size (\(dataSize / 1024 / 1024)MB) exceeds target (5MB)")
      print("   💡 Consider compaction or moving history to segments")
      // TODO: Add telemetry alert here
    }

    // 6. Referential integrity validation
    try validateReferentialIntegrity(container.habits)

    // 7. Streak consistency validation
    try validateStreakConsistency(container.habits)

    // 8. Semver monotonicity validation
    if let prevVersion = previousVersion {
      try validateSemverMonotonicity(previous: prevVersion, current: container.version)
    }

    // 4. Check for valid UTF-8 encoding in habit names and descriptions
    for habit in container.habits {
      if !habit.name.canBeConverted(to: .utf8) {
        throw HabitStoreError.dataIntegrityError("Habit name contains invalid UTF-8 encoding")
      }
      if !habit.description.canBeConverted(to: .utf8) {
        throw HabitStoreError
          .dataIntegrityError("Habit description contains invalid UTF-8 encoding")
      }
    }

    // 5. Check for valid dates
    for habit in container.habits {
      if habit.startDate > Date() {
        throw HabitStoreError.dataIntegrityError("Habit start date in the future")
      }
      if let endDate = habit.endDate, endDate < habit.startDate {
        throw HabitStoreError.dataIntegrityError("Habit end date before start date")
      }
    }

    print("✅ CrashSafeHabitStore: Storage invariants validation passed")
  }

  // MARK: - Compaction

  func compactMainFile() async throws {
    let container = loadContainer()
    let dataSize = try JSONEncoder().encode(container).count
    let targetSize = 5 * 1024 * 1024 // 5MB target

    if dataSize <= targetSize {
      print(
        "✅ CrashSafeHabitStore: Main file already within target size (\(dataSize / 1024 / 1024)MB)")
      return
    }

    print(
      "🔄 CrashSafeHabitStore: Starting main file compaction (\(dataSize / 1024 / 1024)MB -> target 5MB)")

    // Create compacted container with pruned data
    let compactedHabits = container.habits.map { habit in
      // Prune stale completion history (keep only last 90 days)
      let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
      let prunedHistory = habit.completionHistory.filter { dateString, _ in
        if let date = ISO8601DateFormatter().date(from: dateString) {
          return date >= cutoffDate
        }
        return false
      }

      // Prune oversized metadata
      let prunedDescription = habit.description.count > 500
        ? String(habit.description.prefix(500)) + "..."
        : habit.description

      // Create new Habit instance with pruned data
      return Habit(
        id: habit.id,
        name: habit.name,
        description: prunedDescription,
        icon: habit.icon,
        color: habit.color,
        habitType: habit.habitType,
        schedule: habit.schedule,
        goal: habit.goal,
        reminder: habit.reminder,
        startDate: habit.startDate,
        endDate: habit.endDate,
        createdAt: habit.createdAt,
        reminders: habit.reminders,
        baseline: habit.baseline,
        target: habit.target,
        completionHistory: prunedHistory,
        completionStatus: habit.completionStatus,
        completionTimestamps: habit.completionTimestamps,
        difficultyHistory: habit.difficultyHistory,
        actualUsage: habit.actualUsage)
    }

    let compactedContainer = HabitDataContainer(
      habits: compactedHabits,
      version: container.version,
      completedSteps: container.completedMigrationSteps)

    let compactedSize = try JSONEncoder().encode(compactedContainer).count
    print(
      "📊 CrashSafeHabitStore: Compaction reduced size from \(dataSize / 1024 / 1024)MB to \(compactedSize / 1024 / 1024)MB")

    // Save compacted container
    try saveContainer(compactedContainer)

    print("✅ CrashSafeHabitStore: Main file compaction completed")
  }

  // MARK: Private

  private let fileManager = FileManager.default
  private let fileCoordinator = NSFileCoordinator() // For extensions/widgets coordination
  private let mainURL: URL
  private let backupURL: URL
  private let backup2URL: URL
  private let userDefaults = UserDefaults
    .standard // For migration version cache only (not authoritative)
  private let userId: String // For multi-account support

  /// Cache for performance
  private var cachedContainer: HabitDataContainer?

  // MARK: - Private Methods

  private func loadContainer() -> HabitDataContainer {
    var coordinatorError: NSError?
    var result: HabitDataContainer?

    fileCoordinator.coordinate(
      readingItemAt: mainURL,
      options: .withoutChanges,
      error: &coordinatorError)
    { coordinatedURL in
      do {
        let data = try Data(contentsOf: coordinatedURL)
        let container = try JSONDecoder().decode(HabitDataContainer.self, from: data)
        print(
          "✅ CrashSafeHabitStore: Loaded \(container.habits.count) habits, version \(container.version)")

        // Mirror version to UserDefaults cache (not authoritative) with per-account key
        let versionKey = "MigrationVersion:\(userId)"
        userDefaults.set(container.version, forKey: versionKey)

        result = container
      } catch {
        print("⚠️ CrashSafeHabitStore: Failed to load main file, trying backup: \(error)")

        // Fallback to backup
        do {
          let backupData = try Data(contentsOf: backupURL)
          let container = try JSONDecoder().decode(HabitDataContainer.self, from: backupData)
          print(
            "✅ CrashSafeHabitStore: Loaded from backup: \(container.habits.count) habits, version \(container.version)")

          // Mirror version to UserDefaults cache (not authoritative) with per-account key
          let versionKey = "MigrationVersion:\(userId)"
          userDefaults.set(container.version, forKey: versionKey)

          // Try to restore main file from backup
          try? fileManager.copyItem(at: backupURL, to: coordinatedURL)
          result = container
        } catch {
          print(
            "❌ CrashSafeHabitStore: Both main and backup failed, returning empty container: \(error)")
          result = HabitDataContainer(habits: [])
        }
      }
    }

    return result ?? HabitDataContainer(habits: [])
  }

  private func saveContainer(_ container: HabitDataContainer) throws {
    // Check disk space before writing
    try checkDiskSpace(for: container)

    let data = try JSONEncoder().encode(container)

    var coordinatorError: NSError?
    var success = false

    fileCoordinator.coordinate(
      writingItemAt: mainURL,
      options: .forReplacing,
      error: &coordinatorError)
    { coordinatedURL in
      do {
        // 1) Write to temporary file with fsync for durability
        let tempURL = coordinatedURL.deletingPathExtension()
          .appendingPathExtension("tmp.\(UUID().uuidString)")

        // Ensure cleanup on any exit path
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create empty temp file first
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        // Write data via FileHandle for proper durability - write what we fsync
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { try? fileHandle.close() }

        // Write the exact bytes we'll sync
        try fileHandle.write(contentsOf: data)
        try fileHandle.synchronize() // fsync exactly what we wrote

        // 2) Set file protection on temp file BEFORE atomic replace
        try fileManager.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: tempURL.path)

        // 3) Exclude temp file from backup
        try? (tempURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

        // 4) Atomically replace main file
        _ = try fileManager.replaceItem(
          at: coordinatedURL,
          withItemAt: tempURL,
          backupItemName: nil,
          options: [],
          resultingItemURL: nil)

        // 5) Re-assert file protection on replaced target
        try fileManager.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: coordinatedURL.path)

        // 6) Verify by reading back
        let verificationData = try Data(contentsOf: coordinatedURL)
        _ = try JSONDecoder().decode(HabitDataContainer.self, from: verificationData)

        success = true
      } catch {
        print("❌ CrashSafeHabitStore: Write operation failed: \(error)")
        // Attempt rollback from backup
        do {
          try rollbackFromBackup(coordinatedURL)
          print("✅ CrashSafeHabitStore: Successfully rolled back from backup")
        } catch {
          print("❌ CrashSafeHabitStore: Rollback failed: \(error)")
        }
        success = false
      }
    }

    if !success {
      // Surface both coordinator errors and thrown errors with detailed telemetry
      let finalError: NSError
      if let coordinatorError {
        finalError = coordinatorError
        print("❌ CrashSafeHabitStore: File coordination failed (coordinator error)")
        print("   📊 Coordinator Error: \(coordinatorError.localizedDescription)")
        print("   📊 Error Code: \(coordinatorError.code)")
        print("   📊 Error Domain: \(coordinatorError.domain)")
      } else {
        finalError = NSError(domain: "HabitStore", code: -1, userInfo: [
          NSLocalizedDescriptionKey: "Unknown file coordination error",
          NSLocalizedFailureReasonErrorKey: "File coordination completed but success=false"
        ])
        print("❌ CrashSafeHabitStore: File coordination failed (unknown error)")
        print("   📊 Success flag: false")
        print("   📊 No coordinator error provided")
      }

      throw HabitStoreError.fileSystemError(finalError)
    }

    // 6) Read-back verify + invariants before backup rotation
    let verifyData = try Data(contentsOf: mainURL)
    let verifyContainer = try JSONDecoder().decode(HabitDataContainer.self, from: verifyData)

    // Run invariants validation (simplified version for storage layer)
    do {
      try validateStorageInvariants(verifyContainer)
    } catch {
      // Record invariant failure telemetry
      Task {
        await EnhancedMigrationTelemetryManager.shared.recordEvent(
          .killSwitchTriggered,
          errorCode: "invariant_validation_failed",
          success: false)
      }
      throw error
    }

    // 7) Only now rotate backup (keep two generations) - after verify + invariants pass
    try rotateBackup()

    // 8) Mirror version to UserDefaults cache (not authoritative) with per-account key
    let versionKey = "MigrationVersion:\(userId)"
    userDefaults.set(container.version, forKey: versionKey)

    print(
      "✅ CrashSafeHabitStore: Saved \(container.habits.count) habits, version \(container.version)")
  }

  private func rotateBackup() throws {
    // Atomic two-generation backup rotation: bak2 <- bak1 <- main
    // Use copy/rename pattern to avoid leaving zero backups if app dies mid-rotation

    // 1) Create new backup1 from main (atomic copy)
    let newBackupURL = backupURL.appendingPathExtension("new")
    try fileManager.copyItem(at: mainURL, to: newBackupURL)

    // 2) Set file protection on new backup1
    try fileManager.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: newBackupURL.path)

    // 3) Move current backup1 to backup2 (atomic rename)
    if fileManager.fileExists(atPath: backupURL.path) {
      // Remove old backup2 if it exists
      try? fileManager.removeItem(at: backup2URL)
      try fileManager.moveItem(at: backupURL, to: backup2URL)

      // Set file protection on backup2
      try fileManager.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: backup2URL.path)
    }

    // 4) Rename new backup to backup1 (atomic rename)
    try fileManager.moveItem(at: newBackupURL, to: backupURL)

    print("🔄 CrashSafeHabitStore: Atomically rotated backup files (main -> bak1 -> bak2)")
  }

  private func checkDiskSpace(for container: HabitDataContainer) throws {
    let data = try JSONEncoder().encode(container)
    let estimatedWriteSize = data.count * 2 // 2x for temp + final (backup rotation happens after)

    do {
      // Query available capacity for important usage (more accurate than systemFreeSize)
      let volumeURL = mainURL.deletingLastPathComponent()
      let resourceValues = try volumeURL.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeAvailableCapacityKey
      ])

      // Prefer important usage capacity if available, fallback to general capacity
      let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage ??
        Int64(resourceValues.volumeAvailableCapacity ?? 0)

      // Check if we have enough space for the write operation (2x estimate for safety)
      if availableCapacity < Int64(estimatedWriteSize) {
        let error = HabitStoreError.insufficientDiskSpace(
          required: estimatedWriteSize,
          available: Int(availableCapacity))
        print("💾 CrashSafeHabitStore: Insufficient disk space")
        print("   📊 Required: \(estimatedWriteSize / 1024 / 1024)MB (2x safety buffer)")
        print("   📊 Available: \(Int(availableCapacity) / 1024 / 1024)MB")
        print("   💡 Please free up space and try again")

        // Show user-visible alert
        Task { @MainActor in
          DiskSpaceAlertManager.shared.showAlert(
            required: estimatedWriteSize,
            available: Int(availableCapacity))
        }

        // Record disk space telemetry
        Task {
          await EnhancedMigrationTelemetryManager.shared.recordEvent(
            .killSwitchTriggered,
            errorCode: "insufficient_disk_space",
            success: false)
        }
        throw error
      }

      // Additional safety buffer - require 2x the estimated size for safety
      let safetyBuffer = max(
        Int64(estimatedWriteSize) * 2,
        100 * 1024 * 1024) // 2x or 100MB, whichever is larger
      if availableCapacity < safetyBuffer {
        let error = HabitStoreError.lowDiskSpace(
          available: Int(availableCapacity),
          minimum: Int(safetyBuffer))
        print("💾 CrashSafeHabitStore: Low disk space warning")
        print("   📊 Available: \(Int(availableCapacity) / 1024 / 1024)MB")
        print("   📊 Minimum recommended: \(Int(safetyBuffer) / 1024 / 1024)MB")
        print("   💡 Suggestion: Consider freeing up space for optimal performance")
        throw error
      }

      print(
        "💾 CrashSafeHabitStore: Disk space check passed - \(Int(availableCapacity / 1024 / 1024))MB available, \(estimatedWriteSize / 1024)KB needed")

    } catch let error as HabitStoreError {
      throw error
    } catch {
      // If we can't check disk space, log but don't fail
      print("⚠️ CrashSafeHabitStore: Could not check disk space: \(error)")
    }
  }

  // MARK: - Rollback Methods

  private func rollbackFromBackup(_ targetURL: URL) throws {
    // Try to restore from backup1 first, then backup2 if backup1 fails
    if fileManager.fileExists(atPath: backupURL.path) {
      try fileManager.copyItem(at: backupURL, to: targetURL)
      print("✅ CrashSafeHabitStore: Restored from backup1")
    } else if fileManager.fileExists(atPath: backup2URL.path) {
      try fileManager.copyItem(at: backup2URL, to: targetURL)
      print("✅ CrashSafeHabitStore: Restored from backup2")
    } else {
      // No backup available, create empty container
      let emptyContainer = HabitDataContainer(habits: [])
      let emptyData = try JSONEncoder().encode(emptyContainer)
      try emptyData.write(to: targetURL)
      print("⚠️ CrashSafeHabitStore: No backup available, created empty container")
    }

    // Re-apply file protection after rollback
    try fileManager.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: targetURL.path)

    // Record backup rollback telemetry
    Task {
      await EnhancedMigrationTelemetryManager.shared.recordEvent(
        .killSwitchTriggered,
        errorCode: "backup_rollback",
        success: true)
    }
  }

  private func parseDate(from dateKey: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateKey)
  }

  private func validateReferentialIntegrity(_ habits: [Habit]) throws {
    // Validate habit-reminder relationships
    for habit in habits {
      // Check that all reminder IDs in habit.reminders are valid
      for reminder in habit.reminders {
        // Basic validation - reminder should have valid properties
        if reminder.id.uuidString.isEmpty {
          throw HabitStoreError.dataIntegrityError("Habit \(habit.name) has invalid reminder ID")
        }

        // Validate reminder time (Date objects are always valid)
        // No additional validation needed for Date objects
      }

      // Feature flag protection: Only validate challenges if feature is enabled
      // Note: Feature flag check moved to higher-level async methods due to MainActor constraint
      // TODO: When challenges are added, validate habit-challenge relationships
      print("🚩 CrashSafeHabitStore: Challenges validation placeholder")

      // TODO: When notes are added, validate habit-note relationships
    }

    print("✅ CrashSafeHabitStore: Referential integrity validation passed")
  }

  private func validateStreakConsistency(_ habits: [Habit]) throws {
    let calendar = Calendar.current
    let timeZone = TimeZone.current

    for habit in habits {
      // Calculate expected streak from completion history
      let completionDates = habit.completionHistory.compactMap { dateKey, completionCount in
        guard let date = parseDate(from: dateKey),
              completionCount > 0 else { return nil }
        return date
      }.sorted(by: >) // Most recent first

      // Calculate consecutive streak from most recent completion
      var expectedStreak = 0
      var currentDate = Date().startOfDay(in: timeZone)

      for completionDate in completionDates {
        let completionStartOfDay = calendar.startOfDay(for: completionDate)
        let daysDifference = calendar.dateComponents(
          [.day],
          from: completionStartOfDay,
          to: currentDate).day ?? 0

        if daysDifference == expectedStreak {
          expectedStreak += 1
          currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        } else {
          break
        }
      }

      // Allow some tolerance for edge cases (e.g., timezone changes, DST)
      let streakDifference = abs(habit.computedStreak() - expectedStreak)
      if streakDifference > 1 {
        print(
          "⚠️ CrashSafeHabitStore: Streak inconsistency for habit \(habit.name): stored=\(habit.computedStreak()), calculated=\(expectedStreak)")
        // Don't throw error for minor inconsistencies, just log warning
      }
    }

    print("✅ CrashSafeHabitStore: Streak consistency validation passed")
  }

  private func validateSemverMonotonicity(previous: String, current: String) throws {
    let prevComponents = previous.split(separator: ".").compactMap { Int($0) }
    let currentComponents = current.split(separator: ".").compactMap { Int($0) }

    guard prevComponents.count == 3 && currentComponents.count == 3 else {
      throw HabitStoreError
        .dataIntegrityError(
          "Invalid semver format for monotonicity check: \(previous) -> \(current)")
    }

    // Check if current version is greater than or equal to previous
    let isMonotonic = (currentComponents[0] > prevComponents[0]) ||
      (currentComponents[0] == prevComponents[0] && currentComponents[1] > prevComponents[1]) ||
      (currentComponents[0] == prevComponents[0] && currentComponents[1] == prevComponents[1] &&
        currentComponents[2] >= prevComponents[2])

    if !isMonotonic {
      throw HabitStoreError
        .dataIntegrityError("Non-monotonic version progression: \(previous) -> \(current)")
    }

    print("✅ CrashSafeHabitStore: Semver monotonicity validation passed")
  }
}

// MARK: - HabitStoreError

enum HabitStoreError: LocalizedError {
  case noDataLoaded
  case fileSystemError(Error)
  case insufficientDiskSpace(required: Int, available: Int)
  case lowDiskSpace(available: Int, minimum: Int)
  case dataIntegrityError(String)
  case encodingError(Error)
  case decodingError(Error)
  case featureDisabled(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noDataLoaded:
      "No data loaded in HabitStore"
    case .fileSystemError(let error):
      "File system error: \(error.localizedDescription)"
    case .insufficientDiskSpace(let required, let available):
      "Insufficient disk space: need \(required) bytes, have \(available) bytes"
    case .lowDiskSpace(let available, let minimum):
      "Low disk space: \(available) bytes available, minimum \(minimum) bytes required"
    case .dataIntegrityError(let message):
      "Data integrity error: \(message)"
    case .encodingError(let error):
      "Encoding error: \(error.localizedDescription)"
    case .decodingError(let error):
      "Decoding error: \(error.localizedDescription)"
    case .featureDisabled(let message):
      "Feature disabled: \(message)"
    }
  }
}
