import Foundation

// MARK: - Calendar Extension for Leap Year
extension Calendar {
    func isLeapYear(_ year: Int) -> Bool {
        let date = self.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let daysInYear = self.range(of: .day, in: .year, for: date)?.count ?? 365
        return daysInYear == 366
    }
}

// MARK: - Streak Data Calculator
class StreakDataCalculator {
    
    // MARK: - Performance Optimization: Caching
    private static let cacheManager = CacheManager<String, [(intensity: Int, isScheduled: Bool, completionPercentage: Double)]>(maxCacheSize: 50, expirationInterval: 300, cleanupInterval: 60)
    
    // MARK: - Best Streak Calculation
    /// Calculates the best streak from habit history, excluding vacation days
    static func calculateBestStreakFromHistory(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = habit.startDate
        let vacationManager = VacationManager.shared
        
        var maxStreak = 0
        var currentStreak = 0
        var currentDate = startDate
        
        // Iterate through all dates from habit start to today
        while currentDate <= today {
            // Skip vacation days during active vacation - they don't count toward or break streaks
            if vacationManager.isActive && vacationManager.isVacationDay(currentDate) {
                // Move to next day without affecting streak
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                continue
            }
            
            if habit.isCompleted(for: currentDate) {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return maxStreak
    }
    
    // MARK: - Overall Streak Calculation (All Habits Must Be Completed)
    
    /// Calculates the overall streak only when ALL habits are completed for each day
    /// This is the correct behavior: streaks should only increment when all daily habits are done
    private static func calculateOverallStreakWhenAllCompleted(from habits: [Habit], calendar: Calendar, today: Date) -> Int {
        guard !habits.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = today
        
        // Count consecutive days backwards from today where ALL habits were completed
        while true {
            // Check if all habits were completed on this date
            let allCompletedOnThisDate = habits.allSatisfy { habit in
                habit.isCompleted(for: currentDate)
            }
            
            if allCompletedOnThisDate {
                streak += 1
                // Move to previous day
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                // Stop counting when we hit a day where not all habits were completed
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Streak Statistics
    static func calculateStreakStatistics(from habits: [Habit]) -> StreakStatistics {
        guard !habits.isEmpty else {
            return StreakStatistics(
                currentStreak: 0,
                bestStreak: 0,
                averageStreak: 0,
                completionRate: 0,
                consistencyRate: 0
            )
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate current streak - only count when ALL habits are completed
        let currentStreak = calculateOverallStreakWhenAllCompleted(from: habits, calendar: calendar, today: today)
        
        // Calculate best streak - find the longest consecutive streak in history
        let bestStreak = habits.map { calculateBestStreakFromHistory(for: $0) }.max() ?? 0
        
        // Calculate average streak - average of best streaks from each habit
        let totalBestStreak = habits.reduce(0) { $0 + calculateBestStreakFromHistory(for: $1) }
        let averageStreak = totalBestStreak / habits.count
        
        // Calculate completion rate (exclude vacation days)
        let vacationManager = VacationManager.shared
        let completedHabitsToday = habits.filter { 
            !(vacationManager.isActive && vacationManager.isVacationDay(today)) && $0.isCompleted(for: today) 
        }.count
        let completionRate = (completedHabitsToday * 100) / habits.count
        
        // Calculate consistency rate
        let consistencyRate = calculateConsistencyRate(for: habits, calendar: calendar, today: today)
        
        return StreakStatistics(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            averageStreak: averageStreak,
            completionRate: completionRate,
            consistencyRate: consistencyRate
        )
    }
    
    private static func calculateConsistencyRate(for habits: [Habit], calendar: Calendar, today: Date) -> Int {
        let vacationManager = VacationManager.shared
        let last7Days = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
        
        // Filter out vacation days during active vacation from the calculation
        let nonVacationDays = last7Days.filter { !(vacationManager.isActive && vacationManager.isVacationDay($0)) }
        
        let totalCompletions = nonVacationDays.reduce(0) { total, date in
            total + habits.filter { $0.isCompleted(for: date) }.count
        }
        
        // Only count non-vacation days in the total possible
        let totalPossible = habits.count * nonVacationDays.count
        return totalPossible > 0 ? (totalCompletions * 100) / totalPossible : 0
    }
    
    // MARK: - Yearly Heatmap Data
    
    /// Generate yearly heatmap data for habits using the new completion percentage system
    static func generateYearlyDataFromHabits(_ habits: [Habit]) -> [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return generateYearlyDataFromHabits(habits, forYear: currentYear)
    }
    
    /// Generate yearly heatmap data for habits for a specific year
    static func generateYearlyDataFromHabits(_ habits: [Habit], forYear year: Int) -> [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] {
        var yearlyData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] = []
        
        print("🔍 YEARLY DATA GENERATION - Starting for \(habits.count) habits, year \(year)")
        
        for (habitIndex, habit) in habits.enumerated() {
            var habitYearlyData: [(intensity: Int, isScheduled: Bool, completionPercentage: Double)] = []
            
            let calendar = Calendar.current
            
            // Create date components for January 1st of the specified year
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            
            guard let yearStartDate = calendar.date(from: components) else { 
                print("🔍 YEARLY DATA ERROR - Could not create start date for year \(year)")
                continue 
            }
            
            // Handle leap years - use 366 days for leap years, 365 for regular years
            let isLeapYear = calendar.isLeapYear(year)
            let daysInYear = isLeapYear ? 366 : 365
            
            print("🔍 YEARLY DATA DEBUG - Habit \(habitIndex): '\(habit.name)', \(daysInYear) days, leap year: \(isLeapYear)")
            
            // Generate data for each day of the year
            for day in 0..<daysInYear {
                let targetDate = calendar.date(byAdding: .day, value: day, to: yearStartDate) ?? yearStartDate
                let heatmapData = getYearlyHeatmapData(for: habit, dayIndex: day, targetDate: targetDate)
                habitYearlyData.append(heatmapData)
            }
            
            yearlyData.append(habitYearlyData)
            print("🔍 YEARLY DATA DEBUG - Habit \(habitIndex): Generated \(habitYearlyData.count) days of data")
        }
        
        print("🔍 YEARLY DATA GENERATION - Completed: \(yearlyData.count) habits, \(yearlyData.first?.count ?? 0) days per habit")
        return yearlyData
    }
    
    /// Get yearly heatmap data for a specific habit and day
    static func getYearlyHeatmapData(for habit: Habit, dayIndex: Int, targetDate: Date) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        
        // Check if habit was created before this date
        if targetDate < calendar.startOfDay(for: habit.startDate) {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Check if habit should be scheduled on this date
        let isScheduled = shouldShowHabitOnDate(habit, date: targetDate)
        
        // Get completion percentage for this date
        let completionPercentage = calculateCompletionPercentage(for: habit, date: targetDate)
        
        // Debug: Print heatmap data for troubleshooting
        let dateKey = DateUtils.dateKey(for: targetDate)
        let actualProgress = habit.getProgress(for: targetDate)
        print("🔍 YEARLY HEATMAP DEBUG - Habit: '\(habit.name)' | Date: \(dateKey) | DayIndex: \(dayIndex) | Scheduled: \(isScheduled) | Progress: \(completionPercentage)% | ActualProgress: \(actualProgress)")
        
        // If not scheduled, return 0 intensity and 0% completion
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Map completion percentage to intensity for backward compatibility
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
    
    // MARK: - Weekly Heatmap Data
    static func getWeeklyHeatmapIntensity(for habit: Habit, dayIndex: Int, weekStartDate: Date) -> Int {
        let calendar = Calendar.current
        let weekStart = calendar.startOfDay(for: weekStartDate)
        
        // Calculate the date for this day index (0 = Monday, 6 = Sunday)
        let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
        
        // Check if habit was completed on this date
        if habit.isCompleted(for: targetDate) {
            return 3 // High intensity for completed days
        }
        
        // Check if habit should have been scheduled on this date
        if shouldShowHabitOnDate(habit, date: targetDate) {
            return 1 // Low intensity for scheduled but not completed days
        }
        
        return 0 // No intensity for non-scheduled days
    }
    
    static func getWeeklyHeatmapData(for habit: Habit, dayIndex: Int, weekStartDate: Date) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let weekStart = calendar.startOfDay(for: weekStartDate)
        
        // Calculate the date for this day index (0 = Monday, 6 = Sunday)
        // Since weekStartDate is already Monday, we can directly add the dayIndex
        let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
        
        // Check if habit should be scheduled on this date
        let isScheduled = shouldShowHabitOnDate(habit, date: targetDate)
        
        // Get completion percentage for this date
        let completionPercentage = calculateCompletionPercentage(for: habit, date: targetDate)
        
        // Debug: Print heatmap data for troubleshooting
        let dateKey = DateUtils.dateKey(for: targetDate)
        let actualProgress = habit.getProgress(for: targetDate)
        let weekday = calendar.component(.weekday, from: targetDate)
        print("🔍 HEATMAP DEBUG - Habit: '\(habit.name)' | Date: \(dateKey) | DayIndex: \(dayIndex) | Weekday: \(weekday) | Scheduled: \(isScheduled) | Progress: \(completionPercentage)% | ActualProgress: \(actualProgress) | CompletionHistory: \(habit.completionHistory[dateKey] ?? 0)")
        
        // Additional debug for color mapping
        if isScheduled && completionPercentage > 0 {
            print("🔍 COLOR MAPPING DEBUG - Habit: '\(habit.name)' | Date: \(dateKey) | Completion: \(completionPercentage)% | Will show color for: \(completionPercentage >= 100.0 ? "100% (green600)" : "\(completionPercentage)% (gradient)")")
        }
        
        // If not scheduled, return 0 intensity and 0% completion
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Map completion percentage to intensity for backward compatibility
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
    
    static func getWeeklyTotalIntensity(dayIndex: Int, habits: [Habit], weekStartDate: Date) -> Int {
        let totalIntensity = habits.reduce(0) { total, habit in
            total + getWeeklyHeatmapIntensity(for: habit, dayIndex: dayIndex, weekStartDate: weekStartDate)
        }
        return min(totalIntensity, 3)
    }
    
    static func getWeeklyTotalHeatmapData(dayIndex: Int, habits: [Habit], weekStartDate: Date) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let weekStart = calendar.startOfDay(for: weekStartDate)
        let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
        
        // Check if any habit is scheduled for this day
        let scheduledHabits = habits.filter { shouldShowHabitOnDate($0, date: targetDate) }
        let isScheduled = !scheduledHabits.isEmpty
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Calculate average completion percentage from scheduled habits
        let totalCompletion = scheduledHabits.reduce(0.0) { total, habit in
            total + calculateCompletionPercentage(for: habit, date: targetDate)
        }
        let averageCompletion = scheduledHabits.isEmpty ? 0.0 : totalCompletion / Double(scheduledHabits.count)
        
        // Debug: Print total heatmap data
        let dateKey = DateUtils.dateKey(for: targetDate)
        let weekday = calendar.component(.weekday, from: targetDate)
        print("🔍 TOTAL HEATMAP DEBUG - Date: \(dateKey) | DayIndex: \(dayIndex) | Weekday: \(weekday) | Scheduled Habits: \(scheduledHabits.count) | Average Completion: \(averageCompletion)%")
        
        // Map completion percentage to intensity for backward compatibility
        let intensity: Int
        if averageCompletion == 0 {
            intensity = 0
        } else if averageCompletion < 25 {
            intensity = 1
        } else if averageCompletion < 50 {
            intensity = 2
        } else {
            intensity = 3
        }
        
        return (intensity: intensity, isScheduled: true, completionPercentage: averageCompletion)
    }
    
    // MARK: - Monthly Heatmap Data
    static func getMonthlyHeatmapIntensity(weekIndex: Int, dayIndex: Int, habits: [Habit]) -> Int {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this week and day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weeksToSubtract = weekIndex
        let daysToSubtract = daysFromMonday - dayIndex + (weeksToSubtract * 7)
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Count completed habits for this date
        let completedCount = habits.filter { $0.isCompleted(for: targetDate) }.count
        return min(completedCount, 3)
    }
    
    static func getMonthlyHeatmapData(weekIndex: Int, dayIndex: Int, habits: [Habit]) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this week and day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weeksToSubtract = weekIndex
        let daysToSubtract = daysFromMonday - dayIndex + (weeksToSubtract * 7)
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Check if any habit is scheduled for this date
        let scheduledHabits = habits.filter { shouldShowHabitOnDate($0, date: targetDate) }
        let isScheduled = !scheduledHabits.isEmpty
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Calculate average completion percentage from scheduled habits
        let totalCompletion = scheduledHabits.reduce(0.0) { total, habit in
            total + calculateCompletionPercentage(for: habit, date: targetDate)
        }
        let averageCompletion = scheduledHabits.isEmpty ? 0.0 : totalCompletion / Double(scheduledHabits.count)
        
        // Map completion percentage to intensity for backward compatibility
        let intensity: Int
        if averageCompletion == 0 {
            intensity = 0
        } else if averageCompletion < 25 {
            intensity = 1
        } else if averageCompletion < 50 {
            intensity = 2
        } else {
            intensity = 3
        }
        
        return (intensity: intensity, isScheduled: true, completionPercentage: averageCompletion)
    }
    
    // MARK: - Individual Habit Monthly Heatmap Data
    static func getMonthlyHeatmapDataForHabit(habit: Habit, weekIndex: Int, dayIndex: Int) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this week and day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weeksToSubtract = weekIndex
        let daysToSubtract = daysFromMonday - dayIndex + (weeksToSubtract * 7)
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Check if this specific habit is scheduled for this date
        let isScheduled = shouldShowHabitOnDate(habit, date: targetDate)
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Get completion percentage for this specific habit on this date
        let completionPercentage = calculateCompletionPercentage(for: habit, date: targetDate)
        
        // Map completion percentage to intensity for backward compatibility
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
    
    // MARK: - Individual Habit Weekly Heatmap Data (for selected week)
    static func getWeeklyHeatmapDataForHabit(habit: Habit, weekIndex: Int, dayIndex: Int, selectedWeekStartDate: Date) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        
        // Calculate the date for this week and day based on selected week start
        let targetDate = calendar.date(byAdding: .day, value: (weekIndex * 7) + dayIndex, to: selectedWeekStartDate) ?? selectedWeekStartDate
        
        // Check if this specific habit is scheduled for this date
        let isScheduled = shouldShowHabitOnDate(habit, date: targetDate)
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Get completion percentage for this specific habit on this date
        let completionPercentage = calculateCompletionPercentage(for: habit, date: targetDate)
        
        // Map completion percentage to intensity for backward compatibility
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
    
    static func getMonthlyTotalIntensity(dayIndex: Int, habits: [Habit]) -> Int {
        let totalIntensity = habits.reduce(0) { total, habit in
            total + getMonthlyHeatmapIntensity(weekIndex: 0, dayIndex: dayIndex, habits: habits)
        }
        return min(totalIntensity, 3)
    }
    
    static func getMonthlyTotalHeatmapData(dayIndex: Int, habits: [Habit]) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let daysToSubtract = daysFromMonday - dayIndex
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Check if any habit is scheduled for this date
        let scheduledHabits = habits.filter { shouldShowHabitOnDate($0, date: targetDate) }
        let isScheduled = !scheduledHabits.isEmpty
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Calculate average completion percentage from scheduled habits
        let totalCompletion = scheduledHabits.reduce(0.0) { total, habit in
            total + calculateCompletionPercentage(for: habit, date: targetDate)
        }
        let averageCompletion = scheduledHabits.isEmpty ? 0.0 : totalCompletion / Double(scheduledHabits.count)
        
        // Map completion percentage to intensity for backward compatibility
        let intensity: Int
        if averageCompletion == 0 {
            intensity = 0
        } else if averageCompletion < 25 {
            intensity = 1
        } else if averageCompletion < 50 {
            intensity = 2
        } else {
            intensity = 3
        }
        
        return (intensity: intensity, isScheduled: true, completionPercentage: averageCompletion)
    }
    
    // MARK: - Monthly Total Heatmap Data (Updated for Weekly Structure)
    static func getMonthlyTotalHeatmapDataForWeek(weekIndex: Int, dayIndex: Int, habits: [Habit]) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double) {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this week and day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weeksToSubtract = weekIndex
        let daysToSubtract = daysFromMonday - dayIndex + (weeksToSubtract * 7)
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Check if any habit is scheduled for this date
        let scheduledHabits = habits.filter { shouldShowHabitOnDate($0, date: targetDate) }
        let isScheduled = !scheduledHabits.isEmpty
        
        if !isScheduled {
            return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
        }
        
        // Calculate average completion percentage from scheduled habits
        let totalCompletion = scheduledHabits.reduce(0.0) { total, habit in
            total + calculateCompletionPercentage(for: habit, date: targetDate)
        }
        let averageCompletion = scheduledHabits.isEmpty ? 0.0 : totalCompletion / Double(scheduledHabits.count)
        
        // Map completion percentage to intensity for backward compatibility
        let intensity: Int
        if averageCompletion == 0 {
            intensity = 0
        } else if averageCompletion < 25 {
            intensity = 1
        } else if averageCompletion < 50 {
            intensity = 2
        } else {
            intensity = 3
        }
        
        return (intensity: intensity, isScheduled: true, completionPercentage: averageCompletion)
    }
    
    // MARK: - Schedule Helper Functions
    static func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let dateKey = DateUtils.dateKey(for: date)
        
        // Check if the date is before the habit start date
        if date < calendar.startOfDay(for: habit.startDate) {
            print("🔍 SCHEDULE DEBUG - Habit '\(habit.name)' not shown on \(dateKey): Date before start date")
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        if let endDate = habit.endDate, date > calendar.startOfDay(for: endDate) {
            print("🔍 SCHEDULE DEBUG - Habit '\(habit.name)' not shown on \(dateKey): Date after end date")
            return false
        }
        
        // Check if it's a vacation day AND vacation is currently active - habits should not be shown during active vacation
        let vacationManager = VacationManager.shared
        if vacationManager.isActive && vacationManager.isVacationDay(date) {
            print("🔍 SCHEDULE DEBUG - Habit '\(habit.name)' not shown on \(dateKey): Active vacation day")
            return false
        }
        
        // Check if the habit is scheduled for this weekday
        let isScheduledForWeekday = isHabitScheduledForWeekday(habit, weekday: weekday, targetDate: date)
        
        print("🔍 SCHEDULE DEBUG - Habit '\(habit.name)' | Date: \(dateKey) | Weekday: \(weekday) | Schedule: '\(habit.schedule)' | Scheduled for weekday: \(isScheduledForWeekday)")
        
        if !isScheduledForWeekday {
            print("🔍 SCHEDULE DEBUG - Habit '\(habit.name)' not shown on \(dateKey): Not scheduled for weekday \(weekday)")
        }
        
        return isScheduledForWeekday
    }
    
    // MARK: - Completion Percentage Calculation
    static func calculateCompletionPercentage(for habit: Habit, date: Date) -> Double {
        let actualProgress = habit.getProgress(for: date)
        let goalAmount = parseGoalAmount(from: habit.goal)
        
        // If no goal amount specified, treat as binary completion (0% or 100%)
        if goalAmount <= 0 {
            return actualProgress > 0 ? 100.0 : 0.0
        }
        
        // Calculate percentage based on actual progress vs goal
        let percentage = (Double(actualProgress) / Double(goalAmount)) * 100.0
        let clampedPercentage = max(0.0, min(100.0, percentage))
        
        print("🔍 COMPLETION PERCENTAGE DEBUG - Habit '\(habit.name)' | Date: \(DateUtils.dateKey(for: date)) | Actual: \(actualProgress) | Goal: \(goalAmount) | Percentage: \(percentage)% | Clamped: \(clampedPercentage)%")
        
        return clampedPercentage
    }
    
    static func parseGoalAmount(from goalString: String) -> Int {
        // Parse goal strings like "1 time on everyday", "5 sessions per week", etc.
        let components = goalString.lowercased().components(separatedBy: " ")
        guard let firstComponent = components.first else { return 0 }
        
        // Try to extract the number from the first component
        if let amount = Int(firstComponent) {
            return amount
        }
        
        // If no number found, default to 1 (binary completion)
        return 1
    }
    
    private static func isHabitScheduledForWeekday(_ habit: Habit, weekday: Int, targetDate: Date) -> Bool {
        let schedule = habit.schedule.lowercased()
        
        print("🔍 WEEKDAY SCHEDULE DEBUG - Habit '\(habit.name)' | Weekday: \(weekday) | Schedule: '\(schedule)'")
        
        // Check if schedule contains multiple weekdays separated by commas
        if schedule.contains(",") {
            let weekdays = extractWeekdays(from: habit.schedule)
            let isScheduled = weekdays.contains(weekday)
            print("🔍 WEEKDAY SCHEDULE DEBUG - Multiple weekdays detected: \(weekdays) | Contains \(weekday): \(isScheduled)")
            return isScheduled
        }
        
        // Check specific schedule patterns
        switch schedule {
        case "everyday", "every day":
            print("🔍 WEEKDAY SCHEDULE DEBUG - Everyday schedule detected")
            return true
            
        case let s where s.hasPrefix("every ") && s.contains("days"):
            if let dayCount = extractDayCount(from: s) {
                let calendar = Calendar.current
                let startDate = calendar.startOfDay(for: habit.startDate)
                let targetDateStart = calendar.startOfDay(for: targetDate)
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: targetDateStart).day ?? 0
                let isScheduled = daysSinceStart >= 0 && daysSinceStart % dayCount == 0
                print("🔍 WEEKDAY SCHEDULE DEBUG - Every \(dayCount) days schedule | Target date: \(targetDateStart) | Days since start: \(daysSinceStart) | Scheduled: \(isScheduled)")
                return isScheduled
            }
            print("🔍 WEEKDAY SCHEDULE DEBUG - Failed to parse 'every X days' schedule")
            return false
            
        case let s where s.hasPrefix("every ") && !s.contains("days"):
            let weekdays = extractWeekdays(from: habit.schedule)
            let isScheduled = weekdays.contains(weekday)
            print("🔍 WEEKDAY SCHEDULE DEBUG - Specific weekdays: \(weekdays) | Contains \(weekday): \(isScheduled)")
            return isScheduled
            
        case let s where s.contains("times a week"):
            if let timesPerWeek = extractTimesPerWeek(from: s) {
                let calendar = Calendar.current
                let startDate = calendar.startOfDay(for: habit.startDate)
                let targetDateStart = calendar.startOfDay(for: targetDate)
                let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startDate, to: targetDateStart).weekOfYear ?? 0
                let isScheduled = weeksSinceStart >= 0 && weeksSinceStart % timesPerWeek == 0
                print("🔍 WEEKDAY SCHEDULE DEBUG - \(timesPerWeek) times per week | Weeks since start: \(weeksSinceStart) | Scheduled: \(isScheduled)")
                return isScheduled
            }
            print("🔍 WEEKDAY SCHEDULE DEBUG - Failed to parse 'X times a week' schedule")
            return false
            
        case let s where s.contains("days a week"):
            if let daysPerWeek = extractDaysPerWeek(from: s) {
                let calendar = Calendar.current
                let startDate = calendar.startOfDay(for: habit.startDate)
                let targetDateStart = calendar.startOfDay(for: targetDate)
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: targetDateStart).day ?? 0
                let isScheduled = daysSinceStart >= 0 && daysSinceStart % daysPerWeek == 0
                print("🔍 WEEKDAY SCHEDULE DEBUG - \(daysPerWeek) days a week | Days since start: \(daysSinceStart) | Scheduled: \(isScheduled)")
                return isScheduled
            }
            print("🔍 WEEKDAY SCHEDULE DEBUG - Failed to parse 'X days a week' schedule")
            return false
            
        default:
            // For any unrecognized schedule format, don't show the habit (safer default)
            print("🔍 WEEKDAY SCHEDULE DEBUG - Unrecognized schedule format: '\(schedule)'")
            return false
        }
    }
    
    private static func extractDayCount(from schedule: String) -> Int? {
        let pattern = #"Every (\d+) days?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) {
            let range = match.range(at: 1)
            let numberString = (schedule as NSString).substring(with: range)
            return Int(numberString)
        }
        return nil
    }
    
    private static func extractWeekdays(from schedule: String) -> Set<Int> {
        var weekdays: Set<Int> = []
        // Use weekday names that match the schedule strings
        let weekdayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let lowercasedSchedule = schedule.lowercased()
        
        print("🔍 STREAK WEEKDAY EXTRACTION - Input schedule: '\(schedule)'")
        print("🔍 STREAK WEEKDAY EXTRACTION - Lowercased: '\(lowercasedSchedule)'")
        
        for (index, dayName) in weekdayNames.enumerated() {
            let contains = lowercasedSchedule.contains(dayName)
            if contains {
                // Map to Calendar.current weekday numbers (Monday = 2, Sunday = 1)
                let weekdayNumber = index == 6 ? 1 : index + 2 // Sunday = 1, Monday = 2, etc.
                weekdays.insert(weekdayNumber)
                print("🔍 STREAK WEEKDAY EXTRACTION - Found '\(dayName)' (index \(index)) → weekday \(weekdayNumber)")
            } else {
                print("🔍 STREAK WEEKDAY EXTRACTION - '\(dayName)' not found in schedule")
            }
        }
        
        print("🔍 STREAK WEEKDAY EXTRACTION - Final weekdays: \(weekdays)")
        return weekdays
    }
    
    private static func extractTimesPerWeek(from schedule: String) -> Int? {
        let pattern = #"(\d+)\s+times\s+a\s+week"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    private static func extractDaysPerWeek(from schedule: String) -> Int? {
        let pattern = #"(\d+)\s+days\s+a\s+week"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    // MARK: - Cache Management
    static func clearCache() {
        cacheManager.clear()
    }
    
    static func invalidateCacheForHabit(_ habitId: UUID) {
        // Remove all cached data for this habit across all years
        // Since we can't iterate through keys, we'll clear the entire cache
        // This is a limitation of the current cache implementation
        cacheManager.clear()
    }
    
    /// Async version of generateYearlyDataFromHabits for background processing
    static func generateYearlyDataFromHabitsAsync(
        _ habits: [Habit], 
        startIndex: Int, 
        itemsPerPage: Int,
        forYear year: Int = Calendar.current.component(.year, from: Date()),
        progress: @escaping (Double) -> Void = { _ in }
    ) async -> [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Performance optimization: Check cache first (year-specific)
                let cachedData = habits.compactMap { habit in
                    cacheManager.get(forKey: "\(habit.id.uuidString)_\(year)")
                }
                
                if !cachedData.isEmpty && cachedData.count == habits.count {
                    // Return cached data for the requested range
                    let endIndex = min(startIndex + itemsPerPage, cachedData.count)
                    let result = Array(cachedData[startIndex..<endIndex])
                    continuation.resume(returning: result)
                    return
                }
                
                // Cache miss or expired - calculate new data
                var yearlyData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] = []
                let endIndex = min(startIndex + itemsPerPage, habits.count)
                let habitsToProcess = Array(habits[startIndex..<endIndex])
                
                print("🔍 ASYNC YEARLY DATA GENERATION - Processing \(habitsToProcess.count) habits (start: \(startIndex), end: \(endIndex))")
                
                for (index, habit) in habitsToProcess.enumerated() {
                    var habitYearlyData: [(intensity: Int, isScheduled: Bool, completionPercentage: Double)] = []
                    
                    let calendar = Calendar.current
                    
                    // Create date components for January 1st of the specified year
                    var components = DateComponents()
                    components.year = year
                    components.month = 1
                    components.day = 1
                    
                    guard let yearStartDate = calendar.date(from: components) else { 
                        print("🔍 ASYNC YEARLY DATA ERROR - Could not create start date for year \(year)")
                        continue 
                    }
                    
                    // Handle leap years - use 366 days for leap years, 365 for regular years
                    let isLeapYear = calendar.isLeapYear(year)
                    let daysInYear = isLeapYear ? 366 : 365
                    
                    print("🔍 ASYNC YEARLY DATA DEBUG - Habit \(index): '\(habit.name)', \(daysInYear) days, leap year: \(isLeapYear)")
                    
                    // Generate data for each day of the year
                    for day in 0..<daysInYear {
                        let targetDate = calendar.date(byAdding: .day, value: day, to: yearStartDate) ?? yearStartDate
                        let heatmapData = getYearlyHeatmapData(for: habit, dayIndex: day, targetDate: targetDate)
                        habitYearlyData.append(heatmapData)
                    }
                    
                    yearlyData.append(habitYearlyData)
                    
                    // Cache this habit's data for future use (year-specific)
                    cacheManager.set(habitYearlyData, forKey: "\(habit.id.uuidString)_\(year)")
                    
                    print("🔍 ASYNC YEARLY DATA DEBUG - Habit \(index): Generated \(habitYearlyData.count) days of data")
                    
                    // Report progress
                    let progressValue = Double(index + 1) / Double(habitsToProcess.count)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                }
                
                print("🔍 ASYNC YEARLY DATA GENERATION - Completed: \(yearlyData.count) habits, \(yearlyData.first?.count ?? 0) days per habit")
                continuation.resume(returning: yearlyData)
            }
        }
    }
    
    /// Async version of calculateStreakStatistics for background processing
    static func calculateStreakStatisticsAsync(
        from habits: [Habit],
        progress: @escaping (Double) -> Void = { _ in }
    ) async -> StreakStatistics {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard !habits.isEmpty else {
                    let result = StreakStatistics(
                        currentStreak: 0,
                        bestStreak: 0,
                        averageStreak: 0,
                        completionRate: 0,
                        consistencyRate: 0
                    )
                    continuation.resume(returning: result)
                    return
                }
                
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                // Calculate current streak - only count when ALL habits are completed
                let currentStreak = calculateOverallStreakWhenAllCompleted(from: habits, calendar: calendar, today: today)
                
                DispatchQueue.main.async {
                    progress(0.2)
                }
                
                // Calculate best streak - find the longest consecutive streak in history
                let bestStreak = habits.map { calculateBestStreakFromHistory(for: $0) }.max() ?? 0
                
                DispatchQueue.main.async {
                    progress(0.4)
                }
                
                // Calculate average streak - average of best streaks from each habit
                let totalBestStreak = habits.reduce(0) { $0 + calculateBestStreakFromHistory(for: $1) }
                let averageStreak = totalBestStreak / habits.count
                
                DispatchQueue.main.async {
                    progress(0.6)
                }
                
                // Calculate completion rate
                let completedHabitsToday = habits.filter { $0.isCompleted(for: today) }.count
                let completionRate = (completedHabitsToday * 100) / habits.count
                
                DispatchQueue.main.async {
                    progress(0.8)
                }
                
                // Calculate consistency rate
                let consistencyRate = calculateConsistencyRate(for: habits, calendar: calendar, today: today)
                
                DispatchQueue.main.async {
                    progress(1.0)
                }
                
                let result = StreakStatistics(
                    currentStreak: currentStreak,
                    bestStreak: bestStreak,
                    averageStreak: averageStreak,
                    completionRate: completionRate,
                    consistencyRate: consistencyRate
                )
                
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Data Models
struct StreakStatistics {
    let currentStreak: Int
    let bestStreak: Int
    let averageStreak: Int
    let completionRate: Int
    let consistencyRate: Int
} 