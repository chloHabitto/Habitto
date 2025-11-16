import SwiftUI

struct IconBottomSheet: View {
  @Binding var selectedIcon: String

  let onClose: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var isClosing: Bool = false

  var body: some View {
    // Two-phase close: keyboard first, then sheet
    let initiateClose: () -> Void = {
      guard isClosing == false else { return }
      isClosing = true
      isFocused = false
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil)
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        dismiss()
        onClose()
      }
    }

    return BaseBottomSheet(
      title: "Select Icon",
      description: "Choose an icon for your habit",
      onClose: initiateClose)
    {
      VStack(spacing: 16) {
        // Inline text field to host the system keyboard inside the sheet
        SwiftUITextFieldAdapter(
          text: $draft,
          placeholder: "Select an emoji",
          keyboardType: .default, // keep current keyboard type
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
            // no-op
          },
          onEndEditing: {
            // no-op; focus will be cleared on sheet close
          },
          shouldAllowEndEditing: {
            true
          },
          shouldChangeText: { current, range, replacement in
            // Allow backspace
            if replacement.isEmpty { return true }
            // Only allow emoji characters
            if !replacement.containsOnlyEmoji { return false }
            // Keep at most one emoji overall
            if let swiftRange = Range(range, in: current) {
              let next = current.replacingCharacters(in: swiftRange, with: replacement)
              return next.emojisPrefix(1) == next
            }
            return false
          }
        )
        .frame(height: 56)
        .onAppear {
          // Autofocus when sheet opens
          isFocused = true
          // Seed from current selection if it's a single emoji
          if selectedIcon.isSingleEmoji {
            draft = selectedIcon
          }
        }
        .onChange(of: draft) { _, newValue in
          // Keep only first emoji and sync with selection
          if let first = newValue.first {
            let val = String(first)
            if draft != val { draft = val }
            selectedIcon = val
          } else {
            selectedIcon = "None"
          }
        }

        // Existing emoji grid picker; selecting an emoji still confirms and closes
        EmojiKeyboardView { emoji in
          draft = String(emoji.first ?? " ")
          selectedIcon = draft.isEmpty ? emoji : draft
          onClose()
        }
      }
    }
    .background(.surface2)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    // Block swipe-to-dismiss to avoid race with keyboard animation
    .interactiveDismissDisabled(true)
    .onDisappear {
      // Ensure keyboard is dismissed when the sheet closes
      isFocused = false
      // Hard-stop: force-dismiss any active keyboard globally
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil)
    }
  }

  @FocusState private var isFocused: Bool
  @State private var draft: String = ""
}

#Preview {
  IconBottomSheet(
    selectedIcon: .constant("🏃‍♂️"),
    onClose: { })
}
