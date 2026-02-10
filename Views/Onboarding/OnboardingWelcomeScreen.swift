import SwiftUI

// MARK: - OnboardingWelcomeScreen

struct OnboardingWelcomeScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var imageOpacity: Double = 0
  @State private var titleOpacity: Double = 0
  @State private var buttonOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("Habitto")
        .font(.appDisplayMediumEmphasised)
        .foregroundColor(.white)
        .opacity(titleOpacity)

      Spacer()
        .frame(height: 24)

      Image("welcome-image")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .opacity(imageOpacity)

      Spacer()

      VStack(spacing: 16) {
        Button(action: {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          viewModel.goToNext()
        }) {
          Text("Get Started")
            .font(.appButtonText1)
            .foregroundColor(Color("pastelBlue900"))
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color("pastelBlue500"))
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(PlainButtonStyle())
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
        buttonOpacity = 1
      }
    }
  }
}
