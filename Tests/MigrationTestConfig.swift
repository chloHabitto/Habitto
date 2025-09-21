import Foundation

// MARK: - Migration Test Configuration
// Configuration for different test scenarios and environments

struct MigrationTestConfig {
    
    // MARK: - Test Scenarios
    
    enum TestScenario: String, CaseIterable {
        case successful = "successful_migration"
        case idempotent = "idempotent_migration"
        case emptyDataset = "empty_dataset"
        case killSwitch = "kill_switch"
        
        var description: String {
            switch self {
            case .successful: return "Normal migration flow"
            case .idempotent: return "Multiple migration runs"
            case .emptyDataset: return "Empty dataset migration"
            case .killSwitch: return "Kill switch functionality"
            }
        }
        
        var isCritical: Bool {
            switch self {
            case .successful, .killSwitch:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Test Data Sets
    
    enum TestDataSet: String, CaseIterable {
        case minimal = "minimal"
        case standard = "standard"
        
        var habitCount: Int {
            switch self {
            case .minimal: return 1
            case .standard: return 10
            }
        }
        
        var description: String {
            switch self {
            case .minimal: return "Single habit"
            case .standard: return "10 habits (typical user)"
            }
        }
    }
    
    // MARK: - Test Configuration
    
    struct Configuration {
        let scenario: TestScenario
        let dataSet: TestDataSet
        let enableKillSwitch: Bool
        
        init(scenario: TestScenario, 
             dataSet: TestDataSet = .standard,
             enableKillSwitch: Bool = false) {
            self.scenario = scenario
            self.dataSet = dataSet
            self.enableKillSwitch = enableKillSwitch
        }
    }
    
    // MARK: - Predefined Test Suites
    
    static let criticalTests: [Configuration] = [
        Configuration(scenario: .successful, dataSet: .standard),
        Configuration(scenario: .killSwitch, dataSet: .minimal)
    ]
    
    static let standardTests: [Configuration] = [
        Configuration(scenario: .successful, dataSet: .standard),
        Configuration(scenario: .idempotent, dataSet: .standard),
        Configuration(scenario: .emptyDataset, dataSet: .minimal),
        Configuration(scenario: .killSwitch, dataSet: .minimal)
    ]
    
    // MARK: - Test Results
    
    struct TestResult {
        let configuration: Configuration
        let success: Bool
        let duration: TimeInterval
        let errorMessage: String?
        let timestamp: Date
        
        init(configuration: Configuration, success: Bool, duration: TimeInterval, errorMessage: String? = nil) {
            self.configuration = configuration
            self.success = success
            self.duration = duration
            self.errorMessage = errorMessage
            self.timestamp = Date()
        }
    }
    
    struct TestSuiteResult {
        let results: [TestResult]
        let totalDuration: TimeInterval
        let successCount: Int
        let failureCount: Int
        
        var successRate: Double {
            guard !results.isEmpty else { return 0.0 }
            return Double(successCount) / Double(results.count)
        }
        
        var isSuccessful: Bool {
            return failureCount == 0
        }
    }
    
    // MARK: - Test Utilities
    
    static func generateTestReport(_ result: TestSuiteResult) -> String {
        var report = """
        📊 Migration Test Suite Report
        =============================
        
        Duration: \(String(format: "%.2f", result.totalDuration))s
        Success Rate: \(String(format: "%.1f", result.successRate * 100))%
        Results: \(result.successCount) passed, \(result.failureCount) failed
        
        """
        
        if result.failureCount > 0 {
            report += "\n❌ Failed Tests:\n"
            for result in result.results where !result.success {
                report += "• \(result.configuration.scenario.description): \(result.errorMessage ?? "Unknown error")\n"
            }
        }
        
        report += "\n✅ Passed Tests:\n"
        for result in result.results where result.success {
            report += "• \(result.configuration.scenario.description) (\(String(format: "%.2f", result.duration))s)\n"
        }
        
        return report
    }
}