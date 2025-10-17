import Foundation

// MARK: - StorageType

enum StorageType {
  case userDefaults
  case coreData
  case swiftData
  case cloudKit
  case firestore
  case hybrid
}

// MARK: - StorageFactory

/// Factory class for creating storage implementations
class StorageFactory {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = StorageFactory()

  /// Create a habit storage implementation based on the specified type
  /// - Parameter type: The storage type to create
  /// - Returns: A habit storage implementation
  @MainActor
  func createHabitStorage(type: StorageType) -> any HabitStorageProtocol {
    switch type {
    case .userDefaults:
      UserDefaultsStorage()
    case .coreData:
      CoreDataStorage()
    case .swiftData:
      SwiftDataStorage()
    case .cloudKit:
      // For now, return UserDefaults as CloudKit is not fully implemented
      UserDefaultsStorage()
    case .firestore:
      FirestoreStorage()
    case .hybrid:
      // Create DualWriteStorage with Firestore + UserDefaults
      DualWriteStorage(
        primaryStorage: FirestoreService.shared,
        secondaryStorage: UserDefaultsStorage()
      )
    }
  }

  /// Create a habit repository with the specified storage type
  /// - Parameter type: The storage type to use
  /// - Returns: A habit repository implementation
  @MainActor
  func createHabitRepository(type: StorageType) -> any HabitRepositoryProtocol {
    switch type {
    case .hybrid:
      // Use DualWriteStorage directly
      let storage = createHabitStorage(type: .hybrid)
      return HabitRepositoryImpl(storage: storage)
    default:
      let storage = createHabitStorage(type: type)
      return HabitRepositoryImpl(storage: storage)
    }
  }

  /// Get the recommended storage type based on app configuration
  /// - Returns: The recommended storage type
  func getRecommendedStorageType() -> StorageType {
    // Check if Firestore sync is enabled via Remote Config
    if FeatureFlags.enableFirestoreSync {
      return .hybrid
    }
    
    // Use SwiftData as the recommended storage type for modern iOS apps
    // Fall back to UserDefaults if SwiftData is not available
    if isStorageTypeAvailable(.swiftData) {
      return .swiftData
    } else {
      return .userDefaults
    }
  }

  /// Check if a storage type is available
  /// - Parameter type: The storage type to check
  /// - Returns: True if the storage type is available, false otherwise
  func isStorageTypeAvailable(_ type: StorageType) -> Bool {
    switch type {
    case .userDefaults:
      true // UserDefaults is always available
    case .coreData:
      CoreDataManager.shared.checkCoreDataHealth()
    case .swiftData:
      true // SwiftData is available on iOS 17+
    case .cloudKit:
      true // For now, assume CloudKit is available
    case .firestore:
      true // Firestore is available if Firebase is configured
    case .hybrid:
      true // Hybrid is available if both UserDefaults and Firestore are available
    }
  }
}

// MARK: - StorageConfiguration

/// Configuration class for storage settings
class StorageConfiguration {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = StorageConfiguration()

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
    userDefaults.bool(forKey: migrationCompletedKey)
  }

  /// Mark migration as completed
  func markMigrationCompleted() {
    userDefaults.set(true, forKey: migrationCompletedKey)
  }

  /// Reset migration status (for testing)
  func resetMigrationStatus() {
    userDefaults.removeObject(forKey: migrationCompletedKey)
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let storageTypeKey = "StorageType"
  private let migrationCompletedKey = "StorageMigrationCompleted"
}

// MARK: - StorageType + CaseIterable

extension StorageType: CaseIterable {
  // MARK: Lifecycle

  init?(rawValue: String) {
    switch rawValue {
    case "userDefaults":
      self = .userDefaults
    case "coreData":
      self = .coreData
    case "swiftData":
      self = .swiftData
    case "cloudKit":
      self = .cloudKit
    case "firestore":
      self = .firestore
    case "hybrid":
      self = .hybrid
    default:
      return nil
    }
  }

  // MARK: Internal

  var rawValue: String {
    switch self {
    case .userDefaults:
      "userDefaults"
    case .coreData:
      "coreData"
    case .swiftData:
      "swiftData"
    case .cloudKit:
      "cloudKit"
    case .firestore:
      "firestore"
    case .hybrid:
      "hybrid"
    }
  }

  var displayName: String {
    switch self {
    case .userDefaults:
      "UserDefaults"
    case .coreData:
      "Core Data"
    case .swiftData:
      "SwiftData"
    case .cloudKit:
      "CloudKit"
    case .firestore:
      "Firestore"
    case .hybrid:
      "Hybrid (UserDefaults + Firestore)"
    }
  }

  var description: String {
    switch self {
    case .userDefaults:
      "Simple key-value storage, good for small amounts of data"
    case .coreData:
      "Advanced object graph persistence, good for complex relationships"
    case .swiftData:
      "Modern Swift-native persistence framework with type safety"
    case .cloudKit:
      "Cloud-based storage with automatic sync across devices"
    case .firestore:
      "Google Cloud Firestore with real-time sync and offline support"
    case .hybrid:
      "Dual-write to both local and cloud storage for safe migration"
    }
  }
}
