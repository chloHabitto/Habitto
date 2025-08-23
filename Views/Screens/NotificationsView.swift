import SwiftUI
import AVFoundation

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // State variables for notification settings
    @State private var habitRemindersEnabled = true
    @State private var reminderSound = "Default"
    @State private var reminderVibration = true
    @State private var reminderVolume: Double = 0.7
    @State private var showingSoundPicker = false
    @State private var changeVolumeWithButtons = true
    
    // Available sound options
    private let soundOptions = ["Default", "Gentle", "Chime", "Bell", "Crystal", "Digital", "Nature", "Piano", "Pop", "None"]
    
    var body: some View {
        ZStack {
            // Full screen background
            Color.surface2
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Notifications",
                    description: "Manage your notification preferences"
                ) {
                    dismiss()
                }
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Habit Reminders Section
                        VStack(spacing: 0) {
                            // Main toggle for habit reminders
                            HStack(spacing: 12) {
                                Text("Habit Reminders")
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text01)
                                
                                Spacer()
                                
                                Toggle("", isOn: $habitRemindersEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    .scaleEffect(0.8)
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 12)
                            .padding(.vertical, 16)
                            .frame(height: 56)
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Reminder Sound
                            HStack(spacing: 12) {
                                Text("Reminder Sound")
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text01)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text(reminderSound)
                                        .font(.appBodyLarge)
                                        .foregroundColor(.text03)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.text03)
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 24)
                            .padding(.vertical, 16)
                            .frame(height: 56)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingSoundPicker = true
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 24)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSoundPicker) {
            SoundPickerView(selectedSound: $reminderSound, soundOptions: soundOptions)
        }
    }
    
    // MARK: - Sound Preview
    private func previewSoundAtVolume(_ volume: Double) {
        // Only preview if habit reminders are enabled and a sound is selected
        guard habitRemindersEnabled && reminderSound != "None" else { return }
        
        // Map sound names to system sound files
        let soundName: String
        switch reminderSound {
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
        default:
            soundName = "notification_default"
        }
        
        // Try to play the sound at the specified volume
        if let soundURL = Bundle.main.url(forResource: soundName, withExtension: "wav") {
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer.volume = Float(volume)
                audioPlayer.play()
            } catch {
                print("Error playing sound preview: \(error)")
                // Fallback to system sound with volume control
                playSystemSoundAtVolume(volume)
            }
        } else {
            // Fallback to system sounds with volume control
            playSystemSoundAtVolume(volume)
        }
    }
    
    private func playSystemSoundAtVolume(_ volume: Double) {
        // For system sounds, we can't control volume directly, but we can use different sound IDs
        // that represent different volume levels, or implement a workaround
        
        // Map volume to different system sound intensities
        let soundID: SystemSoundID
        let baseVolume: Double
        
        switch reminderSound {
        case "Default":
            soundID = 1007
            baseVolume = 1.0
        case "Gentle":
            soundID = 1008
            baseVolume = 0.8
        case "Chime":
            soundID = 1009
            baseVolume = 1.0
        case "Bell":
            soundID = 1010
            baseVolume = 1.0
        case "Crystal":
            soundID = 1011
            baseVolume = 0.9
        case "Nature":
            soundID = 1012
            baseVolume = 0.7
        case "Piano":
            soundID = 1013
            baseVolume = 0.8
        case "Pop":
            soundID = 1014
            baseVolume = 1.0
        default:
            soundID = 1007
            baseVolume = 1.0
        }
        
        // Calculate effective volume (system sounds have limited volume control)
        let effectiveVolume = min(volume * baseVolume, 1.0)
        
        // Play the system sound
        AudioServicesPlaySystemSoundWithCompletion(soundID) { }
        
        // Note: System sounds have limited volume control, but the volume slider
        // will affect the final notification volume when implemented in the actual notifications
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
