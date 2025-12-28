import SwiftUI

// MARK: - ColorBottomSheet

struct ColorBottomSheet: View {
  // MARK: Lifecycle

  init(
    onClose: @escaping () -> Void,
    onColorSelected: @escaping (Color) -> Void,
    onSave: @escaping (Color) -> Void,
    initialColor: Color? = nil)
  {
    self.onClose = onClose
    self.onColorSelected = onColorSelected
    self.onSave = onSave
    // Default to pastelBlue if no initial color provided, otherwise use the provided color
    self._selectedColor = State(initialValue: initialColor ?? Color("pastelBlue"))
  }

  // MARK: Internal

  let onClose: () -> Void
  let onColorSelected: (Color) -> Void
  let onSave: (Color) -> Void

  var body: some View {
    BaseBottomSheet(
      title: "Colour",
      description: "Set a colour for your habit",
      onClose: onClose,
      useGlassCloseButton: true,
      confirmButton: {
        onSave(selectedColor)
      },
      confirmButtonTitle: "Save")
    {
      HStack(spacing: 16) {
        ForEach(colors.indices, id: \.self) { index in
          ColorButton(
            color: colors[index].color,
            name: colors[index].name,
            isSelected: selectedColor == colors[index].color)
          {
            selectedColor = colors[index].color
            onColorSelected(colors[index].color)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 32)
      Spacer()
    }
    .presentationDetents([.height(800)])
  }

  // MARK: Private

  @State private var selectedColor: Color

  private let colors: [(color: Color, name: String)] = [
    (Color("pastelYellow"), "Yellow"),
    (Color("pastelBlue"), "Blue"),
    (Color("pastelPurple"), "Purple")
  ]
}

// MARK: - ColorButton

struct ColorButton: View {
  let color: Color
  let name: String
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 8) {
        // Color container
        RoundedRectangle(cornerRadius: 24)
          .fill(color)
          .frame(width: 36, height: 36)

        // Color name
        Text(name)
          .font(.appBodyLarge)
          .foregroundColor(.text04)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? .primary : .clear, lineWidth: 1.5))
  }
}

#Preview {
  ColorBottomSheet(
    onClose: { },
    onColorSelected: { _ in },
    onSave: { _ in })
}
