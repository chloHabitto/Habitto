import SwiftUI

struct CreateHabitView: View {
  // MARK: Lifecycle

  init(onSave: @escaping (Habit) -> Void, habitToEdit: Habit? = nil) {
    self.onSave = onSave
    self.habitToEdit = habitToEdit
  }

  // MARK: Internal

  let onSave: (Habit) -> Void
  let habitToEdit: Habit?

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
