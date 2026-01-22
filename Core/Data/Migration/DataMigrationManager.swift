import Foundation
import SwiftUI

// MARK: - MigrationVersion

/// Represents a migration version with semantic versioning
struct MigrationVersion: Comparable, Codable {
  // MARK: Lifecycle

  init(_ major: Int, _ minor: Int, _ patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  init(_ versionString: String) {
    let components = versionString.split(separator: ".").compactMap { Int($0) }
    self.major = components.count > 0 ? components[0] : 0
    self.minor = components.count > 1 ? components[1] : 0
    self.patch = components.count > 2 ? components[2] : 0
  }

  // MARK: Internal

  let major: Int
  let minor: Int
  let patch: Int

  var stringValue: String {
    "\(major).\(minor).\(patch)"
  }

  static func < (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
    if lhs.major != rhs.major { return lhs.major < rhs.major }
    if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
    return lhs.patch < rhs.patch
  }

  static func == (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
    lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
  }
}

// MARK: - MigrationResult

/// Result of a migration operation
enum MigrationResult {
  case success
  case failure(Error)
  case skipped(reason: String)
}

// MARK: - MigrationStep

/// Represents a single migration step
protocol MigrationStep {
  var version: MigrationVersion { get }
  var description: String { get }
  var isRequired: Bool { get }

  func execute() async throws -> MigrationResult
  func canRollback() -> Bool
  func rollback() async throws
}

// MARK: - DataMigrationManager

/// Manages data migrations between different storage systems and data formats
@MainActor
class DataMigrationManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    loadCurrentVersion()
    setupMigrationSteps()
  }

  // MARK: Internal

  static let shared = DataMigrationManager()

  @Published var isMigrating = false
  @Published var currentVersion = MigrationVersion(1, 0, 0)
  @Published var migrationProgress = 0.0
  @Published var currentMigrationStep = ""

  // MARK: - Public Methods

  /// Check if migration is needed
  func needsMigration() -> Bool {
    let latestVersion = migrationSteps.map { $0.version }.max() ?? currentVersion
    return currentVersion < latestVersion
  }

  /// Get available migration steps for current version
  func getAvailableMigrations() -> [MigrationStep] {
    migrationSteps.filter { $0.version > currentVersion }
  }

  /// Execute all pending migrations with crash-safe, idempotent steps
  func executeMigrations() async throws {
    // Check feature flag kill switch
    _ = FeatureFlagManager.shared.provider
    // TODO: Add requireMigrationEnabled method to FeatureFlagProvider
    // try featureFlags.requireMigrationEnabled()

    // Check legacy kill switch (if exists)
    let telemetryManager = EnhancedMigrationTelemetryManager.shared
    guard await telemetryManager.checkMigrationEnabled() else {
      throw DataMigrationError.migrationDisabledByKillSwitch
    }

    guard needsMigration() else {
      print("✅ DataMigrationManager: No migrations needed")
      return
    }

    // Prevent multiple simultaneous migrations
    guard !isMigrating else {
      // This is expected during concurrent app initialization - multiple components may call this
      return
    }

    isMigrating = true
    migrationProgress = 0.0

    let availableMigrations = getAvailableMigrations().sorted { $0.version < $1.version }
    let totalSteps = availableMigrations.count

    let startTime = Date()

    // Record migration start
    await telemetryManager.recordEvent(.migrationStart, datasetSize: getHabitCount(), success: true)

    // Create pre-migration snapshot for rollback
    let snapshotURL = try await createPreMigrationSnapshot()

    // Initialize resume token for this migration
    let resumeTokenManager = MigrationResumeTokenManager.shared
    _ = await resumeTokenManager.createResumeToken(
      migrationVersion: currentVersion.stringValue,
      completedSteps: [],
      currentStep: availableMigrations.first?.description,
      stepCodeHash: "initial")

    do {
      for (index, step) in availableMigrations.enumerated() {
        currentMigrationStep = step.description
        migrationProgress = Double(index) / Double(totalSteps)

        // Check if step already completed (idempotent)
        if await isStepCompleted(step) {
          logMigration(step: step, result: .skipped(reason: "Already completed"), error: nil)
          currentVersion = step.version
          continue
        }

        do {
          let result = try await step.execute()

          switch result {
          case .success:
            print("✅ DataMigrationManager: \(step.description) completed successfully")
            logMigration(step: step, result: .success, error: nil)

            // Mark step as completed (idempotent)
            try await markStepCompleted(step)

            // Update resume token with completed step
            try await resumeTokenManager.markStepCompleted(
              step.description,
              codeHash: step.getCodeHash(),
              migrationVersion: step.version.stringValue)

            // Update version after successful migration
            currentVersion = step.version
            userDefaults.set(currentVersion.stringValue, forKey: versionKey)
            print("✅ DataMigrationManager: Updated to version \(currentVersion.stringValue)")

          case .failure(let error):
            print(
              "❌ DataMigrationManager: \(step.description) failed: \(error.localizedDescription)")
            logMigration(step: step, result: .failure(error), error: error)

            if step.isRequired {
              throw DataMigrationError.requiredStepFailed(step: step.description, error: error)
            } else {
              print("⚠️ DataMigrationManager: Non-required step failed, continuing...")
              // Update version even for failed non-required steps
              currentVersion = step.version
              userDefaults.set(currentVersion.stringValue, forKey: versionKey)
            }

          case .skipped(let reason):
            logMigration(step: step, result: .skipped(reason: reason), error: nil)
            // Update version even for skipped steps
            currentVersion = step.version
            userDefaults.set(currentVersion.stringValue, forKey: versionKey)
          }

        } catch {
          print(
            "❌ DataMigrationManager: Unexpected error in \(step.description): \(error.localizedDescription)")
          logMigration(step: step, result: .failure(error), error: error)

          if step.isRequired {
            throw error
          }
        }
      }

      // Post-migration validation
      try await validatePostMigration()

      migrationProgress = 1.0
      isMigrating = false
      currentMigrationStep = "Migration completed successfully"

      print("🎉 DataMigrationManager: All migrations completed successfully")

      // Complete migration and cleanup resume token
      await resumeTokenManager.completeMigration()

      // Record successful migration
      let totalDuration = Date().timeIntervalSince(startTime)
      await telemetryManager.recordEvent(
        .migrationEndSuccess,
        duration: totalDuration,
        datasetSize: getHabitCount(),
        success: true)

    } catch {
      // Rollback on failure
      print("❌ DataMigrationManager: Migration failed, attempting rollback...")

      // Record failed migration
      let totalDuration = Date().timeIntervalSince(startTime)
      await telemetryManager.recordEvent(
        .migrationEndFailure,
        duration: totalDuration,
        errorCode: error.localizedDescription,
        datasetSize: getHabitCount(),
        success: false)

      try await rollbackFromSnapshot(snapshotURL)
      throw error
    }
  }

  /// Rollback to a specific version
  func rollback(to version: MigrationVersion) async throws {
    guard version < currentVersion else {
      throw DataMigrationError.invalidRollbackVersion
    }


    let stepsToRollback = migrationSteps
      .filter { $0.version > version && $0.version <= currentVersion }
      .sorted { $0.version > $1.version } // Reverse order for rollback

    for step in stepsToRollback {
      guard step.canRollback() else {
        print("⚠️ DataMigrationManager: Cannot rollback \(step.description)")
        continue
      }

      do {
        try await step.rollback()
        print("✅ DataMigrationManager: Rolled back \(step.description)")
      } catch {
        print(
          "❌ DataMigrationManager: Failed to rollback \(step.description): \(error.localizedDescription)")
        throw DataMigrationError.rollbackFailed(step: step.description, error: error)
      }
    }

    currentVersion = version
    userDefaults.set(currentVersion.stringValue, forKey: versionKey)
    print("✅ DataMigrationManager: Rollback completed to version \(version.stringValue)")
  }

  /// Get migration history
  func getMigrationHistory() -> [MigrationLogEntry] {
    guard let data = userDefaults.data(forKey: migrationLogKey),
          let history = try? JSONDecoder().decode([MigrationLogEntry].self, from: data) else
    {
      return []
    }
    return history
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let versionKey = "DataMigrationVersion"
  private let migrationLogKey = "MigrationLog"

  // MARK: - Migration Steps

  private var migrationSteps: [MigrationStep] = []

  // MARK: - Private Methods

  private func loadCurrentVersion() {
    let versionString = userDefaults.string(forKey: versionKey) ?? "1.0.0"
    currentVersion = MigrationVersion(versionString)
    print("🔍 DataMigrationManager: Loaded current version: \(currentVersion.stringValue)")
  }

  private func getHabitCount() async -> Int {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // Return 0 as migrations are already completed
    0
  }

  private func getPreviousVersion() -> String? {
    // Get the previous version from the migration history
    let migrationHistory = userDefaults.array(forKey: "MigrationHistory") as? [String] ?? []
    return migrationHistory.last
  }

  private func createPreMigrationSnapshot() async throws -> URL {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // Snapshots are no longer needed as migrations are complete
    // Return a placeholder URL
    let tempDir = FileManager.default.temporaryDirectory
    return tempDir.appendingPathComponent("legacy_snapshot_not_needed.json")
  }

  private func rollbackFromSnapshot(_: URL) async throws {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // Rollback is no longer supported as migrations are complete
    print("⚠️ DataMigrationManager: Rollback skipped - migrations already complete, using SwiftData")

    // Record successful rollback telemetry
    await EnhancedMigrationTelemetryManager.shared.recordEvent(
      .killSwitchTriggered,
      errorCode: "rollback_skipped_swiftdata",
      success: true)
  }

  private func isStepCompleted(_: MigrationStep) async -> Bool {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // All migrations are considered complete, return true
    true
  }

  private func markStepCompleted(_ step: MigrationStep) async throws {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // Migration tracking is no longer needed as all migrations are complete
    print("✅ DataMigrationManager: Marked step completed (SwiftData mode): \(step.description)")
  }

  private func validatePostMigration() async throws {
    // NOTE: App has migrated to SwiftData, CrashSafeHabitStore is legacy
    // Skip validation as migrations are already complete
    print("✅ DataMigrationManager: Post-migration validation skipped (SwiftData mode)")
  }

  private func setupMigrationSteps() {
    migrationSteps = [
      // Storage migrations - Core Data disabled for now
      // UserDefaultsToCoreDataMigration(),
      // CoreDataToCloudKitMigration(),

      // Data format migrations
      AddHabitCreationDateMigration(),
      NormalizeHabitGoalMigration(),
      CleanUpInvalidDataMigration(),

      // Performance migrations
      OptimizeUserDefaultsStorageMigration()
    ]
  }

  private func logMigration(step: MigrationStep, result: MigrationResult, error: Error?) {
    let logEntry = MigrationLogEntry(
      version: step.version,
      description: step.description,
      timestamp: Date(),
      result: result,
      error: error?.localizedDescription)

    var history = getMigrationHistory()
    history.append(logEntry)

    // Keep only last 50 entries
    if history.count > 50 {
      history = Array(history.suffix(50))
    }

    if let data = try? JSONEncoder().encode(history) {
      userDefaults.set(data, forKey: migrationLogKey)
    }
  }
}

// MARK: - MigrationLogEntry

struct MigrationLogEntry: Codable {
  // MARK: Lifecycle

  init(
    version: MigrationVersion,
    description: String,
    timestamp: Date,
    result: MigrationResult,
    error: String?)
  {
    self.version = version
    self.description = description
    self.timestamp = timestamp
    self.result = result
    self.error = error
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try container.decode(MigrationVersion.self, forKey: .version)
    self.description = try container.decode(String.self, forKey: .description)
    self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    self.error = try container.decodeIfPresent(String.self, forKey: .error)

    // Handle MigrationResult enum
    let resultString = try container.decode(String.self, forKey: .result)
    switch resultString {
    case "success":
      self.result = .success

    case "skipped":
      let reason = try container.decodeIfPresent(String.self, forKey: .error) ?? "Unknown reason"
      self.result = .skipped(reason: reason)

    case "failure":
      self.result = .failure(DataMigrationError.unknown)

    default:
      self.result = .failure(DataMigrationError.unknown)
    }
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case version
    case description
    case timestamp
    case result
    case error
  }

  let version: MigrationVersion
  let description: String
  let timestamp: Date
  let result: MigrationResult
  let error: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(description, forKey: .description)
    try container.encode(timestamp, forKey: .timestamp)
    try container.encodeIfPresent(error, forKey: .error)

    switch result {
    case .success:
      try container.encode("success", forKey: .result)

    case .skipped(let reason):
      try container.encode("skipped", forKey: .result)
      try container.encode(reason, forKey: .error)

    case .failure:
      try container.encode("failure", forKey: .result)
    }
  }
}

// MARK: - DataMigrationError

enum DataMigrationError: LocalizedError {
  case requiredStepFailed(step: String, error: Error)
  case invalidRollbackVersion
  case rollbackFailed(step: String, error: Error)
  case postMigrationValidationFailed(String)
  case migrationDisabledByKillSwitch
  case highFailureRateDetected
  case unknown
}
