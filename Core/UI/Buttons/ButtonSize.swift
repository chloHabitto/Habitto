import SwiftUI

// MARK: - Button Sizes
enum ButtonSize {
    case xLarge
    case large
    case medium
    case small
    
    var horizontalPadding: CGFloat {
        switch self {
        case .xLarge:
            return 32
        case .large:
            return 28
        case .medium:
            return 24
        case .small:
            return 20
        }
    }
    
    var height: CGFloat {
        switch self {
        case .xLarge:
            return 64
        case .large:
            return 56
        case .medium:
            return 48
        case .small:
            return 40 
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .xLarge:
            return 32
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
        case .xLarge:
            return 64
        case .large:
            return 48
        case .medium:
            return 40 // TODO: Update in the future
        case .small:
            return 32 // TODO: Update in the future
        }
    }
    
    var font: Font {
        switch self {
        case .xLarge:
            return .appButtonText1
        case .large:
            return .appButtonText1
        case .medium:
            return .appButtonText2
        case .small:
            return .appButtonText3
        }
    }
} 
