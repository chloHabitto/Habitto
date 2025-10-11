import SwiftUI

struct HabitProgress: Identifiable {
  let id = UUID()
  let habit: Habit
  let period: TimePeriod
  let completionPercentage: Double
  let trend: TrendDirection

  var status: HabitStatus {
    // Check if the habit has any completion history at all
    let hasAnyCompletionHistory = !habit.completionHistory.isEmpty

    // Calculate days since habit creation
    let calendar = Calendar.current
    let today = Date()
    let daysSinceCreation = calendar.dateComponents([.day], from: habit.startDate, to: today)
      .day ?? 0

    // If habit is too new (less than 3 days since creation) or has no completion history yet, show
    // "New Habit" status
    if daysSinceCreation < 3 || !hasAnyCompletionHistory {
      return .newHabit
    }

    if habit.habitType == .breaking {
      // For habit breaking, use reduction-focused status
      if completionPercentage >= 80 {
        return .excellentReduction
      } else if completionPercentage >= 50 {
        return .goodReduction
      } else if completionPercentage >= 20 {
        return .moderateReduction
      } else {
        return .needsMoreReduction
      }
    } else {
      // For habit building, use completion-focused status
      if completionPercentage >= 80 {
        return .workingWell
      } else if completionPercentage >= 50 {
        return .needsAttention
      } else {
        return .atRisk
      }
    }
  }
}
