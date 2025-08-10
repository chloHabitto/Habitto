import SwiftUI

// MARK: - Simple Habit Icon for Calendar Grid
struct HabitIconInlineView: View {
    let habit: Habit
    
    var body: some View {
        ZStack {
            if habit.icon.hasPrefix("Icon-") {
                Image(habit.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(habit.color)
            } else if habit.icon == "None" {
                RoundedRectangle(cornerRadius: 5)
                    .fill(habit.color)
                    .frame(width: 20, height: 20)
            } else {
                Text(habit.icon)
                    .font(.system(size: 16))
            }
        }
    }
}

// MARK: - Weekly Calendar Grid
struct WeeklyCalendarGridView: View {
    let userHabits: [Habit]
    let selectedWeekStartDate: Date
    
    var body: some View {
        Group {
            if userHabits.isEmpty {
                CalendarEmptyStateView(
                    title: "No habits yet",
                    subtitle: "Create habits to see your progress"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.clear)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(height: 32)
                            .padding(.leading, 8)
                            // .background(Color.purple)
                            .overlay(
                                Rectangle()
                                    .stroke(.outline, lineWidth: 1)
                            )
                        
                        ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                            Text(day)
                                .font(.appBodyMedium)
                                .foregroundColor(.text04)
                                .frame(width: 32)
                                .frame(height: 32)
                                .overlay(
                                    Rectangle()
                                        .stroke(.outline, lineWidth: 1)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Habit rows - Performance optimization: Lazy loading
                    LazyVStack(spacing: 0) {
                        ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                            HStack(spacing: 0) {
                                // Habit name cell
                                HStack(spacing: 8) {
                                    HabitIconInlineView(habit: habit)
                                    
                                    Text(habit.name)
                                        .font(.appBodyMedium)
                                        .foregroundColor(.text01)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.trailing, 4)
                                }
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .frame(height: 32)
                                .padding(.leading, 8)
                                // .background(Color.purple)
                                .overlay(
                                    Rectangle()
                                        .stroke(.outline, lineWidth: 1)
                                )
                                
                                // Heatmap cells
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let heatmapData = StreakDataCalculator.getWeeklyHeatmapData(
                                        for: habit,
                                        dayIndex: dayIndex,
                                        weekStartDate: selectedWeekStartDate
                                    )
                                    HeatmapCellView(
                                        intensity: heatmapData.intensity,
                                        isScheduled: heatmapData.isScheduled,
                                        completionPercentage: heatmapData.completionPercentage
                                    )
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Rectangle()
                                            .stroke(.outline, lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("weekly-habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
                        }
                    }
                    
                    // Total row
                    HStack(spacing: 0) {
                        Text("Total")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.text01)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .frame(height: 32)
                            .padding(.leading, 8)
                            // .background(Color.purple)
                            .overlay(
                                Rectangle()
                                    .stroke(.outline, lineWidth: 1)
                            )
                        
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let totalHeatmapData = StreakDataCalculator.getWeeklyTotalHeatmapData(
                                dayIndex: dayIndex,
                                habits: userHabits,
                                weekStartDate: selectedWeekStartDate
                            )
                            HeatmapCellView(
                                intensity: totalHeatmapData.intensity,
                                isScheduled: totalHeatmapData.isScheduled,
                                completionPercentage: totalHeatmapData.completionPercentage
                            )
                            .frame(width: 32, height: 32)
                            .overlay(
                                Rectangle()
                                    .stroke(.outline, lineWidth: 1)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal, 16)
//                .background(.red)
            }
        }
    }
}

// MARK: - Monthly Calendar Grid
struct MonthlyCalendarGridView: View {
    let userHabits: [Habit]
    let selectedMonth: Date
    
    // Calculate the number of weeks in the selected month
    private var numberOfWeeksInMonth: Int {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth)
        let startDate = monthInterval?.start ?? selectedMonth
        let endDate = monthInterval?.end ?? selectedMonth
        
        // Calculate weeks from start of month to end of month
        var currentDate = startDate
        var weekCount = 0
        
        while currentDate < endDate {
            weekCount += 1
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
        
        return max(1, weekCount) // At least 1 week
    }
    
    // Calculate heatmap data for a specific habit, week, and day in the selected month
    private func getMonthlyHeatmapDataForHabit(habit: Habit, weekIndex: Int, dayIndex: Int) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        
        // Calculate the target date based on week and day indices
        let targetDate = calendar.date(byAdding: .day, value: (weekIndex * 7) + dayIndex, to: monthStart) ?? monthStart
        
        // Check if the target date is within the selected month
        let monthEnd = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
        if targetDate >= monthEnd {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: targetDate)
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        let completionPercentage = StreakDataCalculator.calculateCompletionPercentage(for: habit, date: targetDate)
        let intensity: Int
        if completionPercentage == 0 {
            intensity = 0
        } else if completionPercentage < 25 {
            intensity = 1
        } else if completionPercentage < 50 {
            intensity = 2
        } else {
            intensity = 3
        }
        
        return (intensity: intensity, isScheduled: true, completionPercentage: completionPercentage)
    }
    
    var body: some View {
        VStack(spacing: 12) {

            
            if userHabits.isEmpty {
                CalendarEmptyStateView(
                    title: "No habits yet",
                    subtitle: "Create habits to see your monthly progress"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Individual habit tables with monthly heatmaps
                LazyVStack(spacing: 16) {
                    ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                        VStack(spacing: 0) {
                            // Habit header
                            HStack(spacing: 8) {
                                HabitIconInlineView(habit: habit)
                                
                                Text(habit.name)
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            // Weekly heatmap table for this habit
                            monthlyHeatmapTable(for: habit)
                            
                            // Summary statistics row
                            summaryStatisticsView(for: habit)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 16)
                        }
                        .background(Color.grey50)
                        .cornerRadius(16)
                        .id("month-habit-\(habit.id)-\(index)")
                    }
                }
            }
        }
//        .padding(.horizontal, 16)
    }
    
    // MARK: - Weekly Heatmap Table
    @ViewBuilder
    private func monthlyHeatmapTable(for habit: Habit) -> some View {
        VStack(spacing: 0) {
            // Header row with day labels
            HStack(spacing: 0) {
                // Empty cell for top-left corner - must match week label cell exactly
                Rectangle()
                    .fill(.clear)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(.outline, lineWidth: 1)
                    )
                
                // Day headers - must match heatmap cells exactly
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Week rows with heatmap cells - calculate actual weeks in the selected month
            ForEach(0..<numberOfWeeksInMonth, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    // Week label cell - must match empty corner cell exactly
                    Text("Week \(weekIndex + 1)")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                        .frame(height: 32)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                    
                    // Week heatmap cells - must match day headers exactly
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let heatmapData = getMonthlyHeatmapDataForHabit(
                            habit: habit,
                            weekIndex: weekIndex,
                            dayIndex: dayIndex
                        )
                        HeatmapCellView(
                            intensity: heatmapData.intensity,
                            isScheduled: heatmapData.isScheduled,
                            completionPercentage: heatmapData.completionPercentage
                        )
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper View Methods
    @ViewBuilder
    private func summaryStatisticsView(for habit: Habit) -> some View {
        HStack(spacing: 0) {
            // Completion percentage
            VStack(spacing: 4) {
                Text("\(Int(calculateHabitCompletionPercentage(for: habit)))%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Completion")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1, height: 40)
            
            // Completed days
            VStack(spacing: 4) {
                Text("\(calculateHabitCompletedDays(for: habit)) days")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Completed")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1, height: 40)
            
            // Consistency percentage
            VStack(spacing: 4) {
                Text("\(Int(calculateHabitConsistency(for: habit)))%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Consistency")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(.surfaceContainer)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions for Summary Statistics
    private func calculateHabitCompletionPercentage(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use selected month range
        let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
        
        var totalGoal = 0
        var totalCompleted = 0
        
        // Calculate for the selected month range
        var currentDate = startDate
        while currentDate <= endDate && currentDate <= today {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: currentDate)
                totalGoal += goalAmount
                totalCompleted += progress
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        if totalGoal == 0 {
            return habit.isCompleted(for: today) ? 100.0 : 0.0
        }
        
        return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
    }
    
    private func calculateHabitCompletedDays(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use selected month range
        let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
        
        var completedDays = 0
        var currentDate = startDate
        
        while currentDate <= endDate && currentDate <= today {
            if habit.isCompleted(for: currentDate) {
                completedDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return completedDays
    }
    
    private func calculateHabitConsistency(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Use selected month range
        let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
        
        var scheduledDays = 0
        var completedDays = 0
        var currentDate = startDate
        
        while currentDate <= endDate && currentDate <= today {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                scheduledDays += 1
                if habit.isCompleted(for: currentDate) {
                    completedDays += 1
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        if scheduledDays == 0 {
            return 0.0
        }
        
        return (Double(completedDays) / Double(scheduledDays)) * 100.0
    }
    
    private func parseGoalAmount(from goalString: String) -> Int {
        return StreakDataCalculator.parseGoalAmount(from: goalString)
    }
}

// MARK: - Yearly Calendar Grid
struct YearlyCalendarGridView: View {
    let userHabits: [Habit]
    let selectedWeekStartDate: Date
    let yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]]
    let isDataLoaded: Bool
    let isLoadingProgress: Double
    let selectedYear: Int
    
    var body: some View {
        VStack(spacing: 12) {
            if userHabits.isEmpty {
                CalendarEmptyStateView(
                    title: "No habits yet",
                    subtitle: "Create habits to see your yearly progress"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else if isDataLoaded {
                // Individual habit tables with yearly heatmaps and statistics
                LazyVStack(spacing: 16) {
                    ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                        VStack(spacing: 0) {
                            // Habit header
                            HStack(spacing: 8) {
                                HabitIconInlineView(habit: habit)
                                
                                Text(habit.name)
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            // Yearly heatmap for this habit
                            yearlyHeatmapTable(for: habit, index: index)
                            
                            // Summary statistics row
                            summaryStatisticsView(for: habit)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 16)
                        }
                        .background(Color.grey50)
                        .cornerRadius(16)
                        .id("year-habit-\(habit.id)-\(index)")
                    }
                }
            } else {
                // Loading placeholder with progress
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    if isLoadingProgress > 0 {
                        ProgressView(value: isLoadingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                    }
                    
                    Text("Loading heatmap data...")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Yearly Heatmap Table
    @ViewBuilder
    private func yearlyHeatmapTable(for habit: Habit, index: Int) -> some View {
        VStack(spacing: 8) {
            // Calculate date components outside of @ViewBuilder
            let calendar = Calendar.current
            let daysInYear = calendar.isLeapYear(selectedYear) ? 366 : 365
            
            // Main heatmap grid - flexible grid that fills available horizontal space
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 8, maximum: 12), spacing: 1), count: 40), spacing: 1) {
                ForEach(0..<daysInYear, id: \.self) { dayIndex in
                    // Safely access the heatmap data
                    if index < yearlyHeatmapData.count && dayIndex < yearlyHeatmapData[index].count {
                        let heatmapData = yearlyHeatmapData[index][dayIndex]
                        HeatmapCellView(
                            intensity: heatmapData.intensity,
                            isScheduled: heatmapData.isScheduled,
                            completionPercentage: heatmapData.completionPercentage,
                            rectangleSizePercentage: 0.8
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(2)
                    } else {
                        // Fallback for missing data
                        Rectangle()
                            .fill(.clear)
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helper View Methods
    @ViewBuilder
    private func summaryStatisticsView(for habit: Habit) -> some View {
        HStack(spacing: 0) {
            // Completion percentage
            VStack(spacing: 4) {
                Text("\(Int(calculateHabitCompletionPercentage(for: habit)))%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Completion")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1, height: 40)
            
            // Completed days
            VStack(spacing: 4) {
                Text("\(calculateHabitCompletedDays(for: habit)) days")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Completed")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1, height: 40)
            
            // Consistency percentage
            VStack(spacing: 4) {
                Text("\(Int(calculateHabitConsistency(for: habit)))%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Consistency")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(.surfaceContainer)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions for Summary Statistics
    private func calculateHabitCompletionPercentage(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate for the entire year based on selectedYear parameter
        var components = DateComponents()
        components.year = selectedYear
        components.month = 1
        components.day = 1
        let startOfYear = calendar.date(from: components) ?? Date()
        let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear
        
        var totalGoal = 0
        var totalCompleted = 0
        
        // Calculate for the entire year
        var currentDate = startOfYear
        while currentDate <= endOfYear && currentDate <= today {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: currentDate)
                totalGoal += goalAmount
                totalCompleted += progress
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        if totalGoal == 0 {
            return habit.isCompleted(for: today) ? 100.0 : 0.0
        }
        
        return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
    }
    
    private func calculateHabitCompletedDays(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate for the entire year based on selectedYear parameter
        var components = DateComponents()
        components.year = selectedYear
        components.month = 1
        components.day = 1
        let startOfYear = calendar.date(from: components) ?? Date()
        let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear
        
        var completedDays = 0
        var currentDate = startOfYear
        
        while currentDate <= endOfYear && currentDate <= today {
            if habit.isCompleted(for: currentDate) {
                completedDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return completedDays
    }
    
    private func calculateHabitConsistency(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate for the entire year based on selectedYear parameter
        var components = DateComponents()
        components.year = selectedYear
        components.month = 1
        components.day = 1
        let startOfYear = calendar.date(from: components) ?? Date()
        let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear
        
        var scheduledDays = 0
        var completedDays = 0
        var currentDate = startOfYear
        
        while currentDate <= endOfYear && currentDate <= today {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                scheduledDays += 1
                if habit.isCompleted(for: currentDate) {
                    completedDays += 1
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        if scheduledDays == 0 {
            return 0.0
        }
        
        return (Double(completedDays) / Double(scheduledDays)) * 100.0
    }
    
    private func parseGoalAmount(from goalString: String) -> Int {
        return StreakDataCalculator.parseGoalAmount(from: goalString)
    }
} 
