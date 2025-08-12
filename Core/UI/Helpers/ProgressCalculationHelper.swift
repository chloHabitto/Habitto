import Foundation

class ProgressCalculationHelper {
    
    // MARK: - Goal Parsing
    static func parseGoalAmount(from goalString: String) -> Int {
        return StreakDataCalculator.parseGoalAmount(from: goalString)
    }
    
    static func parseGoal(from goalString: String) -> Goal? {
        let components = goalString.lowercased().components(separatedBy: " ")
        guard components.count >= 2,
              let amount = Double(components[0]),
              let unit = components.last else { return nil }
        
        return Goal(amount: amount, unit: unit)
    }
    
    // MARK: - Day Progress Calculations
    static func getDayProgress(day: Int, currentDate: Date, habits: [Habit], selectedHabitType: HabitType, selectedHabit: Habit?) -> Double {
        let calendar = Calendar.current
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) else {
            return 0.0
        }
        
        let habitsForDay: [Habit]
        
        if let selectedHabit = selectedHabit {
            habitsForDay = [selectedHabit]
        } else {
            habitsForDay = habits.filter { $0.habitType == selectedHabitType }
        }
        
        guard !habitsForDay.isEmpty else { return 0.0 }
        
        var totalProgress = 0.0
        var totalGoal = 0.0
        
        for habit in habitsForDay {
            let shouldShow = StreakDataCalculator.shouldShowHabitOnDate(habit, date: dateForDay)
            let goalAmount = parseGoalAmount(from: habit.goal)
            let progress = habit.getProgress(for: dateForDay)
            
            if shouldShow {
                totalGoal += Double(goalAmount)
                totalProgress += Double(progress)
            }
        }
        
        return totalGoal == 0 ? 0.0 : min(totalProgress / totalGoal, 1.0)
    }
    
    static func getDayProgress(for date: Date, habits: [Habit], selectedHabitType: HabitType, selectedHabit: Habit?) -> Double {
        let habitsForDay: [Habit]
        
        if let selectedHabit = selectedHabit {
            habitsForDay = [selectedHabit]
        } else {
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
    
    static func monthlyCompletionRate(habits: [Habit], currentDate: Date, selectedHabitType: HabitType, selectedHabit: Habit?) -> Double {
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
            habitsToCalculate = [selectedHabit]
        } else {
            habitsToCalculate = habits.filter({ $0.habitType == selectedHabitType })
        }
        
        for habit in habitsToCalculate {
            var habitProgress = 0.0
            var habitGoals = 0.0
            
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
    
    static func previousMonthCompletionRate(habits: [Habit], currentDate: Date, selectedHabitType: HabitType) -> Double {
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
    
    // MARK: - Weekly Progress Calculations
    static func currentWeekCompletionRate(habits: [Habit], selectedHabitType: HabitType) -> Double {
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
    
    static func previousWeekCompletionRate(habits: [Habit], selectedHabitType: HabitType) -> Double {
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
    
    // MARK: - Today's Progress Calculations
    static func todaysActualCompletionPercentage(habits: [Habit]) -> Double {
        guard !habits.isEmpty else { return 0.0 }
        
        let today = Date()
        let totalProgress = habits.reduce(0.0) { sum, habit in
            let todayProgress = habit.getProgress(for: today)
            
            if let goal = parseGoal(from: habit.goal) {
                let habitCompletion = min(Double(todayProgress) / goal.amount, 1.0)
                return sum + habitCompletion
            } else {
                return sum + (todayProgress > 0 ? 1.0 : 0.0)
            }
        }
        
        return totalProgress / Double(habits.count)
    }
    
    // MARK: - Goal Achievement Calculations
    static func monthlyGoalsMet(habits: [Habit], currentDate: Date, selectedHabitType: HabitType) -> Int {
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
    
    static func monthlyCompletedHabits(habits: [Habit], currentDate: Date, selectedHabitType: HabitType) -> Int {
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
    
    static func averageDailyProgress(habits: [Habit], currentDate: Date, selectedHabitType: HabitType, selectedHabit: Habit?) -> Double {
        let filteredHabits: [Habit]
        if let selectedHabit = selectedHabit {
            filteredHabits = [selectedHabit]
        } else {
            filteredHabits = habits.filter { $0.habitType == selectedHabitType }
        }
        
        guard !filteredHabits.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0.0
        }
        
        var totalDailyProgress = 0.0
        var totalDays = 0
        
        var currentDate = monthStart
        while currentDate <= monthEnd {
            let dayProgress = getDayProgress(for: currentDate, habits: habits, selectedHabitType: selectedHabitType, selectedHabit: selectedHabit)
            if dayProgress > 0 {
                totalDailyProgress += dayProgress
                totalDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return totalDays > 0 ? totalDailyProgress / Double(totalDays) : 0.0
    }
}
