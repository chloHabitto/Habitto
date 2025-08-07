import SwiftUI

struct HabitEditView: View {
    @FocusState private var isGoalNumberFocused: Bool
    @FocusState private var isBaselineFieldFocused: Bool
    @FocusState private var isTargetFieldFocused: Bool
    
    let habit: Habit
    let onSave: (Habit) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var habitName: String
    @State private var habitDescription: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedHabitType: HabitType
    @State private var selectedSchedule: String
    @State private var selectedReminder: String
    @State private var isReminderEnabled: Bool
    @State private var reminders: [ReminderItem]
    @State private var startDate: Date
    @State private var endDate: Date?
    
    // NEW UNIFIED APPROACH - Unified state for both habit building and breaking
    @State private var goalNumber: String = "1"
    @State private var goalUnit: String = "time"
    @State private var goalFrequency: String = "everyday"
    @State private var baselineNumber: String = "1"
    @State private var baselineUnit: String = "time"
    @State private var baselineFrequency: String = "everyday"
    @State private var targetNumber: String = "1"
    @State private var targetUnit: String = "time"
    @State private var targetFrequency: String = "everyday"
    @State private var showingGoalUnitSheet = false
    @State private var showingGoalFrequencySheet = false
    @State private var showingBaselineUnitSheet = false
    @State private var showingBaselineFrequencySheet = false
    @State private var showingTargetUnitSheet = false
    @State private var showingTargetFrequencySheet = false
    
    // Force UI updates when number changes
    @State private var uiUpdateTrigger = false
    
    // Sheet states
    @State private var showingIconSheet = false
    @State private var showingColorSheet = false
    @State private var showingScheduleSheet = false
    @State private var showingReminderSheet = false
    @State private var showingPeriodSheet = false
    
    // Focus states for text fields
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isDescriptionFieldFocused: Bool
    
    // Computed property to check if any changes have been made
    private var hasChanges: Bool {
        // Check basic fields
        let basicChanges = habitName != habit.name ||
                          habitDescription != habit.description ||
                          selectedIcon != habit.icon ||
                          selectedColor != habit.color ||
                          selectedHabitType != habit.habitType ||
                          selectedReminder != habit.reminder ||
                          reminders != habit.reminders ||
                          startDate != habit.startDate ||
                          endDate != habit.endDate
        
        // Check schedule changes (different logic for habit building vs breaking)
        let scheduleChanges: Bool
        if selectedHabitType == .formation {
            // For habit building, schedule is derived from goal frequency
            scheduleChanges = goalFrequency != habit.schedule
        } else {
            // For habit breaking, schedule is derived from baseline frequency
            scheduleChanges = baselineFrequency != habit.schedule
        }
        
        // Check unified approach fields
        var unifiedChanges = false
        
        if selectedHabitType == .formation {
            // For habit building, check goal fields
            let currentGoal = "\(goalNumber) \(pluralizedGoalUnit) per \(goalFrequency)"
            let originalGoal = habit.goal
            unifiedChanges = currentGoal != originalGoal
        } else {
            // For habit breaking, check baseline and target fields
            let currentBaseline = Int(baselineNumber) ?? 0
            let currentTarget = Int(targetNumber) ?? 0
            unifiedChanges = currentBaseline != habit.baseline || currentTarget != habit.target
        }
        
        return basicChanges || scheduleChanges || unifiedChanges
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
                    CustomTextField(placeholder: "Name", text: $habitName, isFocused: $isNameFieldFocused, showTapGesture: true)
                    
                    // Description
                    CustomTextField(placeholder: "Description (Optional)", text: $habitDescription, isFocused: $isDescriptionFieldFocused, showTapGesture: true)
                    
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
                    
                    // Goal - NEW UNIFIED APPROACH
                    if selectedHabitType == .formation {
                        UnifiedInputElement(
                            title: "Goal",
                            description: "What do you want to achieve?",
                            numberText: $goalNumber,
                            unitText: pluralizedGoalUnit,
                            frequencyText: goalFrequency,
                            isFocused: $isGoalNumberFocused,
                            isValid: isGoalValid,
                            errorMessage: "Please enter a number greater than 0",
                            onUnitTap: { showingGoalUnitSheet = true },
                            onFrequencyTap: { showingGoalFrequencySheet = true },
                            uiUpdateTrigger: uiUpdateTrigger
                        )
                    } else {
                        // Habit Breaking Form
                        VStack(spacing: 16) {
                            // Baseline - NEW UNIFIED APPROACH
                            UnifiedInputElement(
                                title: "Baseline",
                                description: "How much do you currently use?",
                                numberText: $baselineNumber,
                                unitText: pluralizedBaselineUnit,
                                frequencyText: baselineFrequency,
                                isFocused: $isBaselineFieldFocused,
                                isValid: isBaselineValid,
                                errorMessage: "Please enter a number greater than 0",
                                onUnitTap: { showingBaselineUnitSheet = true },
                                onFrequencyTap: { showingBaselineFrequencySheet = true },
                                uiUpdateTrigger: uiUpdateTrigger
                            )
                            
                            // Target - NEW UNIFIED APPROACH
                            UnifiedInputElement(
                                title: "Target",
                                description: "How much do you want to reduce to?",
                                numberText: $targetNumber,
                                unitText: pluralizedTargetUnit,
                                frequencyText: targetFrequency,
                                isFocused: $isTargetFieldFocused,
                                isValid: isTargetValid,
                                errorMessage: "Please enter a number greater than or equal to 0",
                                onUnitTap: { showingTargetUnitSheet = true },
                                onFrequencyTap: { showingTargetFrequencySheet = true },
                                uiUpdateTrigger: uiUpdateTrigger
                            )
                        }
                    }
                    
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
            }, initialSchedule: selectedSchedule)
        }
        
        // NEW UNIFIED APPROACH - Frequency sheets
        .sheet(isPresented: $showingGoalUnitSheet) {
            UnitBottomSheet(
                onClose: { showingGoalUnitSheet = false },
                onUnitSelected: { selectedUnit in
                    goalUnit = selectedUnit
                    showingGoalUnitSheet = false
                },
                currentUnit: goalUnit
            )
        }
        .sheet(isPresented: $showingGoalFrequencySheet) {
            ScheduleBottomSheet(
                onClose: { showingGoalFrequencySheet = false },
                onScheduleSelected: { selectedSchedule in
                    goalFrequency = selectedSchedule.lowercased()
                    showingGoalFrequencySheet = false
                },
                initialSchedule: goalFrequency
            )
        }
        .sheet(isPresented: $showingBaselineUnitSheet) {
            UnitBottomSheet(
                onClose: { showingBaselineUnitSheet = false },
                onUnitSelected: { selectedUnit in
                    baselineUnit = selectedUnit
                    showingBaselineUnitSheet = false
                },
                currentUnit: baselineUnit
            )
        }
        .sheet(isPresented: $showingBaselineFrequencySheet) {
            ScheduleBottomSheet(
                onClose: { showingBaselineFrequencySheet = false },
                onScheduleSelected: { selectedSchedule in
                    baselineFrequency = selectedSchedule.lowercased()
                    showingBaselineFrequencySheet = false
                },
                initialSchedule: baselineFrequency
            )
        }
        .sheet(isPresented: $showingTargetUnitSheet) {
            UnitBottomSheet(
                onClose: { showingTargetUnitSheet = false },
                onUnitSelected: { selectedUnit in
                    targetUnit = selectedUnit
                    showingTargetUnitSheet = false
                },
                currentUnit: targetUnit
            )
        }
        .sheet(isPresented: $showingTargetFrequencySheet) {
            ScheduleBottomSheet(
                onClose: { showingTargetFrequencySheet = false },
                onScheduleSelected: { selectedSchedule in
                    targetFrequency = selectedSchedule.lowercased()
                    showingTargetFrequencySheet = false
                },
                initialSchedule: targetFrequency
            )
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
                },
                onRemoveEndDate: nil,
                onResetStartDate: {
                    startDate = Date()
                    showingPeriodSheet = false
                }
            )
        }
        .onAppear {
            // Initialize values for the new unified approach
            if selectedHabitType == .formation {
                // NEW UNIFIED APPROACH - Parse existing goal into number, unit, and frequency
                let goalComponents = habit.goal.components(separatedBy: " ")
                if goalComponents.count >= 4 && goalComponents[2] == "per" {
                    goalNumber = goalComponents[0]
                    goalUnit = goalComponents[1]
                    goalFrequency = goalComponents[3]
                } else if goalComponents.count >= 2 {
                    // Fallback for old format
                    goalNumber = goalComponents[0]
                    goalUnit = goalComponents[1]
                    goalFrequency = "everyday"
                } else {
                    // Fallback for very old format
                    goalNumber = "1"
                    goalUnit = "time"
                    goalFrequency = "everyday"
                }
            } else {
                // NEW UNIFIED APPROACH - Habit Breaking
                baselineNumber = String(habit.baseline)
                targetNumber = String(habit.target)
                
                let goalComponents = habit.goal.components(separatedBy: " ")
                if goalComponents.count >= 4 && goalComponents[2] == "per" {
                    targetUnit = goalComponents[1]
                    targetFrequency = goalComponents[3]
                    baselineUnit = targetUnit // Assume same unit for baseline
                    baselineFrequency = targetFrequency // Assume same frequency for baseline
                } else if goalComponents.count >= 2 {
                    // Fallback for old format
                    targetUnit = goalComponents[1]
                    targetFrequency = "everyday"
                    baselineUnit = targetUnit
                    baselineFrequency = "everyday"
                } else {
                    // Fallback for very old format
                    targetUnit = "time"
                    targetFrequency = "everyday"
                    baselineUnit = "time"
                    baselineFrequency = "everyday"
                }
            }
        }
        .onChange(of: goalNumber) { oldValue, newValue in
            // Force UI update when goal number changes
            uiUpdateTrigger.toggle()
        }
        .onChange(of: baselineNumber) { _, _ in
            // Force UI update when baseline changes
            uiUpdateTrigger.toggle()
        }
        .onChange(of: targetNumber) { _, _ in
            // Force UI update when target changes
            uiUpdateTrigger.toggle()
        }
        .overlay(
            // Custom Done button overlay for number keyboard
            VStack {
                Spacer()
                if isGoalNumberFocused || isBaselineFieldFocused || isTargetFieldFocused {
                    HStack {
                        Spacer()
                        HabittoButton.mediumFillPrimaryHugging(text: "Done") {
                            isGoalNumberFocused = false
                            isBaselineFieldFocused = false
                            isTargetFieldFocused = false
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        )
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
    
    // MARK: - Helper Functions
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    // Helper function to handle pluralization for units
    private func pluralizedUnit(_ count: Int, unit: String) -> String {
        if unit == "time" || unit == "times" {
            return count == 1 ? "time" : "times"
        }
        return unit
    }
    
    // NEW Unified computed properties
    private var pluralizedGoalUnit: String {
        let number = Int(goalNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: goalUnit)
    }
    
    private var pluralizedBaselineUnit: String {
        let number = Int(baselineNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: baselineUnit)
    }
    
    private var pluralizedTargetUnit: String {
        let number = Int(targetNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: targetUnit)
    }
    
    // NEW Unified computed properties for validation
    private var isGoalValid: Bool {
        let number = Int(goalNumber) ?? 0
        return number > 0
    }
    
    private var isBaselineValid: Bool {
        let number = Int(baselineNumber) ?? 0
        return number > 0
    }
    
    private var isTargetValid: Bool {
        let number = Int(targetNumber) ?? 0
        return number >= 0  // Allow 0 for reduction goal in habit breaking
    }
    
    // Overall form validation
    private var isFormValid: Bool {
        if selectedHabitType == .formation {
            return isGoalValid
        } else {
            return isBaselineValid && isTargetValid
        }
    }
    
    // MARK: - NEW Unified Input Element
    @ViewBuilder
    private func UnifiedInputElement(
        title: String,
        description: String,
        numberText: Binding<String>,
        unitText: String,
        frequencyText: String,
        isFocused: FocusState<Bool>.Binding,
        isValid: Bool,
        errorMessage: String,
        onUnitTap: @escaping () -> Void,
        onFrequencyTap: @escaping () -> Void,
        uiUpdateTrigger: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
            }
            
            Text(description)
                .font(.appBodyMedium)
                .foregroundColor(.text05)
                .padding(.bottom, 12)
            
            HStack(spacing: 4) {
                // Number input field - smaller width
                TextField("1", text: numberText)
                    .font(.appBodyLarge)
                    .foregroundColor(.text01)
                    .accentColor(.text01)
                    .keyboardType(.numberPad)
                    .focused(isFocused)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .inputFieldStyle()
                
                // Unit selector button - smaller width
                Button(action: onUnitTap) {
                    HStack {
                        Text(unitText)
                            .font(.appBodyLarge)
                            .foregroundColor(isValid ? .text04 : .text06)
                            .id(uiUpdateTrigger) // Force re-render when trigger changes
                        Image(systemName: "chevron.right")
                            .font(.appLabelSmall)
                            .foregroundColor(.primaryDim)
                    }
                    .frame(width: 70)
                    .inputFieldStyle()
                }
                .buttonStyle(PlainButtonStyle())
                
                // "/" separator
                Text("/")
                    .font(.appBodyLarge)
                    .foregroundColor(.text04)
                    .frame(width: 12)
                
                // Frequency selector button - larger width for one-line text
                Button(action: onFrequencyTap) {
                    HStack {
                        Text(frequencyText)
                            .font(.appBodyLarge)
                            .foregroundColor(isValid ? .text04 : .text06)
                            .id(uiUpdateTrigger) // Force re-render when trigger changes
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.right")
                            .font(.appLabelSmall)
                            .foregroundColor(.primaryDim)
                    }
                    .frame(maxWidth: .infinity)
                    .inputFieldStyle()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 4)
            
            // Warning message for invalid input
            if !isValid {
                ErrorMessage(message: errorMessage)
                    .padding(.top, 4)
            }
        }
        .selectionRowStyle()
    }
    
    // MARK: - Custom TextField Component (same as CreateHabitStep1View)
    private func CustomTextField(
        placeholder: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding? = nil,
        showTapGesture: Bool = false
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.appBodyLarge)
            .foregroundColor(.text01)
            .textFieldStyle(PlainTextFieldStyle())
            .submitLabel(.done)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.outline, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .modifier(FocusModifier(isFocused: isFocused, showTapGesture: showTapGesture))
    }
    
    // Custom modifier to handle focus and tap gesture (same as CreateHabitStep1View)
    private struct FocusModifier: ViewModifier {
        let isFocused: FocusState<Bool>.Binding?
        let showTapGesture: Bool
        
        func body(content: Content) -> some View {
            if let isFocused = isFocused {
                content
                    .focused(isFocused)
                    .onTapGesture {
                        isFocused.wrappedValue = true
                    }
            } else {
                content
                    .onTapGesture {
                        // For fields without focus binding, just ensure they can be tapped
                        // SwiftUI will handle focus automatically
                    }
            }
        }
    }
    

    
    // MARK: - Habit Type Section
    private var habitTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Type")
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            HStack(spacing: 12) {
                // Habit Building button
                Button(action: {
                    selectedHabitType = .formation
                }) {
                    HStack(spacing: 8) {
                        if selectedHabitType == .formation {
                            Image(systemName: "checkmark")
                                .font(.appLabelSmallEmphasised)
                                .foregroundColor(.onPrimary)
                        }
                        Text("Habit Building")
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
        var updatedHabit: Habit
        
        if selectedHabitType == .formation {
            // NEW UNIFIED APPROACH - Habit Building
            let goalNumberInt = Int(goalNumber) ?? 1
            let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: goalUnit)
            let goalString = "\(goalNumber) \(pluralizedUnit) per \(goalFrequency)"
            
            // For habit building, schedule is derived from goal frequency
            let scheduleString = goalFrequency
            
            updatedHabit = Habit(
                name: habitName,
                description: habitDescription,
                icon: selectedIcon,
                color: selectedColor,
                habitType: selectedHabitType,
                schedule: scheduleString,
                goal: goalString,
                reminder: isReminderEnabled ? selectedReminder : "",
                startDate: startDate,
                endDate: endDate,
                isCompleted: habit.isCompleted,
                streak: habit.streak,
                reminders: reminders
            )
        } else {
            // NEW UNIFIED APPROACH - Habit Breaking
            let targetInt = Int(targetNumber) ?? 1
            let targetPluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
            let goalString = "\(targetNumber) \(targetPluralizedUnit) per \(targetFrequency)"
            
            // For habit breaking, schedule is derived from baseline frequency
            let scheduleString = baselineFrequency
            
            updatedHabit = Habit(
                name: habitName,
                description: habitDescription,
                icon: selectedIcon,
                color: selectedColor,
                habitType: selectedHabitType,
                schedule: scheduleString,
                goal: goalString,
                reminder: isReminderEnabled ? selectedReminder : "",
                startDate: startDate,
                endDate: endDate,
                isCompleted: habit.isCompleted,
                streak: habit.streak,
                reminders: reminders,
                baseline: Int(baselineNumber) ?? 0,
                target: Int(targetNumber) ?? 0
            )
        }
        
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