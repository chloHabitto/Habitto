import SwiftUI

// MARK: - OnboardingWelcomeScreen

struct OnboardingWelcomeScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var imageOpacity: Double = 0
  @State private var titleOpacity: Double = 0
  @State private var subtitleOpacity: Double = 0
  @State private var buttonOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Image("welcome-image")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .opacity(imageOpacity)

      Spacer()
        .frame(height: 24)

      Text("Habitto")
        .font(.appDisplayMediumEmphasised)
        .foregroundColor(.white)
        .opacity(titleOpacity)

      Text("Progress counts, not perfection")
        .font(.appBodyLarge)
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .opacity(subtitleOpacity)

      Spacer()

      VStack(spacing: 16) {
        HabittoButton(
          size: .large,
          style: .fillPrimary,
          content: .text("Get Started"),
          state: .default,
          action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.goToNext()
          }
        )
        .padding(.horizontal, 20)
        .opacity(buttonOpacity)
        .accessibilityLabel("Get Started")

        Button(action: {
          // Placeholder: "I already have an account"
        }) {
          Text("I already have an account")
            .font(.appBodyMedium)
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 4)
        .opacity(buttonOpacity)
        .accessibilityLabel("I already have an account")
      }
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      withAnimation(.easeOut(duration: 0.5)) {
        imageOpacity = 1
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
        titleOpacity = 1
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
        subtitleOpacity = 1
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
        buttonOpacity = 1
      }
    }
  }
}
