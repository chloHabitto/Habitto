import Foundation

// MARK: - User-Aware Storage Wrapper

/// Wraps any storage implementation to provide user-specific data isolation
class UserAwareStorage: HabitStorageProtocol {
  // MARK: Lifecycle

  init(baseStorage: any HabitStorageProtocol) {
    self.baseStorage = baseStorage
  }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - HabitStorageProtocol Implementation

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    clearCacheIfUserChanged()

    // Use the specific saveHabits method from base storage instead of generic save
    // This avoids the "Generic save called" warning
    try await baseStorage.saveHabits(habits, immediate: immediate)

    // ✅ CRITICAL FIX: Update cache with the new habits array
    // This ensures cache is always in sync with storage
    print("🗑️ DELETE_FLOW: UserAwareStorage.saveHabits() - Updating cache with \(habits.count) habits")
    cachedHabits = habits
    print("🗑️ DELETE_FLOW: UserAwareStorage.saveHabits() - Cache updated")
  }

  func loadHabits() async throws -> [Habit] {
    // ✅ CRITICAL FIX: Always clear cache on user change to prevent stale data
    clearCacheIfUserChanged()
    
    // ✅ CRITICAL FIX: Get current userId to verify filtering
    let currentUserId = await getCurrentUserId()
    let userIdForLogging = currentUserId.isEmpty ? "EMPTY (guest)" : String(currentUserId.prefix(8)) + "..."
    print("🔄 [USER_AWARE_STORAGE] Loading habits for userId: '\(userIdForLogging)'")

    // ✅ CRITICAL FIX: Clear cache if userId changed
    if let cachedUserId = self.currentUserId, cachedUserId != currentUserId {
      print("🔄 [USER_AWARE_STORAGE] User changed - clearing cache (old: '\(cachedUserId.isEmpty ? "EMPTY" : String(cachedUserId.prefix(8)) + "...")', new: '\(userIdForLogging)')")
      cachedHabits = nil
      self.currentUserId = currentUserId
    }

    // ✅ CRITICAL FIX: Don't use cache when force loading (e.g., after migration)
    // The cache might have stale data even if userId hasn't changed
    // This ensures fresh data is loaded after migration completes
    // Note: We can't pass a "force" parameter here, so we'll rely on the caller
    // to clear the cache explicitly via clearCache() before calling loadHabits()
    
    // Return cached data if available AND userId matches
    // ✅ CRITICAL FIX: Only use cache if userId hasn't changed
    if let cached = cachedHabits,
       let cachedUserId = self.currentUserId,
       cachedUserId == currentUserId {
      print("🔄 [USER_AWARE_STORAGE] Returning cached habits (count: \(cached.count)) for userId: '\(userIdForLogging)'")
      return cached
    }

    // Use the specific loadHabits method from base storage instead of generic load
    // This avoids the "Generic load called" warning
    let habits = try await baseStorage.loadHabits()
    
    // ✅ CRITICAL FIX: Log results to verify filtering
    print("🔄 [USER_AWARE_STORAGE] Base storage returned \(habits.count) habits for userId: '\(userIdForLogging)'")
    if !habits.isEmpty && currentUserId.isEmpty {
      print("⚠️ [USER_AWARE_STORAGE] WARNING: Found \(habits.count) habits in guest mode - should be 0!")
    }

    // Update cache
    cachedHabits = habits
    self.currentUserId = currentUserId
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
    print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - START for habit ID: \(id)")
    clearCacheIfUserChanged()

    // ✅ CRITICAL FIX: Clear cache before deletion
    print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - Clearing cache")
    cachedHabits = nil

    // ✅ CRITICAL FIX: Call the actual deleteHabit method that does modelContext.delete()
    // The previous approach (load → remove → save) doesn't actually delete the HabitData record
    // We must call baseStorage.deleteHabit(id:) which properly does modelContext.delete(habitData)
    print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - Calling baseStorage.deleteHabit()")
    try await baseStorage.deleteHabit(id: id)
    print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - baseStorage.deleteHabit() completed")
    
    // ✅ CRITICAL FIX: Update cache by removing from cached array if present
    // This ensures cache stays in sync after deletion
    if var cached = cachedHabits {
      let beforeCount = cached.count
      cached.removeAll { $0.id == id }
      let afterCount = cached.count
      if beforeCount != afterCount {
        print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - Updated cache: \(beforeCount) → \(afterCount) habits")
        cachedHabits = cached
      }
    }
    
    print("🗑️ DELETE_FLOW: UserAwareStorage.deleteHabit() - END")
  }

  func clearAllHabits() async throws {
    print("🗑️ DELETE_FLOW: UserAwareStorage.clearAllHabits() - START")
    clearCacheIfUserChanged()

    // ✅ CRITICAL FIX: Clear cache before saving to ensure consistency
    print("🗑️ DELETE_FLOW: UserAwareStorage.clearAllHabits() - Clearing cache")
    cachedHabits = nil

    // Use the specific saveHabits method with empty array instead of generic save
    print("🗑️ DELETE_FLOW: UserAwareStorage.clearAllHabits() - Saving empty array to base storage")
    try await baseStorage.saveHabits([], immediate: true)

    // ✅ CRITICAL FIX: Update cache to empty array (not nil) to prevent stale data
    print("🗑️ DELETE_FLOW: UserAwareStorage.clearAllHabits() - Setting cache to empty array")
    cachedHabits = []
    print("🗑️ DELETE_FLOW: UserAwareStorage.clearAllHabits() - END")
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

  func save(_ data: some Codable, forKey key: String, immediate: Bool = false) async throws {
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
    []
  }

  /// Migrate data from one user to another (for account merging)
  func migrateData(from oldUserId: String, to newUserId: String) async throws {
    // This would need to be implemented based on the base storage
    // For now, just log the request
    print("🔄 UserAwareStorage: Data migration requested from \(oldUserId) to \(newUserId)")
  }

  /// Save data as guest data (when user is not authenticated)
  func saveAsGuest(_ data: some Codable, forKey key: String, immediate: Bool = false) async throws {
    let guestKey = getGuestKey(key)
    try await baseStorage.save(data, forKey: guestKey, immediate: immediate)
  }

  /// Load guest data
  func loadGuestData<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
    let guestKey = getGuestKey(key)
    return try await baseStorage.load(type, forKey: guestKey)
  }

  /// Check if guest data exists
  func hasGuestData(forKey key: String) async throws -> Bool {
    let guestKey = getGuestKey(key)
    return try await baseStorage.exists(forKey: guestKey)
  }

  /// Get all guest data keys
  func getGuestDataKeys() async throws -> [String] {
    try await baseStorage.keys(withPrefix: "guest_")
  }

  /// Clear all guest data
  func clearGuestData() async throws {
    let guestKeys = try await getGuestDataKeys()
    for key in guestKeys {
      try await baseStorage.delete(forKey: key)
    }
    print("🗑️ UserAwareStorage: Cleared all guest data")
  }
  
  /// Force clear the cache (e.g., after migration when data changes but userId doesn't)
  /// ✅ CRITICAL FIX: This ensures fresh data is loaded after migration completes
  func clearCache() {
    cachedHabits = nil
    print("🧹 [USER_AWARE_STORAGE] Cache cleared (forced)")
  }

  // MARK: Private

  private let baseStorage: any HabitStorageProtocol
  private var _authManager: AuthenticationManager?
  // Cache for current user's data
  private var cachedHabits: [Habit]?
  private var currentUserId: String?

  private var authManager: AuthenticationManager {
    get async {
      if let existing = _authManager { return existing }
      let manager = await MainActor.run { AuthenticationManager.shared }
      _authManager = manager
      return manager
    }
  }

  // MARK: - User ID Management

  @MainActor
  private func getCurrentUserId() async -> String {
    // Get current user ID from authentication manager
    let manager = await authManager
    if let user = manager.currentUser {
      return user.uid
    }

    // Fallback to empty string for guest users (consistent with SwiftDataStorage)
    return ""
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

  // MARK: - Guest Data Management

  /// Get the storage key for guest data
  private func getGuestKey(_ baseKey: String) -> String {
    "guest_\(baseKey)"
  }
}
