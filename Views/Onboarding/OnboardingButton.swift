import SwiftUI

// MARK: - OnboardingButton

/// Buttons styled for onboarding screens on the dark #000835 background.
/// Use these instead of HabittoButton so primary actions stand out (AABDFF on dark).
enum OnboardingButton {
  // AABDFF → light periwinkle blue (for button background + secondary text)
  static let accentBlue = Color(red: 170.0 / 255.0, green: 189.0 / 255.0, blue: 255.0 / 255.0)
  // 171D36 → dark navy (for button text)
  static let darkNavy = Color(red: 23.0 / 255.0, green: 29.0 / 255.0, blue: 54.0 / 255.0)
  // 000835 → onboarding background
  static let onboardingBackground = Color(red: 0.0 / 255.0, green: 8.0 / 255.0, blue: 53.0 / 255.0)

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
        .font(.appButtonText2)
        .foregroundColor(disabled ? darkNavy.opacity(0.5) : darkNavy)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(disabled ? accentBlue.opacity(0.5) : accentBlue)
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
        .font(.appButtonText2)
        .foregroundColor(accentBlue)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
