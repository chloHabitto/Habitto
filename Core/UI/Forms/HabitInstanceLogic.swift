import Foundation
import SwiftUI

// MARK: - HabitInstanceLogic

class HabitInstanceLogic {
  // MARK: - Habit Display Logic

  static func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
    let weekday = DateUtils.weekday(for: date)

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

    let today = Date()
    let targetDate = DateUtils.startOfDay(for: date)
    let todayStart = DateUtils.startOfDay(for: today)

    // If the target date is in the past, don't show the habit
    if targetDate < todayStart {
      return false
    }

    // For frequency-based habits, show the habit on the first N days starting from today
    let daysFromToday = DateUtils.daysBetween(todayStart, targetDate)
    return daysFromToday >= 0 && daysFromToday < daysPerWeek
  }

  static func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
    // For now, implement a simple monthly frequency
    // This can be enhanced later with more sophisticated logic
    let calendar = Calendar.current
    let today = Date()
    let targetDate = DateUtils.startOfDay(for: date)
    let todayStart = DateUtils.startOfDay(for: today)

    // If the target date is in the past, don't show the habit
    if targetDate < todayStart {
      return false
    }

    // Extract days per month from schedule
    let pattern = #"(\d+) days a month"#
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
    guard let daysPerMonth = Int(daysPerMonthString) else {
      return false
    }

    // For monthly frequency, show the habit on the first N days of each month
    let dayOfMonth = calendar.component(.day, from: targetDate)
    return dayOfMonth <= daysPerMonth
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
