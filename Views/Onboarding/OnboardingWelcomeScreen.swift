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
        Image("Ellipse 3947")
          .frame(width: 252, height: 252)
          .background(Color(red: 0.13, green: 0.25, blue: 0.59).opacity(0.56))
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
        Button(action: {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          viewModel.goToNext()
        }) {
          Text("Get Started")
            .font(.appButtonText2)
            .foregroundColor(Color(.sRGB, red: 23.0 / 255.0, green: 29.0 / 255.0, blue: 54.0 / 255.0, opacity: 1))
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(.sRGB, red: 170.0 / 255.0, green: 189.0 / 255.0, blue: 255.0 / 255.0, opacity: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .opacity(buttonOpacity)
        .accessibilityLabel("Get Started")

        Button(action: {
          // Placeholder: "I already have an account"
        }) {
          Text("I already have an account")
            .font(.appButtonText2)
            .foregroundColor(Color(hex: "AABDFF"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(buttonOpacity)
        .accessibilityLabel("I already have an account")
      }
      .padding(.bottom, 40)
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
