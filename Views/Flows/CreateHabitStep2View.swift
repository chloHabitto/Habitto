import SwiftUI

struct CreateHabitStep2View: View {
    @FocusState private var isGoalNumberFocused: Bool
    @FocusState private var isBaselineFieldFocused: Bool
    @FocusState private var isTargetFieldFocused: Bool
    let step1Data: (String, String, String, Color, HabitType)
    let habitToEdit: Habit?
    let goBack: () -> Void
    let onSave: (Habit) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
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
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    @State private var schedule: String = "Everyday"
    @State private var goalNumber: String = "1"
    @State private var goalUnit: String = "times"
    @State private var reminder: String = "No reminder"
    @State private var reminders: [ReminderItem] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var showingScheduleSheet = false
    @State private var showingUnitSheet = false
    @State private var showingReminderSheet = false
    @State private var showingStartDateSheet = false
    @State private var showingEndDateSheet = false
    
    // Habit Breaking specific state
    @State private var baseline: String = ""
    @State private var target: String = ""
    @State private var baselineUnit: String = "times"
    @State private var targetUnit: String = "times"
    @State private var showingBaselineUnitSheet = false
    @State private var showingTargetUnitSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                CreateHabitHeader(
                    stepNumber: 2,
                    onCancel: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 16) {
                                if step1Data.4 == .formation {
            // Habit Building Form
            habitBuildingForm
                        } else {
                            // Habit Breaking Form
                            habitBreakingForm
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Add padding to account for fixed button
                }
                .frame(maxHeight: geometry.size.height - 120) // Reserve space for buttons
                .onTapGesture {
                    // Fix for gesture recognition issues with ScrollView
                }
                
                Spacer()
                
                // Bottom Buttons - Fixed at bottom
                HStack(spacing: 12) {
                    // Back Button
                    Button(action: {
                        goBack()
                    }) {
                        Image("Icon-leftArrow")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.onPrimaryContainer)
                            .frame(width: 48, height: 48)
                            .background(.primaryContainer)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        let newHabit: Habit
                        
                        if step1Data.4 == .formation {
                            let goalString = "\(goalNumber) \(goalUnit)"
                            newHabit = Habit(
                                name: step1Data.0,
                                description: step1Data.1,
                                icon: step1Data.2,
                                color: step1Data.3,
                                habitType: step1Data.4,
                                schedule: schedule,
                                goal: goalString,
                                reminder: reminder,
                                startDate: startDate,
                                endDate: endDate,
                                reminders: reminders
                            )
                        } else {
                            // Habit Breaking
                            let goalString = "\(target) \(targetUnit)"
                            newHabit = Habit(
                                name: step1Data.0,
                                description: step1Data.1,
                                icon: step1Data.2,
                                color: step1Data.3,
                                habitType: step1Data.4,
                                schedule: schedule,
                                goal: goalString,
                                reminder: reminder,
                                startDate: startDate,
                                endDate: endDate,
                                reminders: reminders,
                                baseline: Int(baseline) ?? 0,
                                target: Int(target) ?? 0
                            )
                        }
                        
                        // Schedule notifications for the new habit
                        NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
                        
                        onSave(newHabit)
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.appButtonText1)
                            .foregroundColor(.white)
                            .frame(width: UIScreen.main.bounds.width * 0.5)
                            .padding(.vertical, 16)
                            .background(step1Data.3)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(.surface2) // Add background to ensure buttons are visible
            }
            .ignoresSafeArea(.keyboard) // Prevent keyboard from affecting button position
        }
        .background(.surface2)
        .navigationBarHidden(true)
        .keyboardHandling(dismissOnTapOutside: true, showDoneButton: true)
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
        .sheet(isPresented: $showingScheduleSheet) {
            ScheduleBottomSheet(
                onClose: { showingScheduleSheet = false },
                onScheduleSelected: { selectedSchedule in
                    schedule = selectedSchedule
                    showingScheduleSheet = false
                }
            )
        }
        .sheet(isPresented: $showingUnitSheet) {
            UnitBottomSheet(
                onClose: { showingUnitSheet = false },
                onUnitSelected: { selectedUnit in
                    goalUnit = selectedUnit
                    showingUnitSheet = false
                },
                currentUnit: goalUnit
            )
        }
        .sheet(isPresented: $showingReminderSheet) {
            ReminderBottomSheet(
                onClose: { showingReminderSheet = false },
                onReminderSelected: { selectedReminder in
                    reminder = selectedReminder
                    showingReminderSheet = false
                },
                initialReminders: reminders,
                onRemindersUpdated: { updatedReminders in
                    reminders = updatedReminders
                    let activeReminders = updatedReminders.filter { $0.isActive }
                    if !activeReminders.isEmpty {
                        reminder = "\(activeReminders.count) reminder\(activeReminders.count == 1 ? "" : "s")"
                    } else {
                        reminder = "No reminder"
                    }
                    showingReminderSheet = false
                }
            )
        }
        .sheet(isPresented: $showingStartDateSheet) {
            PeriodBottomSheet(
                isSelectingStartDate: true,
                startDate: startDate,
                initialDate: startDate,
                onStartDateSelected: { selectedDate in
                    startDate = selectedDate
                    showingStartDateSheet = false
                },
                onEndDateSelected: { selectedDate in
                    // This should never be called for start date sheet
                },
                onRemoveEndDate: nil,
                onResetStartDate: {
                    startDate = Date()
                    showingStartDateSheet = false
                }
            )
        }
        .sheet(isPresented: $showingEndDateSheet) {
            PeriodBottomSheet(
                isSelectingStartDate: false,
                startDate: startDate,
                initialDate: endDate ?? Date(),
                onStartDateSelected: { selectedDate in
                    // This should never be called for end date sheet
                },
                onEndDateSelected: { selectedDate in
                    endDate = selectedDate
                    showingEndDateSheet = false
                },
                onRemoveEndDate: {
                    endDate = nil
                    showingEndDateSheet = false
                },
                onResetStartDate: nil
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
        .onAppear {
            // Initialize values if editing
            if let habit = habitToEdit {
                schedule = habit.schedule
                
                if habit.habitType == .formation {
                    // Parse existing goal into number and unit
                    let goalComponents = habit.goal.components(separatedBy: " ")
                    if goalComponents.count >= 2 {
                        goalNumber = goalComponents[0]
                        goalUnit = goalComponents[1]
                    } else {
                        // Fallback for old format
                        goalNumber = "1"
                        goalUnit = "times"
                    }
                } else {
                    // Habit Breaking
                    baseline = String(habit.baseline)
                    target = String(habit.target)
                    let goalComponents = habit.goal.components(separatedBy: " ")
                    if goalComponents.count >= 2 {
                        targetUnit = goalComponents[1]
                    }
                }
                
                reminder = habit.reminder
                reminders = habit.reminders
                startDate = habit.startDate
                endDate = habit.endDate
            }
        }
    }
    
    // MARK: - Habit Building Form
    @ViewBuilder
    private var habitBuildingForm: some View {
        VStack(spacing: 16) {
            // Schedule
                        SelectionRow(
                            title: "Schedule",
                            value: schedule,
                            action: { showingScheduleSheet = true }
                        )
                        
                        // Goal
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Goal")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                            
                            HStack(spacing: 12) {
                                // Number input field
                                TextField("1", text: $goalNumber)
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text04)
                                    .accentColor(.text01)
                                    .keyboardType(.numberPad)
                                    .focused($isGoalNumberFocused)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .inputFieldStyle()
                                
                                // Unit selector button
                                Button(action: {
                                    showingUnitSheet = true
                                }) {
                                    HStack {
                                        Text(goalUnit)
                                            .font(.appBodyLarge)
                                            .foregroundColor(.text04)
                                        Image(systemName: "chevron.right")
                                            .font(.appLabelSmall)
                                            .foregroundColor(.primaryDim)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .inputFieldStyle()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .selectionRowStyle()
                        
                        // Reminder
                        VStack(alignment: .leading, spacing: 8) {
                            SelectionRow(
                                title: "Reminder",
                                value: reminders.isEmpty ? "Add" : "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")",
                                action: { showingReminderSheet = true }
                            )
                            
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
                        
                        // Period
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Period")
                                .font(.appTitleMedium)
                                .foregroundColor(.primary)
                
                            HStack(spacing: 12) {
                                // Start Date
                                Button(action: {
                        showingStartDateSheet = true
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Start Date")
                                            .font(.appBodyMedium)
                                            .foregroundColor(.text05)
                                        Text(isToday(startDate) ? "Today" : formatDate(startDate))
                                            .font(.appBodyLarge)
                                            .foregroundColor(.text04)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .inputFieldStyle()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // End Date
                                Button(action: {
                        showingEndDateSheet = true
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
    }
    
    // MARK: - Habit Breaking Form
    @ViewBuilder
    private var habitBreakingForm: some View {
        VStack(spacing: 16) {
            // Schedule
            SelectionRow(
                title: "Schedule",
                value: schedule,
                action: { showingScheduleSheet = true }
            )
            
            // Baseline
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Baseline")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("On average, how often do you do this per day/week?")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                
                HStack(spacing: 12) {
                    // Number input field
                    TextField("10", text: $baseline)
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
                        .accentColor(.text01)
                        .keyboardType(.numberPad)
                        .focused($isBaselineFieldFocused)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .inputFieldStyle()
                    
                    // Unit selector button
                    Button(action: {
                        showingBaselineUnitSheet = true
                    }) {
                        HStack {
                            Text(baselineUnit)
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                        .frame(maxWidth: .infinity)
                        .inputFieldStyle()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .selectionRowStyle()
            
            // Target
            VStack(alignment: .leading, spacing: 12) {
                Text("Reduction Goal")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("What's your first goal?")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                
                HStack(spacing: 12) {
                    // Number input field
                    TextField("5", text: $target)
                        .font(.appBodyLarge)
                        .foregroundColor(.text04)
                        .accentColor(.text01)
                        .keyboardType(.numberPad)
                        .focused($isTargetFieldFocused)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .inputFieldStyle()
                    
                    // Unit selector button
                    Button(action: {
                        showingTargetUnitSheet = true
                    }) {
                        HStack {
                            Text(targetUnit)
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                        .frame(maxWidth: .infinity)
                        .inputFieldStyle()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .selectionRowStyle()
            
            // Reminder
            VStack(alignment: .leading, spacing: 8) {
                SelectionRow(
                    title: "Reminder",
                    value: reminders.isEmpty ? "Add" : "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")",
                    action: { showingReminderSheet = true }
                )
                
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
            
            // Period
            VStack(alignment: .leading, spacing: 12) {
                Text("Period")
                    .font(.appTitleMedium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // Start Date
                    Button(action: {
                        showingStartDateSheet = true
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Date")
                                .font(.appBodyMedium)
                                .foregroundColor(.text05)
                            Text(isToday(startDate) ? "Today" : formatDate(startDate))
                                .font(.appBodyLarge)
                                .foregroundColor(.text04)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .inputFieldStyle()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // End Date
                    Button(action: {
                        showingEndDateSheet = true
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
    }
    
    #Preview {
        Text("Create Habit Step 2")
            .font(.appTitleMedium)
    }
}

