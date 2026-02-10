import SwiftUI

// MARK: - OnboardingFeatureScreen

struct OnboardingFeatureScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  let videoName: String
  let title: String
  let subtitle: String
  let pageIndex: Int
  let totalPages: Int

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      OnboardingVideoPlayer(videoName: videoName)
        .frame(maxWidth: 280)
        .padding(.horizontal, 24)

      Spacer()
        .frame(height: 32)

      Text(title)
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      Text(subtitle)
        .font(.appBodyLarge)
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 8)

      Spacer()

      HStack(spacing: 8) {
        ForEach(0 ..< totalPages, id: \.self) { index in
          Circle()
            .fill(index == pageIndex ? Color.white : Color.white.opacity(0.3))
            .frame(width: 8, height: 8)
        }
      }
      .padding(.bottom, 16)

      HabittoButton(
        size: .large,
        style: .fillPrimary,
        content: .text("Continue"),
        state: .default,
        action: {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          viewModel.goToNext()
        }
      )
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
  }
}
