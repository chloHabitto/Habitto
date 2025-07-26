import SwiftUI

struct AlarmItem: Identifiable {
    let id = UUID()
    let time: Date
    var isActive: Bool
}

struct ReminderBottomSheet: View {
    let onClose: () -> Void
    let onReminderSelected: (String) -> Void
    let initialAlarms: [AlarmItem]
    let onAlarmsUpdated: ([AlarmItem]) -> Void
    
    @State private var selectedReminderType: String = "Notification"
    @State private var selectedTab = 0
    @State private var selectedTime = Date()
    @State private var selectedDays: Set<String> = []
    @State private var showingAddAlarmSheet = false
    @State private var alarms: [AlarmItem]
    @State private var isEditMode = false
    
    init(onClose: @escaping () -> Void, onReminderSelected: @escaping (String) -> Void, initialAlarms: [AlarmItem] = [], onAlarmsUpdated: @escaping ([AlarmItem]) -> Void) {
        self.onClose = onClose
        self.onReminderSelected = onReminderSelected
        self.initialAlarms = initialAlarms
        self.onAlarmsUpdated = onAlarmsUpdated
        self._alarms = State(initialValue: initialAlarms)
    }
    
    private var selectedReminderText: String {
        if selectedTab == 0 {
            // Notification tab
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: selectedTime)
        } else {
            // Custom tab
            if selectedDays.isEmpty {
                return "No reminder"
            } else {
                let dayNames = selectedDays.sorted().map { day in
                    switch day {
                    case "MON": return "Monday"
                    case "TUE": return "Tuesday"
                    case "WED": return "Wednesday"
                    case "THU": return "Thursday"
                    case "FRI": return "Friday"
                    case "SAT": return "Saturday"
                    case "SUN": return "Sunday"
                    default: return day
                    }
                }
                return dayNames.joined(separator: ", ")
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Buttons
            HStack {
                Button(isEditMode ? "Done" : "Edit") {
                    isEditMode.toggle()
                }
                .font(.buttonText2)
                .foregroundColor(.text01)
                .frame(width: 62, height: 44)
                
                Spacer()
                
                Button(action: {
                    showingAddAlarmSheet = true
                }) {
                    Image("Icon-plus")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.primary)
                }
                .frame(width: 48, height: 48)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 16)
            
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminder")
                    .font(.headlineSmallEmphasised)
                    .foregroundColor(.text01)
                Text("Choose when you want to be reminded about this habit")
                    .font(.titleSmall)
                    .foregroundColor(.text05)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            
            // Alarms List
            if !alarms.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                        HStack {
                            Text(formatTime(alarm.time))
                                .font(.bodyLarge)
                                .foregroundColor(.text01)
                            
                            Spacer()
                            
                            if isEditMode {
                                Button(action: {
                                    alarms.remove(at: index)
                                }) {
                                    Image("Icon-close")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(.text04)
                                }
                                .frame(width: 32, height: 32)
                            } else {
                                Toggle("", isOn: $alarms[index].isActive)
                                    .toggleStyle(SwitchToggleStyle(tint: .primary))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(.secondaryContainer)
                        .cornerRadius(8)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Button dock
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
//                    Button("Cancel") {
//                        onClose()
//                    }
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 48)
//                    .background(.secondaryContainer)
//                    .foregroundColor(.onSecondaryContainer)
//                    .cornerRadius(8)
                    
                    Button("Confirm") {
                        onAlarmsUpdated(alarms)
                    }
                    .font(Font.buttonText1)
                    .foregroundColor(.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1C274C"))
                    .clipShape(Capsule())
                }
                .padding(24)
            }
        }
        .background(.surface)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .sheet(isPresented: $showingAddAlarmSheet) {
            AddAlarmSheet { newAlarm in
                alarms.append(AlarmItem(time: newAlarm, isActive: true))
            }
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
}

struct AddAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()
    let onSave: (Date) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.buttonText2)
                .foregroundColor(.text01)
                .frame(width: 62, height: 44)
                
                Spacer()
                
                Button("Save") {
                    onSave(selectedTime)
                    dismiss()
                }
                .font(.buttonText2)
                .foregroundColor(.text01)
                .frame(width: 62, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            // Title
            Text("Select Time")
                .font(.headlineSmallEmphasised)
                .foregroundColor(.text01)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            
            // Time Picker
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(.surface)
        .presentationDetents([.medium, .height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

#Preview {
    ReminderBottomSheet(
        onClose: {},
        onReminderSelected: { _ in },
        initialAlarms: [],
        onAlarmsUpdated: { _ in }
    )
} 
