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
                            .padding(.vertical, 12)
                            .background(.red)
                            
                            // Monthly heatmap table for this habit
                            monthlyHeatmapTable(for: habit)
                            
                            // Summary statistics row
                            summaryStatisticsView(for: habit)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .background(Color.grey50)
                        .cornerRadius(8)
                        .id("month-habit-\(habit.id)-\(index)")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Monthly Heatmap Table
    @ViewBuilder
    private func monthlyHeatmapTable(for habit: Habit) -> some View {
        VStack(spacing: 0) {
            // Header row with day labels
            HStack(spacing: 0) {
                // Empty cell for top-left corner - must match week label cell exactly
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80, height: 32)
                    .overlay(
                        Rectangle()
                            .stroke(.outline, lineWidth: 1)
                    )
                
                // Day headers - must match heatmap cells exactly
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                }
            }
            
            // Week rows with heatmap cells
            ForEach(0..<4, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    // Week label cell - must match empty corner cell exactly
                    Text("Week \(weekIndex + 1)")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                        .frame(width: 80, height: 32, alignment: .center)
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                    
                    // Week heatmap cells - must match day headers exactly
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let heatmapData = StreakDataCalculator.getMonthlyHeatmapDataForHabit(
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
                        .overlay(
                            Rectangle()
                                .stroke(.outline, lineWidth: 1)
                        )
                    }
                }
            }
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
    }
    
    // MARK: - Helper Functions for Summary Statistics
    private func calculateHabitCompletionPercentage(for habit: Habit) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        var totalGoal = 0
        var totalCompleted = 0
        
        // Calculate for the current month
        var currentDate = startOfMonth
        while currentDate <= today {
            if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                let goalAmount = parseGoalAmount(from: habit.goal)
                totalGoal += goalAmount
                totalCompleted += habit.getProgress(for: currentDate)
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
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        var completedDays = 0
        var currentDate = startOfMonth
        
        while currentDate <= today {
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
        let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        var scheduledDays = 0
        var completedDays = 0
        var currentDate = startOfMonth
        
        while currentDate <= today {
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
    let yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]]
    let isDataLoaded: Bool
    let isLoadingProgress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            if userHabits.isEmpty {
                CalendarEmptyStateView(
                    title: "No habits yet",
                    subtitle: "Create habits to see your yearly progress"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else if isDataLoaded {
                // Habit rows with yearly heatmap (365 days) - Performance optimization: Lazy loading
                LazyVStack(spacing: 12) {
                    ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                        VStack(spacing: 6) {
                            // Habit name
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(habit.color)
                                    .frame(width: 8, height: 8)
                                    .cornerRadius(2)
                                
                                Text(habit.name)
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Yearly heatmap (365 rectangles) - Optimized rendering
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 30), spacing: 0) {
                                ForEach(0..<365, id: \.self) { dayIndex in
                                    let heatmapData = yearlyHeatmapData[index][dayIndex]
                                    HeatmapCellView(
                                        intensity: heatmapData.intensity,
                                        isScheduled: heatmapData.isScheduled,
                                        completionPercentage: heatmapData.completionPercentage
                                    )
                                    .frame(height: 4)
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                        .padding(.vertical, 6)
                        .id("\(habit.id)-\(index)") // Performance optimization: Stable ID for better SwiftUI performance
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
} 
