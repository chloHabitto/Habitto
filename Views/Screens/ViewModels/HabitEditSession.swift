import Foundation

final class HabitEditSession: Identifiable, ObservableObject {
  let id = UUID()
  let habit: Habit

  init(habit: Habit) {
    self.habit = habit
  }
}

