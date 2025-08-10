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
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .padding(.leading, 8)
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 32)
                                .padding(.leading, 8)
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
                                    .frame(height: 32)
                                    .overlay(
                                        Rectangle()
                                            .stroke(.outline, lineWidth: 1)
                                    )
                                }
                            }
                            .id("weekly-habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
                        }
                    }
                    
                    // Total row
                    HStack(spacing: 0) {
                        Text("Total")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.text01)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 32)
                            .padding(.leading, 8)
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
                            .frame(height: 32)
                            .overlay(
                                Rectangle()
                                    .stroke(.outline, lineWidth: 1)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Monthly Calendar Grid
struct MonthlyCalendarGridView: View {
    let userHabits: [Habit]
    
    var body: some View {
        VStack(spacing: 12) {
            // Days of week header
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: .infinity)
                
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if userHabits.isEmpty {
                CalendarEmptyStateView(
                    title: "No habits yet",
                    subtitle: "Create habits to see your progress"
                )
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Month weeks (4-5 weeks) - Performance optimization: Lazy loading
                LazyVStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { weekIndex in
                        HStack(spacing: 4) {
                            // Week label
                            Text("Week \(weekIndex + 1)")
                                .font(.appBodySmall)
                                .foregroundColor(.text04)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Week heatmap cells
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let heatmapData = StreakDataCalculator.getMonthlyHeatmapData(
                                    weekIndex: weekIndex,
                                    dayIndex: dayIndex,
                                    habits: userHabits
                                )
                                HeatmapCellView(
                                    intensity: heatmapData.intensity,
                                    isScheduled: heatmapData.isScheduled,
                                    completionPercentage: heatmapData.completionPercentage
                                )
                            }
                        }
                        .id("month-week-\(weekIndex)") // Performance optimization: Stable ID
                    }
                }
                
                // Total row
                HStack(spacing: 4) {
                    Text("Total")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text01)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let totalHeatmapData = StreakDataCalculator.getMonthlyTotalHeatmapData(
                            dayIndex: dayIndex,
                            habits: userHabits
                        )
                        HeatmapCellView(
                            intensity: totalHeatmapData.intensity,
                            isScheduled: totalHeatmapData.isScheduled,
                            completionPercentage: totalHeatmapData.completionPercentage
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Yearly Calendar Grid
struct YearlyCalendarGridView: View {
    let userHabits: [Habit]
    let yearlyHeatmapData: [[Int]]
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
                                    HeatmapCellView(intensity: yearlyHeatmapData[index][dayIndex])
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