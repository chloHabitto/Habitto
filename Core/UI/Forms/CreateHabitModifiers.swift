import SwiftUI

// MARK: - InputFieldModifier

// These modifiers provide consistent styling across all Create Habit step views

struct InputFieldModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 8)
      .padding(.vertical, 12)
      .background(.surface)
      .cornerRadius(16)
  }
}

// MARK: - SelectionRowModifier

struct SelectionRowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.surface)
      .cornerRadius(16)
  }
}

// MARK: - Extension for easy access

extension View {
  func inputFieldStyle() -> some View {
    modifier(InputFieldModifier())
  }

  func selectionRowStyle() -> some View {
    modifier(SelectionRowModifier())
  }
}
