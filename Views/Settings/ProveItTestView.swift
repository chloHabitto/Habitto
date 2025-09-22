import SwiftUI

// MARK: - Prove-It Test View
// SwiftUI interface for running and displaying prove-it test scenarios

struct ProveItTestView: View {
    @StateObject private var testScenarios = ProveItTestScenarios.shared
    @State private var selectedSeverity: ProveItTestScenarios.TestSeverity? = nil
    @State private var showingTestDetails = false
    @State private var selectedResult: ProveItTestScenarios.TestScenarioResult? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Test Controls
                testControlsSection
                
                // Results Summary
                if !testScenarios.testResults.isEmpty {
                    resultsSummarySection
                }
                
                // Test Results List
                testResultsList
            }
            .navigationTitle("Prove-It Tests")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTestDetails) {
                if let result = selectedResult {
                    TestResultDetailView(result: result)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Migration System Validation")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Comprehensive testing of hardened migration system")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !testScenarios.testResults.isEmpty {
                let summary = testScenarios.getTestSummary()
                HStack(spacing: 20) {
                    StatCard(
                        title: "Success Rate",
                        value: "\(Int(summary.successRate * 100))%",
                        color: summary.successRate > 0.9 ? .green : summary.successRate > 0.7 ? .orange : .red
                    )
                    
                    StatCard(
                        title: "Total Tests",
                        value: "\(summary.totalTests)",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Production Ready",
                        value: summary.isProductionReady ? "✅" : "❌",
                        color: summary.isProductionReady ? .green : .red
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Test Controls Section
    
    private var testControlsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Test Controls")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if testScenarios.isRunning {
                VStack(spacing: 12) {
                    HStack {
                        ProgressView(value: testScenarios.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(Int(testScenarios.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                        Text("Running: \(testScenarios.currentTest)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } else {
                Button(action: {
                    Task {
                        await testScenarios.runAllTests()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run All Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Severity Filter
            if !testScenarios.testResults.isEmpty {
                HStack {
                    Text("Filter by Severity:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Severity", selection: $selectedSeverity) {
                        Text("All").tag(nil as ProveItTestScenarios.TestSeverity?)
                        ForEach(ProveItTestScenarios.TestSeverity.allCases, id: \.self) { severity in
                            Text(severity.rawValue).tag(severity as ProveItTestScenarios.TestSeverity?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Results Summary Section
    
    private var resultsSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Test Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                let summary = testScenarios.getTestSummary()
                Text("Avg Duration: \(String(format: "%.2f", summary.averageDuration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            let summary = testScenarios.getTestSummary()
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SeverityCard(
                    title: "Critical",
                    count: summary.criticalResults.count,
                    passed: summary.criticalResults.filter { $0.success }.count,
                    color: .red
                )
                
                SeverityCard(
                    title: "High",
                    count: summary.highResults.count,
                    passed: summary.highResults.filter { $0.success }.count,
                    color: .orange
                )
                
                SeverityCard(
                    title: "Medium",
                    count: summary.mediumResults.count,
                    passed: summary.mediumResults.filter { $0.success }.count,
                    color: .yellow
                )
                
                SeverityCard(
                    title: "Low",
                    count: summary.lowResults.count,
                    passed: summary.lowResults.filter { $0.success }.count,
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Test Results List
    
    private var testResultsList: some View {
        List {
            ForEach(filteredResults, id: \.scenario) { result in
                ProveItTestResultRow(result: result) {
                    selectedResult = result
                    showingTestDetails = true
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredResults: [ProveItTestScenarios.TestScenarioResult] {
        if let severity = selectedSeverity {
            return testScenarios.testResults.filter { $0.severity == severity }
        } else {
            return testScenarios.testResults
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct SeverityCard: View {
    let title: String
    let count: Int
    let passed: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(passed == count ? Color.green : color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text("\(passed)/\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(passed == count ? "✅" : "❌")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
}

struct ProveItTestResultRow: View {
    let result: ProveItTestScenarios.TestScenarioResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Icon
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.title2)
                
                // Test Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.scenario.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(result.scenario.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        // Severity Badge
                        Text(result.severity.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(result.severity.color.opacity(0.2))
                            .foregroundColor(result.severity.color)
                            .cornerRadius(4)
                        
                        // Duration
                        Text("\(String(format: "%.2f", result.duration))s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Metrics
                        Text("\(result.metrics.recordsProcessed) records")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TestResultDetailView: View {
    let result: ProveItTestScenarios.TestScenarioResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.scenario.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(result.scenario.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Severity Badge
                        HStack {
                            Text(result.severity.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(result.severity.color.opacity(0.2))
                                .foregroundColor(result.severity.color)
                                .cornerRadius(6)
                            
                            Spacer()
                        }
                    }
                    
                    // Test Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Details")
                            .font(.headline)
                        
                        DetailRow(label: "Duration", value: "\(String(format: "%.3f", result.duration))s")
                        DetailRow(label: "Start Time", value: DateFormatter.shortTime.string(from: result.startTime))
                        DetailRow(label: "End Time", value: DateFormatter.shortTime.string(from: result.endTime))
                        DetailRow(label: "Status", value: result.success ? "Success" : "Failed")
                        
                        if let error = result.error {
                            DetailRow(label: "Error", value: error)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Metrics")
                            .font(.headline)
                        
                        DetailRow(label: "Records Processed", value: "\(result.metrics.recordsProcessed)")
                        DetailRow(label: "Memory Usage", value: "\(result.metrics.memoryUsage / 1024 / 1024) MB")
                        DetailRow(label: "Disk Usage", value: "\(result.metrics.diskUsage / 1024 / 1024) MB")
                        DetailRow(label: "Network Calls", value: "\(result.metrics.networkCalls)")
                        DetailRow(label: "File Operations", value: "\(result.metrics.fileOperations)")
                        DetailRow(label: "Encryption Operations", value: "\(result.metrics.encryptionOperations)")
                        DetailRow(label: "Validation Checks", value: "\(result.metrics.validationChecks)")
                    }
                }
                .padding()
            }
            .navigationTitle("Test Result")
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

struct DetailRow: View {
    let label: String
    let value: String
    var foregroundColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(foregroundColor)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Preview

struct ProveItTestView_Previews: PreviewProvider {
    static var previews: some View {
        ProveItTestView()
    }
}
