import SwiftUI

// MARK: - OnboardingViewModel

@MainActor
class OnboardingViewModel: ObservableObject {
  @Published var currentScreen: Int = 0 // 0–9 for screens 1–10 (hold → celebration → final)
  @Published var userName: String = ""
  @Published var hasCommitted: Bool = false
  @Published var holdProgress: CGFloat = 0.0
  @Published var isTransitioning = false

  let commitmentItems: [String] = [
    "I will start small and be patient with myself.",
    "I will celebrate progress, not just perfection.",
    "I will keep going, even after hard days.",
    "I believe I can change.",
  ]

  func completeOnboarding() {
    let trimmed = userName.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty {
      UserDefaults.standard.set(trimmed, forKey: "GuestName")
    }
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
  }

  func goToNext() {
    guard !isTransitioning else { return }
    isTransitioning = true
    withAnimation(.easeInOut(duration: 0.3)) {
      currentScreen += 1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      self.isTransitioning = false
    }
  }
}
