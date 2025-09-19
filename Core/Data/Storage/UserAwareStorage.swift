import Foundation

// MARK: - User-Aware Storage Wrapper
/// Wraps any storage implementation to provide user-specific data isolation
class UserAwareStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let baseStorage: any HabitStorageProtocol
    private let authManager = AuthenticationManager.shared
    
    // Cache for current user's data
    private var cachedHabits: [Habit]?
    private var currentUserId: String?
    
    init(baseStorage: any HabitStorageProtocol) {
        self.baseStorage = baseStorage
    }
    
    // MARK: - User ID Management
    
    @MainActor
    private func getCurrentUserId() -> String {
        // Get current user ID from authentication manager
        if let user = authManager.currentUser {
            return user.uid
        }
        
        // Fallback to guest user ID if no authenticated user
        return "guest_user"
    }
    
    private func getUserSpecificKey(_ baseKey: String) async -> String {
        let userId = await getCurrentUserId()
        return "\(userId)_\(baseKey)"
    }
    
    private func clearCacheIfUserChanged() {
        Task { @MainActor in
            let currentUserId = await getCurrentUserId()
            if self.currentUserId != currentUserId {
                self.cachedHabits = nil
                self.currentUserId = currentUserId
            }
        }
    }
    
    // MARK: - HabitStorageProtocol Implementation
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        clearCacheIfUserChanged()
        
        // Use user-specific key for habits
        let userKey = await getUserSpecificKey("SavedHabits")
        
        // Save to base storage with user-specific key
        try await baseStorage.save(habits, forKey: userKey, immediate: immediate)
        
        // Update cache
        cachedHabits = habits
    }
    
    func loadHabits() async throws -> [Habit] {
        clearCacheIfUserChanged()
        
        // Return cached data if available
        if let cached = cachedHabits {
            return cached
        }
        
        // Load from base storage with user-specific key
        let userKey = await getUserSpecificKey("SavedHabits")
        let habits: [Habit] = try await baseStorage.load([Habit].self, forKey: userKey) ?? []
        
        // Update cache
        cachedHabits = habits
        return habits
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        clearCacheIfUserChanged()
        
        // Load current habits
        var habits = try await loadHabits()
        
        // Update or add habit
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
        
        // Save updated habits
        try await saveHabits(habits, immediate: immediate)
    }
    
    func deleteHabit(id: UUID) async throws {
        clearCacheIfUserChanged()
        
        // Load current habits
        var habits = try await loadHabits()
        
        // Remove habit
        habits.removeAll { $0.id == id }
        
        // Save updated habits
        try await saveHabits(habits, immediate: true)
    }
    
    func clearAllHabits() async throws {
        clearCacheIfUserChanged()
        
        // Clear habits for current user
        let userKey = await getUserSpecificKey("SavedHabits")
        try await baseStorage.save([Habit](), forKey: userKey, immediate: true)
        
        // Clear cache
        cachedHabits = []
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        clearCacheIfUserChanged()
        
        // Load all habits and find the one with matching ID
        let habits = try await loadHabits()
        return habits.first { $0.id == id }
    }
    
    func exists(forKey key: String) async throws -> Bool {
        clearCacheIfUserChanged()
        let userKey = await getUserSpecificKey(key)
        return try await baseStorage.exists(forKey: userKey)
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        clearCacheIfUserChanged()
        let userPrefix = await getUserSpecificKey(prefix)
        return try await baseStorage.keys(withPrefix: userPrefix)
    }
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        clearCacheIfUserChanged()
        let userKey = await getUserSpecificKey(key)
        try await baseStorage.save(data, forKey: userKey, immediate: immediate)
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        clearCacheIfUserChanged()
        let userKey = await getUserSpecificKey(key)
        return try await baseStorage.load(type, forKey: userKey)
    }
    
    func load<T: Codable>(forKey key: String) async throws -> T? {
        clearCacheIfUserChanged()
        let userKey = await getUserSpecificKey(key)
        return try await baseStorage.load(T.self, forKey: userKey)
    }
    
    func delete(forKey key: String) async throws {
        clearCacheIfUserChanged()
        let userKey = await getUserSpecificKey(key)
        try await baseStorage.delete(forKey: userKey)
    }
    
    // MARK: - User Data Management
    
    /// Clear all data for the current user
    func clearCurrentUserData() async throws {
        let userId = await getCurrentUserId()
        let userKey = await getUserSpecificKey("SavedHabits")
        
        // Clear habits
        try await baseStorage.save([Habit](), forKey: userKey, immediate: true)
        
        // Clear cache
        cachedHabits = []
        
        print("🗑️ UserAwareStorage: Cleared all data for user: \(userId)")
    }
    
    /// Get all user IDs that have data stored
    func getAllUserIds() async -> [String] {
        // This would need to be implemented based on the base storage
        // For now, return empty array
        return []
    }
    
    /// Migrate data from one user to another (for account merging)
    func migrateData(from oldUserId: String, to newUserId: String) async throws {
        // This would need to be implemented based on the base storage
        // For now, just log the request
        print("🔄 UserAwareStorage: Data migration requested from \(oldUserId) to \(newUserId)")
    }
}
