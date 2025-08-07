import SwiftUI

@main
struct HabittoApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var coreDataAdapter = CoreDataAdapter.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, coreDataManager.context)
                .environmentObject(coreDataManager)
                .environmentObject(coreDataAdapter)
                .onAppear {
                    print("🚀 HabittoApp: App started!")
                    setupCoreData()
                }
        }
    }
    
    private func setupCoreData() {
        // Check if migration is needed
        let hasMigrated = UserDefaults.standard.bool(forKey: "CoreDataMigrationCompleted")
        
        if !hasMigrated {
            print("🔄 Starting Core Data migration...")
            coreDataAdapter.migrateFromUserDefaults()
            UserDefaults.standard.set(true, forKey: "CoreDataMigrationCompleted")
            print("✅ Core Data migration completed")
        } else {
            print("✅ Core Data already migrated")
        }
    }
} 
