import SwiftUI

struct HabitEditView: View {
  // MARK: Lifecycle

  init(habit: Habit, onSave: @escaping (Habit) -> Void) {
    self.onSave = onSave
    self._form = StateObject(wrappedValue: HabitEditFormState(habit: habit))
  }

  // MARK: Internal

  let onSave: (Habit) -> Void
  @StateObject private var form: HabitEditFormState

  var body: some View {
    mainViewWithSheets
  }


  // MARK: Private

  @FocusState private var isGoalNumberFocused: Bool
  @FocusState private var isBaselineFieldFocused: Bool
  @FocusState private var isTargetFieldFocused: Bool
  
  private enum ScrollTarget: Hashable {
    case goal
    case baseline
    case target
  }

  @Environment(\.dismiss) private var dismiss

  @State private var showingGoalUnitSheet = false
  @State private var showingGoalFrequencySheet = false
  @State private var showingBaselineUnitSheet = false
  @State private var showingBaselineFrequencySheet = false
  @State private var showingTargetUnitSheet = false
  @State private var showingTargetFrequencySheet = false

  /// Cached unit display strings to avoid recomputation and re-render forcing
  @State private var goalUnitDisplay: String = "time"
  @State private var baselineUnitDisplay: String = "time"
  @State private var targetUnitDisplay: String = "time"

  // Sheet states
  @State private var showingEmojiPicker = false
  @State private var showingColorSheet = false
  @State private var showingScheduleSheet = false
  @State private var showingReminderSheet = false
  @State private var showingStartDateSheet = false
  @State private var showingEndDateSheet = false

  // Focus states for text fields
  @FocusState private var isNameFieldFocused: Bool
  @FocusState private var isDescriptionFieldFocused: Bool

  private var originalHabit: Habit { form.originalHabit }

  /// Computed property to check if any changes have been made
  private var hasChanges: Bool {
    // Check basic fields
    let basicChanges = form.habitName != originalHabit.name ||
      form.habitDescription != originalHabit.description ||
      form.selectedIcon != originalHabit.icon ||
      form.selectedColor != originalHabit.color.color ||
      form.selectedHabitType != originalHabit.habitType ||
      form.selectedReminder != originalHabit.reminder ||
      form.reminders != originalHabit.reminders ||
      form.startDate != originalHabit.startDate ||
      form.endDate != originalHabit.endDate

    // Check schedule changes (different logic for habit building vs breaking)
    let scheduleChanges: Bool = if form.selectedHabitType == .formation {
      // For habit building, schedule is derived from goal frequency
      form.goalFrequency != originalHabit.schedule
    } else {
      // For habit breaking, schedule is derived from baseline frequency
      form.baselineFrequency != originalHabit.schedule
    }

    // Check unified approach fields
    var unifiedChanges = false

    if form.selectedHabitType == .formation {
      // For habit building, check goal fields
      let currentGoal = "\(form.goalNumber) \(goalUnitDisplay) on \(form.goalFrequency)"
      let originalGoal = originalHabit.goal
      unifiedChanges = currentGoal != originalGoal
    } else {
      // For habit breaking, check baseline and target fields
      let currentBaseline = Int(form.baselineNumber) ?? 0
      let currentTarget = Int(form.targetNumber) ?? 0
      unifiedChanges = currentBaseline != originalHabit.baseline || currentTarget != originalHabit.target
    }

    return basicChanges || scheduleChanges || unifiedChanges
  }

  /// Unit pluralization helpers
  private func computePluralizedUnit(for numberText: String, unit: String) -> String {
    let number = Int(numberText) ?? 1
    if number == 0 { return "time" }
    return pluralizedUnit(number, unit: unit)
  }

  /// NEW Unified computed properties for validation
  private var isGoalValid: Bool {
    let number = Int(form.goalNumber) ?? 0
    return number > 0
  }

  private var isBaselineValid: Bool {
    let number = Int(form.baselineNumber) ?? 0
    return number > 0
  }

  private var isTargetValid: Bool {
    let targetValue = Int(form.targetNumber) ?? 0
    // Allow 0 for reduction goal in habit breaking, but enforce baseline > target when in breaking mode
    if form.selectedHabitType == .breaking {
      let baselineValue = Int(form.baselineNumber) ?? 0
      return targetValue >= 0 && baselineValue > targetValue
    }
    return targetValue >= 0
  }

  /// Inline error message for target when breaking validation fails (baseline must be > target)
  private var targetInlineErrorMessage: String {
    let baselineValue = Int(form.baselineNumber) ?? 0
    let targetValue = Int(form.targetNumber) ?? 0
    if form.selectedHabitType == .breaking && baselineValue <= targetValue {
      let suggested = max(targetValue + 5, targetValue + 1)
      return "Goal must be less than Current. Suggested Current: \(suggested)"
    }
    return "Please enter a number greater than or equal to 0"
  }

  /// Overall form validation
  private var isFormValid: Bool {
    if form.selectedHabitType == .formation {
      isGoalValid
    } else {
      isBaselineValid && isTargetValid
    }
  }

  // MARK: - Main Content Views

  @ViewBuilder
  private var mainContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 16) {
          basicInfoSection
          goalSection
          reminderAndPeriodSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .padding(.bottom, 100) // Add bottom padding to account for fixed button
      }
      .background(.surface2)
      .onChange(of: isGoalNumberFocused) { _, newValue in
        guard newValue else { return }
        scrollToField(.goal, with: proxy)
      }
      .onChange(of: isBaselineFieldFocused) { _, newValue in
        guard newValue else { return }
        scrollToField(.baseline, with: proxy)
      }
      .onChange(of: isTargetFieldFocused) { _, newValue in
        guard newValue else { return }
        scrollToField(.target, with: proxy)
      }
    }
  }

  @ViewBuilder
  private var basicInfoSection: some View {
    VStack(spacing: 16) {
      // Habit Name
      CustomTextField(
        placeholder: "Name",
        text: $form.habitName,
        isFocused: $isNameFieldFocused)

      // Description
      CustomTextField(
        placeholder: "Description (Optional)",
        text: $form.habitDescription,
        isFocused: $isDescriptionFieldFocused)

      // Color Selection (moved before Icon to match creation flow)
      VisualSelectionRow(
        title: "Colour",
        color: form.selectedColor,
        value: getColorDisplayName(form.selectedColor),
        action: { showingColorSheet = true })

      // Icon Selection (moved after Color to match creation flow)
      VisualSelectionRow(
        title: "Icon",
        color: form.selectedColor,
        icon: form.selectedIcon,
        value: getIconDisplayName(form.selectedIcon),
        action: { showingEmojiPicker = true })

      // Habit Type
      habitTypeSection
    }
  }

  @ViewBuilder
  private var goalSection: some View {
    // Goal - NEW UNIFIED APPROACH
    if form.selectedHabitType == .formation {
      UnifiedInputElement(
        title: "Goal",
        description: "What do you want to achieve?",
        numberText: $form.goalNumber,
        unitText: goalUnitDisplay,
        frequencyText: form.goalFrequency,
        isValid: isGoalValid,
        errorMessage: "Please enter a number greater than 0",
        onUnitTap: { showingGoalUnitSheet = true },
        onFrequencyTap: { showingGoalFrequencySheet = true },
        isFocused: $isGoalNumberFocused)
      .id(ScrollTarget.goal)
    } else {
      // Habit Breaking Form
      VStack(spacing: 16) {
        // Baseline - NEW UNIFIED APPROACH
        UnifiedInputElement(
          title: "Current",
          description: "How much do you currently do?",
          numberText: $form.baselineNumber,
          unitText: baselineUnitDisplay,
          frequencyText: form.baselineFrequency,
          isValid: isBaselineValid,
          errorMessage: "Please enter a number greater than 0",
          onUnitTap: { showingBaselineUnitSheet = true },
          onFrequencyTap: { showingBaselineFrequencySheet = true },
          isFocused: $isBaselineFieldFocused)
        .id(ScrollTarget.baseline)

        // Target - NEW UNIFIED APPROACH
        UnifiedInputElement(
          title: "Goal",
          description: "How much do you want to reduce to?",
          numberText: $form.targetNumber,
          unitText: targetUnitDisplay,
          frequencyText: form.targetFrequency,
          isValid: isTargetValid,
          errorMessage: targetInlineErrorMessage,
          onUnitTap: { showingTargetUnitSheet = true },
          onFrequencyTap: { showingTargetFrequencySheet = true },
          isFocused: $isTargetFieldFocused)
        .id(ScrollTarget.target)
      }
    }
  }

  @ViewBuilder
  private var reminderAndPeriodSection: some View {
    VStack(spacing: 16) {
      // Reminder Section
      reminderSection

      // Period Section
      periodSection
    }
  }

  @ViewBuilder
  private var bottomButtonDock: some View {
    VStack(spacing: 0) {
      Divider()
        .background(.outline3)

      saveButton
    }
    .background(.surface2)
  }

  @ViewBuilder
  private var mainViewContent: some View {
    VStack(spacing: 0) {
      // Top navigation bar
      topNavigationBar

      if VacationManager.shared.isActive {
        // Vacation mode blocking view with enhanced feedback
        VStack(spacing: 24) {
          // Animated vacation icon
          Image("Icon-Vacation_Filled")
            .resizable()
            .frame(width: 80, height: 80)
            .foregroundColor(.blue)
            .scaleEffect(1.0)
            .animation(
              .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
              value: VacationManager.shared.isActive)

          VStack(spacing: 12) {
            Text("Vacation Mode Active")
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.text01)

            Text(
              "Habit editing is paused during vacation mode. You can edit habits when vacation mode ends.")
              .font(.appBodyMedium)
              .foregroundColor(.text02)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
          }

          // Enhanced close button with haptic feedback
          Button(action: {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            dismiss()
          }) {
            HStack(spacing: 8) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
              Text("Close")
                .font(.appBodyMediumEmphasised)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
              LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .clipShape(Capsule())
            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
          }
          .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          LinearGradient(
            colors: [Color.surface, Color.surface.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom))
      } else {
        // Main content
        mainContent

        // Fixed bottom button dock
        bottomButtonDock
      }
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
  }

  // MARK: - Main View with All Sheets

  @ViewBuilder
  private var mainViewWithSheets: some View {
    NavigationView {
      ZStack {
        mainViewContent
          .background(.surface2)
          .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
              Spacer()
              Button("Done") {
                resignAllFocus()
              }
              .font(.appBodyMedium)
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Color.accentColor)
              .clipShape(Capsule())
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
              Button("Close") {
                dismiss()
              }
              .foregroundColor(.primary)
            }
          }
        .navigationTitle("Edit habit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
          // Initialize cached unit display values
          goalUnitDisplay = computePluralizedUnit(for: form.goalNumber, unit: form.goalUnit)
          baselineUnitDisplay = computePluralizedUnit(for: form.baselineNumber, unit: form.baselineUnit)
          targetUnitDisplay = computePluralizedUnit(for: form.targetNumber, unit: form.targetUnit)
        }
        .sheet(isPresented: $showingEmojiPicker) {
          EmojiKeyboardBottomSheet(
            selectedEmoji: $form.selectedIcon,
            onClose: {
              showingEmojiPicker = false
            },
            onSave: { emoji in
              form.selectedIcon = emoji
              showingEmojiPicker = false
            })
        }
        .sheet(isPresented: $showingColorSheet) {
          ColorBottomSheet(
            onClose: { showingColorSheet = false },
            onColorSelected: { color in
              form.selectedColor = color
            },
            onSave: { color in
              form.selectedColor = color
              showingColorSheet = false
            })
        }
        .sheet(isPresented: $showingScheduleSheet) {
          ScheduleBottomSheet(
            onClose: { showingScheduleSheet = false },
            onScheduleSelected: { schedule in
              form.selectedSchedule = schedule
              showingScheduleSheet = false
            },
            initialSchedule: form.selectedSchedule)
        }
        .sheet(isPresented: $showingReminderSheet) {
          ReminderBottomSheet(
            onClose: { showingReminderSheet = false },
            onReminderSelected: { reminder in
              form.selectedReminder = reminder
              showingReminderSheet = false
            },
            onRemindersUpdated: { _ in })
        }
        .sheet(isPresented: $showingStartDateSheet) {
          PeriodBottomSheet(
            isSelectingStartDate: true,
            startDate: form.startDate,
            initialDate: form.startDate,
            onStartDateSelected: { date in
              form.startDate = date
              showingStartDateSheet = false
            },
            onEndDateSelected: { _ in }, // Not used for start date
            onRemoveEndDate: nil)
        }
        .sheet(isPresented: $showingEndDateSheet) {
          PeriodBottomSheet(
            isSelectingStartDate: false,
            startDate: form.startDate,
            initialDate: form.endDate ?? Date(),
            onStartDateSelected: { _ in }, // Not used for end date
            onEndDateSelected: { date in
              form.endDate = date
              showingEndDateSheet = false
            },
            onRemoveEndDate: {
              form.endDate = nil
              showingEndDateSheet = false
            })
        }
        .sheet(isPresented: $showingGoalUnitSheet) {
          UnitBottomSheet(
            onClose: { showingGoalUnitSheet = false },
            onUnitSelected: { selectedUnit in
              form.goalUnit = selectedUnit
              showingGoalUnitSheet = false
            },
            currentUnit: form.goalUnit)
        }
        .sheet(isPresented: $showingGoalFrequencySheet) {
          ScheduleBottomSheet(
            onClose: { showingGoalFrequencySheet = false },
            onScheduleSelected: { selectedSchedule in
              form.goalFrequency = selectedSchedule
              showingGoalFrequencySheet = false
            },
            initialSchedule: form.goalFrequency)
        }
        .sheet(isPresented: $showingBaselineUnitSheet) {
          UnitBottomSheet(
            onClose: { showingBaselineUnitSheet = false },
            onUnitSelected: { selectedUnit in
              form.baselineUnit = selectedUnit
              showingBaselineUnitSheet = false
            },
            currentUnit: form.baselineUnit)
        }
        .sheet(isPresented: $showingBaselineFrequencySheet) {
          ScheduleBottomSheet(
            onClose: { showingBaselineFrequencySheet = false },
            onScheduleSelected: { selectedSchedule in
              form.baselineFrequency = selectedSchedule
              showingBaselineFrequencySheet = false
            },
            initialSchedule: form.baselineFrequency)
        }
        .sheet(isPresented: $showingTargetUnitSheet) {
          UnitBottomSheet(
            onClose: { showingTargetUnitSheet = false },
            onUnitSelected: { selectedUnit in
              form.targetUnit = selectedUnit
              showingTargetUnitSheet = false
            },
            currentUnit: form.targetUnit)
        }
        .sheet(isPresented: $showingTargetFrequencySheet) {
          ScheduleBottomSheet(
            onClose: { showingTargetFrequencySheet = false },
            onScheduleSelected: { selectedSchedule in
              form.targetFrequency = selectedSchedule.lowercased()
              showingTargetFrequencySheet = false
            },
            initialSchedule: form.targetFrequency)
        }
        // Update cached unit display values reactively
        .onChange(of: form.goalNumber) { _, newValue in
          goalUnitDisplay = computePluralizedUnit(for: newValue, unit: form.goalUnit)
        }
        .onChange(of: form.goalUnit) { _, newValue in
          goalUnitDisplay = computePluralizedUnit(for: form.goalNumber, unit: newValue)
        }
        .onChange(of: form.baselineNumber) { _, newValue in
          baselineUnitDisplay = computePluralizedUnit(for: newValue, unit: form.baselineUnit)
        }
        .onChange(of: form.baselineUnit) { _, newValue in
          baselineUnitDisplay = computePluralizedUnit(for: form.baselineNumber, unit: newValue)
        }
        .onChange(of: form.targetNumber) { _, newValue in
          targetUnitDisplay = computePluralizedUnit(for: newValue, unit: form.targetUnit)
        }
        .onChange(of: form.targetUnit) { _, newValue in
          targetUnitDisplay = computePluralizedUnit(for: form.targetNumber, unit: newValue)
        }

      }
      .navigationViewStyle(.stack)
    }
  }


  // MARK: - Top Navigation Bar

  private var topNavigationBar: some View {
    VStack(spacing: 0) {
      // Empty spacer for consistent padding (title now in navigation bar)
      Spacer()
        .frame(height: 0)
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
          form.selectedHabitType = .formation
        }) {
          HStack(spacing: 8) {
            if form.selectedHabitType == .formation {
              Image(systemName: "checkmark")
                .font(.appLabelSmallEmphasised)
                .foregroundColor(.onPrimary)
            }
            Text("Habit Building")
              .font(form.selectedHabitType == .formation ? .appLabelLargeEmphasised : .appLabelLarge)
              .foregroundColor(form.selectedHabitType == .formation ? .onPrimary : .onPrimaryContainer)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(form.selectedHabitType == .formation ? .primary : .primaryContainer)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(.outline3, lineWidth: 1.5))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)

        // Habit Breaking button
        Button(action: {
          form.selectedHabitType = .breaking
        }) {
          HStack(spacing: 8) {
            if form.selectedHabitType == .breaking {
              Image(systemName: "checkmark")
                .font(.appLabelSmallEmphasised)
                .foregroundColor(.onPrimary)
            }
            Text("Habit Breaking")
              .font(form.selectedHabitType == .breaking ? .appLabelLargeEmphasised : .appLabelLarge)
              .foregroundColor(form.selectedHabitType == .breaking ? .onPrimary : .onPrimaryContainer)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(form.selectedHabitType == .breaking ? .primary : .primaryContainer)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(.outline3, lineWidth: 1.5))
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
        .stroke(.outline3, lineWidth: 1.5))
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
        Text(form.reminders.isEmpty
          ? "Add"
          :
          "\(form.reminders.filter { $0.isActive }.count) reminder\(form.reminders.filter { $0.isActive }.count == 1 ? "" : "s")")
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

      if !form.reminders.isEmpty {
        Divider()
          .background(.outline3)
          .padding(.vertical, 4)

        VStack(spacing: 4) {
          ForEach(form.reminders.filter { $0.isActive }) { reminder in
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
        onReminderSelected: { _ in
          // Keep for backward compatibility
          showingReminderSheet = false
        },
        initialReminders: form.reminders,
        onRemindersUpdated: { updatedReminders in
          form.reminders = updatedReminders
          let activeReminders = updatedReminders.filter { $0.isActive }
          if !activeReminders.isEmpty {
            form.selectedReminder = "\(activeReminders.count) reminder\(activeReminders.count == 1 ? "" : "s")"
          } else {
            form.selectedReminder = "No reminder"
          }
          showingReminderSheet = false
        })
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
          showingStartDateSheet = true
        }) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Start Date")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
            Text(isToday(form.startDate) ? "Today" : formatDate(form.startDate))
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
            Text(form.endDate == nil
              ? "Not Selected"
              : (isToday(form.endDate!) ? "Today" : formatDate(form.endDate!)))
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
      action: saveHabit)
      .disabled(!hasChanges)
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
      .background(.surface2)
  }

  // MARK: - Custom TextField Component (same as CreateHabitStep1View)

  @ViewBuilder
  private func CustomTextField(
    placeholder: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding) -> some View
  {
    TextField(placeholder, text: text)
      .font(.appBodyLarge)
      .foregroundColor(.text01)
      .textFieldStyle(PlainTextFieldStyle())
      .submitLabel(.done)
      .frame(minHeight: 48)
      .padding(.horizontal, 16)
      .background(.surface)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(.outline3, lineWidth: 1.5))
      .cornerRadius(12)
      .fixedSize(horizontal: false, vertical: true)
      .focused(isFocused)
  }

  /// Helper function for selection rows with visual elements (matching create habit step 1)
  @ViewBuilder
  private func VisualSelectionRow(
    title: String,
    color: Color,
    icon: String? = nil,
    value: String,
    action: @escaping () -> Void) -> some View
  {
    if let icon {
      SelectionRowWithVisual(
        title: title,
        icon: icon,
        color: color,
        value: value,
        action: action)
    } else {
      SelectionRowWithVisual(
        title: title,
        color: color,
        value: value,
        action: action)
    }
  }

  // MARK: - Helper Functions

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func formatDate(_ date: Date) -> String {
    AppDateFormatter.shared.formatCreateHabitDate(date)
  }

  private func isToday(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date)
  }

  /// Helper function to handle pluralization for units
  private func pluralizedUnit(_ count: Int, unit: String) -> String {
    if unit == "time" || unit == "times" {
      return count == 1 ? "time" : "times"
    }
    return unit
  }
  
  private func scrollToField(_ target: ScrollTarget, with proxy: ScrollViewProxy) {
    withAnimation(.easeInOut(duration: 0.2)) {
      proxy.scrollTo(target, anchor: .center)
    }
  }

  private func resignAllFocus() {
    isNameFieldFocused = false
    isDescriptionFieldFocused = false
    isGoalNumberFocused = false
    isBaselineFieldFocused = false
    isTargetFieldFocused = false
  }

  // MARK: - Save Function

  private func saveHabit() {
    var updatedHabit: Habit

    if form.selectedHabitType == .formation {
      // NEW UNIFIED APPROACH - Habit Building
      let goalNumberInt = Int(form.goalNumber) ?? 1
      let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: form.goalUnit)
      let goalString = HabitFormLogic.formatGoalString(number: form.goalNumber, unit: pluralizedUnit, frequency: form.goalFrequency)

      // For habit building, schedule is derived from goal frequency
      let scheduleString = form.goalFrequency

      updatedHabit = Habit(
        name: form.habitName,
        description: form.habitDescription,
        icon: form.selectedIcon,
        color: form.selectedColor,
        habitType: form.selectedHabitType,
        schedule: scheduleString,
        goal: goalString,
        reminder: form.isReminderEnabled ? form.selectedReminder : "",
        startDate: form.startDate,
        endDate: form.endDate,
        reminders: form.reminders)
    } else {
      // NEW UNIFIED APPROACH - Habit Breaking
      let targetInt = Int(form.targetNumber) ?? 1
      let targetPluralizedUnit = pluralizedUnit(targetInt, unit: form.targetUnit)
      let goalString = HabitFormLogic.formatGoalString(number: form.targetNumber, unit: targetPluralizedUnit, frequency: form.targetFrequency)

      // For habit breaking, schedule is derived from target frequency
      let scheduleString = form.targetFrequency

      // ✅ FIX: Ensure baseline > target for breaking habits
      var baselineValue = Int(form.baselineNumber) ?? 0
      let targetValue = Int(form.targetNumber) ?? 0
      
      if baselineValue <= targetValue {
        baselineValue = max(targetValue + 5, 10)
      }

      updatedHabit = Habit(
        name: form.habitName,
        description: form.habitDescription,
        icon: form.selectedIcon,
        color: form.selectedColor,
        habitType: form.selectedHabitType,
        schedule: scheduleString,
        goal: goalString,
        reminder: form.isReminderEnabled ? form.selectedReminder : "",
        startDate: form.startDate,
        endDate: form.endDate,
        reminders: form.reminders,
        baseline: baselineValue,
        target: targetValue)
    }

    var updatedGoalHistory = originalHabit.goalHistory
    let startKey = Habit.dateKey(for: originalHabit.startDate)
    
    // ✅ CRITICAL FIX: Always ensure start date entry exists BEFORE adding new goal change entry
    // This preserves the original goal (1) for dates 12th-14th even after goal changes to 2 on 15th
    if updatedGoalHistory.isEmpty {
      // No history - initialize with start date goal
      updatedGoalHistory[startKey] = originalHabit.goal
    } else if !updatedGoalHistory.keys.contains(startKey) {
      // History exists but start date entry is missing - add it with original goal
      // Use the earliest entry's goal as original goal if it's before start date,
      // otherwise preserve the original goal value (which should be the start date goal)
      updatedGoalHistory[startKey] = originalHabit.goal
    }
    
    // Add new goal change entry if goal changed
    if originalHabit.goal != updatedHabit.goal {
      let todayKey = Habit.dateKey(for: Date())
      updatedGoalHistory[todayKey] = updatedHabit.goal
    }

    // Create a new habit with the original ID, preserving all existing completion data
    updatedHabit = Habit(
      id: originalHabit.id,
      name: updatedHabit.name,
      description: updatedHabit.description,
      icon: updatedHabit.icon,
      color: updatedHabit.color,
      habitType: updatedHabit.habitType,
      schedule: updatedHabit.schedule,
      goal: updatedHabit.goal,
      reminder: updatedHabit.reminder,
      startDate: updatedHabit.startDate,
      endDate: form.endDate,
      createdAt: originalHabit.createdAt, // Preserve original creation date
      reminders: updatedHabit.reminders,
      baseline: updatedHabit.baseline,
      target: updatedHabit.target,
      completionHistory: originalHabit.completionHistory, // Preserve original completion history
      completionStatus: originalHabit.completionStatus, // Preserve historical completion status
      completionTimestamps: originalHabit.completionTimestamps, // Preserve recorded completion times
      difficultyHistory: originalHabit.difficultyHistory, // Preserve original difficulty history
      actualUsage: originalHabit.actualUsage, // Preserve original usage data
      goalHistory: updatedGoalHistory
    )

    // ✅ PHASE 4: Completion status is now computed-only, no need to recalculate
    // Completion status is derived from completion history in real-time

    // Update notifications for the habit
    NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: form.reminders)

    onSave(updatedHabit)
    dismiss()
  }

  // MARK: - Helper Functions

  private func getIconDisplayName(_ icon: String) -> String {
    icon == "None" ? "None" : ""
  }

  private func getColorDisplayName(_ color: Color) -> String {
    // Use the same color definitions as ColorBottomSheet for consistency
    let colors: [(color: Color, name: String)] = [
      (Color(hex: "222222"), "Black"),
      (.primary, "Navy"),
      (Color(hex: "6096FD"), "Blue"),
      (Color(hex: "CB30E0"), "Purple"),
      (Color(hex: "FF7838"), "Orange"),
      (Color(hex: "34C759"), "Green"),
      (Color(hex: "21EAF1"), "Teal")
    ]

    // Find the matching color and return its name
    for (colorOption, name) in colors {
      if color == colorOption {
        return name
      }
    }

    return "Navy" // Default fallback to match CreateHabitStep1View
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
    endDate: nil), onSave: { _ in })
}
