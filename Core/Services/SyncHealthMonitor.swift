import Foundation
import OSLog

// MARK: - SyncHealthMonitor

/// Service to monitor and track sync health metrics
///
/// Tracks:
/// - Sync success rate (target: >99%)
/// - Sync latency (p50, p95, p99)
/// - Conflict resolution frequency
/// - Failed sync attempts with retry count
/// - Queue size (unsynced events count)
///
/// Metrics are stored in UserDefaults and aggregated daily/weekly
@MainActor
class SyncHealthMonitor {
    // MARK: - Singleton
    
    static let shared = SyncHealthMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "SyncHealthMonitor")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SyncHealthMonitor initialized")
    }
    
    // MARK: - Metric Recording
    
    /// Record a sync operation
    func recordSync(
        operation: SyncOperation,
        duration: TimeInterval,
        success: Bool,
        itemsSynced: Int = 0,
        itemsFailed: Int = 0,
        conflictsResolved: Int = 0,
        error: Error? = nil
    ) {
        // Access user ID synchronously since we're on MainActor
        let userId = AuthenticationManager.shared.currentUser?.uid ?? ""
        guard !CurrentUser.isGuestId(userId) else {
            return // Skip metrics for guest users
        }
        
        let timestamp = Date()
        let syncRecord = SyncRecord(
            operation: operation,
            timestamp: timestamp,
            duration: duration,
            success: success,
            itemsSynced: itemsSynced,
            itemsFailed: itemsFailed,
            conflictsResolved: conflictsResolved,
            error: error?.localizedDescription
        )
        
        // Save to daily metrics
        saveSyncRecord(syncRecord, userId: userId)
        
        // Update aggregated statistics
        updateAggregatedStats(syncRecord: syncRecord, userId: userId)
        
    }
    
    /// Record queue size (unsynced items count)
    func recordQueueSize(_ size: Int, operation: SyncOperation) {
        // Access user ID synchronously since we're on MainActor
        let userId = AuthenticationManager.shared.currentUser?.uid ?? ""
        guard !CurrentUser.isGuestId(userId) else {
            return
        }
        
        let dateKey = dateKeyForToday()
        let key = "\(userId)_sync_queue_\(operation.rawValue)_\(dateKey)"
        userDefaults.set(size, forKey: key)
        
        logger.debug("📊 Queue size recorded: operation=\(operation.rawValue), size=\(size)")
    }
    
    // MARK: - Metrics Retrieval
    
    /// Get sync health summary for today
    func getTodayMetrics(userId: String) -> SyncHealthSummary {
        let dateKey = dateKeyForToday()
        return getMetricsForDate(dateKey: dateKey, userId: userId)
    }
    
    /// Get sync health summary for a specific date
    func getMetricsForDate(dateKey: String, userId: String) -> SyncHealthSummary {
        let prefix = "\(userId)_sync_\(dateKey)"
        
        // Load all sync records for this date
        let recordKeys = userDefaults.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix(prefix) && key.contains("_record_")
        }
        
        var records: [SyncRecord] = []
        for key in recordKeys {
            if let data = userDefaults.data(forKey: key),
               let record = try? JSONDecoder().decode(SyncRecord.self, from: data) {
                records.append(record)
            }
        }
        
        return calculateSummary(from: records)
    }
    
    /// Get sync health summary for the last N days
    func getMetricsForLastDays(_ days: Int, userId: String) -> SyncHealthSummary {
        let calendar = Calendar.current
        var allRecords: [SyncRecord] = []
        
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dateKey = dateKeyFormatter.string(from: date)
                let metrics = getMetricsForDate(dateKey: dateKey, userId: userId)
                // Aggregate records from summary
                // Note: This is a simplified aggregation - in production, you'd want to keep raw records
                allRecords.append(contentsOf: metrics.syncRecords)
            }
        }
        
        return calculateSummary(from: allRecords)
    }
    
    // MARK: - Health Status
    
    /// Get overall sync health status
    func getHealthStatus(userId: String) -> SyncHealthStatus {
        let weekMetrics = getMetricsForLastDays(7, userId: userId)
        
        // Calculate health score (0-100)
        var healthScore = 100.0
        
        // Deduct points for low success rate
        if weekMetrics.totalSyncs > 0 {
            let successRate = weekMetrics.successRate
            if successRate < 0.99 {
                healthScore -= (0.99 - successRate) * 100 // Deduct up to 9 points
            }
        }
        
        // Deduct points for high latency (p95 > 5 seconds)
        if weekMetrics.p95Latency > 5.0 {
            healthScore -= min(10.0, (weekMetrics.p95Latency - 5.0) * 2) // Deduct up to 10 points
        }
        
        // Deduct points for high failure rate
        if weekMetrics.totalSyncs > 0 {
            let failureRate = Double(weekMetrics.failedSyncs) / Double(weekMetrics.totalSyncs)
            if failureRate > 0.01 {
                healthScore -= min(20.0, (failureRate - 0.01) * 200) // Deduct up to 20 points
            }
        }
        
        // Determine status
        if healthScore >= 95 {
            return .healthy
        } else if healthScore >= 80 {
            return .degraded
        } else {
            return .unhealthy
        }
    }
    
    // MARK: - Cleanup
    
    /// Clean up old metrics (older than 30 days)
    func cleanupOldMetrics(userId: String) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffKey = dateKeyFormatter.string(from: cutoffDate)
        
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefix = "\(userId)_sync_"
        
        var deletedCount = 0
        for key in allKeys {
            if key.hasPrefix(prefix) {
                // Extract date key from the stored key
                // Format: "{userId}_sync_{dateKey}_{type}_{index}"
                let components = key.dropFirst(prefix.count).split(separator: "_")
                if components.count >= 1 {
                    let dateKey = String(components[0])
                    if dateKey < cutoffKey {
                        userDefaults.removeObject(forKey: key)
                        deletedCount += 1
                    }
                }
            }
        }
        
        logger.info("🧹 Cleaned up \(deletedCount) old sync metric records")
    }
    
    // MARK: - Private Helpers
    
    private func saveSyncRecord(_ record: SyncRecord, userId: String) {
        let dateKey = dateKeyFormatter.string(from: record.timestamp)
        let index = getNextRecordIndex(dateKey: dateKey, userId: userId)
        let key = "\(userId)_sync_\(dateKey)_record_\(index)"
        
        if let data = try? JSONEncoder().encode(record) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    private func getNextRecordIndex(dateKey: String, userId: String) -> Int {
        let prefix = "\(userId)_sync_\(dateKey)_record_"
        let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        return allKeys.count
    }
    
    private func updateAggregatedStats(syncRecord: SyncRecord, userId: String) {
        let dateKey = dateKeyFormatter.string(from: syncRecord.timestamp)
        let prefix = "\(userId)_sync_\(dateKey)_agg"
        
        // Load existing aggregated stats
        var totalSyncs = userDefaults.integer(forKey: "\(prefix)_total")
        var successfulSyncs = userDefaults.integer(forKey: "\(prefix)_success")
        var failedSyncs = userDefaults.integer(forKey: "\(prefix)_failed")
        var totalItemsSynced = userDefaults.integer(forKey: "\(prefix)_itemsSynced")
        var totalConflicts = userDefaults.integer(forKey: "\(prefix)_conflicts")
        
        // Update stats
        totalSyncs += 1
        if syncRecord.success {
            successfulSyncs += 1
            totalItemsSynced += syncRecord.itemsSynced
        } else {
            failedSyncs += 1
        }
        totalConflicts += syncRecord.conflictsResolved
        
        // Save updated stats
        userDefaults.set(totalSyncs, forKey: "\(prefix)_total")
        userDefaults.set(successfulSyncs, forKey: "\(prefix)_success")
        userDefaults.set(failedSyncs, forKey: "\(prefix)_failed")
        userDefaults.set(totalItemsSynced, forKey: "\(prefix)_itemsSynced")
        userDefaults.set(totalConflicts, forKey: "\(prefix)_conflicts")
        
        // Store latency values for percentile calculation
        let latencyKey = "\(prefix)_latencies"
        var latencies = userDefaults.array(forKey: latencyKey) as? [Double] ?? []
        latencies.append(syncRecord.duration)
        // Keep only last 1000 values to avoid unbounded growth
        if latencies.count > 1000 {
            latencies = Array(latencies.suffix(1000))
        }
        userDefaults.set(latencies, forKey: latencyKey)
    }
    
    private func calculateSummary(from records: [SyncRecord]) -> SyncHealthSummary {
        guard !records.isEmpty else {
            return SyncHealthSummary(
                totalSyncs: 0,
                successfulSyncs: 0,
                failedSyncs: 0,
                successRate: 1.0,
                totalItemsSynced: 0,
                conflictsResolved: 0,
                p50Latency: 0,
                p95Latency: 0,
                p99Latency: 0,
                syncRecords: []
            )
        }
        
        let successfulSyncs = records.filter { $0.success }.count
        let failedSyncs = records.count - successfulSyncs
        let successRate = Double(successfulSyncs) / Double(records.count)
        
        let totalItemsSynced = records.reduce(0) { $0 + $1.itemsSynced }
        let conflictsResolved = records.reduce(0) { $0 + $1.conflictsResolved }
        
        // Calculate latency percentiles
        let latencies = records.map { $0.duration }.sorted()
        let p50Index = Int(Double(latencies.count) * 0.5)
        let p95Index = Int(Double(latencies.count) * 0.95)
        let p99Index = Int(Double(latencies.count) * 0.99)
        
        let p50Latency = latencies[min(p50Index, latencies.count - 1)]
        let p95Latency = latencies[min(p95Index, latencies.count - 1)]
        let p99Latency = latencies[min(p99Index, latencies.count - 1)]
        
        return SyncHealthSummary(
            totalSyncs: records.count,
            successfulSyncs: successfulSyncs,
            failedSyncs: failedSyncs,
            successRate: successRate,
            totalItemsSynced: totalItemsSynced,
            conflictsResolved: conflictsResolved,
            p50Latency: p50Latency,
            p95Latency: p95Latency,
            p99Latency: p99Latency,
            syncRecords: records
        )
    }
    
    private func dateKeyForToday() -> String {
        dateKeyFormatter.string(from: Date())
    }
    
    private let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - SyncOperation

/// Types of sync operations
public enum SyncOperation: String, Codable {
    case events = "events"
    case completions = "completions"
    case awards = "awards"
    case habits = "habits"
    case full = "full"
}

// MARK: - SyncRecord

/// Individual sync operation record
public struct SyncRecord: Codable {
    let operation: SyncOperation
    let timestamp: Date
    let duration: TimeInterval
    let success: Bool
    let itemsSynced: Int
    let itemsFailed: Int
    let conflictsResolved: Int
    let error: String?
}

// MARK: - SyncHealthSummary

/// Aggregated sync health metrics
public struct SyncHealthSummary {
    public let totalSyncs: Int
    public let successfulSyncs: Int
    public let failedSyncs: Int
    public let successRate: Double
    public let totalItemsSynced: Int
    public let conflictsResolved: Int
    public let p50Latency: TimeInterval
    public let p95Latency: TimeInterval
    public let p99Latency: TimeInterval
    public let syncRecords: [SyncRecord]
}

// MARK: - SyncHealthStatus

/// Overall sync health status
public enum SyncHealthStatus {
    case healthy      // >95% success rate, low latency
    case degraded     // 80-95% success rate, moderate latency
    case unhealthy    // <80% success rate, high latency or frequent failures
}

