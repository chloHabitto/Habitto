import SwiftUI

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
  @StateObject private var viewModel = OnboardingViewModel()

  private let backgroundColor = OnboardingButton.onboardingBackground

  var body: some View {
    ZStack {
      backgroundColor
        .ignoresSafeArea()

      TabView(selection: $viewModel.currentScreen) {
        OnboardingWelcomeScreen(viewModel: viewModel)
          .tag(0)
        OnboardingFeatureScreen(
          viewModel: viewModel,
          videoName: "Onboarding-Home",
          title: "Build habits. Break bad ones.",
          subtitle: "You don't need a perfect plan. Just one small habit is enough to begin.",
          pageIndex: 0,
          totalPages: 3
        )
        .tag(1)
        OnboardingFeatureScreen(
          viewModel: viewModel,
          videoName: "Onboarding-Progress",
          title: "Progress counts, not perfection",
          subtitle: "Track habits your way, celebrate small wins, and keep going — even on hard days.",
          pageIndex: 1,
          totalPages: 3
        )
        .tag(2)
        OnboardingNameInputScreen(viewModel: viewModel)
          .tag(3)
        OnboardingGreetingScreen(viewModel: viewModel)
          .tag(4)
        OnboardingIntroScreen(viewModel: viewModel)
          .tag(5)
        OnboardingCommitPromptScreen(viewModel: viewModel)
          .tag(6)
        OnboardingCommitHoldScreen(viewModel: viewModel)
          .tag(7)
        OnboardingCommitConfirmedScreen(viewModel: viewModel)
          .tag(8)
        OnboardingCelebrationScreen(viewModel: viewModel)
          .tag(9)
        OnboardingFinalScreen(viewModel: viewModel)
          .tag(10)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .indexViewStyle(.page(backgroundDisplayMode: .never))
      .ignoresSafeArea(edges: .all)
    }
    .preferredColorScheme(.dark)
  }
}
