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
    
    // Performance optimization: Cache expensive operations
    private var lastHabitsUpdate: Date = Date()
    
    func updateHabits(_ newHabits: [Habit]) {
        habits = newHabits
        lastHabitsUpdate = Date()
    }
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date? = nil) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let targetDate = date ?? Calendar.current.startOfDay(for: Date())
            let wasCompleted = habits[index].isCompleted(for: targetDate)
            
            if wasCompleted {
                // Mark as incomplete for the target date
                habits[index].markIncomplete(for: targetDate)
                // Only decrease streak if it's today's date
                if Calendar.current.isDate(targetDate, inSameDayAs: Date()) {
                    habits[index].streak = max(0, habits[index].streak - 1)
                }
            } else {
                // Mark as completed for the target date
                habits[index].markCompleted(for: targetDate)
                // Only increase streak if it's today's date
                if Calendar.current.isDate(targetDate, inSameDayAs: Date()) {
                    habits[index].streak += 1
                }
            }
            
            Habit.saveHabits(habits)
            // Force SwiftUI to recognize the array has changed by creating a new instance
            habits = Array(habits)
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        Habit.saveHabits(habits)
        habitToDelete = nil
    }
    
    func updateHabit(_ updatedHabit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == updatedHabit.id }) {
            habits[index] = updatedHabit
            Habit.saveHabits(habits)
            // Force SwiftUI to recognize the array has changed by creating a new instance
            habits = Array(habits)
        }
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
        .sheet(isPresented: $state.showingCreateHabit) {
            CreateHabitFlowView(onSave: { habit in
                state.habits.append(habit)
                Habit.saveHabits(state.habits, immediate: true)
                // Force SwiftUI to recognize the array has changed by creating a new instance
                state.habits = Array(state.habits)
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
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let habit = state.habitToDelete {
                    state.deleteHabit(habit)
                }
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $state.showingStreakView) {
            StreakView(userHabits: state.habits)
        }
    }
    
    // MARK: - Lifecycle
    private func loadHabits() {
        print("🏠 HomeView: Loading habits...")
        let loadedHabits = Habit.loadHabits()
        print("🏠 HomeView: Loaded \(loadedHabits.count) habits")
        
        state.habits = loadedHabits
        print("🏠 HomeView: Habits assigned to state - total: \(state.habits.count)")
    }
}

#Preview {
    HomeView()
}

 
