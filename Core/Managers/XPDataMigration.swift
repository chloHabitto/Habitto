import Foundation
import SwiftData

// MARK: - XP Data Migration Manager
/// Handles migration of XP data from hardcoded userId to real user authentication
class XPDataMigration {
    static let shared = XPDataMigration()
    
    private let migrationKey = "XPDataMigration_Completed"
    private let oldUserId = "current_user_id"
    
    private init() {}
    
    /// Check if migration is needed and run it
    func checkAndRunMigration(modelContext: ModelContext) async {
        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("🔄 XPDataMigration: Migration already completed, skipping")
            return
        }
        
        print("🔄 XPDataMigration: Starting XP data migration...")
        
        // Query for old hardcoded userId records
        let predicate = #Predicate<DailyAward> { award in
            award.userId == oldUserId
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        
        do {
            let oldAwards = try modelContext.fetch(request)
            print("🔄 XPDataMigration: Found \(oldAwards.count) records with old userId")
            
            if oldAwards.isEmpty {
                print("🔄 XPDataMigration: No old records found, marking migration as complete")
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }
            
            // Check if user is currently authenticated
            if let currentUser = AuthenticationManager.shared.currentUser {
                // User is authenticated - migrate to their real userId
                await migrateToAuthenticatedUser(oldAwards: oldAwards, newUserId: currentUser.uid, modelContext: modelContext)
            } else {
                // User is not authenticated - migrate to guest
                await migrateToGuest(oldAwards: oldAwards, modelContext: modelContext)
            }
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ XPDataMigration: Migration completed successfully")
            
        } catch {
            print("❌ XPDataMigration: Error during migration: \(error)")
        }
    }
    
    /// Migrate old records to authenticated user
    private func migrateToAuthenticatedUser(oldAwards: [DailyAward], newUserId: String, modelContext: ModelContext) async {
        print("🔄 XPDataMigration: Migrating \(oldAwards.count) records to authenticated user: \(newUserId)")
        
        for award in oldAwards {
            // Update the userId
            award.userId = newUserId
            print("🔄 XPDataMigration: Updated award \(award.id) to userId: \(newUserId)")
        }
        
        do {
            try modelContext.save()
            print("✅ XPDataMigration: Successfully migrated to authenticated user")
        } catch {
            print("❌ XPDataMigration: Error saving migrated data: \(error)")
        }
    }
    
    /// Migrate old records to guest user
    private func migrateToGuest(oldAwards: [DailyAward], modelContext: ModelContext) async {
        print("🔄 XPDataMigration: Migrating \(oldAwards.count) records to guest user")
        
        for award in oldAwards {
            // Update the userId to guest
            award.userId = CurrentUser.guestId
            print("🔄 XPDataMigration: Updated award \(award.id) to guest userId")
        }
        
        do {
            try modelContext.save()
            print("✅ XPDataMigration: Successfully migrated to guest user")
        } catch {
            print("❌ XPDataMigration: Error saving migrated data: \(error)")
        }
    }
    
    /// Reset migration flag (for testing)
    func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 XPDataMigration: Migration flag reset")
    }
    
    /// Check migration status
    func isMigrationCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: migrationKey)
    }
}
