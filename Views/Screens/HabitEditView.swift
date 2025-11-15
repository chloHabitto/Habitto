import MCEmojiPicker
import SwiftUI

struct HabitEditView: View {
  // MARK: Lifecycle

  init(habit: Habit, onSave: @escaping (Habit) -> Void) {
    self.habit = habit
    self.onSave = onSave

    self._habitName = State(initialValue: habit.name)
    self._habitDescription = State(initialValue: habit.description)
    self._selectedIcon = State(initialValue: habit.icon)
    self._selectedColor = State(initialValue: habit.color.color)
    self._selectedHabitType = State(initialValue: habit.habitType)
    self._selectedSchedule = State(initialValue: habit.schedule)
    self._selectedReminder = State(initialValue: habit.reminder)
    self._isReminderEnabled = State(initialValue: !habit.reminder.isEmpty)
    self._reminders = State(initialValue: habit.reminders)
    self._startDate = State(initialValue: habit.startDate)
    self._endDate = State(initialValue: habit.endDate)

    // Initialize goal/baseline/target data from saved habit
    let today = LegacyDateUtils.today()
    let todayGoalString = habit.goalString(for: today)

    if habit.habitType == .formation {
      // Parse habit building goal data from habit.goal string
      let parsedGoal = Self.parseGoalString(todayGoalString)
      print(
        "🔍 EDIT INIT - Habit Building: \(todayGoalString) → number: \(parsedGoal.number), unit: \(parsedGoal.unit), frequency: \(parsedGoal.frequency)")
      self._goalNumber = State(initialValue: parsedGoal.number)
      self._goalUnit = State(initialValue: parsedGoal.unit)
      self._goalFrequency = State(initialValue: parsedGoal.frequency)

      // Set defaults for unused fields
      self._baselineNumber = State(initialValue: "1")
      self._baselineUnit = State(initialValue: "time")
      self._baselineFrequency = State(initialValue: "everyday")
      self._targetNumber = State(initialValue: "1")
      self._targetUnit = State(initialValue: "time")
      self._targetFrequency = State(initialValue: "everyday")
    } else {
      // Parse habit breaking data from habit.goal string and habit properties
      let parsedGoal = Self.parseGoalString(todayGoalString)
      print(
        "🔍 EDIT INIT - Habit Breaking: \(todayGoalString) → number: \(parsedGoal.number), unit: \(parsedGoal.unit), frequency: \(parsedGoal.frequency)")
      print("🔍 EDIT INIT - Schedule: \(habit.schedule), Baseline: \(habit.baseline)")

      // For habit breaking, goal string contains target info
      self._targetNumber = State(initialValue: parsedGoal.number)
      self._targetUnit = State(initialValue: parsedGoal.unit)
      self
        ._targetFrequency = State(initialValue: parsedGoal.frequency) // Frequency from goal string

      // Use baseline from habit properties
      self._baselineNumber = State(initialValue: String(habit.baseline))
      self._baselineUnit = State(initialValue: parsedGoal.unit) // Assume same unit
      self._baselineFrequency = State(initialValue: "everyday") // Default, not used for schedule

      // Set defaults for unused goal fields
      self._goalNumber = State(initialValue: "1")
      self._goalUnit = State(initialValue: "time")
      self._goalFrequency = State(initialValue: "everyday")
    }
  }

  // MARK: Internal

  let habit: Habit
  let onSave: (Habit) -> Void

  var body: some View {
    mainViewWithSheets
  }

  // MARK: - Static Helper Functions

  static func sortFrequencyChronologically(_ frequency: String) -> String {
    // Sort weekdays in chronological order for display
    // e.g., "every friday, every monday" → "every monday, every friday"

    let lowercasedFrequency = frequency.lowercased()

    // Check if it contains multiple weekdays
    if lowercasedFrequency.contains("every"), lowercasedFrequency.contains(",") {
      // Extract individual day phrases
      let dayPhrases = frequency.components(separatedBy: ", ")

      // Sort by weekday order
      let weekdayOrder = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday"
      ]

      let sortedPhrases = dayPhrases.sorted { phrase1, phrase2 in
        let lowercased1 = phrase1.lowercased()
        let lowercased2 = phrase2.lowercased()

        // Find which weekday each phrase contains
        let day1Index = weekdayOrder.firstIndex { lowercased1.contains($0) } ?? 99
        let day2Index = weekdayOrder.firstIndex { lowercased2.contains($0) } ?? 99

        return day1Index < day2Index
      }

      return sortedPhrases.joined(separator: ", ")
    }

    // Return as-is if it's not a multi-day weekday frequency
    return frequency
  }

  static func parseGoalString(_ goalString: String)
    -> (number: String, unit: String, frequency: String)
  {
    // Goal strings are in format:
    // Habit Building: "3 times on everyday" or "1 time on monday"
    // Habit Breaking: "1 time on everyday" or "2 times on monday" (changed from "per" to "on")
    // Legacy Habit Breaking: "1 time per everyday" (support old format)

    // Extract number (first part)
    let components = goalString.components(separatedBy: " ")
    let number = components.first ?? "1"

    // Extract unit and frequency
    if goalString.contains(" on ") {
      // Both habit building and new habit breaking format: "3 times on everyday"
      let parts = goalString.components(separatedBy: " on ")
      let beforeOn = parts[0] // "3 times"
      let rawFrequency = parts.count > 1 ? parts[1] : "everyday"

      // Sort and format frequency before returning
      let sortedFrequency = sortFrequencyChronologically(rawFrequency)
      let frequency = formatFrequencyText(sortedFrequency)

      // Extract unit from "3 times"
      let unitComponents = beforeOn.components(separatedBy: " ")
      let unit = unitComponents.count > 1 ? unitComponents[1] : "time"

      return (number: number, unit: unit, frequency: frequency)
    } else if goalString.contains(" per ") {
      // Legacy habit breaking format: "1 time per everyday" (for backward compatibility)
      let parts = goalString.components(separatedBy: " per ")
      let beforePer = parts[0] // "1 time"
      let rawFrequency = parts.count > 1 ? parts[1] : "everyday"

      // Sort and format frequency before returning
      let sortedFrequency = sortFrequencyChronologically(rawFrequency)
      let frequency = formatFrequencyText(sortedFrequency)

      // Extract unit from "1 time"
      let unitComponents = beforePer.components(separatedBy: " ")
      let unit = unitComponents.count > 1 ? unitComponents[1] : "time"

      return (number: number, unit: unit, frequency: frequency)
    } else {
      // Fallback for unknown format
      return (number: "1", unit: "time", frequency: "everyday")
    }
  }
  
  /// Converts old frequency formats to new standardized formats
  static func formatFrequencyText(_ frequency: String) -> String {
    let lowerFreq = frequency.lowercased()
    
    // Check for "X day(s) a week" patterns
    if lowerFreq.contains("day a week") || lowerFreq.contains("days a week") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*week"#, options: .caseInsensitive),
         let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count)) {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
           let number = Int(frequency[numberRange]) {
          switch number {
          case 1: return "once a week"
          case 2: return "twice a week"
          case 7: return "everyday"
          default: return "\(number) days a week"
          }
        }
      }
    }
    
    // Check for "X day(s) a month" patterns
    if lowerFreq.contains("day a month") || lowerFreq.contains("days a month") {
      if let regex = try? NSRegularExpression(pattern: #"(\d+)\s*days?\s*a\s*month"#, options: .caseInsensitive),
         let match = regex.firstMatch(in: frequency, options: [], range: NSRange(location: 0, length: frequency.count)) {
        let range = match.range(at: 1)
        if let numberRange = Range(range, in: frequency),
           let number = Int(frequency[numberRange]) {
          switch number {
          case 1: return "once a month"
          case 2: return "twice a month"
          default: return "\(number) days a month"
          }
        }
      }
    }
    
    return frequency
  }

  // MARK: Private

  /// Custom modifier to handle focus and tap gesture
  private struct FocusModifier: ViewModifier {
    let isFocused: FocusState<Bool>.Binding?
    let showTapGesture: Bool

    func body(content: Content) -> some View {
      if let isFocused {
        content
          .focused(isFocused)
          .onTapGesture {
            // Only focus if explicitly requested via showTapGesture
            if showTapGesture {
              isFocused.wrappedValue = true
            }
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

  @FocusState private var isGoalNumberFocused: Bool
  @FocusState private var isBaselineFieldFocused: Bool
  @FocusState private var isTargetFieldFocused: Bool

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
  @State private var goalNumber = "1"
  @State private var goalUnit = "time"
  @State private var goalFrequency = "everyday"
  @State private var baselineNumber = "1"
  @State private var baselineUnit = "time"
  @State private var baselineFrequency = "everyday"
  @State private var targetNumber = "1"
  @State private var targetUnit = "time"
  @State private var targetFrequency = "everyday"
  @State private var showingGoalUnitSheet = false
  @State private var showingGoalFrequencySheet = false
  @State private var showingBaselineUnitSheet = false
  @State private var showingBaselineFrequencySheet = false
  @State private var showingTargetUnitSheet = false
  @State private var showingTargetFrequencySheet = false

  /// Force UI updates when number changes
  @State private var uiUpdateTrigger = false

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

  /// Computed property to check if any changes have been made
  private var hasChanges: Bool {
    // Check basic fields
    let basicChanges = habitName != habit.name ||
      habitDescription != habit.description ||
      selectedIcon != habit.icon ||
      selectedColor != habit.color.color ||
      selectedHabitType != habit.habitType ||
      selectedReminder != habit.reminder ||
      reminders != habit.reminders ||
      startDate != habit.startDate ||
      endDate != habit.endDate

    // Check schedule changes (different logic for habit building vs breaking)
    let scheduleChanges: Bool = if selectedHabitType == .formation {
      // For habit building, schedule is derived from goal frequency
      goalFrequency != habit.schedule
    } else {
      // For habit breaking, schedule is derived from baseline frequency
      baselineFrequency != habit.schedule
    }

    // Check unified approach fields
    var unifiedChanges = false

    if selectedHabitType == .formation {
      // For habit building, check goal fields
      let currentGoal = "\(goalNumber) \(pluralizedGoalUnit) on \(goalFrequency)"
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

  /// NEW Unified computed properties
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

  /// NEW Unified computed properties for validation
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
    return number >= 0 // Allow 0 for reduction goal in habit breaking
  }

  /// Overall form validation
  private var isFormValid: Bool {
    if selectedHabitType == .formation {
      isGoalValid
    } else {
      isBaselineValid && isTargetValid
    }
  }

  // MARK: - Main Content Views

  @ViewBuilder
  private var mainContent: some View {
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
    .contentShape(Rectangle())
    .onTapGesture {
      // Dismiss keyboard when tapping background
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil)
    }
  }

  @ViewBuilder
  private var basicInfoSection: some View {
    VStack(spacing: 16) {
      // Habit Name
      CustomTextField(
        placeholder: "Name",
        text: $habitName,
        isFocused: $isNameFieldFocused,
        showTapGesture: false)

      // Description
      CustomTextField(
        placeholder: "Description (Optional)",
        text: $habitDescription,
        isFocused: $isDescriptionFieldFocused,
        showTapGesture: false)

      // Color Selection (moved before Icon to match creation flow)
      VisualSelectionRow(
        title: "Colour",
        color: selectedColor,
        value: getColorDisplayName(selectedColor),
        action: { showingColorSheet = true })

      // Icon Selection (moved after Color to match creation flow)
      VisualSelectionRow(
        title: "Icon",
        color: selectedColor,
        icon: selectedIcon,
        value: getIconDisplayName(selectedIcon),
        action: { showingEmojiPicker = true })

      // Habit Type
      habitTypeSection
    }
  }

  @ViewBuilder
  private var goalSection: some View {
    // Goal - NEW UNIFIED APPROACH
    if selectedHabitType == .formation {
      UnifiedInputElement(
        title: "Goal",
        description: "What do you want to achieve?",
        numberText: $goalNumber,
        unitText: pluralizedGoalUnit,
        frequencyText: goalFrequency,
        isValid: isGoalValid,
        errorMessage: "Please enter a number greater than 0",
        onUnitTap: { showingGoalUnitSheet = true },
        onFrequencyTap: { showingGoalFrequencySheet = true },
        uiUpdateTrigger: uiUpdateTrigger,
        isFocused: $isGoalNumberFocused)
    } else {
      // Habit Breaking Form
      VStack(spacing: 16) {
        // Baseline - NEW UNIFIED APPROACH
        UnifiedInputElement(
          title: "Current",
          description: "How much do you currently do?",
          numberText: $baselineNumber,
          unitText: pluralizedBaselineUnit,
          frequencyText: baselineFrequency,
          isValid: isBaselineValid,
          errorMessage: "Please enter a number greater than 0",
          onUnitTap: { showingBaselineUnitSheet = true },
          onFrequencyTap: { showingBaselineFrequencySheet = true },
          uiUpdateTrigger: uiUpdateTrigger,
          isFocused: $isBaselineFieldFocused)

        // Target - NEW UNIFIED APPROACH
        UnifiedInputElement(
          title: "Goal",
          description: "How much do you want to reduce to?",
          numberText: $targetNumber,
          unitText: pluralizedTargetUnit,
          frequencyText: targetFrequency,
          isValid: isTargetValid,
          errorMessage: "Please enter a number greater than or equal to 0",
          onUnitTap: { showingTargetUnitSheet = true },
          onFrequencyTap: { showingTargetFrequencySheet = true },
          uiUpdateTrigger: uiUpdateTrigger,
          isFocused: $isTargetFieldFocused)
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
              Button("Done") {
                dismiss()
              }
              .foregroundColor(.primary)
            }
          }
          .navigationTitle("Edit habit")
          .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isNameFieldFocused) { oldValue, newValue in
          print("🔍 HabitEditView: Name field focus changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: isDescriptionFieldFocused) { oldValue, newValue in
          print("🔍 HabitEditView: Description field focus changed from \(oldValue) to \(newValue)")
        }
        .sheet(isPresented: $showingEmojiPicker) {
          EmojiKeyboardBottomSheet(
            selectedEmoji: $selectedIcon,
            onClose: {
              showingEmojiPicker = false
            },
            onSave: { emoji in
              selectedIcon = emoji
              showingEmojiPicker = false
            })
        }
        .sheet(isPresented: $showingColorSheet) {
          ColorBottomSheet(
            onClose: { showingColorSheet = false },
            onColorSelected: { color in
              selectedColor = color
            },
            onSave: { color in
              selectedColor = color
              showingColorSheet = false
            })
        }
        .sheet(isPresented: $showingScheduleSheet) {
          ScheduleBottomSheet(
            onClose: { showingScheduleSheet = false },
            onScheduleSelected: { schedule in
              selectedSchedule = schedule
              showingScheduleSheet = false
            },
            initialSchedule: selectedSchedule)
        }
        .sheet(isPresented: $showingReminderSheet) {
          ReminderBottomSheet(
            onClose: { showingReminderSheet = false },
            onReminderSelected: { reminder in
              selectedReminder = reminder
              showingReminderSheet = false
            },
            onRemindersUpdated: { _ in })
        }
        .sheet(isPresented: $showingStartDateSheet) {
          PeriodBottomSheet(
            isSelectingStartDate: true,
            startDate: startDate,
            initialDate: startDate,
            onStartDateSelected: { date in
              startDate = date
              showingStartDateSheet = false
            },
            onEndDateSelected: { _ in }, // Not used for start date
            onRemoveEndDate: nil)
        }
        .sheet(isPresented: $showingEndDateSheet) {
          PeriodBottomSheet(
            isSelectingStartDate: false,
            startDate: startDate,
            initialDate: endDate ?? Date(),
            onStartDateSelected: { _ in }, // Not used for end date
            onEndDateSelected: { date in
              endDate = date
              showingEndDateSheet = false
            },
            onRemoveEndDate: {
              endDate = nil
              showingEndDateSheet = false
            })
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
              targetFrequency = selectedSchedule.lowercased()
              showingTargetFrequencySheet = false
            },
            initialSchedule: targetFrequency)
        }

      }
      .navigationViewStyle(.stack)
    }
  }

  @ViewBuilder
  private var allSheets: some View {
    sheet(isPresented: $showingColorSheet) {
      ColorBottomSheet(
        onClose: { showingColorSheet = false },
        onColorSelected: { color in
          selectedColor = color
        },
        onSave: { color in
          selectedColor = color
          showingColorSheet = false
        })
    }
    .sheet(isPresented: $showingScheduleSheet) {
      ScheduleBottomSheet(
        onClose: { showingScheduleSheet = false },
        onScheduleSelected: { schedule in
          selectedSchedule = schedule
          showingScheduleSheet = false
        },
        initialSchedule: selectedSchedule)
    }

    // NEW UNIFIED APPROACH - Frequency sheets
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
          targetFrequency = selectedSchedule
          showingTargetFrequencySheet = false
        },
        initialSchedule: targetFrequency)
    }

    .sheet(isPresented: $showingReminderSheet) {
      ReminderBottomSheet(
        onClose: { showingReminderSheet = false },
        onReminderSelected: { reminder in
          selectedReminder = reminder
          showingReminderSheet = false
        },
        onRemindersUpdated: { _ in })
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

        // IMPORTANT: Initialize goalFrequency from the habit's schedule if it's a frequency-based schedule
        if habit.schedule.contains("days a week") || habit.schedule.contains("days a month") {
          goalFrequency = habit.schedule
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
    }
    .onChange(of: goalNumber) { _, _ in
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
              .stroke(.outline3, lineWidth: 1.5))
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
        Text(reminders.isEmpty
          ? "Add"
          :
          "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")")
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
          .background(.outline3)
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
        onReminderSelected: { _ in
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
            Text(endDate == nil
              ? "Not Selected"
              : (isToday(endDate!) ? "Today" : formatDate(endDate!)))
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

  private func CustomTextField(
    placeholder: String,
    text: Binding<String>,
    isFocused: FocusState<Bool>.Binding? = nil,
    showTapGesture: Bool = false) -> some View
  {
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
          .stroke(.outline3, lineWidth: 1.5))
      .cornerRadius(12)
      .contentShape(Rectangle())
      .allowsHitTesting(true)
      .modifier(FocusModifier(isFocused: isFocused, showTapGesture: showTapGesture))
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

  // MARK: - Save Function

  private func saveHabit() {
    var updatedHabit: Habit

    if selectedHabitType == .formation {
      // NEW UNIFIED APPROACH - Habit Building
      let goalNumberInt = Int(goalNumber) ?? 1
      let pluralizedUnit = pluralizedUnit(goalNumberInt, unit: goalUnit)
      let goalString = HabitFormLogic.formatGoalString(number: goalNumber, unit: pluralizedUnit, frequency: goalFrequency)

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
        reminders: reminders)
    } else {
      // NEW UNIFIED APPROACH - Habit Breaking
      let targetInt = Int(targetNumber) ?? 1
      let targetPluralizedUnit = pluralizedUnit(targetInt, unit: targetUnit)
      let goalString = HabitFormLogic.formatGoalString(number: targetNumber, unit: targetPluralizedUnit, frequency: targetFrequency)

      // For habit breaking, schedule is derived from target frequency
      let scheduleString = targetFrequency

      // ✅ FIX: Ensure baseline > target for breaking habits
      var baselineValue = Int(baselineNumber) ?? 0
      let targetValue = Int(targetNumber) ?? 0
      
      if baselineValue <= targetValue {
        baselineValue = max(targetValue + 5, 10)
        print("⚠️ EDIT SAVE - Baseline (\(Int(baselineNumber) ?? 0)) <= target (\(targetValue))")
        print("✅ EDIT SAVE - Auto-adjusted baseline to \(baselineValue) for breaking habit '\(habitName)'")
      }

      print(
        "🔍 EDIT SAVE - Habit Breaking: goalString: \(goalString), scheduleString: \(scheduleString)")
      print(
        "🔍 EDIT SAVE - Target: \(targetValue), Baseline: \(baselineValue)")

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
        reminders: reminders,
        baseline: baselineValue,
        target: targetValue)
    }

    var updatedGoalHistory = habit.goalHistory
    if updatedGoalHistory.isEmpty {
      let startKey = Habit.dateKey(for: habit.startDate)
      updatedGoalHistory[startKey] = habit.goal
    }
    if habit.goal != updatedHabit.goal {
      let todayKey = Habit.dateKey(for: Date())
      updatedGoalHistory[todayKey] = updatedHabit.goal
    }

    // Create a new habit with the original ID, preserving all existing completion data
    updatedHabit = Habit(
      id: habit.id,
      name: updatedHabit.name,
      description: updatedHabit.description,
      icon: updatedHabit.icon,
      color: updatedHabit.color,
      habitType: updatedHabit.habitType,
      schedule: updatedHabit.schedule,
      goal: updatedHabit.goal,
      reminder: updatedHabit.reminder,
      startDate: updatedHabit.startDate,
      endDate: endDate,
      createdAt: habit.createdAt, // Preserve original creation date
      reminders: updatedHabit.reminders,
      baseline: updatedHabit.baseline,
      target: updatedHabit.target,
      completionHistory: habit.completionHistory, // Preserve original completion history
      completionStatus: habit.completionStatus, // Preserve historical completion status
      completionTimestamps: habit.completionTimestamps, // Preserve recorded completion times
      difficultyHistory: habit.difficultyHistory, // Preserve original difficulty history
      actualUsage: habit.actualUsage, // Preserve original usage data
      goalHistory: updatedGoalHistory
    )

    // ✅ PHASE 4: Completion status is now computed-only, no need to recalculate
    // Completion status is derived from completion history in real-time

    // Update notifications for the habit
    NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: reminders)

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
      (Color(hex: "FF2D55"), "Red"),
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
