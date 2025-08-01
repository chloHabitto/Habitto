import SwiftUI

struct ProgressTabView: View {
    @State private var selectedHabitType: HabitType = .formation
    @State private var selectedPeriod: TimePeriod = .week
    let habits: [Habit]
    
    var body: some View {
        WhiteSheetContainer(
            title: "Progress"
        ) {
            VStack(spacing: 0) {
                // Top Level Tabs: Formation | Breaking
                habitTypeSelector
                
                // Sub Tabs: Today | Weekly | Yearly
                periodSelector
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Performance Overview (adapts to filters)
                        performanceOverview
                        
                        // Insight Highlights (context-aware)
                        insightHighlights
                        
                        // Goal Achievement Analysis
                        goalAchievementAnalysis
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
    }
    
    // MARK: - Habit Type Selector
    private var habitTypeSelector: some View {
        habitTypeTabBar
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        periodTabBar
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var habitTypeTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<habitTypeStats.count, id: \.self) { idx in
                habitTypeTabButton(for: idx)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    @ViewBuilder
    private var periodTabBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<periodStats.count, id: \.self) { idx in
                periodTabButton(for: idx)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var habitTypeStats: [(String, HabitType?)] {
        return [
            ("Formation", .formation),
            ("Breaking", .breaking)
        ]
    }
    
    private var periodStats: [(String, TimePeriod?)] {
        return [
            ("Today", .today),
            ("Week", .week),
            ("Year", .year)
        ]
    }
    
    @ViewBuilder
    private func habitTypeTabButton(for idx: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                if let habitType = habitTypeStats[idx].1 {
                    selectedHabitType = habitType
                }
            }) {
                Text(habitTypeStats[idx].0)
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(selectedHabitType == habitTypeStats[idx].1 ? .text03 : .text04)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            
            // Bottom stroke for each tab
            Rectangle()
                .fill(selectedHabitType == habitTypeStats[idx].1 ? .text03 : .divider)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedHabitType)
        }
    }
    
    @ViewBuilder
    private func periodTabButton(for idx: Int) -> some View {
        Button(action: {
            if let period = periodStats[idx].1 {
                selectedPeriod = period
            }
        }) {
            Text(periodStats[idx].0)
                .font(.appBodyMedium)
                .fontWeight(.medium)
                .foregroundColor(selectedPeriod == periodStats[idx].1 ? .onPrimary : .text04)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(selectedPeriod == periodStats[idx].1 ? .primary : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(selectedPeriod == periodStats[idx].1 ? .clear : .outline, lineWidth: 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
    }
    
    // MARK: - Performance Overview
    private var performanceOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(performanceOverviewTitle)
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Text("\(habitsWithProgress.count) habit\(habitsWithProgress.count == 1 ? "" : "s")")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.surface)
                    )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.outline, lineWidth: 1)
                )
            }
            
            if habitsWithProgress.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: selectedHabitType == .formation ? "plus.circle" : "minus.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.text04)
                    
                    Text(emptyStateMessage)
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
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
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(habitsWithProgress.sorted { $0.completionPercentage > $1.completionPercentage }) { habitProgress in
                        HabitProgressCard(habitProgress: habitProgress)
                    }
                }
            }
        }
    }
    
    private var performanceOverviewTitle: String {
        switch selectedHabitType {
        case .formation:
            return "Top-Performing Building Habits"
        case .breaking:
            return "Reduction Progress"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedHabitType {
        case .formation:
            return "No habit formation data for this period"
        case .breaking:
            return "No habit breaking data for this period"
        }
    }
    
    // MARK: - Insight Highlights
    private var insightHighlights: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Insight Highlights")
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.warning)
            }
            
            VStack(spacing: 16) {
                // Context-aware insights based on selected habit type
                if selectedHabitType == .formation {
                    formationInsights
                } else {
                    breakingInsights
                }
                
                // Overall progress insight
                let improvingCount = habitsWithProgress.filter { $0.trend == .improving }.count
                let needsAttentionCount = habitsWithProgress.filter { $0.trend == .declining }.count
                
                if improvingCount > 0 || needsAttentionCount > 0 {
                    InsightCard(
                        type: .info,
                        title: "Overall Progress",
                        description: "\(improvingCount) habits improving, \(needsAttentionCount) need attention"
                    )
                }
                
                if let suggestion = actionableSuggestion {
                    InsightCard(
                        type: .tip,
                        title: "Suggestion",
                        description: suggestion
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var formationInsights: some View {
        if let bestHabit = habitsWithProgress.max(by: { $0.completionPercentage < $1.completionPercentage }) {
            InsightCard(
                type: .success,
                title: "Your best habit this \(selectedPeriod.displayName.lowercased())",
                description: "\(bestHabit.habit.name) (\(Int(bestHabit.completionPercentage))% completion)"
            )
        }
        
        if let worstHabit = habitsWithProgress.min(by: { $0.completionPercentage < $1.completionPercentage }) {
            InsightCard(
                type: .warning,
                title: "Your lowest-performing habit",
                description: "\(worstHabit.habit.name) (\(Int(worstHabit.completionPercentage))% completion"
            )
        }
    }
    
    @ViewBuilder
    private var breakingInsights: some View {
        if let bestHabit = habitsWithProgress.max(by: { $0.completionPercentage < $1.completionPercentage }) {
            InsightCard(
                type: .success,
                title: "Least slip-ups this \(selectedPeriod.displayName.lowercased())",
                description: "\(bestHabit.habit.name) (\(Int(bestHabit.completionPercentage))% reduction success"
            )
        }
        
        if let worstHabit = habitsWithProgress.min(by: { $0.completionPercentage < $1.completionPercentage }) {
            InsightCard(
                type: .warning,
                title: "Needs more reduction",
                description: "\(worstHabit.habit.name) (\(Int(worstHabit.completionPercentage))% reduction"
            )
        }
        
        if !habitsWithProgress.isEmpty {
            let averageReduction = habitsWithProgress.map { $0.completionPercentage }.reduce(0, +) / Double(habitsWithProgress.count)
            InsightCard(
                type: .tip,
                title: "Reduction Summary",
                description: "Average reduction success: \(Int(averageReduction))% across \(habitsWithProgress.count) habit(s)"
            )
        }
    }
    
    // MARK: - Goal Achievement Analysis
    private var goalAchievementAnalysis: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(goalAchievementTitle)
                    .font(.appTitleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Image(systemName: "target")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            if habitsWithGoals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(.text04)
                    
                    Text(goalEmptyStateMessage)
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
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
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(habitsWithGoals) { habitGoal in
                        GoalAchievementCard(habitGoal: habitGoal)
                    }
                }
            }
        }
    }
    
    private var goalAchievementTitle: String {
        switch selectedHabitType {
        case .formation:
            return "Goal Achievement"
        case .breaking:
            return "Reduction Analysis"
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
    
    // MARK: - Computed Properties
    private var filteredHabits: [Habit] {
        habits.filter { $0.habitType == selectedHabitType }
    }
    
    private var habitsWithProgress: [HabitProgress] {
        filteredHabits.map { habit in
            HabitProgress(
                habit: habit,
                period: selectedPeriod,
                completionPercentage: calculateCompletionPercentage(for: habit, period: selectedPeriod),
                trend: calculateTrend(for: habit, period: selectedPeriod)
            )
        }
    }
    
    private var habitsWithGoals: [HabitGoal] {
        filteredHabits.compactMap { habit in
            guard let goal = parseGoal(from: habit.goal) else { return nil }
            return HabitGoal(
                habit: habit,
                goal: goal,
                currentAverage: calculateCurrentAverage(for: habit, period: selectedPeriod),
                goalHitRate: calculateGoalHitRate(for: habit, period: selectedPeriod)
            )
        }
    }
    
    private var bestHabit: HabitProgress? {
        habitsWithProgress.max { $0.completionPercentage < $1.completionPercentage }
    }
    
    private var worstHabit: HabitProgress? {
        habitsWithProgress.min { $0.completionPercentage < $1.completionPercentage }
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
            // For habit formation, use the original completion percentage
            let dates = period.dates
            let completedDays = dates.filter { habit.isCompleted(for: $0) }.count
            return dates.isEmpty ? 0 : Double(completedDays) / Double(dates.count) * 100
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
            // For habit formation, use the original calculation
            previousPercentage = previousPeriod.isEmpty ? 0 : Double(previousPeriod.filter { habit.isCompleted(for: $0) }.count) / Double(previousPeriod.count) * 100
        }
        
        if currentPercentage > previousPercentage + 5 {
            return .improving
        } else if currentPercentage < previousPercentage - 5 {
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
        let completedDays = dates.filter { habit.isCompleted(for: $0) }.count
        return dates.isEmpty ? 0 : Double(completedDays)
    }
    
    private func calculateGoalHitRate(for habit: Habit, period: TimePeriod) -> Double {
        guard let goal = parseGoal(from: habit.goal) else { return 0 }
        
        let currentAverage = calculateCurrentAverage(for: habit, period: period)
        let targetAmount = goal.amount * Double(period.weeksCount)
        
        return targetAmount > 0 ? min(currentAverage / targetAmount, 1.0) : 0
    }
}

// MARK: - Supporting Types
enum TimePeriod: CaseIterable {
    case today, week, year
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .year: return "Year"
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
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            var dates: [Date] = []
            var currentDate = yearStart
            let yearEnd = calendar.dateInterval(of: .year, for: today)?.end ?? today
            while currentDate < yearEnd {
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
        }
    }
    
    var weeksCount: Int {
        switch self {
        case .today: return 0
        case .week: return 1
        case .year: return 52
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
            // For habit formation, use completion-focused status
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
    case workingWell, needsAttention, atRisk
    case excellentReduction, goodReduction, moderateReduction, needsMoreReduction
    
    var label: String {
        switch self {
        case .workingWell: return "Working Well"
        case .needsAttention: return "Needs Attention"
        case .atRisk: return "At Risk"
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

#Preview {
    ProgressTabView(habits: [])
} 
