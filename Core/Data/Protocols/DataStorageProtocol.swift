import Foundation

// MARK: - DataStorageProtocol

/// Protocol defining the interface for data storage operations
protocol DataStorageProtocol {
  associatedtype DataType: Codable & Identifiable

  /// Save data to storage
  /// - Parameters:
  ///   - data: The data to save
  ///   - key: The storage key
  ///   - immediate: Whether to save immediately or use debouncing
  func save(_ data: some Codable & Sendable, forKey key: String, immediate: Bool) async throws

  /// Load data from storage
  /// - Parameter key: The storage key
  /// - Returns: The loaded data, or nil if not found
  func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?

  /// Delete data from storage
  /// - Parameter key: The storage key
  func delete(forKey key: String) async throws

  /// Check if data exists for a key
  /// - Parameter key: The storage key
  /// - Returns: True if data exists, false otherwise
  func exists(forKey key: String) async throws -> Bool

  /// Get all keys for a given prefix
  /// - Parameter prefix: The key prefix to search for
  /// - Returns: Array of keys matching the prefix
  func keys(withPrefix prefix: String) async throws -> [String]
}

// MARK: - HabitStorageProtocol

/// Protocol specifically for habit data storage operations
protocol HabitStorageProtocol: DataStorageProtocol where DataType == Habit {
  /// Save habits to storage
  /// - Parameters:
  ///   - habits: Array of habits to save
  ///   - immediate: Whether to save immediately or use debouncing
  func saveHabits(_ habits: [Habit], immediate: Bool) async throws

  /// Load habits from storage
  /// - Returns: Array of loaded habits
  func loadHabits() async throws -> [Habit]

  /// Save a single habit
  /// - Parameters:
  ///   - habit: The habit to save
  ///   - immediate: Whether to save immediately or use debouncing
  func saveHabit(_ habit: Habit, immediate: Bool) async throws

  /// Load a single habit by ID
  /// - Parameter id: The habit ID
  /// - Returns: The loaded habit, or nil if not found
  func loadHabit(id: UUID) async throws -> Habit?

  /// Delete a habit by ID
  /// - Parameter id: The habit ID
  func deleteHabit(id: UUID) async throws

  /// Clear all habit data
  func clearAllHabits() async throws
}

// MARK: - RepositoryProtocol

/// Protocol defining the interface for data repository operations
protocol RepositoryProtocol {
  associatedtype DataType: Codable & Identifiable

  /// Get all data items
  /// - Returns: Array of all data items
  func getAll() async throws -> [DataType]

  /// Get a data item by ID
  /// - Parameter id: The item ID
  /// - Returns: The data item, or nil if not found
  func getById(_ id: UUID) async throws -> DataType?

  /// Create a new data item
  /// - Parameter item: The item to create
  /// - Returns: The created item
  func create(_ item: DataType) async throws -> DataType

  /// Update an existing data item
  /// - Parameter item: The item to update
  /// - Returns: The updated item
  func update(_ item: DataType) async throws -> DataType

  /// Delete a data item by ID
  /// - Parameter id: The item ID
  func delete(_ id: UUID) async throws

  /// Check if an item exists by ID
  /// - Parameter id: The item ID
  /// - Returns: True if exists, false otherwise
  func exists(_ id: UUID) async throws -> Bool
}

// MARK: - HabitRepositoryProtocol

/// Protocol specifically for habit repository operations
protocol HabitRepositoryProtocol: RepositoryProtocol where DataType == Habit {
  /// Get habits for a specific date
  /// - Parameter date: The date to filter by
  /// - Returns: Array of habits for the date
  func getHabits(for date: Date) async throws -> [Habit]

  /// Get habits by type
  /// - Parameter type: The habit type to filter by
  /// - Returns: Array of habits of the specified type
  func getHabits(by type: HabitType) async throws -> [Habit]

  /// Get active habits
  /// - Returns: Array of active habits
  func getActiveHabits() async throws -> [Habit]

  /// Get archived habits
  /// - Returns: Array of archived habits
  func getArchivedHabits() async throws -> [Habit]

  /// Update habit completion for a specific date
  /// - Parameters:
  ///   - habitId: The habit ID
  ///   - date: The date
  ///   - progress: The completion progress (0.0 to 1.0)
  func updateHabitCompletion(habitId: UUID, date: Date, progress: Double) async throws

  /// Get habit completion for a specific date
  /// - Parameters:
  ///   - habitId: The habit ID
  ///   - date: The date
  /// - Returns: The completion progress (0.0 to 1.0)
  func getHabitCompletion(habitId: UUID, date: Date) async throws -> Double

  /// Calculate habit streak
  /// - Parameter habitId: The habit ID
  /// - Returns: The current streak count
  func calculateHabitStreak(habitId: UUID) async throws -> Int
}
