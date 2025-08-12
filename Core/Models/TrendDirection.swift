import SwiftUI

enum TrendDirection {
    case improving, stable, declining
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .success
        case .stable: return .warning
        case .declining: return .error
        }
    }
}
