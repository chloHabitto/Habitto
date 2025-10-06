import SwiftUI

// MARK: - Keyboard Done Button Toolbar
struct KeyboardDoneButtonToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(.appBodyMedium)
                    .foregroundColor(.primary)
                }
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Unified Keyboard Handling Modifier
struct KeyboardHandlingModifier: ViewModifier {
    let dismissOnTapOutside: Bool
    let showDoneButton: Bool
    
    init(dismissOnTapOutside: Bool = true, showDoneButton: Bool = false) {
        self.dismissOnTapOutside = dismissOnTapOutside
        self.showDoneButton = showDoneButton
    }
    
    func body(content: Content) -> some View {
        Group {
            if showDoneButton {
                content
                    .modifier(KeyboardDoneButtonToolbar())
            } else {
                content
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            if dismissOnTapOutside {
                // Only dismiss if tapping outside of text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// MARK: - Simple Focus State Manager
class FocusStateManager: ObservableObject {
    @Published var isNameFieldFocused: Bool = false
    @Published var isGoalNumberFocused: Bool = false
    @Published var isDescriptionFieldFocused: Bool = false
    @Published var isBaselineFieldFocused: Bool = false
    @Published var isTargetFieldFocused: Bool = false
    
    // Simplified focus methods to prevent UI hangs
    func focusNameField() {
        DispatchQueue.main.async {
            self.dismissAll()
            self.isNameFieldFocused = true
        }
    }
    
    func focusGoalNumberField() {
        DispatchQueue.main.async {
            self.dismissAll()
            self.isGoalNumberFocused = true
        }
    }
    
    func focusDescriptionField() {
        DispatchQueue.main.async {
            self.dismissAll()
            self.isDescriptionFieldFocused = true
        }
    }
    
    func focusBaselineField() {
        DispatchQueue.main.async {
            self.dismissAll()
            self.isBaselineFieldFocused = true
        }
    }
    
    func focusTargetField() {
        DispatchQueue.main.async {
            self.dismissAll()
            self.isTargetFieldFocused = true
        }
    }
    
    func dismissAll() {
        isNameFieldFocused = false
        isGoalNumberFocused = false
        isDescriptionFieldFocused = false
        isBaselineFieldFocused = false
        isTargetFieldFocused = false
    }
}

// MARK: - View Extensions
extension View {
    func keyboardHandling(dismissOnTapOutside: Bool = true, showDoneButton: Bool = false) -> some View {
        self.modifier(KeyboardHandlingModifier(dismissOnTapOutside: dismissOnTapOutside, showDoneButton: showDoneButton))
    }
    
    /// Adds a "Done" button above the keyboard for text input fields
    func keyboardDoneButton() -> some View {
        self.modifier(KeyboardDoneButtonToolbar())
    }
} 