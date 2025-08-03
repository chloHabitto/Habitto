import SwiftUI

struct HabitsTabView: View {
    @State private var selectedStatsTab: Int = 0
    @State private var selectedHabit: Habit? = nil
    @State private var showingAllHabitsView = false
    @State private var selectedHabitType: HabitType = .formation
    @State private var selectedPeriod: TimePeriod = .today
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
    
    // MARK: - Habit Insights
    private var habitInsights: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Habit Insights")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.text06)
                    .help("Provides personalized insights about your habits")
            }
            
            if filteredHabitsByType.isEmpty {
                EmptyStateView(
                    icon: "lightbulb",
                    message: "No \(selectedHabitType == .formation ? "building" : "breaking") habits to analyze"
                )
            } else {
                VStack(spacing: 16) {
                    // Best performing habit
                    if let bestHabit = getBestHabit() {
                        InsightCard(
                            type: .success,
                            title: "Your best habit",
                            description: "\(bestHabit.name) - Keep up the great work!"
                        )
                    }
                    
                    // Habit that needs attention
                    if let needsAttentionHabit = getHabitNeedingAttention() {
                        InsightCard(
                            type: .warning,
                            title: "Needs attention",
                            description: "\(needsAttentionHabit.name) - Consider adjusting your approach"
                        )
                    }
                    
                    // Overall habit status
                    let activeCount = getActiveHabitsCount()
                    let totalCount = filteredHabitsByType.count
                    
                    if totalCount > 0 {
                        InsightCard(
                            type: .info,
                            title: "Habit Status",
                            description: "\(activeCount) of \(totalCount) habits are currently active"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Habit Statistics
    private var habitStatistics: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Habit Statistics")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.text06)
                    .help("Overview of your habit statistics")
            }
            
            if filteredHabitsByType.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    message: "No \(selectedHabitType == .formation ? "building" : "breaking") habit data to display"
                )
            } else {
                HStack(spacing: 16) {
                    // Total Habits
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(filteredHabitsByType.count)")
                            .font(.appTitleLargeEmphasised)
                            .foregroundColor(.text01)
                        Text("Total \(selectedHabitType == .formation ? "Building" : "Breaking") Habits")
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.surface)
                    .cornerRadius(12)
                    
                    // Active Habits
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(getActiveHabitsCount())")
                            .font(.appTitleLargeEmphasised)
                            .foregroundColor(.text01)
                        Text("Active \(selectedHabitType == .formation ? "Building" : "Breaking") Habits")
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.surface)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getActiveHabitsCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return filteredHabitsByType.filter { habit in
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return today >= startDate && today <= endDate
        }.count
    }
    
    private func getBestHabit() -> Habit? {
        // For now, return the first habit as "best" - this could be enhanced with actual performance data
        return filteredHabitsByType.first
    }
    
    private func getHabitNeedingAttention() -> Habit? {
        // For now, return the second habit as needing attention - this could be enhanced with actual performance data
        return filteredHabitsByType.count > 1 ? filteredHabitsByType[1] : nil
    }
    
    // MARK: - Habit Progress Cards
    private var habitProgressCards: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Habit Progress")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.text06)
                    .help("Individual habit progress and goal achievement")
            }
            
            if filteredHabitsByType.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "No \(selectedHabitType == .formation ? "building" : "breaking") habits to show progress for"
                )
            } else {
                VStack(spacing: 16) {
                    // Show progress cards for each habit (filtered by selected type)
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
        // Create a simple HabitProgress for demonstration
        // In a real app, this would calculate actual progress data
        let completionPercentage = Double.random(in: 20...90) // Placeholder
        let trend: TrendDirection = [.improving, .stable, .declining].randomElement() ?? .stable
        
        return HabitProgress(
            habit: habit,
            period: selectedPeriod,
            completionPercentage: completionPercentage,
            trend: trend
        )
    }
    
    private func createHabitGoal(for habit: Habit) -> HabitGoal? {
        // Create a simple HabitGoal for demonstration
        // In a real app, this would parse actual goal data
        guard let goal = parseGoal(from: habit.goal) else { return nil }
        
        let currentAverage = Double.random(in: 1...10) // Placeholder
        let goalHitRate = Double.random(in: 0.3...1.0) // Placeholder
        
        return HabitGoal(
            habit: habit,
            goal: goal,
            currentAverage: currentAverage,
            goalHitRate: goalHitRate
        )
    }
    
    private func parseGoal(from goalString: String) -> Goal? {
        // Parse goal strings like "5 sessions/week" or "2L/day"
        let components = goalString.lowercased().components(separatedBy: " ")
        guard components.count >= 2,
              let amount = Double(components[0]),
              let unit = components.last else { return nil }
        
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
    
    private var periodStats: [(String, TimePeriod?)] {
        return [
            ("Today", .today),
            ("Week", .week),
            ("Year", .year),
            ("All", .all)
        ]
    }
    
    // MARK: - Computed Properties
    private var filteredHabitsByType: [Habit] {
        habits.filter { $0.habitType == selectedHabitType }
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
                // Top Level Tabs: Building | Breaking
                habitTypeSelector
                
                // Sub Tabs: Today | Weekly | Yearly
                periodSelector
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Habit Insights
                        habitInsights
                        
                        // Habit Statistics
                        habitStatistics
                        
                        // Individual Habit Progress
                        habitProgressCards
                        
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

// MARK: - AllHabitsView
struct AllHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatsTab: Int = 0
    @State private var selectedHabit: Habit? = nil
    let habits: [Habit]
    let onDeleteHabit: (Habit) -> Void
    let onEditHabit: (Habit) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    init(habits: [Habit], onDeleteHabit: @escaping (Habit) -> Void, onEditHabit: @escaping (Habit) -> Void, onUpdateHabit: ((Habit) -> Void)? = nil) {
        self.habits = habits
        self.onDeleteHabit = onDeleteHabit
        self.onEditHabit = onEditHabit
        self.onUpdateHabit = onUpdateHabit
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fixed Header with Tabs
                VStack(spacing: 0) {
                    // Stats Row (Active/Inactive tabs)
                    statsRow
                        .padding(.horizontal, 0)
                        .padding(.top, 16)
                        .background(.white)
                }
                
                // Scrollable Habit List
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
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
                            // Habit List
                            VStack(alignment: .leading, spacing: 16) {
                                Text("All Habits")
                                    .font(.appTitleLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(.text01)
                                    .padding(.horizontal, 20)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(habitsWithProgress) { habit in
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
    
    private var habitsWithProgress: [Habit] {
        return filteredHabits
    }
    
    private var habitsWithGoals: [Habit] {
        return filteredHabits
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
