import Foundation
import SwiftUI

// MARK: - Data Validation Service
class DataValidationService: ObservableObject {
    @Published var isEnabled = true
    @Published var validationMode: ValidationMode = .strict
    @Published var lastValidationTime: Date?
    
    private let habitValidator = HabitValidator()
    private let collectionValidator = HabitCollectionValidator()
    private let integrityChecker = DataIntegrityChecker()
    private let errorHandler = DataErrorHandler()
    
    // MARK: - Validation Modes
    enum ValidationMode {
        case strict    // Validate all data strictly
        case moderate  // Validate with warnings for minor issues
        case lenient   // Only validate critical issues
    }
    
    // MARK: - Public Methods
    
    func validateHabit(_ habit: Habit) -> ValidationResult {
        guard isEnabled else { return .valid }
        
        let result = habitValidator.validate(habit)
        
        // Filter results based on validation mode
        let filteredResult = filterValidationResult(result, mode: validationMode)
        
        if !filteredResult.isValid {
            for error in filteredResult.errors {
                let dataError = DataError.validation(error)
                errorHandler.handle(dataError)
            }
        }
        
        return filteredResult
    }
    
    func validateHabits(_ habits: [Habit]) -> ValidationResult {
        guard isEnabled else { return .valid }
        
        let result = collectionValidator.validate(habits)
        
        // Filter results based on validation mode
        let filteredResult = filterValidationResult(result, mode: validationMode)
        
        if !filteredResult.isValid {
            for error in filteredResult.errors {
                let dataError = DataError.validation(error)
                errorHandler.handle(dataError)
            }
        }
        
        return filteredResult
    }
    
    func validateAndFixHabits(_ habits: inout [Habit]) -> ValidationResult {
        // First, validate the habits
        let validationResult = validateHabits(habits)
        
        // If there are fixable issues, attempt to fix them
        if validationResult.hasErrors {
            let fixedIssues = integrityChecker.autoFixIssues(habits: &habits)
            
            // Log fixed issues
            for issue in fixedIssues {
                print("🔧 DataValidationService: Auto-fixed issue - \(issue.message)")
            }
            
            // Re-validate after fixes
            let postFixResult = validateHabits(habits)
            return postFixResult
        }
        
        return validationResult
    }
    
    func performDataIntegrityCheck(_ habits: [Habit]) async -> DataIntegrityReport {
        let report = await integrityChecker.checkDataIntegrity(habits: habits)
        lastValidationTime = report.checkTime
        return report
    }
    
    func getValidationErrors(for field: String) -> [ValidationError] {
        return errorHandler.getErrors(for: field).compactMap { error in
            if case .validation(let validationError) = error {
                return validationError
            }
            return nil
        }
    }
    
    func clearValidationErrors(for field: String) {
        errorHandler.clearErrors(for: field)
    }
    
    func clearAllValidationErrors() {
        errorHandler.errorHistory.removeAll()
        errorHandler.clearCurrentError()
    }
    
    // MARK: - Configuration
    
    func setValidationMode(_ mode: ValidationMode) {
        validationMode = mode
        print("🔧 DataValidationService: Validation mode set to \(mode)")
    }
    
    func enableValidation() {
        isEnabled = true
        print("✅ DataValidationService: Validation enabled")
    }
    
    func disableValidation() {
        isEnabled = false
        print("⚠️ DataValidationService: Validation disabled")
    }
    
    // MARK: - Private Methods
    
    private func filterValidationResult(_ result: ValidationResult, mode: ValidationMode) -> ValidationResult {
        guard !result.isValid else { return result }
        
        let filteredErrors = result.errors.filter { error in
            switch mode {
            case .strict:
                return true // Include all errors
            case .moderate:
                return error.severity != .warning // Exclude warnings
            case .lenient:
                return error.severity == .critical // Only critical errors
            }
        }
        
        return filteredErrors.isEmpty ? .valid : .invalid(filteredErrors)
    }
}

// MARK: - Validation Middleware
class ValidationMiddleware {
    private let validationService: DataValidationService
    
    init(validationService: DataValidationService) {
        self.validationService = validationService
    }
    
    @MainActor
    func validateBeforeSave<T>(_ data: T) -> ValidationResult where T: Codable {
        if let habit = data as? Habit {
            return validationService.validateHabit(habit)
        } else if let habits = data as? [Habit] {
            return validationService.validateHabits(habits)
        }
        
        return .valid
    }
    
    @MainActor
    func validateAfterLoad<T>(_ data: T) -> ValidationResult where T: Codable {
        if let habit = data as? Habit {
            return validationService.validateHabit(habit)
        } else if let habits = data as? [Habit] {
            return validationService.validateHabits(habits)
        }
        
        return .valid
    }
}

// MARK: - Validation Rules Engine
class ValidationRulesEngine {
    private var rules: [ValidationRule] = []
    
    func addRule(_ rule: ValidationRule) {
        rules.append(rule)
    }
    
    func removeRule(withId id: String) {
        rules.removeAll { $0.id == id }
    }
    
    func validate<T>(_ data: T) -> ValidationResult {
        var allErrors: [ValidationError] = []
        
        for rule in rules {
            if rule.applies(to: data) {
                let result = rule.validate(data)
                if !result.isValid {
                    allErrors.append(contentsOf: result.errors)
                }
            }
        }
        
        return allErrors.isEmpty ? .valid : .invalid(allErrors)
    }
}

// MARK: - Validation Rule Protocol
protocol ValidationRule {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    
    func applies<T>(to data: T) -> Bool
    func validate<T>(_ data: T) -> ValidationResult
}

// MARK: - Built-in Validation Rules
struct HabitNameLengthRule: ValidationRule {
    let id = "habit_name_length"
    let name = "Habit Name Length"
    let description = "Ensures habit names are within acceptable length limits"
    
    func applies<T>(to data: T) -> Bool {
        return data is Habit
    }
    
    func validate<T>(_ data: T) -> ValidationResult {
        guard let habit = data as? Habit else { return .valid }
        
        var errors: [ValidationError] = []
        
        if habit.name.count < 2 {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name must be at least 2 characters",
                severity: .error
            ))
        }
        
        if habit.name.count > 50 {
            errors.append(ValidationError(
                field: "name",
                message: "Habit name cannot exceed 50 characters",
                severity: .error
            ))
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

struct HabitStreakConsistencyRule: ValidationRule {
    let id = "habit_streak_consistency"
    let name = "Habit Streak Consistency"
    let description = "Ensures streak count matches completion history"
    
    func applies<T>(to data: T) -> Bool {
        return data is Habit
    }
    
    func validate<T>(_ data: T) -> ValidationResult {
        guard let habit = data as? Habit else { return .valid }
        
        if !habit.validateStreak() {
            return .invalid(ValidationError(
                field: "streak",
                message: "Streak count doesn't match completion history",
                severity: .warning
            ))
        }
        
        return .valid
    }
}

struct HabitDateConsistencyRule: ValidationRule {
    let id = "habit_date_consistency"
    let name = "Habit Date Consistency"
    let description = "Ensures habit dates are logically consistent"
    
    func applies<T>(to data: T) -> Bool {
        return data is Habit
    }
    
    func validate<T>(_ data: T) -> ValidationResult {
        guard let habit = data as? Habit else { return .valid }
        
        var errors: [ValidationError] = []
        
        // Check start date is not in the future
        if habit.startDate > Date() {
            errors.append(ValidationError(
                field: "startDate",
                message: "Start date cannot be in the future",
                severity: .error
            ))
        }
        
        // Check end date is after start date
        if let endDate = habit.endDate, endDate <= habit.startDate {
            errors.append(ValidationError(
                field: "endDate",
                message: "End date must be after start date",
                severity: .error
            ))
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

// MARK: - Validation Configuration
struct ValidationConfiguration {
    let mode: DataValidationService.ValidationMode
    let enableAutoFix: Bool
    let enableIntegrityChecking: Bool
    let enablePerformanceMonitoring: Bool
    let customRules: [ValidationRule]
    
    static let `default` = ValidationConfiguration(
        mode: .moderate,
        enableAutoFix: true,
        enableIntegrityChecking: true,
        enablePerformanceMonitoring: true,
        customRules: [
            HabitNameLengthRule(),
            HabitStreakConsistencyRule(),
            HabitDateConsistencyRule()
        ]
    )
    
    static let strict = ValidationConfiguration(
        mode: .strict,
        enableAutoFix: false,
        enableIntegrityChecking: true,
        enablePerformanceMonitoring: true,
        customRules: [
            HabitNameLengthRule(),
            HabitStreakConsistencyRule(),
            HabitDateConsistencyRule()
        ]
    )
    
    static let lenient = ValidationConfiguration(
        mode: .lenient,
        enableAutoFix: true,
        enableIntegrityChecking: false,
        enablePerformanceMonitoring: false,
        customRules: []
    )
}
