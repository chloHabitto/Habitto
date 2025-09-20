import SwiftUI

struct BackupRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAutomaticBackupEnabled = false
    @State private var backupFrequency = "Daily"
    @State private var includePhotos = false
    @State private var wifiOnlyBackup = true
    
    let backupFrequencies = ["Daily", "Weekly", "Monthly", "Manual Only"]
    
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack {
                                    Toggle("", isOn: $isAutomaticBackupEnabled)
                                        .toggleStyle(SwitchToggleStyle(tint: .green500))
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.surface)
                            
                            if isAutomaticBackupEnabled {
                                Divider()
                                    .padding(.leading, 56)
                                
                                // Backup Frequency
                                HStack {
                                    Image("Icon-Clock_Filled")
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
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.surface)
                                
                                Divider()
                                    .padding(.leading, 56)
                                
                                // WiFi Only Backup
                                HStack {
                                    Image("Icon-Wifi_Filled")
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
                                        .toggleStyle(SwitchToggleStyle(tint: .green500))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.surface)
                            }
                        }
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Backup Status
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
                                    Text("Never backed up")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.text03)
                                }
                                
                                Spacer()
                                
                                Text("Backup Now")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green500)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green500.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.surface)
                        }
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }
                .background(Color.surface2)
            }
            .background(Color.surface2)
        }
    }
}

#Preview {
    BackupRecoveryView()
}
