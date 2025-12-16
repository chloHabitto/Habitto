import SwiftUI

// MARK: - Font System. This is a custom font system to prevent ambiguity errors.

// This extension provides a centralized font system to prevent ambiguity errors.
// Always use the custom font names defined here instead of direct SwiftUI.Font usage.

extension Font {
  // MARK: - Display

  static let appDisplayLarge = Font.system(size: 57, weight: .regular)
  static let appDisplayLargeEmphasised = Font.system(size: 57, weight: .medium)
  static let appDisplayMedium = Font.system(size: 45, weight: .medium)
  static let appDisplayMediumEmphasised = Font.system(size: 45, weight: .bold)
  static let appDisplaySmall = Font.system(size: 36, weight: .regular)
  static let appDisplaySmallEmphasised = Font.system(size: 36, weight: .medium)

  // MARK: - Headline

  static let appHeadlineLarge = Font.system(size: 32, weight: .regular)
  static let appHeadlineLargeEmphasised = Font.system(size: 32, weight: .semibold)
  static let appHeadlineMedium = Font.system(size: 28, weight: .regular)
  static let appHeadlineMediumEmphasised = Font.system(size: 28, weight: .semibold)
  static let appHeadlineSmall = Font.system(size: 24, weight: .regular)
  static let appHeadlineSmallEmphasised = Font.system(size: 24, weight: .semibold)

  // MARK: - Title

  static let appTitleLarge = Font.system(size: 18, weight: .medium)
  static let appTitleLargeEmphasised = Font.system(size: 18, weight: .semibold)
  static let appTitleMedium = Font.system(size: 16, weight: .medium)
  static let appTitleMediumEmphasised = Font.system(size: 16, weight: .semibold)
  static let appTitleSmall = Font.system(size: 14, weight: .medium)
  static let appTitleSmallEmphasised = Font.system(size: 14, weight: .semibold)

  // MARK: - Label

  static let appLabelLarge = Font.system(size: 14, weight: .medium)
  static let appLabelLargeEmphasised = Font.system(size: 14, weight: .semibold)
  static let appLabelMedium = Font.system(size: 12, weight: .medium)
  static let appLabelMediumEmphasised = Font.system(size: 12, weight: .semibold)
  static let appLabelSmall = Font.system(size: 11, weight: .medium)
  static let appLabelSmallEmphasised = Font.system(size: 11, weight: .semibold)

  // MARK: - Body

  static let appBodyExtraLarge = Font.system(size: 18, weight: .regular)
  static let appBodyLarge = Font.system(size: 16, weight: .regular)
  static let appBodyLargeEmphasised = Font.system(size: 16, weight: .medium)
  static let appBodyMedium = Font.system(size: 14, weight: .regular)
  static let appBodyMediumEmphasised = Font.system(size: 14, weight: .medium)
  static let appBodySmall = Font.system(size: 12, weight: .regular)
  static let appBodySmallEmphasised = Font.system(size: 12, weight: .medium)
  static let appBodyExtraSmall = Font.system(size: 10, weight: .regular)

  // MARK: - Caption

  static let appCaptionLarge = Font.system(size: 12, weight: .medium)
  static let appCaptionMedium = Font.system(size: 11, weight: .medium)
  static let appCaptionSmall = Font.system(size: 10, weight: .medium)

  // MARK: - Button Text

  static let appButtonText1 = Font.system(size: 18, weight: .semibold)
  static let appButtonText2 = Font.system(size: 16, weight: .medium)
  static let appButtonText3 = Font.system(size: 14, weight: .medium)
}

// MARK: - Font Usage Guidelines

// TO PREVENT "ambiguous use of 'font'" ERRORS:
//
// 1. ALWAYS use the custom font names defined above:
//   ✅ .font(.appBodyLarge)
//   ✅ .font(.titleMedium)
//   ✅ .font(.appButtonText1)
//
// 2. NEVER use direct SwiftUI.Font qualification:
//   ❌ .font(SwiftUI.Font.appBodyLarge)
//   ❌ .font(Font.appBodyLarge)
//
// 3. For system fonts, use the predefined custom fonts:
//   ✅ .font(.titleMedium)  // instead of .font(.system(size: 16, weight: .medium))
//   ✅ .font(.appBodyLarge)    // instead of .font(.system(size: 16, weight: .regular))
//
// 4. If you need a custom system font, create it in this extension first:
//   static let customFont = Font.system(size: 20, weight: .bold)
//   Then use: .font(.customFont)
//
// 5. For complex view hierarchies, break them down into smaller components
//   to help the compiler with type inference.
//
// 6. Use @ViewBuilder for complex computed properties to improve type inference.
//
// 7. When in doubt, use the simple dot notation: .font(.appBodyLarge)

// MARK: - Font Helper Functions

extension View {
  /// Apply appBody large font with consistent styling
  func appBodyLargeFont() -> some View {
    font(.appBodyLarge)
  }

  /// Apply title medium font with consistent styling
  func titleMediumFont() -> some View {
    font(.appTitleMedium)
  }

  /// Apply button text font with consistent styling
  func appButtonTextFont() -> some View {
    font(.appButtonText1)
  }

  /// Apply label medium font with consistent styling
  func labelMediumFont() -> some View {
    font(.appLabelMedium)
  }

  /// Apply title small font with consistent styling
  func titleSmallFont() -> some View {
    font(.appTitleSmall)
  }

  /// Apply headline small emphasised font with consistent styling
  func headlineSmallEmphasisedFont() -> some View {
    font(.appHeadlineSmallEmphasised)
  }

  /// Apply label medium emphasised font with consistent styling
  func labelMediumEmphasisedFont() -> some View {
    font(.appLabelMediumEmphasised)
  }
}

// MARK: - Common Font Patterns

// FREQUENTLY USED FONT PATTERNS:
//
// Text Elements:
// - .font(.appBodyLarge)      // Main text content
// - .font(.appBodyMedium)     // Secondary text content
// - .font(.titleMedium)    // Section headers
// - .font(.appTitleSmall)     // Subsection headers
// - .font(.labelMedium)    // Small labels and captions
//
// Buttons:
// - .font(.appButtonText1)    // Primary buttons
// - .font(.appButtonText2)    // Secondary buttons
// - .font(.appButtonText3)    // Small buttons
//
// Headers:
// - .font(.appHeadlineMediumEmphasised)  // Main page titles
// - .font(.appHeadlineSmallEmphasised)   // Section titles
// - .font(.titleLarge)                // Large headers
//
// Always use these patterns consistently across your codebase.

// MARK: - Troubleshooting Font Ambiguity

// IF YOU STILL GET "ambiguous use of 'font'" ERRORS:
//
// 1. Check for inconsistent font usage patterns:
//   - Search for: .font(SwiftUI.Font.
//   - Search for: .font(Font.
//   - Search for: .font(.system(
//
// 2. Replace all instances with the simple pattern:
//   - Change: .font(SwiftUI.Font.appBodyLarge) → .font(.appBodyLarge)
//   - Change: .font(Font.appBodyLarge) → .font(.appBodyLarge)
//   - Change: .font(.system(size: 16, weight: .medium)) → .font(.titleMedium)
//
// 3. For complex view hierarchies, break them down:
//   - Use @ViewBuilder for computed properties
//   - Create separate view components
//   - Use Group wrappers when needed
//
// 4. If the error persists, try explicit type annotation:
//   let textView: Text = Text("Hello")
//   textView.font(.appBodyLarge)
//
// 5. For system fonts, always define them in this extension first:
//   static let customSize = Font.system(size: 20, weight: .bold)
//   Then use: .font(.customSize)
//
// 6. Use the helper functions when possible:
//   Text("Hello").appBodyLargeFont()
//   Text("Title").titleMediumFont()
//   Text("Button").appButtonTextFont()

// MARK: - Quick Fix Commands

// To quickly fix font ambiguity issues, run these search and replace commands:
//
// 1. Replace SwiftUI.Font. with . (simple dot notation)
// 2. Replace Font. with . (simple dot notation)
// 3. Replace .system(size: 16, weight: .medium) with .titleMedium
// 4. Replace .system(size: 14, weight: .medium) with .appBodyMedium
// 5. Replace .system(size: 18, weight: .semibold) with .appButtonText1
//
// Always test after making changes to ensure the app still builds correctly.
