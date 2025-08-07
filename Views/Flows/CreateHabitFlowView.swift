import SwiftUI

struct CreateHabitFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = "None"
    @State private var color: Color = Color(red: 0.11, green: 0.15, blue: 0.30)
    @State private var habitType: HabitType = .formation
    
    // Step 2 state variables
    @State private var reminder: String = "No reminder"
    @State private var reminders: [ReminderItem] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var goalNumber: String = "1"
    @State private var goalUnit: String = "time"
    @State private var goalFrequency: String = "everyday"
    @State private var baselineNumber: String = "1"
    @State private var baselineUnit: String = "time"
    @State private var baselineFrequency: String = "everyday"
    @State private var targetNumber: String = "1"
    @State private var targetUnit: String = "time"
    @State private var targetFrequency: String = "everyday"
    
    let onSave: (Habit) -> Void
    let habitToEdit: Habit?
    
    init(onSave: @escaping (Habit) -> Void, habitToEdit: Habit? = nil) {
        self.onSave = onSave
        self.habitToEdit = habitToEdit
    }
    
    var body: some View {
        Group {
            if currentStep == 1 {
                CreateHabitStep1View(
                    name: $name,
                    description: $description,
                    icon: $icon,
                    color: $color,
                    habitType: $habitType,
                    onNext: { name, description, icon, color, habitType in
                        currentStep = 2
                    },
                    onCancel: {
                        dismiss()
                    }
                )
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
                        onSave(habit)
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            // Initialize values if editing
            if let habit = habitToEdit {
                name = habit.name
                description = habit.description
                icon = habit.icon
                color = habit.color
                habitType = habit.habitType
                
                // Initialize Step 2 data from existing habit
                // Note: This is a simplified initialization - you may need to parse the habit's goal/schedule
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
    }
}

#Preview {
    Text("Create Habit Flow")
        .font(.appTitleMedium)
} 
