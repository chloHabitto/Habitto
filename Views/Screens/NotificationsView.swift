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
    
    
    
    // Check if any changes were made
    private var hasChanges: Bool {
        return planReminderEnabled != originalPlanReminderEnabled ||
               planReminderTime != originalPlanReminderTime ||
               completionReminderEnabled != originalCompletionReminderEnabled ||
               completionReminderTime != originalCompletionReminderTime
    }
    
    // Plan reminder preview title
    private var planReminderPreviewTitle: String {
        let habitCount = getTodayHabitCount()
        return generatePlanReminderTitle(habitCount: habitCount)
    }
    
    // Plan reminder preview message
    private var planReminderPreviewMessage: String {
        let habitCount = getTodayHabitCount()
        return generatePlanReminderMessage(habitCount: habitCount)
    }
    
    // Completion reminder preview title
    private var completionReminderPreviewTitle: String {
        let incompleteCount = getTodayIncompleteHabitCount()
        return generateCompletionReminderTitle(incompleteCount: incompleteCount)
    }
    
    // Completion reminder preview message
    private var completionReminderPreviewMessage: String {
        let incompleteCount = getTodayIncompleteHabitCount()
        return generateCompletionReminderMessage(incompleteCount: incompleteCount)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content with save button
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 24) {
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
                    
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 20)
                    
                    planReminderPreviewRow
                }
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
                    
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 20)
                    
                    completionReminderPreviewRow
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
    
    // MARK: - Plan Reminder Preview Row
    private var planReminderPreviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
            }
            
            // Preview message container
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(planReminderPreviewTitle)
                        .font(.appBodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.text01)
                }
                
                Text(planReminderPreviewMessage)
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Plan reminder preview")
        .accessibilityHint("Shows what your plan reminder notification will look like")
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
    
    
    // MARK: - Completion Reminder Preview Row
    private var completionReminderPreviewRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
            }
            
            // Preview message container
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(completionReminderPreviewTitle)
                        .font(.appBodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.text01)
                }
                
                Text(completionReminderPreviewMessage)
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Completion reminder preview")
        .accessibilityHint("Shows what your completion reminder notification will look like")
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
        
        // Save to UserDefaults
        UserDefaults.standard.set(planReminderEnabled, forKey: "planReminderEnabled")
        UserDefaults.standard.set(completionReminderEnabled, forKey: "completionReminderEnabled")
        UserDefaults.standard.set(planReminderTime, forKey: "planReminderTime")
        UserDefaults.standard.set(completionReminderTime, forKey: "completionReminderTime")
        
        // Schedule daily reminders based on new settings
        Task { @MainActor in
            print("🔄 NotificationsView: Rescheduling daily reminders after settings change...")
            NotificationManager.shared.rescheduleDailyReminders()
        }
        
        // Dismiss the view
        dismiss()
    }
    
    // MARK: - Data Persistence
    private func loadReminderSettings() {
        let planEnabled = UserDefaults.standard.bool(forKey: "planReminderEnabled")
        let completionEnabled = UserDefaults.standard.bool(forKey: "completionReminderEnabled")
        
        // Set both original and current values
        originalPlanReminderEnabled = planEnabled
        planReminderEnabled = planEnabled
        
        originalCompletionReminderEnabled = completionEnabled
        completionReminderEnabled = completionEnabled
        
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
    
    // MARK: - Helper Methods
    
    /// Get the count of habits scheduled for today
    private func getTodayHabitCount() -> Int {
        let today = Date()
        let habits = HabitRepository.shared.habits
        
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: today)
        }.count
    }
    
    /// Generate plan reminder title based on habit count
    private func generatePlanReminderTitle(habitCount: Int) -> String {
        switch habitCount {
        case 0:
            return "📅 Your Daily Plan"
        case 1:
            return "📅 1 Habit Today"
        default:
            return "📅 \(habitCount) Habits Today"
        }
    }
    
    /// Generate plan reminder message based on habit count
    private func generatePlanReminderMessage(habitCount: Int) -> String {
        switch habitCount {
        case 0:
            return "You have a free day! Perfect time to relax or try something new."
        case 1:
            return "You have 1 habit scheduled for today. Let's make it count! 💪"
        case 2...3:
            return "You have \(habitCount) habits scheduled for today. You've got this! 🚀"
        case 4...6:
            return "You have \(habitCount) habits scheduled for today. A productive day ahead! ⭐"
        default:
            return "You have \(habitCount) habits scheduled for today. Time to shine! ✨"
        }
    }
    
    /// Get the count of incomplete habits for today
    private func getTodayIncompleteHabitCount() -> Int {
        let today = Date()
        let habits = HabitRepository.shared.habits
        
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: today) && 
            !habit.isCompleted(for: today)
        }.count
    }
    
    /// Generate completion reminder title based on incomplete habit count
    private func generateCompletionReminderTitle(incompleteCount: Int) -> String {
        switch incompleteCount {
        case 0:
            return "🎉 All Done Today!"
        case 1:
            return "⏰ 1 Habit Remaining"
        default:
            return "⏰ \(incompleteCount) Habits Remaining"
        }
    }
    
    /// Generate completion reminder message based on incomplete habit count
    private func generateCompletionReminderMessage(incompleteCount: Int) -> String {
        switch incompleteCount {
        case 0:
            return "Amazing! You've completed all your habits today. Well done! 🌟"
        case 1:
            return "You have 1 habit left to complete today. You're almost there! 💪"
        case 2...3:
            return "You have \(incompleteCount) habits left to complete today. Keep going! 🚀"
        case 4...6:
            return "You have \(incompleteCount) habits left to complete today. Every step counts! ⭐"
        default:
            return "You have \(incompleteCount) habits left to complete today. You can do this! ✨"
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
        var components = calendar.dateComponents(in: .current, from: self)
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? self
    }
}

#Preview {
    NotificationsView()
}

