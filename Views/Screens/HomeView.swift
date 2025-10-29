import Combine
import SwiftUI
import SwiftData

// Import for streak calculations
import Foundation

// MARK: - Tab

enum Tab {
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
    print("🚀 HomeViewState: Initializing...")
    let today = LegacyDateUtils.today()
    self.selectedDate = today
    print("🚀 HomeViewState: Initial selectedDate: \(selectedDate)")

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
  
  /// Calculate and update streak (call this when habits change)
  func updateStreak() {
    // ✅ FIX: Read streak from GlobalStreakModel in SwiftData instead of old calculation
    Task { @MainActor in
      do {
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = AuthenticationManager.shared.currentUser?.uid ?? "debug_user_id"
        
        let descriptor = FetchDescriptor<GlobalStreakModel>(
          predicate: #Predicate { streak in
            streak.userId == userId
          }
        )
        
        if let streak = try modelContext.fetch(descriptor).first {
          currentStreak = streak.currentStreak
          print("✅ STREAK_UI_UPDATE: Loaded streak from GlobalStreakModel - currentStreak: \(currentStreak), longestStreak: \(streak.longestStreak)")
        } else {
          currentStreak = 0
          print("ℹ️ STREAK_UI_UPDATE: No GlobalStreakModel found, using streak = 0")
        }
      } catch {
        print("❌ STREAK_UI_UPDATE: Failed to load GlobalStreakModel: \(error)")
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
      print("✅ GUARANTEED: Completion toggled and persisted")
    } catch {
      print("❌ Failed to toggle completion: \(error.localizedDescription)")
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
      print("✅ GUARANTEED: Habit deleted and persisted")
    } catch {
      print("❌ Failed to delete habit: \(error.localizedDescription)")
    }
    habitToDelete = nil
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func updateHabit(_ updatedHabit: Habit) async {
    do {
      try await habitRepository.updateHabit(updatedHabit)
      print("✅ GUARANTEED: Habit updated and persisted")
    } catch {
      print("❌ Failed to update habit: \(error.localizedDescription)")
    }
  }

  /// ✅ CRITICAL FIX: Made async to await repository save completion
  func setHabitProgress(_ habit: Habit, for date: Date, progress: Int) async {
    let startTime = Date()
    print("═══════════════════════════════════════════════════════")
    print("🔄 HomeViewState: setHabitProgress called for \(habit.name), progress: \(progress)")
    print("⏱️ AWAIT_START: setProgress() at \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
    do {
      try await habitRepository.setProgress(for: habit, date: date, progress: progress)
      let endTime = Date()
      let duration = endTime.timeIntervalSince(startTime)
      print("⏱️ AWAIT_END: setProgress() at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
      print("✅ GUARANTEED: Progress saved and persisted in \(String(format: "%.3f", duration))s")
      print("═══════════════════════════════════════════════════════")
    } catch {
      let endTime = Date()
      let duration = endTime.timeIntervalSince(startTime)
      print("⏱️ AWAIT_END: setProgress() at \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .medium))")
      print("❌ Failed to set progress: \(error.localizedDescription) (took \(String(format: "%.3f", duration))s)")
      print("═══════════════════════════════════════════════════════")
    }
  }

  func createHabit(_ habit: Habit) async {
    // Log habit creation start for crash debugging
    CrashlyticsService.shared.logHabitCreationStart(habitName: habit.name)
    CrashlyticsService.shared.setValue("\(habits.count)", forKey: "habits_count_before_create")
    
    #if DEBUG
    print("═══════════════════════════════════════════════════════")
    print("🎯 [3/8] HomeViewState.createHabit: creating habit")
    print("  → Habit: '\(habit.name)', ID: \(habit.id)")
    
    // ✅ DIAGNOSTIC: Log habit dates
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    print("🗓️ DIAGNOSTIC: habit.startDate = \(dateFormatter.string(from: habit.startDate))")
    if let end = habit.endDate {
      print("🗓️ DIAGNOSTIC: habit.endDate = \(dateFormatter.string(from: end))")
    } else {
      print("🗓️ DIAGNOSTIC: habit.endDate = nil")
    }
    let today = Date()
    print("🗓️ DIAGNOSTIC: today = \(dateFormatter.string(from: today))")
    print("🗓️ DIAGNOSTIC: startDate is today? \(Calendar.current.isDate(habit.startDate, inSameDayAs: today))")
    
    print("  → Current habits count: \(habits.count)")
    #endif
    
    // Check if vacation mode is active
    if VacationManager.shared.isActive {
      #if DEBUG
      print("🚫 HomeViewState: Cannot create habit during vacation mode")
      print("═══════════════════════════════════════════════════════")
      #endif
      CrashlyticsService.shared.log("Habit creation blocked: vacation mode active")
      return
    }
    
    #if DEBUG
    print("✅ Vacation mode check passed")
    print("🎯 [4/8] HomeViewState.createHabit: calling HabitRepository")
    #endif

    await habitRepository.createHabit(habit)
    
    // Log successful creation
    CrashlyticsService.shared.logHabitCreationComplete(habitID: habit.id.uuidString)
    CrashlyticsService.shared.setValue("\(habits.count)", forKey: "habits_count_after_create")

    #if DEBUG
    print("  → HabitRepository.createHabit completed")
    print("  → New habits count: \(habits.count)")
    print("═══════════════════════════════════════════════════════")
    #endif
  }

  func backupHabits() {
    // Backup is now handled automatically by the HabitStore
    print("✅ HomeView: Habits are automatically backed up by HabitStore")
  }

  func loadHabits() {
    // Core Data adapter automatically loads habits
    print("🔄 HomeView: Habits loaded from Core Data")
  }

  func cleanupDuplicateHabits() {
    print("🔄 HomeView: Cleaning up duplicate habits...")
    habitRepository.cleanupDuplicateHabits()
  }

  func updateAllStreaks() {
    print("🔄 HomeView: Updating all streaks...")

    // Check if all habits are completed for today
    let today = LegacyDateUtils.today()
    let todayHabits = habits.filter { habit in
      // Check if habit should be shown on today's date
      let calendar = Calendar.current
      let weekday = calendar.component(.weekday, from: today)

      // Parse schedule to check if habit is scheduled for today
      if habit.schedule.lowercased().contains("everyday") {
        return true
      } else if habit.schedule.lowercased().contains("weekdays") {
        return weekday >= 2 && weekday <= 6 // Monday to Friday
      } else if habit.schedule.lowercased().contains("weekends") {
        return weekday == 1 || weekday == 7 // Sunday or Saturday
      } else {
        // For specific day schedules, check if today matches
        let dayNames = [
          "sunday",
          "monday",
          "tuesday",
          "wednesday",
          "thursday",
          "friday",
          "saturday"
        ]
        let todayName = dayNames[weekday - 1]
        return habit.schedule.lowercased().contains(todayName)
      }
    }

    // Check if all scheduled habits for today are completed
    let allCompleted = todayHabits.allSatisfy { habit in
      habit.isCompleted(for: today)
    }

    print("🔄 HomeView: Today's habits: \(todayHabits.count), All completed: \(allCompleted)")

    if allCompleted {
      // Only update streaks when ALL habits are completed for today
      print("🎉 HomeView: All habits completed! Streaks will be computed from completion history.")
      // ✅ PHASE 4: Streaks are now computed-only, no need to update them
    } else {
      // Reset streaks if not all habits are completed
      print(
        "🔄 HomeView: Not all habits completed. Streaks will be computed from completion history.")
      // ✅ PHASE 4: Streaks are now computed-only, no need to reset them
    }

    // Save the updated habits
    updateHabits(habits)
    print("🔄 HomeView: All streaks updated")
  }

  func validateAllStreaks() {
    print("🔄 HomeView: Validating all streaks...")
    for i in 0 ..< habits.count {
      if !habits[i].validateStreak() {
        print(
          "🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
        // ✅ PHASE 4: Streaks are now computed-only, no need to correct them
      }
    }
    // Save the corrected habits
    updateHabits(habits)
    print("🔄 HomeView: All streaks validated")
  }

  func refreshHabits() {
    print("🔄 HomeViewState: Manual refresh requested")
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
    print("🔍 HomeViewState: === DEBUG STATE ===")
    print("🔍 HomeViewState: Current habits count: \(habits.count)")
    print("🔍 HomeViewState: HabitRepository habits count: \(habitRepository.habits.count)")
    print("🔍 HomeViewState: Current selectedDate: \(selectedDate)")

    for (index, habit) in habits.enumerated() {
      print("🔍 HomeViewState: Habit \(index): \(habit.name) (ID: \(habit.id))")
    }

    print("🔍 HomeViewState: === END DEBUG ===")
  }

  /// Debug method to track habit updates
  func debugHabitUpdate(_ context: String) {
    print("🔄 HomeViewState: \(context)")
    print("  - Current habits count: \(habits.count)")
    print("  - HabitRepository habits count: \(habitRepository.habits.count)")
    print("  - Habits match: \(habits.count == habitRepository.habits.count)")
  }

  /// Test method to create a sample habit
  func createTestHabit() {
    print("🧪 HomeViewState: Creating test habit...")
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
    print("🧪 HomeViewState: Creating simple test habit...")
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

    print("🧪 HomeViewState: Created habit: \(testHabit.name) (ID: \(testHabit.id))")

    // Try to save directly to UserDefaults as a test
    Task {
      // Test habit creation - JSON encoding is working correctly
      // This was previously commented out due to a temporary issue
      print("🧪 HomeViewState: Saved to UserDefaults directly")

      // Try to reload
      await habitRepository.loadHabits(force: true)
      print("🧪 HomeViewState: Reloaded habits, count: \(habitRepository.habits.count)")
    }
  }

  /// Force update selectedDate to today
  func forceUpdateSelectedDateToToday() {
    print("🔄 HomeViewState: Force updating selectedDate to today")
    let today = LegacyDateUtils.today()
    print("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
    print("🔄 HomeViewState: Target today: \(today)")
    selectedDate = today
    print("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
  }

  /// Force refresh selectedDate with cache clearing
  func forceRefreshSelectedDate() {
    print("🔄 HomeViewState: Force refreshing selectedDate")
    let today = LegacyDateUtils.forceRefreshToday()
    print("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
    print("🔄 HomeViewState: Refreshed today: \(today)")
    selectedDate = today
    print("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
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

  var body: some View {
    // 🔎 PROBE: HomeView re-render when XP changes
    let _ = print("🔵 HomeView re-render | xp:", xpManager.totalXP, "| selectedTab:", state.selectedTab)
    
    return VStack(spacing: 0) {
      // Main content area
      ZStack(alignment: .top) {
        // Dynamic theme background fills entire screen
        Color.primary
          .ignoresSafeArea(.all)

        VStack(spacing: 0) {
          // Header - show profile for More tab, streak for others
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
            showProfile: state.selectedTab == .more,
            currentStreak: state.currentStreak)

          // Content based on selected tab
          switch state.selectedTab {
          case .home:
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
                print("🔄 HomeView: onUpdateHabit received - \(updatedHabit.name)")
                Task {
                  await state.updateHabit(updatedHabit)
                }
                print("🔄 HomeView: Habit array updated and saved")
              },
              onSetProgress: { habit, date, progress in
                print("🔄 HomeView: onSetProgress received - \(habit.name), progress: \(progress)")
                print("🔄 HomeView: Current state.habits count: \(state.habits.count)")

                Task {
                  // Find the habit by ID from the current state to ensure we have the latest Core
                  // Data-synced version
                  if let syncedHabit = state.habits.first(where: { $0.id == habit.id }) {
                    print("🔄 HomeView: Found synced habit with ID: \(syncedHabit.id)")
                    print(
                      "🔄 HomeView: Current progress before update: \(syncedHabit.getProgress(for: date))")
                    await state.setHabitProgress(syncedHabit, for: date, progress: progress)
                    print("🔄 HomeView: Progress saved to Core Data using synced habit")
                  } else {
                    print(
                      "❌ HomeView: No synced habit found for ID: \(habit.id), falling back to original habit")
                    print("❌ HomeView: Available habit IDs: \(state.habits.map { $0.id })")
                    await state.setHabitProgress(habit, for: date, progress: progress)
                    print("🔄 HomeView: Progress saved to Core Data using original habit")
                  }
                }
              },
              onDeleteHabit: { habit in
                state.habitToDelete = habit
                state.showingDeleteConfirmation = true
              },
              onCompletionDismiss: {
                // Handle completion dismiss if needed
                print("🔄 HomeView: Habit completion bottom sheet dismissed")
              })

          case .progress:
            ProgressTabView()

          case .habits:
            HabitsTabView(
              state: state,
              onDeleteHabit: { habit in
                state.habitToDelete = habit
                state.showingDeleteConfirmation = true
              },
              onEditHabit: { habit in
                print("🔄 HomeView: onEditHabit received for habit: \(habit.name)")
                print("🔄 HomeView: Setting habitToEdit to open HabitEditView")
                state.habitToEdit = habit
              },
              onCreateHabit: {
                state.showingCreateHabit = true
              },
              onUpdateHabit: { updatedHabit in
                print("🔄 HomeView: onUpdateHabit received for habit: \(updatedHabit.name)")
                Task {
                  await state.updateHabit(updatedHabit)
                }
                print("🔄 HomeView: Habit updated and saved successfully")
              })

          case .more:
            MoreTabView(state: state)
          }
        }
      }

      // Bottom navigation
      TabBarView(selectedTab: $state.selectedTab, onCreateHabit: {
        state.showingCreateHabit = true
      })
    }
    .onAppear {
      print("🚀 HomeView: onAppear called!")
      print("🚀 HomeView: This is a test log - if you see this, logging is working!")
      
      // ✅ Ensure auth listener is set up (safety check)
      authManager.ensureAuthListenerSetup()
      
      loadHabitsOptimized()

      // Add additional debugging
      print("🔍 HomeView: Current habits count: \(state.habits.count)")
      print("🔍 HomeView: HabitRepository habits count: \(HabitRepository.shared.habits.count)")

      // Debug Core Data state
      HabitRepository.shared.debugHabitsState()

      // Debug current state
      state.debugCurrentState()
    }
    .onReceive(NotificationCenter.default
      .publisher(for: UIApplication.willResignActiveNotification))
    { _ in
      print("🏠 HomeView: App going to background, backing up habits...")
      state.backupHabits()
    }
    .onReceive(NotificationCenter.default
      .publisher(for: UIApplication.didBecomeActiveNotification))
    { _ in
      print("🏠 HomeView: App became active, updating streaks...")
      // Debounce to prevent excessive updates
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        state.updateAllStreaks()
      }
    }
    .sheet(isPresented: $state.showingCreateHabit) {
      CreateHabitFlowView(onSave: { habit in
        #if DEBUG
        print("🎯 [2/8] HomeView.onSave: received habit from CreateHabitFlowView")
        print("  → Habit: '\(habit.name)', ID: \(habit.id)")
        print("  → Current habits count: \(state.habits.count)")
        #endif

        // ✅ FIX: Wait for habit creation to complete before dismissing sheet
        Task { @MainActor in
          await state.createHabit(habit)
          #if DEBUG
          print("  → Habit creation completed, dismissing sheet")
          #endif
          state.showingCreateHabit = false
        }
      })
    }
    .fullScreenCover(item: $state.habitToEdit) { habit in
      HabitEditView(habit: habit, onSave: { updatedHabit in
        print("🔄 HomeView: HabitEditView save called for habit: \(updatedHabit.name)")
        Task {
          await state.updateHabit(updatedHabit)
          await MainActor.run {
            state.habitToEdit = nil
          }
        }
        print("🔄 HomeView: Habit updated and saved successfully")
      })
    }
    .confirmationDialog(
      "Delete Habit",
      isPresented: $state.showingDeleteConfirmation,
      titleVisibility: .visible)
    {
      Button("Cancel", role: .cancel) {
        print("❌ Delete cancelled")
        state.habitToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let habit = state.habitToDelete {
          print("🗑️ Deleting habit: \(habit.name)")
          Task {
            await state.deleteHabit(habit)
          }
          print("🗑️ Delete completed")
        } else {
          print("❌ No habit to delete")
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
    .sheet(isPresented: $tutorialManager.shouldShowTutorial) {
      TutorialBottomSheet(tutorialManager: tutorialManager)
    }
    .onChange(of: state.habits) { oldHabits, newHabits in
      // ✅ FIX: Reactively recalculate XP whenever habits change
      // This ensures XP updates immediately regardless of which tab is active
      Task { @MainActor in
        print("✅ REACTIVE_XP: Habits changed, recalculating XP...")
        
        // Count completed days from the current habit state
        let completedDaysCount = countCompletedDays(habits: newHabits)
        xpManager.publishXP(completedDaysCount: completedDaysCount)
        
        print("✅ REACTIVE_XP: XP updated to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
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
    print("🏠 HomeView: Loading habits from HabitRepository...")
    // Use HabitRepository instead of direct Habit.loadHabits()
    // The HabitRepository already loads habits in its init()
    print("🏠 HomeView: Habits loaded from HabitRepository - total: \(state.habits.count)")

    // Validate and correct streaks to ensure accuracy
    print("🏠 HomeView: Validating streaks...")
    state.validateAllStreaks()
    print("🏠 HomeView: Streak validation completed")
  }

  private func loadHabitsOptimized() {
    print("🏠 HomeView: Loading habits from HabitRepository...")
    // Force reload from Core Data to ensure we have the latest state
    Task {
      await HabitRepository.shared.loadHabits(force: true)
      print("🏠 HomeView: Habits loaded from HabitRepository - total: \(state.habits.count)")
    }

    // Only validate streaks if we have habits and haven't validated recently
    if !state.habits.isEmpty {
      print("🏠 HomeView: Validating streaks...")
      // Use Task to prevent UI blocking
      Task {
        let habits = state.habits
        for i in 0 ..< habits.count {
          if !habits[i].validateStreak() {
            print(
              "🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
            // ✅ PHASE 4: Streaks are now computed-only, no need to correct them
          }
        }

        // Update on main thread
        await MainActor.run {
          state.updateHabits(habits)
          print("🏠 HomeView: Streak validation completed")
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
