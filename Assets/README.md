# Assets

This folder contains all asset catalogs for the Habitto app.

## Structure

### Colors.xcassets
Contains color-related assets:
- `AccentColor.colorset/` - App accent color
- `AppIcon.appiconset/` - App icon
- **Primitive Colors**: All color variants (yellow50-900, green50-900, red50-900, navy50-900, pastelBlue50-900, grey50-900, greyBlack, greyWhite) with light and dark mode support

### Icons.xcassets
Contains all icon assets:
- Individual icon imagesets (Icon-fire, Icon-starBadge, etc.)
- Bottom navigation icons (`Icons-bottomNav/` folder)

## Usage

- **Icons**: Use `Image("Icon-name")` in SwiftUI views
- **Colors**: Use `Color("AccentColor")` or reference through `ColorSystem.swift`
- **App Icon**: Automatically used by iOS

## Organization Benefits

- Clear separation between colors and icons
- Easy to find and manage assets
- Scalable structure for future assets
- Better team collaboration

## Migration Notes

- **Primitive Colors**: Moved from hardcoded hex values in `ColorSystem.swift` to asset catalog
- **Usage**: Colors are now referenced as `Color("colorName")` instead of `Color(hex: "#...")`
- **Benefits**: Better color management, support for dark mode, and easier color updates
- **Dark Mode**: All primitive colors now support both light and dark mode variants 