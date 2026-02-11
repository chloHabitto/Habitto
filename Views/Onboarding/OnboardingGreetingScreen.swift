import SwiftUI

// MARK: - OnboardingGreetingScreen

struct OnboardingGreetingScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var mascotScale: CGFloat = 0.5
  @State private var mascotOpacity: Double = 0

  private let backgroundColor = OnboardingButton.onboardingBackground

  private var displayName: String {
    let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "there" : trimmed
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("Hi \(displayName)!!")
        .font(.appHeadlineMediumEmphasised)
        .foregroundColor(.white)
        .padding(.bottom, 24)

      MascotPlaceholderView(size: 140)
        .scaleEffect(mascotScale)
        .opacity(mascotOpacity)

      Spacer()

      OnboardingButton.primary(text: "Continue") {
        viewModel.goToNext()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        mascotScale = 1.0
        mascotOpacity = 1
      }
    }
  }
}
