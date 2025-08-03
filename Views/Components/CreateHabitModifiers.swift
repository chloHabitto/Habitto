import SwiftUI

// MARK: - Shared Modifiers for Create Habit Flow
// These modifiers provide consistent styling across all Create Habit step views

struct InputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.outline, lineWidth: 1.5)
            )
            .cornerRadius(12)
    }
}

struct SelectionRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.outline, lineWidth: 1.5)
            )
            .cornerRadius(12)
    }
}

// MARK: - Extension for easy access
extension View {
    func inputFieldStyle() -> some View {
        self.modifier(InputFieldModifier())
    }
    
    func selectionRowStyle() -> some View {
        self.modifier(SelectionRowModifier())
    }
} 
