import SwiftUI

// MARK: - BackupSettingsView

struct BackupSettingsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        // Backup Status Section
        Section("more.backup.statusSection".localized) {
          HStack {
            Image(systemName: backupManager.lastBackupDate != nil
              ? "checkmark.circle.fill"
              : "exclamationmark.triangle.fill")
              .foregroundColor(backupManager.lastBackupDate != nil ? .green : .orange)

            VStack(alignment: .leading) {
              Text("more.backup.lastBackup".localized)
                .font(.headline)

              if let lastBackup = backupManager.lastBackupDate {
                Text(lastBackup, style: .relative)
                  .font(.caption)
                  .foregroundColor(.secondary)
              } else {
                Text("more.backup.never".localized)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            Text(String(format: "more.backup.backupsCount".localized, backupManager.backupCount))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        // Backup Actions Section
        Section("more.backup.actionsSection".localized) {
          Button(action: {
            showingCreateBackup = true
          }) {
            HStack {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(.blue)
              Text("more.backup.createBackup".localized)
            }
          }
          .disabled(backupManager.isBackingUp)

          if backupManager.isBackingUp {
            HStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("more.backup.creatingBackup".localized)
                .foregroundColor(.secondary)
            }
          }
        }

        // Available Backups Section
        if !backupManager.availableBackups.isEmpty {
          Section("more.backup.availableBackupsSection".localized) {
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
                })
            }
          }
        }

        // Data Repair Section
        Section("more.backup.dataRepairSection".localized) {
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
              Text("more.backup.repairData".localized)
            }
          }
          .disabled(repairUtility.isRepairing)

          if repairUtility.isRepairing {
            HStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("more.backup.repairingData".localized)
                .foregroundColor(.secondary)
            }
          }
        }

        // Backup Settings Section
        Section("more.backup.settingsSection".localized) {
          HStack {
            Image(systemName: "clock.fill")
              .foregroundColor(.blue)
            Text("more.backup.automaticBackups".localized)
            Spacer()
            Text("more.backup.every24Hours".localized)
              .foregroundColor(.secondary)
          }

          HStack {
            Image(systemName: "number.circle.fill")
              .foregroundColor(.blue)
            Text("more.backup.keepBackups".localized)
            Spacer()
            Text("more.backup.keep10Backups".localized)
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("more.backup.title".localized)
      .navigationBarTitleDisplayMode(.large)
    }
    .alert("more.backup.restoreBackup".localized, isPresented: $showingRestoreAlert) {
      Button("common.cancel".localized, role: .cancel) { }
      Button("more.backup.restore".localized, role: .destructive) {
        if let backup = selectedBackup {
          Task {
            try? await backupManager.restore(from: backup)
          }
        }
      }
    } message: {
      if let backup = selectedBackup {
        Text(
          String(format: "more.backup.restoreConfirm".localized, backup.formattedDate))
      }
    }
    .sheet(isPresented: $showingRepairResults) {
      if let summary = repairSummary {
        RepairResultsView(summary: summary)
      }
    }
  }

  // MARK: Private

  @StateObject private var backupManager = BackupManager.shared
  @StateObject private var repairUtility = DataRepairUtility.shared
  @State private var showingCreateBackup = false
  @State private var showingRestoreAlert = false
  @State private var selectedBackup: BackupSnapshot?
  @State private var showingRepairResults = false
  @State private var repairSummary: RepairSummary?
}

// MARK: - RepairResultsView

struct RepairResultsView: View {
  // MARK: Internal

  let summary: RepairSummary

  var body: some View {
    NavigationView {
      List {
        Section("more.backup.repairSummary".localized) {
          HStack {
            Text("more.backup.issuesFound".localized)
            Spacer()
            Text("\(summary.totalIssuesFound)")
              .foregroundColor(.red)
          }

          HStack {
            Text("more.backup.issuesFixed".localized)
            Spacer()
            Text("\(summary.totalIssuesFixed)")
              .foregroundColor(.green)
          }
        }

        Section("more.backup.repairDetails".localized) {
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
                  Text(String(format: "more.backup.foundCount".localized, result.issuesFound))
                    .font(.caption)
                    .foregroundColor(.red)
                }

                if result.issuesFixed > 0 {
                  Text(String(format: "more.backup.fixedCount".localized, result.issuesFixed))
                    .font(.caption)
                    .foregroundColor(.green)
                }
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
      .navigationTitle("more.backup.repairResults".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("common.done".localized) {
            dismiss()
          }
        }
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
}

// MARK: - Preview

#Preview {
  BackupSettingsView()
}
