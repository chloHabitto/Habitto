import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Storage Implementation (DISABLED)
/// Core Data implementation of the habit storage protocol
/// NOTE: This storage is currently disabled due to missing Core Data model
class CoreDataStorage: HabitStorageProtocol {
    typealias DataType = Habit
    
    private let coreDataManager: CoreDataManager
    private let context: NSManagedObjectContext
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.context = coreDataManager.context
        print("⚠️ CoreDataStorage: Core Data storage is disabled - use UserDefaults storage instead")
    }
    
    // MARK: - Generic Data Storage Methods
    
    func save<T: Codable>(_ data: T, forKey key: String, immediate: Bool = false) async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func delete(forKey key: String) async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func exists(forKey key: String) async throws -> Bool {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    // MARK: - Habit-Specific Storage Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func loadHabits() async throws -> [Habit] {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func deleteHabit(id: UUID) async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
    
    func clearAllHabits() async throws {
        // Core Data is disabled - this storage is not functional
        // The app uses UserDefaults as the primary storage
        throw DataStorageError.operationNotSupported("Core Data storage is disabled. Use UserDefaults storage instead.")
    }
}

// MARK: - Data Storage Error
enum DataStorageError: Error, LocalizedError {
    case operationNotSupported(String)
    case contextUnavailable
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .operationNotSupported(let message):
            return "Operation not supported: \(message)"
        case .contextUnavailable:
            return "Core Data context is not available"
        case .saveFailed(let error):
            return "Save operation failed: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Load operation failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Delete operation failed: \(error.localizedDescription)"
        }
    }
}