import SwiftUI
import Foundation

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
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with close button and left-aligned title
                        ScreenHeader(
                            title: "Backup & Recovery",
                            description: "Configure your backup settings and manage your data"
                        ) {
                            dismiss()
                        }
                        
                        // Backup Settings
                        VStack(spacing: 0) {
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
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // Backup Frequency (shown when automatic backup is enabled)
                            if isAutomaticBackupEnabled {
                                VStack(spacing: 0) {
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
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 12)
                            }
                            
                            // WiFi Only Toggle (shown when automatic backup is enabled)
                            if isAutomaticBackupEnabled {
                                VStack(spacing: 0) {
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
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 12)
                            }
                        }
                        
                        // Backup Status Section
                        VStack(spacing: 0) {
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
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // Backup Now Button
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
                                .cornerRadius(12)
                            }
                            .disabled(isBackingUp)
                            .padding(.top, 12)
                            
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
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
            .background(Color.surface2)
        }
        
        @MainActor
        private func loadBackupSettings() {
            let config = BackupScheduler.loadScheduleConfig()
            isAutomaticBackupEnabled = config.isEnabled
            backupFrequency = config.frequency.displayName
            wifiOnlyBackup = config.networkCondition == NetworkCondition.wifiOnly
        }
        
        private func saveBackupSettings() async {
            let frequency: BackupFrequency = {
                switch backupFrequency {
                case "Daily": return .daily
                case "Weekly": return .weekly
                case "Monthly": return .monthly
                default: return .manual
                }
            }()
            
            backupScheduler.updateSchedule(
                isEnabled: isAutomaticBackupEnabled,
                frequency: frequency,
                networkCondition: wifiOnlyBackup ? NetworkCondition.wifiOnly : NetworkCondition.any
            )
            
            // Show notification for settings change
            notificationService.showSettingsChanged()
        }
        
        private func performBackup() async {
            isBackingUp = true
            
            do {
                let result = try await backupManager.createBackup()
                
                await MainActor.run {
                    notificationService.showBackupSuccess(
                        backupSize: result.formattedSize,
                        habitCount: result.habitCount
                    )
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
