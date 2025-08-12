import SwiftUI

// MARK: - Progress Trend Enum
enum ProgressTrend {
    case improving
    case declining
    case maintaining
}

// MARK: - Week Over Week Trend Enum
enum WeekOverWeekTrend {
    case improving
    case declining
    case maintaining
}

struct ProgressTabView: View {
    @State private var selectedHabitType: HabitType = .formation
    @State private var selectedPeriod: TimePeriod = .today
    @State private var currentDate = Date() // For calendar navigation
    @State private var showingHabitsList = false // For habits popup
    @State private var selectedHabit: Habit? = nil // For individual habit selection
    let habits: [Habit]
    
    // Performance optimization: Cache expensive computations
    @State private var cachedFilteredHabits: [Habit] = []
    @State private var cachedHabitsWithProgress: [HabitProgress] = []
    @State private var cachedHabitsWithGoals: [HabitGoal] = []
    @State private var lastCacheUpdate: (HabitType, TimePeriod) = (.formation, .today)
    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Calendar Helper Functions
    private func previousMonth() {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        // Get the first day of the current month
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        // Subtract one month from the first day
        if let newDate = calendar.date(byAdding: .month, value: -1, to: firstDayOfCurrentMonth) {
            currentDate = newDate
        }
    }
    
    private func nextMonth() {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        // Get the first day of the current month
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        // Add one month from the first day
        if let newDate = calendar.date(byAdding: .month, value: 1, to: firstDayOfCurrentMonth) {
            currentDate = newDate
        }
    }
    
    private func monthYearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        let result = formatter.string(from: currentDate)
        return result
    }
    
    private func firstDayOfMonth() -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US") // Ensure English locale
        calendar.timeZone = TimeZone.current
        
        // Create a date for the first day of the current month
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, etc.)
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Convert to 0-based index (Sunday = 0, Monday = 1, etc.)
        // This is correct - if August 1st is Friday (weekday 6), we need 5 empty cells
        return weekday - 1
    }
    
    private func daysInMonth() -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US") // Ensure English locale
        calendar.timeZone = TimeZone.current
        
        let range = calendar.range(of: .day, in: .month, for: currentDate)
        return range?.count ?? 0
    }
    
    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Create a date for the specific day in the current month
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) else {
            return false
        }
        
        // Compare with today's date
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let dayDateComponents = calendar.dateComponents([.year, .month, .day], from: dateForDay)
        
        let isTodayResult = todayComponents.year == dayDateComponents.year && 
               todayComponents.month == dayDateComponents.month && 
               todayComponents.day == dayDateComponents.day
        
        // Debug: Print today check
        if isTodayResult {
            print("🔍 TODAY CHECK DEBUG - Day \(day) is today!")
        }
        
        return isTodayResult
    }
    
    // MARK: - Progress Ring Helper Functions
    private func getDayProgress(day: Int) -> Double {
        let calendar = Calendar.current
        
        // Create a date for the specific day in the current month
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) else {
            return 0.0
        }
        
        // Calculate total progress for all habits of the selected type on this day
        let habitsForDay = habits.filter { $0.habitType == selectedHabitType }
        guard !habitsForDay.isEmpty else { return 0.0 }
        
        var totalProgress = 0.0
        var totalGoal = 0.0
        
        for habit in habitsForDay {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: dateForDay) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: dateForDay)
                
                totalGoal += Double(goalAmount)
                totalProgress += Double(progress)
            }
        }
        
        let finalProgress = totalGoal == 0 ? 0.0 : min(totalProgress / totalGoal, 1.0)
        return finalProgress
    }
    

    
    // MARK: - Helper Functions
    private func parseGoalAmount(from goalString: String) -> Int {
        return StreakDataCalculator.parseGoalAmount(from: goalString)
    }
    
    private func monthlyHabitCompletionRate(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0.0
        }
        
        var habitProgress = 0.0
        var habitGoals = 0.0
        
        // Calculate progress for each day in the month
        var currentDate = monthStart
        while currentDate <= monthEnd {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: currentDate)
                
                habitGoals += Double(goalAmount)
                habitProgress += Double(progress)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return habitGoals > 0 ? min(habitProgress / habitGoals, 1.0) : 0.0
    }
    
    private func getDayProgress(for date: Date) -> Double {
        let habitsForDay: [Habit]
        
        if let selectedHabit = selectedHabit {
            // If a specific habit is selected, only show that habit (regardless of type)
            habitsForDay = [selectedHabit]
        } else {
            // If no specific habit is selected, show all habits of the selected type
            habitsForDay = habits.filter { $0.habitType == selectedHabitType }
        }
        
        guard !habitsForDay.isEmpty else { return 0.0 }
        
        var totalProgress = 0.0
        var totalGoal = 0.0
        
        for habit in habitsForDay {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: date) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: date)
                totalGoal += Double(goalAmount)
                totalProgress += Double(progress)
            }
        }
        
        return totalGoal == 0 ? 0.0 : min(totalProgress / totalGoal, 1.0)
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
    
    // MARK: - Monthly Progress Computed Properties
    private var monthlyCompletionRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0.0
        }
        
        var totalMonthlyProgress = 0.0
        var totalMonthlyGoals = 0.0
        
        let habitsToCalculate: [Habit]
        if let selectedHabit = selectedHabit {
            // If a specific habit is selected, only calculate that habit (regardless of type)
            habitsToCalculate = [selectedHabit]
        } else {
            // If no specific habit is selected, calculate all habits of the selected type
            habitsToCalculate = habits.filter({ $0.habitType == selectedHabitType })
        }
        
        for habit in habitsToCalculate {
            var habitProgress = 0.0
            var habitGoals = 0.0
            
            // Calculate progress for each day in the month
            var currentDate = monthStart
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    habitGoals += Double(goalAmount)
                    habitProgress += Double(progress)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            totalMonthlyProgress += habitProgress
            totalMonthlyGoals += habitGoals
        }
        
        return totalMonthlyGoals > 0 ? min(totalMonthlyProgress / totalMonthlyGoals, 1.0) : 0.0
    }
    
    private var monthlyCompletedHabits: Int {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0
        }
        
        var completedCount = 0
        for habit in habits.filter({ $0.habitType == selectedHabitType }) {
            var currentDate = monthStart
            var hasCompletedAnyDay = false
            
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    if progress >= goalAmount {
                        hasCompletedAnyDay = true
                        break
                    }
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            if hasCompletedAnyDay {
                completedCount += 1
            }
        }
        
        return completedCount
    }
    
    private var monthlyTotalHabits: Int {
        return habits.filter { $0.habitType == selectedHabitType }.count
    }
    
    // MARK: - Habit Performance Breakdown Computed Properties
    private var topPerformingHabit: Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.max { habit1, habit2 in
            monthlyHabitCompletionRate(for: habit1) < monthlyHabitCompletionRate(for: habit2)
        }
    }
    
    private var needsAttentionHabit: Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.min { habit1, habit2 in
            monthlyHabitCompletionRate(for: habit1) < monthlyHabitCompletionRate(for: habit2)
        }
    }
    
    private var progressTrend: ProgressTrend {
        let currentMonthRate = monthlyCompletionRate
        let previousMonthRate = previousMonthCompletionRate
        
        if currentMonthRate > previousMonthRate + 0.05 { // 5% improvement threshold
            return .improving
        } else if currentMonthRate < previousMonthRate - 0.05 { // 5% decline threshold
            return .declining
        } else {
            return .maintaining
        }
    }
    
    private var progressTrendColor: Color {
        switch progressTrend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .maintaining:
            return .blue
        }
    }
    
    private var progressTrendIcon: String {
        switch progressTrend {
        case .improving:
            return "arrow.up.circle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .maintaining:
            return "minus.circle.fill"
        }
    }
    
    private var progressTrendText: String {
        switch progressTrend {
        case .improving:
            return "Improving"
        case .declining:
            return "Declining"
        case .maintaining:
            return "Maintaining"
        }
    }
    
    private var progressTrendDescription: String {
        switch progressTrend {
        case .improving:
            return "Keep up the great work!"
        case .declining:
            return "Time to refocus"
        case .maintaining:
            return "Staying consistent"
        }
    }
    
    private var previousMonthCompletionRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        let monthComponents = calendar.dateComponents([.year, .month], from: previousMonth)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0.0
        }
        
        var totalMonthlyProgress = 0.0
        var totalMonthlyGoals = 0.0
        
        for habit in habits.filter({ $0.habitType == selectedHabitType }) {
            var habitProgress = 0.0
            var habitGoals = 0.0
            
            // Calculate progress for each day in the previous month
            var currentDate = monthStart
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    habitGoals += Double(goalAmount)
                    habitProgress += Double(progress)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            totalMonthlyProgress += habitProgress
            totalMonthlyGoals += habitGoals
        }
        
        return totalMonthlyGoals > 0 ? min(totalMonthlyProgress / totalMonthlyGoals, 1.0) : 0.0
    }
    
    // MARK: - Goal Achievement Computed Properties
    private var monthlyGoalsMet: Int {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0
        }
        
        var goalsMetCount = 0
        
        for habit in filteredHabits {
            var currentDate = monthStart
            var hasMetGoal = false
            
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    if progress >= goalAmount {
                        hasMetGoal = true
                        break
                    }
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            if hasMetGoal {
                goalsMetCount += 1
            }
        }
        
        return goalsMetCount
    }
    
    private var monthlyTotalGoals: Int {
        return habits.filter { $0.habitType == selectedHabitType }.count
    }
    
    private var monthlyGoalsMetPercentage: Double {
        guard monthlyTotalGoals > 0 else { return 0.0 }
        return Double(monthlyGoalsMet) / Double(monthlyTotalGoals)
    }
    
    private var averageDailyProgress: Double {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0.0
        }
        
        var totalDailyProgress = 0.0
        var totalDays = 0
        
        // Calculate average progress for each day in the month
        var currentDate = monthStart
        while currentDate <= monthEnd {
            let dayProgress = getDayProgress(for: currentDate)
            if dayProgress > 0 { // Only count days with scheduled habits
                totalDailyProgress += dayProgress
                totalDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return totalDays > 0 ? totalDailyProgress / Double(totalDays) : 0.0
    }
    
    private var weekOverWeekTrend: WeekOverWeekTrend {
        let currentWeekRate = currentWeekCompletionRate
        let previousWeekRate = previousWeekCompletionRate
        
        if currentWeekRate > previousWeekRate + 0.05 { // 5% improvement threshold
            return .improving
        } else if currentWeekRate < previousWeekRate - 0.05 { // 5% decline threshold
            return .declining
        } else {
            return .maintaining
        }
    }
    
    private var weekOverWeekTrendColor: Color {
        switch weekOverWeekTrend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .maintaining:
            return .blue
        }
    }
    
    private var weekOverWeekTrendIcon: String {
        switch weekOverWeekTrend {
        case .improving:
            return "arrow.up.circle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .maintaining:
            return "minus.circle.fill"
        }
    }
    
    private var weekOverWeekTrendText: String {
        switch weekOverWeekTrend {
        case .improving:
            return "Improving"
        case .declining:
            return "Declining"
        case .maintaining:
            return "Maintaining"
        }
    }
    
    private var weekOverWeekTrendDescription: String {
        switch weekOverWeekTrend {
        case .improving:
            return "Better than last week"
        case .declining:
            return "Below last week's performance"
        case .maintaining:
            return "Similar to last week"
        }
    }
    
    private var currentWeekCompletionRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        var totalWeeklyProgress = 0.0
        var totalWeeklyGoals = 0.0
        
        for habit in habits.filter({ $0.habitType == selectedHabitType }) {
            var currentDate = weekStart
            while currentDate < weekEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    totalWeeklyGoals += Double(goalAmount)
                    totalWeeklyProgress += Double(progress)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        return totalWeeklyGoals > 0 ? min(totalWeeklyProgress / totalWeeklyGoals, 1.0) : 0.0
    }
    
    private var previousWeekCompletionRate: Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let today = Date()
        let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today) ?? today
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: previousWeek)?.start ?? previousWeek
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: previousWeek)?.end ?? previousWeek
        
        var totalWeeklyProgress = 0.0
        var totalWeeklyGoals = 0.0
        
        for habit in habits.filter({ $0.habitType == selectedHabitType }) {
            var currentDate = weekStart
            while currentDate < weekEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    totalWeeklyGoals += Double(goalAmount)
                    totalWeeklyProgress += Double(progress)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        return totalWeeklyGoals > 0 ? min(totalWeeklyProgress / totalWeeklyGoals, 1.0) : 0.0
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
    
    // MARK: - Overall Progress Section
    private var overallProgressSection: some View {
        VStack(spacing: 16) {
            // Overall + down chevron header - left aligned
            Button(action: {
                showingHabitsList = true
            }) {
                HStack(spacing: 0) {
                    // Always show an icon - either overall icon or selected habit icon
                    if let selectedHabit = selectedHabit {
                        HabitIconView(habit: selectedHabit)
                            .frame(width: 38, height: 54)
                    } else {
                        // Overall icon when no specific habit is selected - match HabitIconView exactly
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.15))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 38, height: 54)
                    }
                    
                    Spacer()
                        .frame(width: 8)
                    
                    Text(selectedHabit?.name ?? "Overall")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                        .frame(width: 12)
                    
                    Image(systemName: "chevron.down")
                        .font(.appLabelMedium)
                        .foregroundColor(.primaryFocus)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            
            // Monthly Calendar
            VStack(spacing: 12) {
                // Calendar header with month/year and Today button
                HStack {
                    Text(monthYearString())
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                        .id("month-header-\(monthYearString())")
                    
                    Spacer()
                    
                    // Today button (shown when not on current month or when current date is not today)
                    let calendar = Calendar.current
                    let today = Date()
                    let isCurrentMonth = calendar.isDate(currentDate, equalTo: today, toGranularity: .month)
                    let isTodayInCurrentMonth = calendar.isDate(today, equalTo: currentDate, toGranularity: .month)
                    
                    if !isCurrentMonth || !isTodayInCurrentMonth {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.08)) {
                                currentDate = Date()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image("Icon-replay")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.primaryFocus)
                                Text("Today")
                                    .font(.appLabelMedium)
                                    .foregroundColor(.primaryFocus)
                            }
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: .infinity)
                                    .stroke(.primaryFocus, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.bottom, 16)
                
                // Days of week header
                HStack(spacing: 0) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { index, day in
                        Text(day)
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    // Empty cells for days before the first day of the month
                    let emptyCells = firstDayOfMonth()
                    ForEach(0..<emptyCells, id: \.self) { index in
                        Text("")
                            .frame(width: 32, height: 32)
                            .id("empty-\(monthYearString())-\(index)")
                    }
                    
                    // Actual days of the month
                    let totalDays = daysInMonth()
                    ForEach(1...totalDays, id: \.self) { day in
                        Button(action: {
                            // Add haptic feedback when selecting a date
                            let selectionFeedback = UISelectionFeedbackGenerator()
                            selectionFeedback.selectionChanged()
                            
                            // Create a date for the selected day in the current month
                            let calendar = Calendar.current
                            let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
                            if let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) {
                                // Here you can add logic to handle the selected date
                                // For now, we'll just print it to console
                                print("Selected date: \(dateForDay)")
                            }
                        }) {
                            ZStack {
                                // Background circle
                                Circle()
                                    .fill(isToday(day: day) ? Color.primary : Color.clear)
                                    .frame(width: 32, height: 32)
                                
                                // Complete stroke around the day (always visible)
                                Circle()
                                    .stroke(Color.primaryContainer, lineWidth: 1)
                                    .frame(width: 32, height: 32)
                                
                                // Progress ring with blue color (fills based on completion percentage)
                                let progress = getDayProgress(day: day)
                                
                                // Progress ring (filled based on progress)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90)) // Start from top
                                    .opacity(progress > 0 ? 1.0 : 0.0)
                                
                                // Day number
                                Text("\(day)")
                                    .font(.appBodySmall)
                                    .foregroundColor(isToday(day: day) ? .onPrimary : .text01)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id("day-\(monthYearString())-\(day)")
                    }
                }
                .frame(minHeight: 200) // Ensure minimum height for calendar

            }
            .padding(20)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.outline, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .id("calendar-container-\(monthYearString())")
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Only handle horizontal swipes for month navigation
                        if abs(value.translation.width) > abs(value.translation.height) {
                            // Horizontal swipe detected - prevent vertical scrolling interference
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        // Only trigger month change for horizontal swipes
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width > threshold {
                                // Swipe right - go to previous month
                                previousMonth()
                            } else if value.translation.width < -threshold {
                                // Swipe left - go to next month
                                nextMonth()
                            }
                        }
                    }
            )
            
            // Monthly Completion Rate Section
            monthlyCompletionRateSection
        }
        .padding(.top, 20)
    }
    
    // MARK: - Monthly Completion Rate Section
    private var monthlyCompletionRateSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Monthly Progress")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Completion rate card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Circular progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.primaryContainer, lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: monthlyCompletionRate)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        // Percentage text
                        Text("\(Int(monthlyCompletionRate * 100))%")
                            .font(.appLabelMedium)
                            .foregroundColor(.text01)
                            .fontWeight(.semibold)
                    }
                    
                    // Progress details
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Completion Rate")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("\(monthlyCompletedHabits) of \(monthlyTotalHabits) habits")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.outline, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Habit Performance Breakdown Section
            habitPerformanceBreakdownSection
        }
    }
    
    // MARK: - Habit Performance Breakdown Section
    private var habitPerformanceBreakdownSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Habit Performance")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Performance breakdown cards
            VStack(spacing: 12) {
                // Top Performing Habit
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                    
                    // Habit details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Top Performing")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text(topPerformingHabit?.name ?? "No habits")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                            .lineLimit(1)
                        
                        if let habit = topPerformingHabit {
                            Text("\(Int(monthlyHabitCompletionRate(for: habit) * 100))% completion")
                                .font(.appLabelSmall)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
                
                // Needs Attention Habit
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    
                    // Habit details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Needs Attention")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text(needsAttentionHabit?.name ?? "No habits")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                            .lineLimit(1)
                        
                        if let habit = needsAttentionHabit {
                            Text("\(Int(monthlyHabitCompletionRate(for: habit) * 100))% completion")
                                .font(.appLabelSmall)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
                
                // Progress Trend
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(progressTrendColor.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: progressTrendIcon)
                            .font(.system(size: 16))
                            .foregroundColor(progressTrendColor)
                    }
                    
                    // Trend details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress Trend")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text(progressTrendText)
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text(progressTrendDescription)
                            .font(.appLabelSmall)
                            .foregroundColor(progressTrendColor)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            // Goal Achievement Section
            goalAchievementSection
        }
    }
    
    // MARK: - Goal Achievement Section
    private var goalAchievementSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Goal Achievement")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Goal achievement cards
            VStack(spacing: 12) {
                // Monthly Goals Met
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                    }
                    
                    // Goal details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Goals Met")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text("\(monthlyGoalsMet) of \(monthlyTotalGoals) targets")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("\(Int(monthlyGoalsMetPercentage * 100))% achievement rate")
                            .font(.appLabelSmall)
                            .foregroundColor(.purple)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
                
                // Average Daily Progress
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    
                    // Progress details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average Daily Progress")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text("\(Int(averageDailyProgress * 100))% completion")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("Typical daily performance")
                            .font(.appLabelSmall)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
                
                // Week-over-Week Comparison
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(weekOverWeekTrendColor.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: weekOverWeekTrendIcon)
                            .font(.system(size: 16))
                            .foregroundColor(weekOverWeekTrendColor)
                    }
                    
                    // Comparison details
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week-over-Week")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                        
                        Text(weekOverWeekTrendText)
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text(weekOverWeekTrendDescription)
                            .font(.appLabelSmall)
                            .foregroundColor(weekOverWeekTrendColor)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Habits List Popup
    private var habitsListPopup: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                habitsPopupHeader
                
                // Habits list
                habitsPopupList
            }
            .background(Color.surface)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Habits Popup Header
    private var habitsPopupHeader: some View {
        HStack {
            Text("Active Habits")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.onPrimaryContainer)
            
            Spacer()
            
            Button("Done") {
                showingHabitsList = false
            }
            .font(.appBodyMedium)
            .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color.surface)
    }
    
    // MARK: - Habits Popup List
    private var habitsPopupList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Overall option (always first)
                overallOptionRow
                
                // Individual habits
                ForEach(habits, id: \.id) { habit in
                    habitRowView(for: habit)
                }
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            print("🔍 HABITS POPUP DEBUG - Total habits: \(habits.count)")
            print("🔍 HABITS POPUP DEBUG - Selected habit type: \(selectedHabitType)")
            for habit in habits {
                print("🔍 HABITS POPUP DEBUG - Habit: \(habit.name), Type: \(habit.habitType)")
            }
        }
    }
    
    // MARK: - Overall Option Row
    private var overallOptionRow: some View {
        Button(action: {
            selectedHabit = nil
            showingHabitsList = false
        }) {
            HStack(spacing: 16) {
                // Overall icon - same style as habit icons
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
                
                // Overall text
                Text("Overall")
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                
                Spacer()
                
                // Selection indicator
                if selectedHabit == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(selectedHabit == nil ? Color.primary.opacity(0.05) : Color.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedHabit == nil ? Color.primary : Color.outline, lineWidth: selectedHabit == nil ? 2 : 1)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Individual Habit Row
    private func habitRowView(for habit: Habit) -> some View {
        Button(action: {
            selectedHabit = habit
            showingHabitsList = false
        }) {
            HStack(spacing: 16) {
                // Habit icon
                HabitIconView(habit: habit)
                    .frame(width: 40, height: 40)
                
                // Habit details in VStack
                VStack(alignment: .leading, spacing: 4) {
                    // Habit type indicator
                    habitTypeIndicator(for: habit)
                    
                    // Habit name
                    Text(habit.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedHabit?.id == habit.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(selectedHabit?.id == habit.id ? Color.primary.opacity(0.05) : Color.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedHabit?.id == habit.id ? Color.primary : Color.outline, lineWidth: selectedHabit?.id == habit.id ? 2 : 1)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Habit Type Indicator
    private func habitTypeIndicator(for habit: Habit) -> some View {
        let typeText = habit.habitType == .formation ? "Habit Building" : "Habit Breaking"
        let typeColor = habit.habitType == .formation ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        
        return Text(typeText)
            .font(.appLabelSmall)
            .foregroundColor(.text02)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor)
            )
    }
    
    var body: some View {
        WhiteSheetContainer(
            // title: "Progress"
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Independent Today's Progress Container
                    independentTodaysProgressContainer
                        .padding(.top, 20)
                    
                    // Overall Progress Section with Monthly Calendar
                    overallProgressSection
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDisabled(false)
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "scrollView")
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
        .sheet(isPresented: $showingHabitsList) {
            habitsListPopup
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
    
    // MARK: - Today's Progress Computed Properties
    // private var todaysProgressPercentage: Double {
    //     guard !cachedHabitsWithProgress.isEmpty else { return 0 }
    //     
    //     let totalProgress = cachedHabitsWithProgress.reduce(0.0) { sum, habitProgress in
    //         sum + habitProgress.completionPercentage
    //     }
    //     
    //     return totalProgress / Double(cachedHabitsWithProgress.count)
    // }
    
    // private var encouragingText: String {
    //     let percentage = todaysProgressPercentage
    //     
    //     if percentage >= 80 {
    //         return "Excellent progress! Keep it up!"
    //     } else if percentage >= 50 {
    //         return "Good progress! You're on track!"
    //     } else if percentage >= 20 {
    //         return "Getting started! Every step counts!"
    //     } else {
    //         return "New day, new opportunities!"
    //     }
    // }
    
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
