import Foundation
import SwiftUI

// MARK: - Data Integrity Checker
class DataIntegrityChecker: ObservableObject {
    @Published var isChecking = false
    @Published var lastCheckTime: Date?
    @Published var issuesFound: [DataIntegrityIssue] = []
    
    private let habitValidator = HabitValidator()
    private let collectionValidator = HabitCollectionValidator()
    
    // MARK: - Public Methods
    
    func checkDataIntegrity(habits: [Habit]) async -> DataIntegrityReport {
        isChecking = true
        lastCheckTime = Date()
        
        defer {
            isChecking = false
        }
        
        var issues: [DataIntegrityIssue] = []
        
        // Check individual habits
        for (index, habit) in habits.enumerated() {
            let validationResult = habitValidator.validate(habit)
            if !validationResult.isValid {
                for error in validationResult.errors {
                    let issue = DataIntegrityIssue(
                        type: .validation,
                        severity: error.severity == .critical ? .critical : .error,
                        message: error.message,
                        field: "habits[\(index)].\(error.field)",
                        habitId: habit.id,
                        suggestedFix: getSuggestedFix(for: error)
                    )
                    issues.append(issue)
                }
            }
        }
        
        // Check collection-level integrity
        let collectionResult = collectionValidator.validate(habits)
        if !collectionResult.isValid {
            for error in collectionResult.errors {
                let issue = DataIntegrityIssue(
                    type: .collection,
                    severity: error.severity == .critical ? .critical : .warning,
                    message: error.message,
                    field: error.field,
                    habitId: nil,
                    suggestedFix: getSuggestedFix(for: error)
                )
                issues.append(issue)
            }
        }
        
        // Check data consistency
        issues.append(contentsOf: checkDataConsistency(habits))
        
        // Check for orphaned data
        issues.append(contentsOf: checkOrphanedData(habits))
        
        // Check for performance issues
        issues.append(contentsOf: checkPerformanceIssues(habits))
        
        await MainActor.run { [issues] in
            self.issuesFound = issues
        }
        
        return DataIntegrityReport(
            totalIssues: issues.count,
            criticalIssues: issues.filter { $0.severity == .critical }.count,
            errorIssues: issues.filter { $0.severity == .error }.count,
            warningIssues: issues.filter { $0.severity == .warning }.count,
            issues: issues,
            checkTime: lastCheckTime ?? Date()
        )
    }
    
    func autoFixIssues(habits: inout [Habit]) -> [DataIntegrityIssue] {
        var fixedIssues: [DataIntegrityIssue] = []
        
        for (index, var habit) in habits.enumerated() {
            // Fix streak inconsistencies
            if !habit.validateStreak() {
                let oldStreak = habit.streak
                habit.correctStreak()
                habits[index] = habit
                
                let issue = DataIntegrityIssue(
                    type: .consistency,
                    severity: .warning,
                    message: "Fixed streak inconsistency: \(oldStreak) → \(habit.streak)",
                    field: "habits[\(index)].streak",
                    habitId: habit.id,
                    suggestedFix: "Streak corrected to match completion history"
                )
                fixedIssues.append(issue)
            }
            
            // Remove future completion dates
            let today = Calendar.current.startOfDay(for: Date())
            let futureDates = habit.completionHistory.keys.filter { dateKey in
                if let date = parseDate(from: dateKey) {
                    return date > today
                }
                return false
            }
            
            if !futureDates.isEmpty {
                for dateKey in futureDates {
                    habit.completionHistory.removeValue(forKey: dateKey)
                }
                habits[index] = habit
                
                let issue = DataIntegrityIssue(
                    type: .consistency,
                    severity: .warning,
                    message: "Removed \(futureDates.count) future completion dates",
                    field: "habits[\(index)].completionHistory",
                    habitId: habit.id,
                    suggestedFix: "Future completion dates removed"
                )
                fixedIssues.append(issue)
            }
            
            // Fix invalid difficulty values
            let invalidDifficulties = habit.difficultyHistory.filter { $0.value < 1 || $0.value > 10 }
            if !invalidDifficulties.isEmpty {
                for (dateKey, _) in invalidDifficulties {
                    habit.difficultyHistory.removeValue(forKey: dateKey)
                }
                habits[index] = habit
                
                let issue = DataIntegrityIssue(
                    type: .consistency,
                    severity: .warning,
                    message: "Removed \(invalidDifficulties.count) invalid difficulty values",
                    field: "habits[\(index)].difficultyHistory",
                    habitId: habit.id,
                    suggestedFix: "Invalid difficulty values removed"
                )
                fixedIssues.append(issue)
            }
        }
        
        return fixedIssues
    }
    
    // MARK: - Private Methods
    
    private func checkDataConsistency(_ habits: [Habit]) -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        for (index, habit) in habits.enumerated() {
            // Check streak consistency
            if !habit.validateStreak() {
                let issue = DataIntegrityIssue(
                    type: .consistency,
                    severity: .warning,
                    message: "Streak count (\(habit.streak)) doesn't match completion history",
                    field: "habits[\(index)].streak",
                    habitId: habit.id,
                    suggestedFix: "Recalculate streak based on completion history"
                )
                issues.append(issue)
            }
            
            // Check for completion dates before habit start date
            let startDate = Calendar.current.startOfDay(for: habit.startDate)
            let earlyCompletions = habit.completionHistory.keys.filter { dateKey in
                if let date = parseDate(from: dateKey) {
                    return date < startDate
                }
                return false
            }
            
            if !earlyCompletions.isEmpty {
                let issue = DataIntegrityIssue(
                    type: .consistency,
                    severity: .warning,
                    message: "Found \(earlyCompletions.count) completion dates before habit start date",
                    field: "habits[\(index)].completionHistory",
                    habitId: habit.id,
                    suggestedFix: "Remove completion dates before start date"
                )
                issues.append(issue)
            }
        }
        
        return issues
    }
    
    private func checkOrphanedData(_ habits: [Habit]) -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        // Check for habits with no completion history but positive streak
        for (index, habit) in habits.enumerated() {
            if habit.streak > 0 && habit.completionHistory.isEmpty {
                let issue = DataIntegrityIssue(
                    type: .orphaned,
                    severity: .warning,
                    message: "Habit has positive streak but no completion history",
                    field: "habits[\(index)].streak",
                    habitId: habit.id,
                    suggestedFix: "Reset streak to 0 or add completion history"
                )
                issues.append(issue)
            }
        }
        
        return issues
    }
    
    private func checkPerformanceIssues(_ habits: [Habit]) -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        // Check for habits with excessive completion history
        for (index, habit) in habits.enumerated() {
            if habit.completionHistory.count > 1000 {
                let issue = DataIntegrityIssue(
                    type: .performance,
                    severity: .warning,
                    message: "Habit has \(habit.completionHistory.count) completion records (consider archiving old data)",
                    field: "habits[\(index)].completionHistory",
                    habitId: habit.id,
                    suggestedFix: "Archive completion history older than 1 year"
                )
                issues.append(issue)
            }
        }
        
        // Check for habits with excessive difficulty history
        for (index, habit) in habits.enumerated() {
            if habit.difficultyHistory.count > 1000 {
                let issue = DataIntegrityIssue(
                    type: .performance,
                    severity: .warning,
                    message: "Habit has \(habit.difficultyHistory.count) difficulty records (consider archiving old data)",
                    field: "habits[\(index)].difficultyHistory",
                    habitId: habit.id,
                    suggestedFix: "Archive difficulty history older than 1 year"
                )
                issues.append(issue)
            }
        }
        
        return issues
    }
    
    private func getSuggestedFix(for error: ValidationError) -> String {
        switch error.field {
        case "name":
            return "Enter a valid habit name (2-50 characters)"
        case "description":
            return "Keep description under 200 characters"
        case "icon":
            return "Select a valid system icon"
        case "schedule":
            return "Select a valid schedule format"
        case "goal":
            return "Enter a valid goal number"
        case "streak":
            return "Recalculate streak based on completion history"
        case "completionHistory":
            return "Remove invalid completion dates"
        case "difficultyHistory":
            return "Remove invalid difficulty values"
        default:
            return "Review and correct the input"
        }
    }
    
    private func parseDate(from dateKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateKey)
    }
}

// MARK: - Data Integrity Issue
struct DataIntegrityIssue: Identifiable {
    let id = UUID()
    let type: IssueType
    let severity: IssueSeverity
    let message: String
    let field: String
    let habitId: UUID?
    let suggestedFix: String
    let timestamp: Date
    
    init(type: IssueType, severity: IssueSeverity, message: String, field: String, habitId: UUID?, suggestedFix: String) {
        self.type = type
        self.severity = severity
        self.message = message
        self.field = field
        self.habitId = habitId
        self.suggestedFix = suggestedFix
        self.timestamp = Date()
    }
}

enum IssueType {
    case validation
    case consistency
    case orphaned
    case performance
    case collection
}

enum IssueSeverity {
    case info
    case warning
    case error
    case critical
}

// MARK: - Data Integrity Report
struct DataIntegrityReport {
    let totalIssues: Int
    let criticalIssues: Int
    let errorIssues: Int
    let warningIssues: Int
    let issues: [DataIntegrityIssue]
    let checkTime: Date
    
    var hasIssues: Bool {
        return totalIssues > 0
    }
    
    var hasCriticalIssues: Bool {
        return criticalIssues > 0
    }
    
    var summary: String {
        if totalIssues == 0 {
            return "No issues found"
        } else {
            var parts: [String] = []
            if criticalIssues > 0 { parts.append("\(criticalIssues) critical") }
            if errorIssues > 0 { parts.append("\(errorIssues) errors") }
            if warningIssues > 0 { parts.append("\(warningIssues) warnings") }
            return parts.joined(separator: ", ")
        }
    }
}

// MARK: - Data Integrity Monitor
@MainActor
class DataIntegrityMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var lastReport: DataIntegrityReport?
    
    private let checker = DataIntegrityChecker()
    private var monitoringTask: Task<Void, Never>?
    
    func startMonitoring(habits: @escaping @MainActor () -> [Habit], interval: TimeInterval = 300) { // 5 minutes
        stopMonitoring()
        
        isMonitoring = true
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled {
                let currentHabits = habits()
                let report = await checker.checkDataIntegrity(habits: currentHabits)
                lastReport = report
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }
    
    func performManualCheck(habits: [Habit]) async {
        let report = await checker.checkDataIntegrity(habits: habits)
        lastReport = report
    }
}
