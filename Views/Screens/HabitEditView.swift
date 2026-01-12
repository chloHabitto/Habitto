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
        VStack(spacing: 12) {
          basicInfoSection
          goalSection
          reminderAndPeriodSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 100) // Add bottom padding to account for fixed button
      }
      .background(Color("appSurface01Variant02"))
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
    VStack(spacing: 12) {
      // Name field - container with surface background and stroke (matching CreateHabitStep1View)
      VStack(alignment: .leading, spacing: 12) {
        FormInputComponents.FormSectionHeader(title: "Name")
        
        CustomTextField(
          placeholder: "Habit name",
          text: $form.habitName,
          isFocused: $isNameFieldFocused)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.appSurface01Variant)
      .cornerRadius(20)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)

      // Description field - container with surface background and stroke (matching CreateHabitStep1View)
      VStack(alignment: .leading, spacing: 12) {
        FormInputComponents.FormSectionHeader(title: "Description")
        
        CustomTextField(
          placeholder: "Description (Optional)",
          text: $form.habitDescription,
          isFocused: $isDescriptionFieldFocused)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(.appSurface01Variant)
      .cornerRadius(20)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)

      // Colour selection (matching CreateHabitStep1View)
      HStack(spacing: 12) {
        Text("Colour")
          .font(.appTitleMedium)
          .foregroundColor(.text02)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          RoundedRectangle(cornerRadius: 12)
            .fill(form.selectedColor)
            .frame(width: 24, height: 24)
          Text(getColorDisplayName(form.selectedColor))
            .font(.appBodyMedium)
            .foregroundColor(.appText04)
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(.appOutline03)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(.appSurface01Variant)
      .cornerRadius(16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
      .onTapGesture {
        showingColorSheet = true
      }

      // Icon selection (matching CreateHabitStep1View)
      HStack(spacing: 12) {
        Text("Icon")
          .font(.appTitleMedium)
          .foregroundColor(.text01)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          if form.selectedIcon != "None" {
            ZStack {
              RoundedRectangle(cornerRadius: 12)
                .fill(form.selectedColor.opacity(0.15))
                .frame(width: 24, height: 24)

              if form.selectedIcon.hasPrefix("Icon-") {
                Image(form.selectedIcon)
                  .resizable()
                  .frame(width: 14, height: 14)
                  .foregroundColor(form.selectedColor)
              } else {
                Text(form.selectedIcon)
                  .font(.system(size: 14))
              }
            }
          } else {
            // Placeholder rectangle to maintain consistent height
            RoundedRectangle(cornerRadius: 12)
              .fill(.clear)
              .frame(width: 24, height: 24)
          }
          Text(getIconDisplayName(form.selectedIcon))
            .font(.appBodyMedium)
            .foregroundColor(.appText04)
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(.appOutline03)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(.appSurface01Variant)
      .cornerRadius(16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
      .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
      .onTapGesture {
        showingEmojiPicker = true
      }

      // Habit Type (matching CreateHabitStep1View)
      habitTypeSection
    }
  }

  @ViewBuilder
  private var goalSection: some View {
    // Goal - NEW UNIFIED APPROACH (matching CreateHabitStep2View spacing)
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
      // Habit Breaking Form (matching CreateHabitStep2View spacing)
      VStack(spacing: 12) {
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
    VStack(spacing: 12) {
      // Reminder Section (using same component as CreateHabitStep2View)
      ReminderSection(
        reminders: form.reminders,
        onTap: { showingReminderSheet = true })

      // Period Section (using same component as CreateHabitStep2View)
      PeriodSection(
        startDate: form.startDate,
        endDate: form.endDate,
        onStartDateTap: { showingStartDateSheet = true },
        onEndDateTap: { showingEndDateSheet = true })
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
          .background(Color("appSurface01Variant02"))
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
            },
            initialColor: form.selectedColor)
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
        .foregroundColor(.text02)

      HStack(spacing: 12) {
        // Habit Building button
        FormInputComponents.HabitTypeButton(
          title: "Habit Building",
          isSelected: form.selectedHabitType == .formation,
          action: { form.selectedHabitType = .formation })

        // Habit Breaking button
        FormInputComponents.HabitTypeButton(
          title: "Habit Breaking",
          isSelected: form.selectedHabitType == .breaking,
          action: { form.selectedHabitType = .breaking })
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(.appSurface01Variant)
    .cornerRadius(20)
    .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 1, x: 0, y: 1)
    .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.04), radius: 2, x: 0, y: 4)
    .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.02), radius: 2.5, x: 0, y: 9)
    .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0.01), radius: 2, x: 0, y: 16)
    .shadow(color: Color(red: 0.62, green: 0.62, blue: 0.64).opacity(0), radius: 3.5, x: 0, y: 25)
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

  // MARK: - Custom TextField Component (matching CreateHabitStep1View LimitedTextField styling)

  @ViewBuilder
  private func CustomTextField(
    placeholder: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding) -> some View
  {
    ZStack(alignment: .leading) {
      // Placeholder text
      if text.wrappedValue.isEmpty {
        Text(placeholder)
          .font(.appBodyLarge)
          .foregroundColor(.text05)
      }
      // Actual text field
      TextField("", text: text)
        .font(.appBodyLarge)
        .foregroundColor(.text01)
        .textFieldStyle(PlainTextFieldStyle())
        .submitLabel(.done)
        .focused(isFocused)
    }
    .frame(maxWidth: .infinity, minHeight: 48)
    .padding(.horizontal, 16)
    .background(.appSurface01)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.outline02, lineWidth: 1.5))
    .cornerRadius(12)
  }


  // MARK: - Helper Functions

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
      (Color("pastelYellow"), "Yellow"),
      (Color("pastelBlue"), "Blue"),
      (Color("pastelPurple"), "Purple")
    ]

    // Find the matching color and return its name
    for (colorOption, name) in colors {
      if color == colorOption {
        return name
      }
    }

    return "Blue" // Default fallback to pastelBlue
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
