import Foundation
import SwiftUI

// MARK: - Migration Test Runner
// Executes migration tests with different configurations and plans

@MainActor
class MigrationTestRunner: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isRunning = false
    @Published var currentTest: String = ""
    @Published var progress: Double = 0.0
    @Published var results: [MigrationTestConfig.TestResult] = []
    
    private let testSuite = MigrationTestSuite()
    private var startTime: Date?
    
    // MARK: - Test Execution
    
    func runStandardTests() async -> MigrationTestConfig.TestSuiteResult {
        isRunning = true
        startTime = Date()
        results = []
        
        let configurations = MigrationTestConfig.standardTests
        let totalTests = configurations.count
        
        print("🚀 Starting Migration Test Plan: Standard Tests")
        print("📋 Running \(totalTests) tests...")
        
        for (index, config) in configurations.enumerated() {
            let result = await runSingleTest(config)
            results.append(result)
            
            progress = Double(index + 1) / Double(totalTests)
            currentTest = config.scenario.description
            
            // Log result
            if result.success {
                print("✅ \(config.scenario.description): PASSED (\(String(format: "%.2f", result.duration))s)")
            } else {
                print("❌ \(config.scenario.description): FAILED - \(result.errorMessage ?? "Unknown error")")
            }
        }
        
        isRunning = false
        currentTest = ""
        progress = 1.0
        
        let totalDuration = Date().timeIntervalSince(startTime ?? Date())
        let successCount = results.filter { $0.success }.count
        let failureCount = results.filter { !$0.success }.count
        
        let suiteResult = MigrationTestConfig.TestSuiteResult(
            results: results,
            totalDuration: totalDuration,
            successCount: successCount,
            failureCount: failureCount
        )
        
        print("🏁 Test Plan Completed:")
        print(MigrationTestConfig.generateTestReport(suiteResult))
        
        return suiteResult
    }
    
    private func runSingleTest(_ config: MigrationTestConfig.Configuration) async -> MigrationTestConfig.TestResult {
        let startTime = Date()
        
        do {
            switch config.scenario {
            case .successful:
                try await testSuite.testSuccessfulMigration()
            case .idempotent:
                try await testSuite.testIdempotentMigration()
            case .emptyDataset:
                try await testSuite.testEmptyDatasetMigration()
            case .killSwitch:
                try await testSuite.testKillSwitchEnabled()
            }
            
            let duration = Date().timeIntervalSince(startTime)
            return MigrationTestConfig.TestResult(
                configuration: config,
                success: true,
                duration: duration
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return MigrationTestConfig.TestResult(
                configuration: config,
                success: false,
                duration: duration,
                errorMessage: error.localizedDescription
            )
        }
    }
}

// MARK: - Test UI Components

struct MigrationTestView: View {
    @StateObject private var testRunner = MigrationTestRunner()
    @State private var testResult: MigrationTestConfig.TestSuiteResult?
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Test Plan Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Plan Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Tests: \(MigrationTestConfig.standardTests.count)")
                    Text("Estimated Duration: ~30s")
                    Text("Description: Standard validation tests")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Run Button
                Button(action: runTests) {
                    HStack {
                        if testRunner.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(testRunner.isRunning ? "Running Tests..." : "Run Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(testRunner.isRunning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(testRunner.isRunning)
                
                // Progress
                if testRunner.isRunning {
                    VStack(spacing: 8) {
                        ProgressView(value: testRunner.progress)
                        Text(testRunner.currentTest)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Migration Tests")
            .sheet(isPresented: $showingResults) {
                if let result = testResult {
                    TestResultsView(result: result)
                }
            }
        }
    }
    
    private func runTests() {
        Task {
            let result = await testRunner.runStandardTests()
            testResult = result
            showingResults = true
        }
    }
}

struct TestResultsView: View {
    let result: MigrationTestConfig.TestSuiteResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Success Rate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", result.successRate * 100))%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(result.isSuccessful ? .green : .red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", result.totalDuration))s")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack {
                        Text("✅ \(result.successCount) passed")
                            .foregroundColor(.green)
                        Spacer()
                        Text("❌ \(result.failureCount) failed")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Detailed Results
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Results")
                        .font(.headline)
                    
                    ForEach(result.results, id: \.timestamp) { testResult in
                        HStack {
                            Image(systemName: testResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testResult.success ? .green : .red)
                            
                            VStack(alignment: .leading) {
                                Text(testResult.configuration.scenario.description)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let error = testResult.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(String(format: "%.2f", testResult.duration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}