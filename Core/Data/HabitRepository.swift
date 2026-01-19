import Combine
import FirebaseAuth
import SwiftData
import SwiftUI
import MijickPopups

// MARK: - Notification Extensions

extension Notification.Name {
  static let habitProgressUpdated = Notification.Name("habitProgressUpdated")
  /// Posted when user data migration completes - triggers @Query view refresh
  static let userDataMigrated = Notification.Name("userDataMigrated")
}


// MARK: - HabitSyncStatus

/// Represents the current sync status of the habit repository
enum HabitSyncStatus: Equatable {
  /// All changes are synced
  case synced
  
  /// Sync is currently in progress
  case syncing
  
  /// There are pending changes waiting to sync (with count)
  case pending(count: Int)
  
  /// Sync failed with an error
  case error(Error)
  
  /// Make Error equatable for HabitSyncStatus comparison
  static func == (lhs: HabitSyncStatus, rhs: HabitSyncStatus) -> Bool {
    switch (lhs, rhs) {
    case (.synced, .synced),
         (.syncing, .syncing):
      return true
    case (.pending(let lhsCount), .pending(let rhsCount)):
      return lhsCount == rhsCount
    case (.error(let lhsError), .error(let rhsError)):
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}

// MARK: - HabitRepository

///
/// This repository acts as a @MainActor facade for UI compatibility.
/// All actual data operations are handled by the HabitStore actor.
///
/// Data Storage:
/// - Habit definitions → SwiftData (primary) → UserDefaults (fallback)
/// - Completion records → SwiftData (primary) → UserDefaults (fallback)
/// - User preferences → UserDefaults
/// - Streak calculations → Computed from local data
///
/// Authentication:
/// - User login → AuthenticationManager (Firebase Auth)
/// - User tokens → Keychain (via KeychainManager)
/// - User profile → Firebase Auth
///
@MainActor
class HabitRepository: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Initialize basic functionality first
    debugLog("✅ HabitRepository: Initializing...")
    debugLog("✅ HabitRepository: Starting with \(habits.count) habits")

    // Load habits using the new actor
    debugLog("✅ HabitRepository: Using HabitStore actor for data operations...")

    // Load habits immediately and wait for completion
    Task { @MainActor in
      await loadHabits(force: true)
      debugLog("✅ HabitRepository: Initial habit loading completed with \(habits.count) habits")
    }

    // Defer CloudKit initialization to avoid crashes
    Task { @MainActor in
      await self.initializeCloudKitSafely()
    }

    // Monitor authentication state changes
    setupUserChangeMonitoring()
    
    // Initialize sync status monitoring
    initializeSyncStatusMonitoring()
    
    // ✅ ISSUE 2 FIX: Setup observer for sync pull completion notifications
    setupSyncObserver()

    debugLog("✅ HabitRepository: Initialization completed")
  }

  // MARK: Internal

  static let shared = HabitRepository()

  @Published var habits: [Habit] = []
  
  /// Published loading state to prevent concurrent loads
  @Published var isLoading = false
  
  /// Timestamp of the last load attempt (published for debugging/metrics)
  @Published private(set) var lastLoadTime: Date?
  private let loadCacheInterval: TimeInterval = 1.0 // 1 second cache

  /// Published properties for UI
  @Published var shouldShowMigrationView = false
  
  // MARK: - Sync Status Properties
  
  /// Current sync status
  @Published var syncStatus: HabitSyncStatus = .synced
  
  /// Number of unsynced changes (events, completions, awards)
  @Published var unsyncedCount: Int = 0
  
  /// Timestamp of last successful sync
  @Published var lastSyncDate: Date?

  /// Debug method to check if repository is working
  func debugRepositoryState() {
    debugLog("🔍 HabitRepository: Debug State")
    debugLog("  - habits.count: \(habits.count)")
    debugLog("  - habits: \(habits.map { "\($0.name) (ID: \($0.id))" })")
    debugLog("  - habitStore: \(habitStore)")
  }

  // MARK: - Guest Data Migration

  /// Handle guest data migration completion
  /// ✅ CRITICAL FIX: Made async to ensure data is loaded before UI dismisses
  func handleMigrationCompleted() async {
    let timestamp = Date()
    print("🔄 [MIGRATION] \(timestamp) handleMigrationCompleted() - START")
    
    // Hide migration view first
    shouldShowMigrationView = false
    print("🔄 [MIGRATION] \(timestamp) Migration view hidden")
    
    // ✅ CRITICAL FIX: Force ModelContext refresh to invalidate cached queries
    // SwiftData @Query predicates cache results, so we need to force a refresh
    // when userId changes from "" to authenticated userId
    print("🔄 [MIGRATION] \(timestamp) Forcing ModelContext refresh to invalidate cached queries...")
    await forceModelContextRefresh()
    
    // ✅ CRITICAL FIX: Clear UserAwareStorage cache before loading habits
    // After migration, data changes but userId doesn't, so the cache might have stale data
    // This ensures we load fresh data from SwiftData instead of returning cached habits
    print("🔄 [MIGRATION] \(timestamp) Clearing storage cache to force fresh load...")
    await habitStore.clearStorageCache()
    
    // ✅ CRITICAL FIX: Await loadHabits() to ensure data is loaded before returning
    print("🔄 [MIGRATION] \(timestamp) Starting loadHabits(force: true)...")
    await loadHabits(force: true)
    
    // ✅ CRITICAL FIX: Explicitly trigger UI update after habits are loaded
    let loadTimestamp = Date()
    print("🔄 [MIGRATION] \(loadTimestamp) loadHabits() completed - habits.count: \(habits.count)")
    
    // ✅ CRITICAL FIX: Post notification to trigger @Query view refresh
    // This ensures any views using @Query will re-evaluate their predicates
    NotificationCenter.default.post(name: .userDataMigrated, object: nil)
    print("🔄 [MIGRATION] \(loadTimestamp) Posted userDataMigrated notification - @Query views should refresh")
    
    // Force UI refresh
    objectWillChange.send()
    print("🔄 [MIGRATION] \(loadTimestamp) objectWillChange.send() called - UI should refresh")
    
    // ✅ VERIFICATION: Log what was actually loaded
    let currentUserId = await CurrentUser().idOrGuest
    print("🎯 [MIGRATION] \(loadTimestamp) Verification - HabitRepository state after migration:")
    print("   CurrentUser.idOrGuest: '\(currentUserId.isEmpty ? "EMPTY_STRING" : currentUserId.prefix(8))...'")
    print("   HabitRepository.habits.count: \(habits.count)")
    
    // Verify SwiftData has the migrated data
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      let allHabits = try modelContext.fetch(FetchDescriptor<HabitData>())
      let userHabits = allHabits.filter { $0.userId == currentUserId }
      print("   SwiftDataContainer habits for current user: \(userHabits.count)")
      print("   Total habits in SwiftData: \(allHabits.count)")
      
      if userHabits.count != habits.count {
        print("   ⚠️ MISMATCH: HabitRepository has \(habits.count) habits but SwiftData has \(userHabits.count) for current user")
      }
    } catch {
      print("   ❌ Error verifying SwiftData state: \(error.localizedDescription)")
    }
    
    for (index, habit) in habits.enumerated() {
      print("   [\(index)] '\(habit.name)' (ID: \(habit.id))")
    }
    
    // ✅ CRITICAL FIX: Refresh XP state after migration
    // DailyAwards may have been deleted (e.g., "Keep Local Data Only"), so we need to recalculate XP
    // from remaining awards (or 0 if all were deleted)
    print("🔄 [MIGRATION] Refreshing XP state after migration...")
    await DailyAwardService.shared.refreshXPState()
    print("✅ [MIGRATION] XP state refreshed after migration")
    
    let endTimestamp = Date()
    let duration = endTimestamp.timeIntervalSince(timestamp)
    print("✅ [MIGRATION] \(endTimestamp) handleMigrationCompleted() - COMPLETE (took \(String(format: "%.2f", duration))s)")
  }
  
  /// Force ModelContext to refresh and invalidate cached queries
  /// This is critical when userId changes (e.g., guest to authenticated)
  /// because SwiftData @Query predicates cache results based on the predicate values
  private func forceModelContextRefresh() async {
    let timestamp = Date()
    print("🔄 [MODEL_CONTEXT] \(timestamp) Forcing ModelContext refresh...")
    
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      // ✅ CRITICAL FIX: Process pending changes to ensure all migrations are visible
      do {
        // Force save any pending changes
        try modelContext.save()
        print("🔄 [MODEL_CONTEXT] \(timestamp) ModelContext.save() completed")
      } catch {
        print("⚠️ [MODEL_CONTEXT] \(timestamp) ModelContext.save() failed: \(error.localizedDescription)")
      }
      
      // ✅ CRITICAL FIX: Reset the ModelContext to clear any cached query results
      // This forces @Query views to re-evaluate their predicates with the new userId
      // Note: We can't directly reset ModelContext, but we can trigger a refresh by:
      // 1. Posting a notification that views can observe
      // 2. Forcing a re-fetch in HabitRepository
      
      print("🔄 [MODEL_CONTEXT] \(timestamp) ModelContext refresh initiated")
    }
  }

  /// Handle starting fresh (no migration)
  /// ✅ CRITICAL FIX: Made async to ensure data is loaded before UI dismisses
  func handleStartFresh() async {
    let timestamp = Date()
    print("🔄 [MIGRATION] \(timestamp) handleStartFresh() - START")
    
    shouldShowMigrationView = false
    print("🔄 [MIGRATION] \(timestamp) Migration view hidden")
    
    // ✅ CRITICAL FIX: Await loadHabits() to ensure data is loaded before returning
    print("🔄 [MIGRATION] \(timestamp) Starting loadHabits(force: true)...")
    await loadHabits(force: true)
    
    // Force UI refresh
    objectWillChange.send()
    print("🔄 [MIGRATION] \(Date()) objectWillChange.send() called - UI should refresh")
    
    let endTimestamp = Date()
    let duration = endTimestamp.timeIntervalSince(timestamp)
    print("✅ [MIGRATION] \(endTimestamp) handleStartFresh() - COMPLETE (took \(String(format: "%.2f", duration))s)")
  }

  /// Emergency fix for repeated migration screen - clears stale guest data
  func fixRepeatedMigrationIssue() {
    debugLog("🚨 HabitRepository: Applying emergency fix for repeated migration screen...")

    // ✅ FIX #23: Actually migrate guest data instead of clearing it
    if guestDataMigration.hasGuestData() {
      debugLog("⚠️ HabitRepository: Guest data detected during emergency fix - attempting migration...")
      Task {
        do {
          try await guestDataMigration.migrateGuestData()
          debugLog("✅ HabitRepository: Guest data migrated successfully during emergency fix")
        } catch {
          debugLog("❌ HabitRepository: Guest migration failed: \(error)")
          debugLog("⚠️ Guest data PRESERVED - user can retry migration later")
          // ❌ CRITICAL FIX: NEVER auto-delete user data - let them choose
          // guestDataMigration.clearStaleGuestData()  // Removed to prevent data loss
        }
        
        // Hide migration view and reload
        await MainActor.run {
          shouldShowMigrationView = false
        }
        await loadHabits(force: true)
      }
    } else {
      debugLog("ℹ️ HabitRepository: No guest data to migrate")
      // Force mark migration as completed
      guestDataMigration.forceMarkMigrationCompleted()
      
      // Hide migration view
      shouldShowMigrationView = false
      
      // Reload habits
      Task {
        await loadHabits(force: true)
      }
    }

    debugLog("✅ HabitRepository: Emergency fix applied - migration screen should no longer appear")
  }

  // MARK: - Emergency Recovery Methods

  /// Emergency method to recover lost habits by forcing a reload
  func emergencyRecoverHabits() async {
    debugLog("🚨 HabitRepository: Emergency habit recovery initiated...")

    // Clear any cached data
    await MainActor.run {
      self.habits = []
      self.objectWillChange.send()
    }

    // Force reload from storage
    await loadHabits(force: true)

    debugLog("🚨 HabitRepository: Emergency recovery completed. Found \(habits.count) habits.")
  }

  // MARK: - Debug Methods

  func debugHabitsState() {
    debugLog("🔍 HabitRepository: Debug - Current habits state:")
    debugLog("  - Published habits count: \(habits.count)")

    // List all published habits
    debugLog("📋 Published habits:")
    for (index, habit) in habits.enumerated() {
      debugLog("  \(index): \(habit.name) (ID: \(habit.id), reminders: \(habit.reminders.count))")
    }

    // Check for any habits without IDs
    let invalidHabits = habits.filter { $0.id == UUID() }
    if !invalidHabits.isEmpty {
      debugLog("⚠️ HabitRepository: Found \(invalidHabits.count) habits with default UUIDs")
    }

    // Check for duplicate IDs
    var seenIds: Set<UUID> = []
    var duplicates: [Habit] = []
    for habit in habits {
      if seenIds.contains(habit.id) {
        duplicates.append(habit)
      } else {
        seenIds.insert(habit.id)
      }
    }

    if !duplicates.isEmpty {
      debugLog("⚠️ HabitRepository: Found \(duplicates.count) duplicate habits:")
      for duplicate in duplicates {
        debugLog("    - \(duplicate.name) (ID: \(duplicate.id))")
      }
    }

    debugLog("✅ HabitRepository: Debug completed")
  }

  func debugCreateHabitFlow(_ habit: Habit) {
    debugLog("🔍 HabitRepository: Debug Create Habit Flow")
    debugLog("  - Habit to create: \(habit.name) (ID: \(habit.id))")
    debugLog("  - Current habits count: \(habits.count)")
    debugLog("  - Current habits: \(habits.map { $0.name })")
  }

  /// Emergency recovery method
  func recoverMissingHabits() {
    debugLog("🚨 HabitRepository: Starting emergency habit recovery...")

    // Force reload habits from storage
    Task {
      await loadHabits(force: true)
      debugLog("🚨 Recovery complete: \(habits.count) habits recovered")
    }
  }

  /// Debug function to analyze user data distribution
  func debugUserStats() async {
    debugLog("\n" + String(repeating: "=", count: 60))
    debugLog("📊 USER STATISTICS DEBUG REPORT")
    debugLog(String(repeating: "=", count: 60) + "\n")
    
    // 1. Current authentication state
    let currentUserId = await CurrentUser().id
    let isGuest = await CurrentUser().isGuest
    let currentEmail = await CurrentUser().email
    
    debugLog("🔐 Current Authentication State:")
    debugLog("  - User ID: \(currentUserId.isEmpty ? "(guest)" : currentUserId)")
    debugLog("  - Is Guest: \(isGuest)")
    debugLog("  - Email: \(currentEmail ?? "N/A")")
    debugLog()
    
    // 2. Load ALL habits from SwiftData (bypassing user filter)
    do {
        let container = SwiftDataContainer.shared.modelContainer
        let context = container.mainContext
        
        // Fetch ALL HabitData without filtering
        let allDescriptor = FetchDescriptor<HabitData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allHabitData = try context.fetch(allDescriptor)
        
        // Separate by user type
        let guestHabits = allHabitData.filter { $0.userId.isEmpty || $0.userId == "" }
        let authenticatedHabits = allHabitData.filter { !$0.userId.isEmpty && $0.userId != "" }
        
        // Get unique user IDs
        let uniqueUserIds = Set(authenticatedHabits.map { $0.userId })
        
        debugLog("📊 SwiftData Analysis:")
        debugLog("  - Total habits in database: \(allHabitData.count)")
        debugLog("  - Guest habits (userId=\"\"): \(guestHabits.count)")
        debugLog("  - Authenticated habits: \(authenticatedHabits.count)")
        debugLog("  - Unique authenticated users: \(uniqueUserIds.count)")
        debugLog()
        
        // 3. Show guest habit details if any exist
        if !guestHabits.isEmpty {
            debugLog("⚠️  GUEST HABITS DETECTED:")
            for (index, habitData) in guestHabits.prefix(10).enumerated() {
                let completionCount = habitData.completionHistory.count
                debugLog("  [\(index + 1)] \(habitData.name)")
                debugLog("      - Created: \(habitData.createdAt.formatted())")
                debugLog("      - Completions: \(completionCount)")
            }
            if guestHabits.count > 10 {
                debugLog("  ... and \(guestHabits.count - 10) more")
            }
            debugLog()
        }
        
        // 4. Show authenticated user breakdown
        if !uniqueUserIds.isEmpty {
            debugLog("👥 AUTHENTICATED USERS:")
            for userId in uniqueUserIds {
                let userHabits = authenticatedHabits.filter { $0.userId == userId }
                let isCurrent = userId == currentUserId
                debugLog("  - User: \(userId.prefix(8))... \(isCurrent ? "(CURRENT)" : "")")
                debugLog("    Habits: \(userHabits.count)")
            }
            debugLog()
        }
        
        // 5. Check for orphaned data
        let currentUserHabits = allHabitData.filter { $0.userId == currentUserId }
        debugLog("🎯 Current User Data:")
        debugLog("  - Visible habits (published): \(habits.count)")
        debugLog("  - Habits in SwiftData: \(currentUserHabits.count)")
        
        if habits.count != currentUserHabits.count {
            debugLog("  ⚠️  MISMATCH: Published count doesn't match SwiftData!")
        }
        debugLog()
        
        // 6. Migration risk assessment
        debugLog("🚨 RISK ASSESSMENT:")
        if guestHabits.count > 0 && !isGuest {
            debugLog("  ⚠️  HIGH RISK: Guest habits exist but user is authenticated!")
            debugLog("     These habits are ORPHANED and invisible to the user.")
            debugLog("     User may have lost \(guestHabits.count) habits when they signed in.")
        } else if guestHabits.count > 0 && isGuest {
            debugLog("  ⚠️  MEDIUM RISK: User has \(guestHabits.count) guest habits.")
            debugLog("     These will become orphaned if user signs in without proper migration.")
        } else if guestHabits.count == 0 && !isGuest {
            debugLog("  ✅ LOW RISK: No guest habits, user is authenticated.")
        } else {
            debugLog("  ✅ LOW RISK: Fresh installation or no data.")
        }
        debugLog()
        
        // 7. Actionable recommendations
        debugLog("💡 RECOMMENDATIONS:")
        if guestHabits.count > 0 && !isGuest {
            debugLog("  1. User has orphaned guest data - consider migration")
            debugLog("  2. Run data recovery to restore these habits")
        } else if guestHabits.count > 0 && isGuest {
            debugLog("  1. Fix guest migration before user signs in")
            debugLog("  2. Implement proper data migration flow")
        } else {
            debugLog("  1. No immediate action needed")
        }
        
    } catch {
        debugLog("❌ Error analyzing user data: \(error)")
        debugLog("   \(error.localizedDescription)")
    }
    
    debugLog("\n" + String(repeating: "=", count: 60))
    debugLog("END OF DEBUG REPORT")
    debugLog(String(repeating: "=", count: 60) + "\n")
  }

  // MARK: - Load Habits

  func loadHabits(force: Bool = false) async {
    let now = Date()
    
    // ✅ FIX: Use cache to prevent excessive reloads within short time window
    if !force, let lastLoad = lastLoadTime, now.timeIntervalSince(lastLoad) < loadCacheInterval {
      debugLog(
        "ℹ️ LOAD_HABITS: Skipping load - recently loaded \(String(format: "%.1f", now.timeIntervalSince(lastLoad)))s ago")
      return
    }
    
    // ✅ FIX: Prevent concurrent loads to reduce excessive data loading
    if isLoading {
      debugLog("⚠️ LOAD_HABITS: Skipping load - already loading")
      return
    }
    
    lastLoadTime = now
    
    debugLog("🔄 LOAD_HABITS_START: Loading from storage (force: \(force))")

    // Always load if force is true, or if habits is empty
    if !force, !habits.isEmpty, lastLoadTime != nil {
      debugLog("ℹ️ LOAD_HABITS: Skipping load - habits not empty and not forced")
      return
    }

    isLoading = true
    defer {
      isLoading = false
      lastLoadTime = Date() // ✅ Update cache timestamp after completion
    }

    do {
      // Use the HabitStore actor for data operations
      // ✅ CRITICAL FIX: Pass force parameter to HabitStore to propagate cache invalidation
      let loadedHabits = try await habitStore.loadHabits(force: force)
      
      if !hasLoggedStartupState {
        let todayKey = Habit.dateKey(for: Date())
        debugLog("🟢 APP_START: Loaded \(loadedHabits.count) habits from disk")
        for habit in loadedHabits {
          let progress = habit.completionHistory[todayKey] ?? 0
          debugLog("🟢 APP_START: \(habit.name) (\(habit.id)) todayProgress=\(progress)")
        }
        hasLoggedStartupState = true
      }
      debugLog("🔄 LOAD_HABITS_COMPLETE: Loaded \(loadedHabits.count) habits")
      
      let todayKey = Habit.dateKey(for: Date())

      // ✅ FIX: Get userId once at the top (reused for XP validation and UI update)
      let currentUserId = await CurrentUser().idOrGuest
      
      // ✅ FIX: Validate today's DailyAward after habits are loaded
      // This ensures XP is correct from app startup, preventing flickering
      // Run validation after a short delay to allow sync to complete first
      // Reuse todayKey that was already declared above
      Task { @MainActor in
        // Wait a bit for sync to complete (if it's running)
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
          debugLog("🎯 XP_VALIDATION: Validating today's DailyAward after habit load (dateKey: \(todayKey))")
          debugLog("   Waiting 2 seconds for sync to complete, then validating...")
          try await habitStore.checkDailyCompletionAndAwardXP(dateKey: todayKey, userId: currentUserId)
          debugLog("✅ XP_VALIDATION: Today's DailyAward validated - XP integrity confirmed")
        } catch {
          debugLog("⚠️ XP_VALIDATION: Failed to validate DailyAward: \(error.localizedDescription)")
          // Don't fail habit loading if XP validation fails
        }
      }

      // Deduplicate habits by ID to prevent duplicates
      var uniqueHabits: [Habit] = []
      var seenIds: Set<UUID> = []

      for habit in loadedHabits {
        if !seenIds.contains(habit.id) {
          uniqueHabits.append(habit)
          seenIds.insert(habit.id)
        } else {
          debugLog(
            "⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - skipping")
        }
      }

      // Update on main thread and notify observers
      // ✅ FIX: Reuse currentUserId from above (already declared)
      
      await MainActor.run {
        self.habits = uniqueHabits
        
        // ✅ CRITICAL FIX: Always call objectWillChange.send() to ensure UI updates
        // This is especially important after migration when userId changes
        self.objectWillChange.send()
          let todayKey = Habit.dateKey(for: Date())
          let todayProgress = habit.completionHistory[todayKey] ?? 0
          let isCompletedToday = habit.completionStatus[todayKey] ?? false
          print("      Today: progress=\(todayProgress), completed=\(isCompletedToday)")
        }
        print("   ✅ objectWillChange.send() called - UI should update")
      }

    } catch {
      debugLog("❌ HabitRepository: Failed to load habits: \(error.localizedDescription)")
      
      // Track silent failures for monitoring
      CrashlyticsService.shared.recordError(error, additionalInfo: [
        "operation": "loadHabits",
        "context": "HabitRepository.loadHabits - returning cached data due to load failure"
      ])
      
      // Keep existing habits if loading fails
    }
  }

  // MARK: - Save Difficulty Rating

  func saveDifficultyRating(habitId: UUID, date: Date, difficulty: Int32) {
    Task {
      do {
        // Use the HabitStore actor for data operations
        try await habitStore.saveDifficultyRating(
          habitId: habitId,
          date: date,
          difficulty: difficulty)

        // Update the local habits array immediately for UI responsiveness
        if let habitIndex = habits.firstIndex(where: { $0.id == habitId }) {
          habits[habitIndex].recordDifficulty(Int(difficulty), for: date)
          objectWillChange.send()
        }

        debugLog("✅ HabitRepository: Saved difficulty \(difficulty) for habit \(habitId) on \(date)")

      } catch {
        debugLog("❌ HabitRepository: Failed to save difficulty: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Fetch Difficulty Data

  func fetchDifficultiesForHabit(_ habitId: UUID, month: Int, year: Int) async -> [Double] {
    do {
      // Use the HabitStore actor for data operations
      return try await habitStore.fetchDifficultiesForHabit(habitId, month: month, year: year)
    } catch {
      debugLog("❌ HabitRepository: Failed to fetch difficulties: \(error.localizedDescription)")
      return []
    }
  }

  func fetchAllDifficulties(month: Int, year: Int) async -> [Double] {
    do {
      // Use the HabitStore actor for data operations
      return try await habitStore.fetchAllDifficulties(month: month, year: year)
    } catch {
      debugLog("❌ HabitRepository: Failed to fetch all difficulties: \(error.localizedDescription)")
      return []
    }
  }

  // MARK: - Save Habits

  func saveHabits(_ habits: [Habit]) {
    debugLog("🔄 HabitRepository: saveHabits called with \(habits.count) habits")

    Task {
      do {
        // Use the HabitStore actor for data operations
        try await habitStore.saveHabits(habits)

        // Update the local habits array on main thread
        await MainActor.run {
          self.habits = habits
          self.objectWillChange.send()
        }

        // CloudKit sync is disabled - infrastructure archived
        // if cloudKitIntegration.isEnabled {
        //   await cloudKitIntegration.startSync()
        // }

        debugLog("✅ HabitRepository: Successfully saved \(habits.count) habits")

      } catch {
        debugLog("❌ HabitRepository: Failed to save habits: \(error.localizedDescription)")
        
        // Track silent failures for monitoring
        CrashlyticsService.shared.recordError(error, additionalInfo: [
          "operation": "saveHabits",
          "habitCount": String(habits.count),
          "context": "HabitRepository.saveHabits - error swallowed for graceful degradation"
        ])
      }
    }
  }

  // MARK: - Create Habit

  func createHabit(_ habit: Habit) async {
    #if DEBUG
    debugLog("🎯 [5/8] HabitRepository.createHabit: persisting habit")
    debugLog("  → Habit: '\(habit.name)', ID: \(habit.id)")
    debugLog("  → Current habits count: \(habits.count)")
    #endif

    do {
      // Use the HabitStore actor for data operations
      #if DEBUG
      debugLog("  → Calling HabitStore.createHabit")
      #endif
      try await habitStore.createHabit(habit)
      #if DEBUG
      debugLog("  → HabitStore.createHabit completed")
      #endif

      // ✅ FIX: Check if today's DailyAward should be updated after habit creation
      // If new habit makes today incomplete, revoke today's XP award
      // Only check if this habit is scheduled for today
      let today = Date()
      let isScheduledForToday = StreakDataCalculator.shouldShowHabitOnDate(habit, date: today)
      
      if isScheduledForToday {
        let todayDateKey = Habit.dateKey(for: today)
        let currentUserId = await CurrentUser().idOrGuest
        
        debugLog("🎯 XP_CHECK: New habit '\(habit.name)' is scheduled for today - checking DailyAward")
        debugLog("   If today had an award but this habit isn't complete, the award will be revoked")
        do {
          try await habitStore.checkDailyCompletionAndAwardXP(dateKey: todayDateKey, userId: currentUserId)
          debugLog("✅ XP_CHECK: DailyAward check completed for today")
        } catch {
          debugLog("⚠️ XP_CHECK: Failed to check DailyAward: \(error.localizedDescription)")
          // Don't fail habit creation if XP check fails
        }
      } else {
        debugLog("ℹ️ XP_CHECK: New habit '\(habit.name)' is not scheduled for today - skipping DailyAward check")
      }

      // Reload habits to get the updated list
      #if DEBUG
      debugLog("  → Reloading habits from storage")
      #endif
      await loadHabits(force: true)
      #if DEBUG
      debugLog("  ✅ Success! New habits count: \(habits.count)")
      #endif

    } catch {
      #if DEBUG
      debugLog("  ❌ FAILED: \(error.localizedDescription)")
      debugLog("  ❌ Error type: \(type(of: error))")
      if let dataError = error as? DataError {
        debugLog("  ❌ DataError: \(dataError)")
      }
      #endif
    }
  }

  // MARK: - Update Habit

  // MARK: - Navy Color Migration
  
  /// Migrate existing Navy-colored habits from fixed RGB to semantic color
  /// This will reload all habits, triggering the decode → re-encode with sentinel value
  /// Call this once at app startup to convert existing habits
  func migrateNavyColorsToSemantic() async {
    debugLog("🎨 HabitRepository: Starting Navy color migration...")
    
    do {
      // Load all habits
      await loadHabits(force: true)
      let allHabits = habits
      
      debugLog("🎨 HabitRepository: Found \(allHabits.count) habits to check for Navy color migration")
      
      var migratedCount = 0
      for habit in allHabits {
        // Re-save each habit - the encode/decode cycle will convert Navy to semantic
        // The decodeColor function automatically detects Navy stored as fixed RGB
        // and the encodeColor function will store it as semantic color
        try await updateHabit(habit)
        migratedCount += 1
      }
      
      debugLog("✅ HabitRepository: Navy color migration completed - \(migratedCount) habits processed")
    } catch {
      debugLog("❌ HabitRepository: Navy color migration failed: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func updateHabit(_ habit: Habit) async throws {
    debugLog("🔄 HabitRepository: updateHabit called for: \(habit.name) (ID: \(habit.id))")
    debugLog("🔄 HabitRepository: Habit has \(habit.reminders.count) reminders")
    debugLog("🔄 HabitRepository: Current habits count before update: \(habits.count)")
    debugLog("🎯 PERSISTENCE FIX: Using async/await to guarantee save completion")

    do {
      // Use the HabitStore actor for data operations
      debugLog("🔄 HabitRepository: Calling habitStore.updateHabit...")
      try await habitStore.updateHabit(habit)
      debugLog("✅ HabitRepository: habitStore.updateHabit completed successfully")

      // ✅ FIX: Check if today's DailyAward should be updated after habit update
      // If habit update (e.g., start date change) makes today incomplete, revoke today's XP award
      let today = Date()
      let todayDateKey = Habit.dateKey(for: today)
      let currentUserId = await CurrentUser().idOrGuest
      
      debugLog("🎯 XP_CHECK: Checking today's DailyAward after habit update (dateKey: \(todayDateKey))")
      do {
        try await habitStore.checkDailyCompletionAndAwardXP(dateKey: todayDateKey, userId: currentUserId)
        debugLog("✅ XP_CHECK: DailyAward check completed for today")
      } catch {
        debugLog("⚠️ XP_CHECK: Failed to check DailyAward: \(error.localizedDescription)")
        // Don't fail habit update if XP check fails
      }

      // Reload habits to get the updated list
      debugLog("🔄 HabitRepository: Reloading habits...")
      await loadHabits(force: true)
      debugLog("✅ HabitRepository: Habits reloaded, new count: \(habits.count)")
      debugLog("✅ GUARANTEED: Habit update persisted to SwiftData")

    } catch {
      debugLog("❌ HabitRepository: Failed to update habit: \(error.localizedDescription)")
      debugLog("❌ HabitRepository: Error type: \(type(of: error))")
      if let dataError = error as? DataError {
        debugLog("❌ HabitRepository: DataError details: \(dataError)")
      }
      throw error
    }
  }

  // MARK: - Delete Habit

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  /// ✅ CRITICAL FIX: DO NOT reload habits after deletion - reloading triggers sync/migration that recreates the habit
  func deleteHabit(_ habit: Habit) async throws {
    print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - START for habit: \(habit.name) (ID: \(habit.id))")
    
    // Remove all notifications for this habit first
    NotificationManager.shared.removeAllNotifications(for: habit)
    print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - Removing notifications")
    debugLog("🎯 PERSISTENCE FIX: Using async/await to guarantee delete completion")
    print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - Calling habitStore.deleteHabit()")

    do {
      try await habitStore.deleteHabit(habit)
      print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - habitStore.deleteHabit() completed")
      debugLog("✅ GUARANTEED: Habit deleted from SwiftData")
      
      // ✅ FIX: Manually update published habits to prevent race condition with publisher
      // This ensures the @Published habits array is immediately updated, preventing the
      // publisher from re-adding the deleted habit to HomeView before delete completes
      await MainActor.run {
        self.habits.removeAll { $0.id == habit.id }
        print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - Updated @Published habits array")
      }
      
      print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - END")
    } catch {
      print("🗑️ DELETE_FLOW: HabitRepository.deleteHabit() - ERROR: \(error.localizedDescription)")
      debugLog("❌ HabitRepository: Failed to delete habit: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Clear All Habits

  func clearAllHabits() async throws {
    debugLog("🗑️ HabitRepository: Clearing all habits")

    // Remove all notifications
    NotificationManager.shared.removeAllPendingNotifications()

    // Use the HabitStore actor for data operations
    try await habitStore.clearAllHabits()

    // Update local state
    await MainActor.run {
      self.habits = []
      self.objectWillChange.send()
    }

    debugLog("✅ HabitRepository: All habits cleared")
  }

  // MARK: - Toggle Habit Completion

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func toggleHabitCompletion(_ habit: Habit, for date: Date) async throws {
    // Skip Core Data and handle completion directly in UserDefaults
    debugLog("⚠️ HabitRepository: Bypassing Core Data for toggleHabitCompletion")

    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone
    
    // ✅ UNIVERSAL RULE: Both types use completionHistory
    let currentProgress = habit.completionHistory[dateKey] ?? 0
    
    if habit.habitType == .breaking {
      debugLog("🔍 TOGGLE - Breaking Habit '\(habit.name)' | Current progress: \(currentProgress)")
    } else {
      debugLog("🔍 TOGGLE - Formation Habit '\(habit.name)' | Current progress: \(currentProgress)")
    }
    
    let newProgress = currentProgress > 0 ? 0 : 1
    debugLog("🔍 TOGGLE - Setting new progress to: \(newProgress)")

    // ✅ CRITICAL FIX: Await save completion
    try await setProgress(for: habit, date: date, progress: newProgress)
  }

  // MARK: - Force Save All Changes

  func forceSaveAllChanges() {
    debugLog("🔄 HabitRepository: Force saving all changes...")

    // Save current habits
    saveHabits(habits)

    debugLog("✅ HabitRepository: All changes saved")
  }

  // MARK: - Set Progress

  /// ✅ CRITICAL FIX: Made async/await to GUARANTEE save completion before returning
  func setProgress(for habit: Habit, date: Date, progress: Int) async throws {
    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone
    #if DEBUG
    debugLog("🔄 HabitRepository: Setting progress to \(progress) for habit '\(habit.name)' on \(dateKey)")
    debugLog("🎯 PERSISTENCE FIX: Using async/await to guarantee save completion")
    #endif

    // Update the local habits array immediately for UI responsiveness
    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
      let oldProgress = habits[index].completionHistory[dateKey] ?? 0
      let isUncompleteAction = progress < oldProgress
      #if DEBUG
      if isUncompleteAction {
        debugLog("🔴 UNCOMPLETE_START: habitId=\(habit.id), dateKey=\(dateKey), oldProgress=\(oldProgress), newProgress=\(progress)")
      }
      #endif
      var updatedHabit = habits[index]
      updatedHabit.completionHistory[dateKey] = progress
      #if DEBUG
      if isUncompleteAction {
        let memProgress = updatedHabit.completionHistory[dateKey] ?? -999
        debugLog("🔴 UNCOMPLETE_MEMORY: Updated in-memory completionHistory[\(dateKey)]=\(memProgress)")
      }
      #endif
      #if DEBUG
      debugLog("🔍 REPO - \(updatedHabit.habitType == .breaking ? "Breaking" : "Formation") Habit '\(updatedHabit.name)' | Old progress: \(oldProgress) → New progress: \(progress)")
      #endif

      // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
      // Set completionStatus[dateKey] = true when progress >= goal
      let goalAmount = updatedHabit.goalAmount(for: date)
      let isComplete = progress >= goalAmount
      updatedHabit.completionStatus[dateKey] = isComplete
      #if DEBUG
      debugLog("🔍 COMPLETION FIX - \(updatedHabit.habitType == .breaking ? "Breaking" : "Formation") Habit '\(updatedHabit.name)' | Progress: \(progress) | Goal: \(goalAmount) | Completed: \(isComplete)")
      #endif

      // Handle timestamp recording for time-based completion analysis
      let currentTimestamp = Date()
      if progress > oldProgress {
        // Progress increased - record new completion timestamp
        if updatedHabit.completionTimestamps[dateKey] == nil {
          updatedHabit.completionTimestamps[dateKey] = []
        }
        let newCompletions = progress - oldProgress
        for _ in 0 ..< newCompletions {
          updatedHabit.completionTimestamps[dateKey]?.append(currentTimestamp)
        }
        #if DEBUG
        debugLog("🕐 HabitRepository: Recorded \(newCompletions) completion timestamp(s) for \(habit.name) at \(currentTimestamp)")
        debugLog("🕐 HabitRepository: Total timestamps for \(dateKey): \(updatedHabit.completionTimestamps[dateKey]?.count ?? 0)")
        #endif
      } else if progress < oldProgress {
        // Progress decreased - remove recent timestamps
        let removedCompletions = oldProgress - progress
        for _ in 0 ..< removedCompletions {
          if updatedHabit.completionTimestamps[dateKey]?.isEmpty == false {
            updatedHabit.completionTimestamps[dateKey]?.removeLast()
          }
        }
        #if DEBUG
        debugLog("🕐 HabitRepository: Removed \(removedCompletions) completion timestamp(s) for \(habit.name)")
        #endif
      }

      // ✅ SYNC METADATA: Any progress change must be re-synced to Firestore
      updatedHabit.lastSyncedAt = nil
      updatedHabit.syncStatus = .pending

      // ✅ CRITICAL FIX: Reassign to habits array to trigger @Published emission
      objectWillChange.send()
      habits[index] = updatedHabit
      
      // ✅ PHASE 4: Streak is now computed-only, no need to update
      // Streak is derived from completion history in real-time
      #if DEBUG
      debugLog("✅ HabitRepository: UI updated immediately for habit '\(habit.name)' on \(dateKey)")
      debugLog("📢 HabitRepository: @Published habits array updated, triggering subscriber notifications")
      #endif

      // ✅ XP SYSTEM: XP awarding is now handled by the UI layer (HomeTabView)
      // Removed automatic XP check here to prevent double celebrations

      // Send notification for UI components to update
      #if DEBUG
      debugLog("🎯 HabitRepository: Posting habitProgressUpdated notification for habit: \(habit.name), progress: \(progress)")
      #endif
      NotificationCenter.default.post(
        name: .habitProgressUpdated,
        object: nil,
        userInfo: ["habitId": habit.id, "progress": progress, "dateKey": dateKey])
      #if DEBUG
      debugLog("🎯 HabitRepository: Notification posted successfully")
      #endif
      
      // ✅ CRITICAL FIX: Await save completion BEFORE returning
      do {
        let startTime = Date()
        #if DEBUG
        debugLog("  🎯 PERSIST_START: \(habit.name) progress=\(progress) date=\(dateKey)")
        debugLog("  ⏱️ REPO_AWAIT_START: Calling habitStore.setProgress() at \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
        #endif
        
        try await habitStore.setProgress(for: habit, date: date, progress: progress)
        #if DEBUG
        if isUncompleteAction {
          debugLog("🔴 UNCOMPLETE_SWIFTDATA: habitStore.setProgress succeeded for habitId=\(habit.id)")
        }
        #endif
        
        #if DEBUG
        if isUncompleteAction {
          do {
            let verificationHabits = try await habitStore.loadHabits()
            let reloadedHabit = verificationHabits.first(where: { $0.id == habit.id })
            let reloadedProgress = reloadedHabit?.completionHistory[dateKey] ?? -999
            debugLog("🔴 UNCOMPLETE_VERIFY: Reloaded progress for \(habit.id) on \(dateKey) = \(reloadedProgress)")
          } catch {
            debugLog("🔴 UNCOMPLETE_VERIFY: Failed to reload habits - \(error)")
          }
        }
        #endif
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        #if DEBUG
        debugLog("  ⏱️ REPO_AWAIT_END: habitStore.setProgress() returned at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
        debugLog("  ✅ PERSIST_SUCCESS: \(habit.name) saved in \(String(format: "%.3f", duration))s")
        debugLog("  ✅ GUARANTEED: Data persisted to SwiftData")
        #endif

      } catch {
        #if DEBUG
        debugLog("  ❌ PERSIST_FAILED: \(habit.name) - \(error.localizedDescription)")
        debugLog("  ❌ Error type: \(type(of: error))")
        debugLog("  ❌ Error details: \(error)")
        #endif
        
        // Revert UI change on error
        var revertedHabit = habits[index]
        revertedHabit.completionHistory[dateKey] = oldProgress
        habits[index] = revertedHabit
        #if DEBUG
        debugLog("  🔄 PERSIST_REVERT: Reverted \(habit.name) to progress=\(oldProgress)")
        debugLog("  📢 HabitRepository: @Published habits array reverted, triggering subscriber notifications")
        #endif
        
        // Re-throw to let caller know save failed
        throw error
      }
    }
  }

  // MARK: - Get Progress

  /// Get progress for a habit on a specific date
  /// 
  /// ⚠️ TODO: Update to use event replay (Priority 1)
  /// Get progress using event-sourcing with fallback to completionHistory
  /// ✅ FIXED: Ensures completionHistory is used correctly (populated from CompletionRecords on load)
  func getProgress(for habit: Habit, date: Date) -> Int {
    // First check completionHistory (populated from CompletionRecords when habits are loaded)
    let progress = habit.getProgress(for: date)
    
    // 🔍 DEBUG: Log if progress is 0 but completionStatus suggests completion
    let dateKey = Habit.dateKey(for: date)
    if progress == 0, let isCompleted = habit.completionStatus[dateKey], isCompleted {
      debugLog("⚠️ getProgress MISMATCH: habit=\(habit.name), dateKey=\(dateKey), progress=0 but completionStatus=true")
      debugLog("   → completionHistory keys: \(Array(habit.completionHistory.keys.sorted()))")
    }
    
    return progress
  }
  
  // MARK: - Soft Delete Recovery
  
  /// Load soft-deleted habits (for Recently Deleted view)
  func loadSoftDeletedHabits() async throws -> [Habit] {
    debugLog("🔄 HabitRepository: Loading soft-deleted habits...")
    do {
      let habits = try await habitStore.loadSoftDeletedHabits()
      debugLog("✅ HabitRepository: Loaded \(habits.count) soft-deleted habits")
      return habits
    } catch {
      debugLog("❌ HabitRepository: Failed to load soft-deleted habits: \(error.localizedDescription)")
      throw error
    }
  }
  
  /// Count soft-deleted habits (for Recently Deleted badge)
  func countSoftDeletedHabits() async -> Int {
    do {
      let count = try await habitStore.countSoftDeletedHabits()
      return count
    } catch {
      debugLog("❌ HabitRepository: Failed to count soft-deleted habits: \(error.localizedDescription)")
      return 0
    }
  }
  
  /// Permanently delete a habit (called from Recently Deleted view)
  func permanentlyDeleteHabit(_ habit: Habit) async throws {
    debugLog("🗑️ HabitRepository: Permanently deleting habit: \(habit.name)")
    do {
      try await habitStore.permanentlyDeleteHabit(id: habit.id)
      debugLog("✅ HabitRepository: Successfully permanently deleted habit: \(habit.name)")
    } catch {
      debugLog("❌ HabitRepository: Failed to permanently delete habit: \(error.localizedDescription)")
      throw error
    }
  }
  
  /// Restore a soft-deleted habit (called from Recently Deleted view)
  func restoreSoftDeletedHabit(_ habit: Habit) async throws {
    debugLog("♻️ HabitRepository: Restoring soft-deleted habit: \(habit.name)")
    
    // CRITICAL: Clear deleted tracking BEFORE reload to prevent filtering
    debugLog("♻️ HabitRepository: Clearing deleted tracking for habit: \(habit.id)")
    SyncEngine.clearDeletedHabit(habit.id)  // Clear from SyncEngine
    await HabitStore.shared.unmarkHabitAsDeleted(habit.id)  // Clear from UserDefaults
    
    // Query SwiftData for the soft-deleted HabitData by ID
    let modelContext = SwiftDataContainer.shared.modelContext
    
    // Fetch ALL habits (including soft-deleted) to find by ID
    let descriptor = FetchDescriptor<HabitData>()
    let allHabits = try modelContext.fetch(descriptor)
    
    guard let habitData = allHabits.first(where: { $0.id == habit.id }) else {
      debugLog("❌ HabitRepository: Habit not found for restoration: \(habit.id)")
      throw DataError.storage(StorageError(
        type: .unknown,
        message: "Habit not found for restoration",
        underlyingError: nil))
    }
    
    // Call restore() method (sets deletedAt = nil)
    habitData.restore()
    
    // Save context
    try modelContext.save()
    debugLog("✅ HabitRepository: Successfully restored habit: \(habit.name)")
    
    // Re-upload to Firestore (habit was hard-deleted during soft-delete)
    debugLog("♻️ HabitRepository: Re-uploading habit to Firestore...")
    FirebaseBackupService.shared.backupHabit(habit)
    debugLog("♻️ HabitRepository: Habit backup initiated to Firestore: \(habit.name)")
    
    // Reload habits to update UI
    await loadHabits(force: true)
  }

  // MARK: - Clean Up Duplicates

  func cleanupDuplicateHabits() {
    debugLog("🔄 HabitRepository: Starting duplicate cleanup...")

    // Check for duplicate IDs in current habits
    var seenIds: Set<UUID> = []
    var duplicatesToRemove: [Habit] = []

    for habit in habits {
      if seenIds.contains(habit.id) {
        duplicatesToRemove.append(habit)
        debugLog(
          "⚠️ HabitRepository: Found duplicate habit with ID: \(habit.id), name: \(habit.name) - will be removed")
      } else {
        seenIds.insert(habit.id)
      }
    }

    if !duplicatesToRemove.isEmpty {
      debugLog("🔄 HabitRepository: Removing \(duplicatesToRemove.count) duplicate habits...")

      // Remove duplicates from habits array
      habits.removeAll { habit in
        duplicatesToRemove.contains { $0.id == habit.id }
      }

      // Save updated habits
      saveHabits(habits)
      debugLog("✅ HabitRepository: Duplicate cleanup completed, total habits: \(habits.count)")
    } else {
      debugLog("✅ HabitRepository: No duplicate habits found")
    }
  }

  // MARK: Private

  /// Use the new HabitStore actor for all data operations
  private let habitStore = HabitStore.shared

  /// Authentication manager for user change monitoring
  private let authManager = AuthenticationManager.shared

  /// UserDefaults for storing migration attempt counts
  private let userDefaults = UserDefaults.standard

  /// Combine cancellables for subscriptions
  private var cancellables = Set<AnyCancellable>()
  private var lastWarmupDate: Date?
  private var hasLoggedStartupState = false
  private var isUserCurrentlyAuthenticated = false
  
  /// Sync monitoring timer cancellable (stored separately for pause/resume)
  private var syncMonitoringCancellable: AnyCancellable?
  /// Flag to pause sync monitoring (e.g., when create habit sheet is open)
  private var isSyncMonitoringPaused = false

  /// Guest data migration
  private let guestDataMigration = GuestDataMigration()

  // CloudKit is disabled - infrastructure archived
  // private lazy var cloudKitManager = CloudKitManager.shared
  // private lazy var cloudKitIntegration = CloudKitIntegrationService.shared

  // MARK: - Post Launch Warmup

  func postLaunchWarmup() async {
    let now = Date()
    if let lastWarmupDate,
       now.timeIntervalSince(lastWarmupDate) < 5.0
    {
      debugLog(
        "ℹ️ POST_LAUNCH: Skipping warmup - ran \(String(format: "%.1f", now.timeIntervalSince(lastWarmupDate)))s ago")
      return
    }
    lastWarmupDate = now

    debugLog("🚀 POST_LAUNCH: Starting deferred warmup tasks...")

    let snapshotHabits = habits
    guard !snapshotHabits.isEmpty else {
      debugLog("🚀 POST_LAUNCH: Skipped warmup - no habits loaded yet")
      return
    }

    Task.detached(priority: .background) { [snapshotHabits] in
      guard !snapshotHabits.isEmpty else { return }
      let notificationManager = NotificationManager.shared
      notificationManager.initializeNotificationCategories()
      notificationManager.setDeterministicCalendarForDST()
      notificationManager.rescheduleAllNotifications(for: snapshotHabits)
      await MainActor.run {
        notificationManager.rescheduleDailyReminders()
      }
    }

    Task.detached(priority: .background) {
      // ✅ GUEST-ONLY MODE: Sync disabled - no cloud sync needed
      // guard !CurrentUser.isGuestId(userId) else {
      //   debugLog("ℹ️ POST_LAUNCH: Skipping completion sync for guest user")
      //   return
      // }
      // do {
      //   try await SyncEngine.shared.syncCompletions()
      // } catch {
      //   debugLog("⚠️ POST_LAUNCH: Completion sync failed: \(error)")
      // }
    }

    Task.detached(priority: .utility) {
      do {
        _ = try await DataRetentionManager.shared.performCleanup()
      } catch {
        debugLog("⚠️ POST_LAUNCH: Data retention cleanup failed: \(error)")
      }
    }

    Task.detached(priority: .background) {
      await MainActor.run {
        XPManager.shared.resetDailyXP()
      }
    }

    debugLog("🚀 POST_LAUNCH: All warmup tasks scheduled")
  }

  // MARK: - Safe CloudKit Initialization (DISABLED)

  private func initializeCloudKitSafely() async {
    // CloudKit sync is disabled - infrastructure archived
    // See: Core/Data/CloudKit/Archive/ for archived CloudKit code
    debugLog("ℹ️ HabitRepository: CloudKit initialization skipped (disabled)")

    // Monitor app lifecycle to reload data when app becomes active
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil)
  }

  // MARK: - User Change Monitoring

  private func setupUserChangeMonitoring() {
    // Monitor authentication state changes
    authManager.$authState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] authState in
        Task { @MainActor in
          await self?.handleUserChange(authState)
        }
      }
      .store(in: &cancellables)
  }
  
  // MARK: - Sync Status Monitoring
  
  /// Initialize sync status monitoring and load initial state
  private func initializeSyncStatusMonitoring() {
    // Load last sync date from UserDefaults
    Task {
      await loadLastSyncDate()
    }
    
    // Update unsynced count periodically
    Task {
      await updateUnsyncedCount()
    }
    
    // Set up periodic updates (every 5 seconds)
    syncMonitoringCancellable = Timer.publish(every: 5.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self = self, !self.isSyncMonitoringPaused else { return }
        Task { @MainActor in
          await self.updateUnsyncedCount()
        }
      }
  }
  
  /// ✅ ISSUE 2 FIX: Setup observer for sync pull completion notifications
  /// This ensures UI refreshes when habits are pulled from Firestore
  private func setupSyncObserver() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("SyncPullCompleted"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self = self else { return }
      let habitsPulled = notification.userInfo?["habitsPulled"] as? Int ?? 0
      print("🔄 HabitRepository: Received SyncPullCompleted notification - \(habitsPulled) habits pulled")
      
      Task { @MainActor in
        await self.loadHabits(force: true)
      }
    }
  }
  
  /// Pause sync monitoring (e.g., when create habit sheet is open)
  /// This prevents the 5-second timer from triggering view re-renders
  func pauseSyncMonitoring() {
    isSyncMonitoringPaused = true
    debugLog("⏸️ HabitRepository: Sync monitoring paused")
  }
  
  /// Resume sync monitoring after it was paused
  func resumeSyncMonitoring() {
    isSyncMonitoringPaused = false
    debugLog("▶️ HabitRepository: Sync monitoring resumed")
    // Immediately update count when resuming
    Task { @MainActor in
      await updateUnsyncedCount()
    }
  }
  
  /// Query SwiftData for unsynced events, completions, and awards count
  func updateUnsyncedCount() async {
    let userId = await CurrentUser().idOrGuest
    
    // Skip for guest users
    guard !CurrentUser.isGuestId(userId) else {
      unsyncedCount = 0
      syncStatus = .synced
      return
    }
    
    let modelContext = SwiftDataContainer.shared.modelContext
    
    // Count unsynced events
    let eventsDescriptor = ProgressEvent.unsyncedEvents()
    let unsyncedEvents = (try? modelContext.fetch(eventsDescriptor)) ?? []
    let eventsCount = unsyncedEvents.count
    
    // Count unsynced completions (completion records without synced flag are considered synced via events)
    // For now, we'll focus on events. If needed, we can add completion sync tracking later
    
    // Count unsynced awards
    // TODO: Add synced property to DailyAward SwiftData model if needed
    // For now, awards are synced via SyncEngine.syncAwards() but don't have a synced flag
    // We'll only count events for unsynced items until DailyAward has sync tracking
    let awardsCount = 0 // Placeholder until DailyAward sync tracking is added
    
    let totalUnsynced = eventsCount + awardsCount
    
    // Update published properties
    unsyncedCount = totalUnsynced
    
    // Update sync status based on count
    if totalUnsynced > 0 {
      if syncStatus != .syncing {
        syncStatus = .pending(count: totalUnsynced)
      }
    } else if syncStatus != .syncing {
      syncStatus = .synced
    }
  }
  
  /// Update sync status when sync starts
  func syncStarted() {
    syncStatus = .syncing
  }
  
  /// Update sync status when sync completes successfully
  func syncCompleted() {
    // ✅ FIX: Run XP validation after sync completes to catch any invalid awards imported from Firestore
    // This ensures XP is correct even if invalid awards were imported during sync
    Task { @MainActor in
      let today = Date()
      let todayKey = Habit.dateKey(for: today)
      let currentUserId = await CurrentUser().idOrGuest
      
      do {
        debugLog("🎯 XP_VALIDATION: Validating today's DailyAward after sync completion (dateKey: \(todayKey))")
        debugLog("   This ensures XP is correct even if invalid awards were imported during sync")
        try await habitStore.checkDailyCompletionAndAwardXP(dateKey: todayKey, userId: currentUserId)
        debugLog("✅ XP_VALIDATION: Today's DailyAward validated after sync - XP integrity confirmed")
      } catch {
        debugLog("⚠️ XP_VALIDATION: Failed to validate DailyAward after sync: \(error.localizedDescription)")
        // Don't fail sync if XP validation fails
      }
    }
    syncStatus = .synced
    lastSyncDate = Date()
    saveLastSyncDate()
    
    // Update unsynced count after sync
    Task {
      await updateUnsyncedCount()
    }
    // Note: Toast notification removed to prevent screen dimming
    // Sync status is already visible in the More tab
  }
  
  /// Update sync status when sync fails
  func syncFailed(error: Error) {
    syncStatus = .error(error)
    
    // Update unsynced count to show what still needs syncing
    Task {
      await updateUnsyncedCount()
    }
    // Note: Toast notification removed to prevent screen dimming
    // Sync status is already visible in the More tab
  }
  
  /// Store last sync date in UserDefaults (per user)
  private func saveLastSyncDate() {
    guard let lastSyncDate = lastSyncDate else { return }
    Task {
      let userId = await CurrentUser().idOrGuest
      guard !CurrentUser.isGuestId(userId) else { return }
      
      let key = "lastSyncDate_\(userId)"
      userDefaults.set(lastSyncDate, forKey: key)
    }
  }
  
  /// Load last sync date from UserDefaults (per user)
  private func loadLastSyncDate() async {
    let userId = await CurrentUser().idOrGuest
    guard !CurrentUser.isGuestId(userId) else {
      lastSyncDate = nil
      return
    }
    
    let key = "lastSyncDate_\(userId)"
    if let date = userDefaults.object(forKey: key) as? Date {
      lastSyncDate = date
    }
  }
  
  /// Trigger manual sync
  func triggerManualSync() async throws {
    syncStarted()
    
    let userId = await CurrentUser().idOrGuest
    guard !CurrentUser.isGuestId(userId) else {
      syncCompleted()
      return
    }
    
    // ✅ GUEST-ONLY MODE: Sync disabled - no cloud sync needed
    // try await SyncEngine.shared.performFullSyncCycle(userId: userId)
    syncCompleted()
  }

  private func handleUserChange(_ authState: AuthenticationState) async {
    switch authState {
    case .authenticated(let user):
      isUserCurrentlyAuthenticated = true
      debugLog(
        "🔄 HabitRepository: User authenticated: \(user.email ?? "Unknown"), checking for guest data migration...")

      // ✅ CRITICAL FIX: Only show migration UI if user is NOT anonymous
      // Note: Anonymous users are authenticated but migration UI is only shown for email/password users
      // Guest data migration for anonymous users is handled automatically in Step 3
      let isAnonymous = (user as? User)?.isAnonymous ?? false
      
      if isAnonymous {
        debugLog("ℹ️ HabitRepository: User is anonymous - skipping migration UI (migration handled automatically)")
        shouldShowMigrationView = false
        await loadHabits(force: true)
        return
      }
      
      // ✅ CRITICAL FIX: Check for CURRENT guest data (userId = "" or "guest")
      // Show migration UI if guest data exists, regardless of previous migration flag
      // The migration flag should only prevent showing UI if there's no guest data to handle
      let hasCurrentGuestData = guestDataMigration.hasGuestData()
      
      if hasCurrentGuestData {
        debugLog("🔄 HabitRepository: Guest data detected - showing migration UI...")
        debugLog("   Found guest data that needs user decision (regardless of previous migrations)")
        shouldShowMigrationView = true  // ✅ Show migration UI, let user choose
        debugLog("✅ Guest data found, user can choose to migrate or start fresh")
        // Don't auto-migrate - wait for user's choice in migration UI
      } else {
        debugLog("ℹ️ HabitRepository: No guest data found - skipping migration UI")
        shouldShowMigrationView = false
        
        // No automatic migration - user must explicitly choose via migration UI
        // If there's no guest data, there's nothing to migrate
      }

      // Load user data
      await loadHabits(force: true)
      debugLog("✅ HabitRepository: Data loaded for user: \(user.email ?? "Unknown")")

      // Load user's XP from SwiftData
      await loadUserXPFromSwiftData(userId: user.uid)
      
      // ✅ GUEST-ONLY MODE: Sync disabled - no cloud sync needed
      // await SyncEngine.shared.startPeriodicSync(userId: user.uid)
      // Task.detached(priority: .background) {
      //   let compactor = EventCompactor(userId: user.uid)
      //   await compactor.scheduleNextCompaction()
      // }

    case .unauthenticated:
      guard isUserCurrentlyAuthenticated else {
        debugLog("ℹ️ HabitRepository: Ignoring unauthenticated state before initial login completes")
        return
      }
      isUserCurrentlyAuthenticated = false
      
      // ✅ CRITICAL FIX: Migration flag is cleared in AuthenticationManager.signOut()
      // before authState changes to .unauthenticated, so we don't need to clear it here
      debugLog("🔄 HabitRepository: User signed out")
      
      // ✅ DEBUG: Log userId before clearing
      let userIdBeforeClear = await CurrentUser().idOrGuest
      debugLog("🔐 HabitRepository: CurrentUser().idOrGuest before clear = '\(userIdBeforeClear.isEmpty ? "EMPTY" : userIdBeforeClear)'")
      
      // ✅ OPTION B: Account data isolation - do NOT convert account data to guest
      // Account data stays with the account (userId = "abc123") and is hidden on sign-out
      // Queries filter by CurrentUser().idOrGuest which returns "" when signed out
      // This means queries return no account data, showing empty app state
      
      // ✅ CRITICAL: Clear in-memory caches IMMEDIATELY (before loading)
      // This ensures UI shows empty state right away
      self.habits = []
      debugLog("✅ HabitRepository: Cleared in-memory habits array (count: \(self.habits.count))")
      
      // ✅ CRITICAL: Small delay to ensure Auth.auth().currentUser is fully nil
      // This prevents race condition where loadHabits() might see old userId
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
      
      // ✅ DEBUG: Verify userId after delay
      let userIdAfterDelay = await CurrentUser().idOrGuest
      debugLog("🔐 HabitRepository: CurrentUser().idOrGuest after delay = '\(userIdAfterDelay.isEmpty ? "EMPTY" : userIdAfterDelay)'")
      debugLog("🔐 HabitRepository: Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
      
      // ✅ GUEST-ONLY MODE: Sync disabled - no cloud sync needed
      // await SyncEngine.shared.stopPeriodicSync(reason: "user signed out")
      debugLog("🔄 HabitRepository: User signed out, loading guest data...")
      // Load guest habits (queries will filter by userId = "" which returns no account data)
      await loadHabits(force: true)
      debugLog("✅ HabitRepository: Guest data loaded for unauthenticated user (habits count: \(self.habits.count))")
      
      // ✅ CRITICAL FIX: Refresh XP state for guest mode
      // This ensures XP is recalculated with the new userId (empty string) after sign-out
      // Query DailyAwards for userId == "" will return 0 awards, so XP will be 0
      await DailyAwardService.shared.refreshXPState()
      debugLog("✅ HabitRepository: XP state refreshed for guest mode")

    case .authenticating:
      debugLog("🔄 HabitRepository: User authenticating, keeping current data...")

    case .error(let error):
      debugLog("❌ HabitRepository: Authentication error: \(error)")
    }
  }

  /// Clear all user-specific data when switching users
  private func clearUserData() async {
    // Clear any cached data and reset state
    habits = []
    objectWillChange.send()

    // Clear any user-specific cache or temporary data
    // This ensures a clean slate when switching between users
    debugLog("✅ HabitRepository: User data cleared for account switch")
  }

  // MARK: - App Lifecycle Handling

  @objc
  private func appDidBecomeActive() {
    debugLog("🔄 HabitRepository: App became active, reloading habits...")

    // Refresh habits from storage (debounced to avoid redundant loads)
    Task {
      await loadHabits()
      debugLog("✅ HabitRepository: Habits reloaded after app became active")
    }
  }

  // MARK: - XP System Integration

  /// Check if all habits are completed for a date and award XP if so
  private func checkAndAwardXPForDate(_ date: Date) async {
    let dateKey = Habit.dateKey(for: date)  // ✅ Uses device timezone

    debugLog("🎯 XP CHECK: Checking if all habits completed for \(dateKey)")

    // Check if all habits are completed for this date
    let allCompleted = habits.allSatisfy { habit in
      let progress = habit.getProgress(for: date)
      let goalAmount = extractNumericGoalAmount(from: habit.goal)
      return progress >= goalAmount
    }

    debugLog("🎯 XP CHECK: All habits completed: \(allCompleted)")

    if allCompleted {
      debugLog("🎯 XP CHECK: ✅ All habits completed, awarding XP")

      // Award XP using new Firebase-based DailyAwardService
      do {
        let awardService = DailyAwardService.shared
        try await awardService.awardDailyCompletionBonus(on: date)
        debugLog("🎯 XP CHECK: XP awarded for all habits complete")
      } catch {
        debugLog("❌ XP CHECK: Failed to award XP: \(error)")
      }
    } else {
      debugLog("🎯 XP CHECK: ❌ Not all habits completed, no XP awarded")

      // Note: XP revocation handled by DailyAwardService integrity checks
      // The ledger-based system doesn't need explicit revocation
      debugLog("🎯 XP CHECK: ❌ Not all habits completed, no XP change needed")
    }
  }

  /// Extract numeric goal amount from goal string (e.g., "3 times per day" -> 3)
  private func extractNumericGoalAmount(from goal: String) -> Int {
    let components = goal.components(separatedBy: CharacterSet.decimalDigits.inverted)
    for component in components {
      if let amount = Int(component), amount > 0 {
        return amount
      }
    }
    return 1 // Default to 1 if no number found
  }

  /// Load user's XP from SwiftData DailyAward records
  private func loadUserXPFromSwiftData(userId: String) async {
    debugLog("🎯 XP LOAD: Loading XP from SwiftData for userId: \(userId)")

    // ✅ FIX #10: Use SwiftDataContainer's ModelContext instead of creating a new container
    // Creating a new container was causing Persistent History to delete tables
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      XPManager.shared.loadUserXPFromSwiftData(userId: userId, modelContext: modelContext)
      debugLog("✅ XP LOAD: User XP loaded successfully")
    }
  }

  /// Reset all user data to userId = "" when signing out
  /// This ensures habits/completions/awards are detected as guest data for streak calculation
  /// ✅ FIX: Resets ALL data that doesn't have userId = "" (since user has already signed out)
  /// ⚠️ DISABLED: Option B - Account Data Isolation
  /// This function is disabled to preserve account data ownership.
  /// Account data (userId = "abc123") stays with the account and is hidden on sign-out
  /// by filtering queries by CurrentUser().idOrGuest (which returns "" when signed out).
  /// 
  /// Previous behavior (Option A): Converted account data to guest data on sign-out
  /// Current behavior (Option B): Account data remains unchanged, queries hide it
  private func resetUserDataToGuest() async {
    // ✅ OPTION B: Do nothing - account data stays with the account
    // Queries filter by userId, so account data is automatically hidden when signed out
    debugLog("ℹ️ HabitRepository: resetUserDataToGuest() disabled - account data isolation enabled")
    debugLog("   Account data remains unchanged. Queries filter by CurrentUser().idOrGuest")
    debugLog("   When signed out, queries return no account data (empty app state)")
    return
  }
}


// MARK: - Note

struct Note {
  let id: UUID
  let title: String
  let content: String
  let tags: [String]
  let createdAt: Date
  let updatedAt: Date
}

// MARK: - DifficultyLog

struct DifficultyLog {
  let id: UUID
  let difficulty: Int // 1-10 scale
  let context: String
  let timestamp: Date
}

// MARK: - MoodLog

struct MoodLog {
  let id: UUID
  let mood: Int // 1-10 scale
  let timestamp: Date
}

