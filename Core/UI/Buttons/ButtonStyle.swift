import SwiftUI

// MARK: - Button Styles

enum ButtonStyle {
  case fillPrimary
  case fillSecondary
  case outline
  case tertiary
  case fillTertiary
  case fillNeutral
  case fillDestructive

  // MARK: Internal

  func backgroundColor(for state: ButtonState) -> Color {
    switch self {
    case .fillPrimary:
      switch state {
      case .default,
           .hover:
        .primary
      case .disabled:
        .disabledBackground
      case .loading:
        .primary // TODO: Update in the future
      }

    case .fillSecondary:
      switch state {
      case .default,
           .hover:
        .secondary // TODO: Update in the future
      case .disabled:
        .disabledBackground
      case .loading:
        .secondary // TODO: Update in the future
      }

    case .outline:
      switch state {
      case .default,
           .hover:
        .clear // TODO: Update in the future
      case .disabled:
        .disabledBackground
      case .loading:
        .clear // TODO: Update in the future
      }

    case .tertiary:
      switch state {
      case .default,
           .hover:
        .clear // TODO: Update in the future
      case .disabled:
        .disabledBackground
      case .loading:
        .clear // TODO: Update in the future
      }

    case .fillTertiary:
      switch state {
      case .default,
           .hover:
        .primaryContainer
      case .disabled:
        .disabledBackground
      case .loading:
        .primaryContainer // TODO: Update in the future
      }

    case .fillNeutral:
      switch state {
      case .default:
        .primaryContainer
      case .hover:
        .primaryContainerFocus
      case .disabled:
        .disabledBackground
      case .loading:
        .primaryContainer // TODO: Update in the future
      }

    case .fillDestructive:
      switch state {
      case .default,
           .hover:
        .red500
      case .disabled:
        .disabledBackground
      case .loading:
        .red500 // TODO: Update in the future
      }
    }
  }

  func textColor(for state: ButtonState) -> Color {
    switch self {
    case .fillPrimary:
      switch state {
      case .default,
           .hover:
        .onPrimary
      case .disabled:
        .text04
      case .loading:
        .onPrimary // TODO: Update in the future
      }

    case .fillSecondary:
      switch state {
      case .default,
           .hover:
        .onSecondary
      case .disabled:
        .text04
      case .loading:
        .onSecondary // TODO: Update in the future
      }

    case .outline:
      switch state {
      case .default,
           .hover:
        .primary
      case .disabled:
        .text04
      case .loading:
        .primary // TODO: Update in the future
      }

    case .tertiary:
      switch state {
      case .default,
           .hover:
        .primary
      case .disabled:
        .text04
      case .loading:
        .primary // TODO: Update in the future
      }

    case .fillTertiary:
      switch state {
      case .default,
           .hover:
        .onPrimaryContainer
      case .disabled:
        .text04
      case .loading:
        .onPrimaryContainer // TODO: Update in the future
      }

    case .fillNeutral:
      switch state {
      case .default:
        .onPrimaryContainer
      case .hover:
        .onPrimaryContainer
      case .disabled:
        .text04
      case .loading:
        .onPrimaryContainer // TODO: Update in the future
      }

    case .fillDestructive:
      switch state {
      case .default,
           .hover:
        .onPrimary
      case .disabled:
        .text04
      case .loading:
        .onPrimary // TODO: Update in the future
      }
    }
  }

  func borderColor(for state: ButtonState) -> Color {
    switch self {
    case .outline:
      switch state {
      case .default,
           .hover:
        .primary
      case .disabled:
        .outline3
      case .loading:
        .primary // TODO: Update in the future
      }

    default:
      .clear
    }
  }

  func iconColor(for state: ButtonState) -> Color {
    textColor(for: state)
  }
}
