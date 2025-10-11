import Foundation

// MARK: - Schedule

// Replaces schedule: String with type-safe enums for better reliability and conflict resolution

enum Schedule: String, CaseIterable, Codable {
  case daily
  case weekdays
  case weekends
  case monday
  case tuesday
  case wednesday
  case thursday
  case friday
  case saturday
  case sunday
  case custom

  // MARK: Internal

  // MARK: - Display Properties

  var displayName: String {
    switch self {
    case .daily: "Daily"
    case .weekdays: "Weekdays"
    case .weekends: "Weekends"
    case .monday: "Monday"
    case .tuesday: "Tuesday"
    case .wednesday: "Wednesday"
    case .thursday: "Thursday"
    case .friday: "Friday"
    case .saturday: "Saturday"
    case .sunday: "Sunday"
    case .custom: "Custom"
    }
  }

  var description: String {
    switch self {
    case .daily: "Every day"
    case .weekdays: "Monday through Friday"
    case .weekends: "Saturday and Sunday"
    case .monday: "Every Monday"
    case .tuesday: "Every Tuesday"
    case .wednesday: "Every Wednesday"
    case .thursday: "Every Thursday"
    case .friday: "Every Friday"
    case .saturday: "Every Saturday"
    case .sunday: "Every Sunday"
    case .custom: "Custom schedule"
    }
  }

  // MARK: - Migration Support

  /// Parse legacy string schedules and convert to typed enum
  static func fromLegacyString(_ legacySchedule: String) -> Schedule {
    let normalized = legacySchedule.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalized {
    case "daily",
         "every day",
         "everyday":
      return .daily
    case "week days",
         "weekday",
         "weekdays":
      return .weekdays
    case "week ends",
         "weekend",
         "weekends":
      return .weekends
    case "mon",
         "monday":
      return .monday
    case "tue",
         "tues",
         "tuesday":
      return .tuesday
    case "wed",
         "wednesday":
      return .wednesday
    case "thu",
         "thurs",
         "thursday":
      return .thursday
    case "fri",
         "friday":
      return .friday
    case "sat",
         "saturday":
      return .saturday
    case "sun",
         "sunday":
      return .sunday
    default:
      // For unknown formats, try to parse as custom or default to daily
      if normalized.contains("custom") || normalized.contains("specific") {
        return .custom
      }
      return .daily // Safe fallback
    }
  }

  /// Get all possible legacy string representations for migration
  static func legacyStringVariants(for schedule: Schedule) -> [String] {
    switch schedule {
    case .daily:
      ["daily", "everyday", "every day"]
    case .weekdays:
      ["weekdays", "weekday", "week days"]
    case .weekends:
      ["weekends", "weekend", "week ends"]
    case .monday:
      ["monday", "mon"]
    case .tuesday:
      ["tuesday", "tue", "tues"]
    case .wednesday:
      ["wednesday", "wed"]
    case .thursday:
      ["thursday", "thu", "thurs"]
    case .friday:
      ["friday", "fri"]
    case .saturday:
      ["saturday", "sat"]
    case .sunday:
      ["sunday", "sun"]
    case .custom:
      ["custom", "specific"]
    }
  }

  // MARK: - Schedule Logic

  /// Check if this schedule applies to the given date
  func appliesToDate(_ date: Date) -> Bool {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)

    switch self {
    case .daily:
      return true
    case .weekdays:
      return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
    case .weekends:
      return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    case .monday:
      return weekday == 2
    case .tuesday:
      return weekday == 3
    case .wednesday:
      return weekday == 4
    case .thursday:
      return weekday == 5
    case .friday:
      return weekday == 6
    case .saturday:
      return weekday == 7
    case .sunday:
      return weekday == 1
    case .custom:
      // Custom schedules would need additional logic
      // For now, default to daily
      return true
    }
  }
}

// MARK: - ScheduleMigration

enum ScheduleMigration {
  /// Migrate all habits from string schedules to typed schedules
  static func migrateAllHabits() async throws {
    // This would be called during app migration
    // Implementation would update all HabitData records
    print("📅 ScheduleMigration: Migrating string schedules to typed schedules")
  }

  /// Validate that a legacy string can be converted to a typed schedule
  static func validateLegacySchedule(_ legacySchedule: String) -> Bool {
    let normalized = legacySchedule.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // Check if it matches any known pattern
    for schedule in Schedule.allCases {
      let variants = Schedule.legacyStringVariants(for: schedule)
      if variants.contains(normalized) {
        return true
      }
    }

    // Check for custom patterns
    if normalized.contains("custom") || normalized.contains("specific") {
      return true
    }

    return false
  }

  /// Get migration statistics for reporting
  static func getMigrationStats() async -> (total: Int, migrated: Int, failed: Int) {
    // Implementation would count habits by schedule type
    // For now, return placeholder
    (total: 0, migrated: 0, failed: 0)
  }
}

// MARK: - Extensions for HabitType Integration

extension Schedule {
  /// Get the default schedule for a habit type
  static func defaultForHabitType(_ habitType: HabitType) -> Schedule {
    switch habitType {
    case .formation:
      .daily // Most habit formation is daily
    case .breaking:
      .daily // Breaking habits also typically daily
    }
  }

  /// Check if this schedule is compatible with the habit type
  func isCompatibleWithHabitType(_: HabitType) -> Bool {
    // All schedules are compatible with all habit types
    // This could be extended for more complex rules
    true
  }
}
