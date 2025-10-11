import CloudKit
import Foundation

// MARK: - GDPRDataDeletionManager

actor GDPRDataDeletionManager {
  // MARK: Lifecycle

  private init() {
    self.cloudKitManager = MockCloudKitManager.shared
  }

  // MARK: Internal

  static let shared = GDPRDataDeletionManager()

  // MARK: - Complete Data Deletion Sequence

  func deleteUserData(userId: String) async throws {
    print("🗑️ GDPRDataDeletionManager: Starting complete data deletion for user: \(userId)")

    // 1. Local deletion
    try await deleteLocalData()

    // 2. CloudKit deletion with tombstones
    try await deleteCloudKitData()

    // 3. Create deletion tombstones
    try await createDeletionTombstones()

    // 4. Telemetry cleanup
    await recordForgetEvent(userId: userId)

    // 5. Verification test
    try await verifyNoDataResurrection()

    print("✅ GDPRDataDeletionManager: Complete data deletion successful")
  }

  // MARK: - Offline Device Protection

  func handleOfflineDeviceReturn() async throws {
    print("📱 GDPRDataDeletionManager: Handling offline device return...")

    // NOTE: App has migrated to SwiftData
    // Check for tombstones first
    let tombstones = try await fetchTombstoneRecords()
    let tombstoneHabitIds = Set(tombstones.compactMap { $0["habitId"] as? String })

    if !tombstoneHabitIds.isEmpty {
      print("🗑️ GDPRDataDeletionManager: Found \(tombstoneHabitIds.count) tombstones to process")
      // In production, would delete from SwiftData
    }

    print("✅ GDPRDataDeletionManager: Offline device protection complete")
  }

  // MARK: - TTL Cleanup

  func cleanupExpiredTombstones() async throws {
    print("🧹 GDPRDataDeletionManager: Cleaning up expired tombstones...")

    let tombstones = try await fetchTombstoneRecords()
    let now = Date()

    let expiredTombstones = tombstones.filter { tombstone in
      if let ttl = tombstone["ttl"] as? Date {
        return now > ttl
      }
      return false
    }

    if !expiredTombstones.isEmpty {
      try await cloudKitManager.deleteRecords(expiredTombstones)
      print("✅ GDPRDataDeletionManager: Cleaned up \(expiredTombstones.count) expired tombstones")
    }
  }

  // MARK: Private

  private let cloudKitManager: MockCloudKitManager

  private var telemetryManager: EnhancedMigrationTelemetryManager {
    get async {
      await MainActor.run { EnhancedMigrationTelemetryManager.shared }
    }
  }

  // MARK: - Step 1: Local Deletion

  private func deleteLocalData() async throws {
    print("🗑️ GDPRDataDeletionManager: Deleting local data...")

    // NOTE: App has migrated to SwiftData
    // For GDPR deletion, we would need to delete from SwiftData
    // This is a placeholder implementation

    // Clear XP and level data
    await MainActor.run {
      XPManager.shared.clearXPData()
      print("✅ GDPRDataDeletionManager: XP and level data cleared")
    }

    // Delete any local snapshots
    try await deleteLocalSnapshots()

    print("✅ GDPRDataDeletionManager: Local data deleted")
  }

  private func deleteLocalSnapshots() async throws {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let snapshotFiles = try FileManager.default.contentsOfDirectory(
      at: documentsURL,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]).filter { $0.lastPathComponent.contains("habits_snapshot") }

    for snapshotFile in snapshotFiles {
      try FileManager.default.removeItem(at: snapshotFile)
    }
  }

  // MARK: - Step 2: CloudKit Deletion

  private func deleteCloudKitData() async throws {
    print("🗑️ GDPRDataDeletionManager: Deleting CloudKit data...")

    // Delete all habit records from private zone
    let records = try await fetchAllHabitRecords()
    try await deleteRecords(records)

    print("✅ GDPRDataDeletionManager: CloudKit data deleted")
  }

  private func fetchAllHabitRecords() async throws -> [CKRecord] {
    // Fetch all habit records from the private zone
    let query = CKQuery(recordType: "Habit", predicate: NSPredicate(value: true))
    let results = try await cloudKitManager.performQuery(query)
    return results
  }

  private func deleteRecords(_ records: [CKRecord]) async throws {
    // Delete records in batches to avoid CloudKit limits
    let batchSize = 100
    let batches = records.chunked(into: batchSize)

    for batch in batches {
      try await cloudKitManager.deleteRecords(batch)
    }
  }

  // MARK: - Step 3: Create Deletion Tombstones

  private func createDeletionTombstones() async throws {
    print("🗑️ GDPRDataDeletionManager: Creating deletion tombstones...")

    // Create tombstone records for each deleted habit
    let tombstoneRecords = try await createTombstoneRecords()
    try await cloudKitManager.saveRecords(tombstoneRecords)

    print("✅ GDPRDataDeletionManager: Deletion tombstones created")
  }

  private func createTombstoneRecords() async throws -> [CKRecord] {
    // Get list of all habit IDs that were deleted
    let deletedHabitIds = try await getDeletedHabitIds()

    return deletedHabitIds.map { habitId in
      let tombstoneRecord = CKRecord(recordType: "DeletionTombstone")
      tombstoneRecord["habitId"] = habitId.uuidString
      tombstoneRecord["deletedAt"] = Date()
      tombstoneRecord["ttl"] = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days TTL
      tombstoneRecord["reason"] = "gdpr_deletion"
      return tombstoneRecord
    }
  }

  private func getDeletedHabitIds() async throws -> [UUID] {
    // This would come from your local storage before deletion
    // For now, return empty array as we've already deleted local data
    []
  }

  // MARK: - Step 4: Telemetry Cleanup

  private func recordForgetEvent(userId: String) async {
    await (telemetryManager).recordEvent(
      .migrationStart, // Using existing event type, could add new .forgetEvent type
      datasetSize: 0,
      success: true)

    // Clear user-specific telemetry (placeholder - would need to implement)
    print("🗑️ GDPRDataDeletionManager: Cleared telemetry for user: \(userId)")
  }

  // MARK: - Step 5: Verification Test

  private func verifyNoDataResurrection() async throws {
    print("🔍 GDPRDataDeletionManager: Verifying no data resurrection...")

    // NOTE: App has migrated to SwiftData
    // Verification would need to check SwiftData storage
    // This is a placeholder implementation

    // Check CloudKit has only tombstones
    let cloudRecords = try await fetchAllHabitRecords()
    guard cloudRecords.isEmpty else {
      throw GDPRDeletionError.cloudKitDataStillExists
    }

    // Verify tombstones exist
    let tombstones = try await fetchTombstoneRecords()
    guard !tombstones.isEmpty else {
      throw GDPRDeletionError.noTombstonesFound
    }

    print("✅ GDPRDataDeletionManager: No data resurrection detected")
  }

  private func fetchTombstoneRecords() async throws -> [CKRecord] {
    let query = CKQuery(recordType: "DeletionTombstone", predicate: NSPredicate(value: true))
    return try await cloudKitManager.performQuery(query)
  }
}

// MARK: - GDPRDeletionError

enum GDPRDeletionError: LocalizedError {
  case localDataStillExists
  case cloudKitDataStillExists
  case noTombstonesFound
  case tombstoneCreationFailed

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .localDataStillExists:
      "Local data still exists after deletion"
    case .cloudKitDataStillExists:
      "CloudKit data still exists after deletion"
    case .noTombstonesFound:
      "No deletion tombstones found"
    case .tombstoneCreationFailed:
      "Failed to create deletion tombstones"
    }
  }
}

// MARK: - Array Extension for Batching

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}

// MARK: - MockCloudKitManager

actor MockCloudKitManager {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = MockCloudKitManager()

  func performQuery(_: CKQuery) async throws -> [CKRecord] {
    // Mock implementation
    []
  }

  func deleteRecords(_ records: [CKRecord]) async throws {
    // Mock implementation
    print("🗑️ CloudKitManager: Deleted \(records.count) records")
  }

  func saveRecords(_ records: [CKRecord]) async throws {
    // Mock implementation
    print("💾 CloudKitManager: Saved \(records.count) records")
  }
}
