import SwiftUI

// MARK: - CloudKit Settings View
/// Settings view for managing CloudKit synchronization
struct CloudKitSettingsView: View {
    @StateObject private var cloudKitIntegration = CloudKitIntegrationService.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var conflictResolver = CloudKitConflictResolver()
    @State private var showingSyncDetails = false
    @State private var showingConflictResolution = false
    
    var body: some View {
        NavigationView {
            List {
                // CloudKit Status Section
                Section {
                    Text("CloudKit Status")
                        .font(.headline)
                        .padding(.bottom, 8)
                    HStack {
                        Image(systemName: CloudKitManager.shared.isSignedIn ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(CloudKitManager.shared.isSignedIn ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text("iCloud Account")
                                .font(.headline)
                            Text(CloudKitManager.shared.isSignedIn ? "Signed In" : "Not Signed In")
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
    
}

// MARK: - CloudKit Sync Details View
struct CloudKitSyncDetailsView: View {
    @StateObject private var cloudKitIntegration = CloudKitIntegrationService.shared
    @Environment(\.dismiss) private var dismiss
    
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
}

// MARK: - CloudKit Conflict Resolution View
struct CloudKitConflictResolutionView: View {
    @StateObject private var conflictResolver = CloudKitConflictResolver.shared
    @Environment(\.dismiss) private var dismiss
    
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
}

// MARK: - Conflict Row View
struct ConflictRowView: View {
    let conflict: ConflictRecord
    @State private var selectedResolution: ConflictResolution = .useLocal
    
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
}

// MARK: - Preview
#Preview {
    CloudKitSettingsView()
}
