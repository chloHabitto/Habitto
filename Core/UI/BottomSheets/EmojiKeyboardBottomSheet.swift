import SwiftUI

// MARK: - Emoji Keyboard Bottom Sheet

struct EmojiKeyboardBottomSheet: View {
  // MARK: Internal

  @Binding var selectedEmoji: String

  let onClose: () -> Void
  let onSave: (String) -> Void

  var body: some View {
    BaseBottomSheet(
      title: "Choose Icon",
      description: "Select an emoji for your habit",
      onClose: onClose,
      confirmButton: {
        onSave(selectedEmoji)
      },
      confirmButtonTitle: "Save")
    {
      VStack(spacing: 16) {
        // Current selection preview
        HStack(spacing: 12) {
          Text(selectedEmoji.isEmpty ? "🙂" : selectedEmoji)
            .font(.system(size: 32))
            .frame(width: 48, height: 48)
            .background(Color.surface2)
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(.outline3, lineWidth: 1)
            )

          VStack(alignment: .leading, spacing: 4) {
            Text("Selected emoji")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
            Text(selectedEmoji.isEmpty ? "None" : selectedEmoji)
              .font(.appHeadlineSmall)
          }

          Spacer()
        }

        Divider()
          .background(.outline3)

        // Custom emoji keyboard (search + categories + grid)
        EmojiKeyboardView { emoji in
          selectedEmoji = emoji
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
  }

  // MARK: Private

  // No focus management or timers needed with the custom grid
}

// MARK: - Preview

#Preview {
  @Previewable @State var selectedEmoji = "🏃‍♂️"

  return VStack {
    Text("Selected: \(selectedEmoji)")
      .font(.title)

    Button("Open Emoji Picker") {
      // This would be handled by the parent view
    }
  }
  .sheet(isPresented: .constant(true)) {
    EmojiKeyboardBottomSheet(
      selectedEmoji: $selectedEmoji,
      onClose: { },
      onSave: { _ in })
  }
}
