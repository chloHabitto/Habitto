import SwiftUI

// MARK: - BaseBottomSheet

struct BaseBottomSheet<Content: View>: View {
  // MARK: Lifecycle

  init(
    title: String,
    description: String,
    onClose: @escaping () -> Void,
    useGlassCloseButton: Bool = false,
    confirmButton: (() -> Void)? = nil,
    confirmButtonTitle: String? = nil,
    @ViewBuilder content: () -> Content)
  {
    self.title = title
    self.description = description
    self.onClose = onClose
    self.useGlassCloseButton = useGlassCloseButton
    self.confirmButton = confirmButton
    self.confirmButtonTitle = confirmButtonTitle
    self.content = content()
  }

  // MARK: Internal

  let title: String
  let description: String
  let onClose: () -> Void
  let useGlassCloseButton: Bool
  let content: Content
  let confirmButton: (() -> Void)?
  let confirmButtonTitle: String?

  var body: some View {
    VStack(spacing: 0) {
      // Header
      BottomSheetHeader(
        title: title,
        description: description,
        onClose: onClose,
        useGlassCloseButton: useGlassCloseButton)

      // Content
      content

      // Confirm button if provided
      if let confirmButton, let confirmButtonTitle {
        VStack(spacing: 0) {
          Divider()

          HabittoButton.largeFillPrimary(
            text: confirmButtonTitle,
            action: confirmButton)
            .padding(24)
        }
      }
    }
    .background(.surface)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(32)
  }
}

// MARK: - Convenience Initializers

extension BaseBottomSheet where Content == AnyView {
  init(
    title: String,
    description: String,
    onClose: @escaping () -> Void,
    useGlassCloseButton: Bool = false,
    @ViewBuilder content: () -> some View)
  {
    self.init(
      title: title,
      description: description,
      onClose: onClose,
      useGlassCloseButton: useGlassCloseButton,
      content: { AnyView(content()) })
  }
}

#Preview {
  BaseBottomSheet(
    title: "Test Sheet",
    description: "This is a test description",
    onClose: { },
    confirmButton: { },
    confirmButtonTitle: "Confirm")
  {
    VStack {
      Text("Content goes here")
      Spacer()
    }
    .padding()
  }
}
