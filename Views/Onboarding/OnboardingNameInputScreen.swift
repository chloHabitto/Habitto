import SwiftUI

// MARK: - OnboardingNameInputScreen

struct OnboardingNameInputScreen: View {
  @ObservedObject var viewModel: OnboardingViewModel
  @FocusState private var isNameFocused: Bool

  @State private var showError = false
  @State private var keyboardHeight: CGFloat = 0
  @State private var titleVisible = false
  @State private var subtitleVisible = false
  @State private var fieldVisible = false
  @State private var helperVisible = false
  @State private var buttonVisible = false
  @State private var fieldShakeOffset: CGFloat = 0
  @State private var skipVisible = false

  private let backgroundColor = OnboardingButton.onboardingBackground
  private let accentBlue = Color(hex: "AABDFF")

  private var isNameEmpty: Bool {
    viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button(action: {
          viewModel.goToNext()
        }) {
          Text("skip")
            .font(.appTitleMedium)
            .foregroundColor(Color(hex: "ADAFB5"))
            .frame(width: 64, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(skipVisible ? 1 : 0)
      }
      .padding(.top, 8)
      .padding(.trailing, 8)

      ScrollView {
        VStack(spacing: 0) {
          Spacer()
            .frame(height: 48)

          Text("What should we call you?")
            .font(.appHeadlineSmallEmphasised)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .opacity(titleVisible ? 1 : 0)
            .offset(y: titleVisible ? 0 : 20)

          Text("We'll use your name to make this feel more personal and encouraging.")
            .font(.appBodyLarge)
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .opacity(subtitleVisible ? 1 : 0)
            .offset(y: subtitleVisible ? 0 : 15)

          nameFieldWithUnderline
            .padding(.top, 24)
            .opacity(fieldVisible ? 1 : 0)
            .offset(y: fieldVisible ? 0 : 10)
            .offset(x: fieldShakeOffset)

          helperText
            .padding(.top, 8)
            .opacity(helperVisible ? 1 : 0)

          if showError {
            errorText
              .transition(.opacity.combined(with: .move(edge: .top)))
          }

          if !viewModel.userName.isEmpty {
            sparkleView
          }

          Spacer()
            .frame(minHeight: 32)
        }
      }
      .padding(.horizontal, 24)
      .scrollDismissesKeyboard(.interactively)
      continueButton
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor)
    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    .onAppear {
      runEntranceAnimations()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isNameFocused = true
      }
    }
    .onChange(of: viewModel.userName) { _, newValue in
      if !newValue.isEmpty && showError {
        withAnimation(.easeInOut(duration: 0.3)) {
          showError = false
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
      guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
      let bottomSafeArea = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?
        .windows
        .first?
        .safeAreaInsets
        .bottom ?? 0
      withAnimation(.easeOut(duration: 0.25)) {
        keyboardHeight = max(0, frame.height - bottomSafeArea)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
      withAnimation(.easeOut(duration: 0.25)) {
        keyboardHeight = 0
      }
    }
  }

  private var nameFieldWithUnderline: some View {
    TextField("Name", text: $viewModel.userName)
      .font(.appBodyLarge)
      .foregroundColor(.white)
      .multilineTextAlignment(.center)
      .focused($isNameFocused)
      .padding(.vertical, 16)
      .background(
        VStack(spacing: 0) {
          Spacer()
          Rectangle()
            .fill(isNameFocused ? accentBlue : Color.white.opacity(0.3))
            .frame(height: isNameFocused ? 2 : 1)
        }
      )
      .shadow(
        color: isNameFocused ? accentBlue.opacity(0.4) : .clear,
        radius: 8,
        y: 2
      )
      .autocorrectionDisabled()
      .textInputAutocapitalization(.words)
      .accessibilityLabel("Name")
      .accessibilityHint("Enter your name")
      .animation(.easeInOut(duration: 0.3), value: isNameFocused)
  }

  private var helperText: some View {
    Text(String(localized: "onboarding.name.helper"))
      .font(.appBodySmall)
      .foregroundColor(.white.opacity(0.5))
      .multilineTextAlignment(.center)
  }

  private var errorText: some View {
    Text(String(localized: "onboarding.name.error"))
      .font(.appBodySmall)
      .foregroundColor(Color(hex: "FF6B6B"))
      .multilineTextAlignment(.center)
      .padding(.top, 8)
  }

  private var sparkleView: some View {
    HStack(spacing: 6) {
      ForEach(0 ..< 3, id: \.self) { index in
        Circle()
          .fill(Color.white.opacity(0.6))
          .frame(width: 4, height: 4)
          .opacity(sparkleOpacity(for: index))
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 12)
  }

  private func sparkleOpacity(for index: Int) -> Double {
    0.4 + Double(index) * 0.15
  }

  private var continueButton: some View {
    OnboardingButton.primary(
      text: "Continue",
      inactive: isNameEmpty
    ) {
      let trimmed = viewModel.userName.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        withAnimation(.easeInOut(duration: 0.3)) {
          showError = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        triggerFieldShake()
      } else {
        showError = false
        viewModel.userName = trimmed
        viewModel.goToNext()
      }
    }
    .padding(.bottom, 20 + keyboardHeight)
    .opacity(buttonVisible ? 1 : 0)
    .scaleEffect(buttonVisible ? 1 : 0.95)
    .accessibilityLabel("Continue")
  }

  private func runEntranceAnimations() {
    withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
      skipVisible = true
    }
    withAnimation(.easeOut(duration: 0.5)) {
      titleVisible = true
    }
    withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
      subtitleVisible = true
    }
    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
      fieldVisible = true
    }
    withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
      helperVisible = true
    }
    withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
      buttonVisible = true
    }
  }

  private func triggerFieldShake() {
    let duration: TimeInterval = 0.04
    let offsets: [CGFloat] = [5, -5, 5, -5, 5, -5, 0]
    for (i, offset) in offsets.enumerated() {
      DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i)) {
        withAnimation(.linear(duration: duration)) {
          fieldShakeOffset = offset
        }
      }
    }
  }
}
