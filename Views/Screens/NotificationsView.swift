import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Plan Reminder State
    @State private var originalPlanReminderEnabled = false
    @State private var originalPlanReminderTime = Date().settingHour(8).settingMinute(0)
    @State private var planReminderEnabled = false
    @State private var planReminderTime = Date().settingHour(8).settingMinute(0)
    
    // Completion Reminder State
    @State private var originalCompletionReminderEnabled = false
    @State private var originalCompletionReminderTime = Date().settingHour(20).settingMinute(30)
    @State private var completionReminderEnabled = false
    @State private var completionReminderTime = Date().settingHour(20).settingMinute(30)
    
    // Habit Reminder State
    @State private var originalHabitReminderEnabled = false
    @State private var habitReminderEnabled = false
    
    
    
    // Check if any changes were made
    private var hasChanges: Bool {
        return planReminderEnabled != originalPlanReminderEnabled ||
               planReminderTime != originalPlanReminderTime ||
               completionReminderEnabled != originalCompletionReminderEnabled ||
               completionReminderTime != originalCompletionReminderTime ||
               habitReminderEnabled != originalHabitReminderEnabled
    }
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content with save button
                ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                            // Habit Reminder Section
                            habitReminderSection
                            
                            // Plan Reminder Section
                            planReminderSection
                            
                            // Completion Reminder Section
                            completionReminderSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 140) // Extra bottom padding for save button
                    }
                    
                    // Save button at bottom
                    saveButton
                }
            }
            .background(Color.surface2)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.text01)
                    }
                }
            }
        }
        .onAppear {
            loadReminderSettings()
        }
    }
    
    // MARK: - Plan Reminder Section
    private var planReminderSection: some View {
        VStack(spacing: 0) {
            // Options container
            VStack(spacing: 0) {
                // Plan Reminder Toggle
                planReminderToggleRow
                
                if planReminderEnabled {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 20)
                    
                    planReminderTimeRow
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Habit Reminder Section
    private var habitReminderSection: some View {
        VStack(spacing: 0) {
            // Options container
            VStack(spacing: 0) {
                // Habit Reminder Toggle
                habitReminderToggleRow
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Completion Reminder Section
    private var completionReminderSection: some View {
        VStack(spacing: 0) {
            // Options container
            VStack(spacing: 0) {
                // Completion Reminder Toggle
                completionReminderToggleRow
                
                if completionReminderEnabled {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 20)
                    
                    completionReminderTimeRow
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    
    // MARK: - Plan Reminder Toggle Row
    private var planReminderToggleRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan reminder")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Text("We'll let you know how many habits you have today.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: $planReminderEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                .scaleEffect(0.8)
                .padding(.trailing, 0)
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Plan reminder toggle")
        .accessibilityHint("Enables or disables daily plan reminders")
    }
    
    // MARK: - Habit Reminder Toggle Row
    private var habitReminderToggleRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Habit reminders")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Text("Get notified for individual habit reminders you've set.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .fixedSize(horizontal: false, vertical: true)
                
                if habitReminderEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Add reminders to individual habits in their detail screens to receive notifications.")
                            .font(.appBodySmall)
                            .foregroundColor(.text05)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    Task { @MainActor in
                                        NotificationManager.shared.scheduleTestHabitReminder()
                                    }
                                }) {
                                    Text("🧪 Test Notification (10 seconds)")
                                        .font(.appBodySmall)
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    Task { @MainActor in
                                        NotificationManager.shared.debugHabitRemindersStatus()
                                    }
                                }) {
                                    Text("🔍 Debug Status")
                                        .font(.appBodySmall)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Button(action: {
                                Task { @MainActor in
                                    NotificationManager.shared.forceRescheduleAllHabitReminders()
                                }
                            }) {
                                Text("🔄 Force Reschedule All Habit Reminders")
                                    .font(.appBodySmall)
                                    .foregroundColor(.orange)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                Task { @MainActor in
                                    // Clear all existing habit reminders
                                    NotificationManager.shared.removeAllHabitReminders()
                                    // Reschedule with corrected timezone handling
                                    NotificationManager.shared.forceRescheduleAllHabitReminders()
                                }
                            }) {
                                Text("🔧 Fix Timezone & Reschedule")
                                    .font(.appBodySmall)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: $habitReminderEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                .scaleEffect(0.8)
                .padding(.trailing, 0)
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Habit reminders toggle")
        .accessibilityHint("Enables or disables individual habit reminders")
    }
    
    // MARK: - Plan Reminder Time Row
    private var planReminderTimeRow: some View {
        HStack(spacing: 16) {
            Text("Reminder time")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $planReminderTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Plan reminder time")
        .accessibilityHint("Set the time for daily plan reminders")
    }
    
    
    // MARK: - Completion Reminder Toggle Row
    private var completionReminderToggleRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Completion reminder")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Text("We'll remind you of any habits you haven't completed today.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: $completionReminderEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                .scaleEffect(0.8)
                .padding(.trailing, 0)
                .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Completion reminder toggle")
        .accessibilityHint("Enables or disables daily completion reminders")
    }
    
    // MARK: - Completion Reminder Time Row
    private var completionReminderTimeRow: some View {
        HStack(spacing: 16) {
            Text("Reminder time")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $completionReminderTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
                    }
                    .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Completion reminder time")
        .accessibilityHint("Set the time for daily completion reminders")
    }
    
    
    
    
    // MARK: - Save Button
    private var saveButton: some View {
        VStack(spacing: 0) {
            // Gradient overlay to fade content behind button
            LinearGradient(
                gradient: Gradient(colors: [Color.surface2.opacity(0), Color.surface2]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            // Button container
            HStack {
                HabittoButton.largeFillPrimary(
                    text: "Save",
                    state: hasChanges ? .default : .disabled,
                    action: saveChanges
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
        }
    }
    
    // MARK: - Save Action
    private func saveChanges() {
        // Update original values to reflect the new saved state
        originalPlanReminderEnabled = planReminderEnabled
        originalPlanReminderTime = planReminderTime
        originalCompletionReminderEnabled = completionReminderEnabled
        originalCompletionReminderTime = completionReminderTime
        originalHabitReminderEnabled = habitReminderEnabled
        
        // Save to UserDefaults
        UserDefaults.standard.set(planReminderEnabled, forKey: "planReminderEnabled")
        UserDefaults.standard.set(completionReminderEnabled, forKey: "completionReminderEnabled")
        UserDefaults.standard.set(habitReminderEnabled, forKey: "habitReminderEnabled")
        UserDefaults.standard.set(planReminderTime, forKey: "planReminderTime")
        UserDefaults.standard.set(completionReminderTime, forKey: "completionReminderTime")
        
        // Schedule daily reminders based on new settings
        Task { @MainActor in
            print("🔄 NotificationsView: Rescheduling daily reminders after settings change...")
            NotificationManager.shared.rescheduleDailyReminders()
            
            // If habit reminders were just enabled, reschedule all existing habits
            if habitReminderEnabled && !originalHabitReminderEnabled {
                print("🔄 NotificationsView: Habit reminders just enabled, rescheduling all existing habits...")
                NotificationManager.shared.rescheduleAllHabitReminders()
            }
        }
        
        // Dismiss the view
        dismiss()
    }
    
    // MARK: - Data Persistence
    private func loadReminderSettings() {
        let planEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
        let completionEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
        let habitEnabled = UserDefaults.standard.bool(forKey: "habitReminderEnabled")
        
        // Set both original and current values
        originalPlanReminderEnabled = planEnabled
        planReminderEnabled = planEnabled
        
        originalCompletionReminderEnabled = completionEnabled
        completionReminderEnabled = completionEnabled
        
        originalHabitReminderEnabled = habitEnabled
        habitReminderEnabled = habitEnabled
        
        // Load times
        if let planTime = UserDefaults.standard.object(forKey: "planReminderTime") as? Date {
            originalPlanReminderTime = planTime
            planReminderTime = planTime
        }
        if let completionTime = UserDefaults.standard.object(forKey: "completionReminderTime") as? Date {
            originalCompletionReminderTime = completionTime
            completionReminderTime = completionTime
        }
        
    }
    
}

// MARK: - Date Extensions
extension Date {
    func settingHour(_ hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? self
    }
    
    func settingMinute(_ minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? self
    }
}

#Preview {
    NotificationsView()
}

