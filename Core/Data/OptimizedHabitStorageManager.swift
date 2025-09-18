import Foundation

// MARK: - Optimized Habit Storage Manager
class OptimizedHabitStorageManager {
    static let shared = OptimizedHabitStorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let habitPrefix = "habit_"
    private let habitIdsKey = "habit_ids"
    private let maxHistoryDays = 365 // Cap history to 1 year
    
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [UUID: Habit] = [:]
    private var lastSaveTime: Date = Date()
    private let saveDebounceInterval: TimeInterval = 0.5
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Save habits with individual storage and history capping
    func saveHabits(_ habits: [Habit], immediate: Bool = false) {
        if immediate {
            performSave(habits)
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                self.performSave(habits)
            }
            return
        }
        
        performSave(habits)
    }
    
    /// Load all habits with individual retrieval
    func loadHabits() -> [Habit] {
        // Return cached habits if available
        if !cachedHabits.isEmpty {
            return Array(cachedHabits.values)
        }
        
        // Load habit IDs
        guard let habitIdsData = userDefaults.data(forKey: habitIdsKey),
              let habitIds = try? JSONDecoder().decode([UUID].self, from: habitIdsData) else {
            print("⚠️ OptimizedHabitStorageManager: No habit IDs found")
            return []
        }
        
        // Load individual habits
        var loadedHabits: [Habit] = []
        for habitId in habitIds {
            if let habit = loadHabit(by: habitId) {
                loadedHabits.append(habit)
                cachedHabits[habitId] = habit
            }
        }
        
        print("✅ OptimizedHabitStorageManager: Loaded \(loadedHabits.count) habits individually")
        return loadedHabits
    }
    
    /// Load a specific habit by ID
    func loadHabit(by id: UUID) -> Habit? {
        // Check cache first
        if let cachedHabit = cachedHabits[id] {
            return cachedHabit
        }
        
        // Load from UserDefaults
        let key = "\(habitPrefix)\(id.uuidString)"
        guard let data = userDefaults.data(forKey: key),
              let habit = try? JSONDecoder().decode(Habit.self, from: data) else {
            return nil
        }
        
        // Cache the loaded habit
        cachedHabits[id] = habit
        return habit
    }
    
    /// Save a single habit
    func saveHabit(_ habit: Habit) {
        let key = "\(habitPrefix)\(habit.id.uuidString)"
        
        // Cap history length before saving
        let cappedHabit = capHabitHistory(habit)
        
        if let encoded = try? JSONEncoder().encode(cappedHabit) {
            userDefaults.set(encoded, forKey: key)
            cachedHabits[habit.id] = cappedHabit
            print("✅ OptimizedHabitStorageManager: Saved habit '\(habit.name)' individually")
        }
    }
    
    /// Delete a habit
    func deleteHabit(by id: UUID) {
        let key = "\(habitPrefix)\(id.uuidString)"
        userDefaults.removeObject(forKey: key)
        cachedHabits.removeValue(forKey: id)
        
        // Update habit IDs list
        updateHabitIdsList()
        print("✅ OptimizedHabitStorageManager: Deleted habit with ID: \(id)")
    }
    
    /// Clear all habits
    func clearAllHabits() {
        // Get all habit IDs
        guard let habitIdsData = userDefaults.data(forKey: habitIdsKey),
              let habitIds = try? JSONDecoder().decode([UUID].self, from: habitIdsData) else {
            return
        }
        
        // Remove individual habit entries
        for habitId in habitIds {
            let key = "\(habitPrefix)\(habitId.uuidString)"
            userDefaults.removeObject(forKey: key)
        }
        
        // Clear habit IDs list
        userDefaults.removeObject(forKey: habitIdsKey)
        cachedHabits.removeAll()
        
        print("✅ OptimizedHabitStorageManager: Cleared all habits")
    }
    
    /// Clear cache
    func clearCache() {
        cachedHabits.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func performSave(_ habits: [Habit]) {
        // Check if habits actually changed
        let currentHabitIds = Set(cachedHabits.keys)
        let newHabitIds = Set(habits.map { $0.id })
        
        if currentHabitIds == newHabitIds {
            // Check if any habit content changed
            var hasChanges = false
            for habit in habits {
                if let cached = cachedHabits[habit.id], cached != habit {
                    hasChanges = true
                    break
                }
            }
            
            if !hasChanges {
                return // No changes, skip save
            }
        }
        
        // Save each habit individually
        for habit in habits {
            saveHabit(habit)
        }
        
        // Update habit IDs list
        updateHabitIdsList(with: habits.map { $0.id })
        
        lastSaveTime = Date()
        print("✅ OptimizedHabitStorageManager: Saved \(habits.count) habits individually")
    }
    
    private func updateHabitIdsList(with habitIds: [UUID]? = nil) {
        let ids: [UUID]
        
        if let providedIds = habitIds {
            ids = providedIds
        } else {
            // Load current habit IDs
            guard let habitIdsData = userDefaults.data(forKey: habitIdsKey),
                  let currentIds = try? JSONDecoder().decode([UUID].self, from: habitIdsData) else {
                return
            }
            ids = currentIds
        }
        
        // Save updated habit IDs list
        if let encoded = try? JSONEncoder().encode(ids) {
            userDefaults.set(encoded, forKey: habitIdsKey)
        }
    }
    
    /// Cap habit history to prevent unlimited growth
    private func capHabitHistory(_ habit: Habit) -> Habit {
        var cappedHabit = habit
        
        // Cap completion history
        if cappedHabit.completionHistory.count > maxHistoryDays {
            let sortedKeys = cappedHabit.completionHistory.keys.sorted(by: >)
            let keysToRemove = Array(sortedKeys.dropFirst(maxHistoryDays))
            
            for key in keysToRemove {
                cappedHabit.completionHistory.removeValue(forKey: key)
            }
            
            print("🔧 OptimizedHabitStorageManager: Capped completion history for '\(habit.name)' to \(maxHistoryDays) days")
        }
        
        // Cap difficulty history
        if cappedHabit.difficultyHistory.count > maxHistoryDays {
            let sortedKeys = cappedHabit.difficultyHistory.keys.sorted(by: >)
            let keysToRemove = Array(sortedKeys.dropFirst(maxHistoryDays))
            
            for key in keysToRemove {
                cappedHabit.difficultyHistory.removeValue(forKey: key)
            }
            
            print("🔧 OptimizedHabitStorageManager: Capped difficulty history for '\(habit.name)' to \(maxHistoryDays) days")
        }
        
        // Cap actual usage history (for habit breaking)
        if cappedHabit.actualUsage.count > maxHistoryDays {
            let sortedKeys = cappedHabit.actualUsage.keys.sorted(by: >)
            let keysToRemove = Array(sortedKeys.dropFirst(maxHistoryDays))
            
            for key in keysToRemove {
                cappedHabit.actualUsage.removeValue(forKey: key)
            }
            
            print("🔧 OptimizedHabitStorageManager: Capped actual usage history for '\(habit.name)' to \(maxHistoryDays) days")
        }
        
        return cappedHabit
    }
    
    // MARK: - Migration Support
    
    /// Migrate from old array-based storage to individual storage
    func migrateFromArrayStorage() {
        let oldKey = "SavedHabits"
        
        guard let data = userDefaults.data(forKey: oldKey),
              let oldHabits = try? JSONDecoder().decode([Habit].self, from: data) else {
            print("ℹ️ OptimizedHabitStorageManager: No old habits found to migrate")
            return
        }
        
        print("🔄 OptimizedHabitStorageManager: Migrating \(oldHabits.count) habits from array storage...")
        
        // Save each habit individually
        for habit in oldHabits {
            saveHabit(habit)
        }
        
        // Update habit IDs list
        updateHabitIdsList(with: oldHabits.map { $0.id })
        
        // Remove old array storage
        userDefaults.removeObject(forKey: oldKey)
        
        print("✅ OptimizedHabitStorageManager: Migration completed")
    }
    
    // MARK: - Performance Monitoring
    
    /// Get storage statistics
    func getStorageStats() -> (totalHabits: Int, totalKeys: Int, cacheSize: Int) {
        let totalHabits = cachedHabits.count
        let totalKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(habitPrefix) }.count
        let cacheSize = cachedHabits.count
        
        return (totalHabits: totalHabits, totalKeys: totalKeys, cacheSize: cacheSize)
    }
    
    /// Clean up orphaned habit entries
    func cleanupOrphanedEntries() {
        guard let habitIdsData = userDefaults.data(forKey: habitIdsKey),
              let habitIds = try? JSONDecoder().decode([UUID].self, from: habitIdsData) else {
            return
        }
        
        let validIds = Set(habitIds)
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        var orphanedKeys: [String] = []
        for key in allKeys {
            if key.hasPrefix(habitPrefix) {
                let habitIdString = String(key.dropFirst(habitPrefix.count))
                if let habitId = UUID(uuidString: habitIdString),
                   !validIds.contains(habitId) {
                    orphanedKeys.append(key)
                }
            }
        }
        
        for key in orphanedKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        if !orphanedKeys.isEmpty {
            print("🧹 OptimizedHabitStorageManager: Cleaned up \(orphanedKeys.count) orphaned entries")
        }
    }
}

// MARK: - Convenience Extensions
extension OptimizedHabitStorageManager {
    /// Check if migration is needed
    var needsMigration: Bool {
        return userDefaults.data(forKey: "SavedHabits") != nil && userDefaults.data(forKey: habitIdsKey) == nil
    }
    
    /// Perform migration if needed
    func migrateIfNeeded() {
        if needsMigration {
            migrateFromArrayStorage()
        }
    }
}
