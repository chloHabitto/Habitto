import Foundation
import SwiftUI

// MARK: - Habit Form Logic Helper
class HabitFormLogic {
    
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
        return number >= 0  // Allow 0 for reduction goal in habit breaking
    }
    
    static func isFormValid(habitType: HabitType, goalNumber: String, baselineNumber: String, targetNumber: String) -> Bool {
        if habitType == .formation {
            return isGoalValid(goalNumber)
        } else {
            return isBaselineValid(baselineNumber) && isTargetValid(targetNumber)
        }
    }
    
    // MARK: - Schedule Conversion
    static func convertGoalFrequencyToSchedule(_ frequency: String) -> String {
        switch frequency.lowercased() {
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
        case let freq where freq.contains("times a week"):
            return frequency // Keep original case
        case let freq where freq.contains("times a month"):
            return frequency // Keep original case
        case let freq where freq.hasPrefix("every ") && freq.contains("days"):
            return freq.replacingOccurrences(of: "every ", with: "Every ")
        default:
            return frequency
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
        reminders: [ReminderItem]
    ) -> Habit {
        
        // For habit building, use goal frequency; for habit breaking, use target frequency
        let scheduleFrequency = step1Data.4 == .formation ? goalFrequency : targetFrequency
        let calendarSchedule = convertGoalFrequencyToSchedule(scheduleFrequency)
        
        if step1Data.4 == .formation {
            // Habit Building
            let goalNumberInt = Int(goalNumber) ?? 1
            let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: goalUnit)
            let goalString = "\(goalNumber) \(pluralizedUnit) on \(goalFrequency)"
            
            return Habit(
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
                reminders: reminders
            )
        } else {
            // Habit Breaking
            let targetInt = Int(targetNumber) ?? 1
            let targetPluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
            let goalString = "\(targetNumber) \(targetPluralizedUnit) per \(targetFrequency)"
            
            return Habit(
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
                target: Int(targetNumber) ?? 0
            )
        }
    }
    
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
} 