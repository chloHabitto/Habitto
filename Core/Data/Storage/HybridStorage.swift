import Foundation
import OSLog

// MARK: - HybridStorage

/// Hybrid storage implementation that writes to both local and cloud storage
/// Provides safe migration path from UserDefaults to Firestore
@MainActor
final class HybridStorage: HabitStorageProtocol {
  // MARK: Lifecycle

  init(
    localStorage: any HabitStorageProtocol,
    cloudStorage: any HabitStorageProtocol)
  {
    self.localStorage = localStorage
    self.cloudStorage = cloudStorage
    logger.info("🔄 HybridStorage: Initialized with dual-write capability")
  }

  // MARK: Internal

  typealias DataType = Habit

  // MARK: - Generic Data Storage Methods

  func save(_ data: some Codable, forKey key: String, immediate: Bool = false) async throws {
    logger.info("🔄 HybridStorage: Saving data for key: \(key)")
    
    // Write to local storage first (fast, reliable)
    do {
      try await localStorage.save(data, forKey: key, immediate: immediate)
      logger.info("✅ HybridStorage: Data saved to local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to save to local storage: \(error.localizedDescription)")
      throw error // Don't continue if local save fails
    }
    
    // Then write to cloud storage (async, can fail)
    Task {
      do {
        try await cloudStorage.save(data, forKey: key, immediate: immediate)
        logger.info("✅ HybridStorage: Data synced to cloud storage")
      } catch {
        logger.warning("⚠️ HybridStorage: Failed to sync to cloud storage: \(error.localizedDescription)")
        // Don't throw - local save succeeded, cloud sync is best-effort
      }
    }
  }

  nonisolated func load<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
    logger.info("🔄 HybridStorage: Loading data for key: \(key)")
    
    // Try local storage first (fast, works offline)
    do {
      if let localData = try await localStorage.load(type, forKey: key) {
        logger.info("✅ HybridStorage: Data loaded from local storage")
        return localData
      }
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to load from local storage: \(error.localizedDescription)")
    }
    
    // Fall back to cloud storage if local is empty
    do {
      if let cloudData = try await cloudStorage.load(type, forKey: key) {
        logger.info("✅ HybridStorage: Data loaded from cloud storage")
        
        // Cache the cloud data locally for next time
        Task { @MainActor in
          try? await localStorage.save(cloudData, forKey: key, immediate: true)
          logger.info("💾 HybridStorage: Cloud data cached locally")
        }
        
        return cloudData
      }
    } catch {
      logger.error("❌ HybridStorage: Failed to load from cloud storage: \(error.localizedDescription)")
    }
    
    logger.info("ℹ️ HybridStorage: No data found for key: \(key)")
    return nil
  }

  func delete(forKey key: String) async throws {
    logger.info("🔄 HybridStorage: Deleting data for key: \(key)")
    
    // Delete from both storages
    do {
      try await localStorage.delete(forKey: key)
      logger.info("✅ HybridStorage: Data deleted from local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to delete from local storage: \(error.localizedDescription)")
    }
    
    do {
      try await cloudStorage.delete(forKey: key)
      logger.info("✅ HybridStorage: Data deleted from cloud storage")
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to delete from cloud storage: \(error.localizedDescription)")
      // Don't throw - local delete succeeded
    }
  }

  func exists(forKey key: String) async throws -> Bool {
    // Check local storage first
    do {
      if try await localStorage.exists(forKey: key) {
        return true
      }
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to check existence in local storage: \(error.localizedDescription)")
    }
    
    // Check cloud storage
    do {
      return try await cloudStorage.exists(forKey: key)
    } catch {
      logger.error("❌ HybridStorage: Failed to check existence in cloud storage: \(error.localizedDescription)")
      return false
    }
  }

  func keys(withPrefix prefix: String) async throws -> [String] {
    // Get keys from local storage
    let localKeys = (try? await localStorage.keys(withPrefix: prefix)) ?? []
    
    // Get keys from cloud storage
    let cloudKeys = (try? await cloudStorage.keys(withPrefix: prefix)) ?? []
    
    // Combine and deduplicate
    let allKeys = Set(localKeys + cloudKeys)
    return Array(allKeys).sorted()
  }

  // MARK: - Habit-Specific Storage Methods

  func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
    logger.info("🔄 HybridStorage: Saving \(habits.count) habits")
    
    // Write to local storage first
    do {
      try await localStorage.saveHabits(habits, immediate: immediate)
      logger.info("✅ HybridStorage: \(habits.count) habits saved to local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to save habits to local storage: \(error.localizedDescription)")
      throw error
    }
    
    // Sync to cloud storage (async, best-effort)
    Task {
      do {
        try await cloudStorage.saveHabits(habits, immediate: immediate)
        logger.info("✅ HybridStorage: \(habits.count) habits synced to cloud storage")
      } catch {
        logger.warning("⚠️ HybridStorage: Failed to sync habits to cloud storage: \(error.localizedDescription)")
      }
    }
  }

  func loadHabits() async throws -> [Habit] {
    logger.info("🔄 HybridStorage: Loading habits")
    
    // Try local storage first
    do {
      let localHabits = try await localStorage.loadHabits()
      if !localHabits.isEmpty {
        logger.info("✅ HybridStorage: Loaded \(localHabits.count) habits from local storage")
        return localHabits
      }
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to load habits from local storage: \(error.localizedDescription)")
    }
    
    // Fall back to cloud storage
    do {
      let cloudHabits = try await cloudStorage.loadHabits()
      logger.info("✅ HybridStorage: Loaded \(cloudHabits.count) habits from cloud storage")
      
      // Cache cloud habits locally
      Task { @MainActor in
        try? await localStorage.saveHabits(cloudHabits, immediate: true)
        logger.info("💾 HybridStorage: Cloud habits cached locally")
      }
      
      return cloudHabits
    } catch {
      logger.error("❌ HybridStorage: Failed to load habits from cloud storage: \(error.localizedDescription)")
      throw error
    }
  }

  func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
    logger.info("🔄 HybridStorage: Saving habit '\(habit.name)'")
    
    // Write to local storage first
    do {
      try await localStorage.saveHabit(habit, immediate: immediate)
      logger.info("✅ HybridStorage: Habit '\(habit.name)' saved to local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to save habit to local storage: \(error.localizedDescription)")
      throw error
    }
    
    // Sync to cloud storage (async, best-effort)
    Task {
      do {
        try await cloudStorage.saveHabit(habit, immediate: immediate)
        logger.info("✅ HybridStorage: Habit '\(habit.name)' synced to cloud storage")
      } catch {
        logger.warning("⚠️ HybridStorage: Failed to sync habit to cloud storage: \(error.localizedDescription)")
      }
    }
  }

  func loadHabit(id: UUID) async throws -> Habit? {
    logger.info("🔄 HybridStorage: Loading habit with ID: \(id)")
    
    // Try local storage first
    do {
      if let localHabit = try await localStorage.loadHabit(id: id) {
        logger.info("✅ HybridStorage: Habit loaded from local storage")
        return localHabit
      }
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to load habit from local storage: \(error.localizedDescription)")
    }
    
    // Fall back to cloud storage
    do {
      if let cloudHabit = try await cloudStorage.loadHabit(id: id) {
        logger.info("✅ HybridStorage: Habit loaded from cloud storage")
        
        // Cache the cloud habit locally
        Task { @MainActor in
          try? await localStorage.saveHabit(cloudHabit, immediate: true)
          logger.info("💾 HybridStorage: Cloud habit cached locally")
        }
        
        return cloudHabit
      }
    } catch {
      logger.error("❌ HybridStorage: Failed to load habit from cloud storage: \(error.localizedDescription)")
    }
    
    logger.info("ℹ️ HybridStorage: Habit with ID \(id) not found")
    return nil
  }

  func deleteHabit(id: UUID) async throws {
    logger.info("🔄 HybridStorage: Deleting habit with ID: \(id)")
    
    // Delete from local storage
    do {
      try await localStorage.deleteHabit(id: id)
      logger.info("✅ HybridStorage: Habit deleted from local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to delete habit from local storage: \(error.localizedDescription)")
    }
    
    // Delete from cloud storage
    do {
      try await cloudStorage.deleteHabit(id: id)
      logger.info("✅ HybridStorage: Habit deleted from cloud storage")
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to delete habit from cloud storage: \(error.localizedDescription)")
      // Don't throw - local delete succeeded
    }
  }

  func clearAllHabits() async throws {
    logger.info("🔄 HybridStorage: Clearing all habits")
    
    // Clear local storage
    do {
      try await localStorage.clearAllHabits()
      logger.info("✅ HybridStorage: All habits cleared from local storage")
    } catch {
      logger.error("❌ HybridStorage: Failed to clear habits from local storage: \(error.localizedDescription)")
      throw error
    }
    
    // Clear cloud storage
    do {
      try await cloudStorage.clearAllHabits()
      logger.info("✅ HybridStorage: All habits cleared from cloud storage")
    } catch {
      logger.warning("⚠️ HybridStorage: Failed to clear habits from cloud storage: \(error.localizedDescription)")
      // Don't throw - local clear succeeded
    }
  }

  // MARK: - Cache Management

  func clearCache() {
    // Clear cache if the storage supports it
    if let localStorage = localStorage as? FirestoreStorage {
      localStorage.clearCache()
    }
    if let cloudStorage = cloudStorage as? FirestoreStorage {
      cloudStorage.clearCache()
    }
    logger.info("🧹 HybridStorage: Cache cleared for both storages")
  }

  func getCacheStatus() -> (isCached: Bool, count: Int) {
    var localStatus = (isCached: false, count: 0)
    var cloudStatus = (isCached: false, count: 0)
    
    if let localStorage = localStorage as? FirestoreStorage {
      localStatus = localStorage.getCacheStatus()
    }
    if let cloudStorage = cloudStorage as? FirestoreStorage {
      cloudStatus = cloudStorage.getCacheStatus()
    }
    
    return (
      isCached: localStatus.isCached || cloudStatus.isCached,
      count: max(localStatus.count, cloudStatus.count)
    )
  }

  // MARK: - Migration Helpers

  /// Force sync all local data to cloud storage
  func forceSyncToCloud() async throws {
    logger.info("🔄 HybridStorage: Force syncing all local data to cloud")
    
    do {
      let localHabits = try await localStorage.loadHabits()
      try await cloudStorage.saveHabits(localHabits, immediate: true)
      logger.info("✅ HybridStorage: Force sync completed - \(localHabits.count) habits synced")
    } catch {
      logger.error("❌ HybridStorage: Force sync failed: \(error.localizedDescription)")
      throw error
    }
  }

  /// Force sync all cloud data to local storage
  func forceSyncFromCloud() async throws {
    logger.info("🔄 HybridStorage: Force syncing all cloud data to local")
    
    do {
      let cloudHabits = try await cloudStorage.loadHabits()
      try await localStorage.saveHabits(cloudHabits, immediate: true)
      logger.info("✅ HybridStorage: Force sync from cloud completed - \(cloudHabits.count) habits synced")
    } catch {
      logger.error("❌ HybridStorage: Force sync from cloud failed: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: Private

  private let localStorage: any HabitStorageProtocol
  private let cloudStorage: any HabitStorageProtocol
  private let logger = Logger(subsystem: "com.habitto.app", category: "HybridStorage")
}

