import SwiftUI

// MARK: - Form Input Components

enum FormInputComponents {
  // MARK: - Custom Text Field

  struct CustomTextField: View {
    // MARK: Lifecycle

    init(
      placeholder: String,
      text: Binding<String>,
      font: Font = .appBodyLarge,
      textColor: Color = .text01,
      backgroundColor: Color = .surface,
      borderColor: Color = .outline3,
      cornerRadius: CGFloat = 12,
      lineWidth: CGFloat = 1.5,
      minHeight: CGFloat = 48,
      horizontalPadding: CGFloat = 16,
      submitLabel: SubmitLabel = .done,
      externalFocus: FocusState<Bool>.Binding? = nil)
    {
      self.placeholder = placeholder
      self._text = text
      self.font = font
      self.textColor = textColor
      self.backgroundColor = backgroundColor
      self.borderColor = borderColor
      self.cornerRadius = cornerRadius
      self.lineWidth = lineWidth
      self.minHeight = minHeight
      self.horizontalPadding = horizontalPadding
      self.submitLabel = submitLabel
      self.externalFocusBinding = externalFocus
    }

    // MARK: Internal

    @Binding var text: String
    @FocusState var isFocused: Bool

    let placeholder: String
    let font: Font
    let textColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let minHeight: CGFloat
    let horizontalPadding: CGFloat
    let submitLabel: SubmitLabel

    /// Optional external focus state binding
    var externalFocusBinding: FocusState<Bool>.Binding?

    var body: some View {
      TextField(placeholder, text: $text)
        .font(font)
        .foregroundColor(textColor)
        .textFieldStyle(PlainTextFieldStyle())
        .submitLabel(submitLabel)
        .focused($isFocused)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .padding(.horizontal, horizontalPadding)
        .background(backgroundColor)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(borderColor, lineWidth: lineWidth))
        .cornerRadius(cornerRadius)
        .onTapGesture {
          print("⏱️ DEBUG: TextField container tapped at \(Date())")
          isFocused = true
        }
        .onChange(of: isFocused) { oldValue, newValue in
          print("⏱️ DEBUG: TextField focus changed from \(oldValue) to \(newValue) at \(Date())")
          // Sync internal focus state with external focus state
          if let externalBinding = externalFocusBinding {
            externalBinding.wrappedValue = newValue
          }
        }
    }
  }

  // MARK: - Selection Row

  struct SelectionRow: View {
    // MARK: Lifecycle

    init(
      title: String,
      value: String,
      action: @escaping () -> Void,
      showChevron: Bool = true,
      titleFont: Font = .appBodyLarge,
      valueFont: Font = .appBodyMedium,
      titleColor: Color = .text01,
      valueColor: Color = .text02)
    {
      self.title = title
      self.value = value
      self.action = action
      self.showChevron = showChevron
      self.titleFont = titleFont
      self.valueFont = valueFont
      self.titleColor = titleColor
      self.valueColor = valueColor
    }

    // MARK: Internal

    let title: String
    let value: String
    let action: () -> Void
    let showChevron: Bool
    let titleFont: Font
    let valueFont: Font
    let titleColor: Color
    let valueColor: Color

    var body: some View {
      Button(action: action) {
        HStack(spacing: 12) {
          Text(title)
            .font(titleFont)
            .foregroundColor(titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(value)
            .font(valueFont)
            .foregroundColor(valueColor)

          if showChevron {
            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
        .cornerRadius(12)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  // MARK: - Selection Row with Visual Elements

  struct SelectionRowWithVisual: View {
    // MARK: Lifecycle

    init(
      title: String,
      icon: String? = nil,
      color: Color = .primary,
      value: String,
      action: @escaping () -> Void,
      showChevron: Bool = true,
      iconSize: CGFloat = 24)
    {
      self.title = title
      self.icon = icon
      self.color = color
      self.value = value
      self.action = action
      self.showChevron = showChevron
      self.iconSize = iconSize
    }

    // MARK: Internal

    let title: String
    let icon: String?
    let color: Color
    let value: String
    let action: () -> Void
    let showChevron: Bool
    let iconSize: CGFloat

    var body: some View {
      Button(action: action) {
        HStack(spacing: 12) {
          // Only show icon on the left if it's not an icon selection row or if no icon is selected
          if let icon, icon != "None", title != "Icon" {
            Image(systemName: icon)
              .font(.system(size: iconSize))
              .foregroundColor(color)
              .frame(width: iconSize, height: iconSize)
          }

          Text(title)
            .font(.appTitleMedium)
            .foregroundColor(.text01)
            .frame(maxWidth: .infinity, alignment: .leading)

          // Show color preview rectangle for color selection, icon preview for icon selection,
          // otherwise show text value
          if icon == nil, title == "Colour" {
            HStack(spacing: 8) {
              RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(.outline3, lineWidth: 1))
              Text(value)
                .font(.appBodyMedium)
                .foregroundColor(.text02)
            }
          } else if title == "Icon", icon != nil, icon != "None" {
            HStack(spacing: 8) {
              ZStack {
                RoundedRectangle(cornerRadius: 8)
                  .fill(color.opacity(0.15))
                  .frame(width: 30, height: 30)

                if icon!.hasPrefix("Icon-") {
                  // Asset icon
                  Image(icon!)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(color)
                } else {
                  // Emoji or system icon
                  Text(icon!)
                    .font(.system(size: 14))
                }
              }

              Text(value)
                .font(.appBodyMedium)
                .foregroundColor(.text02)
            }
          } else {
            Text(value)
              .font(.appBodyMedium)
              .foregroundColor(.text02)
          }

          if showChevron {
            Image(systemName: "chevron.right")
              .font(.appLabelSmall)
              .foregroundColor(.text03)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
        .cornerRadius(12)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  // MARK: - Habit Type Button

  struct HabitTypeButton: View {
    // MARK: Lifecycle

    init(
      title: String,
      isSelected: Bool,
      action: @escaping () -> Void,
      primaryColor: Color = .primary,
      secondaryColor: Color = .surface,
      selectedTextColor: Color = .onPrimary,
      unselectedTextColor: Color = .text01)
    {
      self.title = title
      self.isSelected = isSelected
      self.action = action
      self.primaryColor = primaryColor
      self.secondaryColor = secondaryColor
      self.selectedTextColor = selectedTextColor
      self.unselectedTextColor = unselectedTextColor
    }

    // MARK: Internal

    let title: String
    let isSelected: Bool
    let action: () -> Void
    let primaryColor: Color
    let secondaryColor: Color
    let selectedTextColor: Color
    let unselectedTextColor: Color

    var body: some View {
      Button(action: action) {
        HStack(spacing: 8) {
          if isSelected {
            Image(systemName: "checkmark")
              .font(.appLabelSmallEmphasised)
              .foregroundColor(selectedTextColor)
          }

          Text(title)
            .font(.appBodyLarge)
            .foregroundColor(isSelected ? selectedTextColor : unselectedTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? primaryColor : secondaryColor)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? primaryColor : .outline3, lineWidth: 1.5))
        .cornerRadius(12)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  // MARK: - Form Section Header

  struct FormSectionHeader: View {
    // MARK: Lifecycle

    init(
      title: String,
      subtitle: String? = nil,
      titleFont: Font = .appTitleMedium,
      subtitleFont: Font = .appBodySmall,
      titleColor: Color = .text01,
      subtitleColor: Color = .text02,
      spacing: CGFloat = 12)
    {
      self.title = title
      self.subtitle = subtitle
      self.titleFont = titleFont
      self.subtitleFont = subtitleFont
      self.titleColor = titleColor
      self.subtitleColor = subtitleColor
      self.spacing = spacing
    }

    // MARK: Internal

    let title: String
    let subtitle: String?
    let titleFont: Font
    let subtitleFont: Font
    let titleColor: Color
    let subtitleColor: Color
    let spacing: CGFloat

    var body: some View {
      VStack(alignment: .leading, spacing: spacing) {
        Text(title)
          .font(titleFont)
          .foregroundColor(titleColor)

        if let subtitle {
          Text(subtitle)
            .font(subtitleFont)
            .foregroundColor(subtitleColor)
            .multilineTextAlignment(.leading)
        }
      }
    }
  }

  // MARK: - Form Container

  struct FormContainer<Content: View>: View {
    // MARK: Lifecycle

    init(
      backgroundColor: Color = .surfaceDim,
      cornerRadius: CGFloat = 16,
      padding: EdgeInsets = EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20),
      @ViewBuilder content: () -> Content)
    {
      self.backgroundColor = backgroundColor
      self.cornerRadius = cornerRadius
      self.padding = padding
      self.content = content()
    }

    // MARK: Internal

    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets

    var body: some View {
      content
        .padding(padding)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
    }
  }
}
