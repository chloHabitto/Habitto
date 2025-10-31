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
    // ✅ FIX: Firebase is already configured in HabittoApp.init()
    // Just verify it's configured and skip if already done
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      
      // Configure Firestore settings
      FirebaseConfiguration.configureFirestore()
    }
    
    // CRITICAL: Initialize Remote Config defaults SYNCHRONOUSLY before anything else
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 3600 // 1 hour for production, 0 for dev
    remoteConfig.configSettings = settings
    
    // Set default values from plist SYNCHRONOUSLY
    remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    
    // ✅ CRITICAL: Set up AuthenticationManager's listener now that Firebase is configured
    Task { @MainActor in
      AuthenticationManager.shared.ensureAuthListenerSetup()
    }
    
    // Configure other Firebase services asynchronously
    Task.detached { @MainActor in
      // ✅ FIX: Firestore already configured synchronously above
      // Only configure Auth here
      FirebaseConfiguration.configureAuth()
      
      // Ensure user is authenticated (anonymous if not signed in)
      do {
        let uid = try await FirebaseConfiguration.ensureAuthenticated()
        
        // CRITICAL: Migrate guest data to authenticated user first
        do {
          try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(to: uid)
        } catch {
          print("⚠️ Guest data migration failed: \(error.localizedDescription)")
        }
        
        // Initialize backfill job if Firestore sync is enabled
        if FeatureFlags.enableFirestoreSync {
          await BackfillJob.shared.runIfEnabled()
        }
      } catch {
        print("❌ Failed to authenticate user: \(error.localizedDescription)")
      }
    }
    
    // Initialize Crashlytics
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    
    // Fetch and activate remote values (async) - defaults already loaded above
    Task {
      do {
        let remoteConfig = RemoteConfig.remoteConfig()
        _ = try await remoteConfig.fetchAndActivate()
      } catch {
        print("⚠️ Remote Config fetch failed: \(error.localizedDescription)")
      }
    }

    // TEMPORARY FIX: Enable migration for guest mode by setting local override
    Task.detached { @MainActor in
      EnhancedMigrationTelemetryManager.shared.setLocalOverride(true)
    }

    // Perform completion status migration
    Task.detached {
      await CompletionStatusMigration.shared.performMigrationIfNeeded()
    }

    // Configure Google Sign-In
    let clientID = "657427864427-glmcdnuu4jkjoh9nqoun18t87u443rq8.apps.googleusercontent.com"
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
      if let error {
        print("❌ Google Sign-In restore error: \(error.localizedDescription)")
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

    // Handle snooze actions
    switch actionIdentifier {
    case "SNOOZE_10_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 10)
    case "SNOOZE_15_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 15)
    case "SNOOZE_30_MIN":
      NotificationManager.shared.handleSnoozeAction(for: notificationId, snoozeMinutes: 30)
    case "DISMISS":
      break
    default:
      break
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
            setupCoreData()

            // ✅ FIX #25: Don't force-hide migration UI - let HabitRepository decide
            // (Removed: habitRepository.shouldShowMigrationView = false)
            // The migration view will appear if guest data exists when user signs in

            // Run XP data migration
            // ✅ FIX #17: Use Task (MainActor) instead of Task.detached to avoid Sendable warning
            // ModelContext is not Sendable and must stay on MainActor
            Task { @MainActor in
              await XPDataMigration.shared.checkAndRunMigration(
                modelContext: SwiftDataContainer.shared.modelContext)
            }

            // NOTE: Data migrations are handled automatically in HabitStore.loadHabits()
            // Removed redundant call to migrationService.checkAndExecuteMigrations()
            // to prevent "Migration already in progress" warnings

            // Force reload habits after a short delay to ensure data is loaded
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 500_000_000)
              await habitRepository.loadHabits(force: true)

              // Initialize notification categories first (for snooze functionality)
              NotificationManager.shared.initializeNotificationCategories()

              // Set deterministic calendar for DST handling in production
              NotificationManager.shared.setDeterministicCalendarForDST()

              // Reschedule notifications after habits are loaded
              try? await Task.sleep(nanoseconds: 500_000_000)
              let habits = habitRepository.habits
              NotificationManager.shared.rescheduleAllNotifications(for: habits)

              // Schedule daily reminders after habits are loaded
              try? await Task.sleep(nanoseconds: 500_000_000)
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
    UserDefaults.standard.set(true, forKey: "CoreDataMigrationCompleted")
  }

  // Monitor app lifecycle to reload data when app becomes active
  NotificationCenter.default.addObserver(
    forName: UIApplication.didBecomeActiveNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      await HabitRepository.shared.loadHabits(force: true)

      // Initialize notification categories first (for snooze functionality)
      NotificationManager.shared.initializeNotificationCategories()

      // Reschedule notifications after a short delay to ensure habits are loaded
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      let habits = HabitRepository.shared.habits
      NotificationManager.shared.rescheduleAllNotifications(for: habits)

      // Schedule daily reminders when app becomes active
      try? await Task.sleep(nanoseconds: 500_000_000)
      NotificationManager.shared.rescheduleDailyReminders()
      
      // ✅ PRIORITY 3: Start periodic event sync (only for authenticated users)
      let userId = await CurrentUser().idOrGuest
      if !CurrentUser.isGuestId(userId) {
        await SyncEngine.shared.startPeriodicSync()
      }
    }
  }

  // Monitor app lifecycle to save data when app goes to background
  NotificationCenter.default.addObserver(
    forName: UIApplication.willResignActiveNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
    }
  }

  // Monitor app lifecycle to save data when app terminates
  NotificationCenter.default.addObserver(
    forName: UIApplication.willTerminateNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
    }
  }

  // Monitor app lifecycle to save data when app enters background
  NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
    }
  }

  // Monitor app lifecycle to save data when app enters foreground
  NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification,
    object: nil,
    queue: .main)
  { _ in
    Task.detached { @MainActor in
      let habits = HabitRepository.shared.habits
      HabitStorageManager.shared.saveHabits(habits, immediate: true)
    }
  }
}

private func handleAuthStateChange(
  oldState: AuthenticationState,
  newState: AuthenticationState)
{
  switch newState {
  case .authenticated(let user):
    // Load user-specific XP from SwiftData
    // ✅ FIX #11: Use SwiftDataContainer's ModelContext directly
    Task.detached { @MainActor in
      let modelContext = SwiftDataContainer.shared.modelContext
      XPManager.shared.loadUserXPFromSwiftData(userId: user.uid, modelContext: modelContext)
    }

  case .unauthenticated:
    // XP clearing is already handled in AuthenticationManager.signOut()
    break

  case .authenticating:
    break

  case .error(let error):
    print("❌ Authentication error: \(error)")
  }
}
