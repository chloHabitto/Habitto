import SwiftUI
import AVFoundation

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
    @State private var originalSnoozeDuration = SnoozeDuration.none
    @State private var completionReminderEnabled = false
    @State private var completionReminderTime = Date().settingHour(20).settingMinute(30)
    @State private var snoozeDuration = SnoozeDuration.none
    
    // Notification Sound State
    @State private var originalReminderSound = "Default"
    @State private var reminderSound = "Default"
    @State private var showingSoundPicker = false
    
    // Available sound options
    private let soundOptions = ["Default", "Gentle", "Chime", "Bell", "Crystal", "Digital", "Nature", "Piano", "Pop", "None"]
    
    // Snooze Duration Options
    enum SnoozeDuration: String, CaseIterable {
        case none = "None"
        case tenMinutes = "10 min"
        case fifteenMinutes = "15 min"
        case thirtyMinutes = "30 min"
        
        var minutes: Int {
            switch self {
            case .none: return 0
            case .tenMinutes: return 10
            case .fifteenMinutes: return 15
            case .thirtyMinutes: return 30
            }
        }
    }
    
    // Check if any changes were made
    private var hasChanges: Bool {
        return planReminderEnabled != originalPlanReminderEnabled ||
               planReminderTime != originalPlanReminderTime ||
               completionReminderEnabled != originalCompletionReminderEnabled ||
               completionReminderTime != originalCompletionReminderTime ||
               snoozeDuration != originalSnoozeDuration ||
               reminderSound != originalReminderSound
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
                            
                            // Notification Sound Section
                            notificationSoundSection
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
        .sheet(isPresented: $showingSoundPicker) {
            SoundPickerView(selectedSound: $reminderSound, soundOptions: soundOptions)
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    
                    snoozeDurationRow
                    
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 20)
                    
                    completionReminderPreviewRow
                }
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Notification Sound Section
    private var notificationSoundSection: some View {
        VStack(spacing: 0) {
            // Options container
            VStack(spacing: 0) {
                // Notification Sound Row
                notificationSoundRow
            }
            .background(.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    // MARK: - Snooze Duration Row
    private var snoozeDurationRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Snooze duration")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(SnoozeDuration.allCases, id: \.self) { duration in
                    Button(action: {
                        snoozeDuration = duration
                    }) {
                        Text(duration.rawValue)
                            .font(.appBodyMedium)
                            .foregroundColor(snoozeDuration == duration ? .white : .text02)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(snoozeDuration == duration ? Color.primary : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Snooze duration")
        .accessibilityHint("Choose how long to snooze completion reminders")
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
    
    // MARK: - Notification Sound Row
    private var notificationSoundRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notification Sound")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Text("Choose the sound for your daily reminders.")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Text(reminderSound)
                    .font(.appBodyMedium)
                    .foregroundColor(.text03)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.text03)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingSoundPicker = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityLabel("Notification sound")
        .accessibilityHint("Choose the sound for daily reminders")
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
        originalSnoozeDuration = snoozeDuration
        originalReminderSound = reminderSound
        
        // Save to UserDefaults
        UserDefaults.standard.set(planReminderEnabled, forKey: "planReminderEnabled")
        UserDefaults.standard.set(completionReminderEnabled, forKey: "completionReminderEnabled")
        UserDefaults.standard.set(planReminderTime, forKey: "planReminderTime")
        UserDefaults.standard.set(completionReminderTime, forKey: "completionReminderTime")
        UserDefaults.standard.set(snoozeDuration.rawValue, forKey: "snoozeDuration")
        UserDefaults.standard.set(reminderSound, forKey: "reminderSound")
        
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
        
        // Load snooze duration
        if let snoozeRawValue = UserDefaults.standard.string(forKey: "snoozeDuration"),
           let snooze = SnoozeDuration(rawValue: snoozeRawValue) {
            originalSnoozeDuration = snooze
            snoozeDuration = snooze
        }
        
        // Load reminder sound
        if let sound = UserDefaults.standard.string(forKey: "reminderSound") {
            originalReminderSound = sound
            reminderSound = sound
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

// MARK: - Sound Picker View
struct SoundPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSound: String
    let soundOptions: [String]
    
    // Track the original selection to determine if Save should be enabled
    @State private var originalSelection: String
    
    // Audio player for sound preview
    @State private var audioPlayer: AVAudioPlayer?
    
    init(selectedSound: Binding<String>, soundOptions: [String]) {
        self._selectedSound = selectedSound
        self.soundOptions = soundOptions
        self._originalSelection = State(initialValue: selectedSound.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            // Full screen background
            Color.surface2
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Reminder Sound",
                    description: "Choose your preferred notification sound"
                ) {
                    dismiss()
                }
                
                // Sound Options List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(soundOptions, id: \.self) { sound in
                            HStack(spacing: 12) {
                                Text(sound)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.text01)
                                
                                Spacer()
                                
                                // Checkmark for selected sound
                                if selectedSound == sound {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSound = sound
                                playSound(for: sound)
                            }
                            
                            if sound != soundOptions.last {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
                
                // Save Button
                VStack(spacing: 0) {
                    HabittoButton(
                        size: .large,
                        style: .fillPrimary,
                        content: .text("Save"),
                        state: selectedSound != originalSelection ? .default : .disabled
                    ) {
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Sound Playback
    private func playSound(for sound: String) {
        // Stop any currently playing sound
        audioPlayer?.stop()
        
        // Map sound names to system sound files
        let soundName: String
        switch sound {
        case "Default":
            soundName = "notification_default"
        case "Gentle":
            soundName = "notification_gentle"
        case "Chime":
            soundName = "notification_chime"
        case "Bell":
            soundName = "notification_bell"
        case "Crystal":
            soundName = "notification_crystal"
        case "Digital":
            soundName = "notification_digital"
        case "Nature":
            soundName = "notification_nature"
        case "Piano":
            soundName = "notification_piano"
        case "Pop":
            soundName = "notification_pop"
        case "None":
            return // Don't play anything for "None"
        default:
            soundName = "notification_default"
        }
        
        // Try to play the sound
        if let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.play()
            } catch {
                print("Error playing sound: \(error)")
                // Fallback to system sound if custom sound fails
                playSystemSound(for: sound)
            }
        } else {
            // Fallback to system sounds if custom sounds aren't available
            playSystemSound(for: sound)
        }
    }
    
    private func playSystemSound(for sound: String) {
        // Fallback to system notification sounds
        switch sound {
        case "Default":
            AudioServicesPlaySystemSound(1007) // System notification sound
        case "Gentle":
            AudioServicesPlaySystemSound(1008) // System notification sound (gentle)
        case "Chime":
            AudioServicesPlaySystemSound(1009) // System notification sound (chime)
        case "Bell":
            AudioServicesPlaySystemSound(1010) // System notification sound (bell)
        case "Crystal":
            AudioServicesPlaySystemSound(1011) // System notification sound (crystal-like)
        case "Digital":
            AudioServicesPlaySystemSound(1012) // System notification sound (digital)
        case "Nature":
            AudioServicesPlaySystemSound(1013) // System notification sound (nature)
        case "Piano":
            AudioServicesPlaySystemSound(1014) // System notification sound (piano-like)
        case "Pop":
            AudioServicesPlaySystemSound(1015) // System notification sound (pop)
        default:
            AudioServicesPlaySystemSound(1007) // Default system sound
        }
    }
}

#Preview {
    NotificationsView()
}

