import Foundation
import SwiftUI

// MARK: - HabitInstanceLogic

class HabitInstanceLogic {
  // MARK: - Habit Display Logic

  static func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: date)

    // Check if the date is before the habit start date
    if date < DateUtils.startOfDay(for: habit.startDate) {
      return false
    }

    // Check if the date is after the habit end date (if set)
    // Use >= to be inclusive of the end date
    if let endDate = habit.endDate, date > DateUtils.endOfDay(for: endDate) {
      return false
    }

    switch habit.schedule {
    case "Everyday":
      return true

    case "Weekdays":
      let shouldShow = weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
      return shouldShow

    case "Weekends":
      let shouldShow = weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
      return shouldShow

    case "Monday":
      let shouldShow = weekday == 2
      return shouldShow

    case "Tuesday":
      let shouldShow = weekday == 3
      return shouldShow

    case "Wednesday":
      let shouldShow = weekday == 4
      return shouldShow

    case "Thursday":
      let shouldShow = weekday == 5
      return shouldShow

    case "Friday":
      let shouldShow = weekday == 6
      return shouldShow

    case "Saturday":
      let shouldShow = weekday == 7
      return shouldShow

    case "Sunday":
      let shouldShow = weekday == 1
      return shouldShow

    default:
      // Handle custom schedules like "Every Monday, Wednesday, Friday"
      if habit.schedule.lowercased().contains("every"),
         habit.schedule.lowercased().contains("day")
      {
        // First check if it's an "Every X days" schedule
        if let dayCount = extractDayCount(from: habit.schedule) {
          // Handle "Every X days" schedules
          let startDate = DateUtils.startOfDay(for: habit.startDate)
          let targetDate = DateUtils.startOfDay(for: date)
          let daysSinceStart = DateUtils.daysBetween(startDate, targetDate)

          // Check if the target date falls on the schedule
          let shouldShow = daysSinceStart >= 0 && daysSinceStart % dayCount == 0
          return shouldShow
        } else {
          // Extract weekdays from schedule (like "Every Monday, Wednesday, Friday")
          let weekdays = extractWeekdays(from: habit.schedule)
          return weekdays.contains(weekday)
        }
      } else if habit.schedule.contains("days a week") {
        // Handle frequency schedules like "2 days a week"
        return shouldShowHabitWithFrequency(habit: habit, date: date)
      } else if habit.schedule.contains("days a month") {
        // Handle monthly frequency schedules like "3 days a month"
        return shouldShowHabitWithMonthlyFrequency(habit: habit, date: date)
      } else if habit.schedule.contains("times per week") {
        // Handle "X times per week" schedules
        let schedule = habit.schedule.lowercased()
        let timesPerWeek = extractTimesPerWeek(from: schedule)

        if timesPerWeek != nil {
          // For now, show the habit if it's within the week
          // This is a simplified implementation
          let weekStart = DateUtils.startOfWeek(for: date)
          let weekEnd = DateUtils.endOfWeek(for: date)
          let isInWeek = date >= weekStart && date <= weekEnd
          return isInWeek
        }
        return false
      }
      // Check if schedule contains multiple weekdays separated by commas
      if habit.schedule.contains(",") {
        let weekdays = extractWeekdays(from: habit.schedule)
        return weekdays.contains(weekday)
      }
      // For any unrecognized schedule format, don't show the habit (safer default)
      return false
    }
  }

  // MARK: - Schedule Pattern Extraction

  static func extractDayCount(from schedule: String) -> Int? {
    let pattern = #"every (\d+) days?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let numberString = (schedule as NSString).substring(with: range)
    return Int(numberString)
  }

  static func extractWeekdays(from schedule: String) -> Set<Int> {
    // Performance optimization: Use cached weekday names
    var weekdays: Set<Int> = []
    let lowercasedSchedule = schedule.lowercased()

    for (index, dayName) in DateCalendarLogic.weekdayNames.enumerated() {
      let dayNameLower = dayName.lowercased()
      if lowercasedSchedule.contains(dayNameLower) {
        // Calendar weekday is 1-based, where 1 = Sunday
        let weekdayNumber = index + 1
        weekdays.insert(weekdayNumber)
      }
    }

    return weekdays
  }

  static func extractTimesPerWeek(from schedule: String) -> Int? {
    let pattern = #"(\d+) times per week"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let numberString = (schedule as NSString).substring(with: range)
    return Int(numberString)
  }

  static func extractDaysPerWeek(from schedule: String) -> Int? {
    let pattern = #"(\d+) days a week"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let numberString = (schedule as NSString).substring(with: range)
    return Int(numberString)
  }

  // MARK: - Frequency-based Habit Logic

  static func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
    guard let daysPerWeek = extractDaysPerWeek(from: habit.schedule) else {
      return false
    }

    let calendar = Calendar.current
    let targetDate = calendar.startOfDay(for: date)
    let startDate = calendar.startOfDay(for: habit.startDate)

    // ✅ FIX: For frequency-based habits (e.g., "3 days a week"), the habit should appear EVERY day
    // after the start date. The user decides which days to complete it.
    // Completion tracking will hide it once completed the required number of times that week.
    let isAfterStart = targetDate >= startDate
    
    // Check if habit has ended
    if let endDate = habit.endDate {
      let endDateStart = calendar.startOfDay(for: endDate)
      if targetDate > endDateStart {
        return false
      }
    }
    
    return isAfterStart
  }

  static func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
    // ✅ CORRECT LOGIC: "5 days a month" means show for 5 days, distributed across remaining days
    // Example: On Oct 28 with 4 days left, show for min(5 needed, 4 remaining) = 4 days
    let calendar = Calendar.current
    let today = Date()
    let targetDate = DateUtils.startOfDay(for: date)
    let todayStart = DateUtils.startOfDay(for: today)

    // Extract days per month from schedule
    let lowerSchedule = habit.schedule.lowercased()
    let daysPerMonth: Int
    
    if lowerSchedule.contains("once a month") {
      daysPerMonth = 1
    } else if lowerSchedule.contains("twice a month") {
      daysPerMonth = 2
    } else {
      // Extract number from "X day(s) a month"
      let pattern = #"(\d+) days? a month"#
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(
              in: habit.schedule,
              options: [],
              range: NSRange(location: 0, length: habit.schedule.count)) else
      {
        return false
      }

      let range = match.range(at: 1)
      let daysPerMonthString = (habit.schedule as NSString).substring(with: range)
      guard let days = Int(daysPerMonthString) else {
        return false
      }
      daysPerMonth = days
    }

    // ✅ FIX: Check if habit was completed on this specific date first
    // This ensures completed habits are considered "scheduled" for that date
    let dateKey = Habit.dateKey(for: targetDate)
    let wasCompletedOnThisDate = (habit.completionHistory[dateKey] ?? 0) > 0
    
    if wasCompletedOnThisDate {
      return true
    }

    // If the target date is in the past (and not completed), don't show the habit
    if targetDate < todayStart {
      return false
    }

    // Calculate completions still needed this month
    let completionsThisMonth = countCompletionsForCurrentMonth(habit: habit, currentDate: targetDate)
    let completionsNeeded = daysPerMonth - completionsThisMonth
    
    // If already completed the monthly goal, don't show for future dates
    if completionsNeeded <= 0 {
      return false
    }
    
    // Calculate days remaining in month from today
    let lastDayOfMonth = calendar.dateInterval(of: .month, for: todayStart)?.end ?? todayStart
    let lastDayStart = DateUtils.startOfDay(for: lastDayOfMonth.addingTimeInterval(-1)) // -1 to get last day
    let daysRemainingFromToday = DateUtils.daysBetween(todayStart, lastDayStart) + 1
    
    // Show for minimum of (completions needed, days remaining)
    let daysToShow = min(completionsNeeded, daysRemainingFromToday)
    
    // Check if targetDate is within the next daysToShow days from today
    let daysUntilTarget = DateUtils.daysBetween(todayStart, targetDate)
    return daysUntilTarget >= 0 && daysUntilTarget < daysToShow
  }
  
  /// Helper: Count how many times a habit was completed in the current month
  /// NOTE: This is a static helper. The habit parameter should already be the latest
  /// version from the caller's habits array to avoid stale data issues
  static func countCompletionsForCurrentMonth(habit: Habit, currentDate: Date) -> Int {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: currentDate)
    let year = calendar.component(.year, from: currentDate)
    
    var count = 0
    
    // Iterate through completion history for this month
    for (dateKey, progress) in habit.completionHistory {
      // Parse dateKey format "yyyy-MM-dd"
      let components = dateKey.split(separator: "-")
      guard components.count == 3,
            let keyYear = Int(components[0]),
            let keyMonth = Int(components[1]) else {
        continue
      }
      
      // Check if completion is in the same month and year
      if keyYear == year && keyMonth == month && progress > 0 {
        count += 1
      }
    }
    
    return count
  }

  // MARK: - Habit Instance Management

  static func calculateHabitInstances(
    habit: Habit,
    daysPerWeek: Int,
    targetDate: Date) -> [HabitInstance]
  {
    let calendar = Calendar.current

    // For frequency-based habits, we need to create instances that include today
    // Start from today and work backwards to find the appropriate instances
    let today = Date()
    let todayStart = DateUtils.startOfDay(for: today)

    // Initialize habit instances for this week
    var habitInstances: [HabitInstance] = []

    // Create initial habit instances starting from today
    for i in 0 ..< daysPerWeek {
      if let instanceDate = calendar.date(byAdding: .day, value: i, to: todayStart) {
        let instance = HabitInstance(
          id: "\(habit.id)_\(i)",
          originalDate: instanceDate,
          currentDate: instanceDate)
        habitInstances.append(instance)
      }
    }

    // Apply sliding logic based on completion history
    for i in 0 ..< habitInstances.count {
      var instance = habitInstances[i]

      // Check if this instance was completed on its original date
      let originalDateKey = Habit.dateKey(for: instance.originalDate)
      let originalProgress = habit.completionHistory[originalDateKey] ?? 0

      if originalProgress > 0 {
        // Instance was completed on its original date
        // ❌ REMOVED: Direct assignment in Phase 4
        // instance.isCompleted = true  // Now computed via isCompleted(for:)
        habitInstances[i] = instance
        continue
      }

      // Instance was not completed, so it slides forward
      var currentDate = instance.originalDate

      // Slide the instance forward until it's completed or reaches the end of the week
      while currentDate <= DateUtils.endOfWeek(for: targetDate) {
        let dateKey = Habit.dateKey(for: currentDate)
        let progress = habit.completionHistory[dateKey] ?? 0

        if progress > 0 {
          // Instance was completed on this date
          instance.currentDate = currentDate
          break
        }

        // Move to next day
        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
      }

      // Update instance
      instance.currentDate = currentDate
      // ❌ REMOVED: Direct assignment in Phase 4
      // instance.isCompleted = foundCompletion  // Now computed via isCompleted(for:)
      habitInstances[i] = instance
    }

    // Return instances that should appear on the target date
    return habitInstances.filter { instance in
      let instanceDate = DateUtils.startOfDay(for: instance.currentDate)
      let targetDateStart = DateUtils.startOfDay(for: targetDate)
      return instanceDate == targetDateStart && !instance.isCompleted(for: habit)
    }
  }
}

// MARK: - HabitInstance

struct HabitInstance {
  let id: String
  let originalDate: Date
  var currentDate: Date

  // ❌ REMOVED: Denormalized field in Phase 4
  // var isCompleted: Bool  // Use computed property instead

  /// Computed completion status based on habit completion history
  func isCompleted(for habit: Habit) -> Bool {
    let dateKey = Habit.dateKey(for: currentDate)
    let progress = habit.completionHistory[dateKey] ?? 0
    return progress > 0
  }
}
