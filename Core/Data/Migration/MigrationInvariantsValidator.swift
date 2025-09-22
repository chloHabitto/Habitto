import Foundation
import UIKit

// MARK: - Migration Invariants Validator
// Comprehensive validation system for migration data integrity

struct MigrationInvariantsValidator {
    
    // MARK: - Invariant Types
    
    enum InvariantType: String, CaseIterable, Codable {
        case primaryKeyUniqueness = "primary_key_uniqueness"
        case referentialIntegrity = "referential_integrity"
        case dataTypeValidity = "data_type_validity"
        case enumValueValidity = "enum_value_validity"
        case dateBoundsValidity = "date_bounds_validity"
        case counterMonotonicity = "counter_monotonicity"
        case stringLengthBounds = "string_length_bounds"
        case requiredFieldPresence = "required_field_presence"
        case relationshipConsistency = "relationship_consistency"
        case businessRuleCompliance = "business_rule_compliance"
    }
    
    // MARK: - Validation Result
    
    struct ValidationResult: Codable {
        let isValid: Bool
        let failedInvariants: [InvariantFailure]
        let warnings: [InvariantWarning]
        let summary: ValidationSummary
        
        struct InvariantFailure: Codable {
            let type: InvariantType
            let message: String
            let affectedRecords: [String]
            let severity: Severity
            
            enum Severity: String, CaseIterable, Codable {
                case critical = "critical"
                case high = "high"
                case medium = "medium"
                case low = "low"
            }
        }
        
        struct InvariantWarning: Codable {
            let type: InvariantType
            let message: String
            let suggestion: String
        }
        
        struct ValidationSummary: Codable {
            let totalRecords: Int
            let validRecords: Int
            let invalidRecords: Int
            let criticalFailures: Int
            let highFailures: Int
            let mediumFailures: Int
            let lowFailures: Int
            let warnings: Int
            let validationDuration: TimeInterval
        }
    }
    
    // MARK: - Validation Context
    
    struct ValidationContext {
        let habits: [Habit]
        let migrationVersion: String
        let previousVersion: String?
        let validationTimestamp: Date
        let deviceInfo: DeviceInfo
        
        struct DeviceInfo {
            let appVersion: String
            let iosVersion: String
            let freeDiskSpace: Int64?
            let deviceModel: String
            
            init() {
                self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                self.iosVersion = UIDevice.current.systemVersion
                self.deviceModel = UIDevice.current.model
                self.freeDiskSpace = Self.getFreeDiskSpace()
            }
            
            private static func getFreeDiskSpace() -> Int64? {
                do {
                    let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
                    return attributes[.systemFreeSize] as? Int64
                } catch {
                    return nil
                }
            }
        }
    }
    
    // MARK: - Public Interface
    
    static func validateInvariants(for habits: [Habit], migrationVersion: String, previousVersion: String? = nil) async -> ValidationResult {
        let startTime = Date()
        let context = ValidationContext(
            habits: habits,
            migrationVersion: migrationVersion,
            previousVersion: previousVersion,
            validationTimestamp: Date(),
            deviceInfo: ValidationContext.DeviceInfo()
        )
        
        var allFailures: [ValidationResult.InvariantFailure] = []
        var allWarnings: [ValidationResult.InvariantWarning] = []
        
        // Run all invariant checks
        for invariantType in InvariantType.allCases {
            let result = await validateInvariant(invariantType, context: context)
            allFailures.append(contentsOf: result.failures)
            allWarnings.append(contentsOf: result.warnings)
        }
        
        let validationDuration = Date().timeIntervalSince(startTime)
        let summary = createValidationSummary(
            totalRecords: habits.count,
            failures: allFailures,
            warnings: allWarnings,
            duration: validationDuration
        )
        
        return ValidationResult(
            isValid: allFailures.filter { $0.severity == .critical || $0.severity == .high }.isEmpty,
            failedInvariants: allFailures,
            warnings: allWarnings,
            summary: summary
        )
    }
    
    // MARK: - Individual Invariant Validators
    
    private static func validateInvariant(_ type: InvariantType, context: ValidationContext) async -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        switch type {
        case .primaryKeyUniqueness:
            return validatePrimaryKeyUniqueness(context)
        case .referentialIntegrity:
            return validateReferentialIntegrity(context)
        case .dataTypeValidity:
            return validateDataTypeValidity(context)
        case .enumValueValidity:
            return validateEnumValueValidity(context)
        case .dateBoundsValidity:
            return validateDateBoundsValidity(context)
        case .counterMonotonicity:
            return validateCounterMonotonicity(context)
        case .stringLengthBounds:
            return validateStringLengthBounds(context)
        case .requiredFieldPresence:
            return validateRequiredFieldPresence(context)
        case .relationshipConsistency:
            return validateRelationshipConsistency(context)
        case .businessRuleCompliance:
            return validateBusinessRuleCompliance(context)
        }
    }
    
    // MARK: - Specific Validators
    
    private static func validatePrimaryKeyUniqueness(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        let ids = context.habits.map { $0.id }
        let uniqueIds = Set(ids)
        
        if ids.count != uniqueIds.count {
            let duplicates = ids.filter { id in
                ids.filter { $0 == id }.count > 1
            }
            
            failures.append(ValidationResult.InvariantFailure(
                type: .primaryKeyUniqueness,
                message: "Duplicate habit IDs found",
                affectedRecords: duplicates.map { $0.uuidString },
                severity: .critical
            ))
        }
        
        return (failures, warnings)
    }
    
    private static func validateReferentialIntegrity(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        // Check for orphaned records or broken references
        // For habits, we mainly check that all referenced data is consistent
        
        for habit in context.habits {
            // Check reminder references
            if !habit.reminders.isEmpty {
                let validReminders = habit.reminders.filter { reminder in
                    !reminder.id.uuidString.isEmpty
                }
                
                if validReminders.count != habit.reminders.count {
                    failures.append(ValidationResult.InvariantFailure(
                        type: .referentialIntegrity,
                        message: "Invalid reminder references found",
                        affectedRecords: [habit.id.uuidString],
                        severity: .medium
                    ))
                }
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateDataTypeValidity(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check numeric fields
            if habit.baseline < 0 || habit.target < 0 {
                failures.append(ValidationResult.InvariantFailure(
                    type: .dataTypeValidity,
                    message: "Negative values in numeric fields",
                    affectedRecords: [habit.id.uuidString],
                    severity: .high
                ))
            }
            
            if habit.streak < 0 {
                failures.append(ValidationResult.InvariantFailure(
                    type: .dataTypeValidity,
                    message: "Negative streak value",
                    affectedRecords: [habit.id.uuidString],
                    severity: .medium
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateEnumValueValidity(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check if habitType is valid
            if !HabitType.allCases.contains(where: { $0.rawValue == habit.habitType.rawValue }) {
                failures.append(ValidationResult.InvariantFailure(
                    type: .enumValueValidity,
                    message: "Invalid habit type: \(habit.habitType.rawValue)",
                    affectedRecords: [habit.id.uuidString],
                    severity: .high
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateDateBoundsValidity(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        var warnings: [ValidationResult.InvariantWarning] = []
        
        let now = Date()
        let farFuture = Calendar.current.date(byAdding: .year, value: 10, to: now) ?? now
        let farPast = Calendar.current.date(byAdding: .year, value: -10, to: now) ?? now
        
        for habit in context.habits {
            // Check start date
            if habit.startDate > now {
                warnings.append(ValidationResult.InvariantWarning(
                    type: .dateBoundsValidity,
                    message: "Start date is in the future",
                    suggestion: "Consider if this is intentional"
                ))
            }
            
            if habit.startDate < farPast {
                warnings.append(ValidationResult.InvariantWarning(
                    type: .dateBoundsValidity,
                    message: "Start date is very old",
                    suggestion: "Consider data cleanup"
                ))
            }
            
            // Check end date
            if let endDate = habit.endDate {
                if endDate < habit.startDate {
                    failures.append(ValidationResult.InvariantFailure(
                        type: .dateBoundsValidity,
                        message: "End date is before start date",
                        affectedRecords: [habit.id.uuidString],
                        severity: .high
                    ))
                }
                
                if endDate > farFuture {
                    warnings.append(ValidationResult.InvariantWarning(
                        type: .dateBoundsValidity,
                        message: "End date is very far in the future",
                        suggestion: "Consider if this is intentional"
                    ))
                }
            }
            
            // Check created date
            if habit.createdAt > now {
                failures.append(ValidationResult.InvariantFailure(
                    type: .dateBoundsValidity,
                    message: "Created date is in the future",
                    affectedRecords: [habit.id.uuidString],
                    severity: .critical
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateCounterMonotonicity(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check completion history monotonicity
            let completionDates = habit.completionHistory.keys.compactMap { dateString in
                // Simple date parsing - you may want to use a more robust date formatter
                ISO8601DateFormatter().date(from: dateString)
            }.sorted()
            
            if completionDates.count > 1 {
                for i in 1..<completionDates.count {
                    if completionDates[i] < completionDates[i-1] {
                        failures.append(ValidationResult.InvariantFailure(
                            type: .counterMonotonicity,
                            message: "Non-monotonic completion dates",
                            affectedRecords: [habit.id.uuidString],
                            severity: .medium
                        ))
                        break
                    }
                }
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateStringLengthBounds(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        var warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check name length
            if habit.name.isEmpty {
                failures.append(ValidationResult.InvariantFailure(
                    type: .stringLengthBounds,
                    message: "Empty habit name",
                    affectedRecords: [habit.id.uuidString],
                    severity: .critical
                ))
            } else if habit.name.count > 100 {
                failures.append(ValidationResult.InvariantFailure(
                    type: .stringLengthBounds,
                    message: "Habit name too long (\(habit.name.count) characters)",
                    affectedRecords: [habit.id.uuidString],
                    severity: .high
                ))
            }
            
            // Check description length
            if habit.description.count > 500 {
                warnings.append(ValidationResult.InvariantWarning(
                    type: .stringLengthBounds,
                    message: "Description very long (\(habit.description.count) characters)",
                    suggestion: "Consider shortening for better UX"
                ))
            }
            
            // Check icon validity
            if habit.icon.isEmpty {
                failures.append(ValidationResult.InvariantFailure(
                    type: .stringLengthBounds,
                    message: "Empty icon",
                    affectedRecords: [habit.id.uuidString],
                    severity: .medium
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateRequiredFieldPresence(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check required fields
            if habit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(ValidationResult.InvariantFailure(
                    type: .requiredFieldPresence,
                    message: "Missing required field: name",
                    affectedRecords: [habit.id.uuidString],
                    severity: .critical
                ))
            }
            
            if habit.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(ValidationResult.InvariantFailure(
                    type: .requiredFieldPresence,
                    message: "Missing required field: goal",
                    affectedRecords: [habit.id.uuidString],
                    severity: .high
                ))
            }
            
            if habit.schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(ValidationResult.InvariantFailure(
                    type: .requiredFieldPresence,
                    message: "Missing required field: schedule",
                    affectedRecords: [habit.id.uuidString],
                    severity: .high
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateRelationshipConsistency(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        let warnings: [ValidationResult.InvariantWarning] = []
        
        // Check for circular references or inconsistent relationships
        // For habits, this mainly involves checking reminder relationships
        
        for habit in context.habits {
            // Check that reminders are properly associated
            for reminder in habit.reminders {
                // Check if reminder has valid time (not too far in past or future)
                let now = Date()
                let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
                let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
                
                if reminder.time < oneYearAgo || reminder.time > oneYearFromNow {
                    failures.append(ValidationResult.InvariantFailure(
                        type: .relationshipConsistency,
                        message: "Reminder time is outside reasonable range",
                        affectedRecords: [habit.id.uuidString],
                        severity: .medium
                    ))
                }
            }
        }
        
        return (failures, warnings)
    }
    
    private static func validateBusinessRuleCompliance(_ context: ValidationContext) -> (failures: [ValidationResult.InvariantFailure], warnings: [ValidationResult.InvariantWarning]) {
        var failures: [ValidationResult.InvariantFailure] = []
        var warnings: [ValidationResult.InvariantWarning] = []
        
        for habit in context.habits {
            // Check business rules
            
            // Rule: Target should be >= baseline
            if habit.target < habit.baseline {
                failures.append(ValidationResult.InvariantFailure(
                    type: .businessRuleCompliance,
                    message: "Target (\(habit.target)) is less than baseline (\(habit.baseline))",
                    affectedRecords: [habit.id.uuidString],
                    severity: .medium
                ))
            }
            
            // Rule: Streak should be reasonable (not more than days since start)
            let daysSinceStart = Calendar.current.dateComponents([.day], from: habit.startDate, to: Date()).day ?? 0
            if habit.streak > daysSinceStart + 7 { // Allow some buffer
                warnings.append(ValidationResult.InvariantWarning(
                    type: .businessRuleCompliance,
                    message: "Streak (\(habit.streak)) seems unusually high for start date",
                    suggestion: "Verify streak calculation logic"
                ))
            }
        }
        
        return (failures, warnings)
    }
    
    // MARK: - Helper Methods
    
    private static func createValidationSummary(
        totalRecords: Int,
        failures: [ValidationResult.InvariantFailure],
        warnings: [ValidationResult.InvariantWarning],
        duration: TimeInterval
    ) -> ValidationResult.ValidationSummary {
        let invalidRecords = Set(failures.flatMap { $0.affectedRecords }).count
        let validRecords = totalRecords - invalidRecords
        
        return ValidationResult.ValidationSummary(
            totalRecords: totalRecords,
            validRecords: validRecords,
            invalidRecords: invalidRecords,
            criticalFailures: failures.filter { $0.severity == .critical }.count,
            highFailures: failures.filter { $0.severity == .high }.count,
            mediumFailures: failures.filter { $0.severity == .medium }.count,
            lowFailures: failures.filter { $0.severity == .low }.count,
            warnings: warnings.count,
            validationDuration: duration
        )
    }
}

// MARK: - Resume Token System

struct MigrationResumeToken: Codable {
    let tokenId: UUID
    let migrationVersion: String
    let completedSteps: [String]
    let currentStep: String?
    let stepVersionHash: String
    let createdAt: Date
    let lastUpdated: Date
    let validationResult: MigrationInvariantsValidator.ValidationResult?
    
    struct StepVersionHash {
        let stepName: String
        let stepCodeHash: String
        let migrationVersion: String
        
        func generateHash() -> String {
            let combined = "\(stepName)-\(stepCodeHash)-\(migrationVersion)"
            return combined.data(using: .utf8)?.base64EncodedString() ?? ""
        }
    }
    
    func isStepCompleted(_ stepName: String) -> Bool {
        return completedSteps.contains(stepName)
    }
    
    func canResumeFromStep(_ stepName: String, withHash stepHash: String) -> Bool {
        guard let currentStep = currentStep else { return false }
        return currentStep == stepName && stepVersionHash == stepHash
    }
    
    func toData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func fromData(_ data: Data) -> MigrationResumeToken? {
        return try? JSONDecoder().decode(MigrationResumeToken.self, from: data)
    }
}
