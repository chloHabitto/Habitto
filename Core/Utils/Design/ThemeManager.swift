import Foundation
import SwiftUI

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Load saved theme preference
    if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
       let theme = AppTheme(rawValue: savedTheme)
    {
      self.selectedTheme = theme
    }
    
    // Load saved color scheme preference
    if let savedColorScheme = UserDefaults.standard.string(forKey: "colorScheme"),
       let colorScheme = ColorSchemeOption(rawValue: savedColorScheme)
    {
      self.selectedColorScheme = colorScheme
    }
    
    updateAppColors()
  }

  // MARK: Internal

  static let shared = ThemeManager()

  @Published var selectedTheme: AppTheme = .default {
    didSet {
      UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
      updateAppColors()
    }
  }
  
  @Published var selectedColorScheme: ColorSchemeOption = .system {
    didSet {
      UserDefaults.standard.set(selectedColorScheme.rawValue, forKey: "colorScheme")
      NotificationCenter.default.post(name: .colorSchemeDidChange, object: selectedColorScheme)
    }
  }
  
  /// Get the SwiftUI ColorScheme based on the selected option
  var colorScheme: ColorScheme? {
    switch selectedColorScheme {
    case .system:
      return nil // nil means use system default
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }

  // MARK: Private

  private func updateAppColors() {
    // Update the app's color scheme based on selected theme
    // This will be used to dynamically change colors throughout the app
    NotificationCenter.default.post(name: .themeDidChange, object: selectedTheme)
  }
}

// MARK: - AppTheme

enum AppTheme: String, CaseIterable {
  case `default`
  case black
  case purple
  case pink

  // MARK: Internal

  var name: String {
    switch self {
    case .default:
      "Default"
    case .black:
      "Black"
    case .purple:
      "Purple"
    case .pink:
      "Pink"
    }
  }

  var primaryColor: String {
    switch self {
    case .default:
      "1C274C" // navy500
    case .black:
      "16181E" // black500
    case .purple:
      "8E2AF9" // themePurple500
    case .pink:
      "F92A95" // themePink500
    }
  }

  var previewColor: Color {
    switch self {
    case .default:
      Color(hex: "1C274C")
    case .black:
      Color(hex: "16181E")
    case .purple:
      Color(hex: "8E2AF9")
    case .pink:
      Color(hex: "F92A95")
    }
  }

  var description: String {
    switch self {
    case .default:
      "Classic blue theme"
    case .black:
      "Dark black theme"
    case .purple:
      "Vibrant purple theme"
    case .pink:
      "Bright pink theme"
    }
  }

  // MARK: - Theme Color Palette

  var colorPalette: ThemeColorPalette {
    switch self {
    case .default:
      ThemeColorPalette.defaultPalette
    case .black:
      ThemeColorPalette.blackPalette
    case .purple:
      ThemeColorPalette.purplePalette
    case .pink:
      ThemeColorPalette.pinkPalette
    }
  }
}

// MARK: - ThemeColorPalette

struct ThemeColorPalette {
  static let defaultPalette = ThemeColorPalette(
    primary: "1C274C", // navy500
    primaryFocus: "2A3B5C", // navy400
    onPrimary: "FFFFFF", // greyWhite
    primaryContainer: "F8F9FA", // navy50
    onPrimaryContainer: "1C274C", // navy900
    primaryDim: "5A6B7C", // navy300
    primaryContainerFocus: "E8EBF0", // navy200
    text01: "000000", // greyBlack
    text02: "1C274C", // navy900
    text03: "5A6B7C", // navy600
    text04: "8A9BA8", // navy400
    outlineHighlight: "2A3B5C" // navy400
  )

  static let blackPalette = ThemeColorPalette(
    primary: "16181E", // black500
    primaryFocus: "2A2D33", // black400
    onPrimary: "FFFFFF", // greyWhite
    primaryContainer: "F5F5F5", // black50
    onPrimaryContainer: "16181E", // black900
    primaryDim: "4A4D53", // black300
    primaryContainerFocus: "E5E5E5", // black200
    text01: "000000", // greyBlack
    text02: "16181E", // black900
    text03: "4A4D53", // black600
    text04: "6A6D73", // black400
    outlineHighlight: "2A2D33" // black400
  )

  static let purplePalette = ThemeColorPalette(
    primary: "8E2AF9", // themePurple500
    primaryFocus: "A555FA", // themePurple400
    onPrimary: "FFFFFF", // greyWhite
    primaryContainer: "F4EAFE", // themePurple50
    onPrimaryContainer: "8E2AF9", // themePurple500
    primaryDim: "B370FB", // themePurple300
    primaryContainerFocus: "DCBDFD", // themePurple100
    text01: "000000", // greyBlack
    text02: "8E2AF9", // themePurple500
    text03: "B370FB", // themePurple300
    text04: "A555FA", // themePurple400
    outlineHighlight: "A555FA" // themePurple400
  )

  static let pinkPalette = ThemeColorPalette(
    primary: "F92A95", // themePink500
    primaryFocus: "FA55AA", // themePink400
    onPrimary: "FFFFFF", // greyWhite
    primaryContainer: "FEEAF4", // themePink50
    onPrimaryContainer: "F92A95", // themePink500
    primaryDim: "FB70B8", // themePink300
    primaryContainerFocus: "FDBDDE", // themePink100
    text01: "000000", // greyBlack
    text02: "F92A95", // themePink500
    text03: "FB70B8", // themePink300
    text04: "FA55AA", // themePink400
    outlineHighlight: "FA55AA" // themePink400
  )

  // Primary Colors
  let primary: String
  let primaryFocus: String
  let onPrimary: String
  let primaryContainer: String
  let onPrimaryContainer: String
  let primaryDim: String
  let primaryContainerFocus: String

  // Text Colors (theme-dependent)
  let text01: String
  let text02: String
  let text03: String
  let text04: String

  /// Outline Colors (theme-dependent)
  let outlineHighlight: String
}

// Note: Color extension for hex support is already defined in ColorSystem.swift

// MARK: - Notification Name

extension Notification.Name {
  static let themeDidChange = Notification.Name("themeDidChange")
  static let colorSchemeDidChange = Notification.Name("colorSchemeDidChange")
}

// MARK: - ColorSchemeOption

enum ColorSchemeOption: String {
  case system
  case light
  case dark
  
  var title: String {
    switch self {
    case .system:
      "Auto"
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }
  
  var description: String {
    switch self {
    case .system:
      "Match system appearance"
    case .light:
      "Always use light mode"
    case .dark:
      "Always use dark mode"
    }
  }
  
  var iconName: String {
    switch self {
    case .system:
      "Icon-Theme_Auto"
    case .light:
      "Icon-lightMode_Filled"
    case .dark:
      "Icon-darkMode_Filled"
    }
  }
}
