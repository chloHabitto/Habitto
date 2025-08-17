import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // State variables for notification settings
    @State private var habitRemindersEnabled = true
    @State private var reminderSound = "Default"
    @State private var reminderVibration = true
    @State private var showingSoundPicker = false
    
    // Available sound options
    private let soundOptions = ["Default", "Gentle", "Chime", "Bell", "None"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Notifications",
                        description: "Manage your notification preferences"
                    ) {
                        dismiss()
                    }
                    
                    // Habit Reminders Section
                    VStack(spacing: 0) {
                        // Main toggle for habit reminders
                        AccountOptionRow(
                            icon: "Icon-Bell_Filled",
                            title: "Habit Reminders",
                            subtitle: "Get notified about your daily habits",
                            hasChevron: false,
                            action: {
                                habitRemindersEnabled.toggle()
                            }
                        )
                        .overlay(
                            HStack {
                                Spacer()
                                Toggle("", isOn: $habitRemindersEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    .scaleEffect(0.8)
                            }
                            .padding(.trailing, 20)
                        )
                        
                        if habitRemindersEnabled {
                            Divider()
                                .padding(.leading, 56)
                            
                            // Reminder Sound
                            AccountOptionRow(
                                icon: "Icon-Speaker_Filled",
                                title: "Reminder Sound",
                                subtitle: reminderSound,
                                hasChevron: true
                            ) {
                                showingSoundPicker = true
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Reminder Vibration
                            AccountOptionRow(
                                icon: "Icon-Vibration_Filled",
                                title: "Reminder Vibration",
                                subtitle: reminderVibration ? "On" : "Off",
                                hasChevron: false,
                                action: {
                                    reminderVibration.toggle()
                                }
                            )
                            .overlay(
                                HStack {
                                    Spacer()
                                    Toggle("", isOn: $reminderVibration)
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        .scaleEffect(0.8)
                                }
                                .padding(.trailing, 20)
                            )
                        }
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
                .background(Color.surface2)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSoundPicker) {
            SoundPickerView(selectedSound: $reminderSound, soundOptions: soundOptions)
        }
    }
}

// MARK: - Sound Picker View
struct SoundPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSound: String
    let soundOptions: [String]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Reminder Sound",
                    description: "Choose your preferred notification sound"
                ) {
                    dismiss()
                }
                
                // Sound Options List
                VStack(spacing: 0) {
                    ForEach(soundOptions, id: \.self) { sound in
                        Button(action: {
                            selectedSound = sound
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                // Icon based on sound type
                                Image(systemName: soundIcon(for: sound))
                                    .font(.system(size: 20))
                                    .foregroundColor(sound == "None" ? .text04 : .primary)
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sound)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.text01)
                                    
                                    Text(soundDescription(for: sound))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.text04)
                                }
                                
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
                
                Spacer()
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
    
    private func soundIcon(for sound: String) -> String {
        switch sound {
        case "Default": return "speaker.wave.2.fill"
        case "Gentle": return "speaker.wave.1.fill"
        case "Chime": return "bell.fill"
        case "Bell": return "bell.badge.fill"
        case "None": return "speaker.slash.fill"
        default: return "speaker.wave.2.fill"
        }
    }
    
    private func soundDescription(for sound: String) -> String {
        switch sound {
        case "Default": return "Standard notification sound"
        case "Gentle": return "Soft, pleasant tone"
        case "Chime": return "Clear, melodic chime"
        case "Bell": return "Traditional bell sound"
        case "None": return "Silent notifications"
        default: return "Standard notification sound"
        }
    }
}

#Preview {
    NotificationsView()
}
