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

@objc(AppDelegate)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  private static var hasLoggedInit = false
  private static var hasCompletedLaunch = false
  
  override init() {
    super.init()
    guard !Self.hasLoggedInit else { return }
    Self.hasLoggedInit = true
    // Use both print and NSLog to ensure visibility
    debugLog("🚀 AppDelegate: INIT CALLED")
    NSLog("🚀 AppDelegate: INIT CALLED (NSLog)")
  }
  
  func application(
    _: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool
  {
    if Self.hasCompletedLaunch {
      debugLog("⏭️ AppDelegate: Duplicate didFinishLaunchingWithOptions call detected, skipping redundant initialization")
      return true
    }
    Self.hasCompletedLaunch = true
    
    // Use both print and NSLog to ensure visibility - SYNCHRONOUSLY at the very start
    debugLog("🚀 AppDelegate: didFinishLaunchingWithOptions called")
    NSLog("🚀 AppDelegate: didFinishLaunchingWithOptions called (NSLog)")
    fflush(stdout) // Force flush to ensure log appears immediately
    
    FirebaseBootstrapper.configureIfNeeded(source: "AppDelegate.didFinishLaunching")
    debugLog("✅ AppDelegate: Firebase already configured")
    
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
    debugLog("🚀 AppDelegate: Creating Task.detached for SyncEngine initialization...")
    NSLog("🚀 AppDelegate: Creating Task.detached for SyncEngine initialization...")
    fflush(stdout) // Force flush before async task
    
    // Use Task instead of Task.detached to ensure it runs on MainActor immediately
    Task { @MainActor in
      debugLog("🚀 AppDelegate: Task block started executing...")
      NSLog("🚀 AppDelegate: Task block started executing...")
      fflush(stdout)
      
      // ✅ FIX: Firestore already configured synchronously above
      // Only configure Auth here
      debugLog("🚀 AppDelegate: Calling FirebaseConfiguration.configureAuth()...")
      NSLog("🚀 AppDelegate: Calling FirebaseConfiguration.configureAuth()...")
      FirebaseConfiguration.configureAuth()
      debugLog("✅ AppDelegate: FirebaseConfiguration.configureAuth() completed")
      NSLog("✅ AppDelegate: FirebaseConfiguration.configureAuth() completed")
      
      // Ensure user is authenticated (anonymous if not signed in)
      do {
        debugLog("🔍 SyncEngine: Starting authentication check...")
        NSLog("🔍 SyncEngine: Starting authentication check...")
        let uid = try await FirebaseConfiguration.ensureAuthenticated()
        debugLog("✅ SyncEngine: User authenticated - uid: \(uid)")
        NSLog("✅ SyncEngine: User authenticated - uid: %@", uid)
        
        // CRITICAL: Migrate guest data to authenticated user first
        do {
          try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(to: uid)
        } catch {
          debugLog("⚠️ Guest data migration failed: \(error.localizedDescription)")
          NSLog("⚠️ Guest data migration failed: %@", error.localizedDescription)
        }
        
        // Initialize backfill job if Firestore sync is enabled
        if FeatureFlags.enableFirestoreSync {
          debugLog("🔄 SyncEngine: Running backfill job...")
          NSLog("🔄 SyncEngine: Running backfill job...")
          await BackfillJob.shared.runIfEnabled()
          debugLog("✅ SyncEngine: Backfill job completed")
          NSLog("✅ SyncEngine: Backfill job completed")
        }
        
        // ✅ CRITICAL: Start periodic sync for authenticated users (not guests)
        // This ensures data syncs on app launch, not just when app becomes active
        debugLog("🔍 SyncEngine: Checking if user is guest - uid: \(uid), isGuest: \(CurrentUser.isGuestId(uid))")
        NSLog("🔍 SyncEngine: Checking if user is guest - uid: %@, isGuest: %@", uid, CurrentUser.isGuestId(uid) ? "YES" : "NO")
        if !CurrentUser.isGuestId(uid) {
          debugLog("✅ SyncEngine: User is authenticated, accessing SyncEngine.shared...")
          NSLog("✅ SyncEngine: User is authenticated, accessing SyncEngine.shared...")
          // Access SyncEngine.shared explicitly to ensure initialization
          debugLog("🔍 SyncEngine: About to access SyncEngine.shared...")
          NSLog("🔍 SyncEngine: About to access SyncEngine.shared...")
          fflush(stdout)
          let syncEngine = SyncEngine.shared
          debugLog("✅ SyncEngine: SyncEngine.shared accessed (initialization should have logged above)")
          NSLog("✅ SyncEngine: SyncEngine.shared accessed (initialization should have logged above)")
          fflush(stdout)
          debugLog("✅ SyncEngine: Calling startPeriodicSync(userId: \(uid))...")
          NSLog("✅ SyncEngine: Calling startPeriodicSync(userId: %@)...", uid)
          fflush(stdout)
          // Pass userId directly to avoid race condition with CurrentUser().idOrGuest
          await syncEngine.startPeriodicSync(userId: uid)
          debugLog("✅ SyncEngine: startPeriodicSync() call completed")
          NSLog("✅ SyncEngine: startPeriodicSync() call completed")
          fflush(stdout)
          
          // ✅ PRIORITY 1: Schedule event compaction after authentication
          debugLog("📅 EventCompactor: Initializing for authenticated user: \(uid)")
          NSLog("📅 EventCompactor: Initializing for authenticated user: %@", uid)
          let compactor = EventCompactor(userId: uid)
          await compactor.scheduleNextCompaction()
          debugLog("✅ EventCompactor: Scheduling completed")
          NSLog("✅ EventCompactor: Scheduling completed")
        } else {
          debugLog("⏭️ SyncEngine: Skipping sync for guest user")
          NSLog("⏭️ SyncEngine: Skipping sync for guest user")
        }
      } catch {
        debugLog("❌ SyncEngine: Failed to authenticate user: \(error.localizedDescription)")
        NSLog("❌ SyncEngine: Failed to authenticate user: %@", error.localizedDescription)
        debugLog("❌ SyncEngine: Error details: \(error)")
        NSLog("❌ SyncEngine: Error details: %@", String(describing: error))
        // Log full error stack trace for debugging
        if let nsError = error as NSError? {
          debugLog("❌ SyncEngine: Error domain: \(nsError.domain), code: \(nsError.code)")
          NSLog("❌ SyncEngine: Error domain: %@, code: %d", nsError.domain, nsError.code)
          debugLog("❌ SyncEngine: Error userInfo: \(nsError.userInfo)")
          NSLog("❌ SyncEngine: Error userInfo: %@", String(describing: nsError.userInfo))
        }
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
        debugLog("⚠️ Remote Config fetch failed: \(error.localizedDescription)")
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
    
    // Perform completion to event migration (event-sourcing)
    Task.detached {
      await MigrateCompletionsToEvents.shared.performMigrationIfNeeded()
    }

    // Configure Google Sign-In
    let clientID = "657427864427-glmcdnuu4jkjoh9nqoun18t87u443rq8.apps.googleusercontent.com"
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
      if let error {
        debugLog("❌ Google Sign-In restore error: \(error.localizedDescription)")
      }
    }

    // Configure notification center delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Register event compaction background task
    debugLog("📅 EventCompactor: Registering background task handler...")
    NSLog("📅 EventCompactor: Registering background task handler...")
    EventCompactor.registerBackgroundTaskHandler()
    debugLog("✅ EventCompactor: Background task handler registered")
    NSLog("✅ EventCompactor: Background task handler registered")

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
  
  init() {
    FirebaseBootstrapper.configureIfNeeded(source: "HabittoApp.init")
    
    _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
    _habitRepository = StateObject(wrappedValue: HabitRepository.shared)
    _migrationService = StateObject(wrappedValue: MigrationService.shared)
    _tutorialManager = StateObject(wrappedValue: TutorialManager())
    _authManager = StateObject(wrappedValue: AuthenticationManager.shared)
    _vacationManager = StateObject(wrappedValue: VacationManager.shared)
    _themeManager = StateObject(wrappedValue: ThemeManager.shared)
    _xpManager = State(initialValue: XPManager.shared)
  }

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

            // Refresh habits after a short delay to ensure data is loaded
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 500_000_000)
              await habitRepository.loadHabits()
            }
            
            // Defer heavy work until after the first frame renders
            Task.detached(priority: .background) {
              try? await Task.sleep(nanoseconds: 2_000_000_000)
              await habitRepository.postLaunchWarmup()
            }
          }
        }
      }
    }
  }

  // MARK: Private

  // ✅ FIX #11: Removed @Environment(\.modelContext) - we use SwiftDataContainer.shared.modelContext directly
  // This prevents SwiftUI from creating a second container with Persistent History enabled
  @StateObject private var notificationManager: NotificationManager
  @StateObject private var habitRepository: HabitRepository
  @StateObject private var migrationService: MigrationService
  @StateObject private var tutorialManager: TutorialManager
  @StateObject private var authManager: AuthenticationManager
  @StateObject private var vacationManager: VacationManager
  @StateObject private var themeManager: ThemeManager
  @State private var xpManager: XPManager
  @State private var showSplash = true
}

// MARK: - FirebaseBootstrapper

private enum FirebaseBootstrapper {
  private static var didConfigure = false
  
  static func configureIfNeeded(source: String) {
    guard !didConfigure else { return }
    
    if FirebaseApp.app() == nil {
      debugLog("🔥 FirebaseBootstrapper (\(source)): Configuring Firebase")
      FirebaseApp.configure()
    } else {
      debugLog("ℹ️ FirebaseBootstrapper (\(source)): Firebase already configured")
    }
    
    FirebaseConfiguration.configureFirestore()
    didConfigure = true
  }
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
      await HabitRepository.shared.loadHabits()
      Task.detached(priority: .background) {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await HabitRepository.shared.postLaunchWarmup()
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
    debugLog("❌ Authentication error: \(error)")
  }
}
