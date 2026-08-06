import SwiftUI

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
  @StateObject private var viewModel = OnboardingViewModel()
  @State private var dragOffset: CGFloat = 0

  private let backgroundColor = OnboardingButton.onboardingBackground

  private var currentFeatureTitle: String {
    viewModel.currentScreen == 1
      ? "onboarding.feature.home.title".localized
      : "onboarding.feature.progress.title".localized
  }

  private var currentFeatureSubtitle: String {
    viewModel.currentScreen == 1
      ? "onboarding.feature.home.subtitle".localized
      : "onboarding.feature.progress.subtitle".localized
  }

  var body: some View {
    ZStack {
      backgroundColor
        .ignoresSafeArea()

      Group {
        switch viewModel.currentScreen {
        case 0:
          OnboardingWelcomeScreen(viewModel: viewModel)
        case 1:
          OnboardingFeatureScreen(
            viewModel: viewModel,
            videoName: "Onboarding-Home",
            title: "onboarding.feature.home.title".localized,
            subtitle: "onboarding.feature.home.subtitle".localized
          )
        case 2:
          OnboardingFeatureScreen(
            viewModel: viewModel,
            videoName: "Onboarding-Progress",
            title: "onboarding.feature.progress.title".localized,
            subtitle: "onboarding.feature.progress.subtitle".localized
          )
        case 3:
          OnboardingNameInputScreen(viewModel: viewModel)
        // case 4 / 5: greeting + intro — hidden for now; re-enable with ViewModel navigation
        case 6:
          OnboardingCommitPromptScreen(viewModel: viewModel)
        case 7:
          OnboardingCommitHoldScreen(viewModel: viewModel)
        default:
          OnboardingCommitHoldScreen(viewModel: viewModel)
        }
      }
      .offset(x: dragOffset)
      .gesture(
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
          .onChanged { value in
            dragOffset = value.translation.width * 0.3
          }
          .onEnded { value in
            let threshold: CGFloat = 50
            withAnimation(.easeOut(duration: 0.2)) {
              dragOffset = 0
            }
            if value.translation.width < -threshold {
              viewModel.goToNext()
            } else if value.translation.width > threshold {
              viewModel.goToPrevious()
            }
          }
      )
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreen)
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
          OnboardingButton.primary(text: "onboarding.feature.cta.continue".localized) {
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
