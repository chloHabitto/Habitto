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
      OnboardingVideoPlayer(videoName: videoName, contentMode: .fill)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()

      Color.black.opacity(0.4)
        .ignoresSafeArea()

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

        Spacer()

        OnboardingButton.primary(text: "Continue") {
          viewModel.goToNext()
        }
        .padding(.bottom, 40)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
  }
}
