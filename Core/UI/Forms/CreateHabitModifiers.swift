import SwiftUI

// MARK: - InputFieldModifier

// These modifiers provide consistent styling across all Create Habit step views

struct InputFieldModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 8)
      .padding(.vertical, 12)
      .background(.appSurface2)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(.outline3, lineWidth: 1.5))
      .cornerRadius(12)
  }
}

// MARK: - SelectionRowModifier

struct SelectionRowModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.appSurface)
      .cornerRadius(12)
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
