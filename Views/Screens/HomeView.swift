import SwiftUI
import Combine

// Import for streak calculations
import Foundation

// MARK: - Tab Enum
enum Tab {
    case home, habits, progress, more
}

// MARK: - HomeView State Manager
class HomeViewState: ObservableObject {
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())
    @Published var scrollPosition: Int? = 0
    @Published var isOnCurrentWeek = true
    @Published var selectedTab: Tab = .home
    @Published var selectedStatsTab: Int = 0
    @Published var habits: [Habit] = []
    
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
    let coreDataAdapter = CoreDataAdapter.shared
    
    // Store cancellables for proper memory management
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🚀 HomeViewState: Initializing...")
        let today = DateUtils.today()
        selectedDate = today
        print("🚀 HomeViewState: Initial selectedDate: \(selectedDate)")
        
        // Subscribe to CoreDataAdapter changes
        coreDataAdapter.$habits
            .sink { [weak self] habits in
                print("🔄 HomeViewState: Received \(habits.count) habits from CoreDataAdapter")
                self?.habits = habits
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func updateHabits(_ newHabits: [Habit]) {
        // This method is used for bulk updates like streak validation
        // For individual habit operations, use createHabit, updateHabit, or deleteHabit
        coreDataAdapter.saveHabits(newHabits)
        lastHabitsUpdate = Date()
    }
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date? = nil) {
        let targetDate = date ?? Calendar.current.startOfDay(for: Date())
        coreDataAdapter.toggleHabitCompletion(habit, for: targetDate)
    }
    
    func deleteHabit(_ habit: Habit) {
        print("🗑️ HomeViewState: Starting delete for habit: \(habit.name)")
        print("🗑️ HomeViewState: Current habits count: \(habits.count)")
        
        // Immediately remove from local state for instant UI update
        DispatchQueue.main.async {
            var updatedHabits = self.habits
            updatedHabits.removeAll { $0.id == habit.id }
            self.habits = updatedHabits
            print("🗑️ HomeViewState: Immediately removed habit, new count: \(self.habits.count)")
        }
        
        // Then delete from Core Data
        coreDataAdapter.deleteHabit(habit)
        habitToDelete = nil
        print("🗑️ HomeViewState: Delete completed")
    }
    
    func updateHabit(_ updatedHabit: Habit) {
        coreDataAdapter.updateHabit(updatedHabit)
    }
    
    func setHabitProgress(_ habit: Habit, for date: Date, progress: Int) {
        coreDataAdapter.setProgress(for: habit, date: date, progress: progress)
    }
    
    func createHabit(_ habit: Habit) {
        print("🔍 HomeViewState: createHabit called for habit: \(habit.name)")
        print("🔍 HomeViewState: Habit ID: \(habit.id)")
        print("🔍 HomeViewState: Current habits count: \(habits.count)")
        
        coreDataAdapter.createHabit(habit)
        
        print("🔍 HomeViewState: coreDataAdapter.createHabit completed")
        print("🔍 HomeViewState: Waiting for Core Data update notification...")
    }
    
    func backupHabits() {
        coreDataAdapter.backupToUserDefaults()
    }
    
    func loadHabits() {
        // Core Data adapter automatically loads habits
        print("🔄 HomeView: Habits loaded from Core Data")
    }
    
    func cleanupDuplicateHabits() {
        print("🔄 HomeView: Cleaning up duplicate habits...")
        coreDataAdapter.cleanupDuplicateHabits()
    }
    
    func updateAllStreaks() {
        print("🔄 HomeView: Updating all streaks...")
        for i in 0..<habits.count {
            habits[i].updateStreakWithReset()
        }
        // Save the updated habits
        updateHabits(habits)
        print("🔄 HomeView: All streaks updated")
    }
    
    func validateAllStreaks() {
        print("🔄 HomeView: Validating all streaks...")
        for i in 0..<habits.count {
            if !habits[i].validateStreak() {
                print("🔄 HomeView: Correcting streak for habit: \(habits[i].name)")
                habits[i].correctStreak()
            }
        }
        // Save the corrected habits
        updateHabits(habits)
        print("🔄 HomeView: All streaks validated")
    }
    
    func refreshHabits() {
        print("🔄 HomeViewState: Manual refresh requested")
        coreDataAdapter.loadHabits(force: true)
        
        // Also validate streaks
        if !habits.isEmpty {
            validateAllStreaks()
        }
    }
    
    // Debug method to check current state
    func debugCurrentState() {
        print("🔍 HomeViewState: === DEBUG STATE ===")
        print("🔍 HomeViewState: Current habits count: \(habits.count)")
        print("🔍 HomeViewState: CoreDataAdapter habits count: \(coreDataAdapter.habits.count)")
        print("🔍 HomeViewState: Current selectedDate: \(selectedDate)")
        
        for (index, habit) in habits.enumerated() {
            print("🔍 HomeViewState: Habit \(index): \(habit.name) (ID: \(habit.id))")
        }
        
        print("🔍 HomeViewState: === END DEBUG ===")
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

struct HomeView: View {
    @StateObject private var state = HomeViewState()
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
                    VStack(spacing: 0) {
            
            // Main content area
            ZStack(alignment: .top) {
                // Dark blue background fills entire screen
                Color(red: 0.11, green: 0.15, blue: 0.30)
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
                            }
                        )
                    case .habits:
                        HabitsTabView(
                            habits: state.habits,
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
                    case .progress:
                        ProgressTabView(habits: state.habits)
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
            loadHabitsOptimized()
            
            // Add additional debugging
            print("🔍 HomeView: Current habits count: \(state.habits.count)")
            print("🔍 HomeView: CoreDataAdapter habits count: \(CoreDataAdapter.shared.habits.count)")
            
            // Debug Core Data state
            CoreDataAdapter.shared.debugHabitsState()
            
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

        .fullScreenCover(isPresented: $state.showingStreakView) {
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
        print("🏠 HomeView: Loading habits from CoreDataAdapter...")
        // Use CoreDataAdapter instead of direct Habit.loadHabits()
        // The CoreDataAdapter already loads habits in its init()
        print("🏠 HomeView: Habits loaded from CoreDataAdapter - total: \(state.habits.count)")
        
        // Validate and correct streaks to ensure accuracy
        print("🏠 HomeView: Validating streaks...")
        state.validateAllStreaks()
        print("🏠 HomeView: Streak validation completed")
    }
    
    private func loadHabitsOptimized() {
        print("🏠 HomeView: Loading habits from CoreDataAdapter...")
        // Force reload from Core Data to ensure we have the latest state
        CoreDataAdapter.shared.loadHabits(force: true)
        print("🏠 HomeView: Habits loaded from CoreDataAdapter - total: \(state.habits.count)")
        
        // Only validate streaks if we have habits and haven't validated recently
        if !state.habits.isEmpty {
            print("🏠 HomeView: Validating streaks...")
            // Use async to prevent UI blocking
            DispatchQueue.global(qos: .background).async {
                var updatedHabits = state.habits
                for i in 0..<updatedHabits.count {
                    if !updatedHabits[i].validateStreak() {
                        print("🔄 HomeView: Correcting streak for habit: \(updatedHabits[i].name)")
                        updatedHabits[i].correctStreak()
                    }
                }
                
                // Update on main thread
                DispatchQueue.main.async {
                    state.updateHabits(updatedHabits)
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

 
