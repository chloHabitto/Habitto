import SwiftUI

// MARK: - OnboardingButton

/// Buttons styled for onboarding screens on the dark #000835 background.
/// Use these instead of HabittoButton so primary actions stand out (AABDFF on dark).
enum OnboardingButton {
  /// Primary action: filled capsule, light blue background, dark text.
  static func primary(
    text: String,
    disabled: Bool = false,
    action: @escaping () -> Void)
    -> some View
  {
    Button(action: {
      if !disabled {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
      }
    }) {
      Text(text)
        .font(.appButtonText1)
        .foregroundColor(disabled ? Color(hex: "171D36").opacity(0.5) : Color(hex: "171D36"))
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(disabled ? Color(hex: "AABDFF").opacity(0.5) : Color(hex: "AABDFF"))
        .clipShape(Capsule())
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(disabled)
    .padding(.horizontal, 20)
  }

  /// Secondary / text link: transparent, light blue text.
  static func secondary(text: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(text)
        .font(.appBodyLarge)
        .foregroundColor(Color(hex: "AABDFF"))
    }
    .buttonStyle(PlainButtonStyle())
  }
}
