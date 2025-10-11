import SwiftUI

// MARK: - KeyboardDoneButtonToolbar

struct KeyboardDoneButtonToolbar: ViewModifier {
  // MARK: Internal

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") {
            hideKeyboard()
          }
          .font(.appBodyMedium)
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.accentColor)
          .clipShape(Capsule())
        }
      }
  }

  // MARK: Private

  private func hideKeyboard() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil)
  }
}

// MARK: - KeyboardHandlingModifier

struct KeyboardHandlingModifier: ViewModifier {
  // MARK: Lifecycle

  init(dismissOnTapOutside: Bool = true, showDoneButton: Bool = false) {
    self.dismissOnTapOutside = dismissOnTapOutside
    self.showDoneButton = showDoneButton
  }

  // MARK: Internal

  let dismissOnTapOutside: Bool
  let showDoneButton: Bool

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
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil,
          from: nil,
          for: nil)
      }
    }
  }
}

// MARK: - FocusStateManager

class FocusStateManager: ObservableObject {
  @Published var isNameFieldFocused = false
  @Published var isGoalNumberFocused = false
  @Published var isDescriptionFieldFocused = false
  @Published var isBaselineFieldFocused = false
  @Published var isTargetFieldFocused = false

  /// Simplified focus methods to prevent UI hangs
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
  func keyboardHandling(
    dismissOnTapOutside: Bool = true,
    showDoneButton: Bool = false) -> some View
  {
    modifier(KeyboardHandlingModifier(
      dismissOnTapOutside: dismissOnTapOutside,
      showDoneButton: showDoneButton))
  }

  /// Adds a "Done" button above the keyboard for text input fields
  func keyboardDoneButton() -> some View {
    modifier(KeyboardDoneButtonToolbar())
  }
}
