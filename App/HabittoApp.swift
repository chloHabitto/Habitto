import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct HabittoApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var coreDataAdapter = CoreDataAdapter.shared
    @StateObject private var tutorialManager = TutorialManager()
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .preferredColorScheme(.light) // Force light mode only
                .environment(\.managedObjectContext, coreDataManager.context)
                .environmentObject(coreDataManager)
                .environmentObject(coreDataAdapter)
                .environmentObject(tutorialManager)
                .environmentObject(authManager)
                .onAppear {
                    print("🚀 HabittoApp: App started!")
                    setupCoreData()
                    
                    // Force reload habits after a short delay to ensure data is loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔄 HabittoApp: Force reloading habits after app start...")
                        coreDataAdapter.loadHabits(force: true)
                    }
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
        
        // Monitor app lifecycle to reload data when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 HabittoApp: App became active, reloading habits...")
            coreDataAdapter.loadHabits(force: true)
        }
        
        // Monitor app lifecycle to save data when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 HabittoApp: App going to background, saving data...")
            do {
                try coreDataManager.save()
                print("✅ HabittoApp: Data saved before background")
            } catch {
                print("❌ HabittoApp: Failed to save data before background: \(error)")
            }
        }

        // Monitor app lifecycle to save data when app terminates
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 HabittoApp: App terminating, saving data...")
            do {
                try coreDataManager.save()
                print("✅ HabittoApp: Data saved before termination")
            } catch {
                print("❌ HabittoApp: Failed to save data before termination: \(error)")
            }
        }

        // Monitor app lifecycle to save data when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 HabittoApp: App entering background, saving data...")
            do {
                try coreDataManager.save()
                print("✅ HabittoApp: Data saved before entering background")
            } catch {
                print("❌ HabittoApp: Failed to save data before entering background: \(error)")
            }
        }
        
        // Monitor app lifecycle to save data when app enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 HabittoApp: App entering foreground, saving data...")
            // Force save the Core Data context
            do {
                try coreDataManager.save()
                print("✅ HabittoApp: Core Data context saved before entering foreground")
            } catch {
                print("❌ HabittoApp: Failed to save Core Data context: \(error)")
            }
        }
    }
} 
