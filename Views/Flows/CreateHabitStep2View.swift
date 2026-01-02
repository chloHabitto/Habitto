import SwiftUI
import UIKit

struct CreateHabitStep2View: View {
  // MARK: Internal

  @Binding var name: String
  @Binding var description: String
  @Binding var icon: String
  @Binding var color: Color
  @Binding var habitType: HabitType
  @Binding var reminder: String
  @Binding var reminders: [ReminderItem]
  @Binding var startDate: Date
  @Binding var endDate: Date?
  @Binding var goalNumber: String
  @Binding var goalUnit: String
  @Binding var goalFrequency: String
  @Binding var baselineNumber: String
  @Binding var baselineUnit: String
  @Binding var baselineFrequency: String
  @Binding var targetNumber: String
  @Binding var targetUnit: String
  @Binding var targetFrequency: String

  let habitToEdit: Habit?
  let goBack: () -> Void
  let onSave: (Habit) -> Void

  var body: some View {
    focusStateModifiers
      .sheet(isPresented: $showingReminderSheet) {
        ReminderBottomSheet(
          onClose: {
            showingReminderSheet = false

            // Explicitly unfocus all fields when reminder sheet closes
            DispatchQueue.main.async {
              isGoalNumberFocused = false
              isBaselineFieldFocused = false
              isTargetFieldFocused = false
            }
          },
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

            // Explicitly unfocus all fields when reminder sheet closes
            DispatchQueue.main.async {
              isGoalNumberFocused = false
              isBaselineFieldFocused = false
              isTargetFieldFocused = false
            }
          })
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
          onEndDateSelected: { _ in
            // This should never be called for start date sheet
          },
          onRemoveEndDate: nil,
          onResetStartDate: {
            startDate = Date()
            showingStartDateSheet = false
          })
      }
      .sheet(isPresented: $showingEndDateSheet) {
        PeriodBottomSheet(
          isSelectingStartDate: false,
          startDate: startDate,
          initialDate: endDate ?? Date(),
          onStartDateSelected: { _ in
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
          onResetStartDate: nil)
      }
      .sheet(isPresented: $showingGoalUnitSheet) {
        UnitBottomSheet(
          onClose: { showingGoalUnitSheet = false },
          onUnitSelected: { selectedUnit in
            goalUnit = selectedUnit
            showingGoalUnitSheet = false
          },
          currentUnit: goalUnit)
      }
      .sheet(isPresented: $showingGoalFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingGoalFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            goalFrequency = selectedSchedule
            showingGoalFrequencySheet = false
          },
          initialSchedule: goalFrequency)
      }
      .sheet(isPresented: $showingBaselineUnitSheet) {
        UnitBottomSheet(
          onClose: { showingBaselineUnitSheet = false },
          onUnitSelected: { selectedUnit in
            baselineUnit = selectedUnit
            showingBaselineUnitSheet = false
          },
          currentUnit: baselineUnit)
      }
      .sheet(isPresented: $showingBaselineFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingBaselineFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            baselineFrequency = selectedSchedule
            showingBaselineFrequencySheet = false
          },
          initialSchedule: baselineFrequency)
      }
      .sheet(isPresented: $showingTargetUnitSheet) {
        UnitBottomSheet(
          onClose: { showingTargetUnitSheet = false },
          onUnitSelected: { selectedUnit in
            targetUnit = selectedUnit
            showingTargetUnitSheet = false
          },
          currentUnit: targetUnit)
      }
      .sheet(isPresented: $showingTargetFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingTargetFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            targetFrequency = selectedSchedule
            showingTargetFrequencySheet = false
          },
          initialSchedule: targetFrequency)
      }
      .onAppear {
        // Initialize values if editing
        if let habit = habitToEdit {
          if habit.habitType == .formation {
            // NEW UNIFIED APPROACH - Parse existing goal into number, unit, and frequency
            let goalComponents = habit.goal.components(separatedBy: " ")
            if goalComponents.count >= 4, goalComponents[2] == "per" {
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
            if goalComponents.count >= 4, goalComponents[2] == "per" {
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
      .sheet(isPresented: $showingStartDateSheet) {
        PeriodBottomSheet(
          isSelectingStartDate: true,
          startDate: startDate,
          initialDate: startDate,
          onStartDateSelected: { selectedDate in
            startDate = selectedDate
            showingStartDateSheet = false
          },
          onEndDateSelected: { _ in
            // This should never be called for start date sheet
          },
          onRemoveEndDate: nil,
          onResetStartDate: {
            startDate = Date()
            showingStartDateSheet = false
          })
      }
      .sheet(isPresented: $showingEndDateSheet) {
        PeriodBottomSheet(
          isSelectingStartDate: false,
          startDate: startDate,
          initialDate: endDate ?? Date(),
          onStartDateSelected: { _ in
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
          onResetStartDate: nil)
      }
      .sheet(isPresented: $showingGoalUnitSheet) {
        UnitBottomSheet(
          onClose: { showingGoalUnitSheet = false },
          onUnitSelected: { selectedUnit in
            goalUnit = selectedUnit
            showingGoalUnitSheet = false
          },
          currentUnit: goalUnit)
      }
      .sheet(isPresented: $showingGoalFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingGoalFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            goalFrequency = selectedSchedule.lowercased()
            showingGoalFrequencySheet = false
          },
          initialSchedule: goalFrequency)
      }
      .sheet(isPresented: $showingBaselineUnitSheet) {
        UnitBottomSheet(
          onClose: { showingBaselineUnitSheet = false },
          onUnitSelected: { selectedUnit in
            baselineUnit = selectedUnit
            showingBaselineUnitSheet = false
          },
          currentUnit: baselineUnit)
      }
      .sheet(isPresented: $showingBaselineFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingBaselineFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            baselineFrequency = selectedSchedule.lowercased()
            showingBaselineFrequencySheet = false
          },
          initialSchedule: baselineFrequency)
      }
      .sheet(isPresented: $showingTargetUnitSheet) {
        UnitBottomSheet(
          onClose: { showingTargetUnitSheet = false },
          onUnitSelected: { selectedUnit in
            targetUnit = selectedUnit
            showingTargetUnitSheet = false
          },
          currentUnit: targetUnit)
      }
      .sheet(isPresented: $showingTargetFrequencySheet) {
        ScheduleBottomSheet(
          onClose: { showingTargetFrequencySheet = false },
          onScheduleSelected: { selectedSchedule in
            targetFrequency = selectedSchedule.lowercased()
            showingTargetFrequencySheet = false
          },
          initialSchedule: targetFrequency)
      }
      .onAppear {
        // Initialize values if editing
        if let habit = habitToEdit {
          if habit.habitType == .formation {
            // NEW UNIFIED APPROACH - Parse existing goal into number, unit, and frequency
            let goalComponents = habit.goal.components(separatedBy: " ")
            if goalComponents.count >= 4, goalComponents[2] == "per" {
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
            if goalComponents.count >= 4, goalComponents[2] == "per" {
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

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  @State private var showingReminderSheet = false
  @State private var showingStartDateSheet = false
  @State private var showingEndDateSheet = false

  // Sheet state variables for UI management
  @State private var showingGoalUnitSheet = false
  @State private var showingGoalFrequencySheet = false
  @State private var showingBaselineUnitSheet = false
  @State private var showingBaselineFrequencySheet = false
  @State private var showingTargetUnitSheet = false
  @State private var showingTargetFrequencySheet = false
  @State private var isSaving = false // ✅ FIX: Prevent multiple save button taps

  /// Tooltip state - only one can be shown at a time
  @State private var activeTooltip: String? // "baseline" or "target" or nil
  // @State private var sharedPopTip: PopTip?

  // Removed manual UI update trigger; rely on SwiftUI state changes

  // Focus state for Done button overlay
  @FocusState private var isGoalNumberFocused: Bool
  @FocusState private var isBaselineFieldFocused: Bool
  @FocusState private var isTargetFieldFocused: Bool

  /// Computed properties for pluralized units
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

  /// Form validation
  private var isGoalValid: Bool {
    HabitFormLogic.isGoalValid(goalNumber)
  }

  private var isBaselineValid: Bool {
    HabitFormLogic.isBaselineValid(baselineNumber)
  }

  private var isTargetValid: Bool {
    HabitFormLogic.isTargetValid(targetNumber)
  }

  /// Overall form validation
  private var isFormValid: Bool {
    let result = HabitFormLogic.isFormValid(
      habitType: habitType,
      goalNumber: goalNumber,
      baselineNumber: baselineNumber,
      targetNumber: targetNumber)
    
    #if DEBUG
    print("🔍 VALIDATION CHECK:")
    print("  → habitType: \(habitType)")
    print("  → goalNumber: '\(goalNumber)'")
    print("  → baselineNumber: '\(baselineNumber)'")
    print("  → targetNumber: '\(targetNumber)'")
    print("  → isFormValid: \(result)")
    if habitType == .formation {
      print("  → isGoalValid: \(HabitFormLogic.isGoalValid(goalNumber))")
    } else {
      print("  → isBaselineValid: \(HabitFormLogic.isBaselineValid(baselineNumber))")
      print("  → isTargetValid: \(HabitFormLogic.isTargetValid(targetNumber))")
    }
    #endif
    
    return result
  }

  // MARK: - Computed Properties for UI

  private var bottomGradientColors: [Color] {
    [
      Color.surface2.opacity(0),
      Color.surface2.opacity(0.3),
      Color.surface2.opacity(0.7),
      Color.surface2.opacity(1.0)
    ]
  }

  private var bottomGradient: LinearGradient {
    LinearGradient(
      gradient: Gradient(colors: bottomGradientColors),
      startPoint: .top,
      endPoint: .bottom)
  }

  // MARK: - Main Content View

  private var mainContentView: some View {
    VStack(spacing: 0) {
      CreateHabitHeader(stepNumber: 2, onCancel: { dismiss() })

      ScrollView {
        if habitType == .formation {
          habitBuildingForm
        } else {
          habitBreakingForm
        }
      }
      .padding(.horizontal, 20)

      Spacer()

      FormActionButtons(
        isFormValid: isFormValid && !isSaving, // ✅ FIX: Disable button while saving
        primaryColor: color,
        onBack: goBack,
        onSave: {
          // ✅ FIX: Prevent multiple taps
          guard !isSaving else {
            #if DEBUG
            print("⚠️ SAVE BUTTON: Ignoring tap - save already in progress")
            #endif
            return
          }
          #if DEBUG
          print("🔘 SAVE BUTTON TAPPED!")
          print("  → isFormValid at tap time: \(isFormValid)")
          #endif
          saveHabit()
        })
    }
    .background(.appSurface04Variant)
  }

  // MARK: - Focus State Modifiers

  private var focusStateModifiers: some View {
    mainContentView
      .navigationBarHidden(true)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") {
            // Dismiss all focused fields
            isGoalNumberFocused = false
            isBaselineFieldFocused = false
            isTargetFieldFocused = false
          }
          .font(.appBodyMedium)
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.accentColor)
          .clipShape(Capsule())
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .ignoresSafeArea(.keyboard, edges: .bottom)
  }

  // MARK: - Habit Building Form

  @ViewBuilder
  private var habitBuildingForm: some View {
    HabitBuildingForm(
      goalNumber: $goalNumber,
      pluralizedGoalUnit: pluralizedGoalUnit,
      goalFrequency: goalFrequency,
      isGoalValid: isGoalValid,
      onGoalUnitTap: { showingGoalUnitSheet = true },
      onGoalFrequencyTap: { showingGoalFrequencySheet = true },
      reminderSection: ReminderSection(
        reminders: reminders,
        onTap: { showingReminderSheet = true }),
      periodSection: PeriodSection(
        startDate: startDate,
        endDate: endDate,
        onStartDateTap: { showingStartDateSheet = true },
        onEndDateTap: { showingEndDateSheet = true }),
      isGoalNumberFocused: $isGoalNumberFocused)
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
      onBaselineUnitTap: { showingBaselineUnitSheet = true },
      onBaselineFrequencyTap: { showingBaselineFrequencySheet = true },
      onTargetUnitTap: { showingTargetUnitSheet = true },
      onTargetFrequencyTap: { showingTargetFrequencySheet = true },
      reminderSection: ReminderSection(
        reminders: reminders,
        onTap: { showingReminderSheet = true }),
      periodSection: PeriodSection(
        startDate: startDate,
        endDate: endDate,
        onStartDateTap: { showingStartDateSheet = true },
        onEndDateTap: { showingEndDateSheet = true }),
      isBaselineFieldFocused: $isBaselineFieldFocused,
      isTargetFieldFocused: $isTargetFieldFocused)
  }

  #Preview {
    Text("Create Habit Step 2")
      .font(.appTitleMedium)
  }

  // MARK: - Helper Functions

  private func createHabit() -> Habit {
    HabitFormLogic.createHabit(
      step1Data: (name, description, icon, color, habitType),
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
      reminders: reminders)
  }

  private func saveHabit() {
    // ✅ FIX: Prevent multiple saves
    guard !isSaving else {
      #if DEBUG
      print("⚠️ saveHabit: Already saving, ignoring duplicate call")
      #endif
      return
    }
    
    isSaving = true
    
    let newHabit = createHabit()
    #if DEBUG
    print("🎯 [1/8] CreateHabitStep2View.saveHabit: tap Add button")
    print("  → Habit: '\(newHabit.name)', ID: \(newHabit.id)")
    print("  → Goal: '\(newHabit.goal)', Type: \(newHabit.habitType)")
    print("  → Reminders: \(reminders.count)")
    #endif
    NotificationManager.shared.updateNotifications(for: newHabit, reminders: reminders)
    #if DEBUG
    print("  → Notifications updated")
    #endif
    onSave(newHabit)
    #if DEBUG
    print("  → onSave callback invoked")
    #endif
    // Note: isSaving will be reset when the sheet dismisses
    // ✅ FIX: Don't dismiss here - let HomeView handle dismiss after async save completes
    // dismiss() ← REMOVED: This was dismissing before the async save in HomeView completed!
  }
}
