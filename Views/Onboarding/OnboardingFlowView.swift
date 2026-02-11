import SwiftUI

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
  @StateObject private var viewModel = OnboardingViewModel()

  private let backgroundColor = OnboardingButton.onboardingBackground

  private var currentFeatureTitle: String {
    viewModel.currentScreen == 1
      ? "Build habits. Break bad ones."
      : "Progress counts, not perfection"
  }

  private var currentFeatureSubtitle: String {
    viewModel.currentScreen == 1
      ? "You don't need a perfect plan. Just one small habit is enough to begin."
      : "Track habits your way, celebrate small wins, and keep going — even on hard days."
  }

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
          subtitle: "You don't need a perfect plan. Just one small habit is enough to begin."
        )
        .tag(1)
        OnboardingFeatureScreen(
          viewModel: viewModel,
          videoName: "Onboarding-Progress",
          title: "Progress counts, not perfection",
          subtitle: "Track habits your way, celebrate small wins, and keep going — even on hard days."
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
      .scrollDisabled(true)
      .indexViewStyle(.page(backgroundDisplayMode: .never))
      .ignoresSafeArea(edges: .all)

      // Step indicator: HStack(spacing: 8) with 2 circles (width/height 8).
      // Active dot = viewModel.currentScreen - 1 (screen 1 = index 0, screen 2 = index 1).
      // Active = Color.white, inactive = Color.white.opacity(0.3).
      // Important: There are 2 OnboardingFeatureScreen pages (tags 1 and 2), so show 2 dots only.
      // A third can be added later if a new feature screen is introduced.
      // Fixed overlay for feature screens (tags 1 & 2): step indicator + Continue button
      if viewModel.currentScreen == 1 || viewModel.currentScreen == 2 {
        VStack(spacing: 0) {
          Spacer()
            .allowsHitTesting(false)

          // Step indicator dots
          HStack(spacing: 8) {
            ForEach(0 ..< 2, id: \.self) { index in
              Circle()
                .fill(index == viewModel.currentScreen - 1 ? Color.white : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            }
          }
          .allowsHitTesting(false)

          Color.clear.frame(height: 16)
            .allowsHitTesting(false)

          // Title — cross-fades on screen change
          Text(currentFeatureTitle)
            .font(.appHeadlineSmallEmphasised)
            .foregroundColor(.appText04)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .id(viewModel.currentScreen)
            .transition(.opacity)
            .allowsHitTesting(false)

          // Subtitle — cross-fades on screen change
          Text(currentFeatureSubtitle)
            .font(.appBodyLarge)
            .foregroundColor(.appText05)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .id("subtitle-\(viewModel.currentScreen)")
            .transition(.opacity)
            .allowsHitTesting(false)

          Color.clear.frame(height: 40)
            .allowsHitTesting(false)

          // Continue button
          OnboardingButton.primary(text: "Continue") {
            viewModel.goToNext()
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 64)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .all)
      }
    }
    .preferredColorScheme(.dark)
  }
}
