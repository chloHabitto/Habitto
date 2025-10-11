import SwiftUI

// MARK: - ColorBottomSheet

struct ColorBottomSheet: View {
  // MARK: Lifecycle

  init(
    onClose: @escaping () -> Void,
    onColorSelected: @escaping (Color) -> Void,
    onSave: @escaping (Color) -> Void)
  {
    self.onClose = onClose
    self.onColorSelected = onColorSelected
    self.onSave = onSave
    self._selectedColor = State(initialValue: .primary) // Navy is selected by default
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
      confirmButton: {
        onSave(selectedColor)
      },
      confirmButtonTitle: "Save")
    {
      VStack(spacing: 16) {
        // First row - 4 colors
        HStack(spacing: 16) {
          ForEach(0 ..< 4, id: \.self) { index in
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

        // Second row - 4 colors
        HStack(spacing: 16) {
          ForEach(4 ..< 8, id: \.self) { index in
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
      }
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
    (Color(hex: "222222"), "Black"),
    (.primary, "Navy"),
    (Color(hex: "6096FD"), "Blue"),
    (Color(hex: "CB30E0"), "Purple"),
    (Color(hex: "FF2D55"), "Red"),
    (Color(hex: "FF7838"), "Orange"),
    (Color(hex: "34C759"), "Green"),
    (Color(hex: "21EAF1"), "Teal")
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
