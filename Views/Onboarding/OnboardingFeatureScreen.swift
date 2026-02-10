import SwiftUI

// MARK: - OnboardingFeatureScreen

struct OnboardingFeatureScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  let videoName: String
  let title: String
  let subtitle: String
  let pageIndex: Int
  let totalPages: Int

  private let backgroundColor = OnboardingButton.onboardingBackground

  var body: some View {
    ZStack {
      // Video layer — fills full screen (edge to edge, no letterboxing; overflow is ok)
      ZStack {
        OnboardingVideoPlayer(videoName: videoName, contentMode: .fill)
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
          .clipped()

        Color.black.opacity(0.4)
      }
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
      .ignoresSafeArea(edges: .all)

      // Content layer: texts, step indicators, button (respects safe area)
      GeometryReader { geometry in
        VStack(spacing: 0) {
          Spacer()

          HStack(spacing: 8) {
            ForEach(0 ..< totalPages, id: \.self) { index in
              Circle()
                .fill(index == pageIndex ? Color.white : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            }
          }
          .padding(.bottom, 16)

          Text(title)
            .font(.appHeadlineSmallEmphasised)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

          Text(subtitle)
            .font(.appBodyLarge)
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 8)

          Spacer(minLength: 0)

          Color.clear.frame(height: 40)

          OnboardingButton.primary(text: "Continue") {
            viewModel.goToNext()
          }
          .padding(.bottom, 40)
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
