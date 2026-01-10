import SwiftUI

// MARK: - BackupListView

struct BackupListView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        HStack {
          Button("Cancel") {
            dismiss()
          }
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.navy200)

          Spacer()

          Text("Available Backups")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.text01)

          Spacer()

          Button("Done") {
            dismiss()
          }
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.green500)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.surface)

        // Backup List
        if backupManager.availableBackups.isEmpty {
          VStack(spacing: 16) {
            Image("Icon-Archive_Filled")
              .renderingMode(.template)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 48, height: 48)
              .foregroundColor(.text03)

            Text("No Backups Available")
              .font(.system(size: 18, weight: .medium))
              .foregroundColor(.text02)

            Text("Create your first backup to see it listed here")
              .font(.system(size: 14, weight: .regular))
              .foregroundColor(.text03)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.surface2)
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(backupManager.availableBackups) { backup in
                BackupRowView(
                  backup: backup,
                  onRestore: {
                    selectedBackup = backup
                    showingRestoreAlert = true
                  },
                  onDelete: {
                    Task {
                      try await backupManager.deleteBackup(backup)
                    }
                  })
              }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
          }
          .background(Color.surface2)
        }
      }
      .background(Color.surface2)
    }
    .alert("Restore Backup", isPresented: $showingRestoreAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Restore", role: .destructive) {
        if let backup = selectedBackup {
          Task {
            await restoreFromBackup(backup)
          }
        }
      }
    } message: {
      if let backup = selectedBackup {
        Text(
          "Are you sure you want to restore from backup created on \(backup.formattedDate)? This will replace your current data.")
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @StateObject private var backupManager = BackupManager.shared
  @State private var showingRestoreAlert = false
  @State private var selectedBackup: BackupSnapshot?
  @State private var isRestoring = false

  private func restoreFromBackup(_ backup: BackupSnapshot) async {
    isRestoring = true

    do {
      let backupURL = backupManager.backupDirectory.appendingPathComponent(backup.id.uuidString)
      let data = try Data(contentsOf: backupURL)
      _ = try await backupManager.restoreFromData(data)

      await MainActor.run {
        // Show success message
        dismiss()
      }
    } catch {
      await MainActor.run {
        // Handle error - could show an alert here
        print("Restore failed: \(error.localizedDescription)")
      }
    }

    await MainActor.run {
      isRestoring = false
    }
  }
}

// MARK: - BackupRowView

struct BackupRowView: View {
  // MARK: Internal

  let backup: BackupSnapshot
  let onRestore: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      // Backup Icon
      Image("Icon-Archive_Filled")
        .renderingMode(.template)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 24, height: 24)
        .foregroundColor(.navy200)

      // Backup Info
      VStack(alignment: .leading, spacing: 6) {
        Text(backup.formattedDate)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.text01)
          .lineLimit(1)

        HStack(spacing: 6) {
          Text("\(backup.habitCount) habits")
            .font(.appLabelMedium)
            .foregroundColor(Color("apponBadgeBackground"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color("appBadgeBackground")))
            .fixedSize()

          Text(backup.formattedSize)
            .font(.appLabelMedium)
            .foregroundColor(Color("apponBadgeBackground"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color("appBadgeBackground")))
            .fixedSize()

          Text("v\(backup.appVersion)")
            .font(.appLabelMedium)
            .foregroundColor(Color("apponBadgeBackground"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color("appBadgeBackground")))
            .fixedSize()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Action Buttons
      HStack(spacing: 8) {
        Button(action: onRestore) {
          Text("Restore")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.green500)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green500.opacity(0.1))
            .cornerRadius(8)
        }
        .fixedSize(horizontal: true, vertical: false)

        Button(action: {
          showingDeleteAlert = true
        }) {
          Image("Icon-TrashBin2_Filled")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(.red500)
            .padding(8)
            .background(Color.red500.opacity(0.1))
            .cornerRadius(8)
        }
        .fixedSize()
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.surface)
    .cornerRadius(12)
    .alert("Delete Backup", isPresented: $showingDeleteAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete", role: .destructive) {
        onDelete()
      }
    } message: {
      Text("Are you sure you want to delete this backup? This action cannot be undone.")
    }
  }

  // MARK: Private

  @State private var showingDeleteAlert = false
}

#Preview {
  BackupListView()
}
