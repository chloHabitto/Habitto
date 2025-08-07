import SwiftUI
import UIKit

struct CreateHabitStep2View: View {
    let step1Data: (String, String, String, Color, HabitType)
    let habitToEdit: Habit?
    let goBack: () -> Void
    let onSave: (Habit) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Computed properties for pluralized units
    private var pluralizedGoalUnit: String {
        let number = Int(goalNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return HabitFormLogic.pluralizedUnit(number, unit: goalUnit)
    }
    
    private var pluralizedBaselineUnit: String {
        let number = Int(baselineNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return HabitFormLogic.pluralizedUnit(number, unit: baselineUnit)
    }
    
    private var pluralizedTargetUnit: String {
        let number = Int(targetNumber) ?? 1
        if number == 0 {
            return "time" // Always show singular for 0
        }
        return HabitFormLogic.pluralizedUnit(number, unit: targetUnit)
    }
    
    @State private var reminder: String = "No reminder"
    @State private var reminders: [ReminderItem] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var showingReminderSheet = false
    @State private var showingStartDateSheet = false
    @State private var showingEndDateSheet = false
    
    // OLD Habit Breaking specific state - Commented out for new unified approach
    // @State private var baseline: String = "1"
    // @State private var target: String = "1"
    // @State private var baselineUnit: String = "time"
    // @State private var targetUnit: String = "time"
    // @State private var showingBaselineUnitSheet = false
    // @State private var showingTargetUnitSheet = false
    
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
    
    // Tooltip state - only one can be shown at a time
    @State private var activeTooltip: String? // "baseline" or "target" or nil
    // @State private var sharedPopTip: PopTip?
    
    // Force UI updates when number changes
    @State private var uiUpdateTrigger = false
    
    // Form validation
    private var isGoalValid: Bool {
        return HabitFormLogic.isGoalValid(goalNumber)
    }
    
    private var isBaselineValid: Bool {
        return HabitFormLogic.isBaselineValid(baselineNumber)
    }
    
    private var isTargetValid: Bool {
        return HabitFormLogic.isTargetValid(targetNumber)
    }
    
    // Overall form validation
    private var isFormValid: Bool {
        return HabitFormLogic.isFormValid(
            habitType: step1Data.4,
            goalNumber: goalNumber,
            baselineNumber: baselineNumber,
            targetNumber: targetNumber
        )
    }
    

    
    // MARK: - Helper Functions
    private func createHabit() -> Habit {
        return HabitFormLogic.createHabit(
            step1Data: step1Data,
            goalNumber: goalNumber,
            goalUnit: goalUnit,
            goalFrequency: goalFrequency,
            baselineNumber: baselineNumber,
            targetNumber: targetNumber,
            targetUnit: targetUnit,
            targetFrequency: targetFrequency,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            reminders: reminders
        )
    }

    
    private func saveHabit() {
        let newHabit = createHabit()
        NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
        onSave(newHabit)
        dismiss()
    }
    
    // MARK: - Computed Properties for UI
    private var bottomGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.surface2.opacity(0),
                Color.surface2.opacity(0.3),
                Color.surface2.opacity(0.7),
                Color.surface2.opacity(1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
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
            
            FormActionButtons(
                isFormValid: isFormValid,
                primaryColor: step1Data.3,
                onBack: goBack,
                onSave: saveHabit
            )
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
        .onChange(of: baselineNumber) { _, _ in
            // Force UI update when baseline changes
            uiUpdateTrigger.toggle()
        }
        .onChange(of: targetNumber) { _, _ in
            // Force UI update when target changes
            uiUpdateTrigger.toggle()
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
        .onAppear {
            // Initialize values if editing
            if let habit = habitToEdit {
                
                if habit.habitType == .formation {
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
        HabitBuildingForm(
            goalNumber: $goalNumber,
            pluralizedGoalUnit: pluralizedGoalUnit,
            goalFrequency: goalFrequency,
            isGoalValid: isGoalValid,
            uiUpdateTrigger: uiUpdateTrigger,
            onGoalUnitTap: { showingGoalUnitSheet = true },
            onGoalFrequencyTap: { showingGoalFrequencySheet = true },
            reminderSection: ReminderSection(
                reminders: reminders,
                onTap: { showingReminderSheet = true }
            ),
            periodSection: PeriodSection(
                startDate: startDate,
                endDate: endDate,
                onStartDateTap: { showingStartDateSheet = true },
                onEndDateTap: { showingEndDateSheet = true }
            )
        )
    }
    
    // MARK: - Habit Breaking Form
    @ViewBuilder
    private var habitBreakingForm: some View {
        HabitBreakingForm(
            baselineNumber: $baselineNumber,
            targetNumber: $targetNumber,
            pluralizedBaselineUnit: pluralizedBaselineUnit,
            pluralizedTargetUnit: pluralizedTargetUnit,
            baselineFrequency: baselineFrequency,
            targetFrequency: targetFrequency,
            isBaselineValid: isBaselineValid,
            isTargetValid: isTargetValid,
            uiUpdateTrigger: uiUpdateTrigger,
            onBaselineUnitTap: { showingBaselineUnitSheet = true },
            onBaselineFrequencyTap: { showingBaselineFrequencySheet = true },
            onTargetUnitTap: { showingTargetUnitSheet = true },
            onTargetFrequencyTap: { showingTargetFrequencySheet = true },
            reminderSection: ReminderSection(
                reminders: reminders,
                onTap: { showingReminderSheet = true }
            ),
            periodSection: PeriodSection(
                startDate: startDate,
                endDate: endDate,
                onStartDateTap: { showingStartDateSheet = true },
                onEndDateTap: { showingEndDateSheet = true }
            )
        )
    }
    
    #Preview {
        Text("Create Habit Step 2")
            .font(.appTitleMedium)
    }
}