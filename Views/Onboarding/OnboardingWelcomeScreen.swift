import SwiftUI

// MARK: - OnboardingWelcomeScreen

struct OnboardingWelcomeScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var imageOpacity: Double = 0
  @State private var titleOpacity: Double = 0
  @State private var buttonOpacity: Double = 0

  private let backgroundColor = OnboardingButton.onboardingBackground

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)

      Spacer()
        .frame(height: 88)

      Text("Habitto")
        .font(.appDisplayLargeEmphasised)
        .foregroundColor(.white)
        .opacity(titleOpacity)

      Spacer()
        .frame(height: 24)

      ZStack(alignment: .topTrailing) {
        Circle()
          .fill(Color(red: 0.13, green: 0.25, blue: 0.59).opacity(0.56))
          .frame(width: 252, height: 252)
          .blur(radius: 50.88363)
          .offset(x: 80, y: -60)

        Image("welcome-image")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .opacity(imageOpacity)
      }

      Spacer()
        .frame(height: 16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 8) {
        OnboardingButton.primary(text: "Get Started") {
          viewModel.goToNext()
        }
        .accessibilityLabel("Get Started")

        OnboardingButton.secondary(text: "I already have an account") {
          // Placeholder: "I already have an account"
        }
        .accessibilityLabel("I already have an account")
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
      .background(backgroundColor)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.5)) {
        imageOpacity = 1
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
        titleOpacity = 1
      }
      withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
        buttonOpacity = 1
      }
    }
  }
}
