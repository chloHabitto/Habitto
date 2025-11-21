import CoreData
import Foundation

// MARK: - CoreDataStorage

/// Core Data implementation of the habit storage protocol
/// NOTE: This storage is currently disabled - app uses UserDefaults storage instead.
/// Can be restored from git history if needed.
class CoreDataStorage: HabitStorageProtocol {
  // MARK: Lifecycle

  init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
    self.coreDataManager = coreDataManager
    self.context = coreDataManager.context
    print("⚠️ CoreDataStorage: Core Data storage is disabled - use UserDefaults storage instead")
  }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - DataStorageProtocol Implementation

  func save(_: some Codable, forKey _: String, immediate _: Bool = false) async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func load<T: Codable>(_: T.Type, forKey _: String) async throws -> T? {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func delete(forKey _: String) async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func exists(forKey _: String) async throws -> Bool {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func keys(withPrefix _: String) async throws -> [String] {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  // MARK: - HabitStorageProtocol Implementation

  func saveHabits(_: [Habit], immediate _: Bool = false) async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func loadHabits() async throws -> [Habit] {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func saveHabit(_: Habit, immediate _: Bool = false) async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func loadHabit(id _: UUID) async throws -> Habit? {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func deleteHabit(id _: UUID) async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  func clearAllHabits() async throws {
    throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
  }

  // MARK: Private

  private let coreDataManager: CoreDataManager
  private let context: NSManagedObjectContext
}

// MARK: - DataStorageError

enum DataStorageError: Error, LocalizedError {
  case operationNotSupported(String)
  case contextUnavailable
  case saveFailed(Error)
  case loadFailed(Error)
  case deleteFailed(Error)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .operationNotSupported(let message):
      "Operation not supported: \(message)"
    case .contextUnavailable:
      "Core Data context is not available"
    case .saveFailed(let error):
      "Save operation failed: \(error.localizedDescription)"
    case .loadFailed(let error):
      "Load operation failed: \(error.localizedDescription)"
    case .deleteFailed(let error):
      "Delete operation failed: \(error.localizedDescription)"
    }
  }
}
