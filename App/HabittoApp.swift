import SwiftUI
import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase
        print("🔥 Configuring Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // Configure Google Sign-In
        print("🔐 Configuring Google Sign-In...")
        let clientID = "657427864427-glmcdnuu4jkjoh9nqoun18t87u443rq8.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("✅ AppDelegate: Google Sign-In configuration set successfully")
        
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("❌ Google Sign-In restore error: \(error.localizedDescription)")
            } else if let user = user {
                print("✅ Google Sign-In restored previous sign-in for user: \(user.profile?.email ?? "No email")")
            }
        }
        
        return true
    }
    
    // Handle Google Sign-In URL callback
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct HabittoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var habitRepository = HabitRepository.shared
    @StateObject private var migrationService = MigrationService.shared
    @StateObject private var tutorialManager = TutorialManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var vacationManager = VacationManager.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    LottieSplashView(onAnimationComplete: {
                        // Hide splash immediately when animation completes
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    })
                    .onAppear {
                        // Fallback: Hide splash after 5 seconds if animation doesn't complete
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            if showSplash {
                                print("⚠️ HabittoApp: Animation timeout, forcing transition")
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSplash = false
                                }
                            }
                        }
                    }
                } else {
                    HomeView()
                        .preferredColorScheme(.light) // Force light mode only
                               .environment(\.managedObjectContext, coreDataManager.context)
                               .environmentObject(coreDataManager)
                               .environmentObject(habitRepository)
                        .environmentObject(tutorialManager)
                        .environmentObject(authManager)
                        .environmentObject(vacationManager)
                        .environmentObject(migrationService)
                        .onAppear {
                            print("🚀 HabittoApp: App started!")
                            setupCoreData()
                            
                            // Check and execute migrations
                            Task { @MainActor in
                                print("🔄 HabittoApp: Checking for data migrations...")
                                await migrationService.checkAndExecuteMigrations()
                            }
                            
                            // Force reload habits after a short delay to ensure data is loaded
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                print("🔄 HabittoApp: Force reloading habits after app start...")
                                habitRepository.loadHabits(force: true)
                                
                                // Reschedule notifications after habits are loaded
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                print("🔄 HabittoApp: Rescheduling notifications after app start...")
                                let habits = habitRepository.habits
                                NotificationManager.shared.rescheduleAllNotifications(for: habits)
                            }
                        }
                }
            }
        }
    }
    
    private func setupCoreData() {
        // Check if migration is needed
        let hasMigrated = UserDefaults.standard.bool(forKey: "CoreDataMigrationCompleted")
        
               if !hasMigrated {
                   print("🔄 Starting Core Data migration...")
                   habitRepository.migrateFromUserDefaults()
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
        ) { [weak habitRepository] _ in
            guard let habitRepository = habitRepository else { return }
            
            Task { @MainActor in
                print("🔄 HabittoApp: App became active, reloading habits...")
                habitRepository.loadHabits(force: true)
                
                // Reschedule notifications after a short delay to ensure habits are loaded
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                print("🔄 HabittoApp: Rescheduling notifications after app became active...")
                let habits = habitRepository.habits
                NotificationManager.shared.rescheduleAllNotifications(for: habits)
            }
        }
        
        // Monitor app lifecycle to save data when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak habitRepository] _ in
            guard let habitRepository = habitRepository else { return }
            
            Task { @MainActor in
                print("🔄 HabittoApp: App going to background, saving data...")
                let habits = habitRepository.habits
                HabitStorageManager.shared.saveHabits(habits, immediate: true)
                print("✅ HabittoApp: Data saved before background")
            }
        }

        // Monitor app lifecycle to save data when app terminates
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak habitRepository] _ in
            guard let habitRepository = habitRepository else { return }
            
            Task { @MainActor in
                print("🔄 HabittoApp: App terminating, saving data...")
                let habits = habitRepository.habits
                HabitStorageManager.shared.saveHabits(habits, immediate: true)
                print("✅ HabittoApp: Data saved before termination")
            }
        }

        // Monitor app lifecycle to save data when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak habitRepository] _ in
            guard let habitRepository = habitRepository else { return }
            
            Task { @MainActor in
                print("🔄 HabittoApp: App entering background, saving data...")
                let habits = habitRepository.habits
                HabitStorageManager.shared.saveHabits(habits, immediate: true)
                print("✅ HabittoApp: Data saved before entering background")
            }
        }
        
        // Monitor app lifecycle to save data when app enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak habitRepository] _ in
            guard let habitRepository = habitRepository else { return }
            
            Task { @MainActor in
                print("🔄 HabittoApp: App entering foreground, saving data...")
                let habits = habitRepository.habits
                HabitStorageManager.shared.saveHabits(habits, immediate: true)
                print("✅ HabittoApp: Data saved before entering foreground")
            }
        }
    }
}