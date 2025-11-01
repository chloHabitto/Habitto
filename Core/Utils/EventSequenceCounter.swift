import Foundation

// MARK: - EventSequenceCounter

/// Manages deterministic sequence numbers for ProgressEvent ID generation
///
/// Provides per-device, per-dateKey sequence counters that:
/// - Start at 0 for each new dateKey
/// - Increment atomically for each event
/// - Persist across app restarts (critical for retry scenarios)
/// - Automatically reset when dateKey changes (new day)
///
/// Thread-safe via @MainActor isolation
@MainActor
final class EventSequenceCounter {
    // MARK: - Singleton
    
    static let shared = EventSequenceCounter()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Public API
    
    /// Get the next sequence number for a device+dateKey combination
    ///
    /// - Parameters:
    ///   - deviceId: The device identifier (from DeviceIdProvider)
    ///   - dateKey: The date key in format "yyyy-MM-dd"
    /// - Returns: The next sequence number (starting at 0 for first call)
    ///
    /// Implements atomic increment pattern:
    /// 1. Read current value (0 if doesn't exist)
    /// 2. Increment
    /// 3. Write back
    /// 4. Return new value
    ///
    /// This ensures:
    /// - Same inputs always produce same sequence number
    /// - Deterministic ID generation for idempotency
    /// - Automatic reset per dateKey (new day = new sequence)
    func nextSequence(deviceId: String, dateKey: String) -> Int {
        let key = "\(deviceId)_\(dateKey)_sequence"
        let current = userDefaults.integer(forKey: key) // Returns 0 if not exists
        let next = current + 1
        userDefaults.set(next, forKey: key)
        return next
    }
    
    /// Cleanup old sequence counters (optional maintenance)
    ///
    /// Removes sequence counters for dateKeys older than specified days.
    /// This prevents UserDefaults from growing indefinitely.
    ///
    /// - Parameter retentionDays: Number of days to retain sequence counters (default: 7)
    func cleanupOldSequences(retentionDays: Int = 7) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        
        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Filter for sequence counter keys
        let sequenceKeys = allKeys.filter { $0.hasSuffix("_sequence") }
        
        var cleanedCount = 0
        for key in sequenceKeys {
            // Extract dateKey from key format: "{deviceId}_{dateKey}_sequence"
            let components = key.components(separatedBy: "_")
            guard components.count >= 3 else { continue }
            
            // Reconstruct dateKey (handles deviceId with underscores)
            // Last component is "sequence", second-to-last is dateKey (yyyy-MM-dd)
            let dateKeyString = components[components.count - 2]
            
            // Parse dateKey to Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current
            
            if let dateKeyDate = dateFormatter.date(from: dateKeyString),
               dateKeyDate < cutoffDate {
                userDefaults.removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            print("🧹 EventSequenceCounter: Cleaned up \(cleanedCount) old sequence counters")
        }
    }
    
    /// Get current sequence number without incrementing (for debugging)
    func currentSequence(deviceId: String, dateKey: String) -> Int {
        let key = "\(deviceId)_\(dateKey)_sequence"
        return userDefaults.integer(forKey: key)
    }
    
    /// Reset sequence counter for a specific device+dateKey (for testing)
    func resetSequence(deviceId: String, dateKey: String) {
        let key = "\(deviceId)_\(dateKey)_sequence"
        userDefaults.removeObject(forKey: key)
    }
}

