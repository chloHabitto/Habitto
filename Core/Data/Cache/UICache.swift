import Foundation
import OSLog

// MARK: - UI Cache Protocol

/// Protocol for UI cache operations
protocol UICache {
    /// Get cached data for a key
    func get<T: Codable>(_ key: String, as type: T.Type) -> T?
    
    /// Set cached data for a key
    func set<T: Encodable>(_ key: String, value: T)
    
    /// Invalidate cached data for a key
    func invalidate(_ key: String)
    
    /// Clear all cached data
    func clear()
    
    /// Check if data exists in cache
    func exists(_ key: String) -> Bool
    
    /// Get cache statistics
    func getStats() -> CacheStats
}

// MARK: - Default UI Cache Implementation

/// Default implementation using NSCache for memory and file system for persistence
final class DefaultUICache: UICache {
    
    // MARK: - Properties
    
    private let memoryCache: NSCache<NSString, NSData>
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let logger = Logger(subsystem: "com.habitto.app", category: "UICache")
    
    // Statistics
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var writeCount: Int = 0
    private var invalidateCount: Int = 0
    
    // MARK: - Initialization
    
    init(cacheName: String = "UICache") {
        // Configure memory cache
        self.memoryCache = NSCache<NSString, NSData>()
        memoryCache.name = cacheName
        memoryCache.countLimit = 100 // Maximum 100 items in memory
        memoryCache.totalCostLimit = 10 * 1024 * 1024 // 10 MB memory limit
        
        // Setup cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("uicache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        logger.info("🔧 UICache: Initialized with directory: \(self.cacheDirectory.path)")
    }
    
    // MARK: - UICache Implementation
    
    func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let cacheKey = NSString(string: key)
        
        // Try memory cache first
        if let data = memoryCache.object(forKey: cacheKey) {
            hitCount += 1
            if let decoded = try? JSONDecoder().decode(type, from: data as Data) {
                logger.debug("📥 UICache: Memory hit for key: \(key)")
                return decoded
            }
        }
        
        // Try disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.sanitizedForFilename)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                if let decoded = try? JSONDecoder().decode(type, from: data) {
                    // Store in memory cache for next time
                    memoryCache.setObject(data as NSData, forKey: cacheKey)
                    hitCount += 1
                    logger.debug("📥 UICache: Disk hit for key: \(key)")
                    return decoded
                }
            } catch {
                logger.warning("⚠️ UICache: Failed to read from disk for key: \(key): \(error.localizedDescription)")
                // Remove corrupted file
                try? fileManager.removeItem(at: fileURL)
            }
        }
        
        missCount += 1
        logger.debug("📭 UICache: Miss for key: \(key)")
        return nil
    }
    
    func set<T: Encodable>(_ key: String, value: T) {
        let cacheKey = NSString(string: key)
        
        do {
            let data = try JSONEncoder().encode(value)
            let nsData = data as NSData
            
            // Store in memory cache
            memoryCache.setObject(nsData, forKey: cacheKey)
            
            // Store on disk
            let fileURL = cacheDirectory.appendingPathComponent(key.sanitizedForFilename)
            try data.write(to: fileURL)
            
            writeCount += 1
            logger.debug("💾 UICache: Stored key: \(key)")
            
        } catch {
            logger.error("❌ UICache: Failed to store key: \(key): \(error.localizedDescription)")
        }
    }
    
    func invalidate(_ key: String) {
        let cacheKey = NSString(string: key)
        
        // Remove from memory cache
        memoryCache.removeObject(forKey: cacheKey)
        
        // Remove from disk
        let fileURL = cacheDirectory.appendingPathComponent(key.sanitizedForFilename)
        try? fileManager.removeItem(at: fileURL)
        
        invalidateCount += 1
        logger.debug("🗑️ UICache: Invalidated key: \(key)")
    }
    
    func clear() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
        } catch {
            logger.warning("⚠️ UICache: Failed to clear disk cache: \(error.localizedDescription)")
        }
        
        // Reset statistics
        hitCount = 0
        missCount = 0
        writeCount = 0
        invalidateCount = 0
        
        logger.info("🧹 UICache: Cleared all cached data")
    }
    
    func exists(_ key: String) -> Bool {
        let cacheKey = NSString(string: key)
        
        // Check memory cache
        if memoryCache.object(forKey: cacheKey) != nil {
            return true
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.sanitizedForFilename)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func getStats() -> CacheStats {
        return CacheStats(
            hitCount: hitCount,
            missCount: missCount,
            writeCount: writeCount,
            invalidateCount: invalidateCount,
            memoryItemCount: memoryCache.countLimit,
            diskItemCount: getDiskItemCount(),
            hitRate: calculateHitRate()
        )
    }
    
    // MARK: - Private Methods
    
    private func getDiskItemCount() -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
    
    private func calculateHitRate() -> Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0.0 }
        return Double(hitCount) / Double(total)
    }
}

// MARK: - Cache Keys

/// Centralized cache key management
enum CacheKeys {
    
    // MARK: - Habit Cache Keys
    
    static func habits(for userId: String) -> String {
        return "habits_\(userId)"
    }
    
    static func habit(id: String, userId: String) -> String {
        return "habit_\(id)_\(userId)"
    }
    
    static func habitsForDate(_ date: Date, userId: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        return "habits_date_\(dateKey)_\(userId)"
    }
    
    // MARK: - Completion Cache Keys
    
    static func completion(habitId: String, date: Date, userId: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        return "completion_\(habitId)_\(dateKey)_\(userId)"
    }
    
    static func completionsForHabit(_ habitId: String, from startDate: Date, to endDate: Date, userId: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startKey = dateFormatter.string(from: startDate)
        let endKey = dateFormatter.string(from: endDate)
        return "completions_\(habitId)_\(startKey)_to_\(endKey)_\(userId)"
    }
    
    // MARK: - XP Cache Keys
    
    static func xpState(for userId: String) -> String {
        return "xp_state_\(userId)"
    }
    
    static func xpHistory(limit: Int, userId: String) -> String {
        return "xp_history_\(limit)_\(userId)"
    }
    
    // MARK: - Streak Cache Keys
    
    static func streak(habitId: String, userId: String) -> String {
        return "streak_\(habitId)_\(userId)"
    }
    
    // MARK: - User Settings Cache Keys
    
    static func userSettings(for userId: String) -> String {
        return "user_settings_\(userId)"
    }
    
    // MARK: - Migration Cache Keys
    
    static func migrationState(for userId: String) -> String {
        return "migration_state_\(userId)"
    }
}

// MARK: - Cache Stats

struct CacheStats {
    let hitCount: Int
    let missCount: Int
    let writeCount: Int
    let invalidateCount: Int
    let memoryItemCount: Int
    let diskItemCount: Int
    let hitRate: Double
    
    var totalRequests: Int {
        return hitCount + missCount
    }
    
    var hitRatePercentage: Int {
        return Int(hitRate * 100)
    }
}

// MARK: - String Extension

extension String {
    /// Sanitize string for use as filename
    var sanitizedForFilename: String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - Cache Manager

/// High-level cache manager for UI components
final class UICacheManager {
    
    static let shared = UICacheManager()
    
    private let cache: UICache
    private let logger = Logger(subsystem: "com.habitto.app", category: "UICacheManager")
    
    private init(cache: UICache = DefaultUICache()) {
        self.cache = cache
        
        // Clear cache on app launch if feature flag is disabled
        if !MigrationFeatureFlags.uiCacheEnabled {
            cache.clear()
        }
        
        logger.info("🔧 UICacheManager: Initialized with cache enabled: \(MigrationFeatureFlags.uiCacheEnabled)")
    }
    
    // MARK: - Public Methods
    
    /// Get cached habits for immediate UI display
    func getCachedHabits(for userId: String) -> [Habit] {
        guard MigrationFeatureFlags.uiCacheEnabled else { return [] }
        
        return cache.get(CacheKeys.habits(for: userId), as: [Habit].self) ?? []
    }
    
    /// Cache habits data
    func cacheHabits(_ habits: [Habit], for userId: String) {
        guard MigrationFeatureFlags.uiCacheEnabled else { return }
        
        cache.set(CacheKeys.habits(for: userId), value: habits)
    }
    
    /// Get cached habit for immediate UI display
    func getCachedHabit(id: String, userId: String) -> Habit? {
        guard MigrationFeatureFlags.uiCacheEnabled else { return nil }
        
        return cache.get(CacheKeys.habit(id: id, userId: userId), as: Habit.self)
    }
    
    /// Cache habit data
    func cacheHabit(_ habit: Habit, userId: String) {
        guard MigrationFeatureFlags.uiCacheEnabled else { return }
        
        cache.set(CacheKeys.habit(id: habit.id.uuidString, userId: userId), value: habit)
    }
    
    /// Invalidate habit cache
    func invalidateHabit(id: String, userId: String) {
        cache.invalidate(CacheKeys.habit(id: id, userId: userId))
        cache.invalidate(CacheKeys.habits(for: userId))
    }
    
    /// Invalidate all user data cache
    func invalidateUserCache(userId: String) {
        // This is a simplified approach - in a real implementation,
        // you might want to track all keys per user for efficient invalidation
        logger.info("🗑️ UICacheManager: Invalidating all cache for user \(userId)")
        cache.clear()
    }
    
    /// Get cache statistics
    func getCacheStats() -> CacheStats {
        return cache.getStats()
    }
    
    /// Clear all cache (for debugging/testing)
    func clearAllCache() {
        logger.info("🧹 UICacheManager: Clearing all cache")
        cache.clear()
    }
}
