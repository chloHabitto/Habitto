import SwiftUI

class TutorialManager: ObservableObject {
  // MARK: Lifecycle

  init() {
    debugLog("🔍 TutorialManager: Initializing...")

    // Check tutorial status on main actor
    Task { @MainActor in
      self.checkTutorialStatus()
    }

    // Recheck after a delay to ensure HabitRepository is loaded
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      Task { @MainActor in
        self?.recheckTutorialStatus()
      }
    }
  }

  // MARK: Internal

  @Published var shouldShowTutorial = false

  func markTutorialAsSeen() {
    debugLog("🔍 TutorialManager: markTutorialAsSeen() called")
    UserDefaults.standard.set(true, forKey: hasSeenTutorialKey)
    shouldShowTutorial = false
    debugLog("🔍 TutorialManager: Tutorial marked as seen, shouldShowTutorial = false")
  }

  @MainActor
  func resetTutorial() {
    debugLog("🔍 TutorialManager: resetTutorial() called")
    UserDefaults.standard.set(false, forKey: hasSeenTutorialKey)
    checkTutorialStatus() // Recheck with new logic
    debugLog("🔍 TutorialManager: Tutorial reset, shouldShowTutorial = \(shouldShowTutorial)")
  }

  /// Recheck tutorial status (useful when habits change)
  @MainActor
  func recheckTutorialStatus() {
    debugLog("🔍 TutorialManager: Rechecking tutorial status...")
    checkTutorialStatus()
  }

  // MARK: Private

  private let hasSeenTutorialKey = "HasSeenTutorial"

  @MainActor
  private func checkTutorialStatus() {
    let hasSeenTutorial = UserDefaults.standard.bool(forKey: hasSeenTutorialKey)

    // Additional check: If user has habits, they've likely used the app before
    // This provides a backup in case UserDefaults was cleared
    // Use a safe approach to check habits count
    let hasHabits = (!HabitRepository.shared.habits.isEmpty)

    // Show tutorial only if user hasn't seen it AND has no habits (truly new user)
    shouldShowTutorial = !hasSeenTutorial && !hasHabits

    debugLog(
      "🔍 TutorialManager: HasSeenTutorial = \(hasSeenTutorial), HasHabits = \(hasHabits), ShouldShowTutorial = \(shouldShowTutorial)")
  }
}
