import Foundation

// MARK: - UserDefaults Storage Implementation
/// UserDefaults implementation of the data storage protocol with atomic writes
class UserDefaultsStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let userDefaults = UserDefaultsWrapper.shared
    private let habitsKey = "SavedHabits"
    private let individualHabitKeyPrefix = "Habit_"
    private let backgroundQueue = BackgroundQueueManager.shared
    private let atomicWriter = AtomicFileWriter()
    private let migrationManager = DataMigrationManager.shared
    
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
    private var lastSaveTime: Date = Date()
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        if immediate {
            try await performAtomicSave(data, forKey: key)
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
            // Schedule a delayed save - no weak self needed since we're @MainActor
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(saveDebounceInterval * 1_000_000_000))
                try? await self.performAtomicSave(data, forKey: key)
            }
            return
        }
        
        try await performAtomicSave(data, forKey: key)
    }
    
    private func performAtomicSave<T: Codable>(_ data: T, forKey key: String) async throws {
        try await backgroundQueue.executeSerial {
            // Use atomic file writer for critical data
            let fileURL = self.getFileURL(for: key)
            try self.atomicWriter.writeAtomically(data, to: fileURL)
            
            // Also update UserDefaults for backward compatibility
            try self.userDefaults.setCodable(data, forKey: key)
            
            // Data saved successfully
            
            Task { @MainActor in
                self.lastSaveTime = Date()
            }
        }
    }
    
    private func performSave<T: Codable>(_ data: T, forKey key: String) async throws {
        try await backgroundQueue.executeSerial {
            try self.userDefaults.setCodable(data, forKey: key)
            Task { @MainActor in
                self.lastSaveTime = Date()
            }
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        return try await backgroundQueue.execute {
            // First try to load from atomic file
            let fileURL = self.getFileURL(for: key)
            if let data = try? self.atomicWriter.readObject(type, from: fileURL) {
                return data
            }
            
            // Fallback to UserDefaults
            return try self.userDefaults.getCodable(type, forKey: key)
        }
    }
    
    func delete(forKey key: String) async throws {
        try await backgroundQueue.execute {
            // Delete from atomic file
            let fileURL = self.getFileURL(for: key)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            // Also remove from UserDefaults
            self.userDefaults.remove(forKey: key)
        }
    }
    
    func exists(forKey key: String) async throws -> Bool {
        return try await backgroundQueue.execute {
            self.userDefaults.exists(forKey: key)
        }
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        return try await backgroundQueue.execute {
            self.userDefaults.getKeys(withPrefix: prefix)
        }
    }
    
    // MARK: - Habit-Specific Storage Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        // Performance optimization: Only save if habits actually changed
        if let cached = cachedHabits, cached == habits && !immediate {
            return // No change, skip save
        }
        
        // Use background queue for heavy operations
        try await backgroundQueue.executeSerial {
            // Save habits as individual items for better performance
            for habit in habits {
                let key = "\(self.individualHabitKeyPrefix)\(habit.id.uuidString)"
                let encoded = try JSONEncoder().encode(habit)
                self.userDefaults.set(encoded, forKey: key)
            }
            
            // Also save as a complete array for backward compatibility
            let encodedHabits = try JSONEncoder().encode(habits)
            self.userDefaults.set(encodedHabits, forKey: self.habitsKey)
        }
        
        // Update cache on main thread
        cachedHabits = habits
    }
    
    func loadHabits() async throws -> [Habit] {
        // Migration is handled by HabitStore, not here
        
        // Performance optimization: Return cached result if available
        if let cached = cachedHabits {
            return cached
        }
        
        // Use background queue for heavy operations
        let habits = try await backgroundQueue.execute {
            // Always prioritize the complete array as the source of truth
            if let habits: [Habit] = try? self.userDefaults.getCodable([Habit].self, forKey: self.habitsKey) {
                return habits
            }
            
            // Fallback to loading individual habits (for migration purposes)
            let individualKeys = self.userDefaults.getKeys(withPrefix: self.individualHabitKeyPrefix)
            
            if !individualKeys.isEmpty {
                var habits: [Habit] = []
                for key in individualKeys {
                    if let habit: Habit = try? self.userDefaults.getCodable(Habit.self, forKey: key) {
                        habits.append(habit)
                    }
                }
                return habits
            }
            
            return []
        }
        
        // Update cache on main thread
        cachedHabits = habits
        return habits
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        let key = "\(individualHabitKeyPrefix)\(habit.id.uuidString)"
        try await save(habit, forKey: key, immediate: immediate)
        
        // Update cache
        if var cached = cachedHabits {
            if let index = cached.firstIndex(where: { $0.id == habit.id }) {
                cached[index] = habit
            } else {
                cached.append(habit)
            }
            cachedHabits = cached
        }
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        let key = "\(individualHabitKeyPrefix)\(id.uuidString)"
        return try await load(Habit.self, forKey: key)
    }
    
    func deleteHabit(id: UUID) async throws {
        let key = "\(individualHabitKeyPrefix)\(id.uuidString)"
        try await delete(forKey: key)
        
        // Update cache
        if var cached = cachedHabits {
            cached.removeAll { $0.id == id }
            cachedHabits = cached
        }
    }
    
    func clearAllHabits() async throws {
        try await backgroundQueue.executeSerial {
            let individualKeys = self.userDefaults.getKeys(withPrefix: self.individualHabitKeyPrefix)
            
            for key in individualKeys {
                self.userDefaults.remove(forKey: key)
            }
            self.userDefaults.remove(forKey: self.habitsKey)
        }
        
        // Update cache on main thread
        cachedHabits = nil
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cachedHabits = nil
    }
    
    func getCacheStatus() -> (isCached: Bool, count: Int) {
        return (cachedHabits != nil, cachedHabits?.count ?? 0)
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets the file URL for atomic storage
    private func getFileURL(for key: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let atomicStorageDirectory = documentsPath.appendingPathComponent("AtomicStorage")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: atomicStorageDirectory, withIntermediateDirectories: true)
        
        return atomicStorageDirectory.appendingPathComponent("\(key).json")
    }
}
