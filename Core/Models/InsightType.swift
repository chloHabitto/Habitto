import SwiftUI

enum InsightType {
    case success, warning, info, tip
    
    var color: Color {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .info: return .primary
        case .tip: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .tip: return "lightbulb.fill"
        }
    }
}
