import Foundation

// MARK: - Schema Version Management
/// Centralized schema versioning for data migrations and compatibility

struct SchemaVersion {
    
    // MARK: - Current Version
    
    /// Current schema version - increment this when making breaking changes
    static let current: Int = 1
    
    /// Schema version history and migration matrix
    static let versions: [Int: SchemaInfo] = [
        1: SchemaInfo(
            version: 1,
            description: "Initial SwiftData schema with HabitData, CompletionRecord, etc.",
            breakingChanges: [],
            migrationSteps: []
        )
        // Future versions would be added here:
        // 2: SchemaInfo(version: 2, description: "Added typed Schedule enum", ...)
        // 3: SchemaInfo(version: 3, description: "Added user preferences", ...)
    ]
    
    // MARK: - Migration Matrix
    
    /// Define migration paths between versions
    static let migrationMatrix: [Int: [Int]] = [
        1: [] // Version 1 has no migrations (it's the initial version)
        // Future migrations:
        // 2: [1] // Version 2 can migrate from version 1
        // 3: [1, 2] // Version 3 can migrate from versions 1 or 2
    ]
    
    // MARK: - Validation
    
    /// Check if a version is valid
    static func isValid(_ version: Int) -> Bool {
        return versions.keys.contains(version)
    }
    
    /// Check if migration is possible from one version to another
    static func canMigrate(from fromVersion: Int, to toVersion: Int) -> Bool {
        guard let allowedFromVersions = migrationMatrix[toVersion] else {
            return false
        }
        return allowedFromVersions.contains(fromVersion)
    }
    
    /// Get the latest version that can migrate to the target version
    static func getLatestMigratableVersion(to targetVersion: Int) -> Int? {
        guard let allowedFromVersions = migrationMatrix[targetVersion] else {
            return nil
        }
        return allowedFromVersions.max()
    }
    
    // MARK: - Migration Information
    
    /// Get migration information for a version
    static func getMigrationInfo(from fromVersion: Int, to toVersion: Int) -> MigrationInfo? {
        guard canMigrate(from: fromVersion, to: toVersion) else {
            return nil
        }
        
        guard let fromInfo = versions[fromVersion],
              let toInfo = versions[toVersion] else {
            return nil
        }
        
        return MigrationInfo(
            from: fromInfo,
            to: toInfo,
            steps: toInfo.migrationSteps,
            breakingChanges: toInfo.breakingChanges
        )
    }
}

// MARK: - Schema Information Structures

struct SchemaInfo {
    let version: Int
    let description: String
    let breakingChanges: [String]
    let migrationSteps: [MigrationStep]
    let releaseDate: Date?
    let notes: String?
    
    init(
        version: Int,
        description: String,
        breakingChanges: [String] = [],
        migrationSteps: [MigrationStep] = [],
        releaseDate: Date? = nil,
        notes: String? = nil
    ) {
        self.version = version
        self.description = description
        self.breakingChanges = breakingChanges
        self.migrationSteps = migrationSteps
        self.releaseDate = releaseDate
        self.notes = notes
    }
}

struct MigrationStep {
    let step: Int
    let description: String
    let operation: MigrationOperation
    let isRequired: Bool
    let estimatedTime: TimeInterval?
    
    enum MigrationOperation {
        case dataTransform(transform: (Any) -> Any)
        case dataValidation(validator: (Any) -> Bool)
        case schemaUpdate(update: () -> Void)
        case dataCleanup(cleanup: () -> Void)
        case custom(operation: () -> Void)
    }
}

struct MigrationInfo {
    let from: SchemaInfo
    let to: SchemaInfo
    let steps: [MigrationStep]
    let breakingChanges: [String]
    
    var isBreakingChange: Bool {
        return !breakingChanges.isEmpty
    }
    
    var estimatedMigrationTime: TimeInterval? {
        let times = steps.compactMap { $0.estimatedTime }
        return times.isEmpty ? nil : times.reduce(0, +)
    }
}

// MARK: - Migration Execution

class SchemaMigrationExecutor {
    private let logger = Logger(subsystem: "com.habitto.app", category: "SchemaMigration")
    
    /// Execute migration from one version to another
    func executeMigration(from fromVersion: Int, to toVersion: Int) async throws {
        guard let migrationInfo = SchemaVersion.getMigrationInfo(from: fromVersion, to: toVersion) else {
            throw MigrationError.unsupportedMigration(from: fromVersion, to: toVersion)
        }
        
        logger.info("🔄 Starting migration from v\(fromVersion) to v\(toVersion)")
        
        if migrationInfo.isBreakingChange {
            logger.warning("⚠️ This migration includes breaking changes: \(migrationInfo.breakingChanges)")
        }
        
        // Execute migration steps
        for (index, step) in migrationInfo.steps.enumerated() {
            logger.info("📋 Step \(step.step): \(step.description)")
            
            do {
                try await executeMigrationStep(step)
                logger.info("✅ Step \(step.step) completed successfully")
            } catch {
                if step.isRequired {
                    logger.error("❌ Required step \(step.step) failed: \(error)")
                    throw MigrationError.stepFailed(step: step.step, error: error)
                } else {
                    logger.warning("⚠️ Optional step \(step.step) failed: \(error)")
                }
            }
        }
        
        // Update schema version
        try await updateSchemaVersion(to: toVersion)
        
        logger.info("✅ Migration from v\(fromVersion) to v\(toVersion) completed successfully")
    }
    
    private func executeMigrationStep(_ step: MigrationStep) async throws {
        switch step.operation {
        case .dataTransform(let transform):
            // Execute data transformation
            try await performDataTransform(transform)
        case .dataValidation(let validator):
            // Execute data validation
            try await performDataValidation(validator)
        case .schemaUpdate(let update):
            // Execute schema update
            await performSchemaUpdate(update)
        case .dataCleanup(let cleanup):
            // Execute data cleanup
            await performDataCleanup(cleanup)
        case .custom(let operation):
            // Execute custom operation
            await operation()
        }
    }
    
    private func performDataTransform(_ transform: (Any) -> Any) async throws {
        // Implementation would depend on specific data transformation needs
        logger.info("🔄 Executing data transformation")
    }
    
    private func performDataValidation(_ validator: (Any) -> Bool) async throws {
        // Implementation would validate data integrity
        logger.info("✅ Executing data validation")
    }
    
    private func performSchemaUpdate(_ update: () -> Void) async {
        // Implementation would update schema
        await update()
        logger.info("📋 Executing schema update")
    }
    
    private func performDataCleanup(_ cleanup: () -> Void) async {
        // Implementation would clean up old data
        await cleanup()
        logger.info("🧹 Executing data cleanup")
    }
    
    private func updateSchemaVersion(to version: Int) async throws {
        // Update the schema version in storage
        let container = SwiftDataContainer.shared
        container.updateSchemaVersion(to: version)
        logger.info("📝 Updated schema version to \(version)")
    }
}

// MARK: - Migration Errors

enum MigrationError: Error, LocalizedError {
    case unsupportedMigration(from: Int, to: Int)
    case stepFailed(step: Int, error: Error)
    case validationFailed(step: Int, reason: String)
    case dataCorruption(details: String)
    case insufficientStorage(required: Int64, available: Int64)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedMigration(let from, let to):
            return "Migration from version \(from) to \(to) is not supported"
        case .stepFailed(let step, let error):
            return "Migration step \(step) failed: \(error.localizedDescription)"
        case .validationFailed(let step, let reason):
            return "Migration step \(step) validation failed: \(reason)"
        case .dataCorruption(let details):
            return "Data corruption detected during migration: \(details)"
        case .insufficientStorage(let required, let available):
            return "Insufficient storage for migration. Required: \(required), Available: \(available)"
        }
    }
}

// MARK: - Usage Examples

/*
 Usage Examples:
 
 // Check current schema version
 let currentVersion = SchemaVersion.current
 
 // Check if migration is needed
 let storedVersion = getStoredSchemaVersion()
 if storedVersion < SchemaVersion.current {
     // Migration needed
 }
 
 // Execute migration
 let executor = SchemaMigrationExecutor()
 try await executor.executeMigration(from: storedVersion, to: SchemaVersion.current)
 
 // Validate migration path
 if SchemaVersion.canMigrate(from: 1, to: 2) {
     // Safe to migrate
 }
 
 // Get migration information
 if let migrationInfo = SchemaVersion.getMigrationInfo(from: 1, to: 2) {
     print("Migration includes \(migrationInfo.steps.count) steps")
     if migrationInfo.isBreakingChange {
         print("⚠️ Breaking changes: \(migrationInfo.breakingChanges)")
     }
 }
 */
