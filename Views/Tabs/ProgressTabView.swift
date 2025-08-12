import SwiftUI

// MARK: - Progress Trend Enum
// Moved to Core/Models/ProgressTrend.swift

// MARK: - Week Over Week Trend Enum  
// Moved to Core/Models/WeekOverWeekTrend.swift

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
        

        
        // Determine which habits to show based on selection
        let habitsForDay: [Habit]
        
        if let selectedHabit = selectedHabit {
            // If a specific habit is selected, only show that habit (regardless of type)
            habitsForDay = [selectedHabit]
            
            // Debug: Only log for specific days to avoid spam
            if day <= 7 { // Only log for first week
                print("🔍 CALENDAR DEBUG - Day \(day): Specific habit selected: '\(selectedHabit.name)'")
            }
        } else {
            // If no specific habit is selected, show all habits of the selected type
            habitsForDay = habits.filter { $0.habitType == selectedHabitType }
            
            // Debug: Only log for specific days to avoid spam
            if day <= 7 { // Only log for first week
                print("🔍 CALENDAR DEBUG - Day \(day): No specific habit selected, showing \(habitsForDay.count) habits of type \(selectedHabitType)")
            }
        }
        
        guard !habitsForDay.isEmpty else { 
            if day <= 7 { // Only log for first week
                print("🔍 CALENDAR DEBUG - Day \(day): No habits to show")
            }
            return 0.0 
        }
        
        var totalProgress = 0.0
        var totalGoal = 0.0
        
        for habit in habitsForDay {
            let shouldShow = StreakDataCalculator.shouldShowHabitOnDate(habit, date: dateForDay)
            let goalAmount = parseGoalAmount(from: habit.goal)
            let progress = habit.getProgress(for: dateForDay)
            
            // Debug: Only log for specific days to avoid spam
            if day <= 7 { // Only log for first week
                print("🔍 CALENDAR DEBUG - Day \(day): Habit '\(habit.name)' | Should show: \(shouldShow) | Goal: \(goalAmount) | Progress: \(progress)")
                print("🔍 CALENDAR DEBUG - Day \(day): Habit goal string: '\(habit.goal)' | Parsed goal amount: \(goalAmount)")
            }
            
            if shouldShow {
                totalGoal += Double(goalAmount)
                totalProgress += Double(progress)
            }
        }
        
        let finalProgress = totalGoal == 0 ? 0.0 : min(totalProgress / totalGoal, 1.0)
        
        // Debug: Only log for specific days to avoid spam
        if day <= 7 { // Only log for first week
            print("🔍 CALENDAR DEBUG - Day \(day): Final progress: \(finalProgress) (totalProgress: \(totalProgress), totalGoal: \(totalGoal))")
        }
        
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
                CalendarGridComponents.WeekdayHeader()
                
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
            MonthlyCompletionRateSection(
                monthlyCompletionRate: monthlyCompletionRate,
                monthlyCompletedHabits: monthlyCompletedHabits,
                monthlyTotalHabits: monthlyTotalHabits,
                topPerformingHabit: topPerformingHabit,
                needsAttentionHabit: needsAttentionHabit,
                progressTrendColor: progressTrendColor,
                progressTrendIcon: progressTrendIcon,
                progressTrendText: progressTrendText,
                progressTrendDescription: progressTrendDescription,
                monthlyHabitCompletionRate: monthlyHabitCompletionRate
            )
        }
        .padding(.top, 20)
    }
    
    // Moved to Core/UI/Components/MonthlyCompletionRateSection.swift
    
    // Moved to Core/UI/Components/GoalAchievementSection.swift
    
    // Moved to Core/UI/Components/HabitsListPopup.swift
    
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
        .onChange(of: selectedHabit) { _, newHabit in
            if let habit = newHabit {
                print("🔍 CALENDAR STATE DEBUG - Calendar displaying for selected habit: '\(habit.name)'")
                print("🔍 CALENDAR STATE DEBUG - Selected habit completion history: \(habit.completionHistory)")
                print("🔍 CALENDAR STATE DEBUG - Selected habit goal: '\(habit.goal)'")
                
                if habit.completionHistory.isEmpty {
                    print("🔍 CALENDAR STATE DEBUG - WARNING: Selected habit has no completion history!")
                    print("🔍 CALENDAR STATE DEBUG - This is why the calendar shows no progress rings.")
                    print("🔍 CALENDAR STATE DEBUG - The habit needs to have progress logged to show in the calendar.")
                }
            } else {
                print("🔍 CALENDAR STATE DEBUG - Calendar displaying for overall progress (habit type: \(selectedHabitType))")
            }
            updateCacheIfNeeded()
        }
        .onAppear {
            updateCacheIfNeeded()
            
            // Debug: Show initial state
            if let selectedHabit = selectedHabit {
                print("🔍 CALENDAR STATE DEBUG - Calendar appeared for selected habit: '\(selectedHabit.name)'")
                print("🔍 CALENDAR STATE DEBUG - Selected habit completion history: \(selectedHabit.completionHistory)")
                print("🔍 CALENDAR STATE DEBUG - Selected habit goal: '\(selectedHabit.goal)'")
            } else {
                print("🔍 CALENDAR STATE DEBUG - Calendar appeared for overall progress (habit type: \(selectedHabitType))")
            }
        }
        .sheet(isPresented: $showingHabitsList) {
            HabitsListPopup(
                habits: habits,
                selectedHabit: selectedHabit,
                showingHabitsList: showingHabitsList,
                onHabitSelected: { habit in
                    selectedHabit = habit
                    showingHabitsList = false
                },
                onDismiss: {
                    showingHabitsList = false
                }
            )
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
    
    // Moved to Core/UI/Components/ProgressSelectorComponents.swift
    
    // Moved to Core/UI/Components/ProgressOverviewCharts.swift
    
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
// Moved to Core/Models/TimePeriod.swift
    

    

    

    


// Moved to Core/Models/TrendDirection.swift

// Moved to Core/Models/HabitProgress.swift

// Moved to Core/Models/HabitStatus.swift

// Moved to Core/Models/HabitGoal.swift

// Moved to Core/Models/InsightType.swift

// Moved to Core/UI/Common/EmptyStateView.swift

#Preview {
    ProgressTabView(habits: [])
} 
