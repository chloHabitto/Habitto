import SwiftUI

// MARK: - OnboardingIntroScreen

struct OnboardingIntroScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var textOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      MascotPlaceholderView(size: 100)
        .padding(.bottom, 24)

      Text("I'm here to help you build habits that actually stick — no pressure, no guilt.")
        .font(.appBodyExtraLarge)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .opacity(textOpacity)

      Spacer()

      OnboardingButton.primary(text: "Continue") {
        viewModel.goToNext()
      }
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
        textOpacity = 1
      }
    }
  }
}
