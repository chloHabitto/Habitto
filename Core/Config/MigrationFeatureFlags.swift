import Foundation
import OSLog

// MARK: - Migration Feature Flags

/// Centralized feature flag management for Firebase migration
/// Uses UserDefaults for local configuration with future Remote Config integration
enum MigrationFeatureFlags {
    
    // MARK: - Dual-Write Migration Flags
    
    /// Enable dual-write to both Firestore and CloudKit
    /// Default: true (safe to enable)
    static var dualWriteEnabled: Bool {
        UserDefaults.standard.object(forKey: "dualWriteEnabled") as? Bool ?? true
    }
    
    /// Enable automatic backfill migration from legacy data
    /// Default: false (manual control for rollout)
    static var backfillEnabled: Bool {
        UserDefaults.standard.object(forKey: "backfillEnabled") as? Bool ?? false
    }
    
    /// Enable fallback reads from legacy system when Firestore data is missing
    /// Default: true (safe fallback during migration)
    static var legacyReadFallbackEnabled: Bool {
        UserDefaults.standard.object(forKey: "legacyReadFallbackEnabled") as? Bool ?? true
    }
    
    /// Enable UI cache for improved performance
    /// Default: true (performance optimization)
    static var uiCacheEnabled: Bool {
        UserDefaults.standard.object(forKey: "uiCacheEnabled") as? Bool ?? true
    }
    
    // MARK: - Migration Control Flags
    
    /// Percentage of users to enable backfill for (0-100)
    /// Used for gradual rollout
    static var backfillRolloutPercentage: Int {
        UserDefaults.standard.object(forKey: "backfillRolloutPercentage") as? Int ?? 0
    }
    
    /// Enable telemetry collection for migration monitoring
    /// Default: true (important for monitoring)
    static var migrationTelemetryEnabled: Bool {
        UserDefaults.standard.object(forKey: "migrationTelemetryEnabled") as? Bool ?? true
    }
    
    /// Force migration to complete (bypass user percentage checks)
    /// Default: false (emergency override)
    static var forceMigrationComplete: Bool {
        UserDefaults.standard.object(forKey: "forceMigrationComplete") as? Bool ?? false
    }
    
    // MARK: - Debug Flags
    
    /// Enable debug logging for dual-write operations
    /// Default: false (only in debug builds)
    static var debugDualWrite: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: "debugDualWrite") as? Bool ?? false
        #else
        return false
        #endif
    }
    
    /// Enable debug logging for migration operations
    /// Default: false (only in debug builds)
    static var debugMigration: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: "debugMigration") as? Bool ?? false
        #else
        return false
        #endif
    }
    
    // MARK: - Performance Flags
    
    /// Batch size for migration operations
    /// Default: 50 (balance between speed and reliability)
    static var migrationBatchSize: Int {
        UserDefaults.standard.object(forKey: "migrationBatchSize") as? Int ?? 50
    }
    
    /// Timeout for individual migration operations (seconds)
    /// Default: 30 (generous timeout)
    static var migrationTimeoutSeconds: Int {
        UserDefaults.standard.object(forKey: "migrationTimeoutSeconds") as? Int ?? 30
    }
    
    /// Enable retry logic for failed migration operations
    /// Default: true (improve reliability)
    static var migrationRetryEnabled: Bool {
        UserDefaults.standard.object(forKey: "migrationRetryEnabled") as? Bool ?? true
    }
    
    // MARK: - User Experience Flags
    
    /// Show migration progress UI to users
    /// Default: false (background operation)
    static var showMigrationProgress: Bool {
        UserDefaults.standard.object(forKey: "showMigrationProgress") as? Bool ?? false
    }
    
    /// Enable migration success notification
    /// Default: false (silent operation)
    static var showMigrationSuccess: Bool {
        UserDefaults.standard.object(forKey: "showMigrationSuccess") as? Bool ?? false
    }
    
    // MARK: - Rollout Logic
    
    /// Check if current user should be included in backfill rollout
    static func shouldEnableBackfill(for userId: String) -> Bool {
        // Force complete overrides everything
        if forceMigrationComplete {
            return true
        }
        
        // Check rollout percentage
        let hash = userId.hashValue
        let userPercentage = abs(hash) % 100
        let shouldEnable = userPercentage < backfillRolloutPercentage
        
        if debugMigration {
            logger.info("🎯 MigrationFeatureFlags: User \(userId) backfill check - hash: \(userPercentage), threshold: \(backfillRolloutPercentage), enabled: \(shouldEnable)")
        }
        
        return shouldEnable
    }
    
    // MARK: - Flag Status
    
    /// Get current status of all migration-related flags
    static func getMigrationStatus() -> MigrationFlagStatus {
        return MigrationFlagStatus(
            dualWriteEnabled: dualWriteEnabled,
            backfillEnabled: backfillEnabled,
            legacyReadFallbackEnabled: legacyReadFallbackEnabled,
            uiCacheEnabled: uiCacheEnabled,
            backfillRolloutPercentage: backfillRolloutPercentage,
            migrationTelemetryEnabled: migrationTelemetryEnabled,
            forceMigrationComplete: forceMigrationComplete,
            migrationBatchSize: migrationBatchSize,
            migrationTimeoutSeconds: migrationTimeoutSeconds,
            migrationRetryEnabled: migrationRetryEnabled,
            showMigrationProgress: showMigrationProgress,
            showMigrationSuccess: showMigrationSuccess
        )
    }
    
    /// Log current flag status (for debugging)
    static func logCurrentStatus() {
        let status = getMigrationStatus()
        logger.info("🚩 MigrationFeatureFlags Status:")
        logger.info("  dualWriteEnabled: \(status.dualWriteEnabled)")
        logger.info("  backfillEnabled: \(status.backfillEnabled)")
        logger.info("  legacyReadFallbackEnabled: \(status.legacyReadFallbackEnabled)")
        logger.info("  uiCacheEnabled: \(status.uiCacheEnabled)")
        logger.info("  backfillRolloutPercentage: \(status.backfillRolloutPercentage)%")
        logger.info("  migrationTelemetryEnabled: \(status.migrationTelemetryEnabled)")
        logger.info("  forceMigrationComplete: \(status.forceMigrationComplete)")
        logger.info("  migrationBatchSize: \(status.migrationBatchSize)")
        logger.info("  migrationTimeoutSeconds: \(status.migrationTimeoutSeconds)")
        logger.info("  migrationRetryEnabled: \(status.migrationRetryEnabled)")
        logger.info("  showMigrationProgress: \(status.showMigrationProgress)")
        logger.info("  showMigrationSuccess: \(status.showMigrationSuccess)")
    }
}

// MARK: - Migration Flag Status

struct MigrationFlagStatus {
    let dualWriteEnabled: Bool
    let backfillEnabled: Bool
    let legacyReadFallbackEnabled: Bool
    let uiCacheEnabled: Bool
    let backfillRolloutPercentage: Int
    let migrationTelemetryEnabled: Bool
    let forceMigrationComplete: Bool
    let migrationBatchSize: Int
    let migrationTimeoutSeconds: Int
    let migrationRetryEnabled: Bool
    let showMigrationProgress: Bool
    let showMigrationSuccess: Bool
    
    /// Check if migration is in progress
    var isMigrationActive: Bool {
        return dualWriteEnabled && (backfillEnabled || forceMigrationComplete)
    }
    
    /// Check if migration is complete
    var isMigrationComplete: Bool {
        return !dualWriteEnabled && !legacyReadFallbackEnabled
    }
}

// MARK: - Feature Flag Management

/// Helper methods for managing feature flags
extension MigrationFeatureFlags {
    
    /// Set a boolean feature flag
    static func setBool(_ key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    /// Set an integer feature flag
    static func setInt(_ key: String, value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    /// Reset all feature flags to defaults
    static func resetToDefaults() {
        let keys = [
            "dualWriteEnabled", "backfillEnabled", "legacyReadFallbackEnabled", 
            "uiCacheEnabled", "backfillRolloutPercentage", "migrationTelemetryEnabled",
            "forceMigrationComplete", "debugDualWrite", "debugMigration",
            "migrationBatchSize", "migrationTimeoutSeconds", "migrationRetryEnabled",
            "showMigrationProgress", "showMigrationSuccess"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Logging

private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationFeatureFlags")
