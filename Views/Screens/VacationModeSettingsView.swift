import SwiftUI

struct VacationModeSettingsView: View {
    @StateObject private var vacationManager = VacationManager.shared
    @State private var showingStartVacation = false
    @State private var showingEndVacation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Status Section
                    currentStatusSection
                    
                    // Quick Actions Section
                    quickActionsSection
                    
                    // Vacation History Section
                    vacationHistorySection
                    
                    // Settings Section
                    settingsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Vacation Mode")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingStartVacation) {
            StartVacationModal()
        }
        .sheet(isPresented: $showingEndVacation) {
            EndVacationModal()
        }
    }
    
    // MARK: - Current Status Section
    private var currentStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image("Icon-Vacation_Filled")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
                
                Text("Current Status")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            if vacationManager.isActive {
                // Active vacation mode
                VStack(spacing: 12) {
                    HStack {
                        Text("Vacation Mode Active")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                    }
                    
                    if let current = vacationManager.current {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Started")
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text03)
                                Text(formatDate(current.start))
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Duration")
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text03)
                                Text(durationText(from: current.start, to: current.end ?? Date()))
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Inactive vacation mode
                VStack(spacing: 8) {
                    Text("Vacation Mode Inactive")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text02)
                    
                    Text("Start vacation mode to pause habit tracking and notifications")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(Color.grey100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Quick Actions")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if vacationManager.isActive {
                    // End vacation button
                    Button(action: {
                        showingEndVacation = true
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                            Text("End Vacation Mode")
                                .font(.appBodyMediumEmphasised)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Start vacation button
                    Button(action: {
                        showingStartVacation = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                            Text("Start Vacation Mode")
                                .font(.appBodyMediumEmphasised)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Vacation History Section
    private var vacationHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.purple)
                
                Text("Vacation History")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            if vacationManager.history.isEmpty {
                Text("No vacation periods yet")
                    .font(.appBodyMedium)
                    .foregroundColor(.text03)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.grey100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(vacationManager.history.prefix(5), id: \.start) { vacation in
                        VacationHistoryRow(vacation: vacation)
                    }
                    
                    if vacationManager.history.count > 5 {
                        Button("View All History") {
                            // TODO: Navigate to full history view
                        }
                        .font(.appBodySmall)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gear.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.grey600)
                
                Text("Settings")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                VacationSettingsRow(
                    icon: "bell.slash.fill",
                    title: "Mute Notifications",
                    subtitle: "Automatically mute all notifications during vacation",
                    isOn: true // This would be a setting
                )
                
                VacationSettingsRow(
                    icon: "chart.bar.fill",
                    title: "Pause Analytics",
                    subtitle: "Stop tracking analytics during vacation periods",
                    isOn: true // This would be a setting
                )
                
                VacationSettingsRow(
                    icon: "icloud.fill",
                    title: "Sync Settings",
                    subtitle: "Sync vacation mode across all devices",
                    isOn: false // This would be a setting
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func durationText(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let days = Int(duration / 86400)
        let hours = Int((duration.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            return "\(hours)h"
        }
    }
}

// MARK: - Vacation History Row
struct VacationHistoryRow: View {
    let vacation: VacationPeriod
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(vacation.start))
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                if let end = vacation.end {
                    Text("Duration: \(durationText(from: vacation.start, to: end))")
                        .font(.appLabelSmall)
                        .foregroundColor(.text03)
                } else {
                    Text("Ongoing")
                        .font(.appLabelSmall)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.text04)
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func durationText(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let days = Int(duration / 86400)
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

// MARK: - Vacation Settings Row
struct VacationSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @State var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Text(subtitle)
                    .font(.appLabelSmall)
                    .foregroundColor(.text03)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Start Vacation Modal
struct StartVacationModal: View {
    @State private var startDate = Date()
    @State private var endDate: Date? = nil
    @State private var hasEndDate = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Start Vacation Mode")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                VStack(spacing: 16) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(GraphicalDatePickerStyle())
                    
                    Toggle("Set End Date", isOn: $hasEndDate)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date().addingTimeInterval(86400) },
                            set: { endDate = $0 }
                        ), displayedComponents: [.date])
                        .datePickerStyle(GraphicalDatePickerStyle())
                    }
                }
                
                Spacer()
                
                Button("Start Vacation") {
                    VacationManager.shared.startVacation(now: startDate)
                    dismiss()
                }
                .font(.appBodyMediumEmphasised)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - End Vacation Modal
struct EndVacationModal: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image("Icon-Vacation_Filled")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("End Vacation Mode")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text("This will end your current vacation period and resume normal habit tracking.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("End Vacation Now") {
                        VacationManager.shared.endVacation()
                        dismiss()
                    }
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.grey100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    VacationModeSettingsView()
}
