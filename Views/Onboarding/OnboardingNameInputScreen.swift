import SwiftUI

// MARK: - OnboardingNameInputScreen

struct OnboardingNameInputScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @FocusState private var isNameFocused: Bool

  private let backgroundColor = Color(hex: "000835")

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Spacer()
          .frame(height: 48)

        Text("What should we call you?")
          .font(.appHeadlineSmallEmphasised)
          .foregroundColor(.white)

        Text("We'll use your name to make this feel more personal and encouraging.")
          .font(.appBodyLarge)
          .foregroundColor(.white.opacity(0.7))
          .padding(.top, 8)
          .padding(.trailing, 24)

        TextField("Name", text: $viewModel.userName)
          .font(.appBodyLarge)
          .foregroundColor(.white)
          .focused($isNameFocused)
          .padding(.vertical, 16)
          .background(
            VStack(spacing: 0) {
              Spacer()
              Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 1)
            }
          )
          .padding(.top, 24)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.words)
          .accessibilityLabel("Name")
          .accessibilityHint("Enter your name")

        Text("'Tip' Use your name to make this feel more personal and encouraging")
          .font(.appBodySmall)
          .foregroundColor(.white.opacity(0.5))
          .padding(.top, 12)

        Spacer()
          .frame(minHeight: 32)
      }
      .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .safeAreaInset(edge: .bottom) {
      OnboardingButton.primary(
        text: "Continue",
        disabled: viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty
      ) {
        viewModel.goToNext()
      }
      .padding(.bottom, 24)
      .accessibilityLabel("Continue")
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isNameFocused = true
      }
    }
  }
}
