import SwiftUI

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
    
    // Core Data adapter
    private let coreDataAdapter = CoreDataAdapter.shared
    
    init() {
        // Subscribe to Core Data changes
        coreDataAdapter.$habits
            .receive(on: DispatchQueue.main)
            .assign(to: &$habits)
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
        coreDataAdapter.deleteHabit(habit)
        habitToDelete = nil
    }
    
    func updateHabit(_ updatedHabit: Habit) {
        coreDataAdapter.updateHabit(updatedHabit)
    }
    
    func createHabit(_ habit: Habit) {
        coreDataAdapter.createHabit(habit)
    }
    
    func backupHabits() {
        coreDataAdapter.backupToUserDefaults()
    }
    
    func loadHabits() {
        // Core Data adapter automatically loads habits
        print("🔄 HomeView: Habits loaded from Core Data")
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
}

struct HomeView: View {
    @StateObject private var state = HomeViewState()
    
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
                        showProfile: state.selectedTab == .more
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
                        MoreTabView()
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
            loadHabits()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("🏠 HomeView: App became active, updating streaks...")
            state.updateAllStreaks()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("🏠 HomeView: App going to background, backing up habits...")
            state.backupHabits()
        }
        .sheet(isPresented: $state.showingCreateHabit) {
            CreateHabitFlowView(onSave: { habit in
                state.createHabit(habit)
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
        .alert("Delete Habit", isPresented: $state.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { 
                print("❌ Delete cancelled")
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
            StreakView(userHabits: state.habits)
        }
        .sheet(isPresented: $state.showingNotificationView) {
            NotificationView()
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
}

#Preview {
    HomeView()
}

 
