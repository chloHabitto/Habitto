import SwiftUI
import UIKit

// MARK: - UIKitTextFieldWithDoneButton

struct UIKitTextFieldWithDoneButton: UIViewRepresentable {
  /**
   UIKit-backed text field with an integrated Done toolbar button.
   - Note: iOS does not provide a dedicated emoji keyboard type (there is no UIKeyboardType.emoji). Users should switch to the emoji keyboard manually using the globe/emoji key.
   - Focus control: pass an optional `isFocused` binding to programmatically control focus (become/resign first responder) similar to SwiftUI's `@FocusState`.
   - Validation: provide `shouldChangeText` for input validation (e.g., to restrict to emoji-only input).
   */
  // MARK: Lifecycle

  init(
    text: Binding<String>,
    placeholder: String = "",
    keyboardType: UIKeyboardType = .default,
    // Keyboard customization (sensible defaults to preserve current behavior)
    returnKeyType: UIReturnKeyType = .done,
    textContentType: UITextContentType? = nil,
    autocorrectionType: UITextAutocorrectionType = .default,
    autocapitalizationType: UITextAutocapitalizationType = .sentences,
    isSecureTextEntry: Bool = false,
    clearButtonMode: UITextField.ViewMode = .never,
      // Toolbar
      showDoneToolbar: Bool = true,
    // Appearance
    font: UIFont = UIFont.systemFont(ofSize: 16),
    textColor: UIColor = .label,
    backgroundColor: UIColor = .systemBackground,
    borderColor: UIColor = .systemGray4,
    cornerRadius: CGFloat = 12,
    lineWidth: CGFloat = 1.5,
    minHeight: CGFloat = 48,
    horizontalPadding: CGFloat = 16,
    multilineTextAlignment: NSTextAlignment = .left,
    // Keyboard preference
    preferEmojiKeyboard: Bool = false,
    // Focus and callbacks
    isFocused: Binding<Bool>? = nil,
    onBeginEditing: (() -> Void)? = nil,
    onEndEditing: (() -> Void)? = nil,
    // Return true to allow resign, false to keep keyboard open
    shouldAllowEndEditing: (() -> Bool)? = nil,
    shouldChangeText: ((String, NSRange, String) -> Bool)? = nil)
  {
    self._text = text
    self.placeholder = placeholder
    self.keyboardType = keyboardType
    self.returnKeyType = returnKeyType
    self.textContentType = textContentType
    self.autocorrectionType = autocorrectionType
    self.autocapitalizationType = autocapitalizationType
    self.isSecureTextEntry = isSecureTextEntry
    self.clearButtonMode = clearButtonMode
      self.showDoneToolbar = showDoneToolbar
    self.font = font
    self.textColor = textColor
    self.backgroundColor = backgroundColor
    self.borderColor = borderColor
    self.cornerRadius = cornerRadius
    self.lineWidth = lineWidth
    self.minHeight = minHeight
    self.horizontalPadding = horizontalPadding
    self.multilineTextAlignment = multilineTextAlignment
    self.preferEmojiKeyboard = preferEmojiKeyboard
    self.isFocused = isFocused
    self.onBeginEditing = onBeginEditing
    self.onEndEditing = onEndEditing
    self.shouldAllowEndEditing = shouldAllowEndEditing
    self.shouldChangeText = shouldChangeText
  }

  // MARK: Internal

  class Coordinator: NSObject, UITextFieldDelegate {
    // MARK: Lifecycle

    init(_ parent: UIKitTextFieldWithDoneButton) {
      self.parent = parent
    }

    // MARK: Internal

    // Storing a value-type copy of the parent avoids retain cycles.
    var parent: UIKitTextFieldWithDoneButton

    func textFieldDidChangeSelection(_ textField: UITextField) {
      parent.text = textField.text ?? ""
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
      parent.isFocused?.wrappedValue = true
      parent.onBeginEditing?()
      // Ensure return key type stays in sync if changed dynamically
      textField.returnKeyType = parent.returnKeyType
    }

    func textFieldDidEndEditing(_: UITextField) {
      parent.isFocused?.wrappedValue = false
      parent.onEndEditing?()
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
      // If a policy is provided, enforce it; otherwise allow default behavior
      if let policy = parent.shouldAllowEndEditing {
        return policy()
      }
      return true
    }

    func textField(
      _ textField: UITextField,
      shouldChangeCharactersIn range: NSRange,
      replacementString string: String
    ) -> Bool {
      // If no validator is supplied, allow by default
      guard let validator = parent.shouldChangeText else { return true }
      // Provide current text to the callback (as requested)
      return validator(textField.text ?? "", range, string)
    }
  }

  @Binding var text: String

  let placeholder: String
  let keyboardType: UIKeyboardType
  let returnKeyType: UIReturnKeyType
  let textContentType: UITextContentType?
  let autocorrectionType: UITextAutocorrectionType
  let autocapitalizationType: UITextAutocapitalizationType
  let isSecureTextEntry: Bool
  let clearButtonMode: UITextField.ViewMode
    let showDoneToolbar: Bool
  let font: UIFont
  let textColor: UIColor
  let backgroundColor: UIColor
  let borderColor: UIColor
  let cornerRadius: CGFloat
  let lineWidth: CGFloat
  let minHeight: CGFloat
  let horizontalPadding: CGFloat
  let multilineTextAlignment: NSTextAlignment
  let preferEmojiKeyboard: Bool
  let isFocused: Binding<Bool>?
  let onBeginEditing: (() -> Void)?
  let onEndEditing: (() -> Void)?
  let shouldAllowEndEditing: (() -> Bool)?
  let shouldChangeText: ((String, NSRange, String) -> Bool)?

  func makeUIView(context: Context) -> UITextField {
    let textField: UITextField
    if preferEmojiKeyboard {
      textField = EmojiPreferringTextField()
    } else {
      textField = UITextField()
    }

    // Configure text field
    textField.placeholder = placeholder
    textField.keyboardType = keyboardType
    textField.returnKeyType = returnKeyType
    textField.textContentType = textContentType
    textField.autocorrectionType = autocorrectionType
    textField.autocapitalizationType = autocapitalizationType
    textField.isSecureTextEntry = isSecureTextEntry
    textField.clearButtonMode = clearButtonMode
    textField.font = font
    textField.textColor = textColor
    textField.textAlignment = multilineTextAlignment
    textField.delegate = context.coordinator

    // Configure appearance
    textField.backgroundColor = backgroundColor
    textField.layer.cornerRadius = cornerRadius
    textField.layer.borderWidth = lineWidth
    textField.layer.borderColor = borderColor.cgColor
    textField.layer.masksToBounds = true

    // Configure padding
    textField.leftView = UIView(frame: CGRect(
      x: 0,
      y: 0,
      width: horizontalPadding,
      height: minHeight))
    textField.leftViewMode = .always
    textField.rightView = UIView(frame: CGRect(
      x: 0,
      y: 0,
      width: horizontalPadding,
      height: minHeight))
    textField.rightViewMode = .always

    // Set constraints for minimum height
    textField.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true

    // Add Done button toolbar - THIS IS THE KEY PART
    if showDoneToolbar {
      addDoneButtonToolbar(to: textField)
    }

    // If focus is already requested at creation time, attempt to focus now and with retries
    if isFocused?.wrappedValue == true {
      // Try immediately if attached
      if textField.window != nil {
        DispatchQueue.main.async {
          textField.becomeFirstResponder()
        }
      }
      // Schedule retries to cover attachment timing
      let delays: [UInt64] = [120, 220, 420, 800, 1200, 1600, 2000] // ms
      for delay in delays {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delay))) { [weak textField] in
          guard let tf = textField else { return }
          if self.isFocused?.wrappedValue == true, tf.isFirstResponder == false, tf.window != nil {
            tf.becomeFirstResponder()
          }
        }
      }
    }

    return textField
  }

  func updateUIView(_ uiView: UITextField, context _: Context) {
    uiView.text = text
    // Programmatic focus control
    if let shouldFocus = isFocused?.wrappedValue {
      if shouldFocus && uiView.isFirstResponder == false {
        // Attempt to focus immediately if attached to a window; otherwise retry shortly
        focusTextField(uiView)
      } else if shouldFocus == false && uiView.isFirstResponder {
        DispatchQueue.main.async {
          uiView.resignFirstResponder()
        }
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  // MARK: Private

  // MARK: - Private Helper
  private func focusTextField(_ textField: UITextField) {
    // If already attached, focus immediately
    if textField.window != nil {
      DispatchQueue.main.async {
        textField.becomeFirstResponder()
      }
      return
    }
    // Otherwise, schedule a few retries to outlast sheet animations/attachment timing
    let delays: [UInt64] = [120, 220, 420, 800, 1200, 1600, 2000] // milliseconds
    for delay in delays {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delay))) { [weak textField] in
        guard let tf = textField else { return }
        // Only proceed if focus is still requested
        if self.isFocused?.wrappedValue == true, tf.isFirstResponder == false {
          if tf.window != nil {
            tf.becomeFirstResponder()
          }
        }
      }
    }
  }

  private func addDoneButtonToolbar(to textField: UITextField) {
    let toolbar = UIToolbar()
    toolbar.sizeToFit()

    let doneButton = UIBarButtonItem(
      title: "Done",
      style: .done,
      target: textField,
      action: #selector(UITextField.resignFirstResponder))

    let spacer = UIBarButtonItem(
      barButtonSystemItem: .flexibleSpace,
      target: nil,
      action: nil)

    toolbar.items = [spacer, doneButton]
    textField.inputAccessoryView = toolbar
  }
}

// MARK: - EmojiPreferringTextField

final class EmojiPreferringTextField: UITextField {
  override var textInputMode: UITextInputMode? {
    // Prefer the emoji keyboard when available
    for mode in UITextInputMode.activeInputModes {
      if mode.primaryLanguage == "emoji" {
        return mode
      }
    }
    return super.textInputMode
  }
}

// MARK: - SwiftUITextFieldAdapter

struct SwiftUITextFieldAdapter: View {
  // MARK: Lifecycle

  init(
    text: Binding<String>,
    placeholder: String = "",
    keyboardType: UIKeyboardType = .default,
    // Keyboard customization passthroughs
    returnKeyType: UIReturnKeyType = .done,
    textContentType: UITextContentType? = nil,
    autocorrectionType: UITextAutocorrectionType = .default,
    autocapitalizationType: UITextAutocapitalizationType = .sentences,
    isSecureTextEntry: Bool = false,
    clearButtonMode: UITextField.ViewMode = .never,
      showDoneToolbar: Bool = true,
    font: Font = .body,
    textColor: Color = .primary,
    backgroundColor: Color = .clear,
    borderColor: Color = .gray,
    cornerRadius: CGFloat = 12,
    lineWidth: CGFloat = 1.5,
    minHeight: CGFloat = 48,
    horizontalPadding: CGFloat = 16,
    multilineTextAlignment: NSTextAlignment = .left,
    // Keyboard preference
    preferEmojiKeyboard: Bool = false,
    // Focus and callbacks
    isFocused: Binding<Bool>? = nil,
    onBeginEditing: (() -> Void)? = nil,
    onEndEditing: (() -> Void)? = nil,
    // Return true to allow resign, false to keep keyboard open
    shouldAllowEndEditing: (() -> Bool)? = nil,
    shouldChangeText: ((String, NSRange, String) -> Bool)? = nil)
  {
    self._text = text
    self.placeholder = placeholder
    self.keyboardType = keyboardType
    self.returnKeyType = returnKeyType
    self.textContentType = textContentType
    self.autocorrectionType = autocorrectionType
    self.autocapitalizationType = autocapitalizationType
    self.isSecureTextEntry = isSecureTextEntry
    self.clearButtonMode = clearButtonMode
      self.showDoneToolbar = showDoneToolbar
    self.font = font
    self.textColor = textColor
    self.backgroundColor = backgroundColor
    self.borderColor = borderColor
    self.cornerRadius = cornerRadius
    self.lineWidth = lineWidth
    self.minHeight = minHeight
    self.horizontalPadding = horizontalPadding
    self.multilineTextAlignment = multilineTextAlignment
    self.preferEmojiKeyboard = preferEmojiKeyboard
    self.isFocused = isFocused
    self.onBeginEditing = onBeginEditing
    self.onEndEditing = onEndEditing
    self.shouldAllowEndEditing = shouldAllowEndEditing
    self.shouldChangeText = shouldChangeText
  }

  // MARK: Internal

  @Binding var text: String

  let placeholder: String
  let keyboardType: UIKeyboardType
  let returnKeyType: UIReturnKeyType
  let textContentType: UITextContentType?
  let autocorrectionType: UITextAutocorrectionType
  let autocapitalizationType: UITextAutocapitalizationType
  let isSecureTextEntry: Bool
  let clearButtonMode: UITextField.ViewMode
    let showDoneToolbar: Bool
  let font: Font
  let textColor: Color
  let backgroundColor: Color
  let borderColor: Color
  let cornerRadius: CGFloat
  let lineWidth: CGFloat
  let minHeight: CGFloat
  let horizontalPadding: CGFloat
  let multilineTextAlignment: NSTextAlignment
  let preferEmojiKeyboard: Bool
  let isFocused: Binding<Bool>?
  let onBeginEditing: (() -> Void)?
  let onEndEditing: (() -> Void)?
  let shouldAllowEndEditing: (() -> Bool)?
  let shouldChangeText: ((String, NSRange, String) -> Bool)?

  var body: some View {
    UIKitTextFieldWithDoneButton(
      text: $text,
      placeholder: placeholder,
      keyboardType: keyboardType,
      returnKeyType: returnKeyType,
      textContentType: textContentType,
      autocorrectionType: autocorrectionType,
      autocapitalizationType: autocapitalizationType,
      isSecureTextEntry: isSecureTextEntry,
      clearButtonMode: clearButtonMode,
        showDoneToolbar: showDoneToolbar,
      font: UIFont.preferredFont(forTextStyle: fontToUIFontStyle(font)),
      textColor: UIColor(textColor),
      backgroundColor: UIColor(backgroundColor),
      borderColor: UIColor(borderColor),
      cornerRadius: cornerRadius,
      lineWidth: lineWidth,
      minHeight: minHeight,
      horizontalPadding: horizontalPadding,
      multilineTextAlignment: multilineTextAlignment,
      preferEmojiKeyboard: preferEmojiKeyboard,
      isFocused: isFocused,
      onBeginEditing: onBeginEditing,
      onEndEditing: onEndEditing,
      shouldAllowEndEditing: shouldAllowEndEditing,
      shouldChangeText: shouldChangeText)
  }

  // MARK: Private

  private func fontToUIFontStyle(_: Font) -> UIFont.TextStyle {
    // Convert SwiftUI Font to UIFont.TextStyle
    // This is a simplified mapping. SwiftUI Font does not expose enough runtime info
    // to reliably detect exact styles here. If precise sizing is needed, prefer passing
    // a concrete UIFont via UIKitTextFieldWithDoneButton.
    .body
  }
}

#Preview {
  VStack(spacing: 20) {
    SwiftUITextFieldAdapter(
      text: .constant(""),
      placeholder: "Enter text (letters)",
      keyboardType: .default)

    SwiftUITextFieldAdapter(
      text: .constant(""),
      placeholder: "Enter number",
      keyboardType: .numberPad)

    SwiftUITextFieldAdapter(
      text: .constant(""),
      placeholder: "Enter decimal",
      keyboardType: .decimalPad)
  }
  .padding()
}
