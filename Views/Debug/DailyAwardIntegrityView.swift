import SwiftUI

#if DEBUG
/// Debug view for investigating and fixing DailyAward integrity issues
///
/// **Access via:** Settings → Advanced → Daily Award Integrity
struct DailyAwardIntegrityView: View {
    @State private var investigationResult: DailyAwardIntegrityService.InvestigationResult?
    @State private var isInvestigating = false
    @State private var isCleaningUp = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showCleanupConfirmation = false
    
    var body: some View {
        List {
            // Summary Section
            if let result = investigationResult {
                Section {
                    HStack {
                        Text("Total Awards:")
                        Spacer()
                        Text("\(result.totalAwards)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Valid Awards:")
                        Spacer()
                        Text("\(result.validAwards)")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Invalid Awards:")
                        Spacer()
                        Text("\(result.invalidAwards.count)")
                            .foregroundColor(result.invalidAwards.isEmpty ? .secondary : .red)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total XP:")
                        Spacer()
                        Text("\(result.totalXPFromAwards)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Valid XP:")
                        Spacer()
                        Text("\(result.validXP)")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Invalid XP:")
                        Spacer()
                        Text("\(result.invalidXP)")
                            .foregroundColor(result.invalidXP == 0 ? .secondary : .red)
                    }
                } header: {
                    Text("Investigation Summary")
                }
                
                // Invalid Awards Details
                if !result.invalidAwards.isEmpty {
                    Section {
                        ForEach(Array(result.invalidAwards.enumerated()), id: \.offset) { index, invalid in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invalid.dateKey)
                                    .font(.headline)
                                
                                Text("\(invalid.xpGranted) XP")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(invalid.reason)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                if !invalid.missingHabits.isEmpty {
                                    Text("Missing: \(invalid.missingHabits.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Scheduled: \(invalid.scheduledHabitsCount), Completed: \(invalid.completedHabitsCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Invalid Awards")
                    }
                }
            }
            
            // Actions Section
            Section {
                Button {
                    runInvestigation()
                } label: {
                    HStack {
                        if isInvestigating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text("Investigate DailyAwards")
                    }
                }
                .disabled(isInvestigating || isCleaningUp)
                
                if let result = investigationResult, !result.invalidAwards.isEmpty {
                    Button(role: .destructive) {
                        showCleanupConfirmation = true
                    } label: {
                        HStack {
                            if isCleaningUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Remove Invalid Awards (\(result.invalidAwards.count))")
                        }
                    }
                    .disabled(isInvestigating || isCleaningUp)
                }
            } header: {
                Text("Actions")
            } footer: {
                if let result = investigationResult {
                    if result.invalidAwards.isEmpty {
                        Text("All awards are valid! ✅")
                    } else {
                        Text("Found \(result.invalidAwards.count) invalid awards. Click 'Remove Invalid Awards' to clean them up and recalculate XP.")
                    }
                } else {
                    Text("Run investigation to check DailyAward integrity")
                }
            }
            
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What this does:")
                        .font(.headline)
                    
                    Text("• Validates that each DailyAward matches actual completion data")
                    Text("• Checks that ALL scheduled habits were completed on each award date")
                    Text("• Identifies awards created incorrectly (e.g., from Firestore sync)")
                    Text("• Allows cleanup of invalid awards to fix XP discrepancies")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Daily Award Integrity")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Remove Invalid Awards?",
            isPresented: $showCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Invalid Awards", role: .destructive) {
                runCleanup()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let result = investigationResult {
                Text("This will remove \(result.invalidAwards.count) invalid awards (\(result.invalidXP) XP) and recalculate your total XP. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func runInvestigation() {
        isInvestigating = true
        
        Task { @MainActor in
            do {
                let userId = await CurrentUser().idOrGuest
                let result = try await DailyAwardIntegrityService.shared.investigateDailyAwards(userId: userId)
                
                investigationResult = result
                DailyAwardIntegrityService.shared.printInvestigationReport(result)
                
                isInvestigating = false
                
                if result.invalidAwards.isEmpty {
                    showAlert(title: "Investigation Complete", message: "All awards are valid! ✅")
                } else {
                    showAlert(
                        title: "Investigation Complete",
                        message: "Found \(result.invalidAwards.count) invalid awards. See details below."
                    )
                }
            } catch {
                isInvestigating = false
                showAlert(title: "Investigation Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func runCleanup() {
        guard let result = investigationResult, !result.invalidAwards.isEmpty else {
            return
        }
        
        isCleaningUp = true
        
        Task { @MainActor in
            do {
                let userId = await CurrentUser().idOrGuest
                let removedCount = try await DailyAwardIntegrityService.shared.cleanupInvalidAwards(userId: userId)
                
                isCleaningUp = false
                
                // Re-run investigation to get updated results
                let updatedResult = try await DailyAwardIntegrityService.shared.investigateDailyAwards(userId: userId)
                investigationResult = updatedResult
                
                showAlert(
                    title: "Cleanup Complete",
                    message: "Removed \(removedCount) invalid awards. XP has been recalculated."
                )
            } catch {
                isCleaningUp = false
                showAlert(title: "Cleanup Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
#endif

