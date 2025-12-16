import SwiftUI
import UIKit

// MARK: - ColorTokens
// Semantic color tokens that automatically adapt to light/dark mode via asset catalog
// Asset names are prefixed with "app" to avoid conflicts with SwiftUI built-in colors

enum ColorTokens {
  // MARK: - Primary Colors
  static let primary = Color("appPrimary")
  static let primaryFocus = Color("appPrimaryFocus")
  static let onPrimary = Color("appOnPrimary")
  static let primaryContainer = Color("appPrimaryContainer")
  static let onPrimaryContainer = Color("appOnPrimaryContainer")
  static let primaryDim = Color("appPrimaryDim")
  static let primaryContainerFocus = Color("appPrimaryContainerFocus")

  // MARK: - Secondary Colors
  static let secondary = Color("appSecondary")
  static let onSecondary = Color("appOnSecondary")
  static let secondaryContainer = Color("appSecondaryContainer")
  static let onSecondaryContainer = Color("appOnSecondaryContainer")
  static let secondaryDim = Color("appSecondaryDim")

  // MARK: - Surface Colors
  static let surface = Color("appSurface")
  static let surface2 = Color("appSurface2")
  static let surface3 = Color("appSurface3")
  static let surfaceDim = Color("appSurfaceDim")
  static let surfaceBright = Color("appSurfaceBright")
  static let surfaceBright2 = Color("appSurfaceBright2")
  static let surfaceContainer = Color("appSurfaceContainer")
  static let surfaceTabBar = Color("appSurfaceTabBar")
  static let hover = Color("appHover")

  // MARK: - Text Colors
  static let text01 = Color("appText01")
  static let text02 = Color("appText02")
  static let text03 = Color("appText03")
  static let text04 = Color("appText04")
  static let text05 = Color("appText05")
  static let text06 = Color("appText06")
  static let text07 = Color("appText07")

  // MARK: - Outline Colors
  static let outline1 = Color("appOutline1")
  static let outline2 = Color("appOutline2")
  static let outline3 = Color("appOutline3")
  static let outline4 = Color("appOutline4")
  static let outlineHighlight = Color("appOutlineHighlight")

  // MARK: - System Colors
  static let success = Color("appSuccess")
  static let successDim = Color("appSuccessDim")
  static let warning = Color("appWarning")
  static let error = Color("appError")
  static let errorText = Color("appErrorText")
  static let errorBackground = Color("appErrorBackground")

  // MARK: - Component Colors
  static let disabledBackground = Color("appDisabledBackground")
  static let onDisabledBackground = Color("appOnDisabledBackground")
  static let componentBackground = Color("appComponentBackground")
  static let sheetBackground = Color("appSheetBackground")
  static let sheetBackground02 = Color("appSheetBackground02")
  static let bottomNavIconActive = Color("appBottomeNavIcon_Active")
  static let bottomNavIconInactive = Color("appBottomeNavIcon_Inactive")

  // MARK: - Basic Colors
  static let white = Color.white
  static let black = Color.black
}

// MARK: - Color Extension for Easy Access

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
  static let surface3 = ColorTokens.surface3
  static let surfaceDim = ColorTokens.surfaceDim
  static let surfaceBright = ColorTokens.surfaceBright
  static let surfaceBright2 = ColorTokens.surfaceBright2
  static let surfaceContainer = ColorTokens.surfaceContainer
  static let surfaceTabBar = ColorTokens.surfaceTabBar
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
  static let successDim = ColorTokens.successDim
  static let warning = ColorTokens.warning
  static let error = ColorTokens.error
  static let errorText = ColorTokens.errorText
  static let errorBackground = ColorTokens.errorBackground

  // Component Colors
  static let disabledBackground = ColorTokens.disabledBackground
  static let onDisabledBackground = ColorTokens.onDisabledBackground
  static let componentBackground = ColorTokens.componentBackground
  static let sheetBackground = ColorTokens.sheetBackground
  static let sheetBackground02 = ColorTokens.sheetBackground02
  static let bottomNavIconActive = ColorTokens.bottomNavIconActive
  static let bottomNavIconInactive = ColorTokens.bottomNavIconInactive
}

// MARK: - ShapeStyle Extension for SwiftUI Modifiers

extension ShapeStyle where Self == Color {
  static var primary: Color { ColorTokens.primary }
  static var primaryFocus: Color { ColorTokens.primaryFocus }
  static var onPrimary: Color { ColorTokens.onPrimary }
  static var primaryContainer: Color { ColorTokens.primaryContainer }
  static var onPrimaryContainer: Color { ColorTokens.onPrimaryContainer }
  static var primaryDim: Color { ColorTokens.primaryDim }
  static var primaryContainerFocus: Color { ColorTokens.primaryContainerFocus }

  static var secondary: Color { ColorTokens.secondary }
  static var onSecondary: Color { ColorTokens.onSecondary }
  static var secondaryContainer: Color { ColorTokens.secondaryContainer }
  static var onSecondaryContainer: Color { ColorTokens.onSecondaryContainer }
  static var secondaryDim: Color { ColorTokens.secondaryDim }

  static var surface: Color { ColorTokens.surface }
  static var surface2: Color { ColorTokens.surface2 }
  static var surface3: Color { ColorTokens.surface3 }
  static var surfaceDim: Color { ColorTokens.surfaceDim }
  static var surfaceBright: Color { ColorTokens.surfaceBright }
  static var surfaceBright2: Color { ColorTokens.surfaceBright2 }
  static var surfaceContainer: Color { ColorTokens.surfaceContainer }
  static var surfaceTabBar: Color { ColorTokens.surfaceTabBar }
  static var hover: Color { ColorTokens.hover }

  static var text01: Color { ColorTokens.text01 }
  static var text02: Color { ColorTokens.text02 }
  static var text03: Color { ColorTokens.text03 }
  static var text04: Color { ColorTokens.text04 }
  static var text05: Color { ColorTokens.text05 }
  static var text06: Color { ColorTokens.text06 }
  static var text07: Color { ColorTokens.text07 }

  static var outline1: Color { ColorTokens.outline1 }
  static var outline2: Color { ColorTokens.outline2 }
  static var outline3: Color { ColorTokens.outline3 }
  static var outline4: Color { ColorTokens.outline4 }
  static var outlineHighlight: Color { ColorTokens.outlineHighlight }

  static var success: Color { ColorTokens.success }
  static var successDim: Color { ColorTokens.successDim }
  static var warning: Color { ColorTokens.warning }
  static var error: Color { ColorTokens.error }
  static var errorText: Color { ColorTokens.errorText }
  static var errorBackground: Color { ColorTokens.errorBackground }

  static var disabledBackground: Color { ColorTokens.disabledBackground }
  static var onDisabledBackground: Color { ColorTokens.onDisabledBackground }
  static var componentBackground: Color { ColorTokens.componentBackground }
  static var sheetBackground: Color { ColorTokens.sheetBackground }
  static var sheetBackground02: Color { ColorTokens.sheetBackground02 }
  static var bottomNavIconActive: Color { ColorTokens.bottomNavIconActive }
  static var bottomNavIconInactive: Color { ColorTokens.bottomNavIconInactive }
}

// MARK: - Color Hex Conversion

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3:
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
  
  /// Convert Color to hex string (e.g., "#FF5733")
  func toHex() -> String {
    let uiColor = UIColor(self)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let r = Int(red * 255)
    let g = Int(green * 255)
    let b = Int(blue * 255)
    
    return String(format: "#%02X%02X%02X", r, g, b)
  }
  
  /// Create Color from hex string (e.g., "#FF5733" or "FF5733")
  static func fromHex(_ hex: String) -> Color {
    Color(hex: hex)
  }
}

// MARK: - CodableColor

/// A wrapper around SwiftUI Color that conforms to Codable
/// Used by Habit model to persist color selections
struct CodableColor: Codable, Equatable {
  // MARK: Lifecycle

  init(_ color: Color) {
    // Convert Color to RGBA components for storage
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    self.red = Double(red)
    self.green = Double(green)
    self.blue = Double(blue)
    self.alpha = Double(alpha)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.red = try container.decode(Double.self, forKey: .red)
    self.green = try container.decode(Double.self, forKey: .green)
    self.blue = try container.decode(Double.self, forKey: .blue)
    self.alpha = try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1.0
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case red, green, blue, alpha
  }

  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  var color: Color {
    Color(red: red, green: green, blue: blue, opacity: alpha)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(red, forKey: .red)
    try container.encode(green, forKey: .green)
    try container.encode(blue, forKey: .blue)
    try container.encode(alpha, forKey: .alpha)
  }

  static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
    lhs.red == rhs.red &&
      lhs.green == rhs.green &&
      lhs.blue == rhs.blue &&
      lhs.alpha == rhs.alpha
  }
}
