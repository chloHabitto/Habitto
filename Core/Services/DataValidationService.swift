import Foundation
import SwiftUI

// MARK: - DataValidationService

class DataValidationService: ObservableObject {
  // MARK: Internal

  // MARK: - Validation Modes

  enum ValidationMode {
    case strict // Validate all data strictly
    case moderate // Validate with warnings for minor issues
    case lenient // Only validate critical issues
  }

  @Published var isEnabled = true
  @Published var validationMode: ValidationMode = .strict
  @Published var lastValidationTime: Date?

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
    errorHandler.getErrors(for: field).compactMap { error in
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

  // MARK: Private

  private let habitValidator = HabitValidator()
  private let collectionValidator = HabitCollectionValidator()
  private let integrityChecker = DataIntegrityChecker()
  private let errorHandler = DataErrorHandler()

  // MARK: - Private Methods

  private func filterValidationResult(
    _ result: ValidationResult,
    mode: ValidationMode) -> ValidationResult
  {
    guard !result.isValid else { return result }

    let filteredErrors = result.errors.filter { error in
      switch mode {
      case .strict:
        true // Include all errors
      case .moderate:
        error.severity != .warning // Exclude warnings
      case .lenient:
        error.severity == .critical // Only critical errors
      }
    }

    return filteredErrors.isEmpty ? .valid : .invalid(filteredErrors)
  }
}

// MARK: - ValidationMiddleware

class ValidationMiddleware {
  // MARK: Lifecycle

  init(validationService: DataValidationService) {
    self.validationService = validationService
  }

  // MARK: Internal

  @MainActor
  func validateBeforeSave(_ data: some Codable) -> ValidationResult {
    if let habit = data as? Habit {
      return validationService.validateHabit(habit)
    } else if let habits = data as? [Habit] {
      return validationService.validateHabits(habits)
    }

    return .valid
  }

  @MainActor
  func validateAfterLoad(_ data: some Codable) -> ValidationResult {
    if let habit = data as? Habit {
      return validationService.validateHabit(habit)
    } else if let habits = data as? [Habit] {
      return validationService.validateHabits(habits)
    }

    return .valid
  }

  // MARK: Private

  private let validationService: DataValidationService
}

// MARK: - ValidationRulesEngine

class ValidationRulesEngine {
  // MARK: Internal

  func addRule(_ rule: ValidationRule) {
    rules.append(rule)
  }

  func removeRule(withId id: String) {
    rules.removeAll { $0.id == id }
  }

  func validate(_ data: some Any) -> ValidationResult {
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

  // MARK: Private

  private var rules: [ValidationRule] = []
}

// MARK: - ValidationRule

protocol ValidationRule {
  var id: String { get }
  var name: String { get }
  var description: String { get }

  func applies(to data: some Any) -> Bool
  func validate(_ data: some Any) -> ValidationResult
}

// MARK: - HabitNameLengthRule

struct HabitNameLengthRule: ValidationRule {
  let id = "habit_name_length"
  let name = "Habit Name Length"
  let description = "Ensures habit names are within acceptable length limits"

  func applies(to data: some Any) -> Bool {
    data is Habit
  }

  func validate(_ data: some Any) -> ValidationResult {
    guard let habit = data as? Habit else { return .valid }

    var errors: [ValidationError] = []

    if habit.name.count < 2 {
      errors.append(ValidationError(
        field: "name",
        message: "Habit name must be at least 2 characters",
        severity: .error))
    }

    if habit.name.count > 50 {
      errors.append(ValidationError(
        field: "name",
        message: "Habit name cannot exceed 50 characters",
        severity: .error))
    }

    return errors.isEmpty ? .valid : .invalid(errors)
  }
}

// MARK: - HabitStreakConsistencyRule

struct HabitStreakConsistencyRule: ValidationRule {
  let id = "habit_streak_consistency"
  let name = "Habit Streak Consistency"
  let description = "Ensures streak count matches completion history"

  func applies(to data: some Any) -> Bool {
    data is Habit
  }

  func validate(_ data: some Any) -> ValidationResult {
    guard let habit = data as? Habit else { return .valid }

    if !habit.validateStreak() {
      return .invalid(ValidationError(
        field: "streak",
        message: "Streak count doesn't match completion history",
        severity: .warning))
    }

    return .valid
  }
}

// MARK: - HabitDateConsistencyRule

struct HabitDateConsistencyRule: ValidationRule {
  let id = "habit_date_consistency"
  let name = "Habit Date Consistency"
  let description = "Ensures habit dates are logically consistent"

  func applies(to data: some Any) -> Bool {
    data is Habit
  }

  func validate(_ data: some Any) -> ValidationResult {
    guard let habit = data as? Habit else { return .valid }

    var errors: [ValidationError] = []

    // ✅ FIX: REMOVED future start date validation
    // Habits SHOULD be allowed to have future start dates
    // Date filtering happens in DISPLAY logic, not CREATION logic
    
    // Check end date is after start date
    if let endDate = habit.endDate {
      let calendar = Calendar.current
      let now = Date()
      let today = calendar.startOfDay(for: now)
      let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
      
      let endDateStartOfDay = calendar.startOfDay(for: endDate)
      let startDateStartOfDay = calendar.startOfDay(for: habit.startDate)
      
      // Check if endDate is in the recent past (within 7 days) - this is allowed for inactive habits
      let isRecentPast = endDate < today && endDate >= sevenDaysAgo
      
      // Only enforce "endDate must be after startDate" if endDate is not in the recent past
      // Recent past endDates are intentionally set to mark habits as inactive
      if endDateStartOfDay <= startDateStartOfDay && !isRecentPast {
        errors.append(ValidationError(
          field: "endDate",
          message: "End date must be after start date",
          severity: .error))
      }
    }

    return errors.isEmpty ? .valid : .invalid(errors)
  }
}

// MARK: - ValidationConfiguration

struct ValidationConfiguration {
  static let `default` = ValidationConfiguration(
    mode: .moderate,
    enableAutoFix: true,
    enableIntegrityChecking: true,
    enablePerformanceMonitoring: true,
    customRules: [
      HabitNameLengthRule(),
      HabitStreakConsistencyRule(),
      HabitDateConsistencyRule()
    ])

  static let strict = ValidationConfiguration(
    mode: .strict,
    enableAutoFix: false,
    enableIntegrityChecking: true,
    enablePerformanceMonitoring: true,
    customRules: [
      HabitNameLengthRule(),
      HabitStreakConsistencyRule(),
      HabitDateConsistencyRule()
    ])

  static let lenient = ValidationConfiguration(
    mode: .lenient,
    enableAutoFix: true,
    enableIntegrityChecking: false,
    enablePerformanceMonitoring: false,
    customRules: [])

  let mode: DataValidationService.ValidationMode
  let enableAutoFix: Bool
  let enableIntegrityChecking: Bool
  let enablePerformanceMonitoring: Bool
  let customRules: [ValidationRule]
}
