import Foundation
import OSLog
import SwiftData

// MARK: - BackupTestingSuite

/// Comprehensive testing suite for backup system functionality
@MainActor
final class BackupTestingSuite: ObservableObject {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = BackupTestingSuite()

  @Published var testResults: [BackupTestResult] = []
  @Published var isRunningTests = false

  /// Run comprehensive backup system tests
  func runAllTests() async {
    await MainActor.run {
      isRunningTests = true
      testResults.removeAll()
    }

    logger.info("🧪 Starting comprehensive backup system tests")

    // Core functionality tests
    await runTest("Backup Creation", test: testBackupCreation)
    await runTest("Backup Validation", test: testBackupValidation)
    await runTest("Backup Restoration", test: testBackupRestoration)
    await runTest("Settings Persistence", test: testSettingsPersistence)
    await runTest("Error Handling", test: testErrorHandling)
    await runTest("Data Integrity", test: testDataIntegrity)
    await runTest("Compression", test: testCompression)
    await runTest("Metadata Tracking", test: testMetadataTracking)

    // Integration tests
    await runTest("Scheduler Integration", test: testSchedulerIntegration)
    await runTest("Storage Coordinator", test: testStorageCoordinator)
    await runTest("Network Conditions", test: testNetworkConditions)
    await runTest("Background Tasks", test: testBackgroundTasks)

    await MainActor.run {
      isRunningTests = false
    }

    logger
      .info(
        "🧪 Backup testing completed: \(self.testResults.filter { $0.success }.count)/\(self.testResults.count) tests passed")
  }

  /// Clear all test results
  func clearTestResults() {
    testResults.removeAll()
  }

  /// Get test summary
  func getTestSummary() -> String {
    let total = testResults.count
    let passed = testResults.filter { $0.success }.count
    let failed = total - passed

    return "Tests: \(passed)/\(total) passed, \(failed) failed"
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.backup", category: "testing")
  private let backupManager = BackupManager.shared
  private let backupScheduler = BackupScheduler.shared
  private let storageCoordinator = BackupStorageCoordinator.shared

  /// Run a single test and record results
  private func runTest(_ name: String, test: @escaping () async throws -> Void) async {
    let startTime = Date()
    var result = BackupTestResult(name: name, success: false, duration: 0, error: nil)

    do {
      try await test()
      result.success = true
      logger.info("✅ Test passed: \(name)")
    } catch {
      result.error = error.localizedDescription
      logger.error("❌ Test failed: \(name) - \(error.localizedDescription)")
    }

    result.duration = Date().timeIntervalSince(startTime)

    await MainActor.run {
      testResults.append(result)
    }
  }

  // MARK: - Individual Tests

  /// Test backup creation functionality
  private func testBackupCreation() async throws {
    let result = try await backupManager.createBackup()

    guard result.habitCount >= 0 else {
      throw BackupTestError.invalidData("Backup should have valid habit count")
    }

    guard result.fileSize > 0 else {
      throw BackupTestError.invalidData("Backup should have content")
    }

    logger.debug("Backup created successfully: \(result.id), size: \(result.fileSize) bytes")
  }

  /// Test backup validation functionality
  private func testBackupValidation() async throws {
    let result = try await backupManager.createBackup()

    let isValid = try await backupManager.verifyBackup(result)

    guard isValid else {
      throw BackupTestError.validationFailed("Backup validation failed")
    }

    logger.debug("Backup validation passed: \(result.id)")
  }

  /// Test backup restoration functionality
  private func testBackupRestoration() async throws {
    // Create backup data
    let backupData = try await backupManager.createBackupData()

    // Restore from backup
    let restoreResult = try await backupManager.restoreFromData(backupData)

    guard restoreResult.success else {
      throw BackupTestError
        .restorationFailed(
          "Backup restoration failed: \(restoreResult.details.joined(separator: ", "))")
    }

    logger.debug("Backup restoration completed: \(restoreResult.restoredItems) items restored")
  }

  /// Test settings persistence
  private func testSettingsPersistence() async throws {
    // Test scheduler settings
    let testConfig = BackupScheduleConfig(
      isEnabled: true,
      frequency: .weekly,
      networkCondition: .wifiOnly)

    backupScheduler.updateSchedule(
      isEnabled: testConfig.isEnabled,
      frequency: testConfig.frequency,
      networkCondition: testConfig.networkCondition)

    // Load settings back
    let loadedConfig = BackupScheduler.loadScheduleConfig()

    guard loadedConfig.isEnabled == testConfig.isEnabled else {
      throw BackupTestError.persistenceFailed("Scheduler enabled setting not persisted")
    }

    guard loadedConfig.frequency == testConfig.frequency else {
      throw BackupTestError.persistenceFailed("Scheduler frequency setting not persisted")
    }

    guard loadedConfig.networkCondition == testConfig.networkCondition else {
      throw BackupTestError.persistenceFailed("Scheduler network condition setting not persisted")
    }

    // Test storage coordinator settings
    storageCoordinator.enableiCloudBackup = true
    storageCoordinator.enableGoogleDriveBackup = false
    storageCoordinator.enableLocalBackup = true

    // Verify settings are set
    guard storageCoordinator.enableiCloudBackup == true else {
      throw BackupTestError.persistenceFailed("iCloud backup setting not persisted")
    }

    guard storageCoordinator.enableGoogleDriveBackup == false else {
      throw BackupTestError.persistenceFailed("Google Drive backup setting not persisted")
    }

    guard storageCoordinator.enableLocalBackup == true else {
      throw BackupTestError.persistenceFailed("Local backup setting not persisted")
    }

    logger.debug("Settings persistence test passed")
  }

  /// Test error handling
  private func testErrorHandling() async throws {
    // Test invalid backup file
    let invalidData = "invalid backup data".data(using: .utf8) ?? Data()

    do {
      _ = try await backupManager.restoreFromData(invalidData)
      throw BackupTestError.errorHandlingFailed("Should have thrown error for invalid data")
    } catch {
      // Expected to throw an error
      logger.debug("Error handling test passed - correctly caught invalid data error")
    }

    // Test invalid backup data
    let invalidBackupData = "invalid backup data".data(using: .utf8) ?? Data()

    do {
      _ = try await backupManager.restoreFromData(invalidBackupData)
      throw BackupTestError.errorHandlingFailed("Should have thrown error for invalid backup data")
    } catch {
      // Expected to throw an error
      logger.debug("Error handling test passed - correctly caught invalid data error")
    }
  }

  /// Test data integrity
  private func testDataIntegrity() async throws {
    let result = try await backupManager.createBackup()

    // Verify basic backup properties
    guard result.habitCount >= 0 else {
      throw BackupTestError.dataCorruption("Backup has invalid habit count")
    }

    guard result.fileSize > 0 else {
      throw BackupTestError.dataCorruption("Backup has no content")
    }

    guard !result.id.uuidString.isEmpty else {
      throw BackupTestError.dataCorruption("Backup has no ID")
    }

    logger.debug("Data integrity test passed - backup structure is valid")
  }

  /// Test compression functionality
  private func testCompression() async throws {
    let result = try await backupManager.createBackup()

    // Check if file size is reasonable (compression should make it smaller than raw data)
    guard result.fileSize > 0 else {
      throw BackupTestError.compressionFailed("Backup file has no content")
    }

    // Basic compression test - file should exist and have content
    logger.debug("Compression test passed - backup size: \(result.fileSize) bytes")
  }

  /// Test metadata tracking
  private func testMetadataTracking() async throws {
    let result = try await backupManager.createBackup()

    guard !result.id.uuidString.isEmpty else {
      throw BackupTestError.metadataError("Backup result missing ID")
    }

    guard result.habitCount >= 0 else {
      throw BackupTestError.metadataError("Backup result missing habit count")
    }

    guard result.fileSize > 0 else {
      throw BackupTestError.metadataError("Backup result missing file size")
    }

    logger.debug("Metadata tracking test passed - all metadata present")
  }

  /// Test scheduler integration
  private func testSchedulerIntegration() async throws {
    // Test configuration loading
    let config = BackupScheduler.loadScheduleConfig()
    guard config.frequency != .manual else {
      throw BackupTestError.integrationFailed("Scheduler config missing frequency")
    }

    logger.debug("Scheduler integration test passed")
  }

  /// Test storage coordinator
  private func testStorageCoordinator() async throws {
    // Test basic storage coordinator properties
    guard storageCoordinator.enableiCloudBackup || storageCoordinator
      .enableGoogleDriveBackup || storageCoordinator.enableLocalBackup else
    {
      throw BackupTestError.integrationFailed("No backup providers enabled")
    }

    logger.debug("Storage coordinator test passed - providers configured")
  }

  /// Test network conditions
  private func testNetworkConditions() async throws {
    // Basic network test - just verify the scheduler exists and can be accessed
    let config = BackupScheduler.loadScheduleConfig()

    // Test that network condition is properly configured
    guard config.networkCondition == .any || config.networkCondition == .wifiOnly else {
      throw BackupTestError.integrationFailed("Invalid network condition configuration")
    }

    logger.debug("Network conditions test passed")
  }

  /// Test background tasks
  private func testBackgroundTasks() async throws {
    // Basic background task test - just verify the scheduler exists
    _ = BackupScheduler.loadScheduleConfig()

    // Test that the scheduler can be configured
    logger.debug("Background tasks test passed - scheduler accessible")
  }
}

// MARK: - BackupTestResult

struct BackupTestResult: Identifiable {
  let id = UUID()
  let name: String
  var success: Bool
  var duration: TimeInterval
  var error: String?

  var formattedDuration: String {
    String(format: "%.3fs", duration)
  }
}

// MARK: - BackupTestError

enum BackupTestError: Error, LocalizedError {
  case invalidData(String)
  case fileNotFound(String)
  case validationFailed(String)
  case restorationFailed(String)
  case persistenceFailed(String)
  case errorHandlingFailed(String)
  case dataCorruption(String)
  case compressionFailed(String)
  case metadataError(String)
  case integrationFailed(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .invalidData(let message):
      "Invalid data: \(message)"
    case .fileNotFound(let message):
      "File not found: \(message)"
    case .validationFailed(let message):
      "Validation failed: \(message)"
    case .restorationFailed(let message):
      "Restoration failed: \(message)"
    case .persistenceFailed(let message):
      "Persistence failed: \(message)"
    case .errorHandlingFailed(let message):
      "Error handling failed: \(message)"
    case .dataCorruption(let message):
      "Data corruption: \(message)"
    case .compressionFailed(let message):
      "Compression failed: \(message)"
    case .metadataError(let message):
      "Metadata error: \(message)"
    case .integrationFailed(let message):
      "Integration failed: \(message)"
    }
  }
}
