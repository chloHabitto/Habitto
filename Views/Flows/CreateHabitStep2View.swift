import SwiftUI
import UIKit

struct CreateHabitStep2View: View {
    @FocusState private var isGoalNumberFocused: Bool
    @FocusState private var isBaselineFieldFocused: Bool
    @FocusState private var isTargetFieldFocused: Bool
    let step1Data: (String, String, String, Color, HabitType)
    let habitToEdit: Habit?
    let goBack: () -> Void
    let onSave: (Habit) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Cache screen width to avoid repeated UIScreen.main.bounds.width access
    private let screenWidth = UIScreen.main.bounds.width
    
    // Cache DateFormatters for better performance
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    // Cache Calendar for better performance
    private let calendar = Calendar.current
    
    private func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        return calendar.isDateInToday(date)
    }
    
    // Helper function to handle pluralization for units
    private func pluralizedUnit(_ count: Int, unit: String) -> String {
        if unit == "time" || unit == "times" {
            return count == 1 ? "time" : "times"
        }
        return unit
    }
    
    // Computed properties for pluralized units to ensure proper SwiftUI updates
    private var pluralizedGoalUnit: String {
        let number = Int(goalNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: goalUnit)
    }
    
    private var pluralizedBaselineUnit: String {
        let number = Int(baseline) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: baselineUnit)
    }
    
    private var pluralizedTargetUnit: String {
        let number = Int(target) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return pluralizedUnit(number, unit: targetUnit)
    }
    
    @State private var schedule: String = "Everyday"
    @State private var goalNumber: String = "1"
    @State private var goalUnit: String = "time"
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
    @State private var baseline: String = "1"
    @State private var target: String = "1"
    @State private var baselineUnit: String = "time"
    @State private var targetUnit: String = "time"
    @State private var showingBaselineUnitSheet = false
    @State private var showingTargetUnitSheet = false
    
    // Tooltip state - only one can be shown at a time
    @State private var activeTooltip: String? // "baseline" or "target" or nil
    // @State private var sharedPopTip: PopTip?
    
    // Force UI updates when number changes
    @State private var uiUpdateTrigger = false
    
    // Computed properties for validation
    private var isGoalValid: Bool {
        let number = Int(goalNumber) ?? 0
        return number > 0
    }
    
    private var isBaselineValid: Bool {
        let number = Int(baseline) ?? 0
        return number > 0
    }
    
    private var isTargetValid: Bool {
        let number = Int(target) ?? 0
        return number >= 0  // Allow 0 for reduction goal in habit breaking
    }
    
    // Overall form validation
    private var isFormValid: Bool {
        if step1Data.4 == .formation {
            return isGoalValid
        } else {
            return isBaselineValid && isTargetValid
        }
    }
    

    
    var body: some View {
        VStack(spacing: 0) {
            CreateHabitHeader(stepNumber: 2, onCancel: { dismiss() })
            
            ScrollView {
                if step1Data.4 == .formation {
                    habitBuildingForm
                } else {
                    habitBreakingForm
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { goBack() }) {
                    Image("Icon-leftArrow")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.onPrimaryContainer)
                        .frame(width: 48, height: 48)
                        .background(.primaryContainer)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: { 
                    let newHabit: Habit
                    
                    if step1Data.4 == .formation {
                        let goalNumberInt = Int(goalNumber) ?? 1
                        let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: goalUnit)
                        let goalString = "\(goalNumber) \(pluralizedUnit)"
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
                        let targetInt = Int(target) ?? 1
                        let pluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
                        let goalString = "\(target) \(pluralizedUnit)"
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
                    
                    NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
                    onSave(newHabit)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.appButtonText1)
                        .foregroundColor(isFormValid ? .white : .text06)
                        .frame(width: screenWidth * 0.5)
                        .padding(.vertical, 16)
                        .background(isFormValid ? step1Data.3 : .disabledBackground)
                        .clipShape(Capsule())
                }
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(.surface2)
        }
        .background(.surface2)

        .onAppear {
            // Temporarily disabled AMPopTip for debugging
            // if sharedPopTip == nil {
            //     sharedPopTip = PopTip()
            //     // Configure the shared PopTip with default settings
            //     sharedPopTip?.bubbleColor = UIColor.systemBackground
            //     sharedPopTip?.textColor = UIColor(Color.text05)
            //     sharedPopTip?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            //     sharedPopTip?.cornerRadius = 12
            //     sharedPopTip?.arrowSize = CGSize(width: 12, height: 6)
            //     sharedPopTip?.offset = 8
            //     sharedPopTip?.edgeMargin = 8
            //     sharedPopTip?.padding = 16
            //     sharedPopTip?.shouldShowMask = false
            //     
            //     // Add tap outside to dismiss functionality
            //     sharedPopTip?.tapOutsideHandler = { [weak self] in
            //         print("PopTip tap outside handler triggered")
            //         DispatchQueue.main.async {
            //             self?.activeTooltip = nil
            //             }
            //     }
            // }
        }
        .navigationBarHidden(true)
        .keyboardHandling(dismissOnTapOutside: true, showDoneButton: true)
        .onChange(of: goalNumber) { oldValue, newValue in
            // Force UI update when goal number changes
            uiUpdateTrigger.toggle()
        }
        .onChange(of: baseline) { _, _ in
            // Force UI update when baseline changes
            uiUpdateTrigger.toggle()
        }
        .onChange(of: target) { _, _ in
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
                        goalUnit = "time"
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
            // Goal
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                HStack(spacing: 12) {
                    // Number input field
                    TextField("1", text: $goalNumber)
                        .font(.appBodyLarge)
                        .foregroundColor(.text01)
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
                            Text(pluralizedGoalUnit)
                                .font(.appBodyLarge)
                                .foregroundColor(isGoalValid ? .text04 : .text06)
                                .id(uiUpdateTrigger) // Force re-render when trigger changes
                            Image(systemName: "chevron.right")
                                .font(.appLabelSmall)
                                .foregroundColor(.primaryDim)
                        }
                        .frame(maxWidth: .infinity)
                        .inputFieldStyle()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Warning message for invalid goal
                if !isGoalValid {
                    ErrorMessage(message: "Please enter a number greater than 0")
                        .padding(.top, 4)
                }
            }
            .selectionRowStyle()
            
            // Schedule
            SelectionRow(
                title: "Schedule",
                value: schedule,
                action: { showingScheduleSheet = true }
            )
            
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
                        
                        // Period
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Period")
                                .font(.appTitleMedium)
                                .foregroundColor(.text01)
                
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
            // Current Baseline
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Current Baseline")
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                    
                    // PopTipButton(
                    //     text: "On average, how often do you do this per day/week?",
                    //     tooltipId: "baseline",
                    //     activeTooltip: activeTooltip,
                    //     onTooltipChange: { newActiveTooltip in
                    //         activeTooltip = newActiveTooltip
                    //     },
                    //     sharedPopTip: sharedPopTip
                    // )
                    // .frame(width: 16, height: 16)
                }
                
                Text("On average, how often do you do this per day/week?")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                    .padding(.bottom, 12)
                
                HStack(spacing: 12) {
                    // Number input field
                    TextField("1", text: $baseline)
                        .font(.appBodyLarge)
                        .foregroundColor(.text01)
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
                            Text(pluralizedBaselineUnit)
                                .font(.appBodyLarge)
                                .foregroundColor(isBaselineValid ? .text04 : .text06)
                                .id(uiUpdateTrigger) // Force re-render when trigger changes
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
                
                // Warning message for invalid baseline
                if !isBaselineValid {
                    ErrorMessage(message: "Please enter a number greater than 0")
                        .padding(.top, 4)
                }
            }
            .selectionRowStyle()
            
            // Reduction Goal
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Reduction Goal")
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                    
                    // PopTipButton(
                    //     text: "What's your first goal?",
                    //     tooltipId: "target",
                    //     activeTooltip: activeTooltip,
                    //     onTooltipChange: { newActiveTooltip in
                    //         activeTooltip = newActiveTooltip
                    //     },
                    //     sharedPopTip: sharedPopTip
                    // )
                    // .frame(width: 16, height: 16)
                }
                
                Text("What's your first goal?")
                    .font(.appBodyMedium)
                    .foregroundColor(.text05)
                    .padding(.bottom, 12)
                
                HStack(spacing: 12) {
                    // Number input field
                    TextField("1", text: $target)
                        .font(.appBodyLarge)
                        .foregroundColor(.text01)
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
                            Text(pluralizedTargetUnit)
                                .font(.appBodyLarge)
                                .foregroundColor(isTargetValid ? .text04 : .text06)
                                .id(uiUpdateTrigger) // Force re-render when trigger changes
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
                
                // Warning message for invalid target
                if !isTargetValid {
                    ErrorMessage(message: "Please enter a number greater than or equal to 0")
                        .padding(.top, 4)
                }
            }
            .selectionRowStyle()
            
            // Schedule
            SelectionRow(
                title: "Schedule",
                value: schedule,
                action: { showingScheduleSheet = true }
            )
            
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
           
            
            // Period
            VStack(alignment: .leading, spacing: 12) {
                Text("Period")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
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

// MARK: - SwiftUI Wrapper for AMPopTip (Temporarily disabled)
// struct PopTipButton: UIViewRepresentable {
//     let text: String
//     let tooltipId: String
//     let activeTooltip: String?
//     let onTooltipChange: (String?) -> Void
//     let sharedPopTip: PopTip?
//     
//     func makeUIView(context: Context) -> UIButton {
//         let button = UIButton(type: .system)
//         button.setImage(UIImage(systemName: "info.circle"), for: .normal)
//         button.tintColor = UIColor(Color.text06)
//         button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
//         context.coordinator.button = button
//         context.coordinator.parent = self
//         return button
//     }
//     
//     func updateUIView(_ uiView: UIButton, context: Context) {
//         context.coordinator.parent = self
//     }
//     
//     func makeCoordinator() -> Coordinator {
//         Coordinator(self)
//     }
//     
//     class Coordinator: NSObject {
//         var parent: PopTipButton
//         var button: UIButton?
//         
//         init(_ parent: PopTipButton) {
//             self.parent = parent
//         }
//         
//         @objc func buttonTapped() {
//             print("Button tapped for tooltip: \(parent.tooltipId)")
//             print("Active tooltip: \(parent.activeTooltip ?? "none")")
//             print("Shared PopTip exists: \(parent.sharedPopTip != nil)")
//             
//             if parent.activeTooltip == parent.tooltipId {
//                 // This tooltip is currently active, hide it
//                 print("Hiding tooltip: \(parent.tooltipId)")
//                 parent.sharedPopTip?.hide()
//                 parent.onTooltipChange(nil)
//             } else {
//                 // Show this tooltip and hide any other active tooltip
//                 print("Showing tooltip: \(parent.tooltipId)")
//                 parent.onTooltipChange(parent.tooltipId)
//                 showPopTip()
//             }
//         }
//         
//         func showPopTip() {
//             print("showPopTip called")
//             print("Button exists: \(button != nil)")
//             print("Shared PopTip exists: \(parent.sharedPopTip != nil)")
//             
//             guard let button = button, let popTip = parent.sharedPopTip else { 
//                 print("Guard failed - button or popTip is nil")
//                 return 
//             }
//             
//             print("About to show tooltip with text: \(parent.text)")
//             
//             // Hide any existing popTip before showing a new one
//             popTip.hide()
//             
//             // Get the button's frame in the window
//             if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                let window = windowScene.windows.first {
//                 let buttonFrame = button.convert(button.bounds, to: window)
//                 print("Button frame: \(buttonFrame)")
//                 
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//                     guard let self = self else { return }
//                     popTip.show(text: self.parent.text, direction: .down, maxWidth: 300, in: window, from: buttonFrame)
//                     print("PopTip show called with delay")
//                     
//                     // Check if PopTip is visible after showing
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                         print("PopTip is visible: \(popTip.isVisible)")
//                         print("PopTip frame: \(popTip.frame)")
//                     }
//                 }
//             } else {
//                 print("Failed to get window or windowScene")
//             }
//         }
//     }
// }





