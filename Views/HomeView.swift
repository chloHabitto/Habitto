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
    @State private var showingStreakView = false
    
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
                    HeaderView(
                        onCreateHabit: {
                            showingCreateHabit = true
                        },
                        onStreakTap: {
                            showingStreakView = true
                        }
                    )
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case .home:
                        HomeTabView(
                            selectedDate: $selectedDate,
                            selectedStatsTab: $selectedStatsTab,
                            habits: habits,
                            onToggleHabit: { habit in
                                toggleHabitCompletion(habit)
                            },
                            onUpdateHabit: { updatedHabit in
                                print("🔄 HomeView: onUpdateHabit received - \(updatedHabit.name)")
                                if let index = habits.firstIndex(where: { $0.id == updatedHabit.id }) {
                                    print("🔄 HomeView: Found habit at index \(index)")
                                    habits[index] = updatedHabit
                                    Habit.saveHabits(habits)
                                    // Force SwiftUI to recognize the array has changed by creating a new instance
                                    habits = Array(habits)
                                    print("🔄 HomeView: Habit array updated and saved")
                                } else {
                                    print("❌ HomeView: Could not find habit with id \(updatedHabit.id)")
                                }
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
                                print("🔄 HomeView: onEditHabit received for habit: \(habit.name)")
                                print("🔄 HomeView: Setting habitToEdit to open HabitEditView")
                                habitToEdit = habit
                            },
                            onCreateHabit: {
                                showingCreateHabit = true
                            },
                            onUpdateHabit: { updatedHabit in
                                print("🔄 HomeView: onUpdateHabit received for habit: \(updatedHabit.name)")
                                if let index = habits.firstIndex(where: { $0.id == updatedHabit.id }) {
                                    habits[index] = updatedHabit
                                    Habit.saveHabits(habits)
                                    // Force SwiftUI to recognize the array has changed by creating a new instance
                                    habits = Array(habits)
                                    print("🔄 HomeView: Habit updated and saved successfully")
                                }
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
        .fullScreenCover(item: $habitToEdit) { habit in
            HabitEditView(habit: habit, onSave: { updatedHabit in
                print("🔄 HomeView: HabitEditView save called for habit: \(updatedHabit.name)")
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index] = updatedHabit
                    Habit.saveHabits(habits)
                    // Force SwiftUI to recognize the array has changed by creating a new instance
                    habits = Array(habits)
                    print("🔄 HomeView: Habit updated and saved successfully")
                }
                habitToEdit = nil
            })
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
        .fullScreenCover(isPresented: $showingStreakView) {
            StreakView()
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
            // Force SwiftUI to recognize the array has changed by creating a new instance
            habits = Array(habits)
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

 
