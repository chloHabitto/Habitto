import SwiftUI

enum TrendDirection {
  case improving
  case stable
  case declining

  // MARK: Internal

  var icon: String {
    switch self {
    case .improving: "arrow.up"
    case .stable: "arrow.right"
    case .declining: "arrow.down"
    }
  }

  var color: Color {
    switch self {
    case .improving: .success
    case .stable: .warning
    case .declining: .error
    }
  }
}
