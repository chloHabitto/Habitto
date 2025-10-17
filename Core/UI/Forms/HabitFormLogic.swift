import Foundation
import SwiftUI

// MARK: - Habit Form Logic Helper

class HabitFormLogic {
  // MARK: - Default Values

  static let defaultGoalNumber = "1"
  static let defaultGoalUnit = "time"
  static let defaultGoalFrequency = "everyday"
  static let defaultBaselineNumber = "1"
  static let defaultBaselineUnit = "time"
  static let defaultBaselineFrequency = "everyday"
  static let defaultTargetNumber = "1"
  static let defaultTargetUnit = "time"
  static let defaultTargetFrequency = "everyday"
  static let defaultSchedule = "Everyday"
  static let defaultReminder = "No reminder"
  static let defaultStartDate = Date()

  // MARK: - Unit Pluralization

  static func pluralizedUnit(_ count: Int, unit: String) -> String {
    if unit == "time" || unit == "times" {
      return count == 1 ? "time" : "times"
    }
    return unit
  }

  // MARK: - Form Validation

  static func isGoalValid(_ goalNumber: String) -> Bool {
    let number = Int(goalNumber) ?? 0
    return number > 0
  }

  static func isBaselineValid(_ baselineNumber: String) -> Bool {
    let number = Int(baselineNumber) ?? 0
    return number > 0
  }

  static func isTargetValid(_ targetNumber: String) -> Bool {
    let number = Int(targetNumber) ?? 0
    return number >= 0 // Allow 0 for reduction goal in habit breaking
  }

  static func isFormValid(
    habitType: HabitType,
    goalNumber: String,
    baselineNumber: String,
    targetNumber: String) -> Bool
  {
    if habitType == .formation {
      isGoalValid(goalNumber)
    } else {
      isBaselineValid(baselineNumber) && isTargetValid(targetNumber)
    }
  }

  // MARK: - Schedule Conversion

  static func convertGoalFrequencyToSchedule(_ frequency: String) -> String {
    switch frequency.lowercased() {
    case "everyday":
      "Everyday"
    case "weekdays":
      "Weekdays"
    case "weekends":
      "Weekends"
    case "monday":
      "Monday"
    case "tuesday":
      "Tuesday"
    case "wednesday":
      "Wednesday"
    case "thursday":
      "Thursday"
    case "friday":
      "Friday"
    case "saturday":
      "Saturday"
    case "sunday":
      "Sunday"
    case let freq where freq.contains("once a week"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("twice a week"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("once a month"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("twice a month"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("day a week") || freq.contains("days a week"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("day a month") || freq.contains("days a month"):
      frequency // Keep lowercase for consistency
    case let freq where freq.contains("times a week"):
      frequency // Keep original case
    case let freq where freq.contains("times a month"):
      frequency // Keep original case
    case let freq where freq.hasPrefix("every ") && freq.contains("days"):
      // Convert "every 5 days" to "Every 5 days" format
      freq.replacingOccurrences(of: "every ", with: "Every ")
    case let freq where freq.hasPrefix("Every ") && freq.contains("days"):
      // Already in correct format
      freq
    default:
      frequency
    }
  }

  // MARK: - Goal String Formatting

  /// Formats the goal string with proper capitalization and grammar
  static func formatGoalString(number: String, unit: String, frequency: String) -> String {
    let lowerFrequency = frequency.lowercased()
    
    // Frequency patterns that DON'T need "on"
    let frequencyPatterns = [
      "everyday",
      "once a week",
      "twice a week",
      "once a month",
      "twice a month",
      "day a week",
      "days a week",
      "day a month",
      "days a month",
      "time per week",
      "times per week",
    ]
    
    let needsOn = !frequencyPatterns.contains(where: { lowerFrequency.contains($0) })
    
    if needsOn {
      return "\(number) \(unit) on \(lowerFrequency)"
    } else {
      return "\(number) \(unit) \(lowerFrequency)"
    }
  }

  // MARK: - Habit Creation

  static func createHabit(
    step1Data: (String, String, String, Color, HabitType),
    goalNumber: String,
    goalUnit: String,
    goalFrequency: String,
    baselineNumber: String,
    targetNumber: String,
    targetUnit: String,
    targetFrequency: String,
    reminder: String,
    startDate: Date,
    endDate: Date?,
    reminders: [ReminderItem]) -> Habit
  {
    print("🔍 HabitFormLogic: createHabit called")
    print("🔍 HabitFormLogic: step1Data = \(step1Data)")
    print(
      "🔍 HabitFormLogic: goalNumber = \(goalNumber), goalUnit = \(goalUnit), goalFrequency = \(goalFrequency)")

    // For habit building, use goal frequency; for habit breaking, use target frequency
    let scheduleFrequency = step1Data.4 == .formation ? goalFrequency : targetFrequency
    let calendarSchedule = convertGoalFrequencyToSchedule(scheduleFrequency)

    print(
      "🔍 HabitFormLogic: scheduleFrequency = \(scheduleFrequency), calendarSchedule = \(calendarSchedule)")

    if step1Data.4 == .formation {
      // Habit Building
      let goalNumberInt = Int(goalNumber) ?? 1
      let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: goalUnit)
      let goalString = formatGoalString(number: goalNumber, unit: pluralizedUnit, frequency: goalFrequency)

      let habit = Habit(
        name: step1Data.0,
        description: step1Data.1,
        icon: step1Data.2,
        color: step1Data.3,
        habitType: step1Data.4,
        schedule: calendarSchedule,
        goal: goalString,
        reminder: reminder,
        startDate: startDate,
        endDate: endDate,
        reminders: reminders)

      print("🔍 HabitFormLogic: Created formation habit - name: \(habit.name), id: \(habit.id)")
      return habit
    } else {
      // Habit Breaking
      let targetInt = Int(targetNumber) ?? 1
      let targetPluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
      let goalString = formatGoalString(number: targetNumber, unit: targetPluralizedUnit, frequency: targetFrequency)

      let habit = Habit(
        name: step1Data.0,
        description: step1Data.1,
        icon: step1Data.2,
        color: step1Data.3,
        habitType: step1Data.4,
        schedule: calendarSchedule,
        goal: goalString,
        reminder: reminder,
        startDate: startDate,
        endDate: endDate,
        reminders: reminders,
        baseline: Int(baselineNumber) ?? 0,
        target: Int(targetNumber) ?? 0)

      print("🔍 HabitFormLogic: Created breaking habit - name: \(habit.name), id: \(habit.id)")
      return habit
    }
  }
}
