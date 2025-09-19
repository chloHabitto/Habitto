import Foundation
import SwiftUI

// MARK: - Data Usage Analytics
/// Tracks data usage patterns and storage optimization opportunities
@MainActor
class DataUsageAnalytics: ObservableObject {
    static let shared = DataUsageAnalytics()
    
    // MARK: - Published Properties
    @Published var isTracking = false
    @Published var currentUsage: DataUsage = DataUsage()
    @Published var usageHistory: [DataUsage] = []
    @Published var optimizationSuggestions: [OptimizationSuggestion] = []
    
    // MARK: - Private Properties
    private let usageStorage = DataUsageStorage()
    private var trackingTimer: Timer?
    private let maxHistoryEntries = 30 // Keep 30 days of history
    
    private init() {
        loadUsageHistory()
        generateOptimizationSuggestions()
    }
    
    // MARK: - Public Methods
    
    /// Start tracking data usage
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        currentUsage = DataUsage()
        
        // Start periodic tracking
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateDataUsage()
            }
        }
        
        // Initial measurement
        Task {
            await updateDataUsage()
        }
        
        print("📊 DataUsageAnalytics: Started tracking data usage")
    }
    
    /// Stop tracking data usage
    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        isTracking = false
        
        // Save final usage data
        saveCurrentUsage()
        
        print("📊 DataUsageAnalytics: Stopped tracking data usage")
    }
    
    /// Record a data operation
    func recordDataOperation(_ operation: DataOperation, size: Int64, metadata: [String: String] = [:]) {
        let operationRecord = DataOperationRecord(
            operation: operation,
            size: size,
            timestamp: Date(),
            metadata: metadata
        )
        
        currentUsage.operations.append(operationRecord)
        
        // Update usage counters
        updateUsageCounters(for: operation, size: size)
        
        print("📊 DataUsageAnalytics: Recorded \(operation.rawValue) operation - \(size) bytes")
    }
    
    /// Record storage change
    func recordStorageChange(_ change: StorageChange) {
        currentUsage.storageChanges.append(change)
        
        // Update storage metrics
        updateStorageMetrics(for: change)
        
        print("📊 DataUsageAnalytics: Recorded storage change - \(change.type.rawValue)")
    }
    
    /// Record cache operation
    func recordCacheOperation(_ operation: CacheOperation, key: String, size: Int64) {
        let cacheRecord = CacheRecord(
            operation: operation,
            key: key,
            size: size,
            timestamp: Date()
        )
        
        currentUsage.cacheOperations.append(cacheRecord)
        
        // Update cache metrics
        updateCacheMetrics(for: operation, size: size)
        
        print("📊 DataUsageAnalytics: Recorded cache \(operation.rawValue) - \(key): \(size) bytes")
    }
    
    /// Get data usage summary
    func getDataUsageSummary() -> DataUsageSummary {
        return DataUsageSummary(
            totalStorageUsed: currentUsage.totalStorageUsed,
            habitsStorageUsed: currentUsage.habitsStorageUsed,
            cacheStorageUsed: currentUsage.cacheStorageUsed,
            metadataStorageUsed: currentUsage.metadataStorageUsed,
            averageOperationSize: calculateAverageOperationSize(),
            mostFrequentOperation: getMostFrequentOperation(),
            storageGrowthRate: calculateStorageGrowthRate(),
            optimizationPotential: calculateOptimizationPotential()
        )
    }
    
    /// Get optimization recommendations
    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // Check for large unused data
        if currentUsage.unusedDataSize > 10 * 1024 * 1024 { // 10MB
            recommendations.append(OptimizationRecommendation(
                type: .cleanupUnusedData,
                priority: .high,
                description: "Remove \(formatBytes(currentUsage.unusedDataSize)) of unused data",
                potentialSavings: currentUsage.unusedDataSize
            ))
        }
        
        // Check for cache optimization
        if currentUsage.cacheStorageUsed > currentUsage.habitsStorageUsed / 2 {
            recommendations.append(OptimizationRecommendation(
                type: .optimizeCache,
                priority: .medium,
                description: "Cache is using \(formatBytes(currentUsage.cacheStorageUsed)) - consider reducing cache size",
                potentialSavings: currentUsage.cacheStorageUsed / 2
            ))
        }
        
        // Check for data compression
        if currentUsage.habitsStorageUsed > 5 * 1024 * 1024 { // 5MB
            recommendations.append(OptimizationRecommendation(
                type: .compressData,
                priority: .low,
                description: "Consider compressing habit data to reduce storage usage",
                potentialSavings: currentUsage.habitsStorageUsed / 3
            ))
        }
        
        // Check for old data cleanup
        if currentUsage.oldDataSize > 2 * 1024 * 1024 { // 2MB
            recommendations.append(OptimizationRecommendation(
                type: .cleanupOldData,
                priority: .medium,
                description: "Remove \(formatBytes(currentUsage.oldDataSize)) of old data",
                potentialSavings: currentUsage.oldDataSize
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    /// Apply optimization
    func applyOptimization(_ recommendation: OptimizationRecommendation) async {
        switch recommendation.type {
        case .cleanupUnusedData:
            await cleanupUnusedData()
        case .optimizeCache:
            await optimizeCache()
        case .compressData:
            await compressData()
        case .cleanupOldData:
            await cleanupOldData()
        }
        
        // Update usage after optimization
        await updateDataUsage()
        generateOptimizationSuggestions()
    }
    
    // MARK: - Private Methods
    
    private func updateDataUsage() async {
        // Measure current storage usage
        let storageInfo = await measureStorageUsage()
        currentUsage.totalStorageUsed = storageInfo.total
        currentUsage.habitsStorageUsed = storageInfo.habits
        currentUsage.cacheStorageUsed = storageInfo.cache
        currentUsage.metadataStorageUsed = storageInfo.metadata
        
        // Calculate derived metrics
        currentUsage.unusedDataSize = calculateUnusedDataSize()
        currentUsage.oldDataSize = calculateOldDataSize()
        currentUsage.compressionRatio = calculateCompressionRatio()
        
        // Update timestamp
        currentUsage.lastUpdated = Date()
    }
    
    private func updateUsageCounters(for operation: DataOperation, size: Int64) {
        switch operation {
        case .habitLoad:
            currentUsage.habitLoadCount += 1
            currentUsage.habitLoadSize += size
        case .habitSave:
            currentUsage.habitSaveCount += 1
            currentUsage.habitSaveSize += size
        case .habitDelete:
            currentUsage.habitDeleteCount += 1
        case .dataExport:
            currentUsage.dataExportCount += 1
            currentUsage.dataExportSize += size
        case .dataImport:
            currentUsage.dataImportCount += 1
            currentUsage.dataImportSize += size
        case .cacheRead:
            currentUsage.cacheReadCount += 1
        case .cacheWrite:
            currentUsage.cacheWriteCount += 1
        case .cacheDelete:
            currentUsage.cacheDeleteCount += 1
        }
    }
    
    private func updateStorageMetrics(for change: StorageChange) {
        switch change.type {
        case .habitAdded:
            currentUsage.habitsCount += 1
        case .habitRemoved:
            currentUsage.habitsCount = max(0, currentUsage.habitsCount - 1)
        case .dataMigrated:
            currentUsage.migrationCount += 1
        case .cacheCleared:
            currentUsage.cacheClearCount += 1
        }
    }
    
    private func updateCacheMetrics(for operation: CacheOperation, size: Int64) {
        switch operation {
        case .read:
            currentUsage.cacheReadCount += 1
        case .write:
            currentUsage.cacheWriteCount += 1
            currentUsage.cacheStorageUsed += size
        case .delete:
            currentUsage.cacheDeleteCount += 1
            currentUsage.cacheStorageUsed = max(0, currentUsage.cacheStorageUsed - size)
        }
    }
    
    private func measureStorageUsage() async -> StorageInfo {
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        
        var totalSize: Int64 = 0
        var habitsSize: Int64 = 0
        var cacheSize: Int64 = 0
        var metadataSize: Int64 = 0
        
        for (key, value) in dictionary {
            let size = estimateValueSize(value)
            totalSize += size
            
            if key.hasPrefix("Habit_") {
                habitsSize += size
            } else if key.hasPrefix("Cache_") {
                cacheSize += size
            } else if key.hasPrefix("Analytics_") || key.hasPrefix("Performance_") {
                metadataSize += size
            }
        }
        
        return StorageInfo(
            total: totalSize,
            habits: habitsSize,
            cache: cacheSize,
            metadata: metadataSize
        )
    }
    
    private func estimateValueSize(_ value: Any) -> Int64 {
        if let data = value as? Data {
            return Int64(data.count)
        } else if let string = value as? String {
            return Int64(string.utf8.count)
        } else if (value as? NSNumber) != nil {
            return Int64(MemoryLayout<NSNumber>.size)
        } else if let array = value as? [Any] {
            return Int64(array.count * 8) // Rough estimate
        } else if let dict = value as? [String: Any] {
            return Int64(dict.count * 16) // Rough estimate
        }
        return 0
    }
    
    private func calculateUnusedDataSize() -> Int64 {
        // This would analyze data that hasn't been accessed recently
        // For now, return a placeholder
        return 0
    }
    
    private func calculateOldDataSize() -> Int64 {
        // This would analyze data older than a certain threshold
        // For now, return a placeholder
        return 0
    }
    
    private func calculateCompressionRatio() -> Double {
        // This would calculate the compression ratio of stored data
        // For now, return a placeholder
        return 1.0
    }
    
    private func calculateAverageOperationSize() -> Int64 {
        guard !currentUsage.operations.isEmpty else { return 0 }
        let totalSize = currentUsage.operations.reduce(0) { $0 + $1.size }
        return totalSize / Int64(currentUsage.operations.count)
    }
    
    private func getMostFrequentOperation() -> DataOperation {
        let operationCounts = currentUsage.operations.reduce(into: [DataOperation: Int]()) { counts, operation in
            counts[operation.operation, default: 0] += 1
        }
        
        return operationCounts.max(by: { $0.value < $1.value })?.key ?? .habitLoad
    }
    
    private func calculateStorageGrowthRate() -> Double {
        guard usageHistory.count >= 2 else { return 0.0 }
        
        let recent = usageHistory.suffix(2)
        let current = recent.last?.totalStorageUsed ?? 0
        let previous = recent.first?.totalStorageUsed ?? 0
        
        guard previous > 0 else { return 0.0 }
        return Double(current - previous) / Double(previous)
    }
    
    private func calculateOptimizationPotential() -> Int64 {
        return currentUsage.unusedDataSize + currentUsage.oldDataSize
    }
    
    private func generateOptimizationSuggestions() {
        optimizationSuggestions = getOptimizationRecommendations().map { recommendation in
            OptimizationSuggestion(
                type: recommendation.type,
                priority: recommendation.priority,
                description: recommendation.description,
                potentialSavings: recommendation.potentialSavings,
                isApplied: false
            )
        }
    }
    
    private func cleanupUnusedData() async {
        // Implementation would clean up unused data
        print("📊 DataUsageAnalytics: Cleaning up unused data")
    }
    
    private func optimizeCache() async {
        // Implementation would optimize cache usage
        print("📊 DataUsageAnalytics: Optimizing cache")
    }
    
    private func compressData() async {
        // Implementation would compress data
        print("📊 DataUsageAnalytics: Compressing data")
    }
    
    private func cleanupOldData() async {
        // Implementation would clean up old data
        print("📊 DataUsageAnalytics: Cleaning up old data")
    }
    
    private func saveCurrentUsage() {
        currentUsage.lastUpdated = Date()
        usageHistory.append(currentUsage)
        
        // Keep only recent history
        if usageHistory.count > maxHistoryEntries {
            usageHistory = Array(usageHistory.suffix(maxHistoryEntries))
        }
        
        usageStorage.saveUsageHistory(usageHistory)
    }
    
    private func loadUsageHistory() {
        usageHistory = usageStorage.loadUsageHistory()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Data Usage
struct DataUsage: Codable {
    var timestamp: Date = Date()
    var lastUpdated: Date = Date()
    
    var totalStorageUsed: Int64 = 0
    var habitsStorageUsed: Int64 = 0
    var cacheStorageUsed: Int64 = 0
    var metadataStorageUsed: Int64 = 0
    
    var unusedDataSize: Int64 = 0
    var oldDataSize: Int64 = 0
    var compressionRatio: Double = 1.0
    
    var habitsCount: Int = 0
    var migrationCount: Int = 0
    var cacheClearCount: Int = 0
    
    var habitLoadCount: Int = 0
    var habitSaveCount: Int = 0
    var habitDeleteCount: Int = 0
    var dataExportCount: Int = 0
    var dataImportCount: Int = 0
    var cacheReadCount: Int = 0
    var cacheWriteCount: Int = 0
    var cacheDeleteCount: Int = 0
    
    var habitLoadSize: Int64 = 0
    var habitSaveSize: Int64 = 0
    var dataExportSize: Int64 = 0
    var dataImportSize: Int64 = 0
    
    var operations: [DataOperationRecord] = []
    var storageChanges: [StorageChange] = []
    var cacheOperations: [CacheRecord] = []
}

// MARK: - Data Operation
enum DataOperation: String, Codable, CaseIterable {
    case habitLoad = "habit_load"
    case habitSave = "habit_save"
    case habitDelete = "habit_delete"
    case dataExport = "data_export"
    case dataImport = "data_import"
    case cacheRead = "cache_read"
    case cacheWrite = "cache_write"
    case cacheDelete = "cache_delete"
}

// MARK: - Data Operation Record
struct DataOperationRecord: Codable, Identifiable {
    let id = UUID()
    let operation: DataOperation
    let size: Int64
    let timestamp: Date
    let metadata: [String: String]
}

// MARK: - Storage Change
struct StorageChange: Codable, Identifiable {
    let id = UUID()
    let type: StorageChangeType
    let timestamp: Date
    let metadata: [String: String]
}

// MARK: - Storage Change Type
enum StorageChangeType: String, Codable, CaseIterable {
    case habitAdded = "habit_added"
    case habitRemoved = "habit_removed"
    case dataMigrated = "data_migrated"
    case cacheCleared = "cache_cleared"
}

// MARK: - Cache Operation
enum CacheOperation: String, Codable, CaseIterable {
    case read = "read"
    case write = "write"
    case delete = "delete"
}

// MARK: - Cache Record
struct CacheRecord: Codable, Identifiable {
    let id = UUID()
    let operation: CacheOperation
    let key: String
    let size: Int64
    let timestamp: Date
}

// MARK: - Storage Info
struct StorageInfo {
    let total: Int64
    let habits: Int64
    let cache: Int64
    let metadata: Int64
}

// MARK: - Data Usage Summary
struct DataUsageSummary {
    let totalStorageUsed: Int64
    let habitsStorageUsed: Int64
    let cacheStorageUsed: Int64
    let metadataStorageUsed: Int64
    let averageOperationSize: Int64
    let mostFrequentOperation: DataOperation
    let storageGrowthRate: Double
    let optimizationPotential: Int64
}

// MARK: - Optimization Recommendation
struct OptimizationRecommendation {
    let type: OptimizationType
    let priority: OptimizationPriority
    let description: String
    let potentialSavings: Int64
}

// MARK: - Optimization Type
enum OptimizationType: String, Codable, CaseIterable {
    case cleanupUnusedData = "cleanup_unused_data"
    case optimizeCache = "optimize_cache"
    case compressData = "compress_data"
    case cleanupOldData = "cleanup_old_data"
}

// MARK: - Optimization Priority
enum OptimizationPriority: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

// MARK: - Optimization Suggestion
struct OptimizationSuggestion: Codable, Identifiable {
    let id = UUID()
    let type: OptimizationType
    let priority: OptimizationPriority
    let description: String
    let potentialSavings: Int64
    var isApplied: Bool
}

// MARK: - Data Usage Storage
class DataUsageStorage {
    private let userDefaults = UserDefaults.standard
    private let usageHistoryKey = "DataUsageHistory"
    
    func saveUsageHistory(_ history: [DataUsage]) {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: usageHistoryKey)
        } catch {
            print("❌ DataUsageStorage: Failed to save usage history - \(error.localizedDescription)")
        }
    }
    
    func loadUsageHistory() -> [DataUsage] {
        guard let data = userDefaults.data(forKey: usageHistoryKey) else { return [] }
        
        do {
            return try JSONDecoder().decode([DataUsage].self, from: data)
        } catch {
            print("❌ DataUsageStorage: Failed to load usage history - \(error.localizedDescription)")
            return []
        }
    }
    
    func clearUsageHistory() {
        userDefaults.removeObject(forKey: usageHistoryKey)
    }
}
