import SwiftUI

// MARK: - Primitive Colors
struct ColorPrimitives {
    // Yellow
    static let yellow50 = Color(hex: "#FEF6E6")
    static let yellow100 = Color(hex: "#FCE2B0")
    static let yellow200 = Color(hex: "#FAD58A")
    static let yellow300 = Color(hex: "#F8C154")
    static let yellow400 = Color(hex: "#F7B533")
    static let yellow500 = Color(hex: "#F5A300")
    static let yellow600 = Color(hex: "#DF9400")
    static let yellow700 = Color(hex: "#AE7400")
    static let yellow800 = Color(hex: "#875A00")
    static let yellow900 = Color(hex: "#674400")
    
    // Green
    static let green50 = Color(hex: "#EBF9EE")
    static let green100 = Color(hex: "#C0EECC")
    static let green200 = Color(hex: "#A2E5B3")
    static let green300 = Color(hex: "#77D990")
    static let green400 = Color(hex: "#5DD27A")
    static let green500 = Color(hex: "#34C759")
    static let green600 = Color(hex: "#2FB551")
    static let green700 = Color(hex: "#258D3F")
    static let green800 = Color(hex: "#1D6D31")
    static let green900 = Color(hex: "#165425")
    
    // Red
    static let red50 = Color(hex: "#FCEBEE")
    static let red100 = Color(hex: "#F7C0C9")
    static let red200 = Color(hex: "#F3A2AF")
    static let red300 = Color(hex: "#EE778A")
    static let red400 = Color(hex: "#EA5D74")
    static let red500 = Color(hex: "#E53451")
    static let red600 = Color(hex: "#D02F4A")
    static let red700 = Color(hex: "#A3253A")
    static let red800 = Color(hex: "#7E1D2D")
    static let red900 = Color(hex: "#601622")
    
    // Navy
    static let navy50 = Color(hex: "#E8E9ED")
    static let navy100 = Color(hex: "#B9BCC8")
    static let navy200 = Color(hex: "#979CAD")
    static let navy300 = Color(hex: "#676E87")
    static let navy400 = Color(hex: "#495270")
    static let navy500 = Color(hex: "#1C274C")
    static let navy600 = Color(hex: "#192345")
    static let navy700 = Color(hex: "#141C36")
    static let navy800 = Color(hex: "#0F152A")
    static let navy900 = Color(hex: "#0C1020")
    
    // Pastel Blue
    static let pastelBlue50 = Color(hex: "#F4F6FF")
    static let pastelBlue100 = Color(hex: "#EDF1FF")
    static let pastelBlue300 = Color(hex: "#B3C4FF")
    static let pastelBlue400 = Color(hex: "#A4B9FF")
    static let pastelBlue500 = Color(hex: "#8DA7FF")
    static let pastelBlue600 = Color(hex: "#8098E8")
    static let pastelBlue700 = Color(hex: "#6477B5")
    static let pastelBlue800 = Color(hex: "#4E5C8C")
    static let pastelBlue900 = Color(hex: "#3B466B")
    
    // Grey
    static let grey50 = Color(hex: "#F9F9F9")
    static let grey100 = Color(hex: "#ECECEF")
    static let grey200 = Color(hex: "#E3E3E7")
    static let grey300 = Color(hex: "#D7D7DC")
    static let grey400 = Color(hex: "#CFCFD5")
    static let grey500 = Color(hex: "#C3C3CB")
    static let grey600 = Color(hex: "#B1B1B9")
    static let grey700 = Color(hex: "#8A8A90")
    static let grey800 = Color(hex: "#6B6B70")
    static let grey900 = Color(hex: "#525255")
    static let greyBlack = Color(hex: "#191919")
    static let greyWhite = Color(hex: "#FFFFFF")
}

// MARK: - Semantic Color Tokens
struct ColorTokens {
    // Primary Colors
    static let primary = ColorPrimitives.navy500
    static let primaryFocus = ColorPrimitives.navy400
    static let onPrimary = ColorPrimitives.greyWhite
    static let primaryContainer = ColorPrimitives.navy50
    static let onPrimaryContainer = ColorPrimitives.navy900
    static let primaryDim = ColorPrimitives.navy300
    
    // Secondary Colors
    static let secondary = ColorPrimitives.pastelBlue300
    static let onSecondary = ColorPrimitives.greyBlack
    static let secondaryContainer = ColorPrimitives.pastelBlue100
    static let onSecondaryContainer = ColorPrimitives.pastelBlue900
    static let secondaryDim = ColorPrimitives.pastelBlue500
    
    // Surface Colors
    static let surface = ColorPrimitives.greyWhite
    static let surface2 = ColorPrimitives.grey50
    static let surfaceDim = ColorPrimitives.pastelBlue100
    static let surfaceBright = Color(hex: "#F4F6FF", alpha: 0.21) // 36% opacity
    static let surfaceBright2 = Color(hex: "#F4F6FF", alpha: 0.4) // 66% opacity
    static let surfaceContainer = ColorPrimitives.grey100
    static let hover = Color(hex: "#444752", alpha: 0.16) // 29% opacity
    
    // Text Colors
    static let text01 = ColorPrimitives.greyBlack
    static let text02 = ColorPrimitives.navy900
    static let text03 = ColorPrimitives.navy600
    static let text04 = ColorPrimitives.navy400
    static let text05 = ColorPrimitives.grey800
    static let text06 = ColorPrimitives.grey700
    
    // Outline Colors
    static let divider = ColorPrimitives.grey100
    static let outline = ColorPrimitives.grey200
    static let outline2 = ColorPrimitives.grey300
    static let outlineHighlight = ColorPrimitives.navy400
    
    // Basic Colors
    static let white = ColorPrimitives.greyWhite
    static let black = Color.black
    
    // Component Colors
    static let componentBackground = Color(hex: "#F2F2F7")
    
    // System Colors
    static let success = ColorPrimitives.green500
    static let warning = ColorPrimitives.yellow500
    static let successDim = ColorPrimitives.green700
    static let error = ColorPrimitives.red500
    static let errorBackground = ColorPrimitives.red50
    static let disabledBackground = ColorPrimitives.grey100
    static let onDisabledBackground = ColorPrimitives.grey400
}

// MARK: - Color Extensions
extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: (Double(a) / 255) * alpha
        )
    }
}

// MARK: - Convenience Extensions for Easy Access
extension Color {
    // Primary Colors
    static let primary = ColorTokens.primary
    static let primaryFocus = ColorTokens.primaryFocus
    static let onPrimary = ColorTokens.onPrimary
    static let primaryContainer = ColorTokens.primaryContainer
    static let onPrimaryContainer = ColorTokens.onPrimaryContainer
    static let primaryDim = ColorTokens.primaryDim
    
    // Secondary Colors
    static let secondary = ColorTokens.secondary
    static let onSecondary = ColorTokens.onSecondary
    static let secondaryContainer = ColorTokens.secondaryContainer
    static let onSecondaryContainer = ColorTokens.onSecondaryContainer
    static let secondaryDim = ColorTokens.secondaryDim
    
    // Surface Colors
    static let surface = ColorTokens.surface
    static let surface2 = ColorTokens.surface2
    static let surfaceDim = ColorTokens.surfaceDim
    static let surfaceBright = ColorTokens.surfaceBright
    static let surfaceBright2 = ColorTokens.surfaceBright2
    static let surfaceContainer = ColorTokens.surfaceContainer
    static let hover = ColorTokens.hover
    
    // Text Colors
    static let text01 = ColorTokens.text01
    static let text02 = ColorTokens.text02
    static let text03 = ColorTokens.text03
    static let text04 = ColorTokens.text04
    static let text05 = ColorTokens.text05
    static let text06 = ColorTokens.text06
    
    // Outline Colors
    static let divider = ColorTokens.divider
    static let outline = ColorTokens.outline
    static let outline2 = ColorTokens.outline2
    static let outlineHighlight = ColorTokens.outlineHighlight
    
    // System Colors
    static let success = ColorTokens.success
    static let warning = ColorTokens.warning
    static let successDim = ColorTokens.successDim
    static let error = ColorTokens.error
    static let errorBackground = ColorTokens.errorBackground
    static let disabledBackground = ColorTokens.disabledBackground
    static let onDisabledBackground = ColorTokens.onDisabledBackground
    
    // Component Colors
    static let componentBackground = ColorTokens.componentBackground
}

// MARK: - ShapeStyle Extension for SwiftUI Modifiers
extension ShapeStyle where Self == Color {
    // Primary Colors
    static var primary: Color { ColorTokens.primary }
    static var primaryFocus: Color { ColorTokens.primaryFocus }
    static var onPrimary: Color { ColorTokens.onPrimary }
    static var primaryContainer: Color { ColorTokens.primaryContainer }
    static var onPrimaryContainer: Color { ColorTokens.onPrimaryContainer }
    static var primaryDim: Color { ColorTokens.primaryDim }
    
    // Secondary Colors
    static var secondary: Color { ColorTokens.secondary }
    static var onSecondary: Color { ColorTokens.onSecondary }
    static var secondaryContainer: Color { ColorTokens.secondaryContainer }
    static var onSecondaryContainer: Color { ColorTokens.onSecondaryContainer }
    static var secondaryDim: Color { ColorTokens.secondaryDim }
    
    // Surface Colors
    static var surface: Color { ColorTokens.surface }
    static var surface2: Color { ColorTokens.surface2 }
    static var surfaceDim: Color { ColorTokens.surfaceDim }
    static var surfaceBright: Color { ColorTokens.surfaceBright }
    static var surfaceBright2: Color { ColorTokens.surfaceBright2 }
    static var surfaceContainer: Color { ColorTokens.surfaceContainer }
    static var hover: Color { ColorTokens.hover }
    
    // Text Colors
    static var text01: Color { ColorTokens.text01 }
    static var text02: Color { ColorTokens.text02 }
    static var text03: Color { ColorTokens.text03 }
    static var text04: Color { ColorTokens.text04 }
    static var text05: Color { ColorTokens.text05 }
    static var text06: Color { ColorTokens.text06 }
    
    // Outline Colors
    static var divider: Color { ColorTokens.divider }
    static var outline: Color { ColorTokens.outline }
    static var outline2: Color { ColorTokens.outline2 }
    static var outlineHighlight: Color { ColorTokens.outlineHighlight }
    
    // System Colors
    static var success: Color { ColorTokens.success }
    static var warning: Color { ColorTokens.warning }
    static var successDim: Color { ColorTokens.successDim }
    static var error: Color { ColorTokens.error }
    static var errorBackground: Color { ColorTokens.errorBackground }
    static var disabledBackground: Color { ColorTokens.disabledBackground }
    static var onDisabledBackground: Color { ColorTokens.onDisabledBackground }
    
    // Component Colors
    static var componentBackground: Color { ColorTokens.componentBackground }
}

// MARK: - Usage Examples
/*
 
 // Using semantic tokens (recommended)
 Text("Hello World")
     .foregroundColor(.text01)
     .background(.surface)
 
 Button("Continue") {
     // action
 }
 .background(.primary)
 .foregroundColor(.onPrimary)
 
 // Using primitive colors (when needed)
 Circle()
     .fill(.navy500)
     .frame(width: 20, height: 20)
 
 // Easy to update colors globally by changing the token definitions
 // For example, to change primary color from navy to green:
 // Just update ColorTokens.primary = ColorPrimitives.green500
 
 */ 