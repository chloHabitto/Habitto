import SwiftUI

struct IconBottomSheet: View {
  @ObservedObject private var localizationManager = LocalizationManager.shared

  @Binding var selectedIcon: String

  let onClose: () -> Void

  var body: some View {
    BaseBottomSheet(
      title: "create.iconPicker.title".localized,
      description: "create.iconPicker.description".localized,
      onClose: onClose,
      useGlassCloseButton: true)
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
