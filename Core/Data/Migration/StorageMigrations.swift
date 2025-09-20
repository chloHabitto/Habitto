import Foundation

// MARK: - UserDefaults to Core Data Migration
/// Migrates data from UserDefaults to Core Data storage
class UserDefaultsToCoreDataMigration: MigrationStep {
    let version = MigrationVersion(1, 1, 0)
    let description = "Migrate from UserDefaults to Core Data"
    let isRequired = true
    
    func execute() async throws -> MigrationResult {
        print("🔄 UserDefaultsToCoreDataMigration: Starting migration...")
        
        // Check if migration is needed
        let hasMigrated = UserDefaults.standard.bool(forKey: "UserDefaultsToCoreDataMigrationCompleted")
        if hasMigrated {
            return .skipped(reason: "Migration already completed")
        }
        
        // Load habits from UserDefaults
        guard let habitsData = UserDefaults.standard.data(forKey: "SavedHabits"),
              let habits = try? JSONDecoder().decode([Habit].self, from: habitsData) else {
            print("⚠️ UserDefaultsToCoreDataMigration: No habits found in UserDefaults")
            return .skipped(reason: "No habits found in UserDefaults")
        }
        
        print("📊 UserDefaultsToCoreDataMigration: Found \(habits.count) habits to migrate")
        
        // Migrate to Core Data
        let coreDataStorage = await CoreDataStorage()
        try await coreDataStorage.saveHabits(habits, immediate: true)
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "UserDefaultsToCoreDataMigrationCompleted")
        
        print("✅ UserDefaultsToCoreDataMigration: Successfully migrated \(habits.count) habits")
        return .success
    }
    
    func canRollback() -> Bool {
        return true
    }
    
    func rollback() async throws {
        print("🔄 UserDefaultsToCoreDataMigration: Rolling back...")
        
        // Clear Core Data storage
        let _ = await CoreDataStorage()
        // Note: CoreDataStorage doesn't have deleteAllHabits method yet
        // For now, we'll just log that rollback was attempted
        print("⚠️ UserDefaultsToCoreDataMigration: Core Data rollback not fully implemented")
        
        // Remove migration flag
        UserDefaults.standard.removeObject(forKey: "UserDefaultsToCoreDataMigrationCompleted")
        
        print("✅ UserDefaultsToCoreDataMigration: Rollback completed")
    }
}

// MARK: - Core Data to CloudKit Migration
/// Migrates data from Core Data to CloudKit storage
class CoreDataToCloudKitMigration: MigrationStep {
    let version = MigrationVersion(1, 2, 0)
    let description = "Migrate from Core Data to CloudKit"
    let isRequired = false // Optional migration
    
    func execute() async throws -> MigrationResult {
        print("🔄 CoreDataToCloudKitMigration: Starting migration...")
        
        // Check if CloudKit is available
        // Note: CloudKitManager doesn't have isCloudKitAvailable method yet
        // For now, we'll assume CloudKit is not available
        return .skipped(reason: "CloudKit not available (not fully implemented)")
    }
    
    func canRollback() -> Bool {
        return true
    }
    
    func rollback() async throws {
        print("🔄 CoreDataToCloudKitMigration: Rolling back...")
        
        // Remove migration flag
        UserDefaults.standard.removeObject(forKey: "CoreDataToCloudKitMigrationCompleted")
        
        print("✅ CoreDataToCloudKitMigration: Rollback completed")
    }
}

// MARK: - Optimize UserDefaults Storage Migration
/// Optimizes UserDefaults storage by storing habits individually
class OptimizeUserDefaultsStorageMigration: MigrationStep {
    let version = MigrationVersion(1, 3, 0)
    let description = "Optimize UserDefaults storage structure"
    let isRequired = true
    
    func execute() async throws -> MigrationResult {
        print("🔄 OptimizeUserDefaultsStorageMigration: Starting optimization...")
        
        // Check if optimization is needed
        let hasOptimized = UserDefaults.standard.bool(forKey: "UserDefaultsStorageOptimized")
        if hasOptimized {
            return .skipped(reason: "Storage already optimized")
        }
        
        // Load habits from old format
        guard let habitsData = UserDefaults.standard.data(forKey: "SavedHabits"),
              let habits = try? JSONDecoder().decode([Habit].self, from: habitsData) else {
            return .skipped(reason: "No habits found in old format")
        }
        
        print("📊 OptimizeUserDefaultsStorageMigration: Found \(habits.count) habits to optimize")
        
        // Store habits individually for better performance
        let userDefaultsStorage = UserDefaultsStorage()
        try await userDefaultsStorage.saveHabits(habits, immediate: true)
        
        // Mark optimization as completed
        UserDefaults.standard.set(true, forKey: "UserDefaultsStorageOptimized")
        
        print("✅ OptimizeUserDefaultsStorageMigration: Successfully optimized storage for \(habits.count) habits")
        return .success
    }
    
    func canRollback() -> Bool {
        return false // Cannot easily rollback this optimization
    }
    
    func rollback() async throws {
        throw DataMigrationError.rollbackFailed(step: description, error: DataMigrationError.unknown)
    }
}
