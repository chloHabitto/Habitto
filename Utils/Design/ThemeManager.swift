import Foundation
import SwiftUI

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selectedTheme: AppTheme = .default {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
            updateAppColors()
        }
    }
    
    private init() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.selectedTheme = theme
        }
        updateAppColors()
    }
    
    private func updateAppColors() {
        // Update the app's color scheme based on selected theme
        // This will be used to dynamically change colors throughout the app
        NotificationCenter.default.post(name: .themeDidChange, object: selectedTheme)
    }
}

// MARK: - App Theme Options
enum AppTheme: String, CaseIterable {
    case `default` = "default"
    case black = "black"
    
    var name: String {
        switch self {
        case .default:
            return "Default"
        case .black:
            return "Black"
        }
    }
    
    var primaryColor: String {
        switch self {
        case .default:
            return "1C274C" // navy500
        case .black:
            return "16181E" // black500
        }
    }
    
    var previewColor: Color {
        switch self {
        case .default:
            return Color(hex: "1C274C")
        case .black:
            return Color(hex: "16181E")
        }
    }
    
    var description: String {
        switch self {
        case .default:
            return "Classic blue theme"
        case .black:
            return "Dark black theme"
        }
    }
    
    // MARK: - Theme Color Palette
    var colorPalette: ThemeColorPalette {
        switch self {
        case .default:
            return ThemeColorPalette.defaultPalette
        case .black:
            return ThemeColorPalette.blackPalette
        }
    }
}

// MARK: - Theme Color Palette
struct ThemeColorPalette {
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
    
    // Outline Colors (theme-dependent)
    let outlineHighlight: String
    
    static let defaultPalette = ThemeColorPalette(
        primary: "1C274C",           // navy500
        primaryFocus: "2A3B5C",      // navy400
        onPrimary: "FFFFFF",         // greyWhite
        primaryContainer: "F8F9FA",  // navy50
        onPrimaryContainer: "1C274C", // navy900
        primaryDim: "5A6B7C",        // navy300
        primaryContainerFocus: "E8EBF0", // navy200
        text01: "000000",            // greyBlack
        text02: "1C274C",            // navy900
        text03: "5A6B7C",            // navy600
        text04: "8A9BA8",            // navy400
        outlineHighlight: "2A3B5C"   // navy400
    )
    
    static let blackPalette = ThemeColorPalette(
        primary: "16181E",           // black500
        primaryFocus: "2A2D33",      // black400
        onPrimary: "FFFFFF",         // greyWhite
        primaryContainer: "F5F5F5",  // black50
        onPrimaryContainer: "16181E", // black900
        primaryDim: "4A4D53",        // black300
        primaryContainerFocus: "E5E5E5", // black200
        text01: "000000",            // greyBlack
        text02: "16181E",            // black900
        text03: "4A4D53",            // black600
        text04: "6A6D73",            // black400
        outlineHighlight: "2A2D33"   // black400
    )
}

// Note: Color extension for hex support is already defined in ColorSystem.swift

// MARK: - Notification Name
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
