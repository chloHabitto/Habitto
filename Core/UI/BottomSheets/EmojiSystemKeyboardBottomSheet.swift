import SwiftUI

struct EmojiSystemKeyboardBottomSheet: View {
  @Binding var selectedEmoji: String

  let onClose: () -> Void
  let onSave: (String) -> Void
  @Environment(\.dismiss) private var dismiss

  @FocusState private var isFocused: Bool
  @State private var draft: String = ""
  @State private var hasAppeared = false
  @State private var focusEnforcer: Task<Void, Never>? = nil
  @State private var allowResign: Bool = false
  @State private var isClosing: Bool = false
  @StateObject private var keyboardController = EmojiKeyboardFocusController()

  var body: some View {
    // Two-phase close: keyboard first, then sheet
    let initiateClose: () -> Void = {
      guard isClosing == false else { return }
      isClosing = true
      keyboardController.releaseKeyboard()
      allowResign = true
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
      title: "Choose Icon",
      description: "Select an emoji for your habit",
      onClose: initiateClose,
      confirmButton: {
        // Save selection, then close via the same two-phase approach
        let normalized = draft.isEmpty ? selectedEmoji : draft
        isClosing = true
        keyboardController.releaseKeyboard()
        allowResign = true
        isFocused = false
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil,
          from: nil,
          for: nil)
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(300))
          onSave(normalized)
          dismiss()
          onClose()
        }
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
          },
          onEndEditing: {
            // If we are not in a dismissal flow, keep the keyboard open
            if allowResign == false {
              isFocused = true
            }
          },
          // Allow resign only when the sheet is actively dismissing
          shouldAllowEndEditing: {
            allowResign
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

        // Hidden proxy for instant keyboard display
        EmojiKeyboardFocusProxyView(controller: keyboardController)
          .frame(width: 0, height: 0)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      // Allow intentional keyboard dismissal by tapping outside the field
      .contentShape(Rectangle())
    }
    .background(.surface2)
    // Block swipe-to-dismiss entirely to avoid racing with keyboard animation
    .interactiveDismissDisabled(true)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .onAppear {
      keyboardController.prewarmKeyboard()
      print("📱 Sheet appeared")
      hasAppeared = true
      allowResign = false
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
        if hasAppeared {
          isFocused = true
        }
      }
      // Final retry if needed for slower animations/devices
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(350))
        if hasAppeared {
          isFocused = true
        }
      }
      // Safety retry for slow devices/transitions
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(800))
        if hasAppeared {
          isFocused = true
        }
      }
      // Aggressive focus enforcement loop while the sheet is visible
      focusEnforcer?.cancel()
      focusEnforcer = Task { @MainActor in
        // Run for up to ~3 seconds, nudging focus every 120ms
        for _ in 0..<25 {
          if Task.isCancelled { break }
          if hasAppeared {
            isFocused = true
          } else {
            break
          }
          try? await Task.sleep(for: .milliseconds(120))
        }
      }
    }
    // If the global "choose icon" sheet closes elsewhere, permit resign and drop focus immediately.
    .onReceive(NotificationCenter.default.publisher(for: .iconSheetClosed)) { _ in
      allowResign = true
      isFocused = false
      keyboardController.releaseKeyboard()
    }
    .onDisappear {
      print("👋 Sheet disappearing")
      hasAppeared = false
      focusEnforcer?.cancel()
      focusEnforcer = nil
      // Ensure we allow the text field to resign when this sheet goes away
      allowResign = true
      isFocused = false
      keyboardController.releaseKeyboard()
      // Hard-stop: force-dismiss any active keyboard globally
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil)
    }
  }
}

#if DEBUG
#Preview {
  EmojiSystemKeyboardBottomSheet(
    selectedEmoji: .constant(""),
    onClose: { },
    onSave: { _ in })
  .environmentObject(EmojiKeyboardFocusController())
}
#endif


