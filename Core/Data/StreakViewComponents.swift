import SwiftUI

// MARK: - Helper Functions
private func pluralizeDay(_ count: Int) -> String {
    if count == 0 {
        return "0 day"
    } else if count == 1 {
        return "1 day"
    } else {
        return "\(count) days"
    }
}

// MARK: - Streak Header Components
struct StreakHeaderView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Modern Main Streak Display
struct MainStreakDisplayView: View {
    let currentStreak: Int
    @State private var isAnimating = false
    @State private var fireScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: StreakSpacing.lg) {
            // Enhanced Fire Icon with Modern Design
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(StreakColors.fireGradient)
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .opacity(glowOpacity)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(StreakAnimations.fireFloat, value: isAnimating)
                
                // Main background circle with glassmorphism
                Circle()
                    .fill(StreakColors.glassBackground)
                    .overlay(
                        Circle()
                            .stroke(
                                StreakColors.fireGradient,
                                lineWidth: 3
                            )
                    )
                    .frame(width: 100, height: 100)
                    .streakShadow(StreakShadows.medium)
                
                // Fire icon with enhanced styling
                Image(.iconFire)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundStyle(StreakColors.fireGradient)
                    .scaleEffect(fireScale)
                    .animation(StreakAnimations.fireFlicker, value: isAnimating)
                
                // Floating particles around the fire
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(StreakColors.fireYellow)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: 35 * cos(Double(index) * .pi / 3),
                            y: 35 * sin(Double(index) * .pi / 3)
                        )
                        .opacity(isAnimating ? 0.8 : 0.3)
                        .scaleEffect(isAnimating ? 1.5 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            // Enhanced Streak Counter with Modern Typography
            VStack(spacing: StreakSpacing.sm) {
                Text(pluralizeDay(currentStreak))
                    .font(StreakTypography.numberSmall)
                    .foregroundStyle(StreakColors.streakGradient)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(StreakAnimations.streakCount, value: currentStreak)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentStreak) { _, newStreak in
            if newStreak > 0 {
                celebrateNewStreak()
            }
        }
    }
    
    // MARK: - Animation Functions
    private func startAnimations() {
        withAnimation(StreakAnimations.easeInOut.delay(0.3)) {
            isAnimating = true
        }
        
        // Start glow animation
        withAnimation(StreakAnimations.fireFloat) {
            glowOpacity = 0.6
        }
    }
    
    private func celebrateNewStreak() {
        // Fire scale animation
        withAnimation(StreakAnimations.spring) {
            fireScale = 1.3
        }
        
        // Reset scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(StreakAnimations.spring) {
                fireScale = 1.0
            }
        }
    }
    

}

// MARK: - Modern Streak Summary Cards
struct StreakSummaryCardsView: View {
    let bestStreak: Int
    let averageStreak: Int
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Best Streak Card
            ModernStreakCardView(
                icon: "Icon-starBadge",
                iconColor: StreakColors.streakGold,
                value: pluralizeDay(bestStreak),
                label: "Best Streak",
                description: "",
                isAnimating: isAnimating,
                delay: 0.0
            )
            
            // Divider with modern styling
            Rectangle()
                .fill(StreakColors.lightText.opacity(0.2))
                .frame(width: 1)
                .frame(height: 80)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreakAnimations.easeInOut.delay(0.4), value: isAnimating)
            
            // Average Streak Card
            ModernStreakCardView(
                icon: "Icon-medalBadge",
                iconColor: StreakColors.fireOrange,
                value: pluralizeDay(averageStreak),
                label: "Average Streak",
                description: "",
                isAnimating: isAnimating,
                delay: 0.2
            )
        }
        .background(StreakColors.glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: StreakCorners.lg)
                .stroke(
                    LinearGradient(
                        colors: [StreakColors.fireOrange.opacity(0.3), StreakColors.streakGold.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .streakCorner(StreakCorners.lg)
        .streakShadow(StreakShadows.soft)
        .padding(.horizontal, StreakSpacing.lg)
        .onAppear {
            withAnimation(StreakAnimations.easeInOut.delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Modern Individual Streak Card
struct ModernStreakCardView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let description: String
    let isAnimating: Bool
    let delay: Double
    
    var body: some View {
        VStack(spacing: StreakSpacing.md) {
            // Icon and Value Row
            HStack(spacing: StreakSpacing.sm) {
                // Enhanced Icon with Background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    if icon.hasPrefix("Icon-") {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(iconColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(StreakAnimations.spring.delay(delay), value: isAnimating)
                
                // Value with Modern Typography
                Text(value)
                    .font(StreakTypography.titleLarge)
                    .foregroundColor(StreakColors.primaryText)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(StreakAnimations.easeInOut.delay(delay + 0.1), value: isAnimating)
            }
            
            // Label and (optional) Description
            VStack(spacing: StreakSpacing.xs) {
                Text(label)
                    .font(StreakTypography.labelMedium)
                    .foregroundColor(StreakColors.secondaryText)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(StreakAnimations.easeInOut.delay(delay + 0.2), value: isAnimating)

                if !description.isEmpty {
                    Text(description)
                        .font(StreakTypography.bodySmall)
                        .foregroundColor(StreakColors.accentText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .animation(StreakAnimations.easeInOut.delay(delay + 0.3), value: isAnimating)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StreakSpacing.lg)
        .padding(.horizontal, StreakSpacing.md)
    }
}

// MARK: - Modern Progress Tabs
struct ProgressTabsView: View {
    let selectedTab: Int
    let onTabSelected: (Int) -> Void
    
    private let tabs = ["Weekly", "Monthly", "Yearly"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                ModernTabButton(
                    title: tabs[index],
                    isSelected: selectedTab == index,
                    onTap: { onTabSelected(index) }
                )
            }
        }
        .background(StreakColors.surfaceBackground)
        .streakCorner(StreakCorners.lg)
        .streakShadow(StreakShadows.soft)
        .padding(.horizontal, StreakSpacing.lg)
    }
}

// MARK: - Modern Tab Button
struct ModernTabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Tab Text
                Text(title)
                    .font(StreakTypography.labelLarge)
                    .foregroundColor(isSelected ? StreakColors.primaryText : StreakColors.lightText)
                    .padding(.horizontal, StreakSpacing.lg)
                    .padding(.vertical, StreakSpacing.md)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: StreakCorners.lg)
                            .fill(isSelected ? StreakColors.primary.opacity(0.1) : Color.clear)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(StreakAnimations.easeOut, value: isPressed)
                
                // Modern Underline Indicator
                Rectangle()
                    .fill(
                        isSelected ? StreakColors.fireOrange : Color.clear
                    )
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .streakCorner(StreakCorners.xs)
                    .animation(StreakAnimations.spring, value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(StreakAnimations.easeOut) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Date Range Selector
struct DateRangeSelectorView: View {
    let displayText: String
    let onTap: () -> Void
    let showDownChevron: Bool
    
    init(displayText: String, onTap: @escaping () -> Void, showDownChevron: Bool = false) {
        self.displayText = displayText
        self.onTap = onTap
        self.showDownChevron = showDownChevron
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(displayText)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                if showDownChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 12, height: 12)
                        .foregroundColor(.text04)
                } else {
                    Image(.iconLeftArrow)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.text04)
                        .rotationEffect(.degrees(90))
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())

    }
}

// MARK: - Calendar Empty State View
struct CalendarEmptyStateView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .font(.appDisplaySmall)
                .foregroundColor(.secondary)
            Text(title)
                .font(.appButtonText2)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.appBodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Heatmap Cell
struct HeatmapCellView: View {
    let intensity: Int
    let isScheduled: Bool
    let completionPercentage: Double
    let rectangleSizePercentage: Double
    
    init(intensity: Int, isScheduled: Bool, completionPercentage: Double, rectangleSizePercentage: Double = 0.5) {
        self.intensity = intensity
        self.isScheduled = isScheduled
        self.completionPercentage = completionPercentage
        self.rectangleSizePercentage = rectangleSizePercentage
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let cellSize = size * rectangleSizePercentage // Use custom percentage for rectangle size
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(.clear)
                    .frame(width: size, height: size)
                
                if isScheduled {
                    // Show heatmap when scheduled with modern rounded design
                    RoundedRectangle(cornerRadius: 12)
                        .fill(heatmapColor(for: completionPercentage))
                        .frame(width: cellSize, height: cellSize)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    // Show nothing when not scheduled - better for accessibility
                    // Empty space makes it clear the habit wasn't supposed to be done
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            // Debug: Print cell information for troubleshooting
            print("🔍 HEATMAP CELL DEBUG - Intensity: \(intensity) | Scheduled: \(isScheduled) | Completion: \(completionPercentage)%")
        }
    }
    
    private func heatmapColor(for completionPercentage: Double) -> Color {
        // Clamp completion percentage between 0 and 100
        let clampedPercentage = max(0.0, min(100.0, completionPercentage))
        
        // Map completion percentage to modern color intensity with better contrast
        // 0% = primaryContainer (lightest)
        // 100% = green600 (darkest)
        
        let selectedColor: Color
        if clampedPercentage == 0.0 {
            selectedColor = .primaryContainer
        } else if clampedPercentage >= 100.0 {
            selectedColor = Color("green600")
        } else if clampedPercentage >= 90.0 {
            selectedColor = Color("green500")
        } else if clampedPercentage >= 75.0 {
            selectedColor = Color("green400")
        } else if clampedPercentage >= 60.0 {
            selectedColor = Color("green300")
        } else if clampedPercentage >= 40.0 {
            selectedColor = Color("green200")
        } else if clampedPercentage >= 20.0 {
            selectedColor = Color("green100")
        } else {
            selectedColor = .primaryContainer
        }
        
        // Debug: Print color selection for troubleshooting
        print("🔍 HEATMAP COLOR DEBUG - Completion: \(completionPercentage)% | Clamped: \(clampedPercentage)% | Selected Color: \(selectedColor)")
        
        return selectedColor
    }
}



// MARK: - Modern Summary Statistics
struct SummaryStatisticsView: View {
    let completionRate: Int
    let bestStreak: Int
    let consistencyRate: Int
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Completion Rate Card
            ModernStatisticCardView(
                value: "\(completionRate)%",
                label: "Completion",
                icon: "checkmark.circle.fill",
                iconColor: StreakColors.success,
                isAnimating: isAnimating,
                delay: 0.0
            )
            
            // Modern Divider
            Rectangle()
                .fill(StreakColors.lightText.opacity(0.2))
                .frame(width: 1)
                .frame(height: 70)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreakAnimations.easeInOut.delay(0.4), value: isAnimating)
            
            // Best Streak Card
            ModernStatisticCardView(
                value: pluralizeDay(bestStreak),
                label: "Best Streak",
                icon: "flame.fill",
                iconColor: StreakColors.fireOrange,
                isAnimating: isAnimating,
                delay: 0.2
            )
            
            // Modern Divider
            Rectangle()
                .fill(StreakColors.lightText.opacity(0.2))
                .frame(width: 1)
                .frame(height: 70)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreakAnimations.easeInOut.delay(0.6), value: isAnimating)
            
            // Consistency Rate Card
            ModernStatisticCardView(
                value: "\(consistencyRate)%",
                label: "Consistency",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: StreakColors.info,
                isAnimating: isAnimating,
                delay: 0.4
            )
        }
        .background(StreakColors.glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: StreakCorners.lg)
                .stroke(
                    LinearGradient(
                        colors: [
                            StreakColors.success.opacity(0.3),
                            StreakColors.fireOrange.opacity(0.3),
                            StreakColors.info.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .streakCorner(StreakCorners.lg)
        .streakShadow(StreakShadows.soft)
        .onAppear {
            withAnimation(StreakAnimations.easeInOut.delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Modern Individual Statistic Card
struct ModernStatisticCardView: View {
    let value: String
    let label: String
    let icon: String
    let iconColor: Color
    let isAnimating: Bool
    let delay: Double
    
    var body: some View {
        VStack(spacing: StreakSpacing.sm) {
            // Icon with Background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(StreakAnimations.spring.delay(delay), value: isAnimating)
            
            // Value with Modern Typography
            Text(value)
                .font(StreakTypography.titleMedium)
                .foregroundColor(StreakColors.primaryText)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreakAnimations.easeInOut.delay(delay + 0.1), value: isAnimating)
            
            // Label
            Text(label)
                .font(StreakTypography.labelMedium)
                .foregroundColor(StreakColors.secondaryText)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreakAnimations.easeInOut.delay(delay + 0.2), value: isAnimating)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StreakSpacing.lg)
        .padding(.horizontal, StreakSpacing.md)
    }
} 
