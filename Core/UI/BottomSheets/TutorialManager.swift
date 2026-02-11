import SwiftUI

class TutorialManager: ObservableObject {
  // MARK: Lifecycle

  init() {
    shouldShowTutorial = false
  }

  // MARK: Internal

  @Published var shouldShowTutorial = false

  func markTutorialAsSeen() {
    UserDefaults.standard.set(true, forKey: hasSeenTutorialKey)
    shouldShowTutorial = false
  }

  @MainActor
  func resetTutorial() {
    UserDefaults.standard.set(false, forKey: hasSeenTutorialKey)
    checkTutorialStatus() // Recheck with new logic
  }

  /// Recheck tutorial status (useful when habits change)
  @MainActor
  func recheckTutorialStatus() {
    checkTutorialStatus()
  }

  // MARK: Private

  private let hasSeenTutorialKey = "HasSeenTutorial"

  @MainActor
  private func checkTutorialStatus() {
    // Tutorial is only shown when manually triggered from More tab
    // Do NOT auto-show on app launch
    shouldShowTutorial = false
  }
}
