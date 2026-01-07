import Foundation
import SwiftUI
import FirebaseAuth

struct BackupRecoveryView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var backupManager = BackupManager.shared
  @StateObject private var backupScheduler = BackupScheduler.shared
  @StateObject private var backupCoordinator = BackupStorageCoordinator.shared
  @StateObject private var notificationService = BackupNotificationService.shared
  @StateObject private var settingsManager = BackupSettingsManager.shared
  @ObservedObject var habitRepository = HabitRepository.shared

  @State private var isAutomaticBackupEnabled = true
  @State private var backupFrequency = "Daily"
  @State private var wifiOnlyBackup = true
  @State private var isBackingUp = false
  @State private var showingBackupList = false
  @State private var firestoreSyncStatus: FirestoreSyncStatus = .checking

  let backupFrequencies = ["Daily", "Weekly", "Monthly", "Manual Only"]
  @State private var showingTestingView = false
  
  enum FirestoreSyncStatus {
    case checking
    case active
    case inactive
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ZStack(alignment: .bottom) {
          ScrollView {
            VStack(spacing: 24) {
              // Description text
              Text("Your data automatically syncs to Firestore. Enable iCloud backup for additional protection.")
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
              
              // Firestore Sync Status Banner
              firestoreSyncBanner

              // iCloud Backup Settings
              VStack(alignment: .leading, spacing: 12) {
                Text("iCloud Backup")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundColor(.text01)
                  .padding(.top, 8)
                
                VStack(spacing: 16) {
                  // iCloud Backup Toggle
                  HStack {
                    Image(systemName: "icloud.fill")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.appIconColor)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("iCloud Backup")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                      Text("Create backup snapshots in iCloud Drive")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.text03)
                    }

                  Spacer()

                  Toggle("", isOn: $isAutomaticBackupEnabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(firestoreSyncStatus != .active)
                    .onChange(of: isAutomaticBackupEnabled) {
                      Task {
                        await saveBackupSettings()
                      }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color("appSurface02Variant"))
                .cornerRadius(24)

                // Backup Frequency (shown when automatic backup is enabled)
                if isAutomaticBackupEnabled {
                  HStack {
                    Image("Icon-Calendar_Filled")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.appIconColor)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("Backup Frequency")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                      Text("How often to create iCloud backup snapshots")
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
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                }

                // WiFi Only Toggle (shown when automatic backup is enabled)
                if isAutomaticBackupEnabled {
                  HStack {
                    Image(systemName: "wifi")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.appIconColor)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("WiFi Only")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                      Text("Only create iCloud backups when connected to WiFi")
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
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                }
              }
              }

              // iCloud Backup Status Section
              VStack(alignment: .leading, spacing: 12) {
                Text("iCloud Backup History")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundColor(.text01)
                  .padding(.top, 8)
                
                VStack(spacing: 16) {
                  HStack {
                    Image(systemName: "clock.fill")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 24, height: 24)
                      .foregroundColor(.appIconColor)

                    VStack(alignment: .leading, spacing: 2) {
                      Text("Last iCloud Backup")
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
                    .foregroundColor(.appIconColor)
                  }
                  .padding(.horizontal, 20)
                  .padding(.vertical, 16)
                  .background(Color("appSurface02Variant"))
                  .cornerRadius(24)
                }
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 140) // Extra bottom padding for fixed button
          }
          .background(Color("appSurface01Variant02"))

          // Fixed Backup Now Button at bottom
          VStack(spacing: 0) {
            // Gradient overlay to fade content behind button
            LinearGradient(
              gradient: Gradient(colors: [Color("appSurface01Variant02").opacity(0), Color("appSurface01Variant02")]),
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
                      .progressViewStyle(CircularProgressViewStyle(tint: .appOnPrimary))
                      .scaleEffect(0.8)
                  } else {
                    Image("Icon-RefreshSquare2_Filled")
                      .renderingMode(.template)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .frame(width: 20, height: 20)
                      .foregroundColor(.appOnPrimary)
                  }

                  Text(isBackingUp ? "Creating iCloud Backup..." : "Create iCloud Backup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appOnPrimary)
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
            .background(Color("appSurface01Variant02"))
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
        checkFirestoreSyncStatus()
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
  
  // MARK: - Firestore Sync Status
  
  @MainActor
  private var firestoreSyncBanner: some View {
    Group {
      switch firestoreSyncStatus {
      case .checking:
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Checking Firestore sync status...")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text03)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .cornerRadius(24)
        
      case .active:
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          VStack(alignment: .leading, spacing: 2) {
            Text("Firestore Sync Active")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
            Text("Your data is automatically syncing to the cloud. iCloud backup is optional.")
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text03)
          }
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .cornerRadius(24)
        
      case .inactive:
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          VStack(alignment: .leading, spacing: 2) {
            Text("Firestore Sync Not Active")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
            Text("Please ensure you're signed in. Firestore sync must be active before enabling iCloud backup.")
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text03)
          }
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .cornerRadius(24)
      }
    }
  }
  
  @MainActor
  private func checkFirestoreSyncStatus() {
    // Check if user is authenticated
    guard Auth.auth().currentUser != nil else {
      firestoreSyncStatus = .inactive
      return
    }
    
    // Check if sync is running (periodicSyncUserId is set)
    Task {
      let syncEngine = SyncEngine.shared
      let hasActiveSync = await syncEngine.hasActiveSync()
      
      await MainActor.run {
        if hasActiveSync {
          firestoreSyncStatus = .active
        } else {
          // If user is authenticated but sync isn't running, it might be starting
          // Wait a moment and check again
          Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            let syncEngine = SyncEngine.shared
            let hasActiveSync = await syncEngine.hasActiveSync()
            await MainActor.run {
              firestoreSyncStatus = hasActiveSync ? .active : .inactive
            }
          }
        }
      }
    }
  }
}

#Preview {
  BackupRecoveryView()
}
