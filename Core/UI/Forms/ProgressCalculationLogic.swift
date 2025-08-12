import Foundation
import SwiftUI

// MARK: - Progress Calculation Logic Helper
class ProgressCalculationLogic {
    
    // MARK: - Monthly Progress Calculations
    static func monthlyHabitCompletionRate(for habit: Habit, currentDate: Date) -> Double {
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
                let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: currentDate)
                
                habitGoals += Double(goalAmount)
                habitProgress += Double(progress)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return habitGoals > 0 ? min(habitProgress / habitGoals, 1.0) : 0.0
    }
    
    static func monthlyCompletionRate(for habits: [Habit], selectedHabitType: HabitType, selectedHabit: Habit?, currentDate: Date) -> Double {
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
                    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
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
    
    static func monthlyCompletedHabits(for habits: [Habit], selectedHabitType: HabitType, currentDate: Date) -> Int {
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
                    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
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
    
    static func monthlyTotalHabits(for habits: [Habit], selectedHabitType: HabitType) -> Int {
        return habits.filter { $0.habitType == selectedHabitType }.count
    }
    
    // MARK: - Weekly Progress Calculations
    static func previousWeekCompletionRate(for habits: [Habit], selectedHabitType: HabitType) -> Double {
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
                    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    
                    totalWeeklyGoals += Double(goalAmount)
                    totalWeeklyProgress += Double(progress)
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        return totalWeeklyGoals > 0 ? min(totalWeeklyProgress / totalWeeklyGoals, 1.0) : 0.0
    }
    
    // MARK: - Daily Progress Calculations
    static func getDayProgress(for date: Date, habits: [Habit], selectedHabitType: HabitType, selectedHabit: Habit?) -> Double {
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
                let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
                let progress = habit.getProgress(for: date)
                totalGoal += Double(goalAmount)
                totalProgress += Double(progress)
            }
        }
        
        return totalGoal == 0 ? 0.0 : min(totalProgress / totalGoal, 1.0)
    }
    
    static func todaysActualCompletionPercentage(for habits: [Habit]) -> Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let today = Date()
        let totalProgress = habits.reduce(0.0) { sum, habit in
            // Get today's progress count
            let todayProgress = habit.getProgress(for: today)
            
            // Parse the goal to get target amount
            if let goal = parseGoal(from: habit.goal) {
                // Calculate completion percentage for this habit (capped at 100%)
                let habitCompletion = min(Double(todayProgress) / Double(goal.amount), 1.0)
                return sum + habitCompletion
            } else {
                // Fallback: if no goal, treat as binary completion
                return sum + (todayProgress > 0 ? 1.0 : 0.0)
            }
        }
        
        return totalProgress / Double(habits.count)
    }
    
    // MARK: - Performance Analysis
    static func topPerformingHabit(from habits: [Habit], selectedHabitType: HabitType, currentDate: Date) -> Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.max { habit1, habit2 in
            monthlyHabitCompletionRate(for: habit1, currentDate: currentDate) < monthlyHabitCompletionRate(for: habit2, currentDate: currentDate)
        }
    }
    
    static func needsAttentionHabit(from habits: [Habit], selectedHabitType: HabitType, currentDate: Date) -> Habit? {
        let filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        guard !filteredHabits.isEmpty else { return nil }
        
        return filteredHabits.min { habit1, habit2 in
            monthlyHabitCompletionRate(for: habit1, currentDate: currentDate) < monthlyHabitCompletionRate(for: habit2, currentDate: currentDate)
        }
    }
    
    static func progressTrend(currentMonthRate: Double, previousMonthRate: Double) -> ProgressTrend {
        if currentMonthRate > previousMonthRate + 0.05 { // 5% improvement threshold
            return .improving
        } else if currentMonthRate < previousMonthRate - 0.05 { // 5% decline threshold
            return .declining
        } else {
            return .maintaining
        }
    }
    
    // MARK: - Helper Functions
    private static func parseGoal(from goalString: String) -> (amount: Int, unit: String)? {
        let components = goalString.components(separatedBy: " ")
        guard components.count >= 2,
              let amount = Int(components[0]) else {
            return nil
        }
        
        let unit = components[1]
        return (amount: amount, unit: unit)
    }
}
