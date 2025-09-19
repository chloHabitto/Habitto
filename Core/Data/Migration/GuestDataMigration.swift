import Foundation
import Combine

/// Manages migration of guest user data to authenticated user accounts
@MainActor
final class GuestDataMigration: ObservableObject {
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let authManager = AuthenticationManager.shared
    
    // Keys for guest data
    private let guestHabitsKey = "guest_habits"
    private let guestBackupKey = "guest_backup_created"
    private let guestDataMigratedKey = "guest_data_migrated"
    
    // MARK: - Published Properties
    
    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = ""
    
    // MARK: - Public Methods
    
    /// Check if there's guest data that can be migrated
    func hasGuestData() -> Bool {
        // Check if there are guest habits
        if let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
           let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData),
           !guestHabits.isEmpty {
            return true
        }
        
        // Check if there are guest backup files
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let guestBackupDir = documentsPath.appendingPathComponent("Backups").appendingPathComponent("guest_user")
        
        if fileManager.fileExists(atPath: guestBackupDir.path) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: guestBackupDir.path)
                return !contents.isEmpty
            } catch {
                print("❌ GuestDataMigration: Error checking guest backup directory: \(error)")
            }
        }
        
        return false
    }
    
    /// Check if guest data has already been migrated for the current user
    func hasMigratedGuestData() -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
        return userDefaults.bool(forKey: migrationKey)
    }
    
    /// Migrate guest data to the current authenticated user
    func migrateGuestData() async throws {
        guard let currentUser = authManager.currentUser else {
            throw GuestDataMigrationError.noAuthenticatedUser
        }
        
        guard hasGuestData() else {
            throw GuestDataMigrationError.noGuestData
        }
        
        guard !hasMigratedGuestData() else {
            print("ℹ️ GuestDataMigration: Guest data already migrated for user \(currentUser.uid)")
            return
        }
        
        isMigrating = true
        migrationProgress = 0.0
        migrationStatus = "Starting migration..."
        
        do {
            // Step 1: Migrate habits data
            migrationStatus = "Migrating habits..."
            migrationProgress = 0.2
            try await migrateGuestHabits(to: currentUser.uid)
            
            // Step 2: Migrate backup files
            migrationStatus = "Migrating backups..."
            migrationProgress = 0.6
            try await migrateGuestBackups(to: currentUser.uid)
            
            // Step 3: Mark migration as complete
            migrationStatus = "Finalizing migration..."
            migrationProgress = 0.9
            let migrationKey = "\(guestDataMigratedKey)_\(currentUser.uid)"
            userDefaults.set(true, forKey: migrationKey)
            
            // Step 4: Clean up guest data (optional - we'll keep it for safety)
            migrationStatus = "Migration complete!"
            migrationProgress = 1.0
            
            print("✅ GuestDataMigration: Successfully migrated guest data for user \(currentUser.uid)")
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
            throw error
        }
        
        isMigrating = false
    }
    
    /// Get a preview of guest data that would be migrated
    func getGuestDataPreview() -> GuestDataPreview? {
        guard hasGuestData() else { return nil }
        
        // Get guest habits
        let guestHabits: [Habit] = {
            guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
                  let habits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else {
                return []
            }
            return habits
        }()
        
        // Get guest backup count
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let guestBackupDir = documentsPath.appendingPathComponent("Backups").appendingPathComponent("guest_user")
        var backupCount = 0
        
        if fileManager.fileExists(atPath: guestBackupDir.path) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: guestBackupDir.path)
                backupCount = contents.count
            } catch {
                print("❌ GuestDataMigration: Error counting guest backups: \(error)")
            }
        }
        
        return GuestDataPreview(
            habitCount: guestHabits.count,
            backupCount: backupCount,
            habits: guestHabits
        )
    }
    
    // MARK: - Private Methods
    
    private func migrateGuestHabits(to userId: String) async throws {
        guard let guestHabitsData = userDefaults.data(forKey: guestHabitsKey),
              let guestHabits = try? JSONDecoder().decode([Habit].self, from: guestHabitsData) else {
            print("ℹ️ GuestDataMigration: No guest habits to migrate")
            return
        }
        
        print("🔄 GuestDataMigration: Migrating \(guestHabits.count) guest habits to user \(userId)")
        
        // Load existing user habits
        let userHabitsKey = "\(userId)_habits"
        var existingHabits: [Habit] = {
            guard let userHabitsData = userDefaults.data(forKey: userHabitsKey),
                  let habits = try? JSONDecoder().decode([Habit].self, from: userHabitsData) else {
                return []
            }
            return habits
        }()
        
        // Merge guest habits with existing user habits
        // We'll add guest habits that don't conflict with existing ones
        var mergedHabits = existingHabits
        var migratedCount = 0
        
        for guestHabit in guestHabits {
            // Check if a habit with the same name already exists
            let existingHabit = existingHabits.first { $0.name.lowercased() == guestHabit.name.lowercased() }
            
            if existingHabit == nil {
                // No conflict, add the guest habit
                mergedHabits.append(guestHabit)
                migratedCount += 1
            } else {
                // Conflict exists, we could either skip or merge data
                // For now, we'll skip conflicting habits to avoid data loss
                print("⚠️ GuestDataMigration: Skipping conflicting habit: \(guestHabit.name)")
            }
        }
        
        // Save merged habits
        let mergedHabitsData = try JSONEncoder().encode(mergedHabits)
        userDefaults.set(mergedHabitsData, forKey: userHabitsKey)
        
        print("✅ GuestDataMigration: Migrated \(migratedCount) habits to user \(userId)")
    }
    
    private func migrateGuestBackups(to userId: String) async throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let guestBackupDir = documentsPath.appendingPathComponent("Backups").appendingPathComponent("guest_user")
        let userBackupDir = documentsPath.appendingPathComponent("Backups").appendingPathComponent(userId)
        
        guard fileManager.fileExists(atPath: guestBackupDir.path) else {
            print("ℹ️ GuestDataMigration: No guest backups to migrate")
            return
        }
        
        // Ensure user backup directory exists
        try fileManager.createDirectory(at: userBackupDir, withIntermediateDirectories: true)
        
        // Get all guest backup files
        let guestBackupFiles = try fileManager.contentsOfDirectory(at: guestBackupDir, includingPropertiesForKeys: nil)
        
        print("🔄 GuestDataMigration: Migrating \(guestBackupFiles.count) guest backups to user \(userId)")
        
        for guestBackupFile in guestBackupFiles {
            let fileName = guestBackupFile.lastPathComponent
            let userBackupFile = userBackupDir.appendingPathComponent(fileName)
            
            // Copy the backup file to user directory
            try fileManager.copyItem(at: guestBackupFile, to: userBackupFile)
        }
        
        // Migrate backup metadata
        let guestLastBackupKey = "guest_last_backup_date"
        let guestBackupCountKey = "guest_backup_count"
        let userLastBackupKey = "\(userId)_last_backup_date"
        let userBackupCountKey = "\(userId)_backup_count"
        
        if let lastBackupDate = userDefaults.object(forKey: guestLastBackupKey) as? Date {
            userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
        }
        
        let guestBackupCount = userDefaults.integer(forKey: guestBackupCountKey)
        let userBackupCount = userDefaults.integer(forKey: userBackupCountKey)
        userDefaults.set(userBackupCount + guestBackupCount, forKey: userBackupCountKey)
        
        print("✅ GuestDataMigration: Migrated guest backups to user \(userId)")
    }
}

// MARK: - Supporting Types

struct GuestDataPreview {
    let habitCount: Int
    let backupCount: Int
    let habits: [Habit]
}

enum GuestDataMigrationError: LocalizedError {
    case noAuthenticatedUser
    case noGuestData
    case migrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user found"
        case .noGuestData:
            return "No guest data found to migrate"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        }
    }
}
