import SwiftUI

struct CreateHabitView: View {
    let onSave: (Habit) -> Void
    let habitToEdit: Habit?
    
    init(onSave: @escaping (Habit) -> Void, habitToEdit: Habit? = nil) {
        self.onSave = onSave
        self.habitToEdit = habitToEdit
    }
    
    var body: some View {
        CreateHabitFlowView(habitToEdit: habitToEdit) { habit in
            onSave(habit)
        }
    }
}

#Preview {
    Text("Create Habit View")
        .font(.title)
} 