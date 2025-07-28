import SwiftUI

struct HabitEditView: View {
    let habit: Habit
    let onSave: (Habit) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var habitName: String
    @State private var habitDescription: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedHabitType: HabitType
    @State private var selectedSchedule: String
    @State private var selectedGoal: String
    @State private var selectedReminder: String
    @State private var isReminderEnabled: Bool
    @State private var reminders: [ReminderItem]
    @State private var startDate: Date
    @State private var endDate: Date?
    
    // Sheet states
    @State private var showingIconSheet = false
    @State private var showingColorSheet = false
    @State private var showingScheduleSheet = false
    @State private var showingGoalSheet = false
    @State private var showingReminderSheet = false
    @State private var showingPeriodSheet = false
    
    // Computed property to check if any changes have been made
    private var hasChanges: Bool {
        return habitName != habit.name ||
               habitDescription != habit.description ||
               selectedIcon != habit.icon ||
               selectedColor != habit.color ||
               selectedHabitType != habit.habitType ||
               selectedSchedule != habit.schedule ||
               selectedGoal != habit.goal ||
               selectedReminder != habit.reminder ||
               reminders != habit.reminders ||
               startDate != habit.startDate ||
               endDate != habit.endDate
    }
    
    init(habit: Habit, onSave: @escaping (Habit) -> Void) {
        self.habit = habit
        self.onSave = onSave
        
        self._habitName = State(initialValue: habit.name)
        self._habitDescription = State(initialValue: habit.description)
        self._selectedIcon = State(initialValue: habit.icon)
        self._selectedColor = State(initialValue: habit.color)
        self._selectedHabitType = State(initialValue: habit.habitType)
        self._selectedSchedule = State(initialValue: habit.schedule)
        self._selectedGoal = State(initialValue: habit.goal)
        self._selectedReminder = State(initialValue: habit.reminder)
        self._isReminderEnabled = State(initialValue: !habit.reminder.isEmpty)
        self._reminders = State(initialValue: habit.reminders)
        self._startDate = State(initialValue: habit.startDate)
        self._endDate = State(initialValue: habit.endDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            topNavigationBar
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Habit Name
                    inputFieldSection(
                        title: "Habit Name",
                        placeholder: "Enter habit name",
                        text: $habitName
                    )
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.appBodyMedium)
                            .foregroundColor(.text05)
                        
                        TextField("Description (Optional)", text: $habitDescription, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.appBodyLarge)
                            .foregroundColor(.text01)
                            .accentColor(.text01)
                            .inputFieldStyle()
                            .contentShape(Rectangle())
                            .frame(minHeight: 48)
                            .submitLabel(.done)
                    }
                    
                    // Icon Selection
                    Button(action: {
                        showingIconSheet = true
                    }) {
                        HStack {
                            Text("Icon")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            Spacer()
                            
                            Text(getIconDisplayName(selectedIcon))
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                            
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                    }
                    .selectionRowStyle()
                    
                    // Color Selection
                    Button(action: {
                        showingColorSheet = true
                    }) {
                        HStack {
                            Text("Colour")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 16, height: 16)
                                Text(getColorDisplayName(selectedColor))
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text04)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                    }
                    .selectionRowStyle()
                    
                    // Habit Type
                    habitTypeSection
                    
                    // Schedule
                    Button(action: {
                        showingScheduleSheet = true
                    }) {
                        HStack {
                            Text("Schedule")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            Spacer()
                            
                            Text(selectedSchedule)
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                            
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                    }
                    .selectionRowStyle()
                    
                    // Goal
                    Button(action: {
                        showingGoalSheet = true
                    }) {
                        HStack {
                            Text("Goal")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            Spacer()
                            
                            Text(selectedGoal)
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                            
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                    }
                    .selectionRowStyle()
                    
                    // Reminder Section
                    reminderSection
                    
                    // Period Section
                    periodSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, 100) // Add bottom padding to account for fixed button
            }
            .background(.surface2)
            
            // Fixed bottom button dock
            VStack(spacing: 0) {
                Divider()
                    .background(.outline)
                
                saveButton
            }
            .background(.surface2)
        }
        .background(.surface2)
        .sheet(isPresented: $showingIconSheet) {
            IconBottomSheet(selectedIcon: $selectedIcon, onClose: { showingIconSheet = false })
        }
        .sheet(isPresented: $showingColorSheet) {
            ColorBottomSheet(onClose: { showingColorSheet = false }, onColorSelected: { color in
                selectedColor = color
                showingColorSheet = false
            })
        }
        .sheet(isPresented: $showingScheduleSheet) {
            ScheduleBottomSheet(onClose: { showingScheduleSheet = false }, onScheduleSelected: { schedule in
                selectedSchedule = schedule
                showingScheduleSheet = false
            })
        }
        .sheet(isPresented: $showingGoalSheet) {
            GoalBottomSheet(onClose: { showingGoalSheet = false }, onGoalSelected: { goal in
                selectedGoal = goal
                showingGoalSheet = false
            })
        }
        .sheet(isPresented: $showingReminderSheet) {
            ReminderBottomSheet(onClose: { showingReminderSheet = false }, onReminderSelected: { reminder in
                selectedReminder = reminder
                showingReminderSheet = false
            }, onRemindersUpdated: { _ in })
        }
        .sheet(isPresented: $showingPeriodSheet) {
            PeriodBottomSheet(
                isSelectingStartDate: true,
                startDate: startDate,
                onStartDateSelected: { date in
                    startDate = date
                    showingPeriodSheet = false
                },
                onEndDateSelected: { date in
                    endDate = date
                    showingPeriodSheet = false
                }
            )
        }
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit habit")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.appBodyLarge)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
        .padding(.top, 0)
    }
    
    // MARK: - Input Field Section
    private func inputFieldSection(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appBodyMedium)
                .foregroundColor(.text05)
            
            TextField(placeholder, text: text)
                .font(.appBodyLarge)
                .foregroundColor(.text01)
                .accentColor(.text01)
                .inputFieldStyle()
                .contentShape(Rectangle())
                .frame(minHeight: 48)
                .submitLabel(.done)
        }
    }
    
    // MARK: - Habit Type Section
    private var habitTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Type")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            HStack(spacing: 12) {
                // Habit Formation button
                Button(action: {
                    selectedHabitType = .formation
                }) {
                    HStack(spacing: 8) {
                        if selectedHabitType == .formation {
                            Image(systemName: "checkmark")
                                .font(.appLabelSmallEmphasised)
                                .foregroundColor(.onPrimary)
                        }
                        Text("Habit Formation")
                            .font(selectedHabitType == .formation ? .appLabelLargeEmphasised : .appLabelLarge)
                            .foregroundColor(selectedHabitType == .formation ? .onPrimary : .onPrimaryContainer)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(selectedHabitType == .formation ? .primary : .primaryContainer)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.outline, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity)
                
                // Habit Breaking button
                Button(action: {
                    selectedHabitType = .breaking
                }) {
                    HStack(spacing: 8) {
                        if selectedHabitType == .breaking {
                            Image(systemName: "checkmark")
                                .font(.appLabelSmallEmphasised)
                                .foregroundColor(.onPrimary)
                        }
                        Text("Habit Breaking")
                            .font(selectedHabitType == .breaking ? .appLabelLargeEmphasised : .appLabelLarge)
                            .foregroundColor(selectedHabitType == .breaking ? .onPrimary : .onPrimaryContainer)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(selectedHabitType == .breaking ? .primary : .primaryContainer)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.outline, lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.outline, lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
    
    // MARK: - Reminder Section
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reminder")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Spacer()
                Text(reminders.isEmpty ? "Add" : "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")")
                    .font(.appBodyLarge)
                    .foregroundColor(.text04)
                Image(systemName: "chevron.right")
                    .font(.appLabelMedium)
                    .foregroundColor(.primaryDim)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingReminderSheet = true
            }
            
            if !reminders.isEmpty {
                Divider()
                    .background(.outline)
                    .padding(.vertical, 4)
                
                VStack(spacing: 4) {
                    ForEach(reminders.filter { $0.isActive }) { reminder in
                        HStack {
                            Text(formatTime(reminder.time))
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                            Spacer()
                            Text("Active")
                                .font(.appLabelSmall)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.secondaryContainer)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .selectionRowStyle()
        .sheet(isPresented: $showingReminderSheet) {
            ReminderBottomSheet(
                onClose: { showingReminderSheet = false },
                onReminderSelected: { selectedReminder in
                    // Keep for backward compatibility
                    showingReminderSheet = false
                },
                initialReminders: reminders,
                onRemindersUpdated: { updatedReminders in
                    reminders = updatedReminders
                    let activeReminders = updatedReminders.filter { $0.isActive }
                    if !activeReminders.isEmpty {
                        selectedReminder = "\(activeReminders.count) reminder\(activeReminders.count == 1 ? "" : "s")"
                    } else {
                        selectedReminder = "No reminder"
                    }
                    showingReminderSheet = false
                }
            )
        }
    }
    
    // MARK: - Period Section
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Period")
                .font(.appTitleMedium)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // Start Date
                Button(action: {
                    showingPeriodSheet = true
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Date")
                            .font(.appBodyMedium)
                            .foregroundColor(.text05)
                        Text(formatDate(startDate))
                            .font(.appBodyLarge)
                            .foregroundColor(.text04)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .inputFieldStyle()
                    }
                }
                .frame(maxWidth: .infinity)
                
                // End Date
                Button(action: {
                    showingPeriodSheet = true
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End Date")
                            .font(.appBodyMedium)
                            .foregroundColor(.text05)
                        Text(endDate == nil ? "Not Selected" : formatDate(endDate!))
                            .font(.appBodyLarge)
                            .foregroundColor(.text04)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .inputFieldStyle()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .selectionRowStyle()
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        HabittoButton.largeFillPrimary(
            text: "Save",
            action: saveHabit
        )
        .disabled(!hasChanges)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.surface2)
    }
    
    // MARK: - Save Function
    private func saveHabit() {
        var updatedHabit = Habit(
            name: habitName,
            description: habitDescription,
            icon: selectedIcon,
            color: selectedColor,
            habitType: selectedHabitType,
            schedule: selectedSchedule,
            goal: selectedGoal,
            reminder: isReminderEnabled ? selectedReminder : "",
            startDate: startDate,
            endDate: endDate,
            isCompleted: habit.isCompleted,
            streak: habit.streak,
            reminders: reminders
        )
        updatedHabit.id = habit.id
        
        // Update notifications for the habit
        NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: reminders)
        
        onSave(updatedHabit)
        dismiss()
    }
    
    // MARK: - Helper Functions
    private func getIconDisplayName(_ icon: String) -> String {
        if icon.hasPrefix("Icon-") {
            return icon.replacingOccurrences(of: "Icon-", with: "")
        }
        return icon
    }
    
    private func getColorDisplayName(_ color: Color) -> String {
        // Map colors to display names
        switch color {
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .orange:
            return "Orange"
        case .red:
            return "Red"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        case .yellow:
            return "Yellow"
        case .mint:
            return "Mint"
        case .teal:
            return "Teal"
        case .indigo:
            return "Indigo"
        case .brown:
            return "Brown"
        default:
            return "Custom"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HabitEditView(habit: Habit(
        name: "Read a book",
        description: "Read for 30 minutes",
        icon: "📚",
        color: .blue,
        habitType: .formation,
        schedule: "Every 2 days",
        goal: "1 time a day",
        reminder: "9:00 AM",
        startDate: Date(),
        endDate: nil,
        isCompleted: false,
        streak: 5
    ), onSave: { _ in })
} 