import Foundation

// MARK: - Typed Schedule System
/// Replaces schedule: String with type-safe enums for better reliability and conflict resolution

enum Schedule: String, CaseIterable, Codable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"
    case custom = "custom"
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .daily: return "Every day"
        case .weekdays: return "Monday through Friday"
        case .weekends: return "Saturday and Sunday"
        case .monday: return "Every Monday"
        case .tuesday: return "Every Tuesday"
        case .wednesday: return "Every Wednesday"
        case .thursday: return "Every Thursday"
        case .friday: return "Every Friday"
        case .saturday: return "Every Saturday"
        case .sunday: return "Every Sunday"
        case .custom: return "Custom schedule"
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
    
    // MARK: - Migration Support
    
    /// Parse legacy string schedules and convert to typed enum
    static func fromLegacyString(_ legacySchedule: String) -> Schedule {
        let normalized = legacySchedule.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalized {
        case "daily", "everyday", "every day":
            return .daily
        case "weekdays", "weekday", "week days":
            return .weekdays
        case "weekends", "weekend", "week ends":
            return .weekends
        case "monday", "mon":
            return .monday
        case "tuesday", "tue", "tues":
            return .tuesday
        case "wednesday", "wed":
            return .wednesday
        case "thursday", "thu", "thurs":
            return .thursday
        case "friday", "fri":
            return .friday
        case "saturday", "sat":
            return .saturday
        case "sunday", "sun":
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
            return ["daily", "everyday", "every day"]
        case .weekdays:
            return ["weekdays", "weekday", "week days"]
        case .weekends:
            return ["weekends", "weekend", "week ends"]
        case .monday:
            return ["monday", "mon"]
        case .tuesday:
            return ["tuesday", "tue", "tues"]
        case .wednesday:
            return ["wednesday", "wed"]
        case .thursday:
            return ["thursday", "thu", "thurs"]
        case .friday:
            return ["friday", "fri"]
        case .saturday:
            return ["saturday", "sat"]
        case .sunday:
            return ["sunday", "sun"]
        case .custom:
            return ["custom", "specific"]
        }
    }
}

// MARK: - Migration Utilities

struct ScheduleMigration {
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
        return (total: 0, migrated: 0, failed: 0)
    }
}

// MARK: - Extensions for HabitType Integration

extension Schedule {
    /// Get the default schedule for a habit type
    static func defaultForHabitType(_ habitType: HabitType) -> Schedule {
        switch habitType {
        case .formation:
            return .daily // Most habit formation is daily
        case .breaking:
            return .daily // Breaking habits also typically daily
        }
    }
    
    /// Check if this schedule is compatible with the habit type
    func isCompatibleWithHabitType(_ habitType: HabitType) -> Bool {
        // All schedules are compatible with all habit types
        // This could be extended for more complex rules
        return true
    }
}
