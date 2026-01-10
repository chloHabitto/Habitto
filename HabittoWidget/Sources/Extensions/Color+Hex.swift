//
//  Color+Hex.swift
//  HabittoWidget
//
//  Color extension for parsing hex color strings
//  Used by widget views to display habit colors
//

import SwiftUI

extension Color {
    /// Initialize Color from hex string (e.g., "#FF5733" or "FF5733")
    /// Supports 3, 6, and 8 character hex strings (RGB, RGB with alpha)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            // Short hex format (e.g., "F00" -> RGB)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            // Standard hex format (e.g., "FF0000" -> RGB)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            // Hex with alpha (e.g., "FFFF0000" -> ARGB)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // Invalid format, default to black
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
}
