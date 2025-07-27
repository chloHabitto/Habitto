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
                                    .font(.appLabelMedium)
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
                                    .font(.appLabelMedium)
                                    .foregroundColor(.primaryDim)
                            }
                        }
                        .selectionRowStyle()
                        
                        // Reminder
                        reminderSection
                        
                        // Period
                        periodSection
                        
                        // Extra spacing at bottom for better scrolling
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .background(.surface2)
                
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .font(.appBodyLarge)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit habit")
                    .font(.appHeadlineMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text("Update your habit details.")
                    .font(.appTitleSmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 0) // Let the system handle safe area
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
                Text(selectedReminder.isEmpty || selectedReminder == "No reminder" ? "Add" : selectedReminder)
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
            
            if !selectedReminder.isEmpty && selectedReminder != "No reminder" {
                Divider()
                    .background(.outline)
                    .padding(.vertical, 4)
                
                VStack(spacing: 4) {
                    HStack {
                        Text(selectedReminder)
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
        .selectionRowStyle()
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
        print("🔄 HabitEditView: saveHabit called")
        // Create updated habit with current values, preserving the original ID
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
            streak: habit.streak
        )
        // Preserve the original habit's ID
        updatedHabit.id = habit.id
        print("🔄 HabitEditView: Created updated habit - \(updatedHabit.name) with ID \(updatedHabit.id)")
        onSave(updatedHabit)
        dismiss()
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