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
  /// - Parameter force: If true, bypass cache and reload from storage
  /// - Returns: Array of loaded habits
  func loadHabits(force: Bool) async throws -> [Habit]

  /// Save a single habit
  /// - Parameters:
  ///   - habit: The habit to save
  ///   - immediate: Whether to save immediately or use debouncing
  func saveHabit(_ habit: Habit, immediate: Bool) async throws

  /// Load a single habit by ID
  /// - Parameter id: The habit ID
  /// - Returns: The loaded habit, or nil if not found
  func loadHabit(id: UUID) async throws -> Habit?

  /// Delete a habit by ID (soft delete)
  /// - Parameter id: The habit ID
  /// - Returns: True if deletion occurred, false if deletion was skipped (e.g., habit was restored)
  func deleteHabit(id: UUID) async throws -> Bool

  /// Clear all habit data
  func clearAllHabits() async throws
  
  /// Load soft-deleted habits (for Recently Deleted view)
  /// - Returns: Array of soft-deleted habits within 30 days
  func loadSoftDeletedHabits() async throws -> [Habit]
  
  /// Count soft-deleted habits
  /// - Returns: Number of soft-deleted habits within 30 days
  func countSoftDeletedHabits() async throws -> Int
  
  /// Permanently delete a habit (hard delete)
  /// - Parameter id: The habit ID
  func permanentlyDeleteHabit(id: UUID) async throws
}

// MARK: - Backward Compatibility Extension

extension HabitStorageProtocol {
  /// Load habits from storage (backward compatibility - defaults to force: false)
  func loadHabits() async throws -> [Habit] {
    return try await loadHabits(force: false)
  }
}

// MARK: - Default Implementations for Soft Delete Methods

extension HabitStorageProtocol {
  /// Default implementation - returns empty array
  /// Only SwiftDataStorage has the real implementation
  func loadSoftDeletedHabits() async throws -> [Habit] {
    print("⚠️ loadSoftDeletedHabits() not implemented for this storage type")
    return []
  }
  
  /// Default implementation - returns 0
  /// Only SwiftDataStorage has the real implementation
  func countSoftDeletedHabits() async throws -> Int {
    print("⚠️ countSoftDeletedHabits() not implemented for this storage type")
    return 0
  }
  
  /// Default implementation - no-op
  /// Only SwiftDataStorage has the real implementation
  func permanentlyDeleteHabit(id: UUID) async throws {
    print("⚠️ permanentlyDeleteHabit() not implemented for this storage type")
    // No-op by default
  }
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

