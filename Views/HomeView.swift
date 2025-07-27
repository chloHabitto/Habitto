import SwiftUI

struct HomeView: View {
    @State private var selectedDate = Date()
    @State private var scrollPosition: Int? = 0
    @State private var isOnCurrentWeek = true
    @State private var selectedTab: Tab = .home
    @State private var showingCreateHabit = false
    @State private var habitToEdit: Habit? = nil
    @State private var habits: [Habit] = []
    @State private var selectedStatsTab: Int = 0
    @State private var showingDeleteConfirmation = false
    @State private var habitToDelete: Habit?
    
    enum Tab {
        case home, habits, progress, more
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ZStack(alignment: .top) {
                // Dark blue background fills entire screen
                Color(red: 0.11, green: 0.15, blue: 0.30)
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    HeaderView(onCreateHabit: {
                        showingCreateHabit = true
                    })
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case .home:
                        HomeTabView(
                            selectedDate: $selectedDate,
                            selectedStatsTab: $selectedStatsTab,
                            habits: habits,
                            onToggleHabit: { habit in
                                toggleHabitCompletion(habit)
                            }
                        )
                    case .habits:
                        HabitsTabView(
                            habits: habits,
                            onToggleHabit: { habit in
                                toggleHabitCompletion(habit)
                            },
                            onDeleteHabit: { habit in
                                habitToDelete = habit
                                showingDeleteConfirmation = true
                            },
                            onEditHabit: { habit in
                                habitToEdit = habit
                            },
                            onCreateHabit: {
                                showingCreateHabit = true
                            }
                        )
                    case .progress:
                        ProgressTabView()
                    case .more:
                        MoreTabView()
                    }
                }
            }
            
            // Bottom navigation
            TabBarView(selectedTab: $selectedTab, onCreateHabit: {
                showingCreateHabit = true
            })
        }
        .onAppear {
            loadHabits()
        }
        .sheet(isPresented: $showingCreateHabit) {
            CreateHabitFlowView(onSave: { habit in
                habits.append(habit)
                Habit.saveHabits(habits)
                showingCreateHabit = false
            })
        }
        .sheet(item: $habitToEdit) { habit in
            CreateHabitFlowView(onSave: { updatedHabit in
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index] = updatedHabit
                    Habit.saveHabits(habits)
                }
                habitToEdit = nil
            }, habitToEdit: habit)
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete {
                    deleteHabit(habit)
                }
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
    }
    
    // MARK: - Lifecycle
    private func loadHabits() {
        habits = Habit.loadHabits()
    }
    
    private func toggleHabitCompletion(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isCompleted.toggle()
            if habits[index].isCompleted {
                habits[index].streak += 1
            } else {
                habits[index].streak = max(0, habits[index].streak - 1)
            }
            Habit.saveHabits(habits)
        }
    }
    
    private func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        Habit.saveHabits(habits)
        habitToDelete = nil
    }
}

#Preview {
    HomeView()
}

 
