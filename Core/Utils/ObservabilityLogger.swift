import Foundation
import OSLog

// MARK: - Observability Logger
/// Lightweight logging for migration, XP awards, and auth switches
@MainActor
final class ObservabilityLogger {
    static let shared = ObservabilityLogger()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "Observability")
    
    private init() {}
    
    // MARK: - Migration Logging
    
    /// Log migration start
    func logMigrationStart(userId: String, version: Int) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("Migration started - userId: \(anonymizedUserId), version: \(version)")
    }
    
    /// Log migration end
    func logMigrationEnd(userId: String, version: Int, success: Bool, recordsCount: Int, duration: TimeInterval) {
        let anonymizedUserId = anonymizeUserId(userId)
        let status = success ? "success" : "failure"
        logger.info("Migration ended - userId: \(anonymizedUserId), version: \(version), status: \(status), records: \(recordsCount), duration: \(String(format: "%.2f", duration))s")
    }
    
    /// Log migration error
    func logMigrationError(userId: String, version: Int, error: Error) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.error("Migration error - userId: \(anonymizedUserId), version: \(version), error: \(error.localizedDescription)")
    }
    
    // MARK: - XP Award Logging
    
    /// Log XP award event
    func logXPAward(userId: String, dateKey: String, xpGranted: Int, reason: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("XP awarded - userId: \(anonymizedUserId), dateKey: \(dateKey), xp: \(xpGranted), reason: \(reason)")
    }
    
    /// Log XP revocation event
    func logXPRevocation(userId: String, dateKey: String, xpRevoked: Int, reason: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("XP revoked - userId: \(anonymizedUserId), dateKey: \(dateKey), xp: \(xpRevoked), reason: \(reason)")
    }
    
    /// Log level up event
    func logLevelUp(userId: String, oldLevel: Int, newLevel: Int, totalXP: Int) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("Level up - userId: \(anonymizedUserId), level: \(oldLevel) -> \(newLevel), totalXP: \(totalXP)")
    }
    
    // MARK: - Auth Switch Logging
    
    /// Log auth container switch
    func logAuthSwitch(fromUserId: String?, toUserId: String, reason: String) {
        let anonymizedFromUserId = fromUserId.map(anonymizeUserId) ?? "none"
        let anonymizedToUserId = anonymizeUserId(toUserId)
        logger.info("Auth switch - from: \(anonymizedFromUserId), to: \(anonymizedToUserId), reason: \(reason)")
    }
    
    /// Log repository provider creation
    func logRepositoryProviderCreated(userId: String, providerType: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("Repository provider created - userId: \(anonymizedUserId), type: \(providerType)")
    }
    
    /// Log cache clear event
    func logCacheCleared(userId: String, cacheType: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("Cache cleared - userId: \(anonymizedUserId), type: \(cacheType)")
    }
    
    // MARK: - Data Quality Logging
    
    /// Log data consistency check
    func logDataConsistencyCheck(userId: String, checkType: String, passed: Bool, details: String? = nil) {
        let anonymizedUserId = anonymizeUserId(userId)
        let status = passed ? "passed" : "failed"
        let detailsStr = details.map { ", details: \($0)" } ?? ""
        logger.info("Data consistency check - userId: \(anonymizedUserId), type: \(checkType), status: \(status)\(detailsStr)")
    }
    
    /// Log denormalized field access
    func logDenormalizedFieldAccess(userId: String, fieldName: String, accessType: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.warning("Denormalized field access - userId: \(anonymizedUserId), field: \(fieldName), type: \(accessType)")
    }
    
    // MARK: - Performance Logging
    
    /// Log slow operation
    func logSlowOperation(operation: String, duration: TimeInterval, threshold: TimeInterval) {
        logger.warning("Slow operation - operation: \(operation), duration: \(String(format: "%.2f", duration))s, threshold: \(String(format: "%.2f", threshold))s")
    }
    
    /// Log memory usage
    func logMemoryUsage(operation: String, memoryMB: Double) {
        logger.info("Memory usage - operation: \(operation), memory: \(String(format: "%.1f", memoryMB))MB")
    }
    
    // MARK: - Error Logging
    
    /// Log XP mutation violation
    func logXPMutationViolation(caller: String, function: String, userId: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.error("XP mutation violation - caller: \(caller), function: \(function), userId: \(anonymizedUserId)")
    }
    
    /// Log data corruption detected
    func logDataCorruption(userId: String, corruptionType: String, details: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.error("Data corruption detected - userId: \(anonymizedUserId), type: \(corruptionType), details: \(details)")
    }
    
    // MARK: - Private Helpers
    
    /// Anonymize user ID for logging (no PII)
    private func anonymizeUserId(_ userId: String) -> String {
        // Simple anonymization: use first 8 characters of hash
        let hash = userId.data(using: .utf8)?.withUnsafeBytes { bytes in
            var hasher = Hasher()
            hasher.combine(bytes: bytes)
            return String(hasher.finalize().magnitude, radix: 16)
        } ?? "unknown"
        
        return String(hash.prefix(8))
    }
}

// MARK: - Observability Extensions
extension ObservabilityLogger {
    
    /// Log feature flag change
    func logFeatureFlagChange(flagName: String, oldValue: Bool, newValue: Bool, userId: String) {
        let anonymizedUserId = anonymizeUserId(userId)
        logger.info("Feature flag changed - flag: \(flagName), \(oldValue) -> \(newValue), userId: \(anonymizedUserId)")
    }
    
    /// Log test execution
    func logTestExecution(testName: String, passed: Bool, duration: TimeInterval) {
        let status = passed ? "passed" : "failed"
        logger.info("Test executed - test: \(testName), status: \(status), duration: \(String(format: "%.2f", duration))s")
    }
    
    /// Log app lifecycle event
    func logAppLifecycleEvent(event: String, userId: String?) {
        let anonymizedUserId = userId.map(anonymizeUserId) ?? "none"
        logger.info("App lifecycle - event: \(event), userId: \(anonymizedUserId)")
    }
}
