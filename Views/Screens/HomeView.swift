import Combine
import FirebaseAuth
import SwiftUI
import SwiftData
import UIKit

// Import for streak calculations
import Foundation

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
    self.updateStreak()

    // Subscribe to HabitRepository changes
    habitRepository.$habits
      .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
      .sink { [weak self] habits in
        self?.habits = habits
        self?.isLoadingHabits = false
        // ✅ CRASH FIX: Update streak when habits change
        self?.updateStreak()
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
  @Published var habitToEdit: Habit? = nil
  @Published var showingDeleteConfirmation = false
  @Published var habitToDelete: Habit?
  @Published var showingOverviewView = false
  @Published var showingNotificationView = false

  /// Core Data adapter
  let habitRepository = HabitRepository.shared

  /// ✅ CRASH FIX: Cache streak as @Published instead of computed property
  /// Computed properties that access @Published cause infinite loops!
  @Published var currentStreak: Int = 0
  private var lastStreakUpdateTime: Date?
  private let streakUpdateInterval: TimeInterval = 0.5
  
  /// Calculate and update streak (call this when habits change)
  func updateStreak() {
    // ✅ FIX: Read streak from GlobalStreakModel in SwiftData instead of old calculation
    Task { @MainActor in
      do {
        // ✅ FIX: Add small delay to ensure SwiftData context sees the newly saved streak
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
        
        let modelContext = SwiftDataContainer.shared.modelContext
        
        // ✅ CRITICAL FIX: Use same userId logic as CompletionRecords (empty string for guest/anonymous)
        let currentUser = AuthenticationManager.shared.currentUser
        let userId: String
        if let firebaseUser = currentUser as? User, firebaseUser.isAnonymous {
          userId = "" // Anonymous = guest, use "" as userId (matches CompletionRecord storage)
        } else if let uid = currentUser?.uid {
          userId = uid // Authenticated non-anonymous user
        } else {
          userId = "" // No user = guest
        }
        
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
          currentStreak = loadedStreak
          
          // ✅ FIX: Also broadcast via notification for consistency
          NotificationCenter.default.post(
            name: NSNotification.Name("StreakUpdated"),
            object: nil,
            userInfo: ["newStreak": loadedStreak]
          )
        } else {
          currentStreak = 0
        }
      } catch {
        currentStreak = 0
      }
    }
  }

  func updateHabits(_ newHabits: [Habit]) {
    // This method is used for bulk updates like streak validation
    // For individual habit operations, use createHabit, updateHabit, or deleteHabit
    habitRepository.saveHabits(newHabits)
    lastHabitsUpdate = Date()
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func toggleHabitCompletion(_ habit: Habit, for date: Date? = nil) async {
    let targetDate = date ?? Calendar.current.startOfDay(for: Date())
    do {
      try await habitRepository.toggleHabitCompletion(habit, for: targetDate)
      debugLog("✅ GUARANTEED: Completion toggled and persisted")
    } catch {
      debugLog("❌ Failed to toggle completion: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func deleteHabit(_ habit: Habit) async {
    // Immediately remove from local state for instant UI update
    DispatchQueue.main.async {
      var updatedHabits = self.habits
      updatedHabits.removeAll { $0.id == habit.id }
      self.habits = updatedHabits
    }

    // Then delete from storage
    do {
      try await habitRepository.deleteHabit(habit)
      debugLog("✅ GUARANTEED: Habit deleted and persisted")
    } catch {
      debugLog("❌ Failed to delete habit: \(error.localizedDescription)")
    }
    habitToDelete = nil
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func updateHabit(_ updatedHabit: Habit) async {
    do {
      try await habitRepository.updateHabit(updatedHabit)
      debugLog("✅ GUARANTEED: Habit updated and persisted")
    } catch {
      debugLog("❌ Failed to update habit: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func setHabitProgress(_ habit: Habit, for date: Date, progress: Int) async {
    let startTime = Date()
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

  func updateAllStreaks() {
    let now = Date()
    if let lastUpdate = lastStreakUpdateTime,
       now.timeIntervalSince(lastUpdate) < streakUpdateInterval
    {
      debugLog(
        "ℹ️ STREAK_UPDATE: Skipping - recently updated \(String(format: "%.1f", now.timeIntervalSince(lastUpdate)))s ago")
      return
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
        // ✅ CRITICAL FIX: Use same userId logic as CompletionRecords (empty string for guest/anonymous)
        let currentUser = AuthenticationManager.shared.currentUser
        let userId: String
        if let firebaseUser = currentUser as? User, firebaseUser.isAnonymous {
          userId = "" // Anonymous = guest, use "" as userId (matches CompletionRecord storage)
        } else if let uid = currentUser?.uid {
          userId = uid // Authenticated non-anonymous user
        } else {
          userId = "" // No user = guest
        }
        
        let modelContext = SwiftDataContainer.shared.modelContext
        
        debugLog("🔄 STREAK_RECALC: Starting streak recalculation from CompletionRecords for user '\(userId.isEmpty ? "guest" : userId)'")
        
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
        
        // Fetch all habits for this user
        let habitsDescriptor = FetchDescriptor<HabitData>(
          predicate: #Predicate { habit in
            habit.userId == userId
          }
        )
        let habitDataList = try modelContext.fetch(habitsDescriptor)
        let habits = habitDataList.map { $0.toHabit() }
        
        guard !habits.isEmpty else {
          debugLog("ℹ️ STREAK_RECALC: No habits found - resetting streak to 0")
          streak.currentStreak = 0
          streak.lastCompleteDate = nil
          try modelContext.save()
          updateStreak()
          return
        }
        
            // Calculate streak from CompletionRecords
            let today = DateUtils.startOfDay(for: Date())
            let calendar = Calendar.current
            
            // ✅ Start from yesterday, but check if today is complete first
            // Streak counts consecutive complete days up to AND INCLUDING today if today is complete
            var checkDate = today
            var currentStreakCount = 0
            var lastCompleteDate: Date? = nil
            
            // Look back up to 365 days or earliest habit start (whichever is later)
            let defaultStartDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
            let earliestHabitStart = habits
              .map { calendar.startOfDay(for: $0.startDate) }
              .min() ?? defaultStartDate
            let startDate = max(defaultStartDate, earliestHabitStart)
            
            debugLog("🔄 STREAK_RECALC: Starting from TODAY (\(Habit.dateKey(for: today))) and counting backwards")
        
        let completionDescriptor = FetchDescriptor<CompletionRecord>()
        let allCompletionRecords = try modelContext.fetch(completionDescriptor)
        let filteredCompletionRecords = allCompletionRecords.filter { record in
          guard record.isCompleted else { return false }
          if userId.isEmpty || userId == "guest" {
            return record.userId.isEmpty || record.userId == "guest" || record.userId == userId
          } else {
            return record.userId == userId
          }
        }
        let recordsByDate = Dictionary(grouping: filteredCompletionRecords, by: { $0.dateKey })

        while checkDate >= startDate {
          let dateKey = Habit.dateKey(for: checkDate)
          
          // Get scheduled habits for this date
          // ✅ CRITICAL FIX: Use EXACT same scheduling logic as XP calculation
          let scheduledHabits = habits.filter { habit in
            HabitSchedulingLogic.shouldShowHabitOnDate(habit, date: checkDate, habits: habits)
          }
          
          guard !scheduledHabits.isEmpty else {
            // No habits scheduled for this date - this might mean app wasn't used yet
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            continue
          }
          
          let completedRecords = recordsByDate[dateKey] ?? []
          
          // Check if ALL habits have a completed CompletionRecord (same as XP logic)
          let allComplete = scheduledHabits.allSatisfy { habit in
            completedRecords.contains(where: { $0.habitId == habit.id })
          }
          
          let isToday = calendar.isDate(checkDate, inSameDayAs: today)
          
          if allComplete {
            currentStreakCount += 1
            lastCompleteDate = lastCompleteDate ?? checkDate
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            continue
          }
          
          // CRITICAL: When today is incomplete, continue from yesterday (don't break streak)
          if isToday {
            debugLog("ℹ️ STREAK_RECALC: Today (\(dateKey)) not complete - continuing with yesterday")
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            continue
          }
          
          debugLog("ℹ️ STREAK_RECALC: Stopped at \(dateKey) - first incomplete day")
          break
        }
        
            // Update streak model
            let oldStreak = streak.currentStreak
            streak.currentStreak = currentStreakCount
            streak.longestStreak = max(streak.longestStreak, currentStreakCount)
            streak.lastCompleteDate = lastCompleteDate
            streak.lastUpdated = Date()
            
            try modelContext.save()
            
            debugLog("")
            debugLog(String(repeating: "=", count: 60))
            debugLog("✅ STREAK_RECALC: Recalculation COMPLETE")
            debugLog("   Old streak: \(oldStreak) day(s)")
            debugLog("   New streak: \(currentStreakCount) day(s)")
            debugLog("   Last complete date: \(lastCompleteDate.map { Habit.dateKey(for: $0) } ?? "none")")
            debugLog("   Longest streak: \(streak.longestStreak) day(s)")
            debugLog(String(repeating: "=", count: 60))
            debugLog("")
            
            // Reload the UI streak
            updateStreak()
        
      } catch {
        debugLog("❌ STREAK_RECALC: Failed to recalculate streak: \(error)")
      }
    }
  }

  func validateAllStreaks() {
    debugLog("🔄 HomeView: Validating all streaks...")
    for i in 0 ..< habits.count {
      if !habits[i].validateStreak() {
        debugLog(
          "🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
        // ✅ PHASE 4: Streaks are now computed-only, no need to correct them
      }
    }
    // Save the corrected habits
    updateHabits(habits)
    debugLog("🔄 HomeView: All streaks validated")
  }

  func refreshHabits() {
    debugLog("🔄 HomeViewState: Manual refresh requested")
    Task {
      await habitRepository.loadHabits(force: true)

      // Also validate streaks
      if !habits.isEmpty {
        validateAllStreaks()
      }
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
      Color.primary
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for home tab
        HeaderView(
          onCreateHabit: {
            state.showingCreateHabit = true
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
          state.habitToDelete = habit
          state.showingDeleteConfirmation = true
        },
        onCompletionDismiss: {
          // ✅ FIX: Update streak UI after completion flow finishes
          debugLog("🔄 HomeView: Habit completion bottom sheet dismissed")
          state.updateStreak()
        },
        onStreakRecalculationNeeded: {
          // ✅ CRITICAL FIX: Recalculate streak immediately when habits are completed/uncompleted
          // This ensures streak updates reactively, just like XP does
          debugLog("🔄 HomeView: Streak recalculation requested from HomeTabView")
          state.updateAllStreaks()
          debugLog("✅ HomeView: Streak recalculation completed")
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(edges: .bottom)
    }
  }
  
  private var progressTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.primary
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for progress tab
        HeaderView(
          onCreateHabit: {
            state.showingCreateHabit = true
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
      .ignoresSafeArea(edges: .bottom)
    }
  }
  
  private var habitsTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.primary
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show streak for habits tab
        HeaderView(
          onCreateHabit: {
            state.showingCreateHabit = true
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
          state.habitToDelete = habit
          state.showingDeleteConfirmation = true
        },
        onEditHabit: { habit in
          debugLog("🔄 HomeView: onEditHabit received for habit: \(habit.name)")
          debugLog("🔄 HomeView: Setting habitToEdit to open HabitEditView")
          state.habitToEdit = habit
        },
        onCreateHabit: {
          state.showingCreateHabit = true
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
      .ignoresSafeArea(edges: .bottom)
    }
  }
  
  private var moreTabContent: some View {
    ZStack {
      // Primary color background behind white sheet
      Color.primary
        .ignoresSafeArea(.all)
      
      VStack(spacing: 0) {
        // Header - show profile for more tab
        HeaderView(
          onCreateHabit: {
            state.showingCreateHabit = true
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
      .ignoresSafeArea(edges: .bottom)
    }
  }

  var body: some View {
    return ZStack(alignment: .top) {
      // Dynamic theme background fills entire screen
      Color.primary
        .ignoresSafeArea(.all)
      
      // Vacation mode banner overlay
      if VacationManager.shared.isActive {
        VStack {
          HStack(spacing: 6) {
            Image("Icon-Vacation_Filled")
              .resizable()
              .frame(width: 16, height: 16)
              .foregroundColor(.blue)
            Text("Vacation Mode")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(.blue)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.blue.opacity(0.1))
          .frame(maxWidth: .infinity)
          Spacer()
        }
        .ignoresSafeArea(.all)
        .zIndex(1)
      }
      
      // Native iOS TabView
      // Tab bar automatically overlays on top of content
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
      .accentColor(.primary)
      .onChange(of: state.selectedTab) { oldValue, newValue in
        // Haptic feedback when tab changes
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
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
      state.updateAllStreaks()
      
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
      // Debounce to prevent excessive updates
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        state.updateAllStreaks()
      }
    }
    .sheet(isPresented: $state.showingCreateHabit) {
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
        }
      })
    }
    .fullScreenCover(item: $state.habitToEdit) { habit in
      HabitEditView(habit: habit, onSave: { updatedHabit in
        debugLog("🔄 HomeView: HabitEditView save called for habit: \(updatedHabit.name)")
        Task {
          await state.updateHabit(updatedHabit)
          await MainActor.run {
            state.habitToEdit = nil
          }
        }
        debugLog("🔄 HomeView: Habit updated and saved successfully")
      })
    }
    .confirmationDialog(
      "Delete Habit",
      isPresented: $state.showingDeleteConfirmation,
      titleVisibility: .visible)
    {
      Button("Cancel", role: .cancel) {
        debugLog("❌ Delete cancelled")
        state.habitToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let habit = state.habitToDelete {
          debugLog("🗑️ Deleting habit: \(habit.name)")
          Task {
            await state.deleteHabit(habit)
          }
          debugLog("🗑️ Delete completed")
        } else {
          debugLog("❌ No habit to delete")
        }
      }
    } message: {
      Text("Are you sure you want to delete this habit? This action cannot be undone.")
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
    .onChange(of: state.habits) { oldHabits, newHabits in
      // ✅ FIX: Reactively recalculate XP AND STREAK whenever habits change
      // This ensures both XP and streak update immediately when habits are toggled
      Task { @MainActor in
        debugLog("✅ REACTIVE_XP: Habits changed, recalculating XP...")
        
        // Count completed days from the current habit state
        let completedDaysCount = countCompletedDays(habits: newHabits)
        xpManager.publishXP(completedDaysCount: completedDaysCount)
        
        debugLog("✅ REACTIVE_XP: XP updated to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
        
        // ✅ CRITICAL FIX: Also recalculate streak when habits change!
        // But add a small delay to ensure SwiftData has finished saving CompletionRecords
        debugLog("🔄 REACTIVE_STREAK: Habits changed, scheduling streak recalculation...")
        
        // Wait 100ms to allow SwiftData saves to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        debugLog("🔄 REACTIVE_STREAK: Now recalculating streak after SwiftData sync...")
        state.updateAllStreaks()
      }
    }
  }

  // MARK: - XP Calculation Helpers
  
  /// Count how many days have all habits completed
  /// This is used for reactive XP recalculation when habits change
  @MainActor
  private func countCompletedDays(habits: [Habit]) -> Int {
    guard AuthenticationManager.shared.currentUser?.uid != nil else { return 0 }
    guard !habits.isEmpty else { return 0 }
    
    let calendar = Calendar.current
    let today = LegacyDateUtils.today()
    
    // Find the earliest habit start date
    guard let earliestStartDate = habits.map({ $0.startDate }).min() else { return 0 }
    let startDate = DateUtils.startOfDay(for: earliestStartDate)
    
    var completedCount = 0
    var currentDate = startDate
    
    // Count all days where all habits are completed
    while currentDate <= today {
      let habitsForDate = habits.filter { habit in
        let selected = DateUtils.startOfDay(for: currentDate)
        let start = DateUtils.startOfDay(for: habit.startDate)
        let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
        
        guard selected >= start, selected <= end else { return false }
        return shouldShowHabitOnDate(habit, date: currentDate)
      }
      
      // Check if all habits for this date are completed
      let allCompleted = !habitsForDate.isEmpty && habitsForDate.allSatisfy { $0.isCompleted(for: currentDate) }
      
      if allCompleted {
        completedCount += 1
      }
      
      guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
      currentDate = nextDate
    }
    
    return completedCount
  }
  
  /// Check if a habit should be shown on a specific date based on its schedule
  private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
    // Use StreakDataCalculator for consistent schedule checking
    return StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
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
