import SwiftUI

// MARK: - OnboardingFeatureScreen

struct OnboardingFeatureScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  let videoName: String
  let title: String
  let subtitle: String

  private let backgroundColor = OnboardingButton.onboardingBackground

  var body: some View {
    ZStack {
      // Video layer — fills full screen (edge to edge, no letterboxing; overflow is ok)
      OnboardingVideoPlayer(videoName: videoName, contentMode: .fill)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea(edges: .all)

      // Content layer: texts only (step indicator and button are fixed in OnboardingFlowView)
      GeometryReader { geometry in
        VStack(spacing: 0) {
          Spacer()

          Color.clear.frame(height: 32)  // reserve space for fixed dots above

          Text(title)
            .font(.appHeadlineSmallEmphasised)
            .foregroundColor(.appText04)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

          Text(subtitle)
            .font(.appBodyLarge)
            .foregroundColor(.appText05)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 8)

          Color.clear.frame(height: 150)  // reserve space for fixed button below
        }
        .padding(.top, geometry.safeAreaInsets.top)
        .padding(.bottom, geometry.safeAreaInsets.bottom)
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea(edges: .all)
    .background(backgroundColor)
  }
}
