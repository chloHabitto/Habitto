import SwiftUI

// MARK: - BaseBottomSheet

struct BaseBottomSheet<Content: View>: View {
  // MARK: Lifecycle

  init(
    title: String,
    description: String,
    onClose: @escaping () -> Void,
    useGlassCloseButton: Bool = false,
    useSimpleCloseButton: Bool = false,
    confirmButton: (() -> Void)? = nil,
    confirmButtonTitle: String? = nil,
    isConfirmButtonDisabled: Bool = false,
    @ViewBuilder content: () -> Content)
  {
    self.title = title
    self.description = description
    self.onClose = onClose
    self.useGlassCloseButton = useGlassCloseButton
    self.useSimpleCloseButton = useSimpleCloseButton
    self.confirmButton = confirmButton
    self.confirmButtonTitle = confirmButtonTitle
    self.isConfirmButtonDisabled = isConfirmButtonDisabled
    self.content = content()
  }

  // MARK: Internal

  let title: String
  let description: String
  let onClose: () -> Void
  let useGlassCloseButton: Bool
  let useSimpleCloseButton: Bool
  let content: Content
  let confirmButton: (() -> Void)?
  let confirmButtonTitle: String?
  let isConfirmButtonDisabled: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Custom header with close button
      HStack(alignment: .top) {
        // Title and description
        VStack(alignment: .leading, spacing: description.isEmpty ? 0 : 4) {
          Text(title)
            .font(Font.appHeadlineSmallEmphasised)
            .foregroundColor(.text01)
          if !description.isEmpty {
            Text(description)
              .font(.appTitleSmall)
              .foregroundColor(.text05)
          }
        }
        
        Spacer()
        
        // Close button
        Button(action: onClose) {
          if useSimpleCloseButton {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .heavy))
              .foregroundColor(Color("appText07Variant"))
              .frame(width: 44, height: 44)
          } else {
            ZStack {
              if useGlassCloseButton {
                Circle()
                  .fill(.ultraThinMaterial)
                
                Circle()
                  .stroke(
                    LinearGradient(
                      stops: [
                        .init(color: Color.white.opacity(0.4), location: 0.0),
                        .init(color: Color.white.opacity(0.1), location: 0.5),
                        .init(color: Color.white.opacity(0.4), location: 1.0)
                      ],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                  )
                
                Image(.iconClose)
                  .resizable()
                  .frame(width: 20, height: 20)
                  .foregroundColor(.text04)
              } else {
                Circle()
                  .fill(Color.text01.opacity(0.1))
                
                Image(systemName: "xmark")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(.text01)
              }
            }
            .frame(width: 36, height: 36)
          }
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 4)

      // Content
      content

      // Confirm button if provided
      if let confirmButton, let confirmButtonTitle {
        VStack(spacing: 0) {
          Divider()

          HabittoButton.largeFillPrimary(
            text: confirmButtonTitle,
            state: isConfirmButtonDisabled ? .disabled : .default,
            action: confirmButton)
            .padding(24)
        }
      }
    }
    .background(Color.surface)
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
    useSimpleCloseButton: Bool = false,
    @ViewBuilder content: () -> some View)
  {
    self.init(
      title: title,
      description: description,
      onClose: onClose,
      useGlassCloseButton: useGlassCloseButton,
      useSimpleCloseButton: useSimpleCloseButton,
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
