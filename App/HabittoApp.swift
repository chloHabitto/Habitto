import FirebaseCore
// Note: Add these imports after adding packages in Xcode:
import FirebaseCrashlytics
import FirebaseRemoteConfig
import GoogleSignIn
import MijickPopups
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Firebase Migration Imports
// Import the new Firebase migration classes

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool
  {
    // Configure Firebase SYNCHRONOUSLY (required for RemoteConfig and other services)
    print("🔥 Configuring Firebase...")
    FirebaseApp.configure()
    print("✅ Firebase Core configured")
    
    // CRITICAL: Initialize Remote Config defaults SYNCHRONOUSLY before anything else
    print("🎛️ Initializing Firebase Remote Config defaults...")
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 3600 // 1 hour for production, 0 for dev
    remoteConfig.configSettings = settings
    
    // Set default values from plist SYNCHRONOUSLY
    remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    print("✅ Remote Config defaults loaded from plist")
    
    // Verify the value is set
    let firestoreSyncValue = remoteConfig.configValue(forKey: "enableFirestoreSync").boolValue
    print("🔍 Remote Config: enableFirestoreSync = \(firestoreSyncValue)")
    
    // Configure other Firebase services asynchronously
    Task.detached { @MainActor in
      FirebaseConfiguration.configureFirestore()
      FirebaseConfiguration.configureAuth()
      
      // Ensure user is authenticated (anonymous if not signed in)
      do {
        let uid = try await FirebaseConfiguration.ensureAuthenticated()
        print("✅ User authenticated with uid: \(uid)")
        
        // CRITICAL: Migrate guest data to authenticated user first
        print("🔄 Checking for guest data to migrate...")
        do {
          try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(to: uid)
          print("✅ Guest data migration check complete")
        } catch {
          print("⚠️ Guest data migration failed: \(error.localizedDescription)")
          print("   Data may appear missing until this is resolved")
        }
        
        // Initialize backfill job if Firestore sync is enabled
        if FeatureFlags.enableFirestoreSync {
          print("🔄 Starting backfill job for Firestore migration...")
          await BackfillJob.shared.runIfEnabled()
        }
      } catch {
        print("⚠️ Failed to authenticate user: \(error.localizedDescription)")
        print("📝 App will continue with limited functionality")
      }
    }
    
    // Initialize Crashlytics (uncomment after adding package)
     print("🐛 Initializing Firebase Crashlytics...")
     Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
     print("✅ Crashlytics initialized")
    
    // Fetch and activate remote values (async) - defaults already loaded above
     Task {
       do {
         let remoteConfig = RemoteConfig.remoteConfig()
         let status = try await remoteConfig.fetchAndActivate()
         if status == .successFetchedFromRemote {
           print("✅ Remote Config: Fetched new values from Firebase")
         } else {
           print("ℹ️ Remote Config: Using cached or default values")
         }
       } catch {
         print("⚠️ Remote Config: Failed to fetch - \(error.localizedDescription)")
       }
     }

    // TEMPORARY FIX: Enable migration for guest mode by setting local override
    print("🔧 AppDelegate: Setting migration override for guest mode...")
    Task.detached { @MainActor in
      EnhancedMigrationTelemetryManager.shared.setLocalOverride(true)
    }

    // Perform completion status migration
    print("🔄 AppDelegate: Starting completion status migration...")
    Task.detached {
      await CompletionStatusMigration.shared.performMigrationIfNeeded()
    }

    // Configure Google Sign-In
    print("🔐 Configuring Google Sign-In...")
    let clientID = "657427864427-glmcdnuu4jkjoh9nqoun18t87u443rq8.apps.googleusercontent.com"
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    print("✅ AppDelegate: Google Sign-In configuration set successfully")

    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
      if let error {
        print("❌ Google Sign-In restore error: \(error.localizedDescription)")
      } else if let user {
        print(
          "✅ Google Sign-In restored previous sign-in for user: \(user.profile?.email ?? "No email")")
      }
    }

    // Configure notification center delegate
    UNUserNotificationCenter.current().delegate = self

    return true
  }

  // MARK: - Notification Handling

  /// Handle notification actions (snooze, dismiss, etc.)
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void)
  {
    let actionIdentifier = response.actionIdentifier
    let notificationId = response.notification.request.identifier

    print(
      "📱 AppDelegate: Received notification action: \(actionIdentifier) for notification: \(notificationId)")

    // Handle snooze actions
    switch actionIdentifier {
    case "SNOOZE_10_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 10)
    case "SNOOZE_15_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 15)
    case "SNOOZE_30_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 30)
    case "DISMISS":
      print("ℹ️ AppDelegate: User dismissed notification: \(notificationId)")
    default:
      print("ℹ️ AppDelegate: Unknown notification action: \(actionIdentifier)")
    }

    completionHandler()
  }

  /// Handle notifications when app is in foreground
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
      -> Void)
  {
    print("📱 AppDelegate: Received notification in foreground: \(notification.request.identifier)")

    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  /// Handle Google Sign-In URL callback
  func application(
    _: UIApplication,
    open url: URL,
    options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool
  {
    GIDSignIn.sharedInstance.handle(url)
  }
}

// MARK: - HabittoApp

@main
struct HabittoApp: App {
  // MARK: Internal

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

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
            Task.detached { @MainActor in
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
          ZStack {
            HomeView()
              .preferredColorScheme(.light) // Force light mode only
              // ✅ CRITICAL: Use SwiftDataContainer's ModelContainer to ensure all code uses the same database
              // This prevents XPDataMigration from creating a separate container with Persistent History enabled
              .modelContainer(SwiftDataContainer.shared.modelContainer)
              // .environment(\.managedObjectContext, coreDataManager.context)  // Disabled - using
              // SwiftData only
              // .environmentObject(coreDataManager)  // Disabled - using SwiftData only
              .environmentObject(habitRepository)
              .environmentObject(tutorialManager)
              .environmentObject(authManager)
              .environmentObject(vacationManager)
              .environmentObject(migrationService)
              .environmentObject(themeManager)
              .environment(xpManager)  // ✅ Inject XPManager via @Observable
              .onChange(of: authManager.authState) { oldState, newState in
                handleAuthStateChange(
                  oldState: oldState,
                  newState: newState)
              }
              .registerPopups(id: .shared) { config in config
                .vertical { $0
                  .enableDragGesture(true)
                  .tapOutsideToDismissPopup(true)
                  .cornerRadius(32)
                }
                .center { $0
                  .tapOutsideToDismissPopup(false)
                  .backgroundColor(.white)
                }
              }
          }
          .onAppear {
            print("🚀 HabittoApp: App started!")
            setupCoreData()

            // ✅ CRITICAL FIX: Health check disabled to prevent database corruption
            // The health check was deleting the database while in use, causing corruption
            // Database corruption is now handled gracefully by saveHabits/loadHabits with
            // UserDefaults fallback
            print("🔧 HabittoApp: Health check disabled (corruption handled gracefully)")

            // DISABLED: Migration completely disabled per user request
            print("ℹ️ HabittoApp: Migration disabled - skipping migration checks")

            // Immediately clear any migration state to prevent screen from showing
            habitRepository.shouldShowMigrationView = false

            // Run XP data migration
            // ✅ FIX #11: Use SwiftDataContainer's ModelContext directly
            // Using @Environment(\.modelContext) was creating a second container
            Task.detached {
              await XPDataMigration.shared.checkAndRunMigration(
                modelContext: SwiftDataContainer.shared.modelContext)
            }

            // NOTE: Data migrations are handled automatically in HabitStore.loadHabits()
            // Removed redundant call to migrationService.checkAndExecuteMigrations()
            // to prevent "Migration already in progress" warnings

            // Force reload habits after a short delay to ensure data is loaded
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 500_000_000)
              print("🔄 HabittoApp: Force reloading habits after app start...")
              await habitRepository.loadHabits(force: true)

              // Initialize notification categories first (for snooze functionality)
              print("🔧 HabittoApp: Initializing notification categories...")
              NotificationManager.shared.initializeNotificationCategories()

              // Set deterministic calendar for DST handling in production
              print("🔧 HabittoApp: Setting deterministic calendar for DST handling...")
              NotificationManager.shared.setDeterministicCalendarForDST()

              // Reschedule notifications after habits are loaded
              try? await Task.sleep(nanoseconds: 500_000_000)
              print("🔄 HabittoApp: Rescheduling notifications after app start...")
              let habits = habitRepository.habits
              NotificationManager.shared.rescheduleAllNotifications(for: habits)

              // Schedule daily reminders after habits are loaded
              try? await Task.sleep(nanoseconds: 500_000_000)
              print("🔄 HabittoApp: Scheduling daily reminders after app start...")
              NotificationManager.shared.rescheduleDailyReminders()

              // Reset daily XP counter if needed (maintenance operation)
              // This is a legitimate daily counter reset, not an XP award mutation
              XPManager.shared.resetDailyXP()
            }
          }
        }
      }
    }
  }

  // MARK: Private

  // ✅ FIX #11: Removed @Environment(\.modelContext) - we use SwiftDataContainer.shared.modelContext directly
  // This prevents SwiftUI from creating a second container with Persistent History enabled
  @StateObject private var notificationManager = NotificationManager.shared
  // @StateObject private var coreDataManager = CoreDataManager.shared  // Disabled - using
  // SwiftData only
  @StateObject private var habitRepository = HabitRepository.shared
  @StateObject private var migrationService = MigrationService.shared
  @StateObject private var tutorialManager = TutorialManager()
  @StateObject private var authManager = AuthenticationManager.shared
  @StateObject private var vacationManager = VacationManager.shared
  @StateObject private var themeManager = ThemeManager.shared
  @State private var xpManager = XPManager.shared
  @State private var showSplash = true
}

private func setupCoreData() {
  // Check if migration is needed
  let hasMigrated = UserDefaults.standard.bool(forKey: "CoreDataMigrationCompleted")

  if !hasMigrated {
    print("🔄 Data migration handled by HabitStore...")
    UserDefaults.standard.set(true, forKey: "CoreDataMigrationCompleted")
    print("✅ Data migration completed")
  } else {
    print("✅ Data already migrated")
  }

  // Monitor app lifecycle to reload data when app becomes active
  NotificationCenter.default.addObserver(
    forName: UIApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      print("🔄 HabittoApp: App became active, reloading habits...")
      await HabitRepository.shared.loadHabits(force: true)

      // Initialize notification categories first (for snooze functionality)
      print("🔧 HabittoApp: Initializing notification categories after app became active...")
      NotificationManager.shared.initializeNotificationCategories()

      // Reschedule notifications after a short delay to ensure habits are loaded
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      print("🔄 HabittoApp: Rescheduling notifications after app became active...")
      let habits = HabitRepository.shared.habits
      NotificationManager.shared.rescheduleAllNotifications(for: habits)

      // Schedule daily reminders when app becomes active
      try? await Task.sleep(nanoseconds: 500_000_000)
      print("🔄 HabittoApp: Scheduling daily reminders after app became active...")
      NotificationManager.shared.rescheduleDailyReminders()
    }
  }

  // Monitor app lifecycle to save data when app goes to background
  NotificationCenter.default.addObserver(
    forName: UIApplication.willResignActiveNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      print("🔄 HabittoApp: App going to background, saving data...")
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
      print("✅ HabittoApp: Data saved before background")
    }
  }

  // Monitor app lifecycle to save data when app terminates
  NotificationCenter.default.addObserver(
    forName: UIApplication.willTerminateNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      print("🔄 HabittoApp: App terminating, saving data...")
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
      print("✅ HabittoApp: Data saved before termination")
    }
  }

  // Monitor app lifecycle to save data when app enters background
  NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      print("🔄 HabittoApp: App entering background, saving data...")
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
      print("✅ HabittoApp: Data saved before entering background")
    }
  }

  // Monitor app lifecycle to save data when app enters foreground
  NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      print("🔄 HabittoApp: App entering foreground, saving data...")
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
      print("✅ HabittoApp: Data saved before entering foreground")
    }
  }
}

private func handleAuthStateChange(
  oldState: AuthenticationState,
  newState: AuthenticationState)
{
  print("🎯 AUTH: Auth state changed from \(oldState) to \(newState)")

  switch newState {
  case .authenticated(let user):
    print("🎯 AUTH: User signed in: \(user.email ?? "no email")")
    // Load user-specific XP from SwiftData
    // ✅ FIX #11: Use SwiftDataContainer's ModelContext directly
    Task.detached { @MainActor in
      let modelContext = SwiftDataContainer.shared.modelContext
      XPManager.shared.loadUserXPFromSwiftData(userId: user.uid, modelContext: modelContext)
    }

  case .unauthenticated:
    print("🎯 AUTH: User signed out")
            // XP clearing is already handled in AuthenticationManager.signOut()

  case .authenticating:
    print("🎯 AUTH: User authenticating...")

  case .error(let error):
    print("❌ AUTH: Authentication error: \(error)")
  }
}
