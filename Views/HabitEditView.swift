import SwiftUI

struct HabitEditView: View {
    let habit: Habit
    let onSave: (Habit) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Editable properties
    @State private var habitName: String
    @State private var habitDescription: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedHabitType: HabitType
    @State private var selectedSchedule: String
    @State private var selectedGoal: String
    @State private var selectedReminder: String
    @State private var isReminderEnabled: Bool
    @State private var startDate: Date
    @State private var endDate: Date?
    
    // Sheet states
    @State private var showingIconSheet = false
    @State private var showingColorSheet = false
    @State private var showingScheduleSheet = false
    @State private var showingGoalSheet = false
    @State private var showingReminderSheet = false
    @State private var showingPeriodSheet = false
    
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
        self._startDate = State(initialValue: habit.startDate)
        self._endDate = State(initialValue: habit.endDate)
    }
    
    var body: some View {
        NavigationView {
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
                        inputFieldSection(
                            title: "Description",
                            placeholder: "Description (Optional)",
                            text: $habitDescription
                        )
                        
                        // Icon Selection
                        selectionRow(
                            title: "Icon",
                            value: getIconDisplayName(selectedIcon),
                            icon: selectedIcon,
                            color: selectedColor
                        ) {
                            showingIconSheet = true
                        }
                        
                        // Color Selection
                        selectionRow(
                            title: "Colour",
                            value: getColorDisplayName(selectedColor),
                            color: selectedColor
                        ) {
                            showingColorSheet = true
                        }
                        
                        // Habit Type
                        habitTypeSection
                        
                        // Schedule
                        selectionRow(
                            title: "Schedule",
                            value: selectedSchedule
                        ) {
                            showingScheduleSheet = true
                        }
                        
                        // Goal
                        selectionRow(
                            title: "Goal",
                            value: selectedGoal
                        ) {
                            showingGoalSheet = true
                        }
                        
                        // Reminder
                        reminderSection
                        
                        // Period
                        periodSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Space for save button
                }
                
                // Save Button
                saveButton
            }
            .background(.surface2)
            .navigationBarHidden(true)
        }
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
        HStack {
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .font(.appBodyMedium)
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.surface)
    }
    
    // MARK: - Input Field Section
    private func inputFieldSection(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appBodyMedium)
                .foregroundColor(.text05)
            
            TextField(placeholder, text: text)
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.outline, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Selection Row
    private func selectionRow(title: String, value: String, icon: String? = nil, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let icon = icon {
                        if icon.hasPrefix("Icon-") {
                            Image(icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(color ?? .primary)
                        } else {
                            Text(icon)
                                .font(.system(size: 16))
                        }
                    }
                    
                    if let color = color, icon == nil {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                    }
                    
                    Text(value)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.text05)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.outline, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Habit Type Section
    private var habitTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Type")
                .font(.appBodyMedium)
                .foregroundColor(.text05)
            
            HStack(spacing: 8) {
                Button("✓ Habit Formation") {
                    selectedHabitType = .formation
                }
                .font(.appBodyMedium)
                .foregroundColor(selectedHabitType == .formation ? .onPrimary : .text05)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedHabitType == .formation ? .primary : .surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Button("Habit Breaking") {
                    selectedHabitType = .breaking
                }
                .font(.appBodyMedium)
                .foregroundColor(selectedHabitType == .breaking ? .onPrimary : .text05)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedHabitType == .breaking ? .primary : .surfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Reminder Section
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder")
                .font(.appBodyMedium)
                .foregroundColor(.text05)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Add")
                        .font(.appBodyMedium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.text05)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.outline, lineWidth: 1)
                )
                .onTapGesture {
                    showingReminderSheet = true
                }
                
                HStack {
                    Text(selectedReminder.isEmpty ? "9:41 AM" : selectedReminder)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isReminderEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.outline, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Period Section
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Period")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                
                Spacer()
                
                activeStatusTag
            }
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.appBodySmall)
                        .foregroundColor(.text05)
                    
                    Text(formatDate(startDate))
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.outline, lineWidth: 1)
                )
                .onTapGesture {
                    showingPeriodSheet = true
                }
                
                Text("-")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text05)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date")
                        .font(.appBodySmall)
                        .foregroundColor(.text05)
                    
                    Text(endDate == nil ? "Not Selected" : formatDate(endDate!))
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.outline, lineWidth: 1)
                )
                .onTapGesture {
                    showingPeriodSheet = true
                }
            }
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        VStack {
            Spacer()
            
            HabittoButton.largeFillPrimary(
                text: "Save",
                action: {
                    // Create updated habit with current values
                    let updatedHabit = Habit(
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
                        streak: habit.streak
                    )
                    onSave(updatedHabit)
                    dismiss()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.surface2)
    }
    
    // MARK: - Active Status Tag
    private var activeStatusTag: some View {
        Text("Active")
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - Helper Functions
    private func getIconDisplayName(_ icon: String) -> String {
        if icon.hasPrefix("Icon-") {
            return icon.replacingOccurrences(of: "Icon-", with: "")
        }
        return icon
    }
    
    private func getColorDisplayName(_ color: Color) -> String {
        // This would need to be implemented based on your color system
        return "Navy"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd yyyy"
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