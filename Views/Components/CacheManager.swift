import Foundation
import UIKit

// MARK: - Key Wrapper
private class KeyWrapper: NSObject {
    let key: AnyHashable
    
    init(_ key: AnyHashable) {
        self.key = key
        super.init()
    }
    
    override var hash: Int {
        return key.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? KeyWrapper else { return false }
        return key == other.key
    }
}

// MARK: - Generic Cache Manager
class CacheManager<Key: Hashable, Value> {
    
    // MARK: - Properties
    private let cache = NSCache<NSObject, CachedItem<Value>>()
    private let maxCacheSize: Int
    private let expirationInterval: TimeInterval
    private let cleanupInterval: TimeInterval
    
    // MARK: - Initialization
    init(maxCacheSize: Int = 100, expirationInterval: TimeInterval = 300, cleanupInterval: TimeInterval = 60) {
        self.maxCacheSize = maxCacheSize
        self.expirationInterval = expirationInterval
        self.cleanupInterval = cleanupInterval
        
        // Configure cache behavior
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = maxCacheSize * 1024 * 1024 // 1MB per item max
        
        // Set up memory pressure handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Set up automatic cleanup timer
        startCleanupTimer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Set a value in the cache
    func set(_ value: Value, forKey key: Key) {
        let cachedItem = CachedItem(value: value, timestamp: Date())
        let nsKey = KeyWrapper(key)
        cache.setObject(cachedItem, forKey: nsKey)
        
        // Check if we need to evict items
        if cache.totalCostLimit > maxCacheSize * 1024 * 1024 {
            evictLeastRecentlyUsed()
        }
    }
    
    /// Get a value from the cache
    func get(forKey key: Key) -> Value? {
        let nsKey = KeyWrapper(key)
        guard let cachedItem = cache.object(forKey: nsKey) else { return nil }
        
        // Check if item has expired
        if Date().timeIntervalSince(cachedItem.timestamp) > expirationInterval {
            cache.removeObject(forKey: nsKey)
            return nil
        }
        
        // Update access timestamp for LRU
        cachedItem.lastAccess = Date()
        return cachedItem.value
    }
    
    /// Remove a specific item from cache
    func remove(forKey key: Key) {
        let nsKey = KeyWrapper(key)
        cache.removeObject(forKey: nsKey)
    }
    
    /// Clear all cached items
    func clear() {
        cache.removeAllObjects()
    }
    
    /// Get current cache size
    var currentSize: Int {
        // NSCache doesn't expose totalCost, so we'll track it manually
        return 0 // Placeholder - would need manual tracking
    }
    
    /// Get current cache count
    var currentCount: Int {
        // NSCache doesn't expose count, so we'll track it manually
        return 0 // Placeholder - would need manual tracking
    }
    
    // MARK: - Private Methods
    
    private func evictLeastRecentlyUsed() {
        // NSCache doesn't expose allObjects, so we can't implement LRU eviction
        // Instead, we'll clear the entire cache when memory pressure is detected
        clear()
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.cleanupExpiredItems()
        }
    }
    
    private func cleanupExpiredItems() {
        // NSCache doesn't expose allObjects, so we can't iterate through items
        // Expired items will be handled when they're accessed via get() method
        // This is a limitation of NSCache - we rely on lazy expiration
    }
    
    @objc private func handleMemoryWarning() {
        // Clear cache on memory warning
        clear()
    }
}

// MARK: - Cached Item
private class CachedItem<T> {
    let value: T
    let timestamp: Date
    var lastAccess: Date
    
    init(value: T, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
        self.lastAccess = timestamp
    }
}

// MARK: - Cache Extensions
extension CacheManager {
    
    /// Convenience method for setting with automatic key generation
    func set(_ value: Value, forKey key: Key, cost: Int = 1) {
        let cachedItem = CachedItem(value: value, timestamp: Date())
        let nsKey = KeyWrapper(key)
        cache.setObject(cachedItem, forKey: nsKey, cost: cost)
    }
    
    /// Check if cache contains a key
    func contains(key: Key) -> Bool {
        return get(forKey: key) != nil
    }
    
    /// Get all valid (non-expired) keys
    var validKeys: [Key] {
        // Since we can't directly access keys from cached items,
        // this method is not fully implementable with the current NSCache approach
        // Returning empty array as fallback
        return []
    }
}
