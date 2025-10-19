import SwiftUI
import SwiftData

/// Debug view for testing migration system
///
/// **Access via:** Settings → Advanced → Migration Debug
struct MigrationDebugView: View {
    // MARK: - State
    
    @StateObject private var testRunner = MigrationTestRunner()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Test Data Section
            Section {
                HStack {
                    Text("Old Habits:")
                    Spacer()
                    Text("\(testRunner.getOldDataStatus().habitCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Old Progress:")
                    Spacer()
                    Text("\(testRunner.getOldDataStatus().progressCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Old XP:")
                    Spacer()
                    Text("\(testRunner.getOldDataStatus().xp)")
                        .foregroundColor(.secondary)
                }
                
                Button {
                    generateTestData()
                } label: {
                    Label("Generate Sample Data", systemImage: "plus.circle.fill")
                }
                
                Button(role: .destructive) {
                    clearTestData()
                } label: {
                    Label("Clear Sample Data", systemImage: "trash")
                }
            } header: {
                Text("Test Data")
            } footer: {
                Text("Generate sample habits for testing migration")
            }
            
            // Migration Section
            Section {
                Button {
                    runDryRun()
                } label: {
                    Label("Run Dry Run", systemImage: "flask")
                }
                .disabled(testRunner.isRunning)
                
                Button {
                    runActualMigration()
                } label: {
                    Label("Run Actual Migration", systemImage: "arrow.right.circle.fill")
                }
                .disabled(testRunner.isRunning)
                
                Button(role: .destructive) {
                    rollback()
                } label: {
                    Label("Rollback Migration", systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(testRunner.isRunning)
            } header: {
                Text("Migration")
            } footer: {
                Text("Test migration without affecting production data")
            }
            
            // Validation Section
            Section {
                Button {
                    validate()
                } label: {
                    Label("Validate Data", systemImage: "checkmark.shield")
                }
                .disabled(testRunner.isRunning)
                
                if let result = testRunner.validationResult {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(result.isValid ? "✅ PASSED" : "❌ FAILED")
                            .foregroundColor(result.isValid ? .green : .red)
                    }
                    
                    if !result.isValid {
                        ForEach(result.errors, id: \.self) { error in
                            Text("❌ \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            } header: {
                Text("Validation")
            }
            
            // Full Test Section
            Section {
                Button {
                    runFullTest()
                } label: {
                    Label("Run Full Test", systemImage: "play.circle.fill")
                        .fontWeight(.semibold)
                }
                .disabled(testRunner.isRunning)
            } header: {
                Text("Automated Testing")
            } footer: {
                Text("Runs complete test: generate data → dry run → migrate → validate → cleanup")
            }
            
            // Progress Section
            if testRunner.isRunning {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ProgressView(value: testRunner.progress)
                            Text("\(Int(testRunner.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(testRunner.currentStep)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Progress")
                }
            }
            
            // Summary Section
            if let summary = testRunner.migrationSummary {
                Section {
                    SummaryRow(title: "Status", value: summary.success ? "✅ Success" : "❌ Failed", valueColor: summary.success ? .green : .red)
                    SummaryRow(title: "Mode", value: summary.dryRun ? "🧪 Dry Run" : "💾 Live")
                    SummaryRow(title: "Habits", value: "\(summary.habitsCreated)")
                    SummaryRow(title: "Progress", value: "\(summary.progressRecordsCreated)")
                    SummaryRow(title: "XP", value: "\(summary.totalXP)")
                    SummaryRow(title: "Level", value: "\(UserProgressModel.calculateLevel(fromXP: summary.totalXP))")
                    SummaryRow(title: "Current Streak", value: "\(summary.currentStreak) days")
                    SummaryRow(title: "Longest Streak", value: "\(summary.longestStreak) days")
                    
                    if let duration = summary.duration {
                        SummaryRow(title: "Duration", value: String(format: "%.2fs", duration))
                    }
                    
                    // Schedule parsing details
                    if !summary.scheduleParsing.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Schedule Parsing:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(summary.scheduleParsing.sorted(by: { $0.key < $1.key }), id: \.key) { type, count in
                                Text("  • \(type): \(count) habits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Migration Summary")
                }
            }
            
            // Output Log Section
            Section {
                ScrollView {
                    Text(testRunner.output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 300)
                
                Button {
                    testRunner.output = ""
                } label: {
                    Label("Clear Log", systemImage: "trash")
                }
            } header: {
                Text("Output Log")
            }
        }
        .navigationTitle("Migration Debug")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            setupTestRunner()
        }
    }
    
    // MARK: - Actions
    
    private func setupTestRunner() {
        do {
            try testRunner.setup()
        } catch {
            showAlert(title: "Setup Failed", message: error.localizedDescription)
        }
    }
    
    private func generateTestData() {
        testRunner.generateTestData()
        showAlert(title: "Success", message: "Generated \(testRunner.getOldDataStatus().habitCount) test habits")
    }
    
    private func clearTestData() {
        testRunner.clearTestData()
        showAlert(title: "Success", message: "Test data cleared")
    }
    
    private func runDryRun() {
        Task {
            do {
                try await testRunner.runDryRun()
                showAlert(title: "Dry Run Complete", message: testRunner.migrationSummary?.success == true ? "Migration test passed" : "Migration test failed")
            } catch {
                showAlert(title: "Dry Run Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func runActualMigration() {
        Task {
            do {
                try await testRunner.runActualMigration()
                showAlert(title: "Migration Complete", message: testRunner.migrationSummary?.success == true ? "Data migrated successfully" : "Migration failed")
            } catch {
                showAlert(title: "Migration Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func rollback() {
        Task {
            do {
                try await testRunner.rollback()
                showAlert(title: "Rollback Complete", message: "All new data deleted")
            } catch {
                showAlert(title: "Rollback Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func validate() {
        Task {
            do {
                try await testRunner.validateMigration()
                let isValid = testRunner.validationResult?.isValid == true
                showAlert(
                    title: isValid ? "Validation Passed" : "Validation Failed",
                    message: isValid ? "All checks passed" : "Some checks failed - see details"
                )
            } catch {
                showAlert(title: "Validation Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func runFullTest() {
        Task {
            await testRunner.runFullTest()
            let success = testRunner.migrationSummary?.success == true && testRunner.validationResult?.isValid == true
            showAlert(
                title: success ? "All Tests Passed" : "Tests Failed",
                message: success ? "Migration system is working correctly" : "Some tests failed - check log for details"
            )
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MigrationDebugView()
    }
}
