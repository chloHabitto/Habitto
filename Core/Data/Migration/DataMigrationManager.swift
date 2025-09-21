import Foundation
import SwiftUI

// MARK: - Migration Version
/// Represents a migration version with semantic versioning
struct MigrationVersion: Comparable, Codable {
    let major: Int
    let minor: Int
    let patch: Int
    
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
    
    var stringValue: String {
        return "\(major).\(minor).\(patch)"
    }
    
    static func < (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
    static func == (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

// MARK: - Migration Result
/// Result of a migration operation
enum MigrationResult {
    case success
    case failure(Error)
    case skipped(reason: String)
}

// MARK: - Migration Step
/// Represents a single migration step
protocol MigrationStep {
    var version: MigrationVersion { get }
    var description: String { get }
    var isRequired: Bool { get }
    
    func execute() async throws -> MigrationResult
    func canRollback() -> Bool
    func rollback() async throws
}

// MARK: - Migration Manager
/// Manages data migrations between different storage systems and data formats
@MainActor
class DataMigrationManager: ObservableObject {
    static let shared = DataMigrationManager()
    
    // MARK: - Properties
    @Published var isMigrating = false
    @Published var currentVersion: MigrationVersion = MigrationVersion(1, 0, 0)
    @Published var migrationProgress: Double = 0.0
    @Published var currentMigrationStep: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let versionKey = "DataMigrationVersion"
    private let migrationLogKey = "MigrationLog"
    
    // MARK: - Migration Steps
    private var migrationSteps: [MigrationStep] = []
    
    private init() {
        loadCurrentVersion()
        setupMigrationSteps()
    }
    
    // MARK: - Public Methods
    
    /// Check if migration is needed
    func needsMigration() -> Bool {
        let latestVersion = migrationSteps.map { $0.version }.max() ?? currentVersion
        return currentVersion < latestVersion
    }
    
    /// Get available migration steps for current version
    func getAvailableMigrations() -> [MigrationStep] {
        return migrationSteps.filter { $0.version > currentVersion }
    }
    
    /// Execute all pending migrations with crash-safe, idempotent steps
    func executeMigrations() async throws {
        guard needsMigration() else {
            print("✅ DataMigrationManager: No migrations needed")
            return
        }
        
        // Prevent multiple simultaneous migrations
        guard !isMigrating else {
            print("⚠️ DataMigrationManager: Migration already in progress, skipping")
            return
        }
        
        isMigrating = true
        migrationProgress = 0.0
        
        let availableMigrations = getAvailableMigrations().sorted { $0.version < $1.version }
        let totalSteps = availableMigrations.count
        
        print("🔄 DataMigrationManager: Starting migration from \(currentVersion.stringValue) to latest")
        
        // Create pre-migration snapshot for rollback
        let snapshotURL = try await createPreMigrationSnapshot()
        
        do {
            for (index, step) in availableMigrations.enumerated() {
                currentMigrationStep = step.description
                migrationProgress = Double(index) / Double(totalSteps)
                
                print("🔄 DataMigrationManager: Executing \(step.description) (v\(step.version.stringValue))")
                
                // Check if step already completed (idempotent)
                if isStepCompleted(step) {
                    print("⏭️ DataMigrationManager: \(step.description) already completed, skipping")
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
                        
                        // Update version after successful migration
                        currentVersion = step.version
                        userDefaults.set(currentVersion.stringValue, forKey: versionKey)
                        print("✅ DataMigrationManager: Updated to version \(currentVersion.stringValue)")
                        
                    case .failure(let error):
                        print("❌ DataMigrationManager: \(step.description) failed: \(error.localizedDescription)")
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
                        print("⏭️ DataMigrationManager: \(step.description) skipped: \(reason)")
                        logMigration(step: step, result: .skipped(reason: reason), error: nil)
                        // Update version even for skipped steps
                        currentVersion = step.version
                        userDefaults.set(currentVersion.stringValue, forKey: versionKey)
                    }
                    
                } catch {
                    print("❌ DataMigrationManager: Unexpected error in \(step.description): \(error.localizedDescription)")
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
            
        } catch {
            // Rollback on failure
            print("❌ DataMigrationManager: Migration failed, attempting rollback...")
            try await rollbackFromSnapshot(snapshotURL)
            throw error
        }
    }
    
    /// Rollback to a specific version
    func rollback(to version: MigrationVersion) async throws {
        guard version < currentVersion else {
            throw DataMigrationError.invalidRollbackVersion
        }
        
        print("🔄 DataMigrationManager: Rolling back to version \(version.stringValue)")
        
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
                print("❌ DataMigrationManager: Failed to rollback \(step.description): \(error.localizedDescription)")
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
              let history = try? JSONDecoder().decode([MigrationLogEntry].self, from: data) else {
            return []
        }
        return history
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentVersion() {
        let versionString = userDefaults.string(forKey: versionKey) ?? "1.0.0"
        currentVersion = MigrationVersion(versionString)
        print("🔍 DataMigrationManager: Loaded current version: \(currentVersion.stringValue)")
    }
    
    private func createPreMigrationSnapshot() async throws -> URL {
        let habitStore = CrashSafeHabitStore.shared
        return try habitStore.createSnapshot()
    }
    
    private func rollbackFromSnapshot(_ snapshotURL: URL) async throws {
        let habitStore = CrashSafeHabitStore.shared
        try habitStore.restoreFromSnapshot(snapshotURL)
        
        // Clean up snapshot file
        try? FileManager.default.removeItem(at: snapshotURL)
    }
    
    private func isStepCompleted(_ step: MigrationStep) -> Bool {
        let habitStore = CrashSafeHabitStore.shared
        let completedSteps = habitStore.getCompletedMigrationSteps()
        return completedSteps.contains(step.description)
    }
    
    private func markStepCompleted(_ step: MigrationStep) async throws {
        let habitStore = CrashSafeHabitStore.shared
        try habitStore.markMigrationStepCompleted(step.description)
    }
    
    private func validatePostMigration() async throws {
        let habitStore = CrashSafeHabitStore.shared
        let habits = habitStore.loadHabits()
        
        // Basic validation invariants
        let habitIds = Set(habits.map { $0.id })
        if habitIds.count != habits.count {
            throw DataMigrationError.postMigrationValidationFailed("Duplicate habit IDs detected")
        }
        
        // Validate habit names are not empty
        let emptyNames = habits.filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !emptyNames.isEmpty {
            throw DataMigrationError.postMigrationValidationFailed("Habits with empty names detected")
        }
        
        print("✅ DataMigrationManager: Post-migration validation passed")
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
            error: error?.localizedDescription
        )
        
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

// MARK: - Migration Log Entry
struct MigrationLogEntry: Codable {
    let version: MigrationVersion
    let description: String
    let timestamp: Date
    let result: MigrationResult
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case version, description, timestamp, result, error
    }
    
    init(version: MigrationVersion, description: String, timestamp: Date, result: MigrationResult, error: String?) {
        self.version = version
        self.description = description
        self.timestamp = timestamp
        self.result = result
        self.error = error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(MigrationVersion.self, forKey: .version)
        description = try container.decode(String.self, forKey: .description)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        
        // Handle MigrationResult enum
        let resultString = try container.decode(String.self, forKey: .result)
        switch resultString {
        case "success":
            result = .success
        case "skipped":
            let reason = try container.decodeIfPresent(String.self, forKey: .error) ?? "Unknown reason"
            result = .skipped(reason: reason)
        case "failure":
            result = .failure(DataMigrationError.unknown)
        default:
            result = .failure(DataMigrationError.unknown)
        }
    }
    
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

// MARK: - Migration Errors
enum DataMigrationError: LocalizedError {
    case requiredStepFailed(step: String, error: Error)
    case invalidRollbackVersion
    case rollbackFailed(step: String, error: Error)
    case postMigrationValidationFailed(String)
    case migrationDisabledByKillSwitch
    case highFailureRateDetected
    case unknown
}
