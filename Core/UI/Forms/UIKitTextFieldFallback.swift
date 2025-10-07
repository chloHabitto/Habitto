import SwiftUI
import UIKit

// MARK: - UIKit TextField with Guaranteed Done Button
struct UIKitTextFieldWithDoneButton: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor
    let borderColor: UIColor
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let multilineTextAlignment: NSTextAlignment
    
    init(
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        font: UIFont = UIFont.systemFont(ofSize: 16),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        borderColor: UIColor = .systemGray4,
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 1.5,
        minHeight: CGFloat = 48,
        horizontalPadding: CGFloat = 16,
        multilineTextAlignment: NSTextAlignment = .left
    ) {
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.minHeight = minHeight
        self.horizontalPadding = horizontalPadding
        self.multilineTextAlignment = multilineTextAlignment
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        
        // Configure text field
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
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
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: horizontalPadding, height: minHeight))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: horizontalPadding, height: minHeight))
        textField.rightViewMode = .always
        
        // Set constraints for minimum height
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        
        // Add Done button toolbar - THIS IS THE KEY PART
        addDoneButtonToolbar(to: textField)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: UIKitTextFieldWithDoneButton
        
        init(_ parent: UIKitTextFieldWithDoneButton) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
    
    // MARK: - Private Helper
    private func addDoneButtonToolbar(to textField: UITextField) {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: textField,
            action: #selector(UITextField.resignFirstResponder)
        )
        
        let spacer = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )
        
        toolbar.items = [spacer, doneButton]
        textField.inputAccessoryView = toolbar
    }
}

// MARK: - SwiftUI Adapter for Easy Drop-in Replacement
struct SwiftUITextFieldAdapter: View {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let font: Font
    let textColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let multilineTextAlignment: NSTextAlignment
    
    init(
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        font: Font = .body,
        textColor: Color = .primary,
        backgroundColor: Color = .clear,
        borderColor: Color = .gray,
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 1.5,
        minHeight: CGFloat = 48,
        horizontalPadding: CGFloat = 16,
        multilineTextAlignment: NSTextAlignment = .left
    ) {
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.minHeight = minHeight
        self.horizontalPadding = horizontalPadding
        self.multilineTextAlignment = multilineTextAlignment
    }
    
    var body: some View {
        UIKitTextFieldWithDoneButton(
            text: $text,
            placeholder: placeholder,
            keyboardType: keyboardType,
            font: UIFont.preferredFont(forTextStyle: fontToUIFontStyle(font)),
            textColor: UIColor(textColor),
            backgroundColor: UIColor(backgroundColor),
            borderColor: UIColor(borderColor),
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            minHeight: minHeight,
            horizontalPadding: horizontalPadding,
            multilineTextAlignment: multilineTextAlignment
        )
    }
    
    private func fontToUIFontStyle(_ font: Font) -> UIFont.TextStyle {
        // Convert SwiftUI Font to UIFont.TextStyle
        // This is a simplified mapping - you might need to expand based on your needs
        return .body
    }
}

#Preview {
    VStack(spacing: 20) {
        SwiftUITextFieldAdapter(
            text: .constant(""),
            placeholder: "Enter text (letters)",
            keyboardType: .default
        )
        
        SwiftUITextFieldAdapter(
            text: .constant(""),
            placeholder: "Enter number",
            keyboardType: .numberPad
        )
        
        SwiftUITextFieldAdapter(
            text: .constant(""),
            placeholder: "Enter decimal",
            keyboardType: .decimalPad
        )
    }
    .padding()
}
