import SwiftUI

// MARK: - OnboardingViewModel

@MainActor
class OnboardingViewModel: ObservableObject {
  // 0–7: welcome → features → name → [greeting/intro hidden] → commit prompt → hold
  // Screens 4 (greeting) and 5 (intro) are skipped for now; re-enable later.
  @Published var currentScreen: Int = 0
  @Published var userName: String = ""
  @Published var hasCommitted: Bool = false
  @Published var holdProgress: CGFloat = 0.0
  @Published var isTransitioning = false

  var commitmentItems: [String] {
    [
      "onboarding.commitment.item1".localized,
      "onboarding.commitment.item2".localized,
      "onboarding.commitment.item3".localized,
      "onboarding.commitment.item4".localized,
    ]
  }

  func completeOnboarding() {
    let trimmed = userName.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty {
      UserDefaults.standard.set(trimmed, forKey: "GuestName")
    }
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
  }

  func goToNext() {
    guard !isTransitioning else { return }
    guard currentScreen < 7 else { return }
    isTransitioning = true
    withAnimation(.easeInOut(duration: 0.3)) {
      // Skip greeting (4) and intro (5): name (3) → commit prompt (6)
      if currentScreen == 3 {
        currentScreen = 6
      } else {
        currentScreen += 1
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      self.isTransitioning = false
    }
  }

  func goToPrevious() {
    guard !isTransitioning else { return }
    guard currentScreen > 0 else { return }
    isTransitioning = true
    withAnimation(.easeInOut(duration: 0.3)) {
      // Skip intro (5) and greeting (4): commit prompt (6) → name (3)
      if currentScreen == 6 {
        currentScreen = 3
      } else {
        currentScreen -= 1
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      self.isTransitioning = false
    }
  }
}
