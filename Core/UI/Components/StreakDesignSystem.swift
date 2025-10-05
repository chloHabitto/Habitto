import SwiftUI

// MARK: - Overview View Modern Design System
// This file contains all the design tokens and styles for the modernized overview view

// MARK: - Color Palette
struct StreakColors {
    // Primary Colors
    static let primary = Color.primary
    static let primaryLight = Color.primary.opacity(0.8)
    static let primaryLighter = Color.primary.opacity(0.6)
    
    // Fire & Streak Colors
    static let fireOrange = Color.orange
    static let fireRed = Color.red
    static let fireYellow = Color.yellow
    static let streakGold = Color.yellow.opacity(0.8)
    
    // Modern Gradients
    static let fireGradient = LinearGradient(
        colors: [fireOrange, fireRed, fireYellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let streakGradient = LinearGradient(
        colors: [streakGold, fireOrange, fireRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassGradient = LinearGradient(
        colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Background Colors
    static let glassBackground = Color.white.opacity(0.6)
    static let cardBackground = Color.surface
    static let surfaceBackground = Color.surface2
    
    // Text Colors
    static let primaryText = Color.text01
    static let secondaryText = Color.text02
    static let accentText = Color.text03
    static let lightText = Color.text04
    
    // Status Colors
    static let success = Color.green
    static let warning = Color.orange
    static let info = Color.blue
    static let neutral = Color.gray
}

// MARK: - Typography Scale
struct StreakTypography {
    // Display Text
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 24, weight: .bold, design: .rounded)
    
    // Headlines
    static let headlineLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    
    // Titles
    static let titleLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let titleMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
    
    // Body Text
    static let bodyLarge = Font.system(size: 16, weight: .medium, design: .rounded)
    static let bodyMedium = Font.system(size: 14, weight: .medium, design: .rounded)
    static let bodySmall = Font.system(size: 12, weight: .medium, design: .rounded)
    
    // Labels
    static let labelLarge = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let labelMedium = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let labelSmall = Font.system(size: 10, weight: .semibold, design: .rounded)
    
    // Numbers (for streak counters)
    static let numberLarge = Font.system(size: 64, weight: .black, design: .rounded)
    static let numberMedium = Font.system(size: 48, weight: .black, design: .rounded)
    static let numberSmall = Font.system(size: 32, weight: .black, design: .rounded)
}

// MARK: - Spacing System
struct StreakSpacing {
    // Base spacing unit
    static let base: CGFloat = 4
    
    // Spacing scale
    static let xs: CGFloat = base * 1      // 4pt
    static let sm: CGFloat = base * 2      // 8pt
    static let md: CGFloat = base * 3      // 12pt
    static let lg: CGFloat = base * 4      // 16pt
    static let xl: CGFloat = base * 6      // 24pt
    static let xxl: CGFloat = base * 8     // 32pt
    static let xxxl: CGFloat = base * 12   // 48pt
    
    // Component-specific spacing
    static let cardPadding: CGFloat = lg
    static let sectionSpacing: CGFloat = xl
    static let elementSpacing: CGFloat = md
    static let iconSpacing: CGFloat = sm
}

// MARK: - Shadow System
struct StreakShadows {
    // Soft shadows for depth
    static let soft = Shadow(
        color: .black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )
    
    // Medium shadows for cards
    static let medium = Shadow(
        color: .black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 8
    )
    
    // Strong shadows for emphasis
    static let strong = Shadow(
        color: .black.opacity(0.16),
        radius: 24,
        x: 0,
        y: 12
    )
    
    // Glow effects for fire elements
    static let fireGlow = Shadow(
        color: .orange.opacity(0.3),
        radius: 20,
        x: 0,
        y: 0
    )
    
    static let streakGlow = Shadow(
        color: .yellow.opacity(0.4),
        radius: 16,
        x: 0,
        y: 0
    )
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    var shadow: some View {
        Color.clear
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}

// MARK: - Animation System
struct StreakAnimations {
    // Timing curves
    static let easeOut = Animation.easeOut(duration: 0.3)
    static let easeInOut = Animation.easeInOut(duration: 0.4)
    static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    // Duration constants
    static let quick: Double = 0.2
    static let normal: Double = 0.4
    static let slow: Double = 0.8
    
    // Fire animations
    static let fireFlicker = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let fireFloat = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)
    
    // Streak animations
    static let streakCount = Animation.spring(response: 0.8, dampingFraction: 0.6)
    static let streakCelebration = Animation.easeOut(duration: 0.6)
}

// MARK: - Corner Radius System
struct StreakCorners {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
    static let round: CGFloat = 50
}

// MARK: - Glassmorphism Effects
struct StreakGlassmorphism {
    static let primary = GlassmorphismEffect(
        background: StreakColors.glassBackground,
        overlay: StreakColors.glassGradient,
        border: Color.white.opacity(0.2)
    )
    
    static let secondary = GlassmorphismEffect(
        background: Color.white.opacity(0.1),
        overlay: LinearGradient(
            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        border: Color.white.opacity(0.15)
    )
}

// MARK: - Glassmorphism Effect Helper
struct GlassmorphismEffect {
    let background: Color
    let overlay: LinearGradient
    let border: Color
    
    var effect: some View {
        background
            .overlay(overlay)
            .overlay(
                RoundedRectangle(cornerRadius: StreakCorners.lg)
                    .stroke(border, lineWidth: 1)
            )
    }
}

// MARK: - Modern Card Styles
struct StreakCardStyles {
    // Primary card style
    static let primary = CardStyle(
        background: StreakColors.cardBackground,
        cornerRadius: StreakCorners.lg,
        shadow: StreakShadows.soft,
        padding: StreakSpacing.cardPadding
    )
    
    // Glass card style
    static let glass = CardStyle(
        background: StreakColors.glassBackground,
        cornerRadius: StreakCorners.lg,
        shadow: StreakShadows.medium,
        padding: StreakSpacing.cardPadding
    )
    
    // Elevated card style
    static let elevated = CardStyle(
        background: StreakColors.cardBackground,
        cornerRadius: StreakCorners.xl,
        shadow: StreakShadows.strong,
        padding: StreakSpacing.cardPadding
    )
}

// MARK: - Card Style Helper
struct CardStyle {
    let background: Color
    let cornerRadius: CGFloat
    let shadow: Shadow
    let padding: CGFloat
    
    var style: some View {
        background
            .cornerRadius(cornerRadius)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Extension for Easy Usage
extension View {
    // Apply streak card styles
    func streakCard(_ style: CardStyle) -> some View {
        self
            .background(style.style)
            .padding(style.padding)
    }
    
    // Apply glassmorphism effects
    func streakGlass(_ effect: GlassmorphismEffect) -> some View {
        self
            .background(effect.effect)
    }
    
    // Apply streak shadows
    func streakShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // Apply streak corners
    func streakCorner(_ radius: CGFloat) -> some View {
        self.cornerRadius(radius)
    }
    
    // Apply streak animations
    func streakAnimation(_ animation: Animation) -> some View {
        self.animation(animation, value: UUID())
    }
}
