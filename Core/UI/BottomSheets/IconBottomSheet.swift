import SwiftUI

struct IconBottomSheet: View {
  @Binding var selectedIcon: String

  let onClose: () -> Void

  var body: some View {
    BaseBottomSheet(
      title: "Select Icon",
      description: "Choose an icon for your habit",
      onClose: onClose)
    {
      EmojiKeyboardView { emoji in
        selectedIcon = emoji
        onClose()
      }
    }
    .background(.surface2)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

#Preview {
  IconBottomSheet(
    selectedIcon: .constant("🏃‍♂️"),
    onClose: { })
}
