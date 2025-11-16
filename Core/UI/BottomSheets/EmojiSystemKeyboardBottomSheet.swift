import SwiftUI

struct EmojiSystemKeyboardBottomSheet: View {
  @Binding var selectedEmoji: String

  let onClose: () -> Void
  let onSave: (String) -> Void

  @FocusState private var isFocused: Bool
  @State private var draft: String = ""
  @State private var hasAppeared = false
  @State private var userDismissedKeyboard = false

  var body: some View {
    BaseBottomSheet(
      title: "Choose Icon",
      description: "Select an emoji for your habit",
      onClose: onClose,
      confirmButton: {
        let normalized = draft.isEmpty ? selectedEmoji : draft
        onSave(normalized)
      },
      confirmButtonTitle: "Save")
    {
      VStack(spacing: 16) {
        // Text field for emoji input
        SwiftUITextFieldAdapter(
          text: $draft,
          placeholder: "Select an emoji",
          keyboardType: .default,
          returnKeyType: .done,
          textContentType: nil,
          autocorrectionType: .no,
          autocapitalizationType: .none,
          isSecureTextEntry: false,
          clearButtonMode: .whileEditing,
          showDoneToolbar: false,
          preferEmojiKeyboard: true,
          isFocused: Binding(
            get: { isFocused },
            set: { isFocused = $0 }
          ),
          onBeginEditing: {
            print("🎯 Keyboard opened")
            userDismissedKeyboard = false
          },
          onEndEditing: {
            print("⚠️ Keyboard closing - checking if intentional")
            // Only re-focus if not intentionally dismissed
            if hasAppeared && !userDismissedKeyboard {
              print("🔄 Re-focusing keyboard immediately (not intentional dismissal)")
              // Immediate refocus to prevent flicker or auto-dismiss
              isFocused = true
            }
          },
          // Only allow resign if user intentionally dismissed
          shouldAllowEndEditing: {
            userDismissedKeyboard
          },
          shouldChangeText: { current, range, replacement in
            // Allow backspace
            if replacement.isEmpty { return true }
            // Only allow emoji characters in the replacement
            if !replacement.containsOnlyEmoji { return false }
            // Compute the prospective text
            if let swiftRange = Range(range, in: current) {
              let next = current.replacingCharacters(in: swiftRange, with: replacement)
              // Keep at most 1 emoji overall
              return next.emojisPrefix(1) == next
            }
            return false
          }
        )
        .frame(height: 56)
        .onAppear {
          // Nudge focus right when the field is on screen
          isFocused = true
        }
        .onChange(of: draft) { _, newValue in
          // Keep only first emoji
          if let first = newValue.first { draft = String(first) }
        }

        // Flexible space so header+input stay at top and Save button sits at bottom above keyboard
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      // Allow intentional keyboard dismissal by tapping outside the field
      .contentShape(Rectangle())
    }
    .background(.surface2)
    .interactiveDismissDisabled()
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .onAppear {
      print("📱 Sheet appeared")
      hasAppeared = true
      userDismissedKeyboard = false
      // Start with empty input unless the existing selection is a single emoji
      if selectedEmoji.isSingleEmoji {
        draft = selectedEmoji
      } else {
        draft = ""
      }
      // Try to focus immediately and also retry shortly after to outlast the sheet animation.
      // Immediate attempt
      isFocused = true
      // Short retry to ensure the text field is attached to a window
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(150))
        if hasAppeared && !userDismissedKeyboard {
          isFocused = true
        }
      }
      // Final retry if needed for slower animations/devices
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(350))
        if hasAppeared && !userDismissedKeyboard {
          isFocused = true
        }
      }
      // Safety retry for slow devices/transitions
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(800))
        if hasAppeared && !userDismissedKeyboard {
          isFocused = true
        }
      }
    }
    .onDisappear {
      print("👋 Sheet disappearing")
      hasAppeared = false
      userDismissedKeyboard = false
      isFocused = false
    }
  }
}

#if DEBUG
#Preview {
  EmojiSystemKeyboardBottomSheet(
    selectedEmoji: .constant(""),
    onClose: { },
    onSave: { _ in })
}
#endif


