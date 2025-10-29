import Foundation
import SwiftUI

struct BackupRecoveryView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var backupManager = BackupManager.shared
  @StateObject private var backupScheduler = BackupScheduler.shared
  @StateObject private var backupCoordinator = BackupStorageCoordinator.shared
  @StateObject private var notificationService = BackupNotificationService.shared
  @StateObject private var settingsManager = BackupSettingsManager.shared

  @State private var isAutomaticBackupEnabled = false
  @State private var backupFrequency = "Daily"
  @State private var wifiOnlyBackup = true
  @State private var isBackingUp = false
  @State private var showingBackupList = false

  let backupFrequencies = ["Daily", "Weekly", "Monthly", "Manual Only"]
  @State private var showingTestingView = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ZStack(alignment: .bottom) {
          ScrollView {
            VStack(spacing: 24) {
              // Description text
              Text("Configure your backup settings and manage your data")
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

              // Backup Settings
              VStack(spacing: 16) {
                // Automatic Backup Toggle
                HStack {
                  Image("Icon-CloudDownload_Filled")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.navy200)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("Automatic Backup")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.text01)
                    Text("Automatically backup your data")
                      .font(.system(size: 14, weight: .regular))
                      .foregroundColor(.text03)
                  }

                  Spacer()

                  Toggle("", isOn: $isAutomaticBackupEnabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .onChange(of: isAutomaticBackupEnabled) {
                      Task {
                        await saveBackupSettings()
                      }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(16)

                // Backup Frequency (shown when automatic backup is enabled)
                if isAutomaticBackupEnabled {
                  HStack {
                    Image("Icon-Calendar_Filled")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.navy200)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("Backup Frequency")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                      Text("How often to backup your data")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text03)
                    }

                    Spacer()

                    Picker("Frequency", selection: $backupFrequency) {
                      ForEach(backupFrequencies, id: \.self) { frequency in
                        Text(frequency).tag(frequency)
                      }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: backupFrequency) {
                      Task {
                        await saveBackupSettings()
                      }
                    }
                  }
                  .padding(.horizontal, 20)
                  .padding(.vertical, 16)
                  .background(Color.surface)
                  .cornerRadius(16)
                }

                // WiFi Only Toggle (shown when automatic backup is enabled)
                if isAutomaticBackupEnabled {
                  HStack {
                    Image(systemName: "wifi")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.navy200)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("WiFi Only")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                      Text("Only backup when connected to WiFi")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text03)
                    }

                    Spacer()

                    Toggle("", isOn: $wifiOnlyBackup)
                      .fixedSize(horizontal: true, vertical: false)
                      .onChange(of: wifiOnlyBackup) {
                        Task {
                          await saveBackupSettings()
                        }
                      }
                  }
                  .padding(.horizontal, 20)
                  .padding(.vertical, 16)
                  .background(Color.surface)
                  .cornerRadius(16)
                }
              }

              // Backup Status Section
              VStack(spacing: 16) {
                HStack {
                  Image("Icon-Archive_Filled")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.navy200)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("Last Backup")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.text01)
                    Text(backupManager.lastBackupDate?.formatted() ?? "Never")
                      .font(.system(size: 14, weight: .regular))
                      .foregroundColor(.text03)
                  }

                  Spacer()

                  Button("View All") {
                    showingBackupList = true
                  }
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(.navy200)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.surface)
                .cornerRadius(16)
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140) // Extra bottom padding for fixed button
          }
          .background(Color.surface2)

          // Fixed Backup Now Button at bottom
          VStack(spacing: 0) {
            // Gradient overlay to fade content behind button
            LinearGradient(
              gradient: Gradient(colors: [Color.surface2.opacity(0), Color.surface2]),
              startPoint: .top,
              endPoint: .bottom)
              .frame(height: 20)

            // Button container
            HStack {
              Button(action: {
                Task {
                  await performBackup()
                }
              }) {
                HStack {
                  if isBackingUp {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .white))
                      .scaleEffect(0.8)
                  } else {
                    Image("Icon-RefreshSquare2_Filled")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 20, height: 20)
                      .foregroundColor(.white)
                  }

                  Text(isBackingUp ? "Backing Up..." : "Backup Now")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .clipShape(Capsule()) // Pill shape
              }
              .disabled(isBackingUp)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
          }
        }
      }
      .navigationTitle("Backup & Recovery")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
      .onAppear {
        loadBackupSettings()
      }
      .sheet(isPresented: $showingBackupList) {
        BackupListView()
      }
      .sheet(isPresented: $showingTestingView) {
        BackupTestingView()
      }
      .backupNotifications()
    }
  }

  @MainActor
  private func loadBackupSettings() {
    let config = BackupScheduler.loadScheduleConfig()
    isAutomaticBackupEnabled = config.isEnabled
    backupFrequency = config.frequency.displayName
    wifiOnlyBackup = config.networkCondition == NetworkCondition.wifiOnly
  }

  private func saveBackupSettings() async {
    let frequency: BackupFrequency = switch backupFrequency {
    case "Daily": .daily
    case "Weekly": .weekly
    case "Monthly": .monthly
    case "Manual Only": .manual
    default: .daily
    }

    backupScheduler.updateSchedule(
      isEnabled: isAutomaticBackupEnabled,
      frequency: frequency,
      networkCondition: wifiOnlyBackup ? NetworkCondition.wifiOnly : NetworkCondition.any)
  }

  private func performBackup() async {
    isBackingUp = true

    do {
      _ = try await backupCoordinator.performBackup()

      await MainActor.run {
        notificationService.showBackupSuccess(backupSize: "Unknown", habitCount: 0)
      }
    } catch {
      await MainActor.run {
        notificationService.showBackupFailure(error: error)
      }
    }

    await MainActor.run {
      isBackingUp = false
    }
  }
}

#Preview {
  BackupRecoveryView()
}
