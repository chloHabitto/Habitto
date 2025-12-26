import Foundation
import SwiftUI

// MARK: - StreakModePreferences

@MainActor
class StreakModePreferences: ObservableObject {
  // MARK: Lifecycle

  private init() {
    if let savedPreference = UserDefaults.standard.string(forKey: "streakModePreference"),
       let preference = StreakMode(rawValue: savedPreference) {
      self.streakMode = preference
    }
  }

  // MARK: Internal

  static let shared = StreakModePreferences()

  @Published var streakMode: StreakMode = .fullCompletion {
    didSet {
      UserDefaults.standard.set(streakMode.rawValue, forKey: "streakModePreference")
    }
  }
}

// MARK: - StreakMode

enum StreakMode: String, CaseIterable {
  case fullCompletion
  case anyProgress

  var displayName: String {
    switch self {
    case .fullCompletion:
      return "Full Completion"
    case .anyProgress:
      return "Any Progress"
    }
  }

  var description: String {
    switch self {
    case .fullCompletion:
      return "All habits must be 100% done"
    case .anyProgress:
      return "Streak counts if you made any progress on each habit"
    }
  }

  var icon: String {
    switch self {
    case .fullCompletion:
      return "checkmark.circle.fill"
    case .anyProgress:
      return "circle.fill"
    }
  }
}

