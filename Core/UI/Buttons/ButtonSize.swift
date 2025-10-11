import SwiftUI

// MARK: - Button Sizes

enum ButtonSize {
  case xLarge
  case large
  case medium
  case small

  // MARK: Internal

  var horizontalPadding: CGFloat {
    switch self {
    case .xLarge:
      32
    case .large:
      28
    case .medium:
      24
    case .small:
      20
    }
  }

  var height: CGFloat {
    switch self {
    case .xLarge:
      64
    case .large:
      56
    case .medium:
      48
    case .small:
      40
    }
  }

  var iconSize: CGFloat {
    switch self {
    case .xLarge:
      32
    case .large:
      24
    case .medium:
      20 // TODO: Update in the future
    case .small:
      16 // TODO: Update in the future
    }
  }

  var containerSize: CGFloat {
    switch self {
    case .xLarge:
      64
    case .large:
      48
    case .medium:
      40 // TODO: Update in the future
    case .small:
      32 // TODO: Update in the future
    }
  }

  var font: Font {
    switch self {
    case .xLarge:
      .appButtonText1
    case .large:
      .appButtonText1
    case .medium:
      .appButtonText2
    case .small:
      .appButtonText3
    }
  }
}
