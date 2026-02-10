import SwiftUI

// MARK: - OnboardingCommitPromptScreen

struct OnboardingCommitPromptScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @State private var textOpacity: Double = 0

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("Ready to make a commitment to yourself?")
        .font(.appHeadlineSmallEmphasised)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .opacity(textOpacity)

      Spacer()

      OnboardingButton.primary(text: "Yes, I am ready!") {
        viewModel.goToNext()
      }
      .padding(.bottom, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .onAppear {
      withAnimation(.easeOut(duration: 0.5)) {
        textOpacity = 1
      }
    }
  }
}
