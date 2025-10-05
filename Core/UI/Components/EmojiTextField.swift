import SwiftUI
import UIKit

// MARK: - Custom Emoji TextField
class UIEmojiTextField: UITextField {
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setEmoji() {
        _ = self.textInputMode
    }
    
    override var textInputContextIdentifier: String? {
        return ""
    }
    
    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                self.keyboardType = .default // do not remove this
                return mode
            }
        }
        return nil
    }
}

// MARK: - Emoji TextField Delegate
class EmojiTextFieldDelegate: NSObject, UITextFieldDelegate {
    @Binding var selectedEmoji: String
    let onEmojiSelected: (String) -> Void
    
    init(selectedEmoji: Binding<String>, onEmojiSelected: @escaping (String) -> Void) {
        self._selectedEmoji = selectedEmoji
        self.onEmojiSelected = onEmojiSelected
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Allow deletion
        if string.isEmpty {
            selectedEmoji = ""
            onEmojiSelected("")
            return true
        }
        
        // Check if the replacement string contains only emoji
        if string.containsOnlyEmoji {
            // Limit to single emoji - take only the first emoji
            let singleEmoji = string.emojisPrefix(1)
            textField.text = singleEmoji // Manually set the text field content
            selectedEmoji = singleEmoji
            onEmojiSelected(singleEmoji)
            return false // We handled the change manually
        }
        
        // Reject non-emoji input
        return false
    }
}

// MARK: - Emoji Text Field UIViewRepresentable
struct EmojiTextField: UIViewRepresentable {
    @Binding var selectedEmoji: String
    let onEmojiSelected: (String) -> Void
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onTextFieldCreated: ((UIEmojiTextField) -> Void)?
    
    init(selectedEmoji: Binding<String>, onEmojiSelected: @escaping (String) -> Void, isFocused: Bool, onFocusChange: @escaping (Bool) -> Void, onTextFieldCreated: ((UIEmojiTextField) -> Void)? = nil) {
        self._selectedEmoji = selectedEmoji
        self.onEmojiSelected = onEmojiSelected
        self.isFocused = isFocused
        self.onFocusChange = onFocusChange
        self.onTextFieldCreated = onTextFieldCreated
    }
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.delegate = context.coordinator
        emojiTextField.text = selectedEmoji
        emojiTextField.placeholder = "Tap to enter emoji"
        emojiTextField.font = UIFont.systemFont(ofSize: 20)
        emojiTextField.textAlignment = .center
        emojiTextField.borderStyle = .none
        emojiTextField.backgroundColor = UIColor.clear
        
        // Configure for emoji input
        emojiTextField.keyboardType = .default
        emojiTextField.autocorrectionType = .no
        emojiTextField.autocapitalizationType = .none
        
        if #available(iOS 13.0, *) {
            emojiTextField.textContentType = .none
        }
        
        // Make sure it can become first responder
        emojiTextField.isUserInteractionEnabled = true
        
        // Force emoji keyboard
        emojiTextField.setEmoji()
        
        // Try to focus immediately if we should be focused
        if isFocused {
            DispatchQueue.main.async {
                emojiTextField.becomeFirstResponder()
                emojiTextField.setEmoji()
            }
        }
        
        // Notify parent about the text field creation
        onTextFieldCreated?(emojiTextField)
        
        // Additional aggressive focus attempts - ALWAYS try
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            emojiTextField.becomeFirstResponder()
            emojiTextField.setEmoji()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emojiTextField.becomeFirstResponder()
            emojiTextField.setEmoji()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            emojiTextField.becomeFirstResponder()
            emojiTextField.setEmoji()
        }
        
        return emojiTextField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        uiView.text = selectedEmoji
        
        // ALWAYS try to focus - no conditions
        if isFocused {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.setEmoji() // Force emoji keyboard when focusing
            }
            
            // Additional aggressive attempts - ALWAYS try
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.becomeFirstResponder()
                uiView.setEmoji()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                uiView.becomeFirstResponder()
                uiView.setEmoji()
            }
        }
        // Remove the resignFirstResponder - we want it ALWAYS focused
    }
    
    func makeCoordinator() -> EmojiTextFieldDelegate {
        EmojiTextFieldDelegate(selectedEmoji: $selectedEmoji, onEmojiSelected: onEmojiSelected)
    }
}
