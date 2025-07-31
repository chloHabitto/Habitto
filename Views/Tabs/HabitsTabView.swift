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
            title: "My Habits",
            headerContent: {
                AnyView(
                    statsRow
                        .padding(.horizontal, 0)
                        .padding(.top, 2)
                        .padding(.bottom, 0)
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
        
        let stats = [
            ("Active", activeHabits.count),
            ("Inactive", inactiveHabits.count),
            ("", 0), // Dummy third tab
            ("", 0) // Dummy fourth tab
        ]
        
        return HStack(spacing: 0) {
            ForEach(0..<stats.count, id: \.self) { idx in
                statsTabButton(for: idx, stats: stats)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    @ViewBuilder
    private func statsTabButton(for idx: Int, stats: [(String, Int)]) -> some View {
        VStack(spacing: 0) {
            Button(action: { 
                if idx < 2 { // Only allow clicking for first two tabs (Active, Inactive)
                    selectedStatsTab = idx 
                }
            }) {
                HStack(spacing: 4) {
                    Text(stats[idx].0)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx >= 2 ? 0 : 1) // Make third and fourth tab text invisible
                    Text("\(stats[idx].1)")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx >= 2 ? 0 : 1) // Make third and fourth tab text invisible
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: idx >= 2 ? .infinity : nil) // Expand third and fourth tabs
            .disabled(idx >= 2) // Disable clicking for third and fourth tabs
            
            // Bottom stroke for each tab
            Rectangle()
                .fill(selectedStatsTab == idx ? .text03 : .divider)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedStatsTab)
        }
    }
}

 
