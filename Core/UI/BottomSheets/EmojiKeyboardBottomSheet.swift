import SwiftUI

// MARK: - Emoji Keyboard Bottom Sheet

struct EmojiKeyboardBottomSheet: View {
  // MARK: Internal

  @Binding var selectedEmoji: String

  let onClose: () -> Void
  let onSave: (String) -> Void

  var body: some View {
    BaseBottomSheet(
      title: "Choose Icon",
      description: "Select an emoji for your habit",
      onClose: onClose,
      confirmButton: {
        onSave(selectedEmoji)
      },
      confirmButtonTitle: "Save")
    {
      VStack(spacing: 20) {
        // Emoji text field with visual feedback
        VStack(spacing: 12) {
          // Emoji text field - make it visible and interactive
          EmojiTextField(
            selectedEmoji: $selectedEmoji,
            onEmojiSelected: { emoji in
              selectedEmoji = emoji
            },
            isFocused: isTextFieldFocused,
            onFocusChange: { focused in
              isTextFieldFocused = focused
            },
            onTextFieldCreated: { textField in
              textFieldRef = textField
            })
            .frame(height: 50)
            .background(Color.surface2)
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(
                  isTextFieldFocused ? .primary : .outline3,
                  lineWidth: isTextFieldFocused ? 2 : 1.5))

          Text("Tap to enter an emoji")
            .font(.appLabelSmall)
            .foregroundColor(.text03)
            .multilineTextAlignment(.center)
        }
        .onTapGesture {
          isTextFieldFocused = true
        }

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .onAppear {
        guard !hasAppeared else { return }
        hasAppeared = true

        // Force keyboard to appear immediately when sheet opens
        DispatchQueue.main.async {
          isTextFieldFocused = true
        }

        // Start a timer that ALWAYS keeps the text field focused
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
          // ALWAYS try to focus - no conditions
          isTextFieldFocused = true
          textFieldRef?.becomeFirstResponder()
          textFieldRef?.setEmoji()
        }

        // Additional aggressive timer for maximum persistence
        aggressiveFocusTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
          // Even more aggressive focus attempts
          isTextFieldFocused = true
          textFieldRef?.becomeFirstResponder()
          textFieldRef?.setEmoji()
        }
      }
      .onDisappear {
        focusTimer?.invalidate()
        focusTimer = nil
        aggressiveFocusTimer?.invalidate()
        aggressiveFocusTimer = nil
      }
      .onChange(of: textFieldRef) { _, newRef in
        // When text field reference is available, ALWAYS try to focus
        if let textField = newRef {
          DispatchQueue.main.async {
            isTextFieldFocused = true
            textField.becomeFirstResponder()
            textField.setEmoji()
          }

          // Additional aggressive focus attempts
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
            textField.becomeFirstResponder()
            textField.setEmoji()
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTextFieldFocused = true
            textField.becomeFirstResponder()
            textField.setEmoji()
          }
        }
      }
    }
  }

  // MARK: Private

  @FocusState private var isTextFieldFocused: Bool
  @State private var hasAppeared = false
  @State private var textFieldRef: UIEmojiTextField?
  @State private var focusAttempts = 0
  @State private var focusTimer: Timer?
  @State private var aggressiveFocusTimer: Timer?
}

// MARK: - Preview

#Preview {
  @Previewable @State var selectedEmoji = "🏃‍♂️"

  return VStack {
    Text("Selected: \(selectedEmoji)")
      .font(.title)

    Button("Open Emoji Picker") {
      // This would be handled by the parent view
    }
  }
  .sheet(isPresented: .constant(true)) {
    EmojiKeyboardBottomSheet(
      selectedEmoji: $selectedEmoji,
      onClose: { },
      onSave: { _ in })
  }
}
