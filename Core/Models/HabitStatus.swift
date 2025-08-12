import SwiftUI

enum HabitStatus {
    case workingWell, needsAttention, atRisk, newHabit
    case excellentReduction, goodReduction, moderateReduction, needsMoreReduction
    
    var label: String {
        switch self {
        case .workingWell: return "Working Well"
        case .needsAttention: return "Needs Attention"
        case .atRisk: return "At Risk"
        case .newHabit: return "New Habit"
        case .excellentReduction: return "Excellent Reduction"
        case .goodReduction: return "Good Reduction"
        case .moderateReduction: return "Moderate Reduction"
        case .needsMoreReduction: return "Needs More Reduction"
        }
    }
    
    var color: Color {
        switch self {
        case .workingWell: return .success
        case .needsAttention: return .warning
        case .atRisk: return .error
        case .newHabit: return .primary
        case .excellentReduction: return .success
        case .goodReduction: return .success
        case .moderateReduction: return .warning
        case .needsMoreReduction: return .error
        }
    }
    
    var icon: String {
        switch self {
        case .workingWell: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .atRisk: return "xmark.circle.fill"
        case .newHabit: return "sparkles"
        case .excellentReduction: return "arrow.down.circle.fill"
        case .goodReduction: return "arrow.down.circle.fill"
        case .moderateReduction: return "arrow.down.triangle.fill"
        case .needsMoreReduction: return "arrow.up.triangle.fill"
        }
    }
}
