import Foundation

// MARK: - UserDefaults Storage Implementation

/// UserDefaults implementation of the data storage protocol with atomic writes
class UserDefaultsStorage: HabitStorageProtocol {
  // MARK: Internal

  typealias DataType = Habit

  // MARK: - Generic Data Storage Methods

  func save(_ data: some Codable, forKey key: String, immediate: Bool = false) async throws {
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

  func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
    let queue = await backgroundQueue
    return try await queue.execute {
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
    let queue = await backgroundQueue
    try await queue.execute {
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
    let queue = await backgroundQueue
    return try await queue.execute {
      self.userDefaults.exists(forKey: key)
    }
  }

  func keys(withPrefix prefix: String) async throws -> [String] {
    let queue = await backgroundQueue
    return try await queue.execute {
      self.userDefaults.getKeys(withPrefix: prefix)
    }
  }

  // MARK: - Habit-Specific Storage Methods

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    // Performance optimization: Only save if habits actually changed
    if let cached = cachedHabits, cached == habits, !immediate {
      return // No change, skip save
    }

    // Use background queue for heavy operations
    let queue = await backgroundQueue
    try await queue.executeSerial {
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

  func loadHabits(force: Bool = false) async throws -> [Habit] {
    // Migration is handled by HabitStore, not here

    // ✅ CRITICAL FIX: Clear cache if force is true
    if force {
      cachedHabits = nil
    }

    // Performance optimization: Return cached result if available (only if not forcing)
    if !force, let cached = cachedHabits {
      return cached
    }

    // Use background queue for heavy operations
    let queue = await backgroundQueue
    let habits = try await queue.execute {
      // Always prioritize the complete array as the source of truth
      if let habits: [Habit] = try? self.userDefaults.getCodable(
        [Habit].self,
        forKey: self.habitsKey)
      {
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
    let queue = await backgroundQueue
    try await queue.executeSerial {
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
    (cachedHabits != nil, cachedHabits?.count ?? 0)
  }

  // MARK: Private

  private let userDefaults = UserDefaultsWrapper.shared
  private let habitsKey = "SavedHabits"
  private let individualHabitKeyPrefix = "Habit_"
  private var _backgroundQueue: BackgroundQueueManager?
  private let atomicWriter = AtomicFileWriter()
  private var _migrationManager: DataMigrationManager?
  // Performance optimization: Cache loaded habits
  private var cachedHabits: [Habit]?
  private var lastSaveTime = Date()
  private let saveDebounceInterval: TimeInterval = 0.5

  private var backgroundQueue: BackgroundQueueManager {
    get async {
      if let existing = _backgroundQueue { return existing }
      let queue = await MainActor.run { BackgroundQueueManager.shared }
      _backgroundQueue = queue
      return queue
    }
  }

  private var migrationManager: DataMigrationManager {
    get async {
      if let existing = _migrationManager { return existing }
      let manager = await MainActor.run { DataMigrationManager.shared }
      _migrationManager = manager
      return manager
    }
  }

  private func performAtomicSave(_ data: some Codable, forKey key: String) async throws {
    let queue = await backgroundQueue
    try await queue.executeSerial {
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

  private func performSave(_ data: some Codable, forKey key: String) async throws {
    let queue = await backgroundQueue
    try await queue.executeSerial {
      try self.userDefaults.setCodable(data, forKey: key)
      Task { @MainActor in
        self.lastSaveTime = Date()
      }
    }
  }

  // MARK: - Private Helper Methods

  /// Gets the file URL for atomic storage
  private func getFileURL(for key: String) -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first!
    let atomicStorageDirectory = documentsPath.appendingPathComponent("AtomicStorage")

    // Ensure directory exists
    try? FileManager.default.createDirectory(
      at: atomicStorageDirectory,
      withIntermediateDirectories: true)

    return atomicStorageDirectory.appendingPathComponent("\(key).json")
  }
}
