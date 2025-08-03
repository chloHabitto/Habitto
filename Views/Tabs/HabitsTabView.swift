import SwiftUI

struct HabitsTabView: View {
    @State private var selectedStatsTab: Int = 0
    @State private var selectedHabit: Habit? = nil
    let habits: [Habit]
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onCreateHabit: () -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    // Custom initializer with default value for onUpdateHabit
    init(
        habits: [Habit],
        onDeleteHabit: @escaping (Habit) -> Void,
        onEditHabit: @escaping (Habit) -> Void,
        onCreateHabit: @escaping () -> Void,
        onUpdateHabit: ((Habit) -> Void)? = nil
    ) {
        self.habits = habits
        self.onDeleteHabit = onDeleteHabit
        self.onEditHabit = onEditHabit
        self.onCreateHabit = onCreateHabit
        self.onUpdateHabit = onUpdateHabit
    }
    
    var body: some View {
        WhiteSheetContainer(
            title: "Habits",
            headerContent: {
                AnyView(
                    statsRow
                        .padding(.horizontal, 0)
                        .padding(.top, 2)
                        .padding(.bottom, 0)
                )
            },
            rightButton: {
                AnyView(
                    Button(action: {
                        // View button action
                    }) {
                        Text("View")
                            .font(.appBodyMedium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.primaryContainer)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                )
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if habits.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.circle")
                                .font(.appDisplaySmall)
                                .foregroundColor(.secondary)
                            
                            Text("No habits yet")
                                .font(.appButtonText2)
                                .foregroundColor(.secondary)
                            
                            Text("Create your first habit to get started")
                                .font(.appBodyMedium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHabits) { habit in
                                habitDetailRow(habit)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Edit") {
                                            // TODO: Implement edit functionality
                                        }
                                        .tint(.blue)
                                        
                                        Button("Delete") {
                                            onDeleteHabit(habit)
                                        }
                                        .tint(.red)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: Date(), onDeleteHabit: onDeleteHabit)
        }
    }
    
    private var filteredHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch selectedStatsTab {
        case 0: // Active
            return habits.filter { habit in
                // Check if habit is currently active (within its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is active if today is within its period
                return today >= startDate && today <= endDate
            }
        case 1: // Inactive
            return habits.filter { habit in
                // Check if habit is currently inactive (outside its period)
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                
                // Habit is inactive if today is outside its period
                return today < startDate || today > endDate
            }
        case 2, 3: // Dummy tabs - show all habits
            return habits
        default:
            return habits
        }
    }
    
    private func habitDetailRow(_ habit: Habit) -> some View {
        AddedHabitItem(
            habit: habit,
            onEdit: {
                print("🔄 HabitsTabView: Edit button tapped for habit: \(habit.name)")
                print("🔄 HabitsTabView: Calling onEditHabit callback")
                onEditHabit(habit)
                print("🔄 HabitsTabView: onEditHabit callback completed")
            },
            onDelete: {
                print("🔄 HabitsTabView: Delete button tapped for habit: \(habit.name)")
                onDeleteHabit(habit)
            },
            onTap: {
                selectedHabit = habit
            }
        )
    }
    
    private func detailItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.appLabelSmallEmphasised)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.appLabelSmallEmphasised)
                .foregroundColor(.secondary)
        }
    }
    

    
    // MARK: - Stats Row
    private var statsRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let activeHabits = habits.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today >= startDate && today <= endDate
        }
        
        let inactiveHabits = habits.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today < startDate || today > endDate
        }
        
        let tabs = TabItem.createStatsTabs(activeCount: activeHabits.count, inactiveCount: inactiveHabits.count)
        
        return UnifiedTabBarView(
            tabs: tabs,
            selectedIndex: selectedStatsTab,
            style: .underline
        ) { index in
            if index < 2 { // Only allow clicking for first two tabs (Active, Inactive)
                selectedStatsTab = index
            }
        }
    }
}

 
