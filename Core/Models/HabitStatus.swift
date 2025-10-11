import SwiftUI

enum HabitStatus {
  case workingWell
  case needsAttention
  case atRisk
  case newHabit
  case excellentReduction
  case goodReduction
  case moderateReduction
  case needsMoreReduction

  // MARK: Internal

  var label: String {
    switch self {
    case .workingWell: "Working Well"
    case .needsAttention: "Needs Attention"
    case .atRisk: "At Risk"
    case .newHabit: "New Habit"
    case .excellentReduction: "Excellent Reduction"
    case .goodReduction: "Good Reduction"
    case .moderateReduction: "Moderate Reduction"
    case .needsMoreReduction: "Needs More Reduction"
    }
  }

  var color: Color {
    switch self {
    case .workingWell: .success
    case .needsAttention: .warning
    case .atRisk: .error
    case .newHabit: .primary
    case .excellentReduction: .success
    case .goodReduction: .success
    case .moderateReduction: .warning
    case .needsMoreReduction: .error
    }
  }

  var icon: String {
    switch self {
    case .workingWell: "checkmark.circle.fill"
    case .needsAttention: "exclamationmark.triangle.fill"
    case .atRisk: "xmark.circle.fill"
    case .newHabit: "sparkles"
    case .excellentReduction: "arrow.down.circle.fill"
    case .goodReduction: "arrow.down.circle.fill"
    case .moderateReduction: "arrow.down.triangle.fill"
    case .needsMoreReduction: "arrow.up.triangle.fill"
    }
  }
}
