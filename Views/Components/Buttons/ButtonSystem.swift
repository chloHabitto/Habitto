import SwiftUI

// MARK: - Button Content Types
enum ButtonContent {
    case text(String)
    case icon(String) // Icon name
    case textAndIcon(String, String) // Text and icon name
}

// MARK: - Main Button Component
struct HabittoButton: View {
    let size: ButtonSize
    let style: ButtonStyle
    let content: ButtonContent
    let state: ButtonState
    let hugging: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        size: ButtonSize = .large,
        style: ButtonStyle = .fillPrimary,
        content: ButtonContent,
        state: ButtonState = .default,
        hugging: Bool = false,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.style = style
        self.content = content
        self.state = state
        self.hugging = hugging
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if state != .disabled && state != .loading {
                action()
            }
        }) {
            contentView
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .disabled || state == .loading)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch content {
        case .text(let text):
            textOnlyView(text)
        case .icon(let iconName):
            iconOnlyView(iconName)
        case .textAndIcon(let text, let iconName):
            textAndIconView(text, iconName)
        }
    }
    
    @ViewBuilder
    private func textOnlyView(_ text: String) -> some View {
        Text(text)
            .font(size.font)
            .foregroundColor(style.textColor(for: state))
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: hugging ? nil : .infinity)
            .frame(height: size.height)
            .background(style.backgroundColor(for: state))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    @ViewBuilder
    private func iconOnlyView(_ iconName: String) -> some View {
        Image(iconName)
            .resizable()
            .frame(width: size.iconSize, height: size.iconSize)
            .foregroundColor(style.iconColor(for: state))
            .frame(width: size.containerSize, height: size.containerSize)
            .background(style.backgroundColor(for: state))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    @ViewBuilder
    private func textAndIconView(_ text: String, _ iconName: String) -> some View {
        HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .frame(width: size.iconSize, height: size.iconSize)
                .foregroundColor(style.iconColor(for: state))
            
            Text(text)
                .font(size.font)
                .foregroundColor(style.textColor(for: state))
        }
        .padding(.horizontal, size.horizontalPadding)
        .frame(maxWidth: hugging ? nil : .infinity)
        .frame(height: size.height)
        .background(style.backgroundColor(for: state))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Convenience Initializers
extension HabittoButton {
    // Large Fill Primary Button
    static func largeFillPrimary(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .large,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Large Fill Neutral Button
    static func largeFillNeutral(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .large,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Large Fill Neutral Icon Only Button
    static func largeFillNeutralIcon(
        iconName: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .large,
            style: .fillNeutral,
            content: .icon(iconName),
            state: state,
            action: action
        )
    }
    
    // Medium Fill Primary Button
    static func mediumFillPrimary(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .medium,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Medium Fill Neutral Button
    static func mediumFillNeutral(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .medium,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Medium Fill Neutral Icon Only Button
    static func mediumFillNeutralIcon(
        iconName: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .medium,
            style: .fillNeutral,
            content: .icon(iconName),
            state: state,
            action: action
        )
    }
    
    // Small Fill Primary Button
    static func smallFillPrimary(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .small,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Small Fill Neutral Button
    static func smallFillNeutral(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .small,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            action: action
        )
    }
    
    // Small Fill Neutral Icon Only Button
    static func smallFillNeutralIcon(
        iconName: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .small,
            style: .fillNeutral,
            content: .icon(iconName),
            state: state,
            action: action
        )
    }
    
    // MARK: - Hugging Button Variants
    
    // Large Fill Primary Hugging Button
    static func largeFillPrimaryHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .large,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
    
    // Large Fill Neutral Hugging Button
    static func largeFillNeutralHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .large,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
    
    // Medium Fill Primary Hugging Button
    static func mediumFillPrimaryHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .medium,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
    
    // Medium Fill Neutral Hugging Button
    static func mediumFillNeutralHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .medium,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
    
    // Small Fill Primary Hugging Button
    static func smallFillPrimaryHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .small,
            style: .fillPrimary,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
    
    // Small Fill Neutral Hugging Button
    static func smallFillNeutralHugging(
        text: String,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) -> HabittoButton {
        HabittoButton(
            size: .small,
            style: .fillNeutral,
            content: .text(text),
            state: state,
            hugging: true,
            action: action
        )
    }
}

// MARK: - Preview
struct HabittoButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Large Fill Primary Buttons
            HabittoButton.largeFillPrimary(text: "Large Primary") {
                print("Large primary button tapped")
            }
            
            HabittoButton.largeFillPrimary(text: "Disabled Primary", state: .disabled) {
                print("Disabled button tapped")
            }
            
            // Medium Fill Primary Buttons
            HabittoButton.mediumFillPrimary(text: "Medium Primary") {
                print("Medium primary button tapped")
            }
            
            HabittoButton.mediumFillPrimary(text: "Disabled Medium", state: .disabled) {
                print("Disabled medium button tapped")
            }
            
            // Small Fill Primary Buttons
            HabittoButton.smallFillPrimary(text: "Small Primary") {
                print("Small primary button tapped")
            }
            
            HabittoButton.smallFillPrimary(text: "Disabled Small", state: .disabled) {
                print("Disabled small button tapped")
            }
            
            // Large Fill Neutral Buttons
            HabittoButton.largeFillNeutral(text: "Large Neutral") {
                print("Large neutral button tapped")
            }
            
            // Medium Fill Neutral Buttons
            HabittoButton.mediumFillNeutral(text: "Medium Neutral") {
                print("Medium neutral button tapped")
            }
            
            // Small Fill Neutral Buttons
            HabittoButton.smallFillNeutral(text: "Small Neutral") {
                print("Small neutral button tapped")
            }
            
            // Icon Only Buttons
            HStack(spacing: 12) {
                HabittoButton.largeFillNeutralIcon(iconName: "Icon-plus") {
                    print("Large icon button tapped")
                }
                
                HabittoButton.mediumFillNeutralIcon(iconName: "Icon-plus") {
                    print("Medium icon button tapped")
                }
                
                HabittoButton.smallFillNeutralIcon(iconName: "Icon-plus") {
                    print("Small icon button tapped")
                }
            }
            
            // Hugging Button Variants
            VStack(spacing: 16) {
                Text("Hugging Buttons").font(.headline)
                
                HabittoButton.smallFillPrimaryHugging(text: "Small Hugging") {
                    print("Small hugging button tapped")
                }
                
                HabittoButton.mediumFillPrimaryHugging(text: "Medium Hugging") {
                    print("Medium hugging button tapped")
                }
                
                HabittoButton.largeFillPrimaryHugging(text: "Large Hugging") {
                    print("Large hugging button tapped")
                }
                
                HStack(spacing: 12) {
                    HabittoButton.smallFillPrimaryHugging(text: "Save") {
                        print("Save button tapped")
                    }
                    
                    HabittoButton.smallFillNeutralHugging(text: "Cancel") {
                        print("Cancel button tapped")
                    }
                }
            }
        }
        .padding()
        .background(.surface2)
    }
} 