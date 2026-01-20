import Combine
import FirebaseAuth
import SwiftUI
import SwiftData
import UIKit

// Import for streak calculations
import Foundation

// Import for widget updates
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Tab

enum Tab: Hashable {
  case home
  case progress
  case habits
  case more
}

// MARK: - HomeViewState

@MainActor
class HomeViewState: ObservableObject {
  // MARK: Lifecycle

  init() {
    debugLog("🚀 HomeViewState: Initializing...")
    let today = LegacyDateUtils.today()
    self.selectedDate = today
    debugLog("🚀 HomeViewState: Initial selectedDate: \(selectedDate)")

    // Debug the repository state
    habitRepository.debugRepositoryState()

    // Initialize with current habits from repository to avoid empty state
    self.habits = habitRepository.habits
    self.isLoadingHabits = habits.isEmpty
    
    // ✅ CRASH FIX: Calculate initial streak
    // ✅ WIDGET SYNC: Ensure streak is synced early on app launch
    // First try to read any existing streak from UserDefaults as a fallback
    if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
      let existingStreak = sharedDefaults.integer(forKey: "widgetCurrentStreak")
      if existingStreak > 0 {
        // Keep existing value until we calculate the real one
        self.currentStreak = existingStreak
        debugLog("📱 WIDGET_SYNC: Preserved existing streak value from UserDefaults: \(existingStreak)")
      }
    }
    self.updateStreak()
    
    // ✅ CLEANUP: Remove old soft-deleted habits on app launch
    Task {
      await self.cleanupOldSoftDeletedHabits()
    }

    // Subscribe to HabitRepository changes
    habitRepository.$habits
      .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
      .sink { [weak self] habits in
        self?.habits = habits
        self?.isLoadingHabits = false
        // ✅ CRASH FIX: Update streak when habits change
        self?.updateStreak()
        // ✅ WIDGET SYNC: Sync habits to widget storage
        WidgetDataSync.shared.syncHabitsToWidget(habits)
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)
    
    // ✅ FIX: Listen for streak updates from completion flow
    NotificationCenter.default.publisher(for: NSNotification.Name("StreakUpdated"))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        if let newStreak = notification.userInfo?["newStreak"] as? Int {
          self?.currentStreak = newStreak
        }
      }
      .store(in: &cancellables)
    
    // ✅ STREAK MODE: Listen for streak mode changes and recalculate streaks
    NotificationCenter.default.publisher(for: .streakModeDidChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        debugLog("🔄 STREAK_MODE: Mode changed, recalculating streaks")
        self?.requestStreakRecalculation(reason: "Streak mode changed")
      }
      .store(in: &cancellables)
  }

  // MARK: Internal

  @Published var selectedDate = Calendar.current.startOfDay(for: Date())
  @Published var scrollPosition: Int? = 0
  @Published var isOnCurrentWeek = true
  @Published var selectedTab: Tab = .home
  @Published var selectedStatsTab = 0
  @Published var habits: [Habit] = []
  @Published var isLoadingHabits = true

  // UI State
  @Published var showingCreateHabit = false
  @Published var showingPaywall = false
  @Published var habitToEditSession: HabitEditSession? = nil
  @Published var showingDeleteConfirmation = false
  @Published var habitToDelete: Habit?
  @Published var showingOverviewView = false
  @Published var showingNotificationView = false
  @Published var deletedHabitForUndo: Habit? = nil
  @Published var createdHabitName: String?

  /// Core Data adapter
  let habitRepository = HabitRepository.shared
  
  /// Subscription manager
  @ObservedObject private var subscriptionManager = SubscriptionManager.shared

  /// ✅ CRASH FIX: Cache streak as @Published instead of computed property
  /// Computed properties that access @Published cause infinite loops!
  @Published var currentStreak: Int = 0
  private var lastStreakUpdateTime: Date?
  private let streakUpdateInterval: TimeInterval = 0.5
  private var pendingStreakRecalculation = false
  private var activePersistenceOperations = 0
  // ✅ STEP 1: Add flag to track if current recalculation is user-initiated
  private var isUserInitiatedRecalculation = false
  // ✅ RACE CONDITION FIX: Track continuations waiting for persistence to complete
  private var pendingPersistenceContinuations: [CheckedContinuation<Void, Never>] = []
  
  /// Calculate and update streak (call this when habits change)
  func updateStreak() {
    // ✅ FIX: Read streak from GlobalStreakModel in SwiftData instead of old calculation
    Task { @MainActor in
      defer { self.processStreakRecalculationQueue() }
      
      // ✅ STEP 1: Read the flag before async operations
      let isUserInitiated = self.isUserInitiatedRecalculation
      if isUserInitiated {
        debugLog("✅ STEP1_FLAG: Reading isUserInitiatedRecalculation = true in updateStreak()")
      }
      
      // ✅ STEP 1: Reset the flag immediately after reading
      self.isUserInitiatedRecalculation = false
      if isUserInitiated {
        debugLog("✅ STEP1_FLAG: Reset isUserInitiatedRecalculation = false")
      }
      
      do {
        // ✅ FIX: Add small delay to ensure SwiftData context sees the newly saved streak
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        
        let modelContext = SwiftDataContainer.shared.modelContext
        
        // ✅ OPTION B: Use CurrentUser().idOrGuest for consistency
        // Returns Firebase UID when signed in, "" when signed out
        // This ensures queries filter correctly for account data isolation
        let userId = await CurrentUser().idOrGuest
        
        var descriptor = FetchDescriptor<GlobalStreakModel>(
          predicate: #Predicate { streak in
            streak.userId == userId
          }
        )
        // ✅ FIX: Include newly inserted objects in the fetch
        descriptor.includePendingChanges = true
        
        let allStreaks = try modelContext.fetch(descriptor)
        
        if let streak = allStreaks.first {
          let loadedStreak = streak.currentStreak
          let timestamp = Date()
          let oldStreak = currentStreak
          
          print("💰 [STREAK_TRACE] \(timestamp) updateStreak() - START")
          print("   Source: GlobalStreakModel query")
          print("   Thread: MainActor")
          print("   Streak changing from \(oldStreak) to \(loadedStreak)")
          
          debugLog("🔍 UI_STREAK: updateStreak() will display streak = \(loadedStreak)")
          currentStreak = loadedStreak
          
          // ✅ WIDGET SYNC: Update UserDefaults for widget extension IMMEDIATELY
          // This ensures the widget can read the value even if the app is not running
          syncStreakToWidget(loadedStreak)
          
          print("💰 [STREAK_TRACE] \(Date()) updateStreak() - COMPLETE")
          print("   Final: currentStreak=\(self.currentStreak)")
          
          // ✅ FIX: Also broadcast via notification for consistency
          // ✅ STEP 1: Include isUserInitiated flag in notification
          NotificationCenter.default.post(
            name: NSNotification.Name("StreakUpdated"),
            object: nil,
            userInfo: [
              "newStreak": loadedStreak,
              "isUserInitiated": isUserInitiated
            ]
          )
          debugLog("📢 STEP1_NOTIFICATION: Posted StreakUpdated notification with newStreak: \(loadedStreak), isUserInitiated: \(isUserInitiated)")
        } else {
          debugLog("🔍 UI_STREAK: updateStreak() found no GlobalStreakModel, defaulting to 0")
          currentStreak = 0
          // ✅ CRITICAL: Still sync 0 to UserDefaults so widget knows the value is valid
          syncStreakToWidget(0)
        }
      } catch {
        debugLog("🔍 UI_STREAK: updateStreak() failed to load streak, defaulting to 0 (\(error.localizedDescription))")
        currentStreak = 0
        // ✅ CRITICAL: Still sync 0 to UserDefaults so widget knows the value is valid
        syncStreakToWidget(0)
      }
    }
  }

  func updateHabits(_ newHabits: [Habit]) {
    // This method is used for bulk updates like streak validation
    // For individual habit operations, use createHabit, updateHabit, or deleteHabit
    habitRepository.saveHabits(newHabits)
    lastHabitsUpdate = Date()
  }
  
  /// Check if user can create a new habit and handle paywall if needed
  func handleCreateHabitRequest() {
    print("⌨️ HOME: Create button tapped at \(Date())")
    let currentHabitCount = habits.count
    
    let canCreate = subscriptionManager.canCreateHabit(currentHabitCount: currentHabitCount)
    #if DEBUG
    print("🔍 HomeView - Can create habit: \(canCreate), isPremium: \(subscriptionManager.isPremium), habitCount: \(currentHabitCount)")
    #endif
    if canCreate {
      // User can create habit, show create flow
      showingCreateHabit = true
    } else {
      // User has reached limit, show paywall
      showingPaywall = true
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func toggleHabitCompletion(_ habit: Habit, for date: Date? = nil) async {
    let targetDate = date ?? Calendar.current.startOfDay(for: Date())
    let opContext = "toggleHabitCompletion(\(habit.id))"
    beginPersistenceOperation(opContext)
    defer { endPersistenceOperation(opContext) }

    do {
      try await habitRepository.toggleHabitCompletion(habit, for: targetDate)
      debugLog("✅ GUARANTEED: Completion toggled and persisted")
      
      // ✅ WIDGET SYNC: Sync updated habit to widget storage immediately after completion toggle
      // Get the updated habit from the repository (it should have the latest completionStatus/completionHistory)
      if let updatedHabit = habitRepository.habits.first(where: { $0.id == habit.id }) {
        WidgetDataSync.shared.syncHabitToWidget(updatedHabit)
        debugLog("📱 WIDGET_SYNC: Synced updated habit '\(updatedHabit.name)' to widget storage")
      } else {
        debugLog("⚠️ WIDGET_SYNC: Could not find updated habit in repository, syncing original habit")
        WidgetDataSync.shared.syncHabitToWidget(habit)
      }
      
      requestStreakRecalculation(reason: "Persistence completed for \(opContext)")
    } catch {
      debugLog("❌ Failed to toggle completion: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  /// ✅ UNDO TOAST: Shows toast immediately for instant feedback
  func deleteHabit(_ habit: Habit) async {
    print("🗑️ DELETE_FLOW: HomeViewState.deleteHabit() - START for habit: \(habit.name) (ID: \(habit.id))")
    
    // Show toast immediately and remove from local state for instant UI update
    await MainActor.run {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
        self.deletedHabitForUndo = habit
      }
      self.habits.removeAll { $0.id == habit.id }
      print("🗑️ DELETE_FLOW: Local state updated, toast shown")
    }

    // Delete from storage in background
    print("🗑️ DELETE_FLOW: Calling habitRepository.deleteHabit()")
    do {
      try await habitRepository.deleteHabit(habit)
      print("🗑️ DELETE_FLOW: Delete completed successfully")
      debugLog("✅ GUARANTEED: Habit deleted and persisted")
      
      // ✅ Recalculate streak after delete
      await MainActor.run {
        print("🗑️ DELETE_FLOW: Recalculating streak after deletion")
        self.requestStreakRecalculation(reason: "Habit deleted")
      }
    } catch {
      print("🗑️ DELETE_FLOW: ERROR: \(error.localizedDescription)")
      debugLog("❌ Failed to delete habit: \(error.localizedDescription)")
      
      // ✅ ERROR RECOVERY: Restore habit to UI and dismiss toast
      await MainActor.run {
        self.habits.append(habit)
        self.deletedHabitForUndo = nil
      }
    }
    
    habitToDelete = nil
    print("🗑️ DELETE_FLOW: END")
  }
  
  /// Restore a soft-deleted habit (called from undo toast)
  func restoreHabit(_ habit: Habit) async {
    print("♻️ [RESTORE] HomeViewState.restoreHabit() - START for habit: \(habit.name) (ID: \(habit.id))")
    
    // ✅ IMMEDIATELY dismiss toast and add habit to UI (instant feedback)
    await MainActor.run {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        self.deletedHabitForUndo = nil  // Dismiss toast FIRST
      }
      if !self.habits.contains(where: { $0.id == habit.id }) {
        self.habits.append(habit)
        print("♻️ [RESTORE] Habit added to local UI")
      } else {
        print("♻️ [RESTORE] Habit already in local UI")
      }
    }
    
    // Background: Clear deleted tracking
    print("♻️ [RESTORE] Clearing deleted tracking...")
    SyncEngine.clearDeletedHabit(habit.id)
    await HabitStore.shared.unmarkHabitAsDeleted(habit.id)
    print("♻️ [RESTORE] Deleted tracking cleared")
    
    // Background: Restore in SwiftData (unmark soft-delete)
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      let habitId = habit.id
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { $0.id == habitId }
      )
      
      if let habitData = try modelContext.fetch(descriptor).first {
        print("♻️ [RESTORE] Found habit in SwiftData (deletedAt: \(habitData.deletedAt?.description ?? "nil"))")
        
        // Unmark soft-delete
        if habitData.deletedAt != nil {
          habitData.deletedAt = nil
          habitData.deletionSource = nil
          try modelContext.save()
          print("♻️ [RESTORE] Soft-delete unmarked in SwiftData")
        } else {
          print("♻️ [RESTORE] Habit wasn't soft-deleted yet (delete in progress)")
        }
        
        // Re-upload to Firestore (habit was hard-deleted during soft-delete)
        print("♻️ [RESTORE] Re-uploading to Firestore...")
        FirebaseBackupService.shared.backupHabit(habit)
        
      } else {
        print("⚠️ [RESTORE] Habit not found in SwiftData")
      }
    } catch {
      print("❌ [RESTORE] Error restoring in SwiftData: \(error)")
    }
    
    // Recalculate streak after restore
    await MainActor.run {
      print("♻️ [RESTORE] Recalculating streak...")
      self.requestStreakRecalculation(reason: "Habit restored via Undo")
    }
    
    print("♻️ [RESTORE] HomeViewState.restoreHabit() - END")
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func updateHabit(_ updatedHabit: Habit) async {
    do {
      try await habitRepository.updateHabit(updatedHabit)
      debugLog("✅ GUARANTEED: Habit updated and persisted")
      // ✅ WIDGET SYNC: Sync updated habit to widget storage
      WidgetDataSync.shared.syncHabitToWidget(updatedHabit)
    } catch {
      debugLog("❌ Failed to update habit: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func setHabitProgress(_ habit: Habit, for date: Date, progress: Int) async {
    let startTime = Date()
    let opContext = "setHabitProgress(\(habit.id), progress: \(progress))"
    beginPersistenceOperation(opContext)
    defer { endPersistenceOperation(opContext) }

    debugLog("═══════════════════════════════════════════════════════")
    debugLog("🔄 HomeViewState: setHabitProgress called for \(habit.name), progress: \(progress)")
    debugLog("⏱️ AWAIT_START: setProgress() at \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
    do {
      try await habitRepository.setProgress(for: habit, date: date, progress: progress)
      let endTime = Date()
      let duration = endTime.timeIntervalSince(startTime)
      debugLog("⏱️ AWAIT_END: setProgress() at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
      debugLog("✅ GUARANTEED: Progress saved and persisted in \(String(format: "%.3f", duration))s")
      debugLog("═══════════════════════════════════════════════════════")
      
      // ✅ WIDGET SYNC: Sync updated habit to widget storage immediately after progress update
      // Get the updated habit from the repository (it should have the latest completionStatus/completionHistory)
      if let updatedHabit = habitRepository.habits.first(where: { $0.id == habit.id }) {
        WidgetDataSync.shared.syncHabitToWidget(updatedHabit)
        debugLog("📱 WIDGET_SYNC: Synced updated habit '\(updatedHabit.name)' to widget storage")
      } else {
        debugLog("⚠️ WIDGET_SYNC: Could not find updated habit in repository, syncing original habit")
        WidgetDataSync.shared.syncHabitToWidget(habit)
      }
      
      requestStreakRecalculation(reason: "Persistence completed for \(opContext)")
    } catch {
      let endTime = Date()
      let duration = endTime.timeIntervalSince(startTime)
      debugLog("⏱️ AWAIT_END: setProgress() at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
      debugLog("❌ Failed to set progress: \(error.localizedDescription) (took \(String(format: "%.3f", duration))s)")
      debugLog("═══════════════════════════════════════════════════════")
    }
  }

  func createHabit(_ habit: Habit) async {
    // Log habit creation start for crash debugging
    CrashlyticsService.shared.logHabitCreationStart(habitName: habit.name)
    CrashlyticsService.shared.setValue("\(habits.count)", forKey: "habits_count_before_create")
    
    #if DEBUG
    debugLog("═══════════════════════════════════════════════════════")
    debugLog("🎯 [3/8] HomeViewState.createHabit: creating habit")
    debugLog("  → Habit: '\(habit.name)', ID: \(habit.id)")
    
    // ✅ DIAGNOSTIC: Log habit dates
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    debugLog("🗓️ DIAGNOSTIC: habit.startDate = \(dateFormatter.string(from: habit.startDate))")
    if let end = habit.endDate {
      debugLog("🗓️ DIAGNOSTIC: habit.endDate = \(dateFormatter.string(from: end))")
    } else {
      debugLog("🗓️ DIAGNOSTIC: habit.endDate = nil")
    }
    let today = Date()
    debugLog("🗓️ DIAGNOSTIC: today = \(dateFormatter.string(from: today))")
    debugLog("🗓️ DIAGNOSTIC: startDate is today? \(Calendar.current.isDate(habit.startDate, inSameDayAs: today))")
    
    debugLog("  → Current habits count: \(habits.count)")
    #endif
    
    // Check if vacation mode is active
    if VacationManager.shared.isActive {
      #if DEBUG
      debugLog("🚫 HomeViewState: Cannot create habit during vacation mode")
      debugLog("═══════════════════════════════════════════════════════")
      #endif
      CrashlyticsService.shared.log("Habit creation blocked: vacation mode active")
      return
    }
    
    #if DEBUG
    debugLog("✅ Vacation mode check passed")
    debugLog("🎯 [4/8] HomeViewState.createHabit: calling HabitRepository")
    #endif

    await habitRepository.createHabit(habit)
    
    // Log successful creation
    CrashlyticsService.shared.logHabitCreationComplete(habitID: habit.id.uuidString)
    CrashlyticsService.shared.setValue("\(habits.count)", forKey: "habits_count_after_create")

    #if DEBUG
    debugLog("  → HabitRepository.createHabit completed")
    debugLog("  → New habits count: \(habits.count)")
    debugLog("═══════════════════════════════════════════════════════")
    #endif
  }

  func backupHabits() {
    // Backup is now handled automatically by the HabitStore
    debugLog("✅ HomeView: Habits are automatically backed up by HabitStore")
  }

  func loadHabits() {
    // Core Data adapter automatically loads habits
    debugLog("🔄 HomeView: Habits loaded from Core Data")
  }

  func cleanupDuplicateHabits() {
    debugLog("🔄 HomeView: Cleaning up duplicate habits...")
    habitRepository.cleanupDuplicateHabits()
  }

  // MARK: - Streak Recalculation Queue

  func requestStreakRecalculation(reason: String, delay: TimeInterval = 0, isUserInitiated: Bool = false) {
    debugLog(
      "📥 STREAK_QUEUE: Request received (\(reason)) delay=\(String(format: "%.2f", delay))s, isUserInitiated: \(isUserInitiated)")
    
    // ✅ STEP 1: Store the flag when user-initiated
    if isUserInitiated {
      self.isUserInitiatedRecalculation = true
      debugLog("✅ STEP1_FLAG: Set isUserInitiatedRecalculation = true (reason: \(reason))")
    }
    
    pendingStreakRecalculation = true

    if delay > 0 {
      scheduleStreakRecalculationRetry(after: delay)
    } else {
      processStreakRecalculationQueue()
    }
  }

  private func beginPersistenceOperation(_ context: String) {
    activePersistenceOperations += 1
    debugLog(
      "⏳ STREAK_QUEUE: Persistence op started (\(context)) → count=\(activePersistenceOperations)")
  }

  private func endPersistenceOperation(_ context: String) {
    activePersistenceOperations = max(0, activePersistenceOperations - 1)
    debugLog(
      "⏳ STREAK_QUEUE: Persistence op finished (\(context)) → remaining=\(activePersistenceOperations)")
    
    // ✅ RACE CONDITION FIX: Signal any waiting continuations when all operations complete
    if activePersistenceOperations == 0 {
      let continuations = pendingPersistenceContinuations
      pendingPersistenceContinuations.removeAll()
      debugLog("⏳ STREAK_QUEUE: Resuming \(continuations.count) waiting continuation(s)")
      for continuation in continuations {
        continuation.resume()
      }
    }
    
    processStreakRecalculationQueue()
  }
  
  /// ✅ RACE CONDITION FIX: Wait for all pending persistence operations to complete
  /// This ensures streak calculation doesn't start until data is fully saved to SwiftData
  func waitForPersistenceCompletion() async {
    // If no operations in progress, return immediately
    guard activePersistenceOperations > 0 else {
      debugLog("⏳ WAIT_PERSISTENCE: No operations in progress, returning immediately")
      return
    }
    
    debugLog("⏳ WAIT_PERSISTENCE: Waiting for \(activePersistenceOperations) operation(s) to complete...")
    
    // Otherwise, wait for signal from endPersistenceOperation
    await withCheckedContinuation { continuation in
      pendingPersistenceContinuations.append(continuation)
    }
    
    debugLog("✅ WAIT_PERSISTENCE: All persistence operations completed!")
  }

  @MainActor
  private func processStreakRecalculationQueue() {
    guard pendingStreakRecalculation else { return }

    guard activePersistenceOperations == 0 else {
      debugLog(
        "⏳ STREAK_QUEUE: Waiting for \(activePersistenceOperations) persistence op(s) before recalculation")
      return
    }

    pendingStreakRecalculation = false
    updateAllStreaks()
  }

  private func scheduleStreakRecalculationRetry(after delay: TimeInterval) {
    let clampedDelay = max(0, delay)
    let nanoseconds = UInt64(clampedDelay * 1_000_000_000)

    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: nanoseconds)
      guard let self else { return }
      self.processStreakRecalculationQueue()
    }
  }

  func updateAllStreaks() {
    let now = Date()
    if let lastUpdate = lastStreakUpdateTime {
      let elapsed = now.timeIntervalSince(lastUpdate)
      if elapsed < streakUpdateInterval {
        let remaining = streakUpdateInterval - elapsed
        debugLog(
          "ℹ️ STREAK_UPDATE: Skipping - updated \(String(format: "%.1f", elapsed))s ago, retrying in \(String(format: "%.2f", remaining))s")
        pendingStreakRecalculation = true
        scheduleStreakRecalculationRetry(after: remaining)
        return
      }
    }
    lastStreakUpdateTime = now
    
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    debugLog("")
    debugLog(String(repeating: "=", count: 60))
    debugLog("🔄 STREAK_TRIGGER: updateAllStreaks() called at \(timestamp)")
    debugLog("   Triggered by: Reactive callback from habit completion/uncompletion")
    debugLog(String(repeating: "=", count: 60))
    
    // ✅ CRITICAL FIX: Recalculate streak directly from CompletionRecords (legacy system)
    Task { @MainActor in
      do {
        // ✅ GUEST MODE ONLY: Always use empty string for userId
        let userId = await CurrentUser().idOrGuest // Always "" in guest mode
        
        let modelContext = SwiftDataContainer.shared.modelContext
        
        debugLog("🔄 STREAK_RECALC: Starting streak recalculation from CompletionRecords for user '\(userId.isEmpty ? "guest" : userId)'")
        
        // ✅ ONE-TIME BACKFILL: Calculate and restore historical longestStreak for existing users
        let backfillKey = "longest_streak_backfill_completed_\(userId)"
        let hasBackfilled = UserDefaults.standard.bool(forKey: backfillKey)
        
        if !hasBackfilled {
          debugLog("🔄 STREAK_BACKFILL: Running one-time backfill to restore historical longestStreak")
          await backfillHistoricalLongestStreak(userId: userId, modelContext: modelContext)
          UserDefaults.standard.set(true, forKey: backfillKey)
          debugLog("✅ STREAK_BACKFILL: Backfill completed and marked as done")
        }
        
        // Get or create GlobalStreakModel
        let streakDescriptor = FetchDescriptor<GlobalStreakModel>(
          predicate: #Predicate { streak in
            streak.userId == userId
          }
        )
        
        let existingStreaks = try modelContext.fetch(streakDescriptor)
        let streak = existingStreaks.first ?? {
          let newStreak = GlobalStreakModel(userId: userId)
          modelContext.insert(newStreak)
          return newStreak
        }()
        debugLog("🔍 STREAK_START: GlobalStreakModel.currentStreak = \(streak.currentStreak), longestStreak = \(streak.longestStreak)")
        
        // ✅ CRITICAL FIX: Use HabitRepository.habits instead of querying SwiftData directly
        // HabitRepository.habits already filters out soft-deleted habits (deletedAt != nil)
        // Querying SwiftData directly was including ALL habits (even deleted ones), breaking streak calculation
        
        // ✅ DIAGNOSTIC: Show what was fixed
        #if DEBUG
        var allHabitsDescriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate { habit in
            habit.userId == userId
          }
        )
        allHabitsDescriptor.includePendingChanges = true
        if let allHabitDataList = try? modelContext.fetch(allHabitsDescriptor) {
          let allHabitsCount = allHabitDataList.count
          let deletedHabitsCount = allHabitDataList.filter { $0.deletedAt != nil }.count
          let activeHabitsCount = habitRepository.habits.count
          
          if allHabitsCount != activeHabitsCount {
            debugLog("⚠️ [HABIT_LOAD] MISMATCH DETECTED (but now fixed!):")
            debugLog("   SwiftData has \(allHabitsCount) total habits (\(deletedHabitsCount) soft-deleted)")
            debugLog("   HabitRepository has \(activeHabitsCount) active habits")
            debugLog("   ✅ Using HabitRepository (\(activeHabitsCount) active) for streak calculation")
          }
        }
        #endif
        
        let habits = habitRepository.habits
        
        debugLog("🔄 STREAK_RECALC: Using \(habits.count) active habits from HabitRepository (soft-deleted habits excluded)")
        
        guard !habits.isEmpty else {
          debugLog("ℹ️ STREAK_RECALC: No habits found - resetting streak to 0")
          streak.currentStreak = 0
          streak.lastCompleteDate = nil
          try modelContext.save()
          syncStreakToWidget(0)
          updateStreak()
          return
        }
        
        var completionDescriptor = FetchDescriptor<CompletionRecord>()
        completionDescriptor.includePendingChanges = true
        let allCompletionRecords = try modelContext.fetch(completionDescriptor)
        let filteredCompletionRecords = allCompletionRecords.filter { record in
          guard record.isCompleted else { return false }
          if userId.isEmpty || userId == "guest" {
            return record.userId.isEmpty || record.userId == "guest" || record.userId == userId
          } else {
            return record.userId == userId
          }
        }

        let today = DateUtils.startOfDay(for: Date())
        let calendar = Calendar.current

        debugLog("🔄 STREAK_RECALC: Starting from TODAY (\(Habit.dateKey(for: today))) and counting backwards")

        let computation = StreakCalculator.computeCurrentStreak(
          habits: habits,
          completionRecords: filteredCompletionRecords,
          today: today,
          calendar: calendar)

        // ✅ HIGH-WATER MARK: Calculate longest streak from entire history
        let calculatedLongestStreak = StreakCalculator.computeLongestStreakFromHistory(
          habits: habits,
          completionRecords: filteredCompletionRecords,
          calendar: calendar)

        let oldStreak = streak.currentStreak
        let storedLongestBefore = streak.longestStreak
        let mismatchDetected = oldStreak != computation.currentStreak

        debugLog("🔍 STREAK_END: Calculated streak = \(computation.currentStreak), saving to GlobalStreakModel")
        debugLog("📊 STREAK_LONGEST: Stored longestStreak before: \(storedLongestBefore), calculated from history: \(calculatedLongestStreak)")
        
        streak.currentStreak = computation.currentStreak
        // ✅ HIGH-WATER MARK: Only update longestStreak if the newly calculated value is GREATER
        // This ensures longestStreak never decreases, even if historical data has issues
        if calculatedLongestStreak > storedLongestBefore {
          streak.longestStreak = calculatedLongestStreak
          debugLog("📈 STREAK_HIGH_WATER: Updated longestStreak \(storedLongestBefore) → \(calculatedLongestStreak)")
        } else {
          debugLog("📊 STREAK_HIGH_WATER: Kept longestStreak at \(storedLongestBefore) (calculated: \(calculatedLongestStreak))")
        }
        streak.lastCompleteDate = computation.lastCompleteDate
        streak.lastUpdated = Date()

        try modelContext.save()
        
        // ✅ WIDGET SYNC: Update UserDefaults for widget extension
        syncStreakToWidget(computation.currentStreak)

        debugLog("")
        debugLog(String(repeating: "=", count: 60))
        debugLog("✅ STREAK_RECALC: Recalculation COMPLETE")
        debugLog("   Old streak: \(oldStreak) day(s)")
        debugLog("   New streak: \(computation.currentStreak) day(s)")
        debugLog("   Last complete date: \(computation.lastCompleteDate.map { Habit.dateKey(for: $0) } ?? "none")")
        debugLog("   Longest streak: \(streak.longestStreak) day(s) (stored: \(storedLongestBefore), calculated: \(calculatedLongestStreak))")
        debugLog("   ✅ GLOBAL_STREAK_FINAL: Saved to GlobalStreakModel and UI: \(computation.currentStreak)")
        debugLog(String(repeating: "=", count: 60))
        debugLog("")

        let userFingerprint = userId.isEmpty ? "guest" : String(userId.prefix(6))
        TelemetryService.shared.logEvent(
          "streak.update.success",
          data: [
            "user": userFingerprint,
            "old": oldStreak,
            "new": computation.currentStreak,
            "processedDays": computation.processedDayCount
          ])

        if mismatchDetected {
          TelemetryService.shared.logEvent(
            "streak.integrity.mismatch",
            data: [
              "user": userFingerprint,
              "previous": oldStreak,
              "current": computation.currentStreak
            ])
        }

        let snapshot = StreakIntegritySnapshot(
          userId: userId,
          timestamp: Date(),
          currentStreak: computation.currentStreak,
          longestStreak: streak.longestStreak,
          lastCompleteDate: computation.lastCompleteDate,
          completionChecksum: StreakCalculator.checksum(for: filteredCompletionRecords))
        StreakIntegrityChecker.shared.handleSnapshot(snapshot)

        // ✅ FIX: Update UI streak from the value we just saved (no need to read from DB again)
        // This avoids a race condition where updateStreak() might read a stale value before SwiftData save completes
        currentStreak = computation.currentStreak
        
      } catch {
        TelemetryService.shared.logError("streak.update.failed", error: error)
        debugLog("❌ STREAK_RECALC: Failed to recalculate streak: \(error)")
      }
    }
  }
  
  /// One-time backfill to calculate and restore historical longestStreak for existing users
  /// This runs once per user to restore their historical best streak that was never persisted before
  
  // MARK: - Soft Delete Cleanup
  
  /// Clean up soft-deleted habits older than 30 days
  /// This permanently removes habits that have been in the "Recently Deleted" state for too long
  func cleanupOldSoftDeletedHabits() async {
    debugLog("🗑️ CLEANUP: Starting cleanup of old soft-deleted habits...")
    
    let modelContext = SwiftDataContainer.shared.modelContext
    let userId = await CurrentUser().idOrGuest
    
    do {
      // Find soft-deleted habits older than 30 days
      let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
      
      // ✅ FIX: SwiftData predicates can't capture Date variables
      // Solution: Fetch all soft-deleted habits for user, then filter in Swift
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { habit in
          habit.userId == userId && habit.deletedAt != nil
        }
      )
      
      let allDeletedHabits = try modelContext.fetch(descriptor)
      
      // Filter in Swift for date comparison
      let oldDeletedHabits = allDeletedHabits.filter { habitData in
        guard let deletedAt = habitData.deletedAt else { return false }
        return deletedAt < thirtyDaysAgo
      }
      
      guard !oldDeletedHabits.isEmpty else {
        debugLog("🗑️ CLEANUP: No old soft-deleted habits found")
        return
      }
      
      debugLog("🗑️ CLEANUP: Found \(oldDeletedHabits.count) old soft-deleted habits to permanently delete")
      
      for habitData in oldDeletedHabits {
        debugLog("🗑️ CLEANUP: Permanently deleting '\(habitData.name)' (deleted on \(habitData.deletedAt?.description ?? "unknown"))")
        
        // Delete associated CompletionRecords
        // ✅ FIX: SwiftData predicates can't capture UUID variables
        // Solution: Fetch all CompletionRecords for user, then filter in Swift by habitId
        let completionDescriptor = FetchDescriptor<CompletionRecord>(
          predicate: #Predicate { record in
            record.userId == userId
          }
        )
        let allUserRecords = try modelContext.fetch(completionDescriptor)
        
        // Filter in Swift for UUID comparison
        let habitId = habitData.id
        let completionRecords = allUserRecords.filter { record in
          record.habitId == habitId
        }
        
        for record in completionRecords {
          modelContext.delete(record)
        }
        
        // Delete the habit itself
        modelContext.delete(habitData)
      }
      
      try modelContext.save()
      debugLog("✅ CLEANUP: Permanently deleted \(oldDeletedHabits.count) old soft-deleted habits and their completion records")
      
    } catch {
      debugLog("❌ CLEANUP: Failed to clean up old soft-deleted habits: \(error)")
    }
  }
  
  // MARK: - Widget Sync Helper
  
  /// Syncs the current streak to UserDefaults for widget extension
  private func syncStreakToWidget(_ streak: Int) {
    // Use App Group UserDefaults to share data with widget extension
    if let sharedDefaults = UserDefaults(suiteName: "group.com.habitto.widget") {
      // ✅ FIX: Always sync, even if streak is 0, so widget knows the value is valid
      sharedDefaults.set(streak, forKey: "widgetCurrentStreak")
      sharedDefaults.synchronize()
      debugLog("📱 WIDGET_SYNC: Updated widget streak to \(streak) (key now exists in UserDefaults)")
      
      // ✅ CRITICAL FIX: Reload widget timeline immediately to show updated streak
      // This ensures the widget displays the latest streak value right away
      #if canImport(WidgetKit)
      WidgetCenter.shared.reloadAllTimelines()
      debugLog("📱 WIDGET_SYNC: Triggered widget timeline reload")
      #endif
    } else {
      debugLog("⚠️ WIDGET_SYNC: Failed to access App Group UserDefaults")
      print("⚠️ WIDGET_SYNC: App Group 'group.com.habitto.widget' is not accessible - check entitlements")
    }
  }
  
  @MainActor
  private func backfillHistoricalLongestStreak(userId: String, modelContext: ModelContext) async {
    debugLog("🔄 STREAK_BACKFILL: Starting historical longestStreak backfill for user '\(userId.isEmpty ? "guest" : userId)'")
    
    do {
      // ✅ CRITICAL FIX: Use HabitRepository.habits instead of querying SwiftData directly
      // This ensures we only backfill for ACTIVE habits (excluding soft-deleted ones)
      let habits = habitRepository.habits
      
      debugLog("📊 STREAK_BACKFILL: Using \(habits.count) active habits from HabitRepository")
      
      guard !habits.isEmpty else {
        debugLog("ℹ️ STREAK_BACKFILL: No habits found, skipping backfill")
        return
      }
      
      // Fetch all completion records for this user
      var completionDescriptor = FetchDescriptor<CompletionRecord>()
      completionDescriptor.includePendingChanges = true
      let allCompletionRecords = try modelContext.fetch(completionDescriptor)
      let filteredCompletionRecords = allCompletionRecords.filter { record in
        guard record.isCompleted else { return false }
        if userId.isEmpty || userId == "guest" {
          return record.userId.isEmpty || record.userId == "guest" || record.userId == userId
        } else {
          return record.userId == userId
        }
      }
      
      debugLog("📊 STREAK_BACKFILL: Found \(habits.count) habits and \(filteredCompletionRecords.count) completion records")
      
      // Calculate the true longest streak from all completion records in history
      let calendar = Calendar.current
      let calculatedLongestStreak = StreakCalculator.computeLongestStreakFromHistory(
        habits: habits,
        completionRecords: filteredCompletionRecords,
        calendar: calendar
      )
      
      debugLog("📊 STREAK_BACKFILL: Calculated longest streak from history: \(calculatedLongestStreak)")
      
      // Get or create GlobalStreakModel
      let streakDescriptor = FetchDescriptor<GlobalStreakModel>(
        predicate: #Predicate { streak in
          streak.userId == userId
        }
      )
      
      let existingStreaks = try modelContext.fetch(streakDescriptor)
      let streak = existingStreaks.first ?? {
        let newStreak = GlobalStreakModel(userId: userId)
        modelContext.insert(newStreak)
        return newStreak
      }()
      
      let storedLongestBefore = streak.longestStreak
      
      // Update longestStreak if the calculated value is greater
      if calculatedLongestStreak > storedLongestBefore {
        streak.longestStreak = calculatedLongestStreak
        try modelContext.save()
        debugLog("✅ STREAK_BACKFILL: Updated longestStreak from \(storedLongestBefore) to \(calculatedLongestStreak)")
      } else {
        debugLog("ℹ️ STREAK_BACKFILL: Kept longestStreak at \(storedLongestBefore) (calculated: \(calculatedLongestStreak))")
      }
      
    } catch {
      debugLog("❌ STREAK_BACKFILL: Failed to backfill historical longestStreak: \(error.localizedDescription)")
      // Don't throw - backfill failure shouldn't block app launch
    }
  }

  func validateAllStreaks() { }

  func refreshHabits() {
    debugLog("🔄 HomeViewState: Manual refresh requested")
    Task {
      await habitRepository.loadHabits(force: true)

      // Also validate streaks
      if !habits.isEmpty {}
    }
  }

  /// Debug method to check current state
  func debugCurrentState() {
    debugLog("🔍 HomeViewState: === DEBUG STATE ===")
    debugLog("🔍 HomeViewState: Current habits count: \(habits.count)")
    debugLog("🔍 HomeViewState: HabitRepository habits count: \(habitRepository.habits.count)")
    debugLog("🔍 HomeViewState: Current selectedDate: \(selectedDate)")

    for (index, habit) in habits.enumerated() {
      debugLog("🔍 HomeViewState: Habit \(index): \(habit.name) (ID: \(habit.id))")
    }

    debugLog("🔍 HomeViewState: === END DEBUG ===")
  }

  /// Debug method to track habit updates
  func debugHabitUpdate(_ context: String) {
    debugLog("🔄 HomeViewState: \(context)")
    debugLog("  - Current habits count: \(habits.count)")
    debugLog("  - HabitRepository habits count: \(habitRepository.habits.count)")
    debugLog("  - Habits match: \(habits.count == habitRepository.habits.count)")
  }

  /// Test method to create a sample habit
  func createTestHabit() {
    debugLog("🧪 HomeViewState: Creating test habit...")
    let testHabit = Habit(
      name: "Test Habit",
      description: "This is a test habit",
      icon: "🧪",
      color: CodableColor(.blue),
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 time",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil,
      createdAt: Date(),
      reminders: [],
      baseline: 0,
      target: 1,
      completionHistory: [:],
      completionTimestamps: [:],
      difficultyHistory: [:],
      actualUsage: [:])

    Task {
      await createHabit(testHabit)
    }
  }

  /// Simple test method that bypasses validation
  func createSimpleTestHabit() {
    debugLog("🧪 HomeViewState: Creating simple test habit...")
    let testHabit = Habit(
      name: "Simple Test",
      description: "Simple test habit",
      icon: "🧪",
      color: CodableColor(.blue),
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 time",
      reminder: "No reminder",
      startDate: Date(),
      endDate: nil,
      createdAt: Date(),
      reminders: [],
      baseline: 0,
      target: 1,
      completionHistory: [:],
      completionTimestamps: [:],
      difficultyHistory: [:],
      actualUsage: [:])

    debugLog("🧪 HomeViewState: Created habit: \(testHabit.name) (ID: \(testHabit.id))")

    // Try to save directly to UserDefaults as a test
    Task {
      // Test habit creation - JSON encoding is working correctly
      // This was previously commented out due to a temporary issue
      debugLog("🧪 HomeViewState: Saved to UserDefaults directly")

      // Try to reload
      await habitRepository.loadHabits(force: true)
      debugLog("🧪 HomeViewState: Reloaded habits, count: \(habitRepository.habits.count)")
    }
  }

  /// Force update selectedDate to today
  func forceUpdateSelectedDateToToday() {
    debugLog("🔄 HomeViewState: Force updating selectedDate to today")
    let today = LegacyDateUtils.today()
    debugLog("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
    debugLog("🔄 HomeViewState: Target today: \(today)")
    selectedDate = today
    debugLog("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
  }

  /// Force refresh selectedDate with cache clearing
  func forceRefreshSelectedDate() {
    debugLog("🔄 HomeViewState: Force refreshing selectedDate")
    let today = LegacyDateUtils.forceRefreshToday()
    debugLog("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
    debugLog("🔄 HomeViewState: Refreshed today: \(today)")
    selectedDate = today
    debugLog("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
  }

  // MARK: Private

  /// Performance optimization: Cache expensive operations
  private var lastHabitsUpdate = Date()

  /// Store cancellables for proper memory management
  private var cancellables = Set<AnyCancellable>()
}

// MARK: - HomeView

@MainActor
struct HomeView: View {
  @StateObject private var state = HomeViewState()
  @EnvironmentObject var tutorialManager: TutorialManager
  @EnvironmentObject var authManager: AuthenticationManager
  @EnvironmentObject var themeManager: ThemeManager
  
  // ✅ FIX: Use @Environment to properly observe @Observable changes
  @Environment(XPManager.self) private var xpManager
  

  // MARK: - Tab Content Views
  
  private var homeTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.headerBackground
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for home tab
        HeaderView(
          onCreateHabit: {
            state.handleCreateHabitRequest()
          },
          onStreakTap: {
            state.showingOverviewView = true
          },
          onNotificationTap: {
            state.showingNotificationView = true
          },
          showProfile: false,
          currentStreak: state.currentStreak)
        
        HomeTabView(
        selectedDate: $state.selectedDate,
        selectedStatsTab: $state.selectedStatsTab,
        habits: state.habits,
        isLoadingHabits: state.isLoadingHabits,
        onToggleHabit: { (habit: Habit, date: Date) in
          Task {
            await state.toggleHabitCompletion(habit, for: date)
          }
        },
        onUpdateHabit: { updatedHabit in
          debugLog("🔄 HomeView: onUpdateHabit received - \(updatedHabit.name)")
          Task {
            await state.updateHabit(updatedHabit)
          }
          debugLog("🔄 HomeView: Habit array updated and saved")
        },
        onSetProgress: { habit, date, progress in
          debugLog("🔄 HomeView: onSetProgress received - \(habit.name), progress: \(progress)")
          debugLog("🔄 HomeView: Current state.habits count: \(state.habits.count)")

          Task {
            // Find the habit by ID from the current state to ensure we have the latest Core
            // Data-synced version
            if let syncedHabit = state.habits.first(where: { $0.id == habit.id }) {
              debugLog("🔄 HomeView: Found synced habit with ID: \(syncedHabit.id)")
              debugLog(
                "🔄 HomeView: Current progress before update: \(syncedHabit.getProgress(for: date))")
              await state.setHabitProgress(syncedHabit, for: date, progress: progress)
              debugLog("🔄 HomeView: Progress saved to Core Data using synced habit")
            } else {
              debugLog(
                "❌ HomeView: No synced habit found for ID: \(habit.id), falling back to original habit")
              debugLog("❌ HomeView: Available habit IDs: \(state.habits.map { $0.id })")
              await state.setHabitProgress(habit, for: date, progress: progress)
              debugLog("🔄 HomeView: Progress saved to Core Data using original habit")
            }
          }
        },
        onDeleteHabit: { habit in
          print("🗑️ DELETE_FLOW: HomeView - onDeleteHabit callback received for habit: \(habit.name) (ID: \(habit.id))")
          print("🗑️ DELETE_FLOW: HomeView - Setting state.habitToDelete")
          state.habitToDelete = habit
          print("🗑️ DELETE_FLOW: HomeView - state.habitToDelete set to: \(habit.name) (ID: \(habit.id))")
          print("🗑️ DELETE_FLOW: HomeView - Setting showingDeleteConfirmation = true")
          state.showingDeleteConfirmation = true
          print("🗑️ DELETE_FLOW: HomeView - showingDeleteConfirmation set, confirmationDialog should appear")
        },
        onCompletionDismiss: {
          // ✅ FIX: Streak update is handled by onStreakRecalculationNeeded callback with proper flag
          // Don't call updateStreak() here as it bypasses the isUserInitiated flag system
          debugLog("🔄 HomeView: Habit completion bottom sheet dismissed")
          // Note: Streak will be updated via onStreakRecalculationNeeded callback which sets isUserInitiated=true
        },
        onStreakRecalculationNeeded: { isUserInitiated in
          // ✅ CRITICAL FIX: Recalculate streak immediately when habits are completed/uncompleted
          // This ensures streak updates reactively, just like XP does
          debugLog("🔄 HomeView: Streak recalculation requested from HomeTabView, isUserInitiated: \(isUserInitiated)")
          state.requestStreakRecalculation(reason: "HomeTabView callback", isUserInitiated: isUserInitiated)
          debugLog("✅ HomeView: Streak recalculation enqueued with isUserInitiated=\(isUserInitiated)")
        },
        onWaitForPersistence: {
          // ✅ RACE CONDITION FIX: Allow HomeTabView to wait for persistence to complete
          // This ensures streak calculation doesn't start until data is fully saved
          await state.waitForPersistenceCompletion()
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
  
  private var progressTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.headerBackground
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for progress tab
        HeaderView(
          onCreateHabit: {
            state.handleCreateHabitRequest()
          },
          onStreakTap: {
            state.showingOverviewView = true
          },
          onNotificationTap: {
            state.showingNotificationView = true
          },
          showProfile: false,
          currentStreak: state.currentStreak)
        
        ProgressTabView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
  
  private var habitsTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.headerBackground
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for habits tab
        HeaderView(
          onCreateHabit: {
            state.handleCreateHabitRequest()
          },
          onStreakTap: {
            state.showingOverviewView = true
          },
          onNotificationTap: {
            state.showingNotificationView = true
          },
          showProfile: false,
          currentStreak: state.currentStreak)
        
        HabitsTabView(
        state: state,
        onDeleteHabit: { habit in
          print("🗑️ DELETE_FLOW: HomeView (HabitsTabView) - onDeleteHabit callback received for habit: \(habit.name) (ID: \(habit.id))")
          print("🗑️ DELETE_FLOW: HomeView (HabitsTabView) - Setting state.habitToDelete")
          state.habitToDelete = habit
          print("🗑️ DELETE_FLOW: HomeView (HabitsTabView) - state.habitToDelete set to: \(habit.name) (ID: \(habit.id))")
          print("🗑️ DELETE_FLOW: HomeView (HabitsTabView) - Setting showingDeleteConfirmation = true")
          state.showingDeleteConfirmation = true
          print("🗑️ DELETE_FLOW: HomeView (HabitsTabView) - showingDeleteConfirmation set, confirmationDialog should appear")
        },
        onEditHabit: { habit in
          debugLog("🔄 HomeView: onEditHabit received for habit: \(habit.name)")
          debugLog("🔄 HomeView: Setting habitToEditSession to open HabitEditView")
          state.habitToEditSession = HabitEditSession(habit: habit)
        },
        onCreateHabit: {
          state.handleCreateHabitRequest()
        },
        onUpdateHabit: { updatedHabit in
          debugLog("🔄 HomeView: onUpdateHabit received for habit: \(updatedHabit.name)")
          Task {
            await state.updateHabit(updatedHabit)
          }
          debugLog("🔄 HomeView: Habit updated and saved successfully")
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
  
  private var moreTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.headerBackground
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show profile for more tab
        HeaderView(
          onCreateHabit: {
            state.handleCreateHabitRequest()
          },
          onStreakTap: {
            state.showingOverviewView = true
          },
          onNotificationTap: {
            state.showingNotificationView = true
          },
          showProfile: true,
          currentStreak: state.currentStreak)
        
        MoreTabView(state: state)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  var body: some View {
    TabView(selection: $state.selectedTab) {
      // Home Tab
      homeTabContent
        .tabItem {
          Label("Home", image: "Icon-home-filled")
        }
        .tag(Tab.home)
      
      // Progress Tab
      progressTabContent
        .tabItem {
          Label("Progress", image: "Icon-chart-filled")
        }
        .tag(Tab.progress)
      
      // Habits Tab
      habitsTabContent
        .tabItem {
          Label("Habits", image: "Icon-book-filled")
        }
        .tag(Tab.habits)
      
      // More Tab
      moreTabContent
        .tabItem {
          Label("More", image: "Icon-more-filled")
        }
        .tag(Tab.more)
    }
    .customTabBarAppearance()
    .onChange(of: state.selectedTab) { oldValue, newValue in
      // Add haptic feedback when tab is selected
      UISelectionFeedbackGenerator().selectionChanged()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProgressTabWithHabit"))) { notification in
      // Switch to Progress tab
      state.selectedTab = .progress
      
      // Forward the notification to ProgressTabView to select the habit
      if let habitId = notification.userInfo?["habitId"] as? UUID {
        // Delay slightly to ensure the Progress tab is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          NotificationCenter.default.post(
            name: NSNotification.Name("SelectHabitInProgressTab"),
            object: nil,
            userInfo: ["habitId": habitId]
          )
        }
      }
    }
    .onAppear {
      debugLog("🚀 HomeView: onAppear called!")
      debugLog("🚀 HomeView: This is a test log - if you see this, logging is working!")
      
      // ✅ Ensure auth listener is set up (safety check)
      authManager.ensureAuthListenerSetup()
      
      loadHabitsOptimized()

      // Add additional debugging
      debugLog("🔍 HomeView: Current habits count: \(state.habits.count)")
      debugLog("🔍 HomeView: HabitRepository habits count: \(HabitRepository.shared.habits.count)")

      // Debug Core Data state
      HabitRepository.shared.debugHabitsState()
      
      // ✅ FIX: Recalculate streak from CompletionRecords when app launches
      state.requestStreakRecalculation(reason: "HomeView onAppear")

      // ✅ FIX: Also refresh streak UI
      state.updateStreak()

      // Debug current state
      state.debugCurrentState()
    }
    .onReceive(NotificationCenter.default
      .publisher(for: UIApplication.willResignActiveNotification))
    { _ in
      debugLog("🏠 HomeView: App going to background, backing up habits...")
      state.backupHabits()
    }
    .onReceive(NotificationCenter.default
      .publisher(for: UIApplication.didBecomeActiveNotification))
    { _ in
      debugLog("🏠 HomeView: App became active, updating streaks...")
      state.requestStreakRecalculation(reason: "App became active", delay: 1.0)
    }
    .sheet(isPresented: $state.showingCreateHabit) {
      let _ = print("⌨️ HOME: Sheet closure executing at \(Date())")
      CreateHabitFlowView(onSave: { habit in
        #if DEBUG
        debugLog("🎯 [2/8] HomeView.onSave: received habit from CreateHabitFlowView")
        debugLog("  → Habit: '\(habit.name)', ID: \(habit.id)")
        debugLog("  → Current habits count: \(state.habits.count)")
        #endif

        // ✅ FIX: Wait for habit creation to complete before dismissing sheet
        Task { @MainActor in
          await state.createHabit(habit)
          #if DEBUG
          debugLog("  → Habit creation completed, dismissing sheet")
          #endif
          state.showingCreateHabit = false
          
          // Show success toast after sheet dismisses
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            state.createdHabitName = habit.name
          }
        }
      })
    }
    .sheet(isPresented: $state.showingPaywall) {
      SubscriptionView()
    }
    .fullScreenCover(item: $state.habitToEditSession) { session in
      HabitEditView(habit: session.habit, onSave: { updatedHabit in
        debugLog("🔄 HomeView: HabitEditView save called for habit: \(updatedHabit.name)")
        Task {
          await state.updateHabit(updatedHabit)
          await MainActor.run {
            state.habitToEditSession = nil
          }
        }
        debugLog("🔄 HomeView: Habit updated and saved successfully")
      })
    }
    .alert("Delete Habit", isPresented: $state.showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        print("🗑️ DELETE_FLOW: HomeView - Delete cancelled in alert")
        debugLog("❌ Delete cancelled")
        state.habitToDelete = nil
      }
      Button("Delete", role: .destructive) {
        print("🗑️ DELETE_FLOW: HomeView - Delete button tapped in alert")
        if let habit = state.habitToDelete {
          print("🗑️ DELETE_FLOW: HomeView - Calling state.deleteHabit() for habit: \(habit.name) (ID: \(habit.id))")
          debugLog("🗑️ Deleting habit: \(habit.name)")
          Task {
            await state.deleteHabit(habit)
          }
          print("🗑️ DELETE_FLOW: HomeView - state.deleteHabit() Task started")
          debugLog("🗑️ Delete completed")
        } else {
          print("🗑️ DELETE_FLOW: HomeView - ERROR: No habit to delete (state.habitToDelete is nil)")
          debugLog("❌ No habit to delete")
        }
      }
    } message: {
      if let habit = state.habitToDelete {
        Text("Are you sure you want to delete \"\(habit.name)\"? This action cannot be undone.")
      } else {
        Text("Are you sure you want to delete this habit? This action cannot be undone.")
      }
    }

    .sheet(isPresented: $state.showingOverviewView) {
      OverviewView()
        .environmentObject(state)
    }
    .sheet(isPresented: $state.showingNotificationView) {
      NotificationView()
    }
    .sheet(isPresented: Binding(
      get: { HabitRepository.shared.shouldShowMigrationView },
      set: { HabitRepository.shared.shouldShowMigrationView = $0 }
    )) {
      GuestDataMigrationView()
    }
    .sheet(isPresented: $tutorialManager.shouldShowTutorial) {
      TutorialBottomSheet(tutorialManager: tutorialManager)
    }
    .overlay(alignment: .bottom) {
      // ✅ UNDO TOAST: Show toast when habit is deleted
      if let deletedHabit = state.deletedHabitForUndo {
        UndoToastView(
          habitName: deletedHabit.name,
          onUndo: {
            Task {
              await state.restoreHabit(deletedHabit)
            }
          },
          onDismiss: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              state.deletedHabitForUndo = nil
            }
          }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // Above tab bar
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .overlay(alignment: .bottom) {
      // ✅ SUCCESS TOAST: Show toast when habit is created
      if let habitName = state.createdHabitName {
        SuccessToastView(habitName: habitName) {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            state.createdHabitName = nil
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // Above tab bar
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.createdHabitName)
    .onChange(of: state.habits) { oldHabits, newHabits in
      // ✅ CRITICAL FIX: XP should ONLY come from DailyAwardService (source of truth)
      // DO NOT call publishXP() here - it overwrites the database value with calculated value
      // When habits change, DailyAwardService will award XP via awardXP() if needed
      // XPManager observes DailyAwardService.xpState and updates automatically
      Task { @MainActor in
        debugLog("✅ REACTIVE_XP: Habits changed - XP will update via DailyAwardService (not recalculating)")
        
        // ✅ CRITICAL FIX: Only recalculate streak when habits change
        // But add a small delay to ensure SwiftData has finished saving CompletionRecords
        debugLog("🔄 REACTIVE_STREAK: Habits changed, scheduling streak recalculation...")
        
        // Wait 100ms to allow SwiftData saves to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        debugLog("🔄 REACTIVE_STREAK: Now recalculating streak after SwiftData sync...")
        state.requestStreakRecalculation(reason: "Habits publisher change")
      }
    }
  }

  // MARK: - Lifecycle

  private func loadHabits() {
    debugLog("🏠 HomeView: Loading habits from HabitRepository...")
    // Use HabitRepository instead of direct Habit.loadHabits()
    // The HabitRepository already loads habits in its init()
    debugLog("🏠 HomeView: Habits loaded from HabitRepository - total: \(state.habits.count)")

    // Validate and correct streaks to ensure accuracy
    debugLog("🏠 HomeView: Validating streaks...")
    state.validateAllStreaks()
    debugLog("🏠 HomeView: Streak validation completed")
    
    // ✅ FIX: Refresh global streak from database after habits load
    state.updateStreak()
  }

  private func loadHabitsOptimized() {
    debugLog("🏠 HomeView: Loading habits from HabitRepository...")
    // Refresh from Core Data to ensure we have the latest state (let repository debounce)
    Task {
      await HabitRepository.shared.loadHabits()
      debugLog("🏠 HomeView: Habits loaded from HabitRepository - total: \(state.habits.count)")
    }

    // Only validate streaks if we have habits and haven't validated recently
    if !state.habits.isEmpty {
      debugLog("🏠 HomeView: Validating streaks...")
      // Use Task to prevent UI blocking
      Task {
        let habits = state.habits
        for i in 0 ..< habits.count {
          if !habits[i].validateStreak() {
            debugLog(
              "🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
            // ✅ PHASE 4: Streaks are now computed-only, no need to correct them
          }
        }

        // Update on main thread
        await MainActor.run {
          state.updateHabits(habits)
          debugLog("🏠 HomeView: Streak validation completed")
          
          // ✅ FIX: Refresh global streak from database after validation
          state.updateStreak()
        }
      }
    }
  }
}

#Preview {
  let mockState = HomeViewState()
  let mockTutorialManager = TutorialManager()

  HomeView()
    .environmentObject(mockState)
    .environmentObject(AuthenticationManager.shared)
    .environmentObject(mockTutorialManager)
    .environmentObject(VacationManager.shared)
    .onAppear {
      // Initialize with some mock data for preview
      mockState.habits = []
    }
}
