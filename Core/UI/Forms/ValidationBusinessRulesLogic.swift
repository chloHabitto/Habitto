import Foundation
import SwiftUI

// MARK: - Validation and Business Rules Logic Helper

class ValidationBusinessRulesLogic {
  // MARK: Internal

  // MARK: - Goal Parsing and Validation

  static func parseGoalAmount(from goalString: String) -> Int {
    StreakDataCalculator.parseGoalAmount(from: goalString)
  }

  static func parseGoal(from goalString: String) -> (amount: Int, unit: String)? {
    let components = goalString.components(separatedBy: " ")
    guard components.count >= 2,
          let amount = Int(components[0]) else
    {
      return nil
    }

    let unit = components[1]
    return (amount: amount, unit: unit)
  }

  // MARK: - Schedule Pattern Validation

  static func isValidSchedule(_ schedule: String) -> Bool {
    let validSchedules = [
      "Everyday", "Weekdays", "Weekends",
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]

    // Check if it's a standard schedule
    if validSchedules.contains(schedule) {
      return true
    }

    // Check if it's a custom schedule pattern
    if isValidCustomSchedule(schedule) {
      return true
    }

    return false
  }

  // MARK: - Frequency Sorting Logic

  static func sortFrequencyChronologically(_ frequency: String) -> String {
    let lowercasedFrequency = frequency.lowercased()

    // Handle standard frequencies
    switch lowercasedFrequency {
    case "everyday":
      return "Everyday"
    case "weekdays":
      return "Weekdays"
    case "weekends":
      return "Weekends"
    case "monday":
      return "Monday"
    case "tuesday":
      return "Tuesday"
    case "wednesday":
      return "Wednesday"
    case "thursday":
      return "Thursday"
    case "friday":
      return "Friday"
    case "saturday":
      return "Saturday"
    case "sunday":
      return "Sunday"
    default:
      // Handle custom frequencies
      if lowercasedFrequency.contains("times a week") {
        return frequency // Keep original case
      } else if lowercasedFrequency.contains("times a month") {
        return frequency // Keep original case
      } else if lowercasedFrequency.hasPrefix("every "), lowercasedFrequency.contains("days") {
        return frequency.replacingOccurrences(of: "every ", with: "Every ")
      } else {
        return frequency
      }
    }
  }

  static func sortGoalChronologically(_ goal: String) -> String {
    let components = goal.components(separatedBy: " ")
    guard components.count >= 4, components[2] == "per" else {
      return goal
    }

    // Reconstruct with proper capitalization
    let number = components[0]
    let unit = components[1]
    let per = components[2]
    let frequency = sortFrequencyChronologically(components[3])

    return "\(number) \(unit) \(per) \(frequency)"
  }

  static func sortScheduleChronologically(_ schedule: String) -> String {
    sortFrequencyChronologically(schedule)
  }

  // MARK: - Business Rule Validation

  @MainActor
  static func validateHabitCreation(
    name: String,
    description: String,
    icon: String,
    color _: Color,
    habitType _: HabitType) -> (isValid: Bool, errorMessage: String?)
  {
    // Name validation
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return (false, "Habit name cannot be empty")
    }

    if name.count > 50 {
      return (false, "Habit name cannot exceed 50 characters")
    }

    // Check for duplicate habit names
    if isDuplicateHabitName(name) {
      return (false, "This habit name already exists. Please choose a different name.")
    }

    // Description validation
    if description.count > 200 {
      return (false, "Description cannot exceed 200 characters")
    }

    // Icon validation
    if icon.isEmpty {
      return (false, "Please select an icon for your habit")
    }

    // Color validation (always valid in SwiftUI)

    // Habit type validation - HabitType is always valid since it's not optional
    // No validation needed here

    return (true, nil)
  }

  // MARK: - Duplicate Name Validation

  @MainActor
  static func isDuplicateHabitName(_ name: String) -> Bool {
    // Access habits through HabitRepository (MainActor isolated)
    let existingHabits = HabitRepository.shared.habits

    // Normalize the input name (trim and lowercase for comparison)
    let normalizedInputName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    // Check if any existing habit has the same normalized name
    return existingHabits.contains { habit in
      let normalizedExistingName = habit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      return normalizedExistingName == normalizedInputName
    }
  }

  static func validateHabitGoal(
    goalNumber: String,
    goalUnit: String,
    goalFrequency: String,
    habitType _: HabitType) -> (isValid: Bool, errorMessage: String?)
  {
    // Goal number validation
    guard let number = Int(goalNumber) else {
      return (false, "Goal number must be a valid number")
    }

    if number <= 0 {
      return (false, "Goal number must be greater than 0")
    }

    if number > 1000 {
      return (false, "Goal number cannot exceed 1000")
    }

    // Goal unit validation
    if goalUnit.isEmpty {
      return (false, "Please select a goal unit")
    }

    // Goal frequency validation
    if goalFrequency.isEmpty {
      return (false, "Please select a goal frequency")
    }

    if !isValidSchedule(goalFrequency) {
      return (false, "Please select a valid goal frequency")
    }

    return (true, nil)
  }

  static func validateHabitBreaking(
    baselineNumber: String,
    targetNumber: String,
    targetUnit: String,
    targetFrequency: String) -> (isValid: Bool, errorMessage: String?)
  {
    // Baseline validation
    guard let baseline = Int(baselineNumber) else {
      return (false, "Baseline number must be a valid number")
    }

    if baseline <= 0 {
      return (false, "Baseline number must be greater than 0")
    }

    // Target validation
    guard let target = Int(targetNumber) else {
      return (false, "Target number must be a valid number")
    }

    if target < 0 {
      return (false, "Target number cannot be negative")
    }

    if target >= baseline {
      return (false, "Target number must be less than baseline for habit breaking")
    }

    // Target unit validation
    if targetUnit.isEmpty {
      return (false, "Please select a target unit")
    }

    // Target frequency validation
    if targetFrequency.isEmpty {
      return (false, "Please select a target frequency")
    }

    if !isValidSchedule(targetFrequency) {
      return (false, "Please select a valid target frequency")
    }

    return (true, nil)
  }

  // MARK: - Date Validation

  static func validateHabitDates(
    startDate: Date,
    endDate: Date?) -> (isValid: Bool, errorMessage: String?)
  {
    let today = Date()
    let todayStart = DateUtils.startOfDay(for: today)

    // Start date validation
    if startDate < todayStart {
      return (false, "Start date cannot be in the past")
    }

    // End date validation (if provided)
    if let endDate {
      if endDate <= startDate {
        return (false, "End date must be after start date")
      }

      if endDate < todayStart {
        return (false, "End date cannot be in the past")
      }
    }

    return (true, nil)
  }

  // MARK: - Reminder Validation

  static func validateReminders(_ reminders: [ReminderItem])
    -> (isValid: Bool, errorMessage: String?)
  {
    // Check for duplicate times
    let times = reminders.compactMap { $0.time }
    let uniqueTimes = Set(times)

    if times.count != uniqueTimes.count {
      return (false, "Duplicate reminder times are not allowed")
    }

    // Check for valid times - ReminderItem.time is always a valid Date
    // No validation needed here since time is non-optional

    return (true, nil)
  }

  // MARK: Private

  private static func isValidCustomSchedule(_ schedule: String) -> Bool {
    let lowercasedSchedule = schedule.lowercased()

    // Check for "Every X days" pattern
    if lowercasedSchedule.contains("every"), lowercasedSchedule.contains("day") {
      if let dayCount = extractDayCount(from: schedule) {
        return dayCount > 0
      }
    }

    // Check for "X days a week" pattern
    if lowercasedSchedule.contains("days a week") {
      if let daysPerWeek = extractDaysPerWeek(from: schedule) {
        return daysPerWeek > 0 && daysPerWeek <= 7
      }
    }

    // Check for "X days a month" pattern
    if lowercasedSchedule.contains("days a month") {
      if let daysPerMonth = extractDaysPerMonth(from: schedule) {
        return daysPerMonth > 0 && daysPerMonth <= 31
      }
    }

    // Check for "X times per week" pattern
    if lowercasedSchedule.contains("times per week") {
      if let timesPerWeek = extractTimesPerWeek(from: schedule) {
        return timesPerWeek > 0
      }
    }

    // Check for comma-separated weekdays
    if schedule.contains(",") {
      let weekdays = extractWeekdays(from: schedule)
      return !weekdays.isEmpty
    }

    return false
  }

  // MARK: - Schedule Pattern Extraction (for validation)

  private static func extractDayCount(from schedule: String) -> Int? {
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

  private static func extractDaysPerWeek(from schedule: String) -> Int? {
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

  private static func extractDaysPerMonth(from schedule: String) -> Int? {
    let pattern = #"(\d+) days a month"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let daysPerMonthString = (schedule as NSString).substring(with: range)
    return Int(daysPerMonthString)
  }

  private static func extractTimesPerWeek(from schedule: String) -> Int? {
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

  private static func extractWeekdays(from schedule: String) -> Set<Int> {
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
}
