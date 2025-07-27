import SwiftUI

struct ReminderItem: Identifiable {
    let id = UUID()
    var time: Date
    var isActive: Bool
}

struct ReminderBottomSheet: View {
    let onClose: () -> Void
    let onReminderSelected: (String) -> Void
    let initialReminders: [ReminderItem]
    let onRemindersUpdated: ([ReminderItem]) -> Void
    
    @State private var selectedReminderType: String = "Notification"
    @State private var selectedTab = 0
    @State private var selectedTime = Date()
    @State private var selectedDays: Set<String> = []
    @State private var showingAddReminderSheet = false
    @State private var reminders: [ReminderItem]
    @State private var isEditMode = false
    @State private var editingReminderIndex: Int? = nil
    
    init(onClose: @escaping () -> Void, onReminderSelected: @escaping (String) -> Void, initialReminders: [ReminderItem] = [], onRemindersUpdated: @escaping ([ReminderItem]) -> Void) {
        self.onClose = onClose
        self.onReminderSelected = onReminderSelected
        self.initialReminders = initialReminders
        self.onRemindersUpdated = onRemindersUpdated
        self._reminders = State(initialValue: initialReminders)
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
                    showingAddReminderSheet = true
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
            
            // Divider under header
            Divider()
                .background(.outline)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            
            // Reminders List
            if !reminders.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                            HStack(spacing: 16) {
                                if isEditMode {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            reminders.remove(at: index)
                                            isEditMode = false
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.red)
                                    }
                                    .frame(width: 40, height: 40)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                                
                                HStack {
                                    Text(formatTime(reminder.time))
                                        .font(.bodyLarge)
                                        .foregroundColor(.text01)
                                    
                                    Spacer()
                                    
                                    if isEditMode {
                                        Image(systemName: "chevron.right")
                                            .font(.labelMedium)
                                            .foregroundColor(.primaryDim)
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Toggle("", isOn: $reminders[index].isActive)
                                            .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    }
                                }
                                .padding(.leading, 24)
                                .padding(.trailing, 16)
                                .padding(.vertical, 8)
                                .background(.secondaryContainer)
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isEditMode {
                                        editingReminderIndex = index
                                        selectedTime = reminder.time
                                        showingAddReminderSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .animation(.easeInOut(duration: 0.3), value: isEditMode)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity).combined(with: .move(edge: .trailing))
                            ))
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
            } else {
                Spacer()
            }
            
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
                    
                    Button(action: {
                        onRemindersUpdated(reminders)
                    }) {
                        Text("Confirm")
                            .font(Font.buttonText1)
                            .foregroundColor(.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "1C274C"))
                            .clipShape(Capsule())
                    }
                }
                .padding(24)
            }
        }
        .background(.surface)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .sheet(isPresented: $showingAddReminderSheet) {
            AddReminderSheet(initialTime: selectedTime, isEditing: editingReminderIndex != nil) { newTime in
                if let editingIndex = editingReminderIndex {
                    // Editing existing reminder
                    reminders[editingIndex].time = newTime
                    editingReminderIndex = nil
                    isEditMode = false
                } else {
                    // Adding new reminder
                    reminders.append(ReminderItem(time: newTime, isActive: true))
                }
            }
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
}

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date
    @State private var originalTime: Date
    let onSave: (Date) -> Void
    let isEditing: Bool
    
    init(initialTime: Date = Date(), isEditing: Bool = false, onSave: @escaping (Date) -> Void) {
        self._selectedTime = State(initialValue: initialTime)
        self._originalTime = State(initialValue: initialTime)
        self.isEditing = isEditing
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image("Icon-leftArrow")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.text01)
                }
                .frame(width: 48, height: 48)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 16)
            
            // Title
            Text("Select Time")
                .font(.headlineSmallEmphasised)
                .foregroundColor(.text01)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            
            // Spacer below title
            Spacer()
                .frame(height: 16)
            
            // Time Picker
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Save/Add Button
            Button(action: {
                onSave(selectedTime)
                dismiss()
            }) {
                Text(isEditing ? "Save" : "Add")
                    .font(Font.buttonText1)
                    .foregroundColor(.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isEditing && selectedTime == originalTime ? Color.gray : Color(hex: "1C274C"))
                    .clipShape(Capsule())
            }
            .disabled(isEditing && selectedTime == originalTime)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
        }
        .background(.surface)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

#Preview {
    ReminderBottomSheet(
        onClose: {},
        onReminderSelected: { _ in },
        initialReminders: [],
        onRemindersUpdated: { _ in }
    )
} 
