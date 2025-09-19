import Foundation
import SwiftUI

// MARK: - Validation Result
struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    
    var hasErrors: Bool { !errors.isEmpty }
    var firstError: ValidationError? { errors.first }
    
    init(isValid: Bool, errors: [ValidationError] = []) {
        self.isValid = isValid
        self.errors = errors
    }
    
    static let valid = ValidationResult(isValid: true)
    
    static func invalid(_ errors: [ValidationError]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors)
    }
    
    static func invalid(_ error: ValidationError) -> ValidationResult {
        return ValidationResult(isValid: false, errors: [error])
    }
}

// MARK: - Validation Error
struct ValidationError: Error, LocalizedError, Identifiable {
    let id = UUID()
    let field: String
    let message: String
    let severity: ValidationSeverity
    
    var errorDescription: String? {
        return message
    }
    
    init(field: String, message: String, severity: ValidationSeverity = .error) {
        self.field = field
        self.message = message
        self.severity = severity
    }
}

// MARK: - Validation Severity
enum ValidationSeverity {
    case warning
    case error
    case critical
}

// MARK: - Data Validator Protocol
protocol DataValidator {
    associatedtype DataType
    func validate(_ data: DataType) -> ValidationResult
}

// MARK: - Habit Data Validator
class HabitValidator: DataValidator {
    typealias DataType = Habit
    
    func validate(_ habit: Habit) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Name validation
        errors.append(contentsOf: validateName(habit.name))
        
        // Description validation
        errors.append(contentsOf: validateDescription(habit.description))
        
        // Icon validation
        errors.append(contentsOf: validateIcon(habit.icon))
        
        // Schedule validation
        errors.append(contentsOf: validateSchedule(habit.schedule))
        
        // Goal validation
        errors.append(contentsOf: validateGoal(habit.goal, habitType: habit.habitType))
        
        // Date validation
        errors.append(contentsOf: validateDates(startDate: habit.startDate, endDate: habit.endDate))
        
        // Habit-specific validation
        if habit.habitType == .breaking {
            errors.append(contentsOf: validateHabitBreaking(habit))
        } else {
            // For habit formation, validate that baseline is 0 (not used)
            if habit.baseline != 0 {
                errors.append(ValidationError(
                    field: "baseline",
                    message: "Baseline should be 0 for habit formation",
                    severity: .warning
                ))
            }
        }
        
        // Data integrity validation
        errors.append(contentsOf: validateDataIntegrity(habit))
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    // MARK: - Individual Field Validators
    
    private func validateName(_ name: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name cannot be empty",
                severity: .error
            ))
        }
        
        if name.count > 50 {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name cannot exceed 50 characters",
                severity: .error
            ))
        }
        
        if name.count < 1 {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name cannot be empty",
                severity: .error
            ))
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>\"'&")
        if name.rangeOfCharacter(from: invalidCharacters) != nil {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name contains invalid characters",
                severity: .warning
            ))
        }
        
        return errors
    }
    
    private func validateDescription(_ description: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if description.count > 200 {
            errors.append(ValidationError(
                field: "description",
                message: "Description cannot exceed 200 characters",
                severity: .error
            ))
        }
        
        return errors
    }
    
    private func validateIcon(_ icon: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if icon.isEmpty {
            errors.append(ValidationError(
                field: "icon",
                message: "Please select an icon for your habit",
                severity: .error
            ))
        }
        
        // Validate that the icon is a valid SF Symbol
        if !icon.isEmpty && !isValidSFSymbol(icon) {
            errors.append(ValidationError(
                field: "icon",
                message: "Selected icon is not a valid system icon",
                severity: .warning
            ))
        }
        
        return errors
    }
    
    private func validateSchedule(_ schedule: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if schedule.isEmpty {
            errors.append(ValidationError(
                field: "schedule",
                message: "Please select a schedule for your habit",
                severity: .error
            ))
        }
        
        // Validate schedule format
        if !schedule.isEmpty && !isValidSchedule(schedule) {
            errors.append(ValidationError(
                field: "schedule",
                message: "Invalid schedule format",
                severity: .error
            ))
        }
        
        return errors
    }
    
    private func validateGoal(_ goal: String, habitType: HabitType) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if goal.isEmpty {
            errors.append(ValidationError(
                field: "goal",
                message: "Please set a goal for your habit",
                severity: .error
            ))
        }
        
        // Parse goal for validation
        if !goal.isEmpty {
            let components = goal.components(separatedBy: " ")
            if components.count >= 2 {
                if let number = Int(components[0]) {
                    if number <= 0 {
                        errors.append(ValidationError(
                            field: "goal",
                            message: "Goal number must be greater than 0",
                            severity: .error
                        ))
                    }
                    
                    if number > 1000 {
                        errors.append(ValidationError(
                            field: "goal",
                            message: "Goal number seems too high. Please verify this is correct",
                            severity: .warning
                        ))
                    }
                }
            }
        }
        
        return errors
    }
    
    private func validateDates(startDate: Date, endDate: Date?) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        let now = Date()
        let calendar = Calendar.current
        
        // Start date validation
        if startDate > now {
            errors.append(ValidationError(
                field: "startDate",
                message: "Start date cannot be in the future",
                severity: .error
            ))
        }
        
        // End date validation
        if let endDate = endDate {
            if endDate <= startDate {
                errors.append(ValidationError(
                    field: "endDate",
                    message: "End date must be after start date",
                    severity: .error
                ))
            }
            
            if endDate < now {
                errors.append(ValidationError(
                    field: "endDate",
                    message: "End date is in the past",
                    severity: .warning
                ))
            }
            
            // Check if habit duration is too long (more than 1 year)
            let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            if daysDifference > 365 {
                errors.append(ValidationError(
                    field: "endDate",
                    message: "Habit duration is longer than 1 year. Consider breaking it into smaller goals",
                    severity: .warning
                ))
            }
        }
        
        return errors
    }
    
    private func validateHabitBreaking(_ habit: Habit) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Baseline validation
        if habit.baseline <= 0 {
            errors.append(ValidationError(
                field: "baseline",
                message: "Baseline must be greater than 0",
                severity: .error
            ))
        }
        
        if habit.baseline > 1000 {
            errors.append(ValidationError(
                field: "baseline",
                message: "Baseline seems too high. Please verify this is correct",
                severity: .warning
            ))
        }
        
        // Target validation
        if habit.target < 0 {
            errors.append(ValidationError(
                field: "target",
                message: "Target cannot be negative",
                severity: .error
            ))
        }
        
        if habit.target >= habit.baseline {
            errors.append(ValidationError(
                field: "target",
                message: "Target must be less than baseline for habit breaking",
                severity: .error
            ))
        }
        
        // Check if reduction is too aggressive (more than 90% reduction)
        if habit.baseline > 0 {
            let reductionPercentage = Double(habit.baseline - habit.target) / Double(habit.baseline) * 100
            if reductionPercentage > 90 {
                errors.append(ValidationError(
                    field: "target",
                    message: "Target reduction is very aggressive (\(Int(reductionPercentage))%). Consider a more gradual approach",
                    severity: .warning
                ))
            }
        }
        
        return errors
    }
    
    private func validateDataIntegrity(_ habit: Habit) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Streak validation
        if habit.streak < 0 {
            errors.append(ValidationError(
                field: "streak",
                message: "Streak cannot be negative",
                severity: .critical
            ))
        }
        
        // Validate streak against completion history
        if !habit.validateStreak() {
            errors.append(ValidationError(
                field: "streak",
                message: "Streak count doesn't match completion history",
                severity: .warning
            ))
        }
        
        // Check for future completion dates
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        for (dateKey, _) in habit.completionHistory {
            if let date = parseDate(from: dateKey), date > today {
                errors.append(ValidationError(
                    field: "completionHistory",
                    message: "Found completion record for future date: \(dateKey)",
                    severity: .warning
                ))
            }
        }
        
        // Check for invalid difficulty values
        for (dateKey, difficulty) in habit.difficultyHistory {
            if difficulty < 1 || difficulty > 10 {
                errors.append(ValidationError(
                    field: "difficultyHistory",
                    message: "Invalid difficulty value (\(difficulty)) for date: \(dateKey)",
                    severity: .warning
                ))
            }
        }
        
        return errors
    }
    
    // MARK: - Helper Methods
    
    private func isValidSFSymbol(_ icon: String) -> Bool {
        // Basic validation for SF Symbols
        // In a real app, you might want to check against a list of valid symbols
        return !icon.isEmpty && icon.count > 1
    }
    
    private func isValidSchedule(_ schedule: String) -> Bool {
        // Basic schedule validation - accept common schedule formats
        let validSchedules = [
            "Everyday", "Weekdays", "Weekends",
            "daily", "weekly", "monthly", "yearly",
            "Every 2 days", "Every 3 days", "Every 4 days", "Every 5 days", "Every 6 days", "Every 7 days"
        ]
        
        return validSchedules.contains(schedule) || schedule.isEmpty
    }
    
    private func parseDate(from dateKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateKey)
    }
}

// MARK: - Collection Validator
class HabitCollectionValidator: DataValidator {
    typealias DataType = [Habit]
    
    func validate(_ habits: [Habit]) -> ValidationResult {
        var allErrors: [ValidationError] = []
        
        // Validate each habit
        for (index, habit) in habits.enumerated() {
            let habitValidator = HabitValidator()
            let result = habitValidator.validate(habit)
            
            // Add index context to errors
            for error in result.errors {
                let contextualError = ValidationError(
                    field: "habits[\(index)].\(error.field)",
                    message: error.message,
                    severity: error.severity
                )
                allErrors.append(contextualError)
            }
        }
        
        // Collection-level validation
        allErrors.append(contentsOf: validateCollection(habits))
        
        return allErrors.isEmpty ? .valid : .invalid(allErrors)
    }
    
    private func validateCollection(_ habits: [Habit]) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Check for duplicate habit names
        let names = habits.map { $0.name.lowercased() }
        let uniqueNames = Set(names)
        if names.count != uniqueNames.count {
            errors.append(ValidationError(
                field: "habits",
                message: "Found duplicate habit names",
                severity: .warning
            ))
        }
        
        // Check for too many habits
        if habits.count > 50 {
            errors.append(ValidationError(
                field: "habits",
                message: "You have \(habits.count) habits. Consider focusing on fewer habits for better success",
                severity: .warning
            ))
        }
        
        // Check for habits with very old start dates (older than 2 years)
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        let oldHabits = habits.filter { $0.startDate < twoYearsAgo }
        if !oldHabits.isEmpty {
            errors.append(ValidationError(
                field: "habits",
                message: "Found \(oldHabits.count) habits older than 2 years. Consider reviewing or archiving them",
                severity: .warning
            ))
        }
        
        return errors
    }
}
