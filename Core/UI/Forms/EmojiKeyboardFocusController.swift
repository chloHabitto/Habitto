import SwiftUI
import UIKit

// MARK: - EmojiKeyboardFocusController

/// Centralized controller that can prewarm and release the system emoji keyboard
/// by momentarily focusing a hidden `EmojiPreferringTextField`.
final class EmojiKeyboardFocusController: ObservableObject {
  @Published fileprivate var shouldActivateProxy = false

  /// Ask the hidden proxy text field to become first responder immediately.
  func prewarmKeyboard() {
    DispatchQueue.main.async {
      self.shouldActivateProxy = true
    }
  }

  /// Release the proxy keyboard (if currently focused).
  func releaseKeyboard() {
    DispatchQueue.main.async {
      self.shouldActivateProxy = false
    }
  }
}

// MARK: - EmojiKeyboardFocusProxyView

/// Invisible UIKit text field that prefers the emoji keyboard and can be toggled on demand.
struct EmojiKeyboardFocusProxyView: UIViewRepresentable {
  @ObservedObject var controller: EmojiKeyboardFocusController

  func makeUIView(context _: Context) -> UITextField {
    let textField = EmojiPreferringTextField()
    textField.keyboardType = .default
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    textField.spellCheckingType = .no
    textField.tintColor = .clear
    textField.textColor = .clear
    textField.backgroundColor = .clear
    textField.isHidden = true
    textField.borderStyle = .none
    textField.inputAccessoryView = UIView() // Hide toolbar
    textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
    textField.setContentHuggingPriority(.defaultLow, for: .vertical)
    return textField
  }

  func updateUIView(_ uiView: UITextField, context _: Context) {
    if controller.shouldActivateProxy {
      focusIfNeeded(uiView)
    } else if uiView.isFirstResponder {
      uiView.resignFirstResponder()
    }
  }

  private func focusIfNeeded(_ textField: UITextField) {
    guard textField.window != nil else {
      DispatchQueue.main.async { [weak textField] in
        guard let tf = textField else { return }
        focusIfNeeded(tf)
      }
      return
    }

    if textField.isFirstResponder == false {
      textField.becomeFirstResponder()
    }
  }
}

