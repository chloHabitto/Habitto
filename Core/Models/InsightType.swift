import SwiftUI

enum InsightType {
  case success
  case warning
  case info
  case tip

  // MARK: Internal

  var color: Color {
    switch self {
    case .success: .success
    case .warning: .warning
    case .info: .primary
    case .tip: .secondary
    }
  }

  var icon: String {
    switch self {
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .info: "info.circle.fill"
    case .tip: "lightbulb.fill"
    }
  }
}
