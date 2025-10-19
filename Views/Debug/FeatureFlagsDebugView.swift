import SwiftUI

/// Debug view for testing feature flags
///
/// **Usage:**
/// Add to AccountView or More screen for easy access during development
///
/// **Features:**
/// - Master switch to enable all new systems
/// - Individual feature toggles
/// - Reset button
/// - Visual status indicators
struct FeatureFlagsDebugView: View {
    @StateObject private var flags = NewArchitectureFlags.shared
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            // Status Section
            statusSection
            
            // Master Switch
            masterSwitchSection
            
            // Individual Features
            individualFeaturesSection
            
            // Actions
            actionsSection
            
            // Info
            infoSection
        }
        .navigationTitle("Feature Flags")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: flags.useNewArchitecture) { _, _ in flags.saveFlags() }
        .onChange(of: flags.useNewProgressTracking) { _, _ in flags.saveFlags() }
        .onChange(of: flags.useNewStreakCalculation) { _, _ in flags.saveFlags() }
        .onChange(of: flags.useNewXPSystem) { _, _ in flags.saveFlags() }
        .alert("Reset Feature Flags?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                flags.resetToDefaults()
            }
        } message: {
            Text("This will disable all new features and return to the legacy system.")
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            HStack {
                Text("Current Mode")
                    .font(.headline)
                Spacer()
                Text(flags.anyEnabled ? "🆕 NEW" : "📦 LEGACY")
                    .font(.headline)
                    .foregroundColor(flags.anyEnabled ? .green : .secondary)
            }
            
            if flags.anyEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Features:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(flags.enabledFeatures, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(feature)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Status", systemImage: "info.circle")
        }
    }
    
    // MARK: - Master Switch Section
    
    private var masterSwitchSection: some View {
        Section {
            Toggle(isOn: $flags.useNewArchitecture) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🚀 New Architecture")
                            .font(.headline)
                        if flags.useNewArchitecture {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    Text("Enables all new systems at once")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.blue)
        } header: {
            Label("Master Switch", systemImage: "switch.2")
        } footer: {
            Text("When enabled, all individual feature flags are automatically enabled.")
                .font(.caption)
        }
    }
    
    // MARK: - Individual Features Section
    
    private var individualFeaturesSection: some View {
        Section {
            Toggle(isOn: $flags.useNewProgressTracking) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📊 Progress Tracking")
                        .font(.subheadline)
                    Text("SwiftData-based progress with timestamps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(flags.useNewArchitecture)
            .tint(.green)
            
            Toggle(isOn: $flags.useNewStreakCalculation) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥 Streak Calculation")
                        .font(.subheadline)
                    Text("Global streak across all habits")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(flags.useNewArchitecture)
            .tint(.orange)
            
            Toggle(isOn: $flags.useNewXPSystem) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⭐ XP System")
                        .font(.subheadline)
                    Text("Transaction-based XP with audit log")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(flags.useNewArchitecture)
            .tint(.purple)
        } header: {
            Label("Individual Features", systemImage: "slider.horizontal.3")
        } footer: {
            if flags.useNewArchitecture {
                Text("Individual toggles are disabled when Master Switch is ON.")
                    .font(.caption)
            } else {
                Text("Enable features individually for granular testing.")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button {
                flags.enableAll()
            } label: {
                Label("Enable All Features", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .disabled(flags.useNewArchitecture)
            
            Button {
                showResetAlert = true
            } label: {
                Label("Reset to Legacy", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.red)
            }
            .disabled(!flags.anyEnabled)
            
            Button {
                flags.printStatus()
            } label: {
                Label("Print Status to Console", systemImage: "printer")
            }
        } header: {
            Label("Actions", systemImage: "bolt.fill")
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            InfoRow(
                icon: "📊",
                title: "Progress Tracking",
                description: "Uses new DailyProgressModel with timestamps and difficulty tracking"
            )
            
            InfoRow(
                icon: "🔥",
                title: "Streak Calculation",
                description: "Global streak that only increments when ALL scheduled habits are complete"
            )
            
            InfoRow(
                icon: "⭐",
                title: "XP System",
                description: "Transaction-based XP with automatic reversal when progress is undone"
            )
        } header: {
            Label("What's New", systemImage: "sparkles")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ Testing Mode")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("These flags are for development and testing only. The new architecture is under active development.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeatureFlagsDebugView()
    }
}

