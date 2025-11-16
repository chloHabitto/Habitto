import SwiftUI

// MARK: - KeyboardHandling

/// Simple, focused keyboard utilities
enum KeyboardHandling {
  // MARK: Internal

  struct DoneButton: ViewModifier {
    func body(content: Content) -> some View {
      content
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
              KeyboardHandling.dismissKeyboard()
            }
            .font(.appBodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .clipShape(Capsule())
          }
        }
    }
  }

  /// Helper to dismiss keyboard programmatically
  static func dismissKeyboard() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil)
  }
}

// MARK: - View Extensions

extension View {
  /// Adds a "Done" button above the keyboard for text input fields
  func keyboardDoneButton() -> some View {
    modifier(KeyboardHandling.DoneButton())
  }
}
