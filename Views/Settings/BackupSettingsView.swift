import SwiftUI

// MARK: - Backup Settings View
struct BackupSettingsView: View {
    @StateObject private var backupManager = BackupManager.shared
    @StateObject private var repairUtility = DataRepairUtility.shared
    @State private var showingCreateBackup = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackup: BackupSnapshot?
    @State private var showingRepairResults = false
    @State private var repairSummary: RepairSummary?
    
    var body: some View {
        NavigationView {
            List {
                // Backup Status Section
                Section("Backup Status") {
                    HStack {
                        Image(systemName: backupManager.lastBackupDate != nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(backupManager.lastBackupDate != nil ? .green : .orange)
                        
                        VStack(alignment: .leading) {
                            Text("Last Backup")
                                .font(.headline)
                            
                            if let lastBackup = backupManager.lastBackupDate {
                                Text(lastBackup, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(backupManager.backupCount) backups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Backup Actions Section
                Section("Backup Actions") {
                    Button(action: {
                        showingCreateBackup = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Create Backup")
                        }
                    }
                    .disabled(backupManager.isBackingUp)
                    
                    if backupManager.isBackingUp {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Creating backup...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Available Backups Section
                if !backupManager.availableBackups.isEmpty {
                    Section("Available Backups") {
                        ForEach(backupManager.availableBackups) { backup in
                            BackupRowView(
                                backup: backup,
                                onRestore: {
                                    selectedBackup = backup
                                    showingRestoreAlert = true
                                },
                                onDelete: {
                                    Task {
                                        try? await backupManager.deleteBackup(backup)
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Data Repair Section
                Section("Data Repair") {
                    Button(action: {
                        Task {
                            do {
                                let summary = try await repairUtility.performDataRepair()
                                repairSummary = summary
                                showingRepairResults = true
                            } catch {
                                // Handle error
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                            Text("Repair Data")
                        }
                    }
                    .disabled(repairUtility.isRepairing)
                    
                    if repairUtility.isRepairing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Repairing data...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Backup Settings Section
                Section("Backup Settings") {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Automatic Backups")
                        Spacer()
                        Text("Every 24 hours")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.blue)
                        Text("Keep Backups")
                        Spacer()
                        Text("10 backups")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Backup & Recovery")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Restore Backup", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                if let backup = selectedBackup {
                    Task {
                        try? await backupManager.restore(from: backup)
                    }
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("Are you sure you want to restore from backup created on \(backup.formattedDate)? This will replace your current data.")
            }
        }
        .sheet(isPresented: $showingRepairResults) {
            if let summary = repairSummary {
                RepairResultsView(summary: summary)
            }
        }
    }
}


// MARK: - Repair Results View
struct RepairResultsView: View {
    let summary: RepairSummary
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Repair Summary") {
                    HStack {
                        Text("Issues Found")
                        Spacer()
                        Text("\(summary.totalIssuesFound)")
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Issues Fixed")
                        Spacer()
                        Text("\(summary.totalIssuesFixed)")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Repair Details") {
                    ForEach(summary.repairResults.indices, id: \.self) { index in
                        let result = summary.repairResults[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.operation)
                                .font(.headline)
                            
                            Text(result.details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if result.issuesFound > 0 {
                                    Text("Found: \(result.issuesFound)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                if result.issuesFixed > 0 {
                                    Text("Fixed: \(result.issuesFixed)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Repair Results")
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

// MARK: - Preview
#Preview {
    BackupSettingsView()
}
