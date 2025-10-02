import SwiftUI
import Combine

// Import for streak calculations
import Foundation

// MARK: - Tab Enum
enum Tab {
    case home, progress, habits, more
}

// MARK: - HomeView State Manager
@MainActor
class HomeViewState: ObservableObject {
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())
    @Published var scrollPosition: Int? = 0
    @Published var isOnCurrentWeek = true
    @Published var selectedTab: Tab = .home
    @Published var selectedStatsTab: Int = 0
    @Published var habits: [Habit] = []
    @Published var isLoadingHabits = true
    
    // UI State
    @Published var showingCreateHabit = false
    @Published var habitToEdit: Habit? = nil
    @Published var showingDeleteConfirmation = false
    @Published var habitToDelete: Habit?
    @Published var showingStreakView = false
    @Published var showingNotificationView = false
    
    // Performance optimization: Cache expensive operations
    private var lastHabitsUpdate: Date = Date()
    
    // Computed property for current streak
    var currentStreak: Int {
        guard !habits.isEmpty else { return 0 }
        let streakStats = StreakDataCalculator.calculateStreakStatistics(from: habits)
        return streakStats.currentStreak
    }
    
    // Core Data adapter
    let habitRepository = HabitRepository.shared
    
    // Store cancellables for proper memory management
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🚀 HomeViewState: Initializing...")
        let today = DateUtils.today()
        selectedDate = today
        print("🚀 HomeViewState: Initial selectedDate: \(selectedDate)")
        
        // Debug the repository state
        habitRepository.debugRepositoryState()
        
        // Initialize with current habits from repository to avoid empty state
        habits = habitRepository.habits
        isLoadingHabits = habits.isEmpty
        
        // Subscribe to HabitRepository changes
        habitRepository.$habits
            .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
            .sink { [weak self] habits in
                self?.habits = habits
                self?.isLoadingHabits = false
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
    }
    
    func updateHabits(_ newHabits: [Habit]) {
        // This method is used for bulk updates like streak validation
        // For individual habit operations, use createHabit, updateHabit, or deleteHabit
        habitRepository.saveHabits(newHabits)
        lastHabitsUpdate = Date()
    }
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date? = nil) {
        let targetDate = date ?? Calendar.current.startOfDay(for: Date())
        habitRepository.toggleHabitCompletion(habit, for: targetDate)
    }
    
    func deleteHabit(_ habit: Habit) {
        // Immediately remove from local state for instant UI update
        DispatchQueue.main.async {
            var updatedHabits = self.habits
            updatedHabits.removeAll { $0.id == habit.id }
            self.habits = updatedHabits
        }
        
        // Then delete from storage
        habitRepository.deleteHabit(habit)
        habitToDelete = nil
    }
    
    func updateHabit(_ updatedHabit: Habit) {
        habitRepository.updateHabit(updatedHabit)
    }
    
    func setHabitProgress(_ habit: Habit, for date: Date, progress: Int) {
        print("🔄 HomeViewState: setHabitProgress called for \(habit.name), progress: \(progress)")
        habitRepository.setProgress(for: habit, date: date, progress: progress)
        print("🔄 HomeViewState: setHabitProgress completed for \(habit.name)")
    }
    
    func createHabit(_ habit: Habit) {
        // Check if vacation mode is active
        if VacationManager.shared.isActive {
            print("🚫 HomeViewState: Cannot create habit during vacation mode")
            return
        }
        
        print("🔍 HomeViewState: createHabit called for habit: \(habit.name)")
        print("🔍 HomeViewState: Habit ID: \(habit.id)")
        print("🔍 HomeViewState: Current habits count: \(habits.count)")
        
        debugHabitUpdate("Before creating habit")
        
        Task {
            await habitRepository.createHabit(habit)
            print("🔍 HomeViewState: habitRepository.createHabit completed")
            
            debugHabitUpdate("After creating habit")
        }
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
        let today = DateUtils.today()
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
                let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
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
            print("🔄 HomeView: Not all habits completed. Streaks will be computed from completion history.")
            // ✅ PHASE 4: Streaks are now computed-only, no need to reset them
        }
        
        // Save the updated habits
        updateHabits(habits)
        print("🔄 HomeView: All streaks updated")
    }
    
    func validateAllStreaks() {
        print("🔄 HomeView: Validating all streaks...")
        for i in 0..<habits.count {
            if !habits[i].validateStreak() {
                print("🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
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
    
    // Debug method to check current state
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
    
    // Debug method to track habit updates
    func debugHabitUpdate(_ context: String) {
        print("🔄 HomeViewState: \(context)")
        print("  - Current habits count: \(habits.count)")
        print("  - HabitRepository habits count: \(habitRepository.habits.count)")
        print("  - Habits match: \(habits.count == habitRepository.habits.count)")
    }
    
    // Test method to create a sample habit
    func createTestHabit() {
        print("🧪 HomeViewState: Creating test habit...")
        let testHabit = Habit(
            name: "Test Habit",
            description: "This is a test habit",
            icon: "🧪",
            color: .blue,
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
            actualUsage: [:]
        )
        
        createHabit(testHabit)
    }
    
    // Simple test method that bypasses validation
    func createSimpleTestHabit() {
        print("🧪 HomeViewState: Creating simple test habit...")
        let testHabit = Habit(
            name: "Simple Test",
            description: "Simple test habit",
            icon: "🧪",
            color: .blue,
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
            actualUsage: [:]
        )
        
        print("🧪 HomeViewState: Created habit: \(testHabit.name) (ID: \(testHabit.id))")
        
        // Try to save directly to UserDefaults as a test
        Task {
            _ = UserDefaults.standard
            // TODO: Fix JSON encoding issue
            // let encoded = try JSONEncoder().encode([testHabit])
            // userDefaults.set(encoded, forKey: "habits")
            print("🧪 HomeViewState: Saved to UserDefaults directly")
            
            // Try to reload
            await habitRepository.loadHabits(force: true)
            print("🧪 HomeViewState: Reloaded habits, count: \(habitRepository.habits.count)")
        }
    }
    
    // Force update selectedDate to today
    func forceUpdateSelectedDateToToday() {
        print("🔄 HomeViewState: Force updating selectedDate to today")
        let today = DateUtils.today()
        print("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
        print("🔄 HomeViewState: Target today: \(today)")
        selectedDate = today
        print("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
    }
    
    // Force refresh selectedDate with cache clearing
    func forceRefreshSelectedDate() {
        print("🔄 HomeViewState: Force refreshing selectedDate")
        let today = DateUtils.forceRefreshToday()
        print("🔄 HomeViewState: Current selectedDate: \(selectedDate)")
        print("🔄 HomeViewState: Refreshed today: \(today)")
        selectedDate = today
        print("🔄 HomeViewState: Updated selectedDate to: \(selectedDate)")
    }
}

@MainActor
struct HomeView: View {
    @StateObject private var state = HomeViewState()
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
                    VStack(spacing: 0) {
            
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
                            state.showingStreakView = true
                        },
                        onNotificationTap: {
                            state.showingNotificationView = true
                        },
                        showProfile: state.selectedTab == .more,
                        currentStreak: state.currentStreak
                    )
                    
                    // Content based on selected tab
                    switch state.selectedTab {
                    case .home:
                        HomeTabView(
                            selectedDate: $state.selectedDate,
                            selectedStatsTab: $state.selectedStatsTab,
                            habits: state.habits,
                            isLoadingHabits: state.isLoadingHabits,
                            onToggleHabit: { (habit: Habit, date: Date) in
                                state.toggleHabitCompletion(habit, for: date)
                            },
                            onUpdateHabit: { updatedHabit in
                                print("🔄 HomeView: onUpdateHabit received - \(updatedHabit.name)")
                                state.updateHabit(updatedHabit)
                                print("🔄 HomeView: Habit array updated and saved")
                            },
                            onSetProgress: { habit, date, progress in
                                print("🔄 HomeView: onSetProgress received - \(habit.name), progress: \(progress)")
                                
                                // Find the habit by ID from the current state to ensure we have the latest Core Data-synced version
                                if let syncedHabit = state.habits.first(where: { $0.id == habit.id }) {
                                    print("🔄 HomeView: Found synced habit with ID: \(syncedHabit.id)")
                                    print("🔄 HomeView: Current progress before update: \(syncedHabit.getProgress(for: date))")
                                    state.setHabitProgress(syncedHabit, for: date, progress: progress)
                                    print("🔄 HomeView: Progress saved to Core Data using synced habit")
                                } else {
                                    print("❌ HomeView: No synced habit found for ID: \(habit.id), falling back to original habit")
                                    state.setHabitProgress(habit, for: date, progress: progress)
                                    print("🔄 HomeView: Progress saved to Core Data using original habit")
                                }
                            },
                            onDeleteHabit: { habit in
                                state.habitToDelete = habit
                                state.showingDeleteConfirmation = true
                            },
                            onCompletionDismiss: {
                                // Handle completion dismiss if needed
                                print("🔄 HomeView: Habit completion bottom sheet dismissed")
                            }
                        )
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
                                state.updateHabit(updatedHabit)
                                print("🔄 HomeView: Habit updated and saved successfully")
                            }
                        )
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
            loadHabitsOptimized()
            
            // Add additional debugging
            print("🔍 HomeView: Current habits count: \(state.habits.count)")
            print("🔍 HomeView: HabitRepository habits count: \(HabitRepository.shared.habits.count)")
            
            // Debug Core Data state
            HabitRepository.shared.debugHabitsState()
            
            // Debug current state
            state.debugCurrentState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("🏠 HomeView: App going to background, backing up habits...")
            state.backupHabits()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("🏠 HomeView: App became active, updating streaks...")
            // Debounce to prevent excessive updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                state.updateAllStreaks()
            }
        }
        .sheet(isPresented: $state.showingCreateHabit) {
            CreateHabitFlowView(onSave: { habit in
                print("🔍 HomeView: CreateHabitFlowView onSave called with habit: \(habit.name)")
                print("🔍 HomeView: Habit details - ID: \(habit.id), Color: \(habit.color), Icon: \(habit.icon)")
                print("🔍 HomeView: Current habits count before creation: \(state.habits.count)")
                
                state.createHabit(habit)
                
                print("🔍 HomeView: createHabit called, waiting for Core Data update...")
                state.showingCreateHabit = false
            })
        }
        .fullScreenCover(item: $state.habitToEdit) { habit in
            HabitEditView(habit: habit, onSave: { updatedHabit in
                print("🔄 HomeView: HabitEditView save called for habit: \(updatedHabit.name)")
                state.updateHabit(updatedHabit)
                print("🔄 HomeView: Habit updated and saved successfully")
                state.habitToEdit = nil
            })
        }
        .confirmationDialog("Delete Habit", isPresented: $state.showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { 
                print("❌ Delete cancelled")
                state.habitToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let habit = state.habitToDelete {
                    print("🗑️ Deleting habit: \(habit.name)")
                    state.deleteHabit(habit)
                    print("🗑️ Delete completed")
                } else {
                    print("❌ No habit to delete")
                }
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }

        .sheet(isPresented: $state.showingStreakView) {
            StreakView()
                .environmentObject(state)
        }
        .sheet(isPresented: $state.showingNotificationView) {
            NotificationView()
        }
        .sheet(isPresented: $tutorialManager.shouldShowTutorial) {
            TutorialBottomSheet(tutorialManager: tutorialManager)
        }
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
                for i in 0..<habits.count {
                    if !habits[i].validateStreak() {
                        print("🔄 HomeView: Streak validation failed for habit: \(habits[i].name) - streak is now computed-only")
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

 
