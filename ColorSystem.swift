import SwiftUI

// MARK: - Primitive Colors
struct ColorPrimitives {
    // Yellow
    static let yellow50 = Color("yellow50")
    static let yellow100 = Color("yellow100")
    static let yellow200 = Color("yellow200")
    static let yellow300 = Color("yellow300")
    static let yellow400 = Color("yellow400")
    static let yellow500 = Color("yellow500")
    static let yellow600 = Color("yellow600")
    static let yellow700 = Color("yellow700")
    static let yellow800 = Color("yellow800")
    static let yellow900 = Color("yellow900")
    
    // Green
    static let green50 = Color("green50")
    static let green100 = Color("green100")
    static let green200 = Color("green200")
    static let green300 = Color("green300")
    static let green400 = Color("green400")
    static let green500 = Color("green500")
    static let green600 = Color("green600")
    static let green700 = Color("green700")
    static let green800 = Color("green800")
    static let green900 = Color("green900")
    
    // Red
    static let red50 = Color("red50")
    static let red100 = Color("red100")
    static let red200 = Color("red200")
    static let red300 = Color("red300")
    static let red400 = Color("red400")
    static let red500 = Color("red500")
    static let red600 = Color("red600")
    static let red700 = Color("red700")
    static let red800 = Color("red800")
    static let red900 = Color("red900")
    
    // Navy
    static let navy50 = Color("navy50")
    static let navy100 = Color("navy100")
    static let navy200 = Color("navy200")
    static let navy300 = Color("navy300")
    static let navy400 = Color("navy400")
    static let navy500 = Color("navy500")
    static let navy600 = Color("navy600")
    static let navy700 = Color("navy700")
    static let navy800 = Color("navy800")
    static let navy900 = Color("navy900")
    
    // Pastel Blue
    static let pastelBlue50 = Color("pastelBlue50")
    static let pastelBlue100 = Color("pastelBlue100")
    static let pastelBlue300 = Color("pastelBlue300")
    static let pastelBlue400 = Color("pastelBlue400")
    static let pastelBlue500 = Color("pastelBlue500")
    static let pastelBlue600 = Color("pastelBlue600")
    static let pastelBlue700 = Color("pastelBlue700")
    static let pastelBlue800 = Color("pastelBlue800")
    static let pastelBlue900 = Color("pastelBlue900")
    
    // Grey
    static let grey50 = Color("grey50")
    static let grey100 = Color("grey100")
    static let grey200 = Color("grey200")
    static let grey300 = Color("grey300")
    static let grey400 = Color("grey400")
    static let grey500 = Color("grey500")
    static let grey600 = Color("grey600")
    static let grey700 = Color("grey700")
    static let grey800 = Color("grey800")
    static let grey900 = Color("grey900")
    static let greyBlack = Color("greyBlack")
    static let greyWhite = Color("greyWhite")
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
    static let primaryContainerFocus = ColorPrimitives.navy200
    
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



// MARK: - Convenience Extensions for Easy Access
extension Color {
    // Primary Colors
    static let primary = ColorTokens.primary
    static let primaryFocus = ColorTokens.primaryFocus
    static let onPrimary = ColorTokens.onPrimary
    static let primaryContainer = ColorTokens.primaryContainer
    static let onPrimaryContainer = ColorTokens.onPrimaryContainer
    static let primaryDim = ColorTokens.primaryDim
    static let primaryContainerFocus = ColorTokens.primaryContainerFocus
    
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
    static var primaryContainerFocus: Color { ColorTokens.primaryContainerFocus }
    
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