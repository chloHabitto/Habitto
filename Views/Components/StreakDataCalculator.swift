import Foundation

// MARK: - Streak Data Calculator
class StreakDataCalculator {
    
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
        
        // Calculate current streak
        let totalCurrentStreak = habits.reduce(0) { $0 + $1.calculateTrueStreak() }
        let currentStreak = totalCurrentStreak / habits.count
        
        // Calculate best streak
        let bestStreak = habits.map { $0.calculateTrueStreak() }.max() ?? 0
        
        // Calculate average streak
        let totalStreak = habits.reduce(0) { $0 + $1.calculateTrueStreak() }
        let averageStreak = totalStreak / habits.count
        
        // Calculate completion rate
        let completedHabitsToday = habits.filter { $0.isCompleted(for: today) }.count
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
        let last7Days = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
        
        let totalCompletions = last7Days.reduce(0) { total, date in
            total + habits.filter { $0.isCompleted(for: date) }.count
        }
        
        let totalPossible = habits.count * 7
        return totalPossible > 0 ? (totalCompletions * 100) / totalPossible : 0
    }
    
    // MARK: - Heatmap Data Generation
    static func generateYearlyDataFromHabits(_ habits: [Habit], startIndex: Int, itemsPerPage: Int) -> [[Int]] {
        var yearlyData: [[Int]] = []
        
        let endIndex = min(startIndex + itemsPerPage, habits.count)
        let habitsToProcess = Array(habits[startIndex..<endIndex])
        
        for habit in habitsToProcess {
            var habitYearlyData: [Int] = []
            
            let calendar = Calendar.current
            let today = Calendar.current.startOfDay(for: Date())
            
            for day in 0..<365 {
                let targetDate = calendar.date(byAdding: .day, value: day - 364, to: today) ?? today
                let intensity = generateYearlyIntensity(for: habit, date: targetDate)
                habitYearlyData.append(intensity)
            }
            
            yearlyData.append(habitYearlyData)
        }
        
        return yearlyData
    }
    
    private static func generateYearlyIntensity(for habit: Habit, date: Date) -> Int {
        let calendar = Calendar.current
        
        // Check if habit was created before this date
        if date < calendar.startOfDay(for: habit.startDate) {
            return 0
        }
        
        // Check if habit was completed on this date
        if habit.isCompleted(for: date) {
            return 3 // High intensity for completed days
        }
        
        // Check if habit should have been scheduled on this date
        if shouldShowHabitOnDate(habit, date: date) {
            return 1 // Low intensity for scheduled but not completed days
        }
        
        return 0 // No intensity for non-scheduled days
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
    
    static func getWeeklyTotalIntensity(dayIndex: Int, habits: [Habit], weekStartDate: Date) -> Int {
        let totalIntensity = habits.reduce(0) { total, habit in
            total + getWeeklyHeatmapIntensity(for: habit, dayIndex: dayIndex, weekStartDate: weekStartDate)
        }
        return min(totalIntensity, 3)
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
    
    static func getMonthlyTotalIntensity(dayIndex: Int, habits: [Habit]) -> Int {
        let totalIntensity = habits.reduce(0) { total, habit in
            total + getMonthlyHeatmapIntensity(weekIndex: 0, dayIndex: dayIndex, habits: habits)
        }
        return min(totalIntensity, 3)
    }
    
    // MARK: - Schedule Helper Functions
    private static func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if the date is before the habit start date
        if date < calendar.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        if let endDate = habit.endDate, date > calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate {
            return false
        }
        
        switch habit.schedule {
        case "Everyday":
            return true
            
        case let schedule where schedule.hasPrefix("Every ") && schedule.contains("days"):
            if let dayCount = extractDayCount(from: schedule) {
                let startDate = calendar.startOfDay(for: habit.startDate)
                let selectedDate = calendar.startOfDay(for: date)
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: selectedDate).day ?? 0
                return daysSinceStart >= 0 && daysSinceStart % dayCount == 0
            }
            return false
            
        case let schedule where schedule.hasPrefix("Every ") && !schedule.contains("days"):
            let weekdays = extractWeekdays(from: schedule)
            return weekdays.contains(weekday)
            
        case let schedule where schedule.contains("times a week"):
            if let timesPerWeek = extractTimesPerWeek(from: schedule) {
                let startDate = calendar.startOfDay(for: habit.startDate)
                let selectedDate = calendar.startOfDay(for: date)
                let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startDate, to: selectedDate).weekOfYear ?? 0
                return weeksSinceStart >= 0 && weeksSinceStart % timesPerWeek == 0
            }
            return false
            
        default:
            return true
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
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        
        for (index, dayName) in weekdayNames.enumerated() {
            if schedule.contains(dayName) {
                weekdays.insert(index + 1)
            }
        }
        
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
}

// MARK: - Data Models
struct StreakStatistics {
    let currentStreak: Int
    let bestStreak: Int
    let averageStreak: Int
    let completionRate: Int
    let consistencyRate: Int
} 