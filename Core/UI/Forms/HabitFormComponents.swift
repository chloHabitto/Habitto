import SwiftUI

// MARK: - Unified Input Element
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
    let uiUpdateTrigger: Bool
    @Binding var isFocused: Bool
    
    @FocusState private var internalIsFocused: Bool
    
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
                // Number input field - smaller width with optimized focus handling
                TextField("1", text: $numberText)
                    .font(.appBodyLarge)
                    .foregroundColor(.text01)
                    .accentColor(.text01)
                    .keyboardType(.numberPad)
                    .focused($internalIsFocused)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .inputFieldStyle()
                    .onChange(of: internalIsFocused) { _, newValue in
                        // Debounce focus changes to prevent UI hangs
                        DispatchQueue.main.async {
                            isFocused = newValue
                        }
                    }
                    .onChange(of: isFocused) { _, newValue in
                        // Debounce focus changes to prevent UI hangs
                        DispatchQueue.main.async {
                            internalIsFocused = newValue
                        }
                    }
                
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
            
            // Descriptive text showing what the user has selected (for Goal and Current)
            if title == "Goal" {
                Text("I want to do this habit \(numberText) \(unitText) on \(frequencyText)")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "1C274C").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
            } else if title == "Current" {
                Text("I do this habit \(numberText) \(unitText) on \(frequencyText)")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "1C274C").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
            }
        }
        .selectionRowStyle()
    }
}

// MARK: - Reminder Section
struct ReminderSection: View {
    let reminders: [ReminderItem]
    let onTap: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SelectionRow(
                title: "Reminder",
                value: reminders.isEmpty ? "Add" : "\(reminders.filter { $0.isActive }.count) reminder\(reminders.filter { $0.isActive }.count == 1 ? "" : "s")",
                action: onTap
            )
            
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
    }
}

// MARK: - Period Section
struct PeriodSection: View {
    let startDate: Date
    let endDate: Date?
    let onStartDateTap: () -> Void
    let onEndDateTap: () -> Void
    
    private let calendar = Calendar.current
    
    private func formatDate(_ date: Date) -> String {
        return AppDateFormatter.shared.formatCreateHabitDate(date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        return calendar.isDateInToday(date)
    }
    
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
}

// MARK: - Habit Building Form
struct HabitBuildingForm: View {
    @Binding var goalNumber: String
    let pluralizedGoalUnit: String
    let goalFrequency: String
    let isGoalValid: Bool
    let uiUpdateTrigger: Bool
    let onGoalUnitTap: () -> Void
    let onGoalFrequencyTap: () -> Void
    let reminderSection: ReminderSection
    let periodSection: PeriodSection
    @Binding var isGoalNumberFocused: Bool
    
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
                uiUpdateTrigger: uiUpdateTrigger,
                isFocused: $isGoalNumberFocused
            )
            
            // Reminder
            reminderSection
            
            // Period
            periodSection
                .selectionRowStyle()
        }
    }
}

// MARK: - Habit Breaking Form
struct HabitBreakingForm: View {
    @Binding var baselineNumber: String
    @Binding var targetNumber: String
    let pluralizedBaselineUnit: String
    let pluralizedTargetUnit: String
    let baselineFrequency: String
    let targetFrequency: String
    let isBaselineValid: Bool
    let isTargetValid: Bool
    let uiUpdateTrigger: Bool
    let onBaselineUnitTap: () -> Void
    let onBaselineFrequencyTap: () -> Void
    let onTargetUnitTap: () -> Void
    let onTargetFrequencyTap: () -> Void
    let reminderSection: ReminderSection
    let periodSection: PeriodSection
    @Binding var isBaselineFieldFocused: Bool
    @Binding var isTargetFieldFocused: Bool
    
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
                uiUpdateTrigger: uiUpdateTrigger,
                isFocused: $isBaselineFieldFocused
            )
            
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
                uiUpdateTrigger: uiUpdateTrigger,
                isFocused: $isTargetFieldFocused
            )
            
            // Reminder
            reminderSection
            
            // Period
            periodSection
                .selectionRowStyle()
        }
    }
}

// MARK: - Form Action Buttons
struct FormActionButtons: View {
    let isFormValid: Bool
    let primaryColor: Color
    let onBack: () -> Void
    let onSave: () -> Void
    
    private let screenWidth = UIScreen.main.bounds.width
    
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
                    .background(isFormValid ? primaryColor : .disabledBackground)
                    .clipShape(Capsule())
            }
            .disabled(!isFormValid)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(bottomGradient)
    }
    
    private var bottomGradient: some View {
        LinearGradient(
            colors: [.surface2, .surface2.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
} 