import SwiftUI

struct ProgressTabView: View {
    @State private var selectedHabitType: HabitType = .formation
    @State private var selectedPeriod: TimePeriod = .today
    let habits: [Habit]
    
    // Performance optimization: Cache expensive computations
    @State private var cachedFilteredHabits: [Habit] = []
    @State private var cachedHabitsWithProgress: [HabitProgress] = []
    @State private var cachedHabitsWithGoals: [HabitGoal] = []
    @State private var lastCacheUpdate: (HabitType, TimePeriod) = (.formation, .today)
    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Today's Progress Computed Properties
    private var todaysActualCompletionPercentage: Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let today = Date()
        let totalProgress = habits.reduce(0.0) { sum, habit in
            // Get today's progress count
            let todayProgress = habit.getProgress(for: today)
            
            // Parse the goal to get target amount
            if let goal = parseGoal(from: habit.goal) {
                // Calculate completion percentage for this habit (capped at 100%)
                let habitCompletion = min(Double(todayProgress) / goal.amount, 1.0)
                return sum + habitCompletion
            } else {
                // Fallback: if no goal, treat as binary completion
                return sum + (todayProgress > 0 ? 1.0 : 0.0)
            }
        }
        
        return totalProgress / Double(habits.count)
    }
    
    // MARK: - Independent Today's Progress Container
    private var independentTodaysProgressContainer: some View {
        Group {
            if !habits.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 20) {
                        // Left side: Text content
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Goal Progress")
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.onPrimaryContainer)
                            
                            Text("Great progress! Keep building your habits!")
                                .font(.appBodySmall)
                                .foregroundColor(.primaryFocus)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Right side: Circular progress ring
                        ZStack {
                            // Background circle (unfilled part)
                            Circle()
                                .stroke(Color.primaryContainer, lineWidth: 8)
                                .frame(width: 52, height: 52)
                            
                            // Progress circle (filled part) - showing actual completion percentage
                            Circle()
                                .trim(from: 0, to: todaysActualCompletionPercentage)
                                .stroke(
                                    Color.primary,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: todaysActualCompletionPercentage)
                            
                            // Percentage text
                            VStack(spacing: 2) {
                                Text("\(Int(todaysActualCompletionPercentage * 100))%")
                                    .font(.appLabelMediumEmphasised)
                                    .foregroundColor(.primaryFocus)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.surfaceDim)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    var body: some View {
        WhiteSheetContainer(
            title: "Progress"
        ) {
            VStack(spacing: 0) {
                // Top Level Tabs: Building | Breaking
                // habitTypeSelector
                
                // Sub Tabs: Today | Weekly | Yearly
                // periodSelector
                
                // Independent Today's Progress Container
                independentTodaysProgressContainer
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Today's Progress Section (only shown when Today is selected)
                        // todaysProgressSection
                        
                        // Progress Overview Charts
                        // progressOverviewCharts
                        
                        // Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .onChange(of: selectedHabitType) { _, _ in
            updateCacheIfNeeded()
        }
        .onChange(of: selectedPeriod) { _, _ in
            updateCacheIfNeeded()
        }
        .onAppear {
            updateCacheIfNeeded()
        }
    }
    
    // Performance optimization: Update cache only when needed
    private func updateCacheIfNeeded() {
        let currentState = (selectedHabitType, selectedPeriod)
        
        // Only update cache if state actually changed
        if lastCacheUpdate != currentState {
            cachedFilteredHabits = habits.filter { $0.habitType == selectedHabitType }
            cachedHabitsWithProgress = calculateHabitsWithProgress()
            cachedHabitsWithGoals = calculateHabitsWithGoals()
            lastCacheUpdate = currentState
        }
    }
    
    // Performance optimization: Pre-calculate expensive operations
    private func calculateHabitsWithProgress() -> [HabitProgress] {
        return cachedFilteredHabits.map { habit in
            HabitProgress(
                habit: habit,
                period: selectedPeriod,
                completionPercentage: calculateCompletionPercentage(for: habit, period: selectedPeriod),
                trend: calculateTrend(for: habit, period: selectedPeriod)
            )
        }
    }
    
    private func calculateHabitsWithGoals() -> [HabitGoal] {
        return cachedFilteredHabits.compactMap { habit in
            guard let goal = parseGoal(from: habit.goal) else { return nil }
            
            let currentAverage = calculateCurrentAverage(for: habit, period: selectedPeriod)
            let targetAmount = goal.amount * Double(selectedPeriod.weeksCount)
            let goalHitRate = targetAmount > 0 ? min(currentAverage / targetAmount, 1.0) : 0
            
            return HabitGoal(
                habit: habit,
                goal: goal,
                currentAverage: currentAverage,
                goalHitRate: goalHitRate
            )
        }
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
    
    // MARK: - Chart Components
    private var overallProgressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            // Placeholder for progress chart
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                        Text("Progress Chart")
                            .font(.appBodyMedium)
                            .foregroundColor(.text05)
                    }
                )
        }
    }
    
    private var successRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Success Rate")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            // Placeholder for success rate chart
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .frame(height: 150)
                .overlay(
                    VStack {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                        Text("Success Rate Chart")
                            .font(.appBodyMedium)
                            .foregroundColor(.text05)
                    }
                )
        }
    }
    
    // MARK: - Progress Overview Charts
    private var progressOverviewCharts: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Progress Overview")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.text06)
                    .help("Shows your overall progress trends for this period")
            }
            
            if cachedHabitsWithProgress.isEmpty {
                EmptyStateView(
                    icon: selectedHabitType == .formation ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    message: "No progress data for this period"
                )
            } else {
                VStack(spacing: 16) {
                    // Overall Progress Chart
                    overallProgressChart
                    
                    // Success Rate Chart
                    successRateChart
                }
            }
        }
    }
    
    // MARK: - Today's Progress Component
    private var todaysProgressSection: some View {
        Group {
            if !cachedHabitsWithProgress.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 20) {
                        // Left side: Text content
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Goal Progress")
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.onPrimaryContainer)
                            
                            Text(encouragingText)
                                .font(.appBodySmall)
                                .foregroundColor(.primaryFocus)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        // Right side: Circular progress ring
                        ZStack {
                            // Background circle (unfilled part)
                            Circle()
                                .stroke(Color.primaryContainer, lineWidth: 8)
                                .frame(width: 40, height: 40)
                            
                            // Progress circle (filled part)
                            Circle()
                                .trim(from: 0, to: todaysProgressPercentage / 100)
                                .stroke(
                                    Color.primary,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: todaysProgressPercentage)
                            
                            // Percentage text
                            VStack(spacing: 2) {
                                Text("\(Int(todaysProgressPercentage))%")
                                    .font(.appLabelMediumEmphasised)
                                    .foregroundColor(.primaryFocus)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.surfaceDim)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Today's Progress Computed Properties
    private var todaysProgressPercentage: Double {
        guard !cachedHabitsWithProgress.isEmpty else { return 0 }
        
        let totalProgress = cachedHabitsWithProgress.reduce(0.0) { sum, habitProgress in
            sum + habitProgress.completionPercentage
        }
        
        return totalProgress / Double(cachedHabitsWithProgress.count)
    }
    
    private var encouragingText: String {
        let percentage = todaysProgressPercentage
        
        if percentage >= 80 {
            return "Excellent progress! Keep it up!"
        } else if percentage >= 50 {
            return "Good progress! You're on track!"
        } else if percentage >= 20 {
            return "Getting started! Every step counts!"
        } else {
            return "New day, new opportunities!"
        }
    }
    
    private var performanceOverviewTitle: String {
        switch selectedHabitType {
        case .formation:
            switch selectedPeriod {
            case .today:
                return "Today's Building Habits"
            case .week:
                return "This Week's Building Habits"
            case .year:
                return "This Year's Building Habits"
            case .all:
                return "All-Time Building Habits"
            }
        case .breaking:
            switch selectedPeriod {
            case .today:
                return "Today's Reduction Progress"
            case .week:
                return "This Week's Reduction Progress"
            case .year:
                return "This Year's Reduction Progress"
            case .all:
                return "All-Time Reduction Progress"
            }
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedHabitType {
        case .formation:
            return "No habit building data for this period"
        case .breaking:
            return "No habit breaking data for this period"
        }
    }
    

    

    

    
    private var goalAchievementTitle: String {
        switch selectedHabitType {
        case .formation:
            switch selectedPeriod {
            case .today:
                return "Today's Goal Achievement"
            case .week:
                return "This Week's Goal Achievement"
            case .year:
                return "This Year's Goal Achievement"
            case .all:
                return "All-Time Goal Achievement"
            }
        case .breaking:
            switch selectedPeriod {
            case .today:
                return "Today's Reduction Analysis"
            case .week:
                return "This Week's Reduction Analysis"
            case .year:
                return "This Year's Reduction Analysis"
            case .all:
                return "All-Time Reduction Analysis"
            }
        }
    }
    
    private var goalEmptyStateMessage: String {
        switch selectedHabitType {
        case .formation:
            return "No goal data for this period"
        case .breaking:
            return "No reduction data for this period"
        }
    }
    
    private var insightEmptyStateMessage: String {
        switch selectedHabitType {
        case .formation:
            return "No habit building data for this period"
        case .breaking:
            return "No habit breaking data for this period"
        }
    }
    
    // MARK: - Computed Properties
    private var filteredHabits: [Habit] {
        habits.filter { $0.habitType == selectedHabitType }
    }
    
    private var habitsWithProgress: [HabitProgress] {
        cachedHabitsWithProgress
    }
    
    private var habitsWithGoals: [HabitGoal] {
        cachedHabitsWithGoals
    }
    
    private var bestHabit: HabitProgress? {
        cachedHabitsWithProgress.max { $0.completionPercentage < $1.completionPercentage }
    }
    
    private var worstHabit: HabitProgress? {
        cachedHabitsWithProgress.min { $0.completionPercentage < $1.completionPercentage }
    }
    
    private var actionableSuggestion: String? {
        guard let worstHabit = worstHabit else { return nil }
        
        switch selectedHabitType {
        case .formation:
            if worstHabit.completionPercentage < 30 {
                return "Try adjusting reminder time or lowering the goal to build consistency"
            } else if worstHabit.completionPercentage < 60 {
                return "Consider breaking down the habit into smaller, more manageable steps"
            } else {
                return "You're doing great! Keep up the momentum"
            }
        case .breaking:
            if worstHabit.completionPercentage < 30 {
                return "Try setting smaller reduction targets to build momentum"
            } else if worstHabit.completionPercentage < 60 {
                return "Focus on one habit at a time - gradual reduction is sustainable"
            } else {
                return "Keep tracking your usage - awareness is the first step to change"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateCompletionPercentage(for habit: Habit, period: TimePeriod) -> Double {
        if habit.habitType == .breaking {
            // For habit breaking, calculate success rate based on reduction progress
            return calculateHabitBreakingSuccessRate(for: habit, period: period)
        } else {
            // For habit building, use the original completion percentage
            let dates = period.dates
            let activeDates = dates.filter { date in
                // Only consider dates when the habit was active (after start date)
                let startDate = Calendar.current.startOfDay(for: habit.startDate)
                let currentDate = Calendar.current.startOfDay(for: date)
                return currentDate >= startDate
            }
            
            let completedDays = activeDates.filter { habit.isCompleted(for: $0) }.count
            return activeDates.isEmpty ? 0 : Double(completedDays) / Double(activeDates.count) * 100
        }
    }
    
    private func calculateHabitBreakingSuccessRate(for habit: Habit, period: TimePeriod) -> Double {
        let dates = period.dates
        guard !dates.isEmpty else { return 0 }
        
        var totalSuccessRate: Double = 0
        var validDays = 0
        
        for date in dates {
            let successRate = habit.calculateSuccessRate(for: date)
            if successRate >= 0 { // Only count days with valid data
                totalSuccessRate += successRate
                validDays += 1
            }
        }
        
        return validDays > 0 ? totalSuccessRate / Double(validDays) : 0
    }
    
    private func calculateTrend(for habit: Habit, period: TimePeriod) -> TrendDirection {
        let previousPeriod = period.previousPeriodDates
        
        let currentPercentage = calculateCompletionPercentage(for: habit, period: period)
        let previousPercentage: Double
        
        if habit.habitType == .breaking {
            // For habit breaking, calculate previous period success rate
            var totalSuccessRate: Double = 0
            var validDays = 0
            
            for date in previousPeriod {
                let successRate = habit.calculateSuccessRate(for: date)
                if successRate >= 0 {
                    totalSuccessRate += successRate
                    validDays += 1
                }
            }
            previousPercentage = validDays > 0 ? totalSuccessRate / Double(validDays) : 0
        } else {
            // For habit building, use the original calculation
            let activePreviousDates = previousPeriod.filter { date in
                // Only consider dates when the habit was active (after start date)
                let startDate = Calendar.current.startOfDay(for: habit.startDate)
                let currentDate = Calendar.current.startOfDay(for: date)
                return currentDate >= startDate
            }
            previousPercentage = activePreviousDates.isEmpty ? 0 : Double(activePreviousDates.filter { habit.isCompleted(for: $0) }.count) / Double(activePreviousDates.count) * 100
        }
        
        let difference = currentPercentage - previousPercentage
        
        if difference > 5 {
            return .improving
        } else if difference < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    

    
    private func parseGoal(from goalString: String) -> Goal? {
        // Parse goal strings like "5 sessions/week" or "2L/day"
        let components = goalString.lowercased().components(separatedBy: " ")
        guard components.count >= 2,
              let amount = Double(components[0]),
              let unit = components.last else { return nil }
        
        return Goal(amount: amount, unit: unit)
    }
    
    private func calculateCurrentAverage(for habit: Habit, period: TimePeriod) -> Double {
        let dates = period.dates
        let activeDates = dates.filter { date in
            // Only consider dates when the habit was active (after start date)
            let startDate = Calendar.current.startOfDay(for: habit.startDate)
            let currentDate = Calendar.current.startOfDay(for: date)
            return currentDate >= startDate
        }
        let completedDays = activeDates.filter { habit.isCompleted(for: $0) }.count
        return activeDates.isEmpty ? 0 : Double(completedDays)
    }
    
    private func calculateGoalHitRate(for habit: Habit, period: TimePeriod) -> Double {
        guard let goal = parseGoal(from: habit.goal) else { return 0 }
        
        let currentAverage = calculateCurrentAverage(for: habit, period: period)
        let targetAmount = goal.amount * Double(period.weeksCount)
        
        return targetAmount > 0 ? min(currentAverage / targetAmount, 1.0) : 0
    }
    
    // Performance optimization: Clear cache when needed
    private func clearCalculationCache() {
        // Cache clearing is now handled by the state variables
    }
    
    // MARK: - Dynamic Insight Helpers
    
    private func getBuildingInsightTitle(for period: TimePeriod) -> String {
        switch period {
        case .today:
            return "Your best habit today"
        case .week:
            return "Your best habit this week"
        case .year:
            return "Your best habit this year"
        case .all:
            return "Your best habit overall"
        }
    }
    
    private func getBuildingInsightDescription(for habit: HabitProgress, period: TimePeriod) -> String {
        switch period {
        case .today:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% completion)"
        case .week:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% completion)"
        case .year:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% completion)"
        case .all:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% completion)"
        }
    }
    
    private func getBreakingInsightTitle(for period: TimePeriod) -> String {
        switch period {
        case .today:
            return "Best reduction today"
        case .week:
            return "You avoided sugary drinks 6/7 days this week"
        case .year:
            return "Best reduction this year"
        case .all:
            return "Best reduction overall"
        }
    }
    
    private func getBreakingInsightDescription(for habit: HabitProgress, period: TimePeriod) -> String {
        switch period {
        case .today:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% reduction success)"
        case .week:
            // For week, show days avoided out of 7
            let daysAvoided = Int((habit.completionPercentage / 100.0) * 7.0)
            return "\(habit.habit.name) (\(daysAvoided)/7 days avoided)"
        case .year:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% reduction success)"
        case .all:
            return "\(habit.habit.name) (\(Int(habit.completionPercentage))% reduction success)"
        }
    }
}

// MARK: - Supporting Types
enum TimePeriod: CaseIterable {
    case today, week, year, all
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .year: return "Year"
        case .all: return "All"
        }
    }
    
    var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .today:
            return [calendar.startOfDay(for: today)]
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        case .year:
            // For "Year" period, return all dates from the start of the year to today
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            var dates: [Date] = []
            var currentDate = yearStart
            while currentDate <= today {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .all:
            // For "All" period, return all dates from the start of the year to today
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            var dates: [Date] = []
            var currentDate = yearStart
            while currentDate <= today {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    var previousPeriodDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .today:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return [calendar.startOfDay(for: yesterday)]
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: previousWeekStart) }
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: yearStart) ?? yearStart
            var dates: [Date] = []
            var currentDate = previousYearStart
            let previousYearEnd = calendar.dateInterval(of: .year, for: previousYearStart)?.end ?? previousYearStart
            while currentDate < previousYearEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .all:
            // For "All" period, return previous year's dates
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: yearStart) ?? yearStart
            var dates: [Date] = []
            var currentDate = previousYearStart
            let previousYearEnd = calendar.dateInterval(of: .year, for: previousYearStart)?.end ?? previousYearStart
            while currentDate < previousYearEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    var weeksCount: Int {
        switch self {
        case .today: return 0
        case .week: return 1
        case .year: return 52
        case .all: return 52
        }
    }
}

enum TrendDirection {
    case improving, stable, declining
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .success
        case .stable: return .warning
        case .declining: return .error
        }
    }
}

struct HabitProgress: Identifiable {
    let id = UUID()
    let habit: Habit
    let period: TimePeriod
    let completionPercentage: Double
    let trend: TrendDirection
    
    var status: HabitStatus {
        // Check if the habit has any completion history at all
        let hasAnyCompletionHistory = !habit.completionHistory.isEmpty
        
        // Calculate days since habit creation
        let calendar = Calendar.current
        let today = Date()
        let daysSinceCreation = calendar.dateComponents([.day], from: habit.startDate, to: today).day ?? 0
        
        // If habit is too new (less than 3 days since creation) or has no completion history yet, show "New Habit" status
        if daysSinceCreation < 3 || !hasAnyCompletionHistory {
            return .newHabit
        }
        
        if habit.habitType == .breaking {
            // For habit breaking, use reduction-focused status
            if completionPercentage >= 80 {
                return .excellentReduction
            } else if completionPercentage >= 50 {
                return .goodReduction
            } else if completionPercentage >= 20 {
                return .moderateReduction
            } else {
                return .needsMoreReduction
            }
        } else {
            // For habit building, use completion-focused status
            if completionPercentage >= 80 {
                return .workingWell
            } else if completionPercentage >= 50 {
                return .needsAttention
            } else {
                return .atRisk
            }
        }
    }
}

enum HabitStatus {
    case workingWell, needsAttention, atRisk, newHabit
    case excellentReduction, goodReduction, moderateReduction, needsMoreReduction
    
    var label: String {
        switch self {
        case .workingWell: return "Working Well"
        case .needsAttention: return "Needs Attention"
        case .atRisk: return "At Risk"
        case .newHabit: return "New Habit"
        case .excellentReduction: return "Excellent Reduction"
        case .goodReduction: return "Good Reduction"
        case .moderateReduction: return "Moderate Reduction"
        case .needsMoreReduction: return "Needs More Reduction"
        }
    }
    
    var color: Color {
        switch self {
        case .workingWell: return .success
        case .needsAttention: return .warning
        case .atRisk: return .error
        case .newHabit: return .primary
        case .excellentReduction: return .success
        case .goodReduction: return .success
        case .moderateReduction: return .warning
        case .needsMoreReduction: return .error
        }
    }
    
    var icon: String {
        switch self {
        case .workingWell: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .atRisk: return "xmark.circle.fill"
        case .newHabit: return "sparkles"
        case .excellentReduction: return "arrow.down.circle.fill"
        case .goodReduction: return "arrow.down.circle.fill"
        case .moderateReduction: return "arrow.down.triangle.fill"
        case .needsMoreReduction: return "arrow.up.triangle.fill"
        }
    }
}

struct Goal {
    let amount: Double
    let unit: String
}

struct HabitGoal: Identifiable {
    let id = UUID()
    let habit: Habit
    let goal: Goal
    let currentAverage: Double
    let goalHitRate: Double
}

enum InsightType {
    case success, warning, info, tip
    
    var color: Color {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .info: return .primary
        case .tip: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        }
    }
}

// MARK: - EmptyStateView
struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.primaryContainer)
            
            Text(message)
                .font(.appBodyLarge)
                .foregroundColor(.text05)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.outline, lineWidth: 1)
        )
    }
}

#Preview {
    ProgressTabView(habits: [])
} 
