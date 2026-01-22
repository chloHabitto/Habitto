import Foundation
import SwiftUI

/// ✅ SHARED UTILITY: Single source of truth for habit scheduling logic
/// Used by both XP calculation (HomeTabView) and streak calculation (HomeView)
/// to ensure they use IDENTICAL logic for determining which habits are scheduled on which dates
class HabitSchedulingLogic {
  
  // MARK: - Weekday Names Cache
  
  static let weekdayNames = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  ]
  
  // MARK: - Main Scheduling Function
  
  /// Determines if a habit should be shown on a given date
  /// This is the SINGLE SOURCE OF TRUTH used by both XP and streak calculations
  static func shouldShowHabitOnDate(_ habit: Habit, date: Date, habits: [Habit]) -> Bool {
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

    switch habit.schedule.lowercased() {
    case "every day",
         "everyday":
      return true

    case "weekdays":
      let shouldShow = weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
      return shouldShow

    case "weekends":
      let shouldShow = weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
      return shouldShow

    case "mon",
         "monday":
      let shouldShow = weekday == 2
      return shouldShow

    case "tue",
         "tuesday":
      let shouldShow = weekday == 3
      return shouldShow

    case "wed",
         "wednesday":
      let shouldShow = weekday == 4
      return shouldShow

    case "thu",
         "thursday":
      let shouldShow = weekday == 5
      return shouldShow

    case "fri",
         "friday":
      let shouldShow = weekday == 6
      return shouldShow

    case "sat",
         "saturday":
      let shouldShow = weekday == 7
      return shouldShow

    case "sun",
         "sunday":
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
          let shouldShow = weekdays.contains(weekday)
          return shouldShow
        }
      } else if habit.schedule.contains("once a week") || habit.schedule.contains("twice a week") || habit.schedule.contains("day a week") || habit.schedule.contains("days a week") {
        // Handle frequency schedules like "once a week", "twice a week", or "3 days a week"
        let shouldShow = shouldShowHabitWithFrequency(habit: habit, date: date)
        return shouldShow
      } else if habit.schedule.contains("once a month") || habit.schedule.contains("twice a month") || habit.schedule.contains("day a month") || habit.schedule.contains("days a month") {
        // Handle monthly frequency schedules like "once a month", "twice a month", or "3 days a month"
        let shouldShow = shouldShowHabitWithMonthlyFrequency(habit: habit, date: date, habits: habits)
        return shouldShow
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
        let shouldShow = weekdays.contains(weekday)
        return shouldShow
      }
      
      // ✅ CRITICAL FIX: For any unrecognized schedule format, SHOW the habit (don't hide saved habits)
      // Previously returned false, which caused successfully saved habits to disappear from UI
      print("⚠️ shouldShowHabitOnDate - '\(habit.name)' has unrecognized schedule '\(habit.schedule)' - showing by default")
      return true  // ✅ Changed from false to true - better to show than hide
    }
  }
  
  // MARK: - Helper Functions
  
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

    for (index, dayName) in weekdayNames.enumerated() {
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
    let lowerSchedule = schedule.lowercased()
    
    // Handle word-based frequencies
    if lowerSchedule.contains("once a week") {
      return 1
    }
    if lowerSchedule.contains("twice a week") {
      return 2
    }
    
    // Handle number-based frequencies like "3 days a week"
    let pattern = #"(\d+) days? a week"#  // Made "s" optional to match both "day" and "days"
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
    // Verify this is actually a frequency-based schedule (e.g., "3 days a week")
    guard extractDaysPerWeek(from: habit.schedule) != nil else {
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

  static func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date, habits: [Habit]) -> Bool {
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
    let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
    let dateKey = Habit.dateKey(for: targetDate)
    let wasCompletedOnThisDate = (latestHabit.completionHistory[dateKey] ?? 0) > 0
    
    if wasCompletedOnThisDate {
      return true
    }

    // If the target date is in the past (and not completed), don't show the habit
    if targetDate < todayStart {
      return false
    }

    // Calculate completions still needed this month
    let completionsThisMonth = countCompletionsForCurrentMonth(habit: habit, currentDate: targetDate, habits: habits)
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
    let shouldShow = daysUntilTarget >= 0 && daysUntilTarget < daysToShow
    
    return shouldShow
  }
  
  /// Helper: Count how many times a habit was completed in the current month
  /// ✅ FIX: Use fresh habit data from habits array to prevent stale data issues
  static func countCompletionsForCurrentMonth(habit: Habit, currentDate: Date, habits: [Habit]) -> Int {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: currentDate)
    let year = calendar.component(.year, from: currentDate)
    
    // ✅ FIX: Get the latest habit data from the habits array to avoid stale data
    // This prevents the race condition where completionHistory is outdated
    let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
    
    var count = 0
    
    // Iterate through completion history for this month
    for (dateKey, progress) in latestHabit.completionHistory {
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
}

