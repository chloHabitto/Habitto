import SwiftUI

struct HabitsTabView: View {
    @State private var selectedHabit: Habit? = nil
    @State private var showingAllHabitsView = false
    @State private var selectedHabitType: HabitType = .formation
    @State private var selectedPeriod: TimePeriod = .today
    
    let habits: [Habit]
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onCreateHabit: () -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    // MARK: - Computed Properties
    private var filteredHabitsByType: [Habit] {
        habits.filter { $0.habitType == selectedHabitType }
    }
    
    private var periodStats: [(String, TimePeriod?)] {
        return [
            ("Today", .today),
            ("Week", .week),
            ("Year", .year),
            ("All", .all)
        ]
    }
    
    // MARK: - Habit Management Section
    private var habitManagementSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Habit Management")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.text06)
                    .help("Manage and track your individual habits")
            }
            
            if filteredHabitsByType.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.circle",
                    message: "No \(selectedHabitType == .formation ? "building" : "breaking") habits to manage"
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(filteredHabitsByType.prefix(3), id: \.id) { habit in
                        if let habitProgress = createHabitProgress(for: habit) {
                            HabitProgressCard(habitProgress: habitProgress)
                        }
                        
                        if let habitGoal = createHabitGoal(for: habit) {
                            GoalAchievementCard(habitGoal: habitGoal)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods for Progress Cards
    private func createHabitProgress(for habit: Habit) -> HabitProgress? {
        let completionPercentage = Double.random(in: 20...90)
        let trend: TrendDirection = [.improving, .stable, .declining].randomElement() ?? .stable
        
        return HabitProgress(
            habit: habit,
            period: selectedPeriod,
            completionPercentage: completionPercentage,
            trend: trend
        )
    }
    
    private func createHabitGoal(for habit: Habit) -> HabitGoal? {
        let goal = parseGoal(from: habit.goal)
        let currentAverage = Double.random(in: 1...10)
        let goalHitRate = Double.random(in: 0.3...1.0)
        
        return HabitGoal(
            habit: habit,
            goal: goal,
            currentAverage: currentAverage,
            goalHitRate: goalHitRate
        )
    }
    
    private func parseGoal(from goalString: String) -> Goal {
        let components = goalString.lowercased().components(separatedBy: " ")
        
        var amount: Double = 1.0
        if let firstComponent = components.first, let parsedAmount = Double(firstComponent) {
            amount = parsedAmount
        }
        
        var unit = "times"
        if let lastComponent = components.last, !lastComponent.isEmpty {
            unit = lastComponent
        }
        
        return Goal(amount: amount, unit: unit)
    }
    
    // MARK: - Habit Type Selector
    private var habitTypeSelector: some View {
        UnifiedTabBarView(
            tabs: TabItem.createHabitTypeTabs(
                buildingCount: habits.filter { $0.habitType == .formation }.count,
                breakingCount: habits.filter { $0.habitType == .breaking }.count
            ),
            selectedIndex: selectedHabitType == .formation ? 0 : 1,
            style: .underline
        ) { index in
            selectedHabitType = index == 0 ? .formation : .breaking
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        UnifiedTabBarView(
            tabs: TabItem.createPeriodTabs(),
            selectedIndex: periodStats.firstIndex { $0.1 == selectedPeriod } ?? 0,
            style: .pill
        ) { index in
            if let period = periodStats[index].1 {
                selectedPeriod = period
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }
    
    var body: some View {
        WhiteSheetContainer(
            title: "Habits",
            rightButton: {
                AnyView(
                    Button(action: {
                        showingAllHabitsView = true
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
            VStack(spacing: 0) {
                habitTypeSelector
                periodSelector
                
                ScrollView {
                    VStack(spacing: 32) {
                        habitManagementSection
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: Date(), onDeleteHabit: onDeleteHabit)
        }
        .sheet(isPresented: $showingAllHabitsView) {
            AllHabitsView(
                habits: habits,
                onDeleteHabit: onDeleteHabit,
                onEditHabit: onEditHabit,
                onUpdateHabit: onUpdateHabit
            )
        }
    }
}

// MARK: - AllHabitsView
struct AllHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatsTab: Int = 0
    @State private var selectedHabit: Habit? = nil
    
    let habits: [Habit]
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    // MARK: - Computed Properties
    private var filteredHabits: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch selectedStatsTab {
        case 0: // Active
            return habits.filter { habit in
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                return today >= startDate && today <= endDate
            }
        case 1: // Inactive
            return habits.filter { habit in
                let startDate = calendar.startOfDay(for: habit.startDate)
                let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
                return today < startDate || today > endDate
            }
        case 2, 3: // Dummy tabs - show all habits
            return habits
        default:
            return habits
        }
    }
    
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
            if index < 2 {
                selectedStatsTab = index
            }
        }
    }
    
    private func habitDetailRow(_ habit: Habit) -> some View {
        AddedHabitItem(
            habit: habit,
            onEdit: {
                onEditHabit(habit)
            },
            onDelete: {
                onDeleteHabit(habit)
            },
            onTap: {
                selectedHabit = habit
            }
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    statsRow
                        .padding(.horizontal, 0)
                        .padding(.top, 16)
                        .background(.white)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if habits.isEmpty {
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
                            VStack(alignment: .leading, spacing: 16) {
                                Text("All Habits")
                                    .font(.appTitleLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(.text01)
                                    .padding(.horizontal, 20)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredHabits, id: \.id) { habit in
                                        habitDetailRow(habit)
                                            .padding(.horizontal, 20)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button("Edit") {
                                                    onEditHabit(habit)
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
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                }
                .background(.surface2)
            }
            .navigationTitle("All Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: Date(), onDeleteHabit: onDeleteHabit)
        }
    }
}
