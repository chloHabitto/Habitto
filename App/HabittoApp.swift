import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
// Note: Add these imports after adding packages in Xcode:
import FirebaseCrashlytics
import FirebaseRemoteConfig
import GoogleSignIn
import MijickPopups
import OSLog
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Firebase Migration Imports
// Import the new Firebase migration classes

// MARK: - AppDelegate

@objcMembers
@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  var window: UIWindow?
  private static var hasLoggedInit = false
  private static var hasCompletedLaunch = false
  
  override init() {
    super.init()
    guard !Self.hasLoggedInit else { return }
    Self.hasLoggedInit = true
    debugLog("🚀 AppDelegate: INIT CALLED")
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
    
    FirebaseBootstrapper.configureIfNeeded(source: "AppDelegate.didFinishLaunching")
    
    // Force flush to ensure log appears immediately
    debugLog("🚀 AppDelegate: didFinishLaunchingWithOptions called")
    fflush(stdout)
    
    FirebaseBootstrapper.configureIfNeeded(source: "AppDelegate.didFinishLaunching")
    debugLog("✅ AppDelegate: Firebase configured (or already configured)")
    
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
    fflush(stdout) // Force flush before async task
    
    // Use Task instead of Task.detached to ensure it runs on MainActor immediately
    Task { @MainActor in
      debugLog("🚀 AppDelegate: Task block started executing...")
      fflush(stdout)
      
      // ✅ CRITICAL: Ensure user is authenticated (anonymous if not signed in)
      // This must happen before any data operations
      // Firebase Auth is already configured by FirebaseBootstrapper.configureIfNeeded()
      do {
        debugLog("🔐 AppDelegate: Ensuring user authentication...")
        let uid = try await FirebaseConfiguration.ensureAuthenticated()
        debugLog("✅ AppDelegate: User authenticated - uid: \(uid)")
        
        // ✅ CRITICAL: Check if this is a scenario that needs user choice
        // If user has BOTH guest data AND cloud data, don't auto-migrate - let UI show choice
        let migrationManager = GuestDataMigration()
        let hasGuestData = migrationManager.hasGuestData()
        let cloudDataPreview = await migrationManager.getCloudDataPreview()
        let hasCloudData = cloudDataPreview != nil && (cloudDataPreview?.habitCount ?? 0) > 0
        
        if hasGuestData && hasCloudData {
          // BOTH exist - don't auto-migrate, let UI show choice
          debugLog("🔄 AppDelegate: Guest and cloud data both exist - skipping auto-migration, UI will show choice")
        } else if hasGuestData && !hasCloudData {
          // Only guest data exists - safe to auto-migrate to new account
          debugLog("🔄 AppDelegate: Only guest data exists - auto-migrating to new account...")
          await GuestDataMigrationHelper.runCompleteMigration(userId: uid)
          debugLog("✅ AppDelegate: Guest data migration completed")
        } else {
          // No guest data - nothing to migrate
          debugLog("🔄 AppDelegate: No guest data to migrate")
        }
        
        // ✅ CRITICAL: Start periodic sync for anonymous users
        // This ensures data syncs to Firestore automatically in the background
        debugLog("🔄 AppDelegate: Starting periodic sync for user: \(uid)")
        await SyncEngine.shared.startPeriodicSync(userId: uid)
        debugLog("✅ AppDelegate: Periodic sync started")
        
        // ✅ Register/update device on every app launch (non-guest users only)
        if !CurrentUser.isGuestId(uid) {
          Task {
            await DeviceManager.shared.registerCurrentDevice()
          }
        }
        
      } catch {
        debugLog("❌ AppDelegate: Failed to authenticate user: \(error.localizedDescription)")
        // Continue app launch even if authentication fails
        // User can still use the app in guest mode
      }
      
      // DISABLED: Sign-in functionality commented out for future use
      /*
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
      */
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

    // DISABLED: Sign-in functionality commented out for future use
    /*
    // Configure Google Sign-In
    let clientID = "657427864427-glmcdnuu4jkjoh9nqoun18t87u443rq8.apps.googleusercontent.com"
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
      if let error {
        debugLog("❌ Google Sign-In restore error: \(error.localizedDescription)")
      }
    }
    */

    // Configure notification center delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Clear app icon badge on launch
    clearAppIconBadge()
    
    // Register event compaction background task
    debugLog("📅 EventCompactor: Registering background task handler...")
    EventCompactor.registerBackgroundTaskHandler()
    debugLog("✅ EventCompactor: Background task handler registered")

    return true
  }
  
  /// Clear the app icon badge count
  func clearAppIconBadge() {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
    debugLog("✅ AppDelegate: Cleared app icon badge")
  }
  
  /// Called when app becomes active - clear badge
  func applicationDidBecomeActive(_ application: UIApplication) {
    clearAppIconBadge()
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

  // DISABLED: Sign-in functionality commented out for future use
  /*
  /// Handle Google Sign-In URL callback
  func application(
    _: UIApplication,
    open url: URL,
    options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool
  {
    GIDSignIn.sharedInstance.handle(url)
  }
  */
}

// MARK: - HabittoApp

@main
struct HabittoApp: App {
  // MARK: Internal
  
  init() {
    _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
    _habitRepository = StateObject(wrappedValue: HabitRepository.shared)
    _migrationService = StateObject(wrappedValue: MigrationService.shared)
    _tutorialManager = StateObject(wrappedValue: TutorialManager())
    _authManager = StateObject(wrappedValue: AuthenticationManager.shared)
    _vacationManager = StateObject(wrappedValue: VacationManager.shared)
    _themeManager = StateObject(wrappedValue: ThemeManager.shared)
    _xpManager = State(initialValue: XPManager.shared)

    // Force the UIApplicationDelegateAdaptor to instantiate AppDelegate before configuring Firebase.
    // This ensures GoogleUtilities' AppDelegate swizzler sees a valid delegate instance.
    _ = delegate
    
    // Configure tab bar appearance at app launch
    configureTabBarAppearance()
  }

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  // MARK: - Tab Bar Appearance
  
  static func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
    
    // Unselected state
    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(named: "appBottomeNavIcon_Inactive")
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appText03") ?? .gray
    ]
    
    // Selected state
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(named: "appBottomeNavIcon_Active")
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appPrimary") ?? .systemBlue
    ]
    
    // Apply to all tab bars
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    
    // Also apply to all existing tab bars in the window hierarchy
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
      windowScene.windows.forEach { window in
        window.rootViewController?.view.subviews.forEach { view in
          if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
          }
        }
      }
    }
  }
  
  private func configureTabBarAppearance() {
    Self.configureTabBarAppearance()
  }

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
              .preferredColorScheme(themeManager.preferredColorScheme)
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
            // App startup logging
            print("🚀 App Launched")
            print("   isPremium: \(SubscriptionManager.shared.isPremium)")
            
            // Give transaction listener time to check
            Task { @MainActor in
              try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
              print("🚀 App Launched +2s")
              print("   isPremium: \(SubscriptionManager.shared.isPremium)")
            }
            
            // ✅ DIAGNOSTIC - Run this FIRST before anything else
            Task { @MainActor in
              await diagnoseDataIssue()
              
              // ✅ FIX - Repair broken relationships (one-time only)
              let repairKey = "completionRecordRelationshipsRepaired"
              if !UserDefaults.standard.bool(forKey: repairKey) {
                await repairCompletionRecordRelationships()
                UserDefaults.standard.set(true, forKey: repairKey)
                
                // ✅ VERIFY - Check that the fix worked
                await diagnoseDataIssue()
              } else {
                print("ℹ️ [REPAIR] Relationship repair already completed - skipping")
              }
              
              // ✅ RESTORE - Try to restore progress from Firestore if CompletionRecords have progress=0
              // Check if we need to restore by checking if any CompletionRecords have progress=0
              let needsRestore = await checkIfNeedsProgressRestore()
              if needsRestore {
                print("🔧 [RESTORE] CompletionRecords with progress=0 detected - attempting restore from Firestore")
                await restoreProgressFromFirestore()
              } else {
                print("ℹ️ [RESTORE] All CompletionRecords have progress > 0 - no restore needed")
              }
              
              // ✅ FIX - Clean up duplicate CompletionRecords (one-time only)
              let cleanupKey = "completionRecordDuplicatesCleaned"
              if !UserDefaults.standard.bool(forKey: cleanupKey) {
                await cleanupDuplicateCompletionRecords()
                UserDefaults.standard.set(true, forKey: cleanupKey)
              } else {
                print("ℹ️ [CLEANUP] Duplicate CompletionRecord cleanup already completed - skipping")
              }
            }
            
            setupCoreData()

            // ✅ GUEST MODE ONLY: No anonymous authentication
            // All users use userId = "" (guest mode)
            Task { @MainActor in
              // ✅ FORCE RELOAD - Reload data after repair to ensure UI sees fixed relationships
              print("🔄 [RELOAD] Forcing data reload after relationship repair...")
              await habitRepository.loadHabits()
              
              // Reload XP - Use the @State instance that the UI is observing
              let userId = await CurrentUser().idOrGuest // Always "" in guest mode
              // ✅ DIAGNOSTIC: Check if instances are the same
              let areSameInstance = xpManager === XPManager.shared
              print("🔄 [RELOAD] Loading XP for userId: '\(userId.isEmpty ? "EMPTY_STRING" : userId.prefix(8))...'")
              print("   xpManager === XPManager.shared: \(areSameInstance)")
              print("   xpManager.totalXP before load: \(xpManager.totalXP)")
              
              // ✅ FIX: Refresh DailyAwardService FIRST to ensure xpState is correct
              // This way the observer won't overwrite the loaded value
              print("🔄 [RELOAD] Refreshing DailyAwardService state first...")
              await DailyAwardService.shared.refreshXPState()
              
              // If DailyAwardService has the correct state, use it
              if let xpState = DailyAwardService.shared.xpState, xpState.totalXP > 0 {
                print("✅ [RELOAD] DailyAwardService has correct XP state: \(xpState.totalXP) - using it")
                // The observer will automatically apply this state
              } else {
                print("⚠️ [RELOAD] DailyAwardService state is nil or 0 - loading directly from SwiftData")
                // Use the @State instance that the UI is observing
                xpManager.loadUserXPFromSwiftData(
                  userId: userId,
                  modelContext: SwiftDataContainer.shared.modelContext
                )
              }
              
              // Verify the load worked
              print("   xpManager.totalXP after load: \(xpManager.totalXP)")
              print("   XPManager.shared.totalXP after load: \(XPManager.shared.totalXP)")
              
              // ✅ FORCE UI REFRESH - Ensure SwiftUI sees the updated data
              await MainActor.run {
                print("🔄 [UI_REFRESH] Forcing UI refresh...")
                habitRepository.objectWillChange.send()
                // XPManager is @Observable, so accessing properties should trigger update
                _ = xpManager.totalXP
                print("   ✅ objectWillChange.send() called for HabitRepository")
                print("   ✅ xpManager.totalXP accessed: \(xpManager.totalXP) - should trigger @Observable update")
              }
              
              print("✅ [RELOAD] Data reload complete")
            }

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

            // ✅ PRIORITY 0: Diagnose and migrate data from old anonymous users
            // This handles cases where Firebase created a new anonymous user, leaving old data inaccessible
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 500_000_000) // Wait for auth to complete
              await diagnoseAndMigrateOldUserData()
            }
            
            // ✅ PRIORITY 1: Fix userId mismatches FIRST to ensure data is visible
            // This fixes cases where CompletionRecords/DailyAwards were saved with wrong userId
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 500_000_000) // Wait for auth to complete
              await repairUserIdMismatches()
            }
            
            // ✅ PRIORITY 2: Run XP integrity check after data is loaded
            // This ensures XP data is consistent on every app launch
            // (Data is already loaded in the auth task above, so we can run this after a short delay)
            Task.detached { @MainActor in
              try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait for auth task to complete
              await performXPIntegrityCheck()
              
              // ✅ PRIORITY 3: Run CompletionRecord reconciliation after XP check
              // This ensures CompletionRecord.progress matches ProgressEvents (source of truth)
              Task.detached(priority: .background) { @MainActor in
                await performCompletionRecordReconciliation()
              }
              
              // ✅ PRIORITY 4: Run HabitStore data integrity validation
              // This ensures habit data structure is valid (e.g., no duplicate IDs)
              Task.detached(priority: .background) { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait for reconciliation to start
                await performDataIntegrityValidation()
              }
              
              // ✅ DEBUG: Run DailyAward integrity investigation on app launch (silent unless issues found)
              #if DEBUG
              Task.detached { @MainActor in
                // Wait for data to load
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                let userId = await CurrentUser().idOrGuest
                guard !CurrentUser.isGuestId(userId) else {
                  return // Silent skip for guest users
                }
                
                // Run investigation silently
                do {
                  let result = try await DailyAwardIntegrityService.shared.investigateDailyAwards(userId: userId)
                  
                  // Only log if issues are found
                  if !result.invalidAwards.isEmpty {
                    print("⚠️ [DAILY_AWARD_INTEGRITY] Found \(result.invalidAwards.count) invalid awards!")
                    DailyAwardIntegrityService.shared.printInvestigationReport(result)
                    
                    // ✅ FIX: Use time-based cleanup flag instead of one-time flag
                    // This allows cleanup to run again if invalid awards are detected after the last cleanup
                    let cleanupKey = "dailyAwardIntegrityCleanupLastRun_\(userId)"
                    let lastCleanupTimestamp = UserDefaults.standard.double(forKey: cleanupKey)
                    let lastCleanupDate = lastCleanupTimestamp > 0 ? Date(timeIntervalSince1970: lastCleanupTimestamp) : nil
                    let now = Date()
                    
                    // Only skip cleanup if it ran within the last hour (to prevent excessive cleanup)
                    let shouldSkipCleanup: Bool
                    if let lastCleanup = lastCleanupDate {
                      let timeSinceLastCleanup = now.timeIntervalSince(lastCleanup)
                      shouldSkipCleanup = timeSinceLastCleanup < 3600 // 1 hour
                    } else {
                      shouldSkipCleanup = false
                    }
                    
                    if !shouldSkipCleanup {
                      let _ = try await DailyAwardIntegrityService.shared.cleanupInvalidAwards(userId: userId)
                      
                      // Store timestamp of cleanup (time-based instead of one-time flag)
                      UserDefaults.standard.set(now.timeIntervalSince1970, forKey: cleanupKey)
                      print("✅ [DAILY_AWARD_INTEGRITY] Cleanup completed (timestamp stored - can run again after 1 hour if needed)")
                    } else {
                      let timeSinceLastCleanup = now.timeIntervalSince(lastCleanupDate!)
                      let minutesSince = Int(timeSinceLastCleanup / 60)
                      print("ℹ️ [DAILY_AWARD_INTEGRITY] Cleanup ran \(minutesSince) minute(s) ago - skipping to prevent excessive cleanup")
                      print("   Invalid awards detected but cleanup will run again after 1 hour if still present")
                      print("   Use DailyAwardIntegrityView to manually clean up immediately if needed")
                    }
                  }
                  // Silent success - no logging if all awards are valid
                } catch {
                  // Only log errors
                  print("❌ [DAILY_AWARD_INTEGRITY] Investigation failed: \(error.localizedDescription)")
                }
              }
              #endif
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
  
  // MARK: - Integrity Checks
  
  /// Repair userId mismatches on CompletionRecords and DailyAward records
  ///
  /// ✅ CRITICAL FIX: This fixes data loss issues where records were saved with wrong userId
  /// (e.g., empty string when user was guest, but now they're authenticated)
  ///
  /// Algorithm:
  /// 1. Get current userId
  /// 2. Find all CompletionRecords for current user's habits with mismatched userId
  /// Diagnoses all userIds in the database and migrates data from old anonymous users to the current user.
  /// This handles cases where Firebase creates a new anonymous user, leaving old data inaccessible.
  @MainActor
  private func diagnoseAndMigrateOldUserData() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "UserDataMigration")
    logger.info("🔍 User Data Migration: Starting diagnosis and migration...")
    
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      let currentUserId = await CurrentUser().idOrGuest
      logger.info("🔍 User Data Migration: Current userId: '\(currentUserId.isEmpty ? "guest" : currentUserId)'")
      
      // STEP 1: Diagnose all userIds in the database
      let allHabits = try modelContext.fetch(FetchDescriptor<HabitData>())
      let allCompletionRecords = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
      let allDailyAwards = try modelContext.fetch(FetchDescriptor<DailyAward>())
      
      let habitUserIds = Set(allHabits.map { $0.userId })
      let recordUserIds = Set(allCompletionRecords.map { $0.userId })
      let awardUserIds = Set(allDailyAwards.map { $0.userId })
      let allUserIds = habitUserIds.union(recordUserIds).union(awardUserIds)
      
      print("📊 [USER_MIGRATION] All userIds in database: \(Array(allUserIds).map { $0.isEmpty ? "EMPTY_STRING" : String($0.prefix(8)) + "..." })")
      
      for userId in allUserIds {
        let habitsForUser = allHabits.filter { $0.userId == userId }
        let recordsForUser = allCompletionRecords.filter { $0.userId == userId }
        let awardsForUser = allDailyAwards.filter { $0.userId == userId }
        
        let userIdDisplay = userId.isEmpty ? "EMPTY_STRING" : String(userId.prefix(8)) + "..."
        print("   📊 User \(userIdDisplay):")
        print("      - \(habitsForUser.count) habits")
        print("      - \(recordsForUser.count) CompletionRecords")
        print("      - \(awardsForUser.count) DailyAwards")
        
        // Check if this user has any progress data
        let recordsWithProgress = recordsForUser.filter { $0.progress > 0 }
        if recordsWithProgress.count > 0 {
          print("      - ⚠️ \(recordsWithProgress.count) CompletionRecords with progress > 0")
        }
      }
      
      // STEP 2: Identify old userIds that need migration
      let oldUserIds = allUserIds.filter { $0 != currentUserId && !$0.isEmpty }
      
      if oldUserIds.isEmpty {
        logger.info("✅ User Data Migration: No old userIds found - all data belongs to current user")
        return
      }
      
      logger.warning("⚠️ User Data Migration: Found \(oldUserIds.count) old userId(s) that need migration")
      for oldUserId in oldUserIds {
        logger.info("   Old userId: '\(oldUserId.prefix(8))...'")
      }
      
      // STEP 3: Migrate data from old userIds to current userId
      var totalMigrated = 0
      
      for oldUserId in oldUserIds {
        logger.info("🔄 User Data Migration: Migrating data from '\(oldUserId.prefix(8))...' to '\(currentUserId.isEmpty ? "guest" : currentUserId.prefix(8))...'")
        
        // Migrate HabitData
        let oldHabits = allHabits.filter { $0.userId == oldUserId }
        for habit in oldHabits {
          logger.info("   Migrating habit '\(habit.name)' (id: \(habit.id.uuidString.prefix(8))...)")
          habit.userId = currentUserId
          totalMigrated += 1
        }
        
        // Migrate CompletionRecords
        let oldRecords = allCompletionRecords.filter { $0.userId == oldUserId }
        for record in oldRecords {
          record.userId = currentUserId
          record.userIdHabitIdDateKey = "\(currentUserId)#\(record.habitId.uuidString)#\(record.dateKey)"
          totalMigrated += 1
        }
        
        // Migrate DailyAwards
        let oldAwards = allDailyAwards.filter { $0.userId == oldUserId }
        for award in oldAwards {
          award.userId = currentUserId
          award.userIdDateKey = "\(currentUserId)#\(award.dateKey)"
          totalMigrated += 1
        }
        
        logger.info("   ✅ Migrated \(oldHabits.count) habits, \(oldRecords.count) records, \(oldAwards.count) awards")
      }
      
      // STEP 4: Save all changes
      if totalMigrated > 0 {
        try modelContext.save()
        logger.info("✅ User Data Migration: Successfully migrated \(totalMigrated) records to current user")
        
        // Refresh data to show migrated records
        await DailyAwardService.shared.refreshXPState()
        await habitRepository.loadHabits(force: true)
        
        logger.info("✅ User Data Migration: Data refreshed - migrated data should now be visible")
      } else {
        logger.info("✅ User Data Migration: No data needed migration")
      }
      
    } catch {
      logger.error("❌ User Data Migration: Failed to migrate old user data: \(error.localizedDescription)")
      logger.error("   Error details: \(error)")
    }
    
    logger.info("✅ User Data Migration: Completed")
  }
  
  /// Repairs userId mismatches across HabitData, CompletionRecord, and DailyAward records.
  /// This is crucial for ensuring data visibility and integrity, especially after migrations or authentication changes.
  /// 
  /// Steps:
  /// 1. Find all HabitData records for current user
  /// 2. Find all CompletionRecords with mismatched userId but correct habitId
  /// 3. Find all DailyAward records with mismatched userId
  /// 4. Update userId and unique constraint keys to match current user
  /// 5. Save changes
  @MainActor
  private func repairUserIdMismatches() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "UserIdRepair")
    
    // Prevent multiple simultaneous repairs
    struct RepairLock {
      static var isRunning = false
    }
    
    guard !RepairLock.isRunning else {
      return
    }
    
    RepairLock.isRunning = true
    defer { RepairLock.isRunning = false }
    
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      let currentUserId = await CurrentUser().idOrGuest
      
      // Step 1: Find all HabitData for current user
      let habitPredicate = #Predicate<HabitData> { habit in
        habit.userId == currentUserId
      }
      let habitDescriptor = FetchDescriptor<HabitData>(predicate: habitPredicate)
      let userHabits = try modelContext.fetch(habitDescriptor)
      let userHabitIds = Set(userHabits.map { $0.id })
      
      // Step 2: Find all CompletionRecords for these habits with mismatched userId
      let allRecordsDescriptor = FetchDescriptor<CompletionRecord>()
      let allRecords = try modelContext.fetch(allRecordsDescriptor)
      
      var recordsFixed = 0
      for record in allRecords {
        // Check if this record belongs to one of the user's habits
        if userHabitIds.contains(record.habitId) && record.userId != currentUserId {
          record.userId = currentUserId
          record.userIdHabitIdDateKey = "\(currentUserId)#\(record.habitId.uuidString)#\(record.dateKey)"
          recordsFixed += 1
        }
      }
      
      // Step 3: Find all DailyAward records with mismatched userId
      // Strategy: If user has habits with completions on a date, and there's a DailyAward for that date
      // with wrong userId, it's likely the user's award
      let allAwardsDescriptor = FetchDescriptor<DailyAward>()
      let allAwards = try modelContext.fetch(allAwardsDescriptor)
      
      // Get all dateKeys where user has completed habits
      var userCompletionDates = Set<String>()
      for record in allRecords {
        if userHabitIds.contains(record.habitId) && record.isCompleted {
          userCompletionDates.insert(record.dateKey)
        }
      }
      
      var awardsFixed = 0
      for award in allAwards {
        if award.userId != currentUserId {
          // Check if this award date matches one of the user's completion dates
          if userCompletionDates.contains(award.dateKey) {
            // This award is for a date where the user has completions, so it's likely the user's award
            award.userId = currentUserId
            award.userIdDateKey = "\(currentUserId)#\(award.dateKey)"
            awardsFixed += 1
          } else if currentUserId.isEmpty && award.userId.isEmpty {
            // Both are guest - ensure they use consistent empty string
            // (no change needed, but ensure userIdDateKey is correct)
            award.userIdDateKey = "\(currentUserId)#\(award.dateKey)"
          }
        }
      }
      
      // Step 4: Save all changes
      if recordsFixed > 0 || awardsFixed > 0 {
        try modelContext.save()
        
        // Refresh XP state to reflect the fixes
        await DailyAwardService.shared.refreshXPState()
        
        // Refresh habits to show the fixed completion records
        Task {
          await habitRepository.loadHabits()
        }
      } else {
        logger.info("✅ UserId Repair: No userId mismatches found - all records are correct")
      }
      
    } catch {
      logger.error("❌ UserId Repair: Failed to repair userId mismatches: \(error.localizedDescription)")
      logger.error("   Error details: \(error)")
    }
    
    logger.info("✅ UserId Repair: Completed")
  }
  
  /// Perform XP integrity check and auto-repair on app launch
  ///
  /// ✅ PRIORITY 2: Ensures XP data integrity by verifying that
  /// UserProgressData.totalXP == sum(DailyAward.xpGranted).
  ///
  /// Runs in background to avoid blocking app startup.
  /// Automatically repairs any mismatches found.
  @MainActor
  private func performXPIntegrityCheck() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "XPIntegrityCheck")
    
    logger.info("🔍 XP Integrity Check: Starting automatic integrity check on app launch...")
    
    // Prevent multiple simultaneous checks
    struct IntegrityCheckLock {
      static var isRunning = false
    }
    
    guard !IntegrityCheckLock.isRunning else {
      logger.info("⏭️ XP Integrity Check: Already running, skipping duplicate check")
      return
    }
    
    IntegrityCheckLock.isRunning = true
    defer { IntegrityCheckLock.isRunning = false }
    
    do {
      // Get current XP state before check (for comparison if repair is needed)
      let awardService = DailyAwardService.shared
      let xpStateBefore = awardService.xpState
      let totalXPBefore = xpStateBefore?.totalXP ?? 0
      
      logger.info("🔍 XP Integrity Check: Current XP state - Total: \(totalXPBefore), Level: \(xpStateBefore?.level ?? 1)")
      
      // Perform integrity check and auto-repair
      let wasValid = try await awardService.checkAndRepairIntegrity()
      
      if wasValid {
        // Get XP state after check
        let xpStateAfter = awardService.xpState
        let totalXPAfter = xpStateAfter?.totalXP ?? 0
        
        if totalXPBefore != totalXPAfter {
          // Repair was performed
          logger.info("✅ XP Integrity Check: Integrity repaired successfully")
          logger.info("   Before: Total XP = \(totalXPBefore), Level = \(xpStateBefore?.level ?? 1)")
          logger.info("   After:  Total XP = \(totalXPAfter), Level = \(xpStateAfter?.level ?? 1)")
          logger.info("   Delta:  \(totalXPAfter - totalXPBefore) XP")
          
          // TODO: Consider adding user notification if repair was significant
          // if abs(totalXPAfter - totalXPBefore) > 50 {
          //   // Notify user of significant repair
          // }
        } else {
          // Integrity was already valid
          logger.info("✅ XP Integrity Check: Integrity verified - no repair needed")
          logger.info("   Total XP: \(totalXPAfter), Level: \(xpStateAfter?.level ?? 1)")
        }
      } else {
        logger.warning("⚠️ XP Integrity Check: Integrity check returned false (unexpected)")
      }
      
    } catch {
      // Handle errors gracefully - don't crash app
      logger.error("❌ XP Integrity Check: Failed to perform integrity check: \(error.localizedDescription)")
      logger.error("   Error details: \(error)")
      
      // Log error to Crashlytics for monitoring (if available)
      #if canImport(FirebaseCrashlytics)
      Crashlytics.crashlytics().record(error: error)
      #endif
      
      // Continue app launch even if integrity check fails
      // User can manually trigger repair if needed
    }
    
    logger.info("✅ XP Integrity Check: Completed")
  }
  
  /// Perform CompletionRecord reconciliation on app launch
  ///
  /// ✅ PRIORITY 3: Ensures CompletionRecord.progress matches ProgressEvents.
  /// Runs in background to avoid blocking app startup.
  @MainActor
  private func performCompletionRecordReconciliation() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "CompletionRecordReconciliation")
    
    logger.info("🔧 CompletionRecord Reconciliation: Starting automatic reconciliation on app launch...")
    
    // Prevent multiple simultaneous reconciliations
    struct ReconciliationLock {
      static var isRunning = false
    }
    
    guard !ReconciliationLock.isRunning else {
      logger.info("⏭️ CompletionRecord Reconciliation: Already running, skipping duplicate reconciliation")
      return
    }
    
    ReconciliationLock.isRunning = true
    defer { ReconciliationLock.isRunning = false }
    
    do {
      let result = try await DailyAwardService.shared.reconcileCompletionRecords()
      
      if result.mismatchesFixed > 0 {
        logger.info("✅ CompletionRecord Reconciliation: Fixed \(result.mismatchesFixed) mismatches")
        logger.info("   Total checked: \(result.totalRecords), Mismatches found: \(result.mismatchesFound), Errors: \(result.errors)")
      } else {
        logger.info("✅ CompletionRecord Reconciliation: All records are consistent (no repairs needed)")
        logger.info("   Total checked: \(result.totalRecords), Errors: \(result.errors)")
      }
      
    } catch {
      // Handle errors gracefully - don't crash app
      logger.error("❌ CompletionRecord Reconciliation: Failed to reconcile: \(error.localizedDescription)")
      logger.error("   Error details: \(error)")
      
      // Log error to Crashlytics for monitoring (if available)
      #if canImport(FirebaseCrashlytics)
      Crashlytics.crashlytics().record(error: error)
      #endif
      
      // Continue app launch even if reconciliation fails
    }
    
    logger.info("✅ CompletionRecord Reconciliation: Completed")
  }
  
  /// Perform HabitStore data integrity validation on app launch
  ///
  /// ✅ PRIORITY 4: Ensures habit data structure is valid (e.g., no duplicate IDs).
  /// Runs in background to avoid blocking app startup.
  @MainActor
  private func performDataIntegrityValidation() async {
    print("🔍🔍🔍 DATA INTEGRITY VALIDATION STARTING 🔍🔍🔍")
    
    let logger = Logger(subsystem: "com.habitto.app", category: "DataIntegrityValidation")
    
    logger.info("🔍 Data Integrity Validation: Starting automatic validation on app launch...")
    
    // Prevent multiple simultaneous validations
    struct ValidationLock {
      static var isRunning = false
    }
    
    guard !ValidationLock.isRunning else {
      logger.info("⏭️ Data Integrity Validation: Already running, skipping duplicate validation")
      return
    }
    
    ValidationLock.isRunning = true
    defer { ValidationLock.isRunning = false }
    
    do {
      let isValid = try await HabitStore.shared.validateDataIntegrity()
      
      if isValid {
        logger.info("✅ Data Integrity Validation: All checks passed - no issues found")
      } else {
        logger.warning("⚠️ Data Integrity Validation: Issues detected (check logs for details)")
        // Non-fatal - log warning but don't crash the app
        // The validation method already logs specific issues (e.g., duplicate IDs)
      }
      
    } catch {
      // Handle errors gracefully - don't crash app
      logger.error("❌ Data Integrity Validation: Failed to validate: \(error.localizedDescription)")
      logger.error("   Error details: \(error)")
      
      // Log error to Crashlytics for monitoring (if available)
      #if canImport(FirebaseCrashlytics)
      Crashlytics.crashlytics().record(error: error)
      #endif
      
      // Continue app launch even if validation fails
      // User can manually trigger validation if needed
    }
    
    logger.info("✅ Data Integrity Validation: Completed")
  }
  
  // MARK: - Guest Data Migration
  
  /// Migrate guest data (userId = "") to anonymous user
  /// This runs automatically after anonymous auth is established
  @MainActor
  private func migrateGuestDataToAnonymousUser() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "GuestMigration")
    
    // Check if user is authenticated (anonymous or otherwise)
    guard let currentUser = authManager.currentUser else {
      logger.debug("⏭️ GuestMigration: No authenticated user, skipping migration")
      print("⏭️ [GUEST_MIGRATION] No authenticated user, skipping migration")
      return
    }
    
    let newUserId = currentUser.uid
    
    // ✅ NEW: Use a new migration flag for the complete migration
    // OLD flag: "guest_to_anonymous_migrated_{userId}" (habits only - legacy)
    // NEW flag: "guest_to_anonymous_complete_migrated_{userId}" (all data)
    let oldMigrationKey = "guest_to_anonymous_migrated_\(newUserId)"
    let newMigrationKey = "guest_to_anonymous_complete_migrated_\(newUserId)"
    
    // ✅ DIAGNOSTIC: Log migration status BEFORE checking flags
    print("🔍 [GUEST_MIGRATION] Checking migration status for user: \(newUserId.prefix(8))...")
    logger.info("🔍 GuestMigration: Checking migration status for user \(newUserId.prefix(8))...")
    
    let oldFlagSet = UserDefaults.standard.bool(forKey: oldMigrationKey)
    let newFlagSet = UserDefaults.standard.bool(forKey: newMigrationKey)
    
    print("   Old migration flag (habits only): \(oldFlagSet ? "✅ TRUE" : "❌ FALSE")")
    print("   New migration flag (complete): \(newFlagSet ? "✅ TRUE" : "❌ FALSE")")
    logger.info("   Old migration flag: \(oldFlagSet), New migration flag: \(newFlagSet)")
    
    // Check if complete migration already completed
    // ✅ CRITICAL FIX: Even if flag is set, check for orphaned data and repair if needed
    if newFlagSet {
      // Check if there's orphaned data that needs repair
      do {
        let modelContext = SwiftDataContainer.shared.modelContext
        
        print("🔍 [ORPHANED_DATA_CHECK] Checking for orphaned data (migration flag already set)...")
        logger.info("🔍 GuestMigration: Checking for orphaned data (migration flag already set)")
        
        // Get user's habits
        let userHabitsDescriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate<HabitData> { habit in
            habit.userId == newUserId
          }
        )
        let userHabits = try modelContext.fetch(userHabitsDescriptor)
        let userHabitIds = Set(userHabits.map { $0.id })
        
        print("🔍 [ORPHANED_DATA_CHECK] Found \(userHabits.count) habits for current user")
        print("   User ID: \(newUserId.prefix(8))...")
        logger.info("🔍 GuestMigration: Found \(userHabits.count) habits for user \(newUserId.prefix(8))...")
        
        // Check for orphaned CompletionRecords
        let allCompletionsDescriptor = FetchDescriptor<CompletionRecord>()
        let allCompletions = try modelContext.fetch(allCompletionsDescriptor)
        let orphanedCompletions = allCompletions.filter { record in
          userHabitIds.contains(record.habitId) && record.userId != newUserId
        }
        
        // Group orphaned completions by old userId for logging
        let completionsByOldUserId = Dictionary(grouping: orphanedCompletions) { $0.userId }
        print("📊 [ORPHANED_DATA_CHECK] Orphaned CompletionRecords: \(orphanedCompletions.count)")
        for (oldUserId, records) in completionsByOldUserId.sorted(by: { $0.key < $1.key }) {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          print("   → \(records.count) records with userId '\(oldUserIdDisplay)'")
        }
        logger.info("📊 GuestMigration: Found \(orphanedCompletions.count) orphaned CompletionRecords")
        
        // Check for orphaned DailyAwards
        let allAwardsDescriptor = FetchDescriptor<DailyAward>()
        let allAwards = try modelContext.fetch(allAwardsDescriptor)
        let orphanedAwards = allAwards.filter { $0.userId != newUserId }
        
        // Calculate total XP from orphaned awards
        let totalOrphanedXP = orphanedAwards.reduce(0) { $0 + $1.xpGranted }
        
        // Group orphaned awards by old userId for logging
        let awardsByOldUserId = Dictionary(grouping: orphanedAwards) { $0.userId }
        print("📊 [ORPHANED_DATA_CHECK] Orphaned DailyAwards: \(orphanedAwards.count)")
        print("   Total XP from orphaned awards: \(totalOrphanedXP)")
        for (oldUserId, awards) in awardsByOldUserId.sorted(by: { $0.key < $1.key }) {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          let xp = awards.reduce(0) { $0 + $1.xpGranted }
          print("   → \(awards.count) awards with userId '\(oldUserIdDisplay)' (XP: \(xp))")
        }
        logger.info("📊 GuestMigration: Found \(orphanedAwards.count) orphaned DailyAwards with \(totalOrphanedXP) total XP")
        
        // Check for orphaned UserProgressData
        let allProgressDescriptor = FetchDescriptor<UserProgressData>()
        let allProgress = try modelContext.fetch(allProgressDescriptor)
        let orphanedProgress = allProgress.filter { $0.userId != newUserId }
        
        print("📊 [ORPHANED_DATA_CHECK] Orphaned UserProgressData: \(orphanedProgress.count)")
        for progress in orphanedProgress {
          let oldUserIdDisplay = progress.userId.isEmpty ? "EMPTY STRING" : "\(progress.userId.prefix(8))..."
          print("   → Progress with userId '\(oldUserIdDisplay)' (XP: \(progress.xpTotal), Level: \(progress.level))")
        }
        logger.info("📊 GuestMigration: Found \(orphanedProgress.count) orphaned UserProgressData records")
        
        // If orphaned data exists, run repair migration
        if !orphanedCompletions.isEmpty || !orphanedAwards.isEmpty || !orphanedProgress.isEmpty {
          print("⚠️ [ORPHANED_DATA_CHECK] Orphaned data detected! Summary:")
          print("   ✅ Orphaned CompletionRecords: \(orphanedCompletions.count)")
          print("   ✅ Orphaned DailyAwards: \(orphanedAwards.count) (Total XP: \(totalOrphanedXP))")
          print("   ✅ Orphaned UserProgressData: \(orphanedProgress.count)")
          print("   🔄 Running repair migration...")
          logger.warning("⚠️ GuestMigration: Orphaned data detected - \(orphanedCompletions.count) completions, \(orphanedAwards.count) awards (\(totalOrphanedXP) XP), \(orphanedProgress.count) progress")
          
          // Run repair migration (it will only migrate orphaned data, not re-migrate everything)
          await GuestDataMigrationHelper.runCompleteMigration(userId: newUserId)
          return
        } else {
          print("✅ [ORPHANED_DATA_CHECK] No orphaned data found - migration complete")
          logger.debug("⏭️ GuestMigration: Complete migration already done for user \(newUserId.prefix(8))...")
          print("⏭️ [GUEST_MIGRATION] Complete migration already done, skipping")
          return
        }
      } catch {
        // If check fails, log and skip (don't block app startup)
        logger.warning("⚠️ GuestMigration: Error checking for orphaned data: \(error.localizedDescription)")
        print("⚠️ [ORPHANED_DATA_CHECK] Error checking for orphaned data: \(error.localizedDescription)")
        print("⚠️ [GUEST_MIGRATION] Error checking for orphaned data, skipping migration check")
        return
      }
    }
    
    // ✅ DIAGNOSTIC: Check ALL data in database BEFORE migration
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      print("🔍 [DIAGNOSTIC] Starting comprehensive data audit...")
      logger.info("🔍 GuestMigration: Starting comprehensive data audit...")
      
      // Query ALL CompletionRecords regardless of userId
      let allCompletionsDescriptor = FetchDescriptor<CompletionRecord>()
      let allCompletions = try modelContext.fetch(allCompletionsDescriptor)
      print("🔍 [DIAGNOSTIC] Total CompletionRecords in database: \(allCompletions.count)")
      logger.info("🔍 GuestMigration: Total CompletionRecords: \(allCompletions.count)")
      
      // Group by userId
      let completionsByUserId = Dictionary(grouping: allCompletions) { $0.userId }
      print("🔍 [DIAGNOSTIC] CompletionRecords grouped by userId:")
      for (userId, records) in completionsByUserId.sorted(by: { $0.key < $1.key }) {
        let userIdDisplay = userId.isEmpty ? "EMPTY STRING" : "\(userId.prefix(8))..."
        print("   UserId: '\(userIdDisplay)' - \(records.count) records")
        logger.info("   CompletionRecords - UserId: '\(userIdDisplay)': \(records.count) records")
      }
      
      // Query ALL DailyAwards regardless of userId
      let allAwardsDescriptor = FetchDescriptor<DailyAward>()
      let allAwards = try modelContext.fetch(allAwardsDescriptor)
      print("🔍 [DIAGNOSTIC] Total DailyAwards in database: \(allAwards.count)")
      logger.info("🔍 GuestMigration: Total DailyAwards: \(allAwards.count)")
      
      // Group by userId
      let awardsByUserId = Dictionary(grouping: allAwards) { $0.userId }
      print("🔍 [DIAGNOSTIC] DailyAwards grouped by userId:")
      for (userId, awards) in awardsByUserId.sorted(by: { $0.key < $1.key }) {
        let userIdDisplay = userId.isEmpty ? "EMPTY STRING" : "\(userId.prefix(8))..."
        var totalXP = 0
        for award in awards {
          totalXP += award.xpGranted
        }
        print("   UserId: '\(userIdDisplay)' - \(awards.count) awards (Total XP: \(totalXP))")
        logger.info("   DailyAwards - UserId: '\(userIdDisplay)': \(awards.count) awards, \(totalXP) XP")
      }
      
      // Query ALL UserProgressData regardless of userId
      let allProgressDescriptor = FetchDescriptor<UserProgressData>()
      let allProgress = try modelContext.fetch(allProgressDescriptor)
      print("🔍 [DIAGNOSTIC] Total UserProgressData in database: \(allProgress.count)")
      logger.info("🔍 GuestMigration: Total UserProgressData: \(allProgress.count)")
      
      for progress in allProgress {
        let userIdDisplay = progress.userId.isEmpty ? "EMPTY STRING" : "\(progress.userId.prefix(8))..."
        print("   UserId: '\(userIdDisplay)' - XP: \(progress.xpTotal), Level: \(progress.level), Streak: \(progress.streakDays)")
        logger.info("   UserProgressData - UserId: '\(userIdDisplay)': XP=\(progress.xpTotal), Level=\(progress.level), Streak=\(progress.streakDays)")
      }
      
      // Query ALL HabitData regardless of userId
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabits = try modelContext.fetch(allHabitsDescriptor)
      print("🔍 [DIAGNOSTIC] Total HabitData in database: \(allHabits.count)")
      logger.info("🔍 GuestMigration: Total HabitData: \(allHabits.count)")
      
      // Group by userId
      let habitsByUserId = Dictionary(grouping: allHabits) { $0.userId }
      print("🔍 [DIAGNOSTIC] HabitData grouped by userId:")
      for (userId, habits) in habitsByUserId.sorted(by: { $0.key < $1.key }) {
        let userIdDisplay = userId.isEmpty ? "EMPTY STRING" : "\(userId.prefix(8))..."
        print("   UserId: '\(userIdDisplay)' - \(habits.count) habits")
        logger.info("   HabitData - UserId: '\(userIdDisplay)': \(habits.count) habits")
      }
      
      // Now try predicate-based queries
      print("🔍 [DIAGNOSTIC] Testing predicate-based queries for userId = \"\"...")
      
      let guestHabitsDescriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { habit in
          habit.userId == ""
        }
      )
      let guestHabits = try modelContext.fetch(guestHabitsDescriptor)
      
      let guestCompletionRecordsDescriptor = FetchDescriptor<CompletionRecord>(
        predicate: #Predicate<CompletionRecord> { record in
          record.userId == ""
        }
      )
      let guestCompletionRecords = try modelContext.fetch(guestCompletionRecordsDescriptor)
      
      let guestAwardsDescriptor = FetchDescriptor<DailyAward>(
        predicate: #Predicate<DailyAward> { award in
          award.userId == ""
        }
      )
      let guestAwards = try modelContext.fetch(guestAwardsDescriptor)
      
      let guestProgressDescriptor = FetchDescriptor<UserProgressData>(
        predicate: #Predicate<UserProgressData> { progress in
          progress.userId == ""
        }
      )
      let guestProgress = try modelContext.fetch(guestProgressDescriptor)
      
      print("📊 [GUEST_MIGRATION] Predicate query results (userId = \"\"):")
      print("   Guest Habits: \(guestHabits.count)")
      print("   Guest Completion Records: \(guestCompletionRecords.count)")
      print("   Guest Daily Awards: \(guestAwards.count)")
      print("   Guest User Progress: \(guestProgress.count)")
      logger.info("📊 GuestMigration: Predicate results - \(guestHabits.count) habits, \(guestCompletionRecords.count) completions, \(guestAwards.count) awards, \(guestProgress.count) progress")
      
      // ✅ FALLBACK: Use code-based filtering if predicate returns 0 but we know data exists
      let guestCompletionsFiltered = allCompletions.filter { $0.userId.isEmpty }
      let guestAwardsFiltered = allAwards.filter { $0.userId.isEmpty }
      let guestProgressFiltered = allProgress.filter { $0.userId.isEmpty }
      let guestHabitsFiltered = allHabits.filter { $0.userId.isEmpty }
      
      if guestCompletionsFiltered.count != guestCompletionRecords.count ||
         guestAwardsFiltered.count != guestAwards.count ||
         guestProgressFiltered.count != guestProgress.count ||
         guestHabitsFiltered.count != guestHabits.count {
        print("⚠️ [DIAGNOSTIC] PREDICATE MISMATCH DETECTED!")
        print("   Predicate vs Filtered results:")
        print("   Completions: \(guestCompletionRecords.count) (predicate) vs \(guestCompletionsFiltered.count) (filtered)")
        print("   Awards: \(guestAwards.count) (predicate) vs \(guestAwardsFiltered.count) (filtered)")
        print("   Progress: \(guestProgress.count) (predicate) vs \(guestProgressFiltered.count) (filtered)")
        print("   Habits: \(guestHabits.count) (predicate) vs \(guestHabitsFiltered.count) (filtered)")
        logger.warning("⚠️ GuestMigration: Predicate mismatch detected - using filtered results")
      }
      
      // Use filtered results if they differ from predicate results
      let finalGuestCompletions = guestCompletionsFiltered.isEmpty ? guestCompletionRecords : guestCompletionsFiltered
      let finalGuestAwards = guestAwardsFiltered.isEmpty ? guestAwards : guestAwardsFiltered
      let finalGuestProgress = guestProgressFiltered.isEmpty ? guestProgress : guestProgressFiltered
      let finalGuestHabits = guestHabitsFiltered.isEmpty ? guestHabits : guestHabitsFiltered
      
      print("📊 [GUEST_MIGRATION] Final guest data to migrate:")
      print("   Guest Habits: \(finalGuestHabits.count)")
      print("   Guest Completion Records: \(finalGuestCompletions.count)")
      print("   Guest Daily Awards: \(finalGuestAwards.count)")
      print("   Guest User Progress: \(finalGuestProgress.count)")
      
      // If no guest data exists, mark migration as complete and return
      if finalGuestHabits.isEmpty && finalGuestCompletions.isEmpty && finalGuestAwards.isEmpty && finalGuestProgress.isEmpty {
        print("ℹ️ [GUEST_MIGRATION] No guest data found, marking migration as complete")
        UserDefaults.standard.set(true, forKey: newMigrationKey)
        return
      }
      
      // Store filtered results for use in migration
      // We'll pass these to the helper if predicate failed
      if finalGuestCompletions.count > guestCompletionRecords.count ||
         finalGuestAwards.count > guestAwards.count ||
         finalGuestProgress.count > guestProgress.count {
        print("⚠️ [GUEST_MIGRATION] Using code-filtered results instead of predicate results")
        logger.warning("⚠️ GuestMigration: Using code-filtered results due to predicate mismatch")
      }
      
    } catch {
      print("⚠️ [GUEST_MIGRATION] Error checking for guest data: \(error.localizedDescription)")
      logger.warning("⚠️ GuestMigration: Error checking for guest data: \(error.localizedDescription)")
    }
    
    print("🔄 [GUEST_MIGRATION] Starting COMPLETE migration to anonymous user")
    print("   Target User ID: \(newUserId)")
    logger.info("🔄 GuestMigration: Starting COMPLETE migration to anonymous user \(newUserId.prefix(8))...")
    
    // Delegate to the helper class for the actual migration logic
    await GuestDataMigrationHelper.runCompleteMigration(userId: newUserId)
    
    // The helper already sets the migration flag, so trigger backup
    print("🔄 [GUEST_MIGRATION] Starting backup of migrated data to Firestore...")
    Task.detached { @MainActor in
      await backupMigratedGuestData(userId: newUserId)
    }
  }
  
  /// Backup migrated guest data to Firestore
  @MainActor
  private func backupMigratedGuestData(userId: String) async {
    let logger = Logger(subsystem: "com.habitto.app", category: "GuestMigration")
    print("🔄 [GUEST_MIGRATION] Backing up migrated data to Firestore...")
    logger.info("🔄 GuestMigration: Starting backup of migrated data...")
    
    // Load habits and backup them
    do {
      let habits = try await HabitStore.shared.loadHabits()
      print("🔄 [GUEST_MIGRATION] Backing up \(habits.count) migrated habits...")
      for habit in habits {
        await MainActor.run {
          FirebaseBackupService.shared.backupHabit(habit)
        }
      }
      print("✅ [GUEST_MIGRATION] Backup complete - \(habits.count) habits queued for backup")
      logger.info("✅ GuestMigration: Backed up \(habits.count) habits to Firestore")
    } catch {
      print("❌ [GUEST_MIGRATION] Backup failed: \(error.localizedDescription)")
      logger.warning("⚠️ GuestMigration: Failed to backup habits: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Helper Functions
  
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
      // ✅ FIX: Use the @State instance that the UI is observing
      Task.detached { @MainActor in
        let modelContext = SwiftDataContainer.shared.modelContext
        // Use the instance from the app's @State, not XPManager.shared
        // We need to access it through the app instance, but since we're in a static context,
        // we'll update both to ensure consistency
        XPManager.shared.loadUserXPFromSwiftData(userId: user.uid, modelContext: modelContext)
        // Note: The @State xpManager should be the same instance as XPManager.shared
        // but we'll verify this in the reload code above
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
  
  // MARK: - Diagnostic Functions
  
  /// Complete data diagnosis - shows the full state of the database
  @MainActor
  private func diagnoseDataIssue() async {
    print(String(repeating: "=", count: 80))
    print("📊 STARTING COMPLETE DATA DIAGNOSIS")
    print(String(repeating: "=", count: 80))
    
    let context = SwiftDataContainer.shared.modelContext
    let currentUserId = await CurrentUser().idOrGuest // Always "" in guest mode
    
    print("\n🔍 Current userId (guest mode): '\(currentUserId.isEmpty ? "EMPTY_STRING" : currentUserId)'")
    
    // 1. Check habits
    do {
      let habitsDesc = FetchDescriptor<HabitData>()
      let allHabits = try context.fetch(habitsDesc)
      // DIAGNOSIS logs removed for cleaner console output
      
      // Habit detail logs removed for cleaner console output
      
      // 2. Check CompletionRecords
      let recordsDesc = FetchDescriptor<CompletionRecord>()
      let allRecords = try context.fetch(recordsDesc)
      // DIAGNOSIS logs removed for cleaner console output
      
      // 4. Check UserProgressData
      let xpDesc = FetchDescriptor<UserProgressData>()
      let allXP = try context.fetch(xpDesc)
      // DIAGNOSIS logs removed for cleaner console output
      for xp in allXP {
        let userIdDisplay = xp.userId.isEmpty ? "EMPTY STRING" : "\(xp.userId.prefix(8))..."
        print("   userId: '\(userIdDisplay)', XP: \(xp.xpTotal), Level: \(xp.level), Streak: \(xp.streakDays)")
      }
      
      // 5. Check DailyAwards
      let awardsDesc = FetchDescriptor<DailyAward>()
      let allAwards = try context.fetch(awardsDesc)
      // DIAGNOSIS logs removed for cleaner console output
      let awardsByUserId = Dictionary(grouping: allAwards, by: { $0.userId })
      for (userId, awards) in awardsByUserId.sorted(by: { $0.key < $1.key }) {
        let totalXP = awards.reduce(0) { $0 + $1.xpGranted }
        let userIdDisplay = userId.isEmpty ? "EMPTY STRING" : "\(userId.prefix(8))..."
        print("   userId '\(userIdDisplay)': \(awards.count) awards, Total XP: \(totalXP)")
      }
      
      // 6. Check what the app will actually load
      // DIAGNOSIS logs removed for cleaner console output
      if currentUserId != "nil" {
        let habitsForUser = allHabits.filter { $0.userId == currentUserId }
        let recordsForUser = allRecords.filter { $0.userId == currentUserId }
        let xpForUser = allXP.filter { $0.userId == currentUserId }
        let awardsForUser = allAwards.filter { $0.userId == currentUserId }
        
        print("   Habits: \(habitsForUser.count)")
        print("   CompletionRecords: \(recordsForUser.count)")
        print("   UserProgressData: \(xpForUser.count)")
        print("   DailyAwards: \(awardsForUser.count)")
        
        if habitsForUser.isEmpty && !allHabits.isEmpty {
          print("   ⚠️ WARNING: No habits found for current userId, but \(allHabits.count) habits exist with other userIds")
        }
        if recordsForUser.isEmpty && !allRecords.isEmpty {
          print("   ⚠️ WARNING: No CompletionRecords found for current userId, but \(allRecords.count) records exist with other userIds")
        }
        if awardsForUser.isEmpty && !allAwards.isEmpty {
          print("   ⚠️ WARNING: No DailyAwards found for current userId, but \(allAwards.count) awards exist with other userIds")
        }
      } else {
        print("   ⚠️ WARNING: No authenticated user - will query for userId = \"\"")
        let guestHabits = allHabits.filter { $0.userId.isEmpty }
        let guestRecords = allRecords.filter { $0.userId.isEmpty }
        let guestXP = allXP.filter { $0.userId.isEmpty }
        let guestAwards = allAwards.filter { $0.userId.isEmpty }
        
        print("   Guest habits (userId = \"\"): \(guestHabits.count)")
        print("   Guest CompletionRecords (userId = \"\"): \(guestRecords.count)")
        print("   Guest UserProgressData (userId = \"\"): \(guestXP.count)")
        print("   Guest DailyAwards (userId = \"\"): \(guestAwards.count)")
      }
      
    } catch {
      print("❌ DIAGNOSIS ERROR: \(error.localizedDescription)")
      print("   Error details: \(error)")
    }
    
    print("\n" + String(repeating: "=", count: 80))
    print("📊 DIAGNOSIS COMPLETE")
    print(String(repeating: "=", count: 80))
  }
  
  /// Check if progress restoration is needed by checking for CompletionRecords with progress=0
  @MainActor
  private func checkIfNeedsProgressRestore() async -> Bool {
    let context = SwiftDataContainer.shared.modelContext
    let userId = await CurrentUser().idOrGuest
    
    do {
      // Check if any CompletionRecords have progress=0
      let predicate = #Predicate<CompletionRecord> { record in
        record.userId == userId && record.progress == 0
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      let recordsWithZeroProgress = try context.fetch(descriptor)
      
      if !recordsWithZeroProgress.isEmpty {
        print("🔍 [RESTORE_CHECK] Found \(recordsWithZeroProgress.count) CompletionRecords with progress=0 - restore needed")
        return true
      } else {
        print("✅ [RESTORE_CHECK] All CompletionRecords have progress > 0 - no restore needed")
        return false
      }
    } catch {
      print("⚠️ [RESTORE_CHECK] Failed to check CompletionRecords: \(error.localizedDescription)")
      // If check fails, assume restore is needed (safe default)
      return true
    }
  }
  
  /// Restore progress data from Firestore backups
  /// This repairs CompletionRecords that have progress=0 by restoring from Firestore
  @MainActor
  private func restoreProgressFromFirestore() async {
    print("🔧 [RESTORE] Starting progress restoration from Firestore...")
    
    // ✅ GUEST MODE: Firestore restore requires authentication
    // In guest mode, we can't restore from Firestore, so skip it
    print("ℹ️ [RESTORE] Guest mode - Firestore restore requires authentication, skipping")
  }
  
  /// Check UserDefaults for any backup data that might help recover progress
  @MainActor
  private func checkUserDefaultsForRecovery() async {
    print("🔍 [RECOVERY] Checking UserDefaults for backup data...")
    
    // Check common UserDefaults keys
    let possibleKeys = ["SavedHabits", "guest_habits", "habits", "user_progress"]
    
    for key in possibleKeys {
      if let data = UserDefaults.standard.data(forKey: key) {
        print("   ✅ Found data in UserDefaults key: \(key) (size: \(data.count) bytes)")
        
        if key == "user_progress" {
          // Try to decode as UserProgress
          if let progress = try? JSONDecoder().decode(UserProgress.self, from: data) {
            print("   📊 UserProgress found: totalXP=\(progress.totalXP), level=\(progress.currentLevel)")
            if progress.totalXP > 0 {
              print("   ⚠️ UserProgress has XP but CompletionRecords don't - data mismatch detected")
            }
          }
        } else {
          // Try to decode as habits
          if let habits = try? JSONDecoder().decode([Habit].self, from: data) {
            print("   📊 Found \(habits.count) habits in UserDefaults")
            var totalProgressEntries = 0
            var totalNonZeroProgress = 0
            for habit in habits {
              for (_, progress) in habit.completionHistory {
                totalProgressEntries += 1
                if progress > 0 {
                  totalNonZeroProgress += 1
                }
              }
            }
            print("   📊 Total progress entries: \(totalProgressEntries), Non-zero: \(totalNonZeroProgress)")
            if totalNonZeroProgress > 0 {
              print("   ⚠️ UserDefaults has progress data but SwiftData doesn't - potential recovery source")
              print("   💡 However, UserDefaults data may be outdated - use with caution")
            }
          }
        }
      }
    }
    
    print("🔍 [RECOVERY] UserDefaults check complete")
  }
  
  /// Repair broken CompletionRecord relationships
  /// The migration updated userId on CompletionRecords but broke the SwiftData relationship links
  @MainActor
  private func repairCompletionRecordRelationships() async {
    print("🔧 [REPAIR] Starting relationship repair...")
    
    let context = SwiftDataContainer.shared.modelContext
    
    do {
      // Get all habits
      let habitsDesc = FetchDescriptor<HabitData>()
      let allHabits = try context.fetch(habitsDesc)
      
      // Get all completion records
      let recordsDesc = FetchDescriptor<CompletionRecord>()
      let allRecords = try context.fetch(recordsDesc)
      
      print("🔧 [REPAIR] Found \(allHabits.count) habits and \(allRecords.count) completion records")
      
      // Group records by habitId
      let recordsByHabit = Dictionary(grouping: allRecords, by: { $0.habitId })
      
      var totalRepaired = 0
      
      // For each habit, reconnect its completion records
      for habit in allHabits {
        let recordsForThisHabit = recordsByHabit[habit.id] ?? []
        
        // Only repair if there's a mismatch
        if recordsForThisHabit.count != habit.completionHistory.count {
          print("🔧 [REPAIR] Habit '\(habit.name)': Found \(recordsForThisHabit.count) records, but only \(habit.completionHistory.count) linked")
          
          // Clear existing relationship (which is empty anyway)
          habit.completionHistory.removeAll()
          
          // Add all matching records back to the relationship
          for record in recordsForThisHabit {
            habit.completionHistory.append(record)
          }
          
          print("🔧 [REPAIR] Habit '\(habit.name)': Linked \(recordsForThisHabit.count) completion records")
          totalRepaired += recordsForThisHabit.count
        } else {
          print("✅ [REPAIR] Habit '\(habit.name)': Already correctly linked (\(recordsForThisHabit.count) records)")
        }
      }
      
      // Save the changes
      if totalRepaired > 0 {
        try context.save()
        print("✅ [REPAIR] Successfully repaired \(totalRepaired) completion record relationships")
      } else {
        print("ℹ️ [REPAIR] No relationships needed repair - all relationships are correct")
      }
      
    } catch {
      print("❌ [REPAIR] Failed to repair relationships: \(error.localizedDescription)")
      print("   Error details: \(error)")
    }
  }
  
  /// Clean up duplicate CompletionRecords - ensures exactly one record per habit/date/user
  private func cleanupDuplicateCompletionRecords() async {
    let context = SwiftDataContainer.shared.modelContext
    let userId = await CurrentUser().idOrGuest
    
    do {
      // Fetch all CompletionRecords for this user
      let predicate = #Predicate<CompletionRecord> { record in
        record.userId == userId || (userId.isEmpty && record.userId.isEmpty)
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      let allRecords = try context.fetch(descriptor)
      
      // Group records by (habitId, dateKey) to find duplicates
      let recordsByKey = Dictionary(grouping: allRecords) { record in
        "\(record.habitId)#\(record.dateKey)"
      }
      
      var duplicatesDeleted = 0
      
      // For each group, keep only the most recent record and delete the rest
      for (key, records) in recordsByKey {
        if records.count > 1 {
          // Sort by createdAt (most recent first)
          let sortedRecords = records.sorted { $0.createdAt > $1.createdAt }
          
          // Keep the first (most recent) record (no need to store it, we just don't delete it)
          let _ = sortedRecords.first!
          
          // Delete all other duplicates
          for duplicateRecord in sortedRecords.dropFirst() {
            context.delete(duplicateRecord)
            duplicatesDeleted += 1
            print("🗑️ [CLEANUP] Deleted duplicate CompletionRecord: habitId=\(duplicateRecord.habitId), dateKey=\(duplicateRecord.dateKey), createdAt=\(duplicateRecord.createdAt)")
          }
          
          print("✅ [CLEANUP] Kept most recent record for key '\(key)' (deleted \(sortedRecords.count - 1) duplicates)")
        }
      }
      
      // Save the changes
      if duplicatesDeleted > 0 {
        try context.save()
        print("✅ [CLEANUP] Successfully deleted \(duplicatesDeleted) duplicate CompletionRecords")
      } else {
        print("ℹ️ [CLEANUP] No duplicate CompletionRecords found - all records are unique")
      }
      
    } catch {
      print("❌ [CLEANUP] Failed to clean up duplicate CompletionRecords: \(error.localizedDescription)")
      print("   Error details: \(error)")
    }
  }
}
