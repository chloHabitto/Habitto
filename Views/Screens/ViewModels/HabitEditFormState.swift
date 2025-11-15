import SwiftUI

@MainActor
final class HabitEditFormState: ObservableObject {
  // MARK: Lifecycle

  init(habit: Habit) {
    self.originalHabit = habit
    self.habitName = habit.name
    self.habitDescription = habit.description
    self.selectedIcon = habit.icon
    self.selectedColor = habit.color.color
    self.selectedHabitType = habit.habitType
    self.selectedSchedule = habit.schedule
    self.selectedReminder = habit.reminder
    self.isReminderEnabled = !habit.reminder.isEmpty
    self.reminders = habit.reminders
    self.startDate = habit.startDate
    self.endDate = habit.endDate

    let today = LegacyDateUtils.today()
    let todayGoalString = habit.goalString(for: today)
    let parsedGoal = HabitEditFormState.parseGoalString(todayGoalString)

    if habit.habitType == .formation {
      goalNumber = parsedGoal.number
      goalUnit = parsedGoal.unit
      goalFrequency = HabitEditFormState.normalizedFrequency(
        parsedGoal.frequency,
        fallbackSchedule: habit.schedule)

      baselineNumber = "1"
      baselineUnit = "time"
      baselineFrequency = "everyday"
      targetNumber = "1"
      targetUnit = "time"
      targetFrequency = "everyday"
    } else {
      targetNumber = parsedGoal.number
      targetUnit = parsedGoal.unit
      targetFrequency = parsedGoal.frequency

      baselineNumber = String(habit.baseline)
      baselineUnit = parsedGoal.unit
      baselineFrequency = parsedGoal.frequency

      goalNumber = "1"
      goalUnit = "time"
      goalFrequency = "everyday"
    }
  }

  // MARK: Internal

  let originalHabit: Habit

  @Published var habitName: String
  @Published var habitDescription: String
  @Published var selectedIcon: String
  @Published var selectedColor: Color
  @Published var selectedHabitType: HabitType
  @Published var selectedSchedule: String
  @Published var selectedReminder: String
  @Published var isReminderEnabled: Bool
  @Published var reminders: [ReminderItem]
  @Published var startDate: Date
  @Published var endDate: Date?

  @Published var goalNumber = "1"
  @Published var goalUnit = "time"
  @Published var goalFrequency = "everyday"
  @Published var baselineNumber = "1"
  @Published var baselineUnit = "time"
  @Published var baselineFrequency = "everyday"
  @Published var targetNumber = "1"
  @Published var targetUnit = "time"
  @Published var targetFrequency = "everyday"

  // MARK: Private helpers

  private static func normalizedFrequency(_ frequency: String, fallbackSchedule: String) -> String {
    if fallbackSchedule.contains("days a week") || fallbackSchedule.contains("days a month") {
      return fallbackSchedule
    }
    return frequency
  }

  private static func sortFrequencyChronologically(_ frequency: String) -> String {
    let lowercasedFrequency = frequency.lowercased()
    if lowercasedFrequency.contains("every"), lowercasedFrequency.contains(",") {
      let dayPhrases = frequency.components(separatedBy: ", ")
      let weekdayOrder = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday"
      ]

      let sortedPhrases = dayPhrases.sorted { phrase1, phrase2 in
        let lowercased1 = phrase1.lowercased()
        let lowercased2 = phrase2.lowercased()
        let day1Index = weekdayOrder.firstIndex { lowercased1.contains($0) } ?? 99
        let day2Index = weekdayOrder.firstIndex { lowercased2.contains($0) } ?? 99
        return day1Index < day2Index
      }

      return sortedPhrases.joined(separator: ", ")
    }

    return frequency
  }

  private static func formatFrequencyText(_ frequency: String) -> String {
    let lowerFreq = frequency.lowercased()

    if lowerFreq.contains("day a week") || lowerFreq.contains("days a week") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*week"#, options: .caseInsensitive),
        let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count))
      {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
          let number = Int(frequency[numberRange])
        {
          switch number {
          case 1: return "once a week"
          case 2: return "twice a week"
          case 7: return "everyday"
          default: return "\(number) days a week"
          }
        }
      }
    }

    if lowerFreq.contains("day a month") || lowerFreq.contains("days a month") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*month"#, options: .caseInsensitive),
        let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count))
      {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
          let number = Int(frequency[numberRange])
        {
          switch number {
          case 1: return "once a month"
          case 2: return "twice a month"
          default: return "\(number) days a month"
          }
        }
      }
    }

    return frequency
  }

  private static func parseGoalString(_ goalString: String) -> (number: String, unit: String, frequency: String) {
    let components = goalString.components(separatedBy: " ")
    let number = components.first ?? "1"

    if goalString.contains(" on ") {
      let parts = goalString.components(separatedBy: " on ")
      let beforeOn = parts[0]
      let rawFrequency = parts.count > 1 ? parts[1] : "everyday"

      let sortedFrequency = sortFrequencyChronologically(rawFrequency)
      let frequency = formatFrequencyText(sortedFrequency)

      let unitComponents = beforeOn.components(separatedBy: " ")
      let unit = unitComponents.count > 1 ? unitComponents[1] : "time"
      return (number: number, unit: unit, frequency: frequency)
    } else if goalString.contains(" per ") {
      let parts = goalString.components(separatedBy: " per ")
      let beforePer = parts[0]
      let rawFrequency = parts.count > 1 ? parts[1] : "everyday"

      let sortedFrequency = sortFrequencyChronologically(rawFrequency)
      let frequency = formatFrequencyText(sortedFrequency)

      let unitComponents = beforePer.components(separatedBy: " ")
      let unit = unitComponents.count > 1 ? unitComponents[1] : "time"
      return (number: number, unit: unit, frequency: frequency)
    } else {
      let tokens = goalString.components(separatedBy: " ")
      let numberToken = tokens.first ?? "1"
      let unitToken = tokens.count > 1 ? tokens[1] : "time"
      let rawFrequency = tokens.count > 2 ? tokens.dropFirst(2).joined(separator: " ") : "everyday"
      let frequency = formatFrequencyText(rawFrequency)
      return (number: numberToken, unit: unitToken, frequency: frequency)
    }
  }
}

