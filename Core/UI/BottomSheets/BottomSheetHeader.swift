import SwiftUI

struct BottomSheetHeader: View {
  let title: String
  let description: String
  let onClose: () -> Void
  var useGlassCloseButton: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Close button row
      HStack {
        Button(action: onClose) {
          if useGlassCloseButton {
            Image(.iconClose)
              .resizable()
              .frame(width: 24, height: 24)
              .foregroundColor(.text04)
              .frame(width: 48, height: 48)
              .background(.ultraThinMaterial, in: Circle())
              .overlay(
                Circle()
                  .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
              )
          } else {
            Image(.iconClose)
              .resizable()
              .frame(width: 24, height: 24)
              .foregroundColor(.text04)
              .frame(width: 48, height: 48)
          }
        }
        Spacer()
      }
      .padding(.horizontal, 4)
      .padding(.top, 24)

      // Title and description container
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(Font.appHeadlineSmallEmphasised)
          .foregroundColor(.text01)
        Text(description)
          .font(.appTitleSmall)
          .foregroundColor(.text05)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 4)
    }
  }
}

#Preview {
  BottomSheetHeader(
    title: "Select Icon",
    description: "Choose an icon for your habit",
    onClose: { })
}
