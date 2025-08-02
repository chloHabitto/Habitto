import SwiftUI

// MARK: - Unified Keyboard Handling Modifier
struct KeyboardHandlingModifier: ViewModifier {
    let dismissOnTapOutside: Bool
    let showDoneButton: Bool
    
    init(dismissOnTapOutside: Bool = true, showDoneButton: Bool = false) {
        self.dismissOnTapOutside = dismissOnTapOutside
        self.showDoneButton = showDoneButton
    }
    
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onTapGesture {
                if dismissOnTapOutside {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
    }
}

// MARK: - Focus State Manager
class FocusStateManager: ObservableObject {
    @Published var isNameFieldFocused: Bool = false
    @Published var isGoalNumberFocused: Bool = false
    @Published var isDescriptionFieldFocused: Bool = false
    @Published var isBaselineFieldFocused: Bool = false
    @Published var isTargetFieldFocused: Bool = false
    
    func focusNameField() {
        isNameFieldFocused = true
        isGoalNumberFocused = false
        isDescriptionFieldFocused = false
        isBaselineFieldFocused = false
        isTargetFieldFocused = false
    }
    
    func focusGoalNumberField() {
        isNameFieldFocused = false
        isGoalNumberFocused = true
        isDescriptionFieldFocused = false
        isBaselineFieldFocused = false
        isTargetFieldFocused = false
    }
    
    func focusDescriptionField() {
        isNameFieldFocused = false
        isGoalNumberFocused = false
        isDescriptionFieldFocused = true
        isBaselineFieldFocused = false
        isTargetFieldFocused = false
    }
    
    func focusBaselineField() {
        isNameFieldFocused = false
        isGoalNumberFocused = false
        isDescriptionFieldFocused = false
        isBaselineFieldFocused = true
        isTargetFieldFocused = false
    }
    
    func focusTargetField() {
        isNameFieldFocused = false
        isGoalNumberFocused = false
        isDescriptionFieldFocused = false
        isBaselineFieldFocused = false
        isTargetFieldFocused = true
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
} 