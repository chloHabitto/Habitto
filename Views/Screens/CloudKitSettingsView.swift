import SwiftUI

// MARK: - CloudKitSettingsView

/// Settings view for managing CloudKit synchronization
struct CloudKitSettingsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        // iCloud Status Banner
        if !isiCloudAvailable {
          Section {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text("iCloud Not Available")
                  .font(.headline)
              }
              
              Text("Your habits are saved locally on this device only. To backup your data to iCloud:")
                .font(.subheadline)
                .foregroundColor(.secondary)
              
              VStack(alignment: .leading, spacing: 6) {
                Text("1. Open Settings app")
                Text("2. Tap your name at the top")
                Text("3. Tap iCloud")
                Text("4. Enable iCloud Drive")
              }
              .font(.caption)
              .foregroundColor(.secondary)
              .padding(.leading, 8)
              
              Button(action: {
                if let url = URL(string: "App-prefs:CASTLE") {
                  UIApplication.shared.open(url)
                }
              }) {
                HStack {
                  Text("Open Settings")
                  Image(systemName: "arrow.up.forward.app")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .tint(.blue)
            }
            .padding(.vertical, 8)
          }
        } else if isGuestMode {
          Section {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "info.circle.fill")
                  .foregroundColor(.blue)
                Text("Guest Mode")
                  .font(.headline)
              }
              
              Text("You're using Habitto as a guest. Your habits are saved locally on this device only.")
                .font(.subheadline)
                .foregroundColor(.secondary)
              
              Text("Create an account to backup your habits to iCloud and sync across devices.")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
          }
        }
        
        // CloudKit Status Section
        Section {
          Text("CloudKit Status")
            .font(.headline)
            .padding(.bottom, 8)
          HStack {
            Image(systemName: isiCloudAvailable
              ? "checkmark.circle.fill"
              : "xmark.circle.fill")
              .foregroundColor(isiCloudAvailable ? .green : .orange)

            VStack(alignment: .leading) {
              Text("iCloud Drive")
                .font(.headline)
              Text(isiCloudAvailable ? "Available" : "Not Available")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if cloudKitIntegration.isSyncing {
              ProgressView()
                .scaleEffect(0.8)
            }
          }
          .padding(.vertical, 4)

          HStack {
            Image(systemName: cloudKitIntegration.isEnabled ? "icloud.fill" : "icloud.slash")
              .foregroundColor(cloudKitIntegration.isEnabled ? .blue : .gray)

            VStack(alignment: .leading) {
              Text("CloudKit Sync")
                .font(.headline)
              Text(cloudKitIntegration.isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $cloudKitIntegration.isEnabled)
          }
          .padding(.vertical, 4)
        }

        // Sync Controls Section
        Section {
          Text("Sync Controls")
            .font(.headline)
            .padding(.bottom, 8)
          Button(action: {
            Task {
              await cloudKitIntegration.forceSync()
            }
          }) {
            HStack {
              Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
              Text("Force Sync")
                .foregroundColor(.primary)
              Spacer()
              if cloudKitIntegration.isSyncing {
                ProgressView()
                  .scaleEffect(0.8)
              }
            }
          }
          .disabled(cloudKitIntegration.isSyncing || !cloudKitIntegration.isEnabled)

          Button(action: {
            showingSyncDetails = true
          }) {
            HStack {
              Image(systemName: "info.circle")
                .foregroundColor(.blue)
              Text("Sync Details")
                .foregroundColor(.primary)
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .disabled(!cloudKitIntegration.isEnabled)
        }

        // Statistics Section - temporarily removed for debugging

        // Advanced Settings Section
        Section(header: Text("Advanced Settings")) {
          Button(action: {
            showingConflictResolution = true
          }) {
            HStack {
              Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
              Text("Resolve Conflicts")
                .foregroundColor(.primary)
              Spacer()
              if cloudKitIntegration.conflictCount > 0 {
                Text("\(cloudKitIntegration.conflictCount)")
                  .foregroundColor(.orange)
                  .font(.caption)
              }
              Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .disabled(cloudKitIntegration.conflictCount == 0)

          Button(action: {
            Task {
              await cloudKitIntegration.migrateLocalDataToCloudKit()
            }
          }) {
            HStack {
              Image(systemName: "arrow.up.circle")
                .foregroundColor(.blue)
              Text("Migrate Local Data")
                .foregroundColor(.primary)
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .disabled(!cloudKitIntegration.isEnabled)
        }
      }
      .navigationTitle("CloudKit Sync")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            // Dismiss view
          }
        }
      }
    }
    .sheet(isPresented: $showingSyncDetails) {
      CloudKitSyncDetailsView()
    }
    .sheet(isPresented: $showingConflictResolution) {
      CloudKitConflictResolutionView()
    }
  }

  // MARK: Private

  @StateObject private var cloudKitIntegration = CloudKitIntegrationService.shared
  @StateObject private var cloudKitManager = CloudKitManager.shared
  @StateObject private var conflictResolver = CloudKitConflictResolver()
  @State private var showingSyncDetails = false
  @State private var showingConflictResolution = false
  
  // Check iCloud and auth status
  private var isiCloudAvailable: Bool {
    FileManager.default.ubiquityIdentityToken != nil
  }
  
  private var isGuestMode: Bool {
    AuthenticationManager.shared.currentUser == nil
  }
}

// MARK: - CloudKitSyncDetailsView

struct CloudKitSyncDetailsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        Section("Sync Information") {
          HStack {
            Text("CloudKit Available")
            Spacer()
            Text(CloudKitManager.shared.isCloudKitAvailable() ? "Yes" : "No")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("User Signed In")
            Spacer()
            Text(CloudKitManager.shared.isSignedIn ? "Yes" : "No")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Sync Enabled")
            Spacer()
            Text(cloudKitIntegration.isEnabled ? "Yes" : "No")
              .foregroundColor(.secondary)
          }
        }

        Section("Last Sync") {
          if let lastSync = cloudKitIntegration.lastSyncDate {
            HStack {
              Text("Date")
              Spacer()
              Text(lastSync, style: .date)
                .foregroundColor(.secondary)
            }

            HStack {
              Text("Time")
              Spacer()
              Text(lastSync, style: .time)
                .foregroundColor(.secondary)
            }
          } else {
            Text("No sync performed yet")
              .foregroundColor(.secondary)
          }
        }

        if let errorMessage = cloudKitIntegration.errorMessage {
          Section("Error") {
            Text(errorMessage)
              .foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Sync Details")
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

  // MARK: Private

  @StateObject private var cloudKitIntegration = CloudKitIntegrationService.shared
  @Environment(\.dismiss) private var dismiss
}

// MARK: - CloudKitConflictResolutionView

struct CloudKitConflictResolutionView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        Section("Pending Conflicts") {
          ForEach(conflictResolver.pendingConflicts) { conflict in
            ConflictRowView(conflict: conflict)
          }
        }

        if conflictResolver.pendingConflicts.isEmpty {
          Section {
            Text("No conflicts detected")
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Conflict Resolution")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Auto Resolve") {
            Task {
              await conflictResolver.autoResolveConflicts()
            }
          }
          .disabled(conflictResolver.pendingConflicts.isEmpty)
        }
      }
    }
  }

  // MARK: Private

  @StateObject private var conflictResolver = CloudKitConflictResolver.shared
  @Environment(\.dismiss) private var dismiss
}

// MARK: - ConflictRowView

struct ConflictRowView: View {
  // MARK: Internal

  let conflict: ConflictRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(conflict.recordType.rawValue)
        .font(.headline)

      Text("Conflict Type: \(conflict.conflictType.rawValue)")
        .font(.caption)
        .foregroundColor(.secondary)

      Text("Detected: \(conflict.detectedAt, style: .relative) ago")
        .font(.caption)
        .foregroundColor(.secondary)

      Picker("Resolution", selection: $selectedResolution) {
        Text("Use Local").tag(ConflictResolution.useLocal)
        Text("Use Remote").tag(ConflictResolution.useRemote)
        Text("Merge").tag(ConflictResolution.merge)
        Text("Recalculate").tag(ConflictResolution.recalculate)
      }
      .pickerStyle(.segmented)

      Button("Resolve") {
        Task {
          await CloudKitConflictResolver().resolveConflict(conflict, using: selectedResolution)
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.vertical, 4)
  }

  // MARK: Private

  @State private var selectedResolution: ConflictResolution = .useLocal
}

// MARK: - Preview

#Preview {
  CloudKitSettingsView()
}
