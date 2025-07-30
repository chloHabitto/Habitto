import SwiftUI

struct ProgressTabView: View {
    @State private var selectedPeriod: TimePeriod = .week
    @State private var habits: [Habit] = []
    
    var body: some View {
        WhiteSheetContainer(
            title: "Progress"
        ) {
            VStack(spacing: 0) {
                // Period Selector
                periodSelector
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Performance Overview
                        performanceOverview
                        
                        // Insight Highlights
                        insightHighlights
                        
                        // Goal Achievement Analysis
                        goalAchievementAnalysis
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            loadHabits()
        }
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        periodTabBar
            .padding(.horizontal, 0)
            .padding(.top, 2)
            .padding(.bottom, 0)
    }
    
    @ViewBuilder
    private var periodTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<periodStats.count, id: \.self) { idx in
                periodTabButton(for: idx)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    private var periodStats: [(String, TimePeriod?)] {
        return [
            ("Week", .week),
            ("Month", .month),
            ("Custom", .custom),
            ("", nil) // Dummy tab - exactly like Home screen
        ]
    }
    
    @ViewBuilder
    private func periodTabButton(for idx: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                if let period = periodStats[idx].1 {
                    selectedPeriod = period
                }
            }) {
                HStack(spacing: 4) {
                    Text(periodStats[idx].0)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedPeriod == periodStats[idx].1 ? .text03 : .text04)
                        .opacity(idx == 3 ? 0 : 1) // Make dummy tab text invisible
                    Text("0") // Add a number like the other screens
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedPeriod == periodStats[idx].1 ? .text03 : .text04)
                        .opacity(idx == 3 ? 0 : 1) // Make dummy tab text invisible
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: idx == 3 ? .infinity : nil) // Only expand the dummy tab (index 3)
            .disabled(idx == 3) // Disable clicking for dummy tab
            
            // Bottom stroke for each tab
            Rectangle()
                .fill(selectedPeriod == periodStats[idx].1 ? .text03 : .divider)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
        }
    }
    
    // MARK: - Performance Overview
    private var performanceOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Overview")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            LazyVStack(spacing: 12) {
                ForEach(habitsWithProgress.sorted { $0.completionPercentage > $1.completionPercentage }) { habitProgress in
                    HabitProgressCard(habitProgress: habitProgress)
                }
            }
        }
    }
    
    // MARK: - Insight Highlights
    private var insightHighlights: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insight Highlights")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            VStack(spacing: 12) {
                if let bestHabit = bestHabit {
                    InsightCard(
                        type: .success,
                        title: "Your best habit this \(selectedPeriod.displayName.lowercased())",
                        description: "\(bestHabit.habit.name) (\(Int(bestHabit.completionPercentage))% completion)"
                    )
                }
                
                if let worstHabit = worstHabit {
                    InsightCard(
                        type: .warning,
                        title: "Your lowest-performing habit",
                        description: "\(worstHabit.habit.name) (\(Int(worstHabit.completionPercentage))%)"
                    )
                }
                
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
    
    // MARK: - Goal Achievement Analysis
    private var goalAchievementAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Achievement")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            LazyVStack(spacing: 12) {
                ForEach(habitsWithGoals) { habitGoal in
                    GoalAchievementCard(habitGoal: habitGoal)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var habitsWithProgress: [HabitProgress] {
        habits.map { habit in
            HabitProgress(
                habit: habit,
                period: selectedPeriod,
                completionPercentage: calculateCompletionPercentage(for: habit, period: selectedPeriod),
                trend: calculateTrend(for: habit, period: selectedPeriod)
            )
        }
    }
    
    private var habitsWithGoals: [HabitGoal] {
        habits.compactMap { habit in
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
        
        if worstHabit.completionPercentage < 30 {
            return "Try adjusting reminder time or lowering the goal to build consistency"
        } else if worstHabit.completionPercentage < 60 {
            return "Consider breaking down the habit into smaller, more manageable steps"
        } else {
            return "You're doing great! Keep up the momentum"
        }
    }
    
    // MARK: - Helper Methods
    private func loadHabits() {
        habits = Habit.loadHabits()
    }
    
    private func calculateCompletionPercentage(for habit: Habit, period: TimePeriod) -> Double {
        let dates = period.dates
        let completedDays = dates.filter { habit.isCompleted(for: $0) }.count
        return dates.isEmpty ? 0 : Double(completedDays) / Double(dates.count) * 100
    }
    
    private func calculateTrend(for habit: Habit, period: TimePeriod) -> TrendDirection {
        let previousPeriod = period.previousPeriodDates
        
        let currentPercentage = calculateCompletionPercentage(for: habit, period: period)
        let previousPercentage = previousPeriod.isEmpty ? 0 : Double(previousPeriod.filter { habit.isCompleted(for: $0) }.count) / Double(previousPeriod.count) * 100
        
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
    case week, month, custom
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .custom: return "Custom"
        }
    }
    
    var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let monthEnd = calendar.dateInterval(of: .month, for: today)?.end ?? today
            var dates: [Date] = []
            var currentDate = monthStart
            while currentDate < monthEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .custom:
            return (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        }
    }
    
    var previousPeriodDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: previousWeekStart) }
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
            let previousMonthEnd = calendar.date(byAdding: .month, value: 1, to: previousMonthStart) ?? previousMonthStart
            var dates: [Date] = []
            var currentDate = previousMonthStart
            while currentDate < previousMonthEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .custom:
            return (30..<60).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        }
    }
    
    var weeksCount: Int {
        switch self {
        case .week: return 1
        case .month: return 4
        case .custom: return 4
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
        if completionPercentage >= 80 {
            return .workingWell
        } else if completionPercentage >= 50 {
            return .needsAttention
        } else {
            return .atRisk
        }
    }
}

enum HabitStatus {
    case workingWell, needsAttention, atRisk
    
    var label: String {
        switch self {
        case .workingWell: return "Working Well"
        case .needsAttention: return "Needs Attention"
        case .atRisk: return "At Risk"
        }
    }
    
    var color: Color {
        switch self {
        case .workingWell: return .success
        case .needsAttention: return .warning
        case .atRisk: return .error
        }
    }
    
    var icon: String {
        switch self {
        case .workingWell: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .atRisk: return "xmark.circle.fill"
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
    ProgressTabView()
} 
