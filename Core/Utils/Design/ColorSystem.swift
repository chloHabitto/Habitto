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
  static let secondaryContainer03 = Color("appSecondaryContainer03")
  static let onSecondaryContainer = Color("appOnSecondaryContainer")
  static let secondaryDim = Color("appSecondaryDim")

  // MARK: - Surface Colors
  static let surface = Color("appSurface")
  static let surface1 = Color("appSurface01")
  static let surface01 = Color("appSurface01")
  static let surface2 = Color("appSurface02")
  static let surface02 = Color("appSurface02")
  static let surface2MoreTab = Color("appSurface2(moreTab)")
  static let surface3 = Color("appSurface03")
  static let surfaceOverview = Color("appSurface(Overview)")
    static let containerBG01 = Color("appContainerBG01")
    static let cardBG01 = Color("appCardBG01")
    static let cardBG02 = Color("appCardBG02")
    static let surface4 = Color("appSurface4")
  static let surface01Variant = Color("appSurface01Variant")
  static let surface04Variant = Color("appSurface04Variant")
  static let surfaceDim = Color("appSurfaceDim")
  static let surfaceBright = Color("appSurfaceBright")
  static let surfaceBright2 = Color("appSurfaceBright2")
  static let surfaceContainer = Color("appSurfaceContainer")
  static let surfaceTabBar = Color("appSurfaceTabBar")
  static let hover = Color("appHover")
  static let headerBackground = Color("appSurfaceFixed")
  static let surfaceFixed20 = Color("appSurfaceFixed20")

  // MARK: - Text Colors
  static let text01 = Color("appText01")
  static let text02 = Color("appText02")
  static let text03 = Color("appText03")
  static let text04 = Color("appText04")
  static let text05 = Color("appText05")
  static let text06 = Color("appText06")
  static let text07 = Color("appText07")
  static let text08 = Color("appText08")
  static let text09 = Color("appText09")

  // MARK: - Outline Colors
  static let outline1 = Color("appOutline1")
  static let outline1Variant = Color("appOutline1Variant")
  static let outline2 = Color("appOutline02")
  static let outline02 = Color("appOutline02")
  static let outline3 = Color("appOutline03")
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
  static let onSurfaceFixed = Color("appOnSurfaceFixed")
  static let componentBackground = Color("appComponentBackground")
  static let sheetBackground = Color("appSheetBackground")
  static let sheetBackground02 = Color("appSheetBackground02")
  static let bottomNavIconActive = Color("appBottomeNavIcon_Active")
  static let bottomNavIconInactive = Color("appBottomeNavIcon_Inactive")
  static let appIconColor = Color("appIcon")
  static let checkStroke = Color("appCheckStroke")
  static let greenBadgeBackground = Color("appGreenBadgeBackground")
  static let onGreenBadgeBackground = Color("apponGreenBadgeBackground")
  static let badgeBackground = Color("appBadgeBackground")
  static let onBadgeBackground = Color("apponBadgeBackground")

  // MARK: - Basic Colors
  static let white = Color.white
  static let black = Color.black
  static let shade10Percent = Color("appShade10%")
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
  static let secondaryContainer03 = ColorTokens.secondaryContainer03
  static let onSecondaryContainer = ColorTokens.onSecondaryContainer
  static let secondaryDim = ColorTokens.secondaryDim

  // Surface Colors
  static let surface = ColorTokens.surface
  static let surface1 = ColorTokens.surface1
  static let surface01 = ColorTokens.surface01
  static let surface2 = ColorTokens.surface2
  static let surface02 = ColorTokens.surface02
  static let surface2MoreTab = ColorTokens.surface2MoreTab
  static let surface3 = ColorTokens.surface3
  static let surfaceOverview = ColorTokens.surfaceOverview
    static let containerBG01 = ColorTokens.containerBG01
    static let surface01Variant = ColorTokens.surface01Variant
    static let surface04Variant = ColorTokens.surface04Variant
    static let cardBG01 = ColorTokens.cardBG01
    static let cardBG02 = ColorTokens.cardBG02
    static let surface4 = ColorTokens.surface4
  static let surfaceDim = ColorTokens.surfaceDim
  static let surfaceBright = ColorTokens.surfaceBright
  static let surfaceBright2 = ColorTokens.surfaceBright2
  static let surfaceContainer = ColorTokens.surfaceContainer
  static let surfaceTabBar = ColorTokens.surfaceTabBar
  static let hover = ColorTokens.hover
  static let headerBackground = ColorTokens.headerBackground
  static let surfaceFixed20 = ColorTokens.surfaceFixed20

  // Text Colors
  static let text01 = ColorTokens.text01
  static let text02 = ColorTokens.text02
  static let text03 = ColorTokens.text03
  static let text04 = ColorTokens.text04
  static let text05 = ColorTokens.text05
  static let text06 = ColorTokens.text06
  static let text07 = ColorTokens.text07
  static let text08 = ColorTokens.text08
  static let text09 = ColorTokens.text09

  // Outline Colors
  static let outline1 = ColorTokens.outline1
  static let outline2 = ColorTokens.outline2
  static let outline02 = ColorTokens.outline02
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
  static let onSurfaceFixed = ColorTokens.onSurfaceFixed
  static let componentBackground = ColorTokens.componentBackground
  static let sheetBackground = ColorTokens.sheetBackground
  static let sheetBackground02 = ColorTokens.sheetBackground02
  static let bottomNavIconActive = ColorTokens.bottomNavIconActive
  static let bottomNavIconInactive = ColorTokens.bottomNavIconInactive
  static let appIconColor = ColorTokens.appIconColor
  static let checkStroke = ColorTokens.checkStroke
  static let greenBadgeBackground = ColorTokens.greenBadgeBackground
  static let onGreenBadgeBackground = ColorTokens.onGreenBadgeBackground
  static let badgeBackground = ColorTokens.badgeBackground
  static let onBadgeBackground = ColorTokens.onBadgeBackground
  
  // Basic Colors
  static let shade10Percent = ColorTokens.shade10Percent
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
  static var secondaryContainer03: Color { ColorTokens.secondaryContainer03 }
  static var onSecondaryContainer: Color { ColorTokens.onSecondaryContainer }
  static var secondaryDim: Color { ColorTokens.secondaryDim }

  static var surface: Color { ColorTokens.surface }
  static var surface1: Color { ColorTokens.surface1 }
  static var surface01: Color { ColorTokens.surface01 }
  static var surface2: Color { ColorTokens.surface2 }
  static var surface02: Color { ColorTokens.surface02 }
  static var surface2MoreTab: Color { ColorTokens.surface2MoreTab }
  static var surface3: Color { ColorTokens.surface3 }
  static var surfaceOverview: Color { ColorTokens.surfaceOverview }
    static var containerBG01: Color { ColorTokens.containerBG01 }
    static var cardBG01: Color { ColorTokens.cardBG01 }
    static var cardBG02: Color { ColorTokens.cardBG02 }
    static var surface4: Color { ColorTokens.surface4 }
    static var surface01Variant: Color { ColorTokens.surface01Variant }
    static var surface04Variant: Color { ColorTokens.surface04Variant }
  static var surfaceDim: Color { ColorTokens.surfaceDim }
  static var surfaceBright: Color { ColorTokens.surfaceBright }
  static var surfaceBright2: Color { ColorTokens.surfaceBright2 }
  static var surfaceContainer: Color { ColorTokens.surfaceContainer }
  static var surfaceTabBar: Color { ColorTokens.surfaceTabBar }
  static var hover: Color { ColorTokens.hover }
  static var headerBackground: Color { ColorTokens.headerBackground }
  static var surfaceFixed20: Color { ColorTokens.surfaceFixed20 }

  static var text01: Color { ColorTokens.text01 }
  static var text02: Color { ColorTokens.text02 }
  static var text03: Color { ColorTokens.text03 }
  static var text04: Color { ColorTokens.text04 }
  static var text05: Color { ColorTokens.text05 }
  static var text06: Color { ColorTokens.text06 }
  static var text07: Color { ColorTokens.text07 }
  static var text08: Color { ColorTokens.text08 }
  static var text09: Color { ColorTokens.text09 }

  static var outline1: Color { ColorTokens.outline1 }
  static var outline1Variant: Color { ColorTokens.outline1Variant }
  static var outline2: Color { ColorTokens.outline2 }
  static var outline02: Color { ColorTokens.outline02 }
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
  static var onSurfaceFixed: Color { ColorTokens.onSurfaceFixed }
  static var componentBackground: Color { ColorTokens.componentBackground }
  static var sheetBackground: Color { ColorTokens.sheetBackground }
  static var sheetBackground02: Color { ColorTokens.sheetBackground02 }
  static var bottomNavIconActive: Color { ColorTokens.bottomNavIconActive }
  static var bottomNavIconInactive: Color { ColorTokens.bottomNavIconInactive }
  static var checkStroke: Color { ColorTokens.checkStroke }
  static var greenBadgeBackground: Color { ColorTokens.greenBadgeBackground }
  static var onGreenBadgeBackground: Color { ColorTokens.onGreenBadgeBackground }
  static var badgeBackground: Color { ColorTokens.badgeBackground }
  static var onBadgeBackground: Color { ColorTokens.onBadgeBackground }
  
  static var shade10Percent: Color { ColorTokens.shade10Percent }
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
    // ✅ FIX: Explicitly use Color("appPrimary") to detect Navy
    let appPrimaryColor = Color("appPrimary")
    
    let primaryUIColorLight = UIColor(appPrimaryColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let primaryUIColorDark = UIColor(appPrimaryColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    let colorUIColorLight = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let colorUIColorDark = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    
    var primaryRedLight: CGFloat = 0, primaryGreenLight: CGFloat = 0, primaryBlueLight: CGFloat = 0, primaryAlphaLight: CGFloat = 0
    primaryUIColorLight.getRed(&primaryRedLight, green: &primaryGreenLight, blue: &primaryBlueLight, alpha: &primaryAlphaLight)
    
    var primaryRedDark: CGFloat = 0, primaryGreenDark: CGFloat = 0, primaryBlueDark: CGFloat = 0, primaryAlphaDark: CGFloat = 0
    primaryUIColorDark.getRed(&primaryRedDark, green: &primaryGreenDark, blue: &primaryBlueDark, alpha: &primaryAlphaDark)
    
    var colorRedLight: CGFloat = 0, colorGreenLight: CGFloat = 0, colorBlueLight: CGFloat = 0, colorAlphaLight: CGFloat = 0
    colorUIColorLight.getRed(&colorRedLight, green: &colorGreenLight, blue: &colorBlueLight, alpha: &colorAlphaLight)
    
    var colorRedDark: CGFloat = 0, colorGreenDark: CGFloat = 0, colorBlueDark: CGFloat = 0, colorAlphaDark: CGFloat = 0
    colorUIColorDark.getRed(&colorRedDark, green: &colorGreenDark, blue: &colorBlueDark, alpha: &colorAlphaDark)
    
    let tolerance: CGFloat = 0.02
    
    let matchesLight = abs(colorRedLight - primaryRedLight) < tolerance &&
                       abs(colorGreenLight - primaryGreenLight) < tolerance &&
                       abs(colorBlueLight - primaryBlueLight) < tolerance
    
    let matchesDark = abs(colorRedDark - primaryRedDark) < tolerance &&
                      abs(colorGreenDark - primaryGreenDark) < tolerance &&
                      abs(colorBlueDark - primaryBlueDark) < tolerance
    
    if matchesLight && matchesDark {
        // Store sentinel value for semantic Navy color
        self.red = -1.0
        self.green = 0.0
        self.blue = 0.0
        self.alpha = 1.0
        return
    }
    
    // Also detect NEW Navy stored as fixed light mode RGB (#2A3563)
    let newNavyLightRed: CGFloat = 42.0 / 255.0
    let newNavyLightGreen: CGFloat = 53.0 / 255.0
    let newNavyLightBlue: CGFloat = 99.0 / 255.0
    
    if abs(colorRedLight - newNavyLightRed) < tolerance &&
       abs(colorGreenLight - newNavyLightGreen) < tolerance &&
       abs(colorBlueLight - newNavyLightBlue) < tolerance {
        self.red = -1.0
        self.green = 0.0
        self.blue = 0.0
        self.alpha = 1.0
        return
    }
    
    // Also detect OLD Navy stored as fixed light mode RGB (#1C264C)
    let oldNavyLightRed: CGFloat = 28.0 / 255.0
    let oldNavyLightGreen: CGFloat = 39.0 / 255.0
    let oldNavyLightBlue: CGFloat = 76.0 / 255.0
    
    if abs(colorRedLight - oldNavyLightRed) < tolerance &&
       abs(colorGreenLight - oldNavyLightGreen) < tolerance &&
       abs(colorBlueLight - oldNavyLightBlue) < tolerance {
        self.red = -1.0
        self.green = 0.0
        self.blue = 0.0
        self.alpha = 1.0
        return
    }
    
    // For other colors, store actual RGB
    let uiColor = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    
    self.red = Double(r)
    self.green = Double(g)
    self.blue = Double(b)
    self.alpha = Double(a)
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
    // Check for sentinel value (Navy/appPrimary semantic color)
    if red < 0 {
        return Color("appPrimary")
    }
    
    let tolerance: Double = 0.02
    
    // NEW Navy (appPrimary): #2A3563
    let newNavyRed: Double = 42.0 / 255.0
    let newNavyGreen: Double = 53.0 / 255.0
    let newNavyBlue: Double = 99.0 / 255.0
    
    // OLD Navy (navy500): #1C264C
    let oldNavyRed: Double = 28.0 / 255.0
    let oldNavyGreen: Double = 39.0 / 255.0
    let oldNavyBlue: Double = 76.0 / 255.0
    
    // Check for NEW Navy
    if abs(red - newNavyRed) < tolerance &&
       abs(green - newNavyGreen) < tolerance &&
       abs(blue - newNavyBlue) < tolerance {
        return Color("appPrimary")
    }
    
    // Check for OLD Navy
    if abs(red - oldNavyRed) < tolerance &&
       abs(green - oldNavyGreen) < tolerance &&
       abs(blue - oldNavyBlue) < tolerance {
        return Color("appPrimary")
    }
    
    return Color(red: red, green: green, blue: blue, opacity: alpha)
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
