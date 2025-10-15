import Foundation
import OSLog

// MARK: - Migration Telemetry

/// Enhanced telemetry service for dual-write and migration operations
final class MigrationTelemetryService {
    
    static let shared = MigrationTelemetryService()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationTelemetry")
    
    // MARK: - Private Helper Methods
    
    private func incrementDualWrite(_ operation: String, success: Bool) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 DualWrite: \(operation) - Success: \(success)")
    }
    
    private func incrementBackfill(_ operation: String, success: Bool) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 Backfill: \(operation) - Success: \(success)")
    }
    
    private func incrementCache(_ operation: String, success: Bool) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 Cache: \(operation) - Success: \(success)")
    }
    
    private func incrementRepository(_ operation: String, success: Bool) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 Repository: \(operation) - Success: \(success)")
    }
    
    private func recordDuration(_ metric: String, duration: TimeInterval) {
        // Placeholder implementation - integrate with actual analytics
        recordMetric(metric, value: duration)
    }
    
    private func recordMetric(_ metric: String, value: Double) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 Metric: \(metric) - \(value)")
    }
    
    private func recordEvent(_ event: String, parameters: [String: String]) {
        // Placeholder implementation - integrate with actual analytics
        logger.debug("📊 Event: \(event) - \(parameters)")
    }
    
    private func recordError(_ context: String, error: Error, additionalInfo: [String: String] = [:]) {
        // Placeholder implementation - integrate with actual analytics
        logger.error("📊 Error: \(context) - \(error.localizedDescription) - \(additionalInfo)")
    }
    
    // MARK: - Dual-Write Telemetry
    
    /// Track dual-write operations
    func trackDualWrite(operation: String, primarySuccess: Bool, secondarySuccess: Bool, duration: TimeInterval) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        let success = primarySuccess // Primary success determines overall success
        
        // Log the operation
        if success {
            logger.info("✅ DualWrite: \(operation) - Primary: \(primarySuccess), Secondary: \(secondarySuccess), Duration: \(duration)s")
        } else {
            logger.warning("❌ DualWrite: \(operation) - Primary: \(primarySuccess), Secondary: \(secondarySuccess), Duration: \(duration)s")
        }
        
        // Record in telemetry service
        incrementDualWrite(operation, success: success)
        
        // Record secondary write status separately
        incrementDualWrite("\(operation).secondary", success: secondarySuccess)
        
        // Record duration
        recordDuration("dualwrite.\(operation).duration", duration: duration)
        
        // Record in crashlytics if secondary failed
        if !secondarySuccess {
            let error = NSError(domain: "DualWrite", code: 1001, userInfo: [
                "operation": operation,
                "primary_success": primarySuccess,
                "secondary_success": secondarySuccess
            ])
            CrashlyticsService.shared.recordError(error)
        }
    }
    
    /// Track dual-write batch operations
    func trackDualWriteBatch(operation: String, batchSize: Int, primarySuccess: Bool, secondarySuccess: Bool, duration: TimeInterval) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        let success = primarySuccess
        
        logger.info("📦 DualWriteBatch: \(operation) - Size: \(batchSize), Primary: \(primarySuccess), Secondary: \(secondarySuccess), Duration: \(duration)s")
        
incrementDualWrite("batch.\(operation)", success: success)
incrementDualWrite("batch.\(operation).secondary", success: secondarySuccess)
recordDuration("dualwrite.batch.\(operation).duration", duration: duration)
        
        // Record batch size
recordMetric("dualwrite.batch.size", value: Double(batchSize))
    }
    
    // MARK: - Migration Telemetry
    
    /// Track migration start
    func trackMigrationStart(userId: String, totalItems: Int) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        logger.info("🚀 Migration: Started for user \(userId) - \(totalItems) items")
        
incrementBackfill("migration.started", success: true)
recordMetric("migration.total_items", value: Double(totalItems))
        
        // Set migration start time
        UserDefaults.standard.set(Date(), forKey: "migration_start_time_\(userId)")
    }
    
    /// Track migration progress
    func trackMigrationProgress(userId: String, itemsProcessed: Int, totalItems: Int, batchNumber: Int) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        let progress = Double(itemsProcessed) / Double(totalItems)
        let progressPercentage = Int(progress * 100)
        
        if itemsProcessed % 10 == 0 || batchNumber % 5 == 0 { // Log every 10 items or 5 batches
            logger.debug("📊 Migration: Progress for user \(userId) - \(itemsProcessed)/\(totalItems) (\(progressPercentage)%), Batch: \(batchNumber)")
        }
        
recordMetric("migration.progress", value: progress)
incrementBackfill("migration.batch.processed", success: true)
    }
    
    /// Track migration completion
    func trackMigrationCompletion(userId: String, itemsProcessed: Int, duration: TimeInterval) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        logger.info("✅ Migration: Completed for user \(userId) - \(itemsProcessed) items in \(duration)s")
        
incrementBackfill("migration.completed", success: true)
recordDuration("migration.total.duration", duration: duration)
recordMetric("migration.items_processed", value: Double(itemsProcessed))
        
        // Calculate items per second
        let itemsPerSecond = Double(itemsProcessed) / duration
recordMetric("migration.items_per_second", value: itemsPerSecond)
        
        // Clear migration start time
        UserDefaults.standard.removeObject(forKey: "migration_start_time_\(userId)")
    }
    
    /// Track migration failure
    func trackMigrationFailure(userId: String, error: Error, itemsProcessed: Int, lastItemKey: String?) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        logger.error("❌ Migration: Failed for user \(userId) - \(error.localizedDescription), Items: \(itemsProcessed), LastKey: \(lastItemKey ?? "none")")
        
incrementBackfill("migration.failed", success: false)
recordMetric("migration.items_before_failure", value: Double(itemsProcessed))
        
        // Record error details
        let errorInfo = [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "items_processed": String(itemsProcessed),
            "last_item_key": lastItemKey ?? "none"
        ]
        
recordError("migration.failure", error: error, additionalInfo: errorInfo)
        CrashlyticsService.shared.recordError(error)
        
        // Clear migration start time
        UserDefaults.standard.removeObject(forKey: "migration_start_time_\(userId)")
    }
    
    /// Track migration batch processing
    func trackMigrationBatch(batchNumber: Int, batchSize: Int, success: Bool, duration: TimeInterval, error: Error? = nil) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        let operation = success ? "batch.success" : "batch.failure"
        
        logger.debug("📦 Migration: Batch \(batchNumber) - Size: \(batchSize), Success: \(success), Duration: \(duration)s")
        
incrementBackfill(operation, success: success)
recordDuration("migration.batch.duration", duration: duration)
recordMetric("migration.batch.size", value: Double(batchSize))
        
        if let error = error {
recordError("migration.batch.error", error: error)
        }
    }
    
    // MARK: - Cache Telemetry
    
    /// Track cache operations
    func trackCacheOperation(operation: String, hit: Bool, key: String) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        let success = hit
        let result = hit ? "hit" : "miss"
        
incrementCache("cache.\(operation).\(result)", success: success)
        
        if MigrationFeatureFlags.debugMigration {
            logger.debug("💾 Cache: \(operation) - \(result) for key: \(key)")
        }
    }
    
    /// Track cache invalidation
    func trackCacheInvalidation(key: String, reason: String) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
incrementCache("cache.invalidation", success: true)
        
        if MigrationFeatureFlags.debugMigration {
            logger.debug("🗑️ Cache: Invalidated key: \(key), reason: \(reason)")
        }
    }
    
    // MARK: - Feature Flag Telemetry
    
    /// Track feature flag changes
    func trackFeatureFlagChange(flag: String, oldValue: Any, newValue: Any, source: String) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        logger.info("🚩 FeatureFlag: \(flag) changed from \(String(describing: oldValue)) to \(String(describing: newValue)) (source: \(source))")
        
recordEvent("feature_flag.changed", parameters: [
            "flag": flag,
            "old_value": String(describing: oldValue),
            "new_value": String(describing: newValue),
            "source": source
        ])
    }
    
    // MARK: - Performance Telemetry
    
    /// Track repository performance
    func trackRepositoryPerformance(repository: String, operation: String, duration: TimeInterval, success: Bool) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
recordDuration("repository.\(repository).\(operation).duration", duration: duration)
incrementRepository("repository.\(repository).\(operation)", success: success)
        
        if duration > 5.0 { // Log slow operations
            logger.warning("🐌 Performance: Slow \(repository).\(operation) operation - \(duration)s")
        }
    }
    
    /// Track memory usage during migration
    func trackMemoryUsage(context: String, memoryUsage: Int) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
recordMetric("memory.\(context)", value: Double(memoryUsage))
        
        // Log high memory usage
        if memoryUsage > 100 * 1024 * 1024 { // 100 MB
            logger.warning("🧠 Memory: High usage in \(context) - \(memoryUsage / 1024 / 1024) MB")
        }
    }
    
    // MARK: - Error Telemetry
    
    /// Track specific migration errors
    func trackMigrationError(type: MigrationErrorType, context: String, error: Error, additionalInfo: [String: String] = [:]) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
        var errorInfo = additionalInfo
            errorInfo["error_type"] = String(describing: type)
        errorInfo["context"] = context
        errorInfo["error_message"] = error.localizedDescription
        
recordError("migration.\(String(describing: type))", error: error, additionalInfo: errorInfo)
        
        logger.error("❌ Migration: \(String(describing: type)) in \(context) - \(error.localizedDescription)")
    }
    
    // MARK: - Health Check Telemetry
    
    /// Track system health during migration
    func trackSystemHealth(metrics: SystemHealthMetrics) {
        guard MigrationFeatureFlags.migrationTelemetryEnabled else { return }
        
recordMetric("system.memory_usage", value: Double(metrics.memoryUsage))
recordMetric("system.cpu_usage", value: metrics.cpuUsage)
recordMetric("system.disk_space", value: Double(metrics.diskSpace))
recordMetric("system.network_status", value: metrics.networkAvailable ? 1.0 : 0.0)
        
        // Log concerning metrics
        if metrics.memoryUsage > 200 * 1024 * 1024 { // 200 MB
            logger.warning("🧠 System: High memory usage - \(metrics.memoryUsage / 1024 / 1024) MB")
        }
        
        if metrics.cpuUsage > 80.0 { // 80%
            logger.warning("⚡ System: High CPU usage - \(metrics.cpuUsage)%")
        }
    }
}

// MARK: - Migration Error Types (using existing MigrationErrorType from DataError.swift)

// MARK: - System Health Metrics

struct SystemHealthMetrics {
    let memoryUsage: Int // bytes
    let cpuUsage: Double // percentage
    let diskSpace: Int // bytes available
    let networkAvailable: Bool
    let timestamp: Date
    
    init(memoryUsage: Int, cpuUsage: Double, diskSpace: Int, networkAvailable: Bool) {
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.diskSpace = diskSpace
        self.networkAvailable = networkAvailable
        self.timestamp = Date()
    }
}

// MARK: - Telemetry Service Extensions

