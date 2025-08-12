import Foundation
import SwiftUI

class ProgressTrendHelper {
    
    // MARK: - Progress Trend Calculations
    static func progressTrend(currentMonthRate: Double, previousMonthRate: Double) -> ProgressTrend {
        if currentMonthRate > previousMonthRate + 0.05 { // 5% improvement threshold
            return .improving
        } else if currentMonthRate < previousMonthRate - 0.05 { // 5% decline threshold
            return .declining
        } else {
            return .maintaining
        }
    }
    
    static func progressTrendColor(for trend: ProgressTrend) -> Color {
        switch trend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .maintaining:
            return .blue
        }
    }
    
    static func progressTrendIcon(for trend: ProgressTrend) -> String {
        switch trend {
        case .improving:
            return "arrow.up.circle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .maintaining:
            return "minus.circle.fill"
        }
    }
    
    static func progressTrendText(for trend: ProgressTrend) -> String {
        switch trend {
        case .improving:
            return "Improving"
        case .declining:
            return "Declining"
        case .maintaining:
            return "Maintaining"
        }
    }
    
    static func progressTrendDescription(for trend: ProgressTrend) -> String {
        switch trend {
        case .improving:
            return "Keep up the great work!"
        case .declining:
            return "Time to refocus"
        case .maintaining:
            return "Staying consistent"
        }
    }
    
    // MARK: - Week Over Week Trend Calculations
    static func weekOverWeekTrend(currentWeekRate: Double, previousWeekRate: Double) -> WeekOverWeekTrend {
        if currentWeekRate > previousWeekRate + 0.05 { // 5% improvement threshold
            return .improving
        } else if currentWeekRate < previousWeekRate - 0.05 { // 5% decline threshold
            return .declining
        } else {
            return .maintaining
        }
    }
    
    static func weekOverWeekTrendColor(for trend: WeekOverWeekTrend) -> Color {
        switch trend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .maintaining:
            return .blue
        }
    }
    
    static func weekOverWeekTrendIcon(for trend: WeekOverWeekTrend) -> String {
        switch trend {
        case .improving:
            return "arrow.up.circle.fill"
        case .declining:
            return "arrow.down.circle.fill"
        case .maintaining:
            return "minus.circle.fill"
        }
    }
    
    static func weekOverWeekTrendText(for trend: WeekOverWeekTrend) -> String {
        switch trend {
        case .improving:
            return "Improving"
        case .declining:
            return "Declining"
        case .maintaining:
            return "Maintaining"
        }
    }
    
    static func weekOverWeekTrendDescription(for trend: WeekOverWeekTrend) -> String {
        switch trend {
        case .improving:
            return "Better than last week"
        case .declining:
            return "Below last week's performance"
        case .maintaining:
            return "Similar to last week"
        }
    }
    
    // MARK: - Habit Performance Analysis
    static func topPerformingHabit(habits: [Habit], selectedHabitType: HabitType, currentDate: Date) -> Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.max { habit1, habit2 in
            ProgressCalculationHelper.monthlyHabitCompletionRate(for: habit1, currentDate: currentDate) < 
            ProgressCalculationHelper.monthlyHabitCompletionRate(for: habit2, currentDate: currentDate)
        }
    }
    
    static func needsAttentionHabit(habits: [Habit], selectedHabitType: HabitType, currentDate: Date) -> Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.min { habit1, habit2 in
            ProgressCalculationHelper.monthlyHabitCompletionRate(for: habit1, currentDate: currentDate) < 
            ProgressCalculationHelper.monthlyHabitCompletionRate(for: habit2, currentDate: currentDate)
        }
    }
    
    // MARK: - Goal Achievement Analysis
    static func monthlyGoalsMetPercentage(habits: [Habit], currentDate: Date, selectedHabitType: HabitType) -> Double {
        let totalGoals = habits.filter { $0.habitType == selectedHabitType }.count
        guard totalGoals > 0 else { return 0.0 }
        
        let goalsMet = ProgressCalculationHelper.monthlyGoalsMet(habits: habits, currentDate: currentDate, selectedHabitType: selectedHabitType)
        return Double(goalsMet) / Double(totalGoals)
    }
    
    static func monthlyTotalGoals(habits: [Habit], selectedHabitType: HabitType) -> Int {
        return habits.filter { $0.habitType == selectedHabitType }.count
    }
    
    static func monthlyTotalHabits(habits: [Habit], selectedHabitType: HabitType) -> Int {
        return habits.filter { $0.habitType == selectedHabitType }.count
    }
}
