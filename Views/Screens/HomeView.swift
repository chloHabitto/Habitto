import Combine
import FirebaseAuth
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
    
    // ✅ FIX: Listen for streak updates from completion flow
    NotificationCenter.default.publisher(for: NSNotification.Name("StreakUpdated"))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        if let newStreak = notification.userInfo?["newStreak"] as? Int {
          print("📢 STREAK_UI_UPDATE: Received StreakUpdated notification with newStreak: \(newStreak)")
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
        
        print("🔍 STREAK_UI_UPDATE: Fetching streak for userId: '\(userId.isEmpty ? "guest" : userId)'")
        
        var descriptor = FetchDescriptor<GlobalStreakModel>(
          predicate: #Predicate { streak in
            streak.userId == userId
          }
        )
        // ✅ FIX: Include newly inserted objects in the fetch
        descriptor.includePendingChanges = true
        
        let allStreaks = try modelContext.fetch(descriptor)
        print("🔍 STREAK_UI_UPDATE: Found \(allStreaks.count) streak records")
        
        if let streak = allStreaks.first {
          let loadedStreak = streak.currentStreak
          currentStreak = loadedStreak
          print("✅ STREAK_UI_UPDATE: Loaded streak from GlobalStreakModel - currentStreak: \(loadedStreak), longestStreak: \(streak.longestStreak)")
          
          // ✅ FIX: Also broadcast via notification for consistency
          NotificationCenter.default.post(
            name: NSNotification.Name("StreakUpdated"),
            object: nil,
            userInfo: ["newStreak": loadedStreak]
          )
          print("📢 STREAK_UI_UPDATE: Broadcasted loaded streak via notification: \(loadedStreak)")
        } else {
          currentStreak = 0
          print("ℹ️ STREAK_UI_UPDATE: No GlobalStreakModel found for userId: \(userId), using streak = 0")
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
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("")
    print(String(repeating: "=", count: 60))
    print("🔄 STREAK_TRIGGER: updateAllStreaks() called at \(timestamp)")
    print("   Triggered by: Reactive callback from habit completion/uncompletion")
    print(String(repeating: "=", count: 60))
    
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
        
        print("🔄 STREAK_RECALC: Starting streak recalculation from CompletionRecords for user '\(userId.isEmpty ? "guest" : userId)'")
        
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
          print("ℹ️ STREAK_RECALC: No habits found - resetting streak to 0")
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
            
            // Look back up to 365 days
            let startDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
            
            print("🔄 STREAK_RECALC: Starting from TODAY (\(Habit.dateKey(for: today))) and counting backwards")
        
        while checkDate >= startDate {
          let dateKey = Habit.dateKey(for: checkDate)
          
          // Get scheduled habits for this date
          // ✅ CRITICAL FIX: Use EXACT same scheduling logic as XP calculation
          let scheduledHabits = habits.filter { habit in
            HabitSchedulingLogic.shouldShowHabitOnDate(habit, date: checkDate, habits: habits)
          }
          
          // ✅ Enhanced logging: Show what date we're checking
          let isToday = calendar.isDateInToday(checkDate)
          let isYesterday = calendar.isDateInYesterday(checkDate)
          let dayLabel = isToday ? "(TODAY)" : isYesterday ? "(YESTERDAY)" : ""
          
          print("🔍 STREAK_RECALC: Checking \(dateKey) \(dayLabel)")
          
          guard !scheduledHabits.isEmpty else {
            // No habits scheduled for this date - this might mean app wasn't used yet
            print("⏭️ STREAK_RECALC: Day \(dateKey) \(dayLabel) - no habits scheduled, skipping")
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            continue
          }
          
          print("   📅 \(scheduledHabits.count) habit(s) scheduled: \(scheduledHabits.map { $0.name }.joined(separator: ", "))")
          
          // ✅ CRITICAL: Use EXACT same logic as XP calculation (check CompletionRecords, not completionHistory)
          // ✅ CRITICAL FIX: Use same userId fallback logic as toHabit() to handle userId mismatches
          // Fetch CompletionRecords from SwiftData for this date
          let descriptor = FetchDescriptor<CompletionRecord>()
          let allRecords = try modelContext.fetch(descriptor)
          let completedRecords = allRecords.filter { record in
            guard record.dateKey == dateKey && record.isCompleted else { return false }
            
            // ✅ CRITICAL FIX: Handle userId mismatches (same logic as toHabit())
            // For guest users, accept both "" and "guest" userIds (legacy compatibility)
            if userId.isEmpty || userId == "guest" {
              return record.userId.isEmpty || record.userId == "guest" || record.userId == userId
            } else {
              // For authenticated users, exact match required
              return record.userId == userId
            }
          }
          
          // ✅ Show detailed completion status
          print("   🔍 CompletionRecords found: \(completedRecords.count)/\(scheduledHabits.count)")
          for habit in scheduledHabits {
            let record = completedRecords.first(where: { $0.habitId == habit.id })
            if let record = record {
              print("     ✅ \(habit.name) - CompletionRecord exists (isCompleted=\(record.isCompleted), progress=\(record.progress))")
            } else {
              print("     ❌ \(habit.name) - NO CompletionRecord found")
            }
          }
          
          // Check if ALL habits have a completed CompletionRecord (same as XP logic)
          let allComplete = scheduledHabits.allSatisfy { habit in
            completedRecords.contains(where: { $0.habitId == habit.id })
          }
          
          if allComplete {
            // Day is complete - increment streak
            currentStreakCount += 1
            if lastCompleteDate == nil {
              lastCompleteDate = checkDate
            }
            print("   ✅ RESULT: Day \(dateKey) \(dayLabel) COMPLETE - streak now \(currentStreakCount)")
          } else {
            // Day is incomplete
            let missingHabits = scheduledHabits.filter { habit in
              !completedRecords.contains(where: { $0.habitId == habit.id })
            }
            print("   ❌ RESULT: Day \(dateKey) \(dayLabel) INCOMPLETE - missing: \(missingHabits.map { $0.name }.joined(separator: ", "))")
            
            // ✅ CRITICAL FIX: Only break if we've already found complete days
            // This allows us to skip today if incomplete and continue checking yesterday
            if currentStreakCount > 0 {
              // We've found complete days already, so this incomplete day breaks the streak
              print("   ⏸️ STOPPING: Streak broken at \(currentStreakCount) day(s)")
              print("   📊 Last complete date was: \(lastCompleteDate.map { Habit.dateKey(for: $0) } ?? "none")")
              break
            } else {
              // We haven't found any complete days yet, so keep looking backwards
              // This handles the case where today is incomplete but yesterday might be complete
              print("   ⏭️ SKIPPING: Day incomplete, continuing backwards to find streak start...")
            }
          }
          
          // Move to previous day
          checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
            // Update streak model
            let oldStreak = streak.currentStreak
            streak.currentStreak = currentStreakCount
            streak.longestStreak = max(streak.longestStreak, currentStreakCount)
            streak.lastCompleteDate = lastCompleteDate
            streak.lastUpdated = Date()
            
            try modelContext.save()
            
            print("")
            print(String(repeating: "=", count: 60))
            print("✅ STREAK_RECALC: Recalculation COMPLETE")
            print("   Old streak: \(oldStreak) day(s)")
            print("   New streak: \(currentStreakCount) day(s)")
            print("   Last complete date: \(lastCompleteDate.map { Habit.dateKey(for: $0) } ?? "none")")
            print("   Longest streak: \(streak.longestStreak) day(s)")
            print(String(repeating: "=", count: 60))
            print("")
            
            // Reload the UI streak
            updateStreak()
        
      } catch {
        print("❌ STREAK_RECALC: Failed to recalculate streak: \(error)")
      }
    }
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
                // ✅ FIX: Update streak UI after completion flow finishes
                print("🔄 HomeView: Habit completion bottom sheet dismissed")
                state.updateStreak()
              },
              onStreakRecalculationNeeded: {
                // ✅ CRITICAL FIX: Recalculate streak immediately when habits are completed/uncompleted
                // This ensures streak updates reactively, just like XP does
                print("🔄 HomeView: Streak recalculation requested from HomeTabView")
                state.updateAllStreaks()
                print("✅ HomeView: Streak recalculation completed")
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
        print("✅ REACTIVE_XP: Habits changed, recalculating XP...")
        
        // Count completed days from the current habit state
        let completedDaysCount = countCompletedDays(habits: newHabits)
        xpManager.publishXP(completedDaysCount: completedDaysCount)
        
        print("✅ REACTIVE_XP: XP updated to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
        
        // ✅ CRITICAL FIX: Also recalculate streak when habits change!
        // But add a small delay to ensure SwiftData has finished saving CompletionRecords
        print("🔄 REACTIVE_STREAK: Habits changed, scheduling streak recalculation...")
        
        // Wait 100ms to allow SwiftData saves to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("🔄 REACTIVE_STREAK: Now recalculating streak after SwiftData sync...")
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
    print("🏠 HomeView: Loading habits from HabitRepository...")
    // Use HabitRepository instead of direct Habit.loadHabits()
    // The HabitRepository already loads habits in its init()
    print("🏠 HomeView: Habits loaded from HabitRepository - total: \(state.habits.count)")

    // Validate and correct streaks to ensure accuracy
    print("🏠 HomeView: Validating streaks...")
    state.validateAllStreaks()
    print("🏠 HomeView: Streak validation completed")
    
    // ✅ FIX: Refresh global streak from database after habits load
    state.updateStreak()
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
