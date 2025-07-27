import SwiftUI

struct CreateHabitView: View {
    let onSave: (Habit) -> Void
    let habitToEdit: Habit?
    
    init(onSave: @escaping (Habit) -> Void, habitToEdit: Habit? = nil) {
        self.onSave = onSave
        self.habitToEdit = habitToEdit
    }
    
    var body: some View {
        CreateHabitFlowView(onSave: { habit in
            onSave(habit)
        }, habitToEdit: habitToEdit)
    }
}

#Preview {
    Text("Create Habit View")
        .font(.appTitleMedium)
} 
