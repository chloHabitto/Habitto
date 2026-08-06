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
  @State private var showBackupCreatedToast = false
  @State private var showBackupRestoredToast = false

  /// Internal frequency keys — must match BackupFrequency.displayName / saveBackupSettings switch cases.
  let backupFrequencies = ["Daily", "Weekly", "Monthly", "Manual Only"]
  @State private var showingTestingView = false

  private func backupFrequencyDisplayName(_ key: String) -> String {
    switch key {
    case "Daily": "more.backup.frequency.daily".localized
    case "Weekly": "more.backup.frequency.weekly".localized
    case "Monthly": "more.backup.frequency.monthly".localized
    case "Manual Only": "more.backup.frequency.manualOnly".localized
    default: key
    }
  }
  
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
              Text("more.backup.subtitle".localized)
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
              
              // Firestore Sync Status Banner
              firestoreSyncBanner

              // iCloud Backup Settings Section
              iCloudBackupSettingsSection

              // iCloud Backup History Section
              iCloudBackupHistorySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 0)
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

                  Text(isBackingUp ? "more.backup.creatingICloudBackup".localized : "more.backup.createICloudBackup".localized)
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
      .navigationTitle("more.backup.title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
      .onAppear {
        loadBackupSettings()
        checkFirestoreSyncStatus()
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowBackupRestoredToast"))) { _ in
        showBackupRestoredToast = true
      }
      .sheet(isPresented: $showingBackupList) {
        BackupListView()
      }
      .sheet(isPresented: $showingTestingView) {
        BackupTestingView()
      }
      .backupNotifications()
      .overlay(alignment: .bottom) {
        if showBackupCreatedToast {
          SuccessToastView(message: "more.backup.createdToast".localized) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              showBackupCreatedToast = false
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 140)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .overlay(alignment: .bottom) {
        if showBackupRestoredToast {
          SuccessToastView(message: "more.backup.restoredToast".localized) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
              showBackupRestoredToast = false
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 140)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showBackupCreatedToast)
      .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showBackupRestoredToast)
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
        showBackupCreatedToast = true
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
  
  // MARK: - iCloud Backup Settings Section
  
  private var iCloudBackupSettingsSection: some View {
    VStack(spacing: 0) {
      // Section Header
      HStack {
        Text("more.backup.iCloudBackup".localized)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text01)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 8)
      
      // iCloud Backup Toggle Row
      HStack(spacing: 12) {
        Image(systemName: "icloud.fill")
          .font(.system(size: 20))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("more.backup.iCloudBackup".localized)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          Text("more.backup.iCloudBackupDescription".localized)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text04)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        Toggle("", isOn: $isAutomaticBackupEnabled)
          .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
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
      
      // Backup Frequency Row (shown when automatic backup is enabled)
      if isAutomaticBackupEnabled {
        Divider()
          .padding(.leading, 56)
        
        HStack(spacing: 12) {
          Image("Icon-Calendar_Filled")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.appIconColor)
          
          VStack(alignment: .leading, spacing: 4) {
            Text("more.backup.backupFrequency".localized)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
            Text("more.backup.backupFrequencyDescription".localized)
              .font(.system(size: 14, weight: .regular))
              .foregroundColor(.text04)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          Picker("more.backup.frequency".localized, selection: $backupFrequency) {
            ForEach(backupFrequencies, id: \.self) { frequency in
              Text(backupFrequencyDisplayName(frequency)).tag(frequency)
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
      }
      
      // WiFi Only Toggle Row (shown when automatic backup is enabled)
      if isAutomaticBackupEnabled {
        Divider()
          .padding(.leading, 56)
        
        HStack(spacing: 12) {
          Image(systemName: "wifi")
            .font(.system(size: 20))
            .foregroundColor(.appIconColor)
            .frame(width: 24, height: 24)
          
          VStack(alignment: .leading, spacing: 4) {
            Text("more.backup.wifiOnly".localized)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.text01)
            Text("more.backup.wifiOnlyDescription".localized)
              .font(.system(size: 14, weight: .regular))
              .foregroundColor(.text04)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          Toggle("", isOn: $wifiOnlyBackup)
            .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
            .fixedSize(horizontal: true, vertical: false)
            .onChange(of: wifiOnlyBackup) {
              Task {
                await saveBackupSettings()
              }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
    }
    .background(Color("appSurface02Variant"))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }
  
  // MARK: - iCloud Backup History Section
  
  private var iCloudBackupHistorySection: some View {
    VStack(spacing: 0) {
      // Section Header
      HStack {
        Text("more.backup.iCloudBackupHistory".localized)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.text01)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 8)
      
      // Last Backup Row
      HStack(spacing: 12) {
        Image(systemName: "clock.fill")
          .font(.system(size: 20))
          .foregroundColor(.appIconColor)
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("more.backup.lastICloudBackup".localized)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text01)
          Text(backupManager.lastBackupDate?.formatted() ?? "more.backup.never".localized)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text04)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        Button("more.backup.viewAll".localized) {
          showingBackupList = true
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.primary)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
    .background(Color("appSurface02Variant"))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
          Text("more.backup.checkingSync".localized)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.text03)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        
      case .active:
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          VStack(alignment: .leading, spacing: 2) {
            Text("more.backup.syncActive".localized)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
            Text("more.backup.syncActiveDescription".localized)
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text03)
          }
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        
      case .inactive:
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          VStack(alignment: .leading, spacing: 2) {
            Text("more.backup.syncInactive".localized)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
            Text("more.backup.syncInactiveDescription".localized)
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.text03)
          }
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color("appSurface02Variant"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
