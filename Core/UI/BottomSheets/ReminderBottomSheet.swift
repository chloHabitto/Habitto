import SwiftUI

struct ReminderItem: Identifiable, Codable, Equatable {
    var id = UUID()
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
        BaseBottomSheet(
            title: "Reminder",
            description: "Choose when you want to be reminded about this habit",
            onClose: onClose,
            confirmButton: {
                if reminders.isEmpty {
                    // When no reminders, open the add reminder sheet
                    showingAddReminderSheet = true
                } else {
                    // When there are reminders, save and close
                    onRemindersUpdated(reminders)
                }
            },
            confirmButtonTitle: reminders.isEmpty ? "Add a reminder" : "Confirm"
        ) {
        VStack(spacing: 0) {
            // Custom Buttons - only show when there are reminders
            if !reminders.isEmpty {
                HStack {
                    Button(isEditMode ? "Done" : "Edit") {
                        isEditMode.toggle()
                    }
                        .font(.appButtonText2)
                    .foregroundColor(.text01)
                    .frame(width: 62, height: 44)
                    
                    Spacer()
                    
                    Button(action: {
                            showingAddReminderSheet = true
                    }) {
                        Image(.iconPlus)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 48, height: 48)
                }
                .padding(.horizontal, 2)
            }
            
            // Divider under header - only show when there are reminders
            if !reminders.isEmpty {
                Divider()
                    .background(.outline3)
            }
            
            // Content area
            if !reminders.isEmpty {
                // Reminders List
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
                                            .font(.appBodyLarge)
                                        .foregroundColor(.text01)
                                    
                                    Spacer()
                                    
                                    if isEditMode {
                                        Image(systemName: "chevron.right")
                                                .font(.appLabelMedium)
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
                // No reminders state
                VStack {
                    Spacer()
                    
                    Text("No reminder")
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
                    
                    Spacer()
                }
            }
            
                Spacer()
            }
        }
        .presentationDetents([.height(500)])
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
                    Image(.iconLeftArrow)
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
                .font(.appHeadlineSmallEmphasised)
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
            HabittoButton.largeFillPrimary(
                text: isEditing ? "Save" : "Add",
                state: isEditing && selectedTime == originalTime ? .disabled : .default,
                action: {
                    onSave(selectedTime)
                    dismiss()
                }
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
        }
        .background(.surface)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
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
