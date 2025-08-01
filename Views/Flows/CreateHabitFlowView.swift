import SwiftUI

struct CreateHabitFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = "None"
    @State private var color: Color = Color(red: 0.11, green: 0.15, blue: 0.30)
    @State private var habitType: HabitType = .formation
    @State private var isInitialLoad = true
    
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
                    isInitialLoad: $isInitialLoad,
                    onNext: { name, description, icon, color, habitType in
                        currentStep = 2
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            } else if currentStep == 2 {
                CreateHabitStep2View(
                    step1Data: (name, description, icon, color, habitType),
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
            }
        }
    }
}

#Preview {
    Text("Create Habit Flow")
        .font(.appTitleMedium)
} 
