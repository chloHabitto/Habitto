import SwiftUI

// MARK: - Goal

struct Goal {
  let amount: Double
  let unit: String
}

// MARK: - HabitGoal

struct HabitGoal: Identifiable {
  let id = UUID()
  let habit: Habit
  let goal: Goal
  let currentAverage: Double
  let goalHitRate: Double
}
