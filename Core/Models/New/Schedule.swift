import Foundation

/// Schedule determines when a habit should appear and be tracked
///
/// **Two modes:**
/// - **Interval-based**: Habit appears ONLY on specific days (daily, everyNDays, specificWeekdays)
/// - **Frequency-based**: Habit appears EVERY day, user chooses which days to complete (frequencyWeekly, frequencyMonthly)
///
/// **Examples:**
/// - `.daily` → Every day
/// - `.everyNDays(3)` → Every 3 days starting from habit.startDate
/// - `.specificWeekdays([.monday, .friday])` → Only Mon & Fri
/// - `.frequencyWeekly(3)` → Shows every day, goal is 3 completions per week
/// - `.frequencyMonthly(10)` → Shows every day, goal is 10 completions per month
enum Schedule: Codable, Equatable, Hashable {
    case daily
    case everyNDays(Int)
    case specificWeekdays([Weekday])
    case frequencyWeekly(Int)  // Goal: complete N days per week
    case frequencyMonthly(Int) // Goal: complete N days per month
    
    // MARK: - Scheduling Logic
    
    /// Determines if habit should appear on given date
    /// - Parameters:
    ///   - date: Target date to check
    ///   - habitStartDate: When habit was created
    /// - Returns: True if habit should be shown on this date
    func shouldAppear(on date: Date, habitStartDate: Date) -> Bool {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let startDate = calendar.startOfDay(for: habitStartDate)
        
        // Never show before habit start date
        guard targetDate >= startDate else { return false }
        
        switch self {
        case .daily:
            return true
            
        case .everyNDays(let n):
            guard n > 0 else { return false }
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
            return daysSinceStart % n == 0
            
        case .specificWeekdays(let weekdays):
            let weekday = calendar.component(.weekday, from: targetDate)
            return weekdays.contains(Weekday(weekdayNumber: weekday))
            
        case .frequencyWeekly(_):
            // Show EVERY day - user decides which days to complete
            return true
            
        case .frequencyMonthly(_):
            // Show EVERY day - user decides which days to complete
            return true
        }
    }
    
    /// Returns the goal count for the period containing the given date (frequency-based only)
    /// - Parameter date: Date within the period
    /// - Returns: Goal count, or nil if not frequency-based
    func goalForPeriod(containing date: Date) -> Int? {
        switch self {
        case .frequencyWeekly(let daysPerWeek):
            return daysPerWeek
            
        case .frequencyMonthly(let daysPerMonth):
            return daysPerMonth
            
        default:
            return nil  // Not frequency-based
        }
    }
    
    /// Checks if this is a frequency-based schedule
    var isFrequencyBased: Bool {
        switch self {
        case .frequencyWeekly, .frequencyMonthly:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Display Helpers
    
    /// Human-readable description
    var displayString: String {
        switch self {
        case .daily:
            return "Every day"
            
        case .everyNDays(let n):
            return n == 1 ? "Every day" : "Every \(n) days"
            
        case .specificWeekdays(let weekdays):
            if weekdays.count == 7 {
                return "Every day"
            } else if weekdays.count == 1 {
                return "Every \(weekdays[0].displayName)"
            } else {
                let names = weekdays.map { $0.displayName }.joined(separator: ", ")
                return "Every \(names)"
            }
            
        case .frequencyWeekly(let n):
            return n == 1 ? "Once a week" : "\(n) days a week"
            
        case .frequencyMonthly(let n):
            return n == 1 ? "Once a month" : "\(n) days a month"
        }
    }
}

/// Represents days of the week (ISO 8601: Monday = start of week)
enum Weekday: String, Codable, CaseIterable, Hashable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    
    /// Calendar weekday number (1 = Sunday in Foundation)
    var weekdayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    /// Initialize from Calendar weekday number
    init(weekdayNumber: Int) {
        switch weekdayNumber {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: self = .sunday
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var shortName: String {
        String(rawValue.prefix(3)).capitalized
    }
}

/// Helper to convert old schedule strings to new Schedule enum
extension Schedule {
    /// Migrate from old string-based schedule format
    /// - Parameter legacySchedule: Old schedule string (e.g., "Everyday", "Monday, Wednesday")
    /// - Returns: New Schedule enum case
    static func fromLegacyString(_ legacySchedule: String) -> Schedule {
        let lower = legacySchedule.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 1. Daily patterns
        if lower == "everyday" || lower == "daily" || lower == "every day" {
            return .daily
        }
        
        // 2. Every N days patterns (e.g., "Every 2 days", "every 5 days")
        // Must check BEFORE weekday parsing to avoid false matches
        if lower.hasPrefix("every ") && (lower.hasSuffix("days") || lower.hasSuffix("day")) && !lower.contains(",") {
            // Extract number between "every" and "days/day"
            let components = lower.components(separatedBy: " ")
            if components.count >= 3, let n = Int(components[1]), n > 0 {
                return .everyNDays(n)
            }
        }
        
        // 3. Frequency weekly patterns (e.g., "3 days a week", "once a week")
        if lower.contains("day a week") || lower.contains("days a week") {
            if lower.hasPrefix("once") || lower.contains("once a week") {
                return .frequencyWeekly(1)
            } else if lower.hasPrefix("twice") || lower.contains("twice a week") {
                return .frequencyWeekly(2)
            } else {
                // Extract number at start (e.g., "3 days a week" or "5 day a week")
                let components = lower.components(separatedBy: " ")
                if let n = Int(components[0]), n > 0, n <= 7 {
                    return .frequencyWeekly(n)
                }
            }
        }
        
        // 4. Frequency monthly patterns (e.g., "5 days a month", "once a month")
        if lower.contains("day a month") || lower.contains("days a month") {
            if lower.hasPrefix("once") || lower.contains("once a month") {
                return .frequencyMonthly(1)
            } else if lower.hasPrefix("twice") || lower.contains("twice a month") {
                return .frequencyMonthly(2)
            } else {
                // Extract number at start
                let components = lower.components(separatedBy: " ")
                if let n = Int(components[0]), n > 0, n <= 31 {
                    return .frequencyMonthly(n)
                }
            }
        }
        
        // 5. Specific weekdays (e.g., "Monday", "Every Monday, Wednesday, Friday")
        // This must be LAST to avoid false matches with "Every N days"
        let weekdayMap: [String: Weekday] = [
            "monday": .monday, "mon": .monday,
            "tuesday": .tuesday, "tue": .tuesday, "tues": .tuesday,
            "wednesday": .wednesday, "wed": .wednesday,
            "thursday": .thursday, "thu": .thursday, "thur": .thursday, "thurs": .thursday,
            "friday": .friday, "fri": .friday,
            "saturday": .saturday, "sat": .saturday,
            "sunday": .sunday, "sun": .sunday
        ]
        
        var foundWeekdays: [Weekday] = []
        
        // Check each weekday name in the string
        for (key, weekday) in weekdayMap {
            if lower.contains(key) && !foundWeekdays.contains(weekday) {
                foundWeekdays.append(weekday)
            }
        }
        
        if !foundWeekdays.isEmpty {
            // Sort by weekday number for consistency
            let sorted = foundWeekdays.sorted { $0.weekdayNumber < $1.weekdayNumber }
            return .specificWeekdays(sorted)
        }
        
        // Default fallback
        print("⚠️ Could not parse schedule: '\(legacySchedule)', defaulting to .daily")
        return .daily
    }
}

