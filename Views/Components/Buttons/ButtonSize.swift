import SwiftUI

// MARK: - Button Sizes
enum ButtonSize {
    case large
    case medium
    case small
    
    var padding: CGFloat {
        switch self {
        case .large:
            return 16
        case .medium:
            return 12 // TODO: Update in the future
        case .small:
            return 8 // TODO: Update in the future
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .large:
            return 24
        case .medium:
            return 20 // TODO: Update in the future
        case .small:
            return 16 // TODO: Update in the future
        }
    }
    
    var containerSize: CGFloat {
        switch self {
        case .large:
            return 48
        case .medium:
            return 40 // TODO: Update in the future
        case .small:
            return 32 // TODO: Update in the future
        }
    }
} 