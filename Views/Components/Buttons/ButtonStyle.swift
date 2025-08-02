import SwiftUI

// MARK: - Button Styles
enum ButtonStyle {
    case fillPrimary
    case fillSecondary
    case outline
    case tertiary
    case fillTertiary
    case fillNeutral
    
    func backgroundColor(for state: ButtonState) -> Color {
        switch self {
        case .fillPrimary:
            switch state {
            case .default, .hover:
                return .primary
            case .disabled:
                return .disabledBackground
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .fillSecondary:
            switch state {
            case .default, .hover:
                return .secondary // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .secondary // TODO: Update in the future
            }
        case .outline:
            switch state {
            case .default, .hover:
                return .clear // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .clear // TODO: Update in the future
            }
        case .tertiary:
            switch state {
            case .default, .hover:
                return .clear // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .clear // TODO: Update in the future
            }
        case .fillTertiary:
            switch state {
            case .default, .hover:
                return .primaryContainer
            case .disabled:
                return .disabledBackground
            case .loading:
                return .primaryContainer // TODO: Update in the future
            }
        case .fillNeutral:
            switch state {
            case .default:
                return .primaryContainer
            case .hover:
                return .primaryContainerFocus
            case .disabled:
                return .disabledBackground
            case .loading:
                return .primaryContainer // TODO: Update in the future
            }
        }
    }
    
    func textColor(for state: ButtonState) -> Color {
        switch self {
        case .fillPrimary:
            switch state {
            case .default, .hover:
                return .onPrimary
            case .disabled:
                return .text04
            case .loading:
                return .onPrimary // TODO: Update in the future
            }
        case .fillSecondary:
            switch state {
            case .default, .hover:
                return .onSecondary
            case .disabled:
                return .text04
            case .loading:
                return .onSecondary // TODO: Update in the future
            }
        case .outline:
            switch state {
            case .default, .hover:
                return .primary
            case .disabled:
                return .text04
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .tertiary:
            switch state {
            case .default, .hover:
                return .primary
            case .disabled:
                return .text04
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .fillTertiary:
            switch state {
            case .default, .hover:
                return .onPrimaryContainer
            case .disabled:
                return .text04
            case .loading:
                return .onPrimaryContainer // TODO: Update in the future
            }
        case .fillNeutral:
            switch state {
            case .default:
                return .onPrimaryContainer
            case .hover:
                return .onPrimaryContainer
            case .disabled:
                return .text04
            case .loading:
                return .onPrimaryContainer // TODO: Update in the future
            }
        }
    }
    
    func borderColor(for state: ButtonState) -> Color {
        switch self {
        case .outline:
            switch state {
            case .default, .hover:
                return .primary
            case .disabled:
                return .outline
            case .loading:
                return .primary // TODO: Update in the future
            }
        default:
            return .clear
        }
    }
    
    func iconColor(for state: ButtonState) -> Color {
        return textColor(for: state)
    }
} 