import Foundation
import SwiftUI

// MARK: - ThemeManager

@MainActor
class ThemeManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    if let savedPreference = UserDefaults.standard.string(forKey: "colorSchemePreference"),
       let preference = ColorSchemePreference(rawValue: savedPreference) {
      self.colorSchemePreference = preference
    }
  }

  // MARK: Internal

  static let shared = ThemeManager()

  @Published var colorSchemePreference: ColorSchemePreference = .system {
    didSet {
      UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: "colorSchemePreference")
    }
  }

  var preferredColorScheme: ColorScheme? {
    switch colorSchemePreference {
    case .system:
      return nil
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

// MARK: - ColorSchemePreference

enum ColorSchemePreference: String, CaseIterable {
  case system
  case light
  case dark

  var displayName: String {
    switch self {
    case .system:
      return "System"
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    }
  }

  var icon: String {
    switch self {
    case .system:
      return "circle.lefthalf.filled"
    case .light:
      return "sun.max.fill"
    case .dark:
      return "moon.fill"
    }
  }
}
