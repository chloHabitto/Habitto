import SwiftUI

struct CreateHabitFlowView: View {
  // MARK: Lifecycle

  init(onSave: @escaping (Habit) -> Void, habitToEdit: Habit? = nil) {
    self.onSave = onSave
    self.habitToEdit = habitToEdit
  }

  // MARK: Internal

  let onSave: (Habit) -> Void
  let habitToEdit: Habit?

  var body: some View {
    Group {
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
            .onAppear {
              withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                // Animation will be handled by the scaleEffect
              }
            }

          VStack(spacing: 12) {
            Text("Vacation Mode Active")
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.text01)

            Text(
              "Habit creation is paused during vacation mode. You can create new habits when vacation mode ends.")
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
      } else if currentStep == 1 {
        CreateHabitStep1View(
          name: $name,
          description: $description,
          icon: $icon,
          color: $color,
          habitType: $habitType,
          onNext: { _, _, _, _, _ in
            currentStep = 2
          },
          onCancel: {
            dismiss()
          })
      } else if currentStep == 2 {
        CreateHabitStep2View(
          name: $name,
          description: $description,
          icon: $icon,
          color: $color,
          habitType: $habitType,
          reminder: $reminder,
          reminders: $reminders,
          startDate: $startDate,
          endDate: $endDate,
          goalNumber: $goalNumber,
          goalUnit: $goalUnit,
          goalFrequency: $goalFrequency,
          baselineNumber: $baselineNumber,
          baselineUnit: $baselineUnit,
          baselineFrequency: $baselineFrequency,
          targetNumber: $targetNumber,
          targetUnit: $targetUnit,
          targetFrequency: $targetFrequency,
          habitToEdit: habitToEdit,
          goBack: { currentStep = 1 },
          onSave: { habit in
            // ✅ FIX: Don't dismiss here - let the parent handle dismiss after async save completes
            onSave(habit)
            // dismiss() ← REMOVED: This was dismissing before the async save completed!
          })
      }
    }
    .onAppear {
      print("⌨️ CREATE_FLOW: Sheet appeared at \(Date())")
      HabitRepository.shared.pauseSyncMonitoring()
      // Initialize values if editing
      if let habit = habitToEdit {
        name = habit.name
        description = habit.description
        icon = habit.icon
        color = habit.color.color
        habitType = habit.habitType

        // Initialize Step 2 data from existing habit
        // Note: This is a simplified initialization - you may need to parse the habit's
        // goal/schedule
        // to populate the individual fields (goalNumber, goalUnit, goalFrequency, etc.)
        reminder = habit.reminder.isEmpty ? "No reminder" : habit.reminder
        startDate = habit.startDate
        endDate = habit.endDate

        // For now, set default values - you may want to parse the habit's goal string
        // to extract goalNumber, goalUnit, goalFrequency, etc.
        goalNumber = "1"
        goalUnit = "time"
        goalFrequency = "everyday"
        baselineNumber = "1"
        baselineUnit = "time"
        baselineFrequency = "everyday"
        targetNumber = "1"
        targetUnit = "time"
        targetFrequency = "everyday"
      }
    }
    .onDisappear {
      HabitRepository.shared.resumeSyncMonitoring()
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var currentStep = 1
  @State private var name = ""
  @State private var description = ""
  @State private var icon = "None"
  @State private var color = Color(red: 0.11, green: 0.15, blue: 0.30)
  @State private var habitType: HabitType = .formation

  // Step 2 state variables
  @State private var reminder = "No reminder"
  @State private var reminders: [ReminderItem] = []
  @State private var startDate = Date()
  @State private var endDate: Date? = nil
  @State private var goalNumber = "1"
  @State private var goalUnit = "time"
  @State private var goalFrequency = "everyday"
  @State private var baselineNumber = "1"
  @State private var baselineUnit = "time"
  @State private var baselineFrequency = "everyday"
  @State private var targetNumber = "1"
  @State private var targetUnit = "time"
  @State private var targetFrequency = "everyday"
}

#Preview {
  Text("Create Habit Flow")
    .font(.appTitleMedium)
}
