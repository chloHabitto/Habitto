import Foundation

// MARK: - UserDefaults Storage Implementation
/// UserDefaults implementation of the data storage protocol
class UserDefaultsStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let userDefaults = UserDefaults.standard
    private let habitsKey = "SavedHabits"
    private let individualHabitKeyPrefix = "Habit_"
    
    // Performance optimization: Cache loaded habits
    private var cachedHabits: [Habit]?
    private var lastSaveTime: Date = Date()
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        if immediate {
            try await performSave(data, forKey: key)
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
            // Schedule a delayed save
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                Task {
                    try? await self.performSave(data, forKey: key)
                }
            }
            return
        }
        
        try await performSave(data, forKey: key)
    }
    
    private func performSave<T: Codable>(_ data: T, forKey key: String) async throws {
        let encoded = try JSONEncoder().encode(data)
        userDefaults.set(encoded, forKey: key)
        lastSaveTime = Date()
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(forKey key: String) async throws {
        userDefaults.removeObject(forKey: key)
    }
    
    func exists(forKey key: String) async throws -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys.filter { $0.hasPrefix(prefix) }
    }
    
    // MARK: - Habit-Specific Storage Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        // Performance optimization: Only save if habits actually changed
        if let cached = cachedHabits, cached == habits && !immediate {
            return // No change, skip save
        }
        
        // Save habits as individual items for better performance
        for habit in habits {
            let key = "\(individualHabitKeyPrefix)\(habit.id.uuidString)"
            try await save(habit, forKey: key, immediate: immediate)
        }
        
        // Also save as a complete array for backward compatibility
        try await save(habits, forKey: habitsKey, immediate: immediate)
        
        cachedHabits = habits
    }
    
    func loadHabits() async throws -> [Habit] {
        // Performance optimization: Return cached result if available
        if let cached = cachedHabits {
            return cached
        }
        
        // Try to load individual habits first (newer approach)
        let individualKeys = try await keys(withPrefix: individualHabitKeyPrefix)
        if !individualKeys.isEmpty {
            var habits: [Habit] = []
            for key in individualKeys {
                if let habit: Habit = try await load(Habit.self, forKey: key) {
                    habits.append(habit)
                }
            }
            cachedHabits = habits
            return habits
        }
        
        // Fallback to loading the complete array (legacy approach)
        if let habits: [Habit] = try await load([Habit].self, forKey: habitsKey) {
            cachedHabits = habits
            return habits
        }
        
        return []
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
        let individualKeys = try await keys(withPrefix: individualHabitKeyPrefix)
        for key in individualKeys {
            try await delete(forKey: key)
        }
        try await delete(forKey: habitsKey)
        cachedHabits = nil
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cachedHabits = nil
    }
    
    func getCacheStatus() -> (isCached: Bool, count: Int) {
        return (cachedHabits != nil, cachedHabits?.count ?? 0)
    }
}
