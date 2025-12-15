import SwiftUI

// MARK: - UnifiedInputElement

struct UnifiedInputElement: View {
  let title: String
  let description: String
  @Binding var numberText: String
  let unitText: String
  let frequencyText: String
  let isValid: Bool
  let errorMessage: String
  let onUnitTap: () -> Void
  let onFrequencyTap: () -> Void
  @FocusState.Binding var isFocused: Bool

  var body: some View {
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
        // Number input field - using direct @FocusState binding
        TextField("1", text: $numberText)
          .font(.appBodyLarge)
          .foregroundColor(.text01)
          .accentColor(.text01)
          .keyboardType(.numberPad) // Back to .numberPad - toolbar will work
          .focused($isFocused)
          .multilineTextAlignment(.center)
          .frame(minWidth: 44, idealWidth: 56, maxWidth: 72)
          .animation(.none, value: isFocused)
          .inputFieldStyle()

        // Unit selector button - smaller width
        Button(action: onUnitTap) {
          HStack {
            Text(unitText)
              .font(.appBodyLarge)
              .foregroundColor(isValid ? .text04 : .text06)
            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.primaryDim)
          }
          .frame(minWidth: 70)
          .fixedSize(horizontal: true, vertical: false)
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

      // Descriptive text showing what the user has selected (for Goal and Current)
      if title == "Goal" {
        Text(formatGoalSentence(numberText: numberText, unitText: unitText, frequencyText: frequencyText))
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color(hex: "1C274C").opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.top, 8)
      } else if title == "Current" {
        Text(formatCurrentSentence(numberText: numberText, unitText: unitText, frequencyText: frequencyText))
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color(hex: "1C274C").opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.top, 8)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(.appSurface)
    .cornerRadius(20)
  }
}

// MARK: - ReminderSection

struct ReminderSection: View {
  // MARK: Internal

  let reminders: [ReminderItem]
  let onTap: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Main reminder row
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
      .onTapGesture {
        onTap()
      }

      // Reminder details inside the same container
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
  }

  // MARK: Private

  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()

  private func formatTime(_ date: Date) -> String {
    timeFormatter.string(from: date)
  }
}

// MARK: - PeriodSection

struct PeriodSection: View {
  // MARK: Internal

  let startDate: Date
  let endDate: Date?
  let onStartDateTap: () -> Void
  let onEndDateTap: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Period")
        .font(.appTitleMedium)
        .foregroundColor(.text01)

      HStack(spacing: 12) {
        // Start Date
        Button(action: onStartDateTap) {
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
        Button(action: onEndDateTap) {
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
  }

  // MARK: Private

  private let calendar = Calendar.current

  private func formatDate(_ date: Date) -> String {
    AppDateFormatter.shared.formatCreateHabitDate(date)
  }

  private func isToday(_ date: Date) -> Bool {
    calendar.isDateInToday(date)
  }
}

// MARK: - HabitBuildingForm

struct HabitBuildingForm: View {
  @Binding var goalNumber: String
  let pluralizedGoalUnit: String
  let goalFrequency: String
  let isGoalValid: Bool
  let onGoalUnitTap: () -> Void
  let onGoalFrequencyTap: () -> Void
  let reminderSection: ReminderSection
  let periodSection: PeriodSection
  @FocusState.Binding var isGoalNumberFocused: Bool

  var body: some View {
    VStack(spacing: 16) {
      // Goal
      UnifiedInputElement(
        title: "Goal",
        description: "What do you want to achieve?",
        numberText: $goalNumber,
        unitText: pluralizedGoalUnit,
        frequencyText: goalFrequency,
        isValid: isGoalValid,
        errorMessage: "Please enter a number greater than 0",
        onUnitTap: onGoalUnitTap,
        onFrequencyTap: onGoalFrequencyTap,
        isFocused: $isGoalNumberFocused)

      // Reminder
      reminderSection

      // Period
      periodSection
        .selectionRowStyle()
    }
  }
}

// MARK: - HabitBreakingForm

struct HabitBreakingForm: View {
  @Binding var baselineNumber: String
  @Binding var targetNumber: String
  let pluralizedBaselineUnit: String
  let pluralizedTargetUnit: String
  let baselineFrequency: String
  let targetFrequency: String
  let isBaselineValid: Bool
  let isTargetValid: Bool
  let onBaselineUnitTap: () -> Void
  let onBaselineFrequencyTap: () -> Void
  let onTargetUnitTap: () -> Void
  let onTargetFrequencyTap: () -> Void
  let reminderSection: ReminderSection
  let periodSection: PeriodSection
  @FocusState.Binding var isBaselineFieldFocused: Bool
  @FocusState.Binding var isTargetFieldFocused: Bool

  var body: some View {
    VStack(spacing: 16) {
      // Current
      UnifiedInputElement(
        title: "Current",
        description: "How much do you currently do?",
        numberText: $baselineNumber,
        unitText: pluralizedBaselineUnit,
        frequencyText: baselineFrequency,
        isValid: isBaselineValid,
        errorMessage: "Please enter a number greater than 0",
        onUnitTap: onBaselineUnitTap,
        onFrequencyTap: onBaselineFrequencyTap,
        isFocused: $isBaselineFieldFocused)

      // Goal
      UnifiedInputElement(
        title: "Goal",
        description: "How much do you want to reduce to?",
        numberText: $targetNumber,
        unitText: pluralizedTargetUnit,
        frequencyText: targetFrequency,
        isValid: isTargetValid,
        errorMessage: "Please enter a number greater than or equal to 0",
        onUnitTap: onTargetUnitTap,
        onFrequencyTap: onTargetFrequencyTap,
        isFocused: $isTargetFieldFocused)

      // Reminder
      reminderSection

      // Period
      periodSection
        .selectionRowStyle()
    }
  }
}

// MARK: - FormActionButtons

struct FormActionButtons: View {
  // MARK: Internal

  let isFormValid: Bool
  let primaryColor: Color
  let onBack: () -> Void
  let onSave: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onBack) {
        Image(.iconLeftArrow)
          .resizable()
          .frame(width: 24, height: 24)
          .foregroundColor(.onPrimaryContainer)
          .frame(width: 48, height: 48)
          .background(.primaryContainer)
          .clipShape(Circle())
      }

      Spacer()

      Button(action: onSave) {
        Text("Save")
          .font(.appButtonText1)
          .foregroundColor(isFormValid ? .white : .text06)
          .frame(width: screenWidth * 0.5)
          .padding(.vertical, 16)
          .background(isFormValid ? .primary : .disabledBackground)
          .clipShape(Capsule())
      }
      .disabled(!isFormValid)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
    .background(.appSheetBackground)
  }

  // MARK: Private

  private let screenWidth = UIScreen.main.bounds.width
}

// MARK: - Helper Functions

/// Formats multiple "Every [Day]" entries into "every Monday, Wednesday & Friday" format
private func formatMultipleDays(_ frequencyText: String) -> String {
  let lowerFrequency = frequencyText.lowercased()
  
  // Check if it contains multiple "every [day]" patterns
  if lowerFrequency.contains(", ") && lowerFrequency.contains("every ") {
    // Split by comma and extract day names
    let parts = frequencyText.components(separatedBy: ", ")
    var days: [String] = []
    
    for part in parts {
      let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedLower = trimmed.lowercased()
      
      // Remove "Every " or "every " prefix and get the day name
      if trimmed.hasPrefix("Every ") {
        let dayName = String(trimmed.dropFirst(6)) // Remove "Every "
        days.append(dayName)
      } else if trimmedLower.hasPrefix("every ") {
        let dayName = String(trimmed.dropFirst(6)) // Remove "every "
        // Capitalize first letter only (e.g., "monday" -> "Monday")
        days.append(dayName.prefix(1).uppercased() + dayName.dropFirst())
      } else {
        // If it doesn't match the pattern, return original (lowercased)
        return frequencyText.lowercased()
      }
    }
    
    // Format as "every Monday, Wednesday & Friday"
    if days.isEmpty {
      return frequencyText.lowercased()
    } else if days.count == 1 {
      return "every \(days[0])"
    } else if days.count == 2 {
      return "every \(days[0]) & \(days[1])"
    } else {
      // Join all but last with commas, then add " & " before last
      let allButLast = days.dropLast().joined(separator: ", ")
      let last = days.last!
      return "every \(allButLast) & \(last)"
    }
  }
  
  // Not multiple days, return as-is (lowercased)
  return frequencyText.lowercased()
}

/// Formats the goal sentence with proper grammar and capitalization
private func formatGoalSentence(numberText: String, unitText: String, frequencyText: String) -> String {
  // Format multiple days if needed
  let formattedFrequency = formatMultipleDays(frequencyText)
  
  // Check if frequency needs "on" preposition or not
  let needsOn = needsOnPreposition(formattedFrequency)
  
  if needsOn {
    return "I want to do this habit \(numberText) \(unitText) on \(formattedFrequency)"
  } else {
    return "I want to do this habit \(numberText) \(unitText) \(formattedFrequency)"
  }
}

/// Formats the current sentence with proper grammar and capitalization
private func formatCurrentSentence(numberText: String, unitText: String, frequencyText: String) -> String {
  // Format multiple days if needed
  let formattedFrequency = formatMultipleDays(frequencyText)
  
  // Check if frequency needs "on" preposition or not
  let needsOn = needsOnPreposition(formattedFrequency)
  
  if needsOn {
    return "I do this habit \(numberText) \(unitText) on \(formattedFrequency)"
  } else {
    return "I do this habit \(numberText) \(unitText) \(formattedFrequency)"
  }
}

/// Determines if a frequency text needs the "on" preposition
/// - Returns: true for specific days/dates, false for frequency descriptions
private func needsOnPreposition(_ frequencyText: String) -> Bool {
  let lowerFrequency = frequencyText.lowercased()
  
  // Frequency patterns that DON'T need "on"
  let frequencyPatterns = [
    "everyday",
    "once a week",
    "twice a week",
    "once a month",
    "twice a month",
    "day a week",
    "days a week",
    "day a month",
    "days a month",
    "time per week",
    "times per week",
  ]
  
  for pattern in frequencyPatterns {
    if lowerFrequency.contains(pattern) {
      return false
    }
  }
  
  // Everything else (specific weekdays, dates, etc.) needs "on"
  return true
}
