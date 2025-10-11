import SwiftUI

// MARK: - MigrationDeveloperSettingsView

// Developer interface for managing migration telemetry and kill switch

struct MigrationDeveloperSettingsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        // Status Section
        Section("Migration Status") {
          HStack {
            Image(systemName: telemetryManager.isMigrationEnabled
              ? "checkmark.circle.fill"
              : "xmark.circle.fill")
              .foregroundColor(telemetryManager.isMigrationEnabled ? .green : .red)

            Text("Migration Enabled")
              .font(.headline)

            Spacer()

            Text(telemetryManager.isMigrationEnabled ? "Yes" : "No")
              .foregroundColor(.secondary)
          }

          if let lastUpdate = telemetryManager.lastConfigUpdate {
            HStack {
              Text("Last Config Update")
              Spacer()
              Text(lastUpdate, style: .relative)
                .foregroundColor(.secondary)
            }
          }
        }

        // Remote Config Section
        Section("Remote Configuration") {
          HStack {
            Image(systemName: telemetryManager.remoteConfigLoaded
              ? "checkmark.circle.fill"
              : "exclamationmark.triangle.fill")
              .foregroundColor(telemetryManager.remoteConfigLoaded ? .green : .orange)

            Text("Config Loaded")

            Spacer()

            Text(telemetryManager.remoteConfigLoaded ? "Yes" : "No")
              .foregroundColor(.secondary)
          }

          Button("Refresh Config") {
            Task {
              await telemetryManager.fetchRemoteConfig()
            }
          }
          .foregroundColor(.blue)
        }

        // Telemetry Section
        Section("Telemetry Data") {
          HStack {
            Text("Failure Rate")
            Spacer()
            Text(String(format: "%.1f%%", telemetryManager.developerSettings.failureRate * 100))
              .foregroundColor(telemetryManager.developerSettings
                .failureRate > 0.15 ? .red : .green)
          }

          HStack {
            Text("Event Count")
            Spacer()
            Text("\(telemetryManager.developerSettings.eventCount)")
              .foregroundColor(.secondary)
          }

          Button("View Config Details") {
            showingConfigDetails = true
          }
          .foregroundColor(.blue)

          Button("Clear Telemetry Data") {
            showingClearConfirmation = true
          }
          .foregroundColor(.red)

          Button("Emergency Kill Switch") {
            telemetryManager.developerSettings.setMigrationOverride(false)
          }
          .foregroundColor(.red)

          Button("Emergency Enable") {
            telemetryManager.developerSettings.setMigrationOverride(true)
          }
          .foregroundColor(.green)
        }

        // Local Override Section
        Section("Local Override") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Override remote settings locally")
              .font(.caption)
              .foregroundColor(.secondary)

            HStack {
              Button("Enable Migrations") {
                telemetryManager.setLocalOverride(true)
              }
              .buttonStyle(.bordered)
              .foregroundColor(.green)

              Button("Disable Migrations") {
                telemetryManager.setLocalOverride(false)
              }
              .buttonStyle(.bordered)
              .foregroundColor(.red)

              Button("Use Remote") {
                telemetryManager.setLocalOverride(nil)
              }
              .buttonStyle(.bordered)
              .foregroundColor(.blue)
            }
          }
        }

        // Emergency Recovery Section
        Section("Emergency Recovery") {
          HStack {
            Text("Current Habits")
            Spacer()
            Text("\(habitRepository.habits.count)")
              .foregroundColor(.secondary)
          }

          Button("🚨 Recover Lost Habits") {
            showingRecoveryConfirmation = true
          }
          .foregroundColor(.red)

          Button("Debug Habits State") {
            habitRepository.debugHabitsState()
          }
          .foregroundColor(.blue)
        }

        // Test Section
        Section("Testing") {
          Button("Test Migration Start") {
            Task {
              await telemetryManager.recordEvent(.migrationStart, success: true)
            }
          }
          .foregroundColor(.blue)

          Button("Test Migration Failure") {
            Task {
              await telemetryManager.recordEvent(
                .migrationEndFailure,
                duration: 2.5,
                errorCode: "test_error",
                datasetSize: 100,
                success: false)
            }
          }
          .foregroundColor(.red)

          Button("Test Kill Switch Trigger") {
            Task {
              await telemetryManager.recordEvent(
                .killSwitchTriggered,
                errorCode: "manual_test",
                success: false)
            }
          }
          .foregroundColor(.orange)
        }
      }
      .navigationTitle("Migration Settings")
      .navigationBarTitleDisplayMode(.inline)
      .alert("Clear Telemetry Data", isPresented: $showingClearConfirmation) {
        Button("Cancel", role: .cancel) { }
        Button("Clear", role: .destructive) {
          telemetryManager.developerSettings.clearTelemetry()
        }
      } message: {
        Text("This will permanently delete all telemetry data. This action cannot be undone.")
      }
      .alert("Recover Lost Habits", isPresented: $showingRecoveryConfirmation) {
        Button("Cancel", role: .cancel) { }
        Button("Recover", role: .destructive) {
          Task {
            await habitRepository.emergencyRecoverHabits()
          }
        }
      } message: {
        Text(
          "This will attempt to recover your lost habits by forcing a reload from storage. This may help if habits disappeared after the recent update.")
      }
      .sheet(isPresented: $showingConfigDetails) {
        ConfigDetailsView()
      }
    }
  }

  // MARK: Private

  @StateObject private var telemetryManager = EnhancedMigrationTelemetryManager.shared
  @StateObject private var habitRepository = HabitRepository.shared
  @State private var showingClearConfirmation = false
  @State private var showingConfigDetails = false
  @State private var showingRecoveryConfirmation = false
}

// MARK: - ConfigDetailsView

struct ConfigDetailsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      List {
        Section("Remote Configuration") {
          HStack {
            Text("Migration Enabled")
            Spacer()
            Text(telemetryManager.isMigrationEnabled ? "Yes" : "No")
              .foregroundColor(telemetryManager.isMigrationEnabled ? .green : .red)
          }

          HStack {
            Text("Config Loaded")
            Spacer()
            Text(telemetryManager.remoteConfigLoaded ? "Yes" : "No")
              .foregroundColor(telemetryManager.remoteConfigLoaded ? .green : .orange)
          }

          if let lastUpdate = telemetryManager.lastConfigUpdate {
            HStack {
              Text("Last Update")
              Spacer()
              Text(lastUpdate, style: .date)
                .foregroundColor(.secondary)
            }

            HStack {
              Text("Age")
              Spacer()
              Text(lastUpdate, style: .relative)
                .foregroundColor(.secondary)
            }
          }
        }

        Section("Failure Rate Analysis") {
          let failureRate = telemetryManager.developerSettings.failureRate

          HStack {
            Text("Current Rate")
            Spacer()
            Text(String(format: "%.1f%%", failureRate * 100))
              .foregroundColor(failureRate > 0.15 ? .red : .green)
          }

          HStack {
            Text("Threshold")
            Spacer()
            Text("15.0%")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Status")
            Spacer()
            Text(failureRate > 0.15 ? "⚠️ High" : "✅ Normal")
              .foregroundColor(failureRate > 0.15 ? .red : .green)
          }
        }

        Section("Device Information") {
          let deviceInfo = EnhancedMigrationTelemetryManager.TelemetryEvent.DeviceInfo()

          HStack {
            Text("App Version")
            Spacer()
            Text(deviceInfo.appVersion)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("iOS Version")
            Spacer()
            Text(deviceInfo.iosVersion)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Device Model")
            Spacer()
            Text(deviceInfo.deviceModel)
              .foregroundColor(.secondary)
          }

          if let freeSpace = deviceInfo.freeDiskSpace {
            HStack {
              Text("Free Disk Space")
              Spacer()
              Text(formatBytes(freeSpace))
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .navigationTitle("Config Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            // Dismiss sheet
          }
        }
      }
    }
  }

  // MARK: Private

  @StateObject private var telemetryManager = EnhancedMigrationTelemetryManager.shared

  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }
}

// MARK: - MigrationDeveloperSettingsView_Previews

struct MigrationDeveloperSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    MigrationDeveloperSettingsView()
  }
}
