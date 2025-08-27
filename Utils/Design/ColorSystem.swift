import SwiftUI

// MARK: - Primitive Colors
struct ColorPrimitives {
    // Yellow
    // static let yellow50 = Color("yellow50")
    // static let yellow100 = Color("yellow100")
    // static let yellow200 = Color("yellow200")
    // static let yellow300 = Color("yellow300")
    // static let yellow400 = Color("yellow400")
    // static let yellow500 = Color("yellow500")
    // static let yellow600 = Color("yellow600")
    // static let yellow700 = Color("yellow700")
    // static let yellow800 = Color("yellow800")
    // static let yellow900 = Color("yellow900")
    
    // Green
    // static let green50 = Color("green50")
    // static let green100 = Color("green100")
    // static let green200 = Color("green200")
    // static let green300 = Color("green300")
    // static let green400 = Color("green400")
    // static let green500 = Color("green500")
    // static let green600 = Color("green600")
    // static let green700 = Color("green700")
    // static let green800 = Color("green800")
    // static let green900 = Color("green900")
    
    // Red
    // static let red50 = Color("red50")
    // static let red100 = Color("red100")
    // static let red200 = Color("red200")
    // static let red300 = Color("red300")
    // static let red400 = Color("red400")
    // static let red500 = Color("red500")
    // static let red600 = Color("red600")
    // static let red700 = Color("red700")
    // static let red800 = Color("red800")
    // static let red900 = Color("red900")
    
    // Navy
    // static let navy50 = Color("navy50")
    // static let navy100 = Color("navy100")
    // static let navy200 = Color("navy200")
    // static let navy300 = Color("navy300")
    // static let navy400 = Color("navy400")
    // static let navy500 = Color("navy500")
    // static let navy600 = Color("navy600")
    // static let navy700 = Color("navy700")
    // static let navy800 = Color("navy800")
    // static let navy900 = Color("navy900")
    
    // Pastel Blue
    // static let pastelBlue50 = Color("pastelBlue50")
    // static let pastelBlue100 = Color("pastelBlue100")
    // static let pastelBlue300 = Color("pastelBlue300")
    // static let pastelBlue400 = Color("pastelBlue400")
    // static let pastelBlue500 = Color("pastelBlue500")
    // static let pastelBlue600 = Color("pastelBlue600")
    // static let pastelBlue700 = Color("pastelBlue700")
    // static let pastelBlue800 = Color("pastelBlue800")
    // static let pastelBlue900 = Color("pastelBlue900")
    
    // Grey
    // static let grey50 = Color("grey50")
    // static let grey100 = Color("grey100")
    // static let grey200 = Color("grey200")
    // static let grey300 = Color("grey300")
    // static let grey400 = Color("grey400")
    // static let grey500 = Color("grey500")
    // static let grey600 = Color("grey600")
    // static let grey700 = Color("grey700")
    // static let grey800 = Color("grey800")
    // static let grey900 = Color("grey900")
    // static let greyBlack = Color("greyBlack")
    // static let greyWhite = Color("greyWhite")
    
    // Additional colors from asset catalog
    // static let accentColor = Color("AccentColor")
}

// MARK: - Semantic Color Tokens
struct ColorTokens {
    // Primary Colors
    static let primary = Color("navy500")
    static let primaryFocus = Color("navy400")
    static let onPrimary = Color("greyWhite")
    static let primaryContainer = Color("navy50")
    static let onPrimaryContainer = Color("navy900")
    static let primaryDim = Color("navy300")
    static let primaryContainerFocus = Color("navy200")
    
    // Secondary Colors
    static let secondary = Color("pastelBlue300")
    static let onSecondary = Color("greyBlack")
    static let secondaryContainer = Color("pastelBlue100")
    static let onSecondaryContainer = Color("pastelBlue900")
    static let secondaryDim = Color("pastelBlue500")
    
    // Surface Colors
    static let surface = Color("greyWhite")
    static let surface2 = Color("grey50")
    static let surfaceDim = Color("pastelBlue100")
    static let surfaceBright = Color("pastelBlue50").opacity(0.21) // Using asset color with opacity
    static let surfaceBright2 = Color("pastelBlue50").opacity(0.4) // Using asset color with opacity
    static let surfaceContainer = Color("grey100")
    static let hover = Color("grey800").opacity(0.16) // Using asset color with opacity
    
    // Text Colors
    static let text01 = Color("greyBlack")
    static let text02 = Color("navy900")
    static let text03 = Color("navy600")
    static let text04 = Color("navy400")
    static let text05 = Color("grey800")
    static let text06 = Color("grey700")
    static let text07 = Color("navy300")

    
    // Outline Colors
    static let outline2 = Color("grey100")
    static let outline3 = Color("grey200")
    static let outline1 = Color("grey50")
    static let outline4 = Color("grey300")
    static let outlineHighlight = Color("navy400")
    
    // Basic Colors
    static let white = Color("greyWhite")
    static let black = Color("greyBlack") // Using asset color instead of Color.black
    
    // Component Colors
    static let componentBackground = Color("grey100") // Using asset color instead of hardcoded hex
    
    // System Colors
    static let success = Color("green500")
    static let warning = Color("yellow500")
    static let successDim = Color("green700")
    static let error = Color("red500")
    static let errorText = Color("red800")
    static let errorBackground = Color("red50")
    static let disabledBackground = Color("grey100")
    static let onDisabledBackground = Color("grey400")
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
    static let text07 = ColorTokens.text07
    
    // Outline Colors
    static let outline1 = ColorTokens.outline1
    static let outline2 = ColorTokens.outline2
    static let outline3 = ColorTokens.outline3
    static let outline4 = ColorTokens.outline4
    static let outlineHighlight = ColorTokens.outlineHighlight
    
    // System Colors
    static let success = ColorTokens.success
    static let warning = ColorTokens.warning
    static let successDim = ColorTokens.successDim
    static let error = ColorTokens.error
    static let errorText = ColorTokens.errorText
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
    static var outline2: Color { ColorTokens.outline2 }
    static var outline3: Color { ColorTokens.outline3 }
    static var outline1: Color { ColorTokens.outline1 }
    static var outline4: Color { ColorTokens.outline4 }
    static var outlineHighlight: Color { ColorTokens.outlineHighlight }
    
    // System Colors
    static var success: Color { ColorTokens.success }
    static var warning: Color { ColorTokens.warning }
    static var successDim: Color { ColorTokens.successDim }
    static var error: Color { ColorTokens.error }
    static var errorText: Color { ColorTokens.errorText }
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
 // Just update ColorTokens.primary = Color("green500")
 
 */ 

// MARK: - Color Hex Conversion Methods
extension Color {
    // Performance optimization: Cache color hex values
    private static var hexCache: [Color: String] = [:]
    private static var colorCache: [String: Color] = [:]
    private static let cacheQueue = DispatchQueue(label: "color.cache.queue", attributes: .concurrent)
    
    func toHex() -> String {
        // Performance optimization: Use cached hex value if available
        let cachedHex = Self.cacheQueue.sync {
            Self.hexCache[self]
        }
        if let cachedHex = cachedHex {
            return cachedHex
        }
        
        // Safely convert to UIColor and extract components
        let hex: String
        let uic = UIColor(self)
        let cgColor = uic.cgColor
        if let components = cgColor.components,
           components.count >= 3 {
            let r = Float(components[0])
            let g = Float(components[1])
            let b = Float(components[2])
            hex = String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            hex = "000000"
        }
        
        // Cache the hex value thread-safely
        Self.cacheQueue.async(flags: .barrier) {
            Self.hexCache[self] = hex
        }
        return hex
    }
    
    func toHexWithHash() -> String {
        return "#" + toHex()
    }
    
    init(hex: String) {
        // Performance optimization: Use cached color if available
        let cachedColor = Self.cacheQueue.sync {
            Self.colorCache[hex]
        }
        if let cachedColor = cachedColor {
            self = cachedColor
            return
        }
        
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
        
        let color = Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
        
        // Cache the color thread-safely
        Self.cacheQueue.async(flags: .barrier) {
            Self.colorCache[hex] = color
        }
        self = color
    }
    
    static func fromHex(_ hex: String) -> Color {
        return Color(hex: hex)
    }
}

// MARK: - Color Codable Extension
extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        self.init(hex: hex)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toHex())
    }
} 
