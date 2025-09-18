import Foundation

// MARK: - Storage Type Enum
enum StorageType {
    case userDefaults
    case coreData
    case cloudKit
}

// MARK: - Storage Factory
/// Factory class for creating storage implementations
class StorageFactory {
    static let shared = StorageFactory()
    
    private init() {}
    
    /// Create a habit storage implementation based on the specified type
    /// - Parameter type: The storage type to create
    /// - Returns: A habit storage implementation
    func createHabitStorage(type: StorageType) -> any HabitStorageProtocol {
        switch type {
        case .userDefaults:
            return UserDefaultsStorage()
        case .coreData:
            return CoreDataStorage()
        case .cloudKit:
            // For now, return UserDefaults as CloudKit is not fully implemented
            return UserDefaultsStorage()
        }
    }
    
    /// Create a habit repository with the specified storage type
    /// - Parameter type: The storage type to use
    /// - Returns: A habit repository implementation
    func createHabitRepository(type: StorageType) -> any HabitRepositoryProtocol {
        let storage = createHabitStorage(type: type)
        return HabitRepositoryImpl(storage: storage)
    }
    
    /// Get the recommended storage type based on app configuration
    /// - Returns: The recommended storage type
    func getRecommendedStorageType() -> StorageType {
        // For now, always use UserDefaults as it's the most stable
        // In the future, this could check for Core Data availability, user preferences, etc.
        return .userDefaults
    }
    
    /// Check if a storage type is available
    /// - Parameter type: The storage type to check
    /// - Returns: True if the storage type is available, false otherwise
    func isStorageTypeAvailable(_ type: StorageType) -> Bool {
        switch type {
        case .userDefaults:
            return true // UserDefaults is always available
        case .coreData:
            return CoreDataManager.shared.checkCoreDataHealth()
        case .cloudKit:
            return true // For now, assume CloudKit is available
        }
    }
}

// MARK: - Storage Configuration
/// Configuration class for storage settings
class StorageConfiguration {
    static let shared = StorageConfiguration()
    
    private let userDefaults = UserDefaults.standard
    private let storageTypeKey = "StorageType"
    private let migrationCompletedKey = "StorageMigrationCompleted"
    
    private init() {}
    
    /// Get the current storage type
    /// - Returns: The current storage type
    func getCurrentStorageType() -> StorageType {
        let rawValue = userDefaults.string(forKey: storageTypeKey) ?? "userDefaults"
        return StorageType(rawValue: rawValue) ?? .userDefaults
    }
    
    /// Set the storage type
    /// - Parameter type: The storage type to set
    func setStorageType(_ type: StorageType) {
        userDefaults.set(type.rawValue, forKey: storageTypeKey)
    }
    
    /// Check if migration has been completed
    /// - Returns: True if migration is completed, false otherwise
    func isMigrationCompleted() -> Bool {
        return userDefaults.bool(forKey: migrationCompletedKey)
    }
    
    /// Mark migration as completed
    func markMigrationCompleted() {
        userDefaults.set(true, forKey: migrationCompletedKey)
    }
    
    /// Reset migration status (for testing)
    func resetMigrationStatus() {
        userDefaults.removeObject(forKey: migrationCompletedKey)
    }
}

// MARK: - Storage Type Extensions
extension StorageType: CaseIterable {
    var rawValue: String {
        switch self {
        case .userDefaults:
            return "userDefaults"
        case .coreData:
            return "coreData"
        case .cloudKit:
            return "cloudKit"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "userDefaults":
            self = .userDefaults
        case "coreData":
            self = .coreData
        case "cloudKit":
            self = .cloudKit
        default:
            return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .userDefaults:
            return "UserDefaults"
        case .coreData:
            return "Core Data"
        case .cloudKit:
            return "CloudKit"
        }
    }
    
    var description: String {
        switch self {
        case .userDefaults:
            return "Simple key-value storage, good for small amounts of data"
        case .coreData:
            return "Advanced object graph persistence, good for complex relationships"
        case .cloudKit:
            return "Cloud-based storage with automatic sync across devices"
        }
    }
}
