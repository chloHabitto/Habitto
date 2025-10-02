import Foundation

// MARK: - Common Test Types

struct TestScenario {
    let id: String
    let name: String
    let description: String
    let category: TestCategory
    let complexity: TestComplexity
    
    enum TestCategory {
        case reliability
        case performance
        case security
        case concurrency
        case migration
        case storage
    }
    
    enum TestComplexity {
        case low
        case medium
        case high
        case critical
    }
}

struct TestScenarioResult {
    let scenario: TestScenario
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let success: Bool
    let error: String?
    let metrics: TestMetrics
    let severity: TestSeverity
    
    struct TestMetrics {
        let recordsProcessed: Int
        let memoryUsage: Int64
        let diskUsage: Int64
        let networkCalls: Int
        let fileOperations: Int
        let encryptionOperations: Int
        let validationChecks: Int
        
        init(recordsProcessed: Int = 0, memoryUsage: Int64 = 0, diskUsage: Int64 = 0, networkCalls: Int = 0, fileOperations: Int = 0, encryptionOperations: Int = 0, validationChecks: Int = 0) {
            self.recordsProcessed = recordsProcessed
            self.memoryUsage = memoryUsage
            self.diskUsage = diskUsage
            self.networkCalls = networkCalls
            self.fileOperations = fileOperations
            self.encryptionOperations = encryptionOperations
            self.validationChecks = validationChecks
        }
    }
    
    enum TestSeverity {
        case low
        case medium
        case high
        case critical
    }
    
    init(scenario: TestScenario, startTime: Date, endTime: Date, duration: TimeInterval, success: Bool, error: String?, metrics: TestMetrics, severity: TestSeverity) {
        self.scenario = scenario
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.success = success
        self.error = error
        self.metrics = metrics
        self.severity = severity
    }
}

// MARK: - Test Scenario Extensions

extension TestScenario {
    static let widgetExtensionConcurrency = TestScenario(
        id: "widget_extension_concurrency",
        name: "Widget/Extension Concurrent Access",
        description: "Test concurrent access between main app and widget extension",
        category: .concurrency,
        complexity: .high
    )
    
    static let fileCoordinatorRacePrevention = TestScenario(
        id: "file_coordinator_race_prevention",
        name: "File Coordinator Race Prevention",
        description: "Test NSFileCoordinator prevents file corruption during concurrent access",
        category: .concurrency,
        complexity: .high
    )
    
    static let actorIsolation = TestScenario(
        id: "actor_isolation",
        name: "Actor Isolation",
        description: "Test actor isolation prevents data races",
        category: .concurrency,
        complexity: .medium
    )
    
    static let powerLossBetweenReplaceAndVerify = TestScenario(
        id: "power_loss_replace_verify",
        name: "Power Loss Between Replace and Verify",
        description: "Test recovery from power loss between atomic replace and verification",
        category: .reliability,
        complexity: .high
    )
    
    static let powerLossBetweenVerifyAndBackup = TestScenario(
        id: "power_loss_verify_backup",
        name: "Power Loss Between Verify and Backup",
        description: "Test recovery from power loss between verification and backup rotation",
        category: .reliability,
        complexity: .high
    )
    
    static let powerLossDuringBackupRotation = TestScenario(
        id: "power_loss_backup_rotation",
        name: "Power Loss During Backup Rotation",
        description: "Test recovery from power loss during backup rotation",
        category: .reliability,
        complexity: .high
    )
    
    static let corruptedTempFileRecovery = TestScenario(
        id: "corrupted_temp_file_recovery",
        name: "Corrupted Temp File Recovery",
        description: "Test recovery from corrupted temp files after power loss",
        category: .reliability,
        complexity: .high
    )
    
    static let atomicWriteIntegrity = TestScenario(
        id: "atomic_write_integrity",
        name: "Atomic Write Integrity",
        description: "Test atomic write integrity during power loss scenarios",
        category: .reliability,
        complexity: .critical
    )
    
    static let iCloudRestoreWithBackups = TestScenario(
        id: "icloud_restore_with_backups",
        name: "iCloud Restore With Backups",
        description: "Test iCloud restore with backup files and payload version consistency",
        category: .reliability,
        complexity: .high
    )
    
    static let iCloudRestoreFromBackup = TestScenario(
        id: "icloud_restore_from_backup",
        name: "iCloud Restore From Backup",
        description: "Test iCloud restore when main file is corrupted but backup is available",
        category: .reliability,
        complexity: .high
    )
    
    static let iCloudRestoreVersionMismatch = TestScenario(
        id: "icloud_restore_version_mismatch",
        name: "iCloud Restore Version Mismatch",
        description: "Test iCloud restore with version mismatch handling",
        category: .reliability,
        complexity: .medium
    )
    
    static let iCloudRestoreMissingBackups = TestScenario(
        id: "icloud_restore_missing_backups",
        name: "iCloud Restore Missing Backups",
        description: "Test iCloud restore with missing backup files",
        category: .reliability,
        complexity: .medium
    )
    
    static let iCloudRestoreCorruptedVersion = TestScenario(
        id: "icloud_restore_corrupted_version",
        name: "iCloud Restore Corrupted Version",
        description: "Test iCloud restore with corrupted payload version",
        category: .reliability,
        complexity: .medium
    )
    
    static let offlineDeviceResurrectionPrevention = TestScenario(
        id: "offline_device_resurrection_prevention",
        name: "Offline Device Resurrection Prevention",
        description: "Test offline device comes online later with tombstone preventing resurrection",
        category: .security,
        complexity: .critical
    )
    
    static let tombstoneTTLExpiration = TestScenario(
        id: "tombstone_ttl_expiration",
        name: "Tombstone TTL Expiration",
        description: "Test tombstone TTL expiration and garbage collection",
        category: .security,
        complexity: .medium
    )
    
    static let tombstonePreventsRecreation = TestScenario(
        id: "tombstone_prevents_recreation",
        name: "Tombstone Prevents Recreation",
        description: "Test tombstone prevents re-creation of deleted habits",
        category: .security,
        complexity: .high
    )
    
    static let crossDeviceTombstoneSync = TestScenario(
        id: "cross_device_tombstone_sync",
        name: "Cross Device Tombstone Sync",
        description: "Test cross-device tombstone synchronization",
        category: .security,
        complexity: .high
    )
    
    static let tombstoneVerificationIntegrity = TestScenario(
        id: "tombstone_verification_integrity",
        name: "Tombstone Verification Integrity",
        description: "Test tombstone verification and integrity",
        category: .security,
        complexity: .medium
    )
    
    // Additional test scenarios for ImprovedTestScenarios
    static let clockSkew = TestScenario(
        id: "clock_skew",
        name: "Clock Skew",
        description: "Test clock skew scenarios",
        category: .reliability,
        complexity: .medium
    )
    
    static let crashRecovery = TestScenario(
        id: "crash_recovery",
        name: "Crash Recovery",
        description: "Test crash recovery scenarios",
        category: .reliability,
        complexity: .high
    )
    
    static let largeDataset = TestScenario(
        id: "large_dataset",
        name: "Large Dataset",
        description: "Test large dataset handling",
        category: .performance,
        complexity: .high
    )
}
