import SwiftUI

// MARK: - Button Sizes
enum ButtonSize {
    case large
    case medium
    case small
    
    var padding: CGFloat {
        switch self {
        case .large:
            return 16
        case .medium:
            return 12 // TODO: Update in the future
        case .small:
            return 8 // TODO: Update in the future
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .large:
            return 24
        case .medium:
            return 20 // TODO: Update in the future
        case .small:
            return 16 // TODO: Update in the future
        }
    }
    
    var containerSize: CGFloat {
        switch self {
        case .large:
            return 48
        case .medium:
            return 40 // TODO: Update in the future
        case .small:
            return 32 // TODO: Update in the future
        }
    }
}

// MARK: - Button Styles
enum ButtonStyle {
    case fillPrimary
    case fillSecondary
    case outline
    case tertiary
    case fillNeutral
    
    func backgroundColor(for state: ButtonState) -> Color {
        switch self {
        case .fillPrimary:
            switch state {
            case .default, .hover:
                return .primary
            case .disabled:
                return .disabledBackground
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .fillSecondary:
            switch state {
            case .default, .hover:
                return .secondary // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .secondary // TODO: Update in the future
            }
        case .outline:
            switch state {
            case .default, .hover:
                return .clear // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .clear // TODO: Update in the future
            }
        case .tertiary:
            switch state {
            case .default, .hover:
                return .clear // TODO: Update in the future
            case .disabled:
                return .disabledBackground
            case .loading:
                return .clear // TODO: Update in the future
            }
        case .fillNeutral:
            switch state {
            case .default:
                return .primaryContainer
            case .hover:
                return .primaryContainerFocus
            case .disabled:
                return .disabledBackground
            case .loading:
                return .primaryContainer // TODO: Update in the future
            }
        }
    }
    
    func textColor(for state: ButtonState) -> Color {
        switch self {
        case .fillPrimary:
            switch state {
            case .default, .hover:
                return .onPrimary
            case .disabled:
                return .text06
            case .loading:
                return .onPrimary // TODO: Update in the future
            }
        case .fillSecondary:
            switch state {
            case .default, .hover:
                return .onSecondary // TODO: Update in the future
            case .disabled:
                return .text06
            case .loading:
                return .onSecondary // TODO: Update in the future
            }
        case .outline:
            switch state {
            case .default, .hover:
                return .primary // TODO: Update in the future
            case .disabled:
                return .text06
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .tertiary:
            switch state {
            case .default, .hover:
                return .primary // TODO: Update in the future
            case .disabled:
                return .text06
            case .loading:
                return .primary // TODO: Update in the future
            }
        case .fillNeutral:
            switch state {
            case .default, .hover:
                return .onPrimaryContainer
            case .disabled:
                return .text06
            case .loading:
                return .onPrimaryContainer // TODO: Update in the future
            }
        }
    }
    
    func iconColor(for state: ButtonState) -> Color {
        return textColor(for: state)
    }
}

// MARK: - Button States
enum ButtonState {
    case `default`
    case hover
    case disabled
    case loading
}

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
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        size: ButtonSize = .large,
        style: ButtonStyle = .fillPrimary,
        content: ButtonContent,
        state: ButtonState = .default,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.style = style
        self.content = content
        self.state = state
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
            .font(.appButtonText1) // TODO: Update font system in the future
            .foregroundColor(style.textColor(for: state))
            .padding(.horizontal, size.padding)
            .padding(.vertical, size.padding)
            .frame(maxWidth: .infinity)
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
                .font(.appButtonText1) // TODO: Update font system in the future
                .foregroundColor(style.textColor(for: state))
        }
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding)
        .frame(maxWidth: .infinity)
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
}

// MARK: - Preview
struct HabittoButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Large Fill Primary Buttons
            HabittoButton.largeFillPrimary(text: "Primary Button") {
                print("Primary button tapped")
            }
            
            HabittoButton.largeFillPrimary(text: "Disabled Primary", state: .disabled) {
                print("Disabled button tapped")
            }
            
            // Large Fill Neutral Buttons
            HabittoButton.largeFillNeutral(text: "Neutral Button") {
                print("Neutral button tapped")
            }
            
            HabittoButton.largeFillNeutral(text: "Disabled Neutral", state: .disabled) {
                print("Disabled neutral button tapped")
            }
            
            // Large Fill Neutral Icon Only
            HabittoButton.largeFillNeutralIcon(iconName: "Icon-plus") {
                print("Icon button tapped")
            }
        }
        .padding()
        .background(.surface2)
    }
} 