import SwiftUI

// MARK: - Progress Chart Components
struct ProgressChartComponents {
    
    // MARK: - Circular Progress Ring
    struct CircularProgressRing: View {
        let progress: Double
        let size: CGFloat
        let lineWidth: CGFloat
        let primaryColor: Color
        let secondaryColor: Color
        let showPercentage: Bool
        let percentageFont: Font
        
        init(
            progress: Double,
            size: CGFloat = 52,
            lineWidth: CGFloat = 8,
            primaryColor: Color = .primary,
            secondaryColor: Color = .primaryContainer,
            showPercentage: Bool = true,
            percentageFont: Font = .appLabelMediumEmphasised
        ) {
            self.progress = progress
            self.size = size
            self.lineWidth = lineWidth
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.showPercentage = showPercentage
            self.percentageFont = percentageFont
        }
        
        var body: some View {
            ZStack {
                // Background circle (unfilled part)
                Circle()
                    .stroke(secondaryColor, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // Progress circle (filled part)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        primaryColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Percentage text
                if showPercentage {
                    VStack(spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(percentageFont)
                            .foregroundColor(.primaryFocus)
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    struct ProgressBar: View {
        let progress: Double
        let height: CGFloat
        let primaryColor: Color
        let secondaryColor: Color
        let showPercentage: Bool
        let cornerRadius: CGFloat
        
        init(
            progress: Double,
            height: CGFloat = 8,
            primaryColor: Color = .primary,
            secondaryColor: Color = .primaryContainer,
            showPercentage: Bool = false,
            cornerRadius: CGFloat = 4
        ) {
            self.progress = progress
            self.height = height
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.showPercentage = showPercentage
            self.cornerRadius = cornerRadius
        }
        
        var body: some View {
            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(secondaryColor)
                        .frame(height: height)
                    
                    // Progress bar
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(primaryColor)
                        .frame(width: max(0, min(1, progress)) * UIScreen.main.bounds.width * 0.8, height: height)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                
                if showPercentage {
                    Text("\(Int(progress * 100))%")
                        .font(.appLabelSmall)
                        .foregroundColor(.text02)
                }
            }
        }
    }
    
    // MARK: - Progress Card
    struct ProgressCard: View {
        let title: String
        let subtitle: String
        let progress: Double
        let progressRingSize: CGFloat
        let showProgressRing: Bool
        let showProgressBar: Bool
        
        init(
            title: String,
            subtitle: String,
            progress: Double,
            progressRingSize: CGFloat = 52,
            showProgressRing: Bool = true,
            showProgressBar: Bool = false
        ) {
            self.title = title
            self.subtitle = subtitle
            self.progress = progress
            self.progressRingSize = progressRingSize
            self.showProgressRing = showProgressRing
            self.showProgressBar = showProgressBar
        }
        
        var body: some View {
            HStack(spacing: 20) {
                // Left side: Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text(subtitle)
                        .font(.appBodySmall)
                        .foregroundColor(.primaryFocus)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side: Progress visualization
                if showProgressRing {
                    CircularProgressRing(
                        progress: progress,
                        size: progressRingSize
                    )
                } else if showProgressBar {
                    ProgressBar(
                        progress: progress,
                        height: 8,
                        showPercentage: true
                    )
                    .frame(width: 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.surfaceDim)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Progress Trend Indicator
    struct ProgressTrendIndicator: View {
        let trend: ProgressTrend
        let value: String
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: trendIcon)
                    .font(.appLabelSmall)
                    .foregroundColor(trendColor)
                
                Text(value)
                    .font(.appLabelSmall)
                    .foregroundColor(trendColor)
            }
        }
        
        private var trendIcon: String {
            switch trend {
            case .improving:
                return "arrow.up.circle.fill"
            case .declining:
                return "arrow.down.circle.fill"
            case .maintaining:
                return "minus.circle.fill"
            }
        }
        
        private var trendColor: Color {
            switch trend {
            case .improving:
                return .green500
            case .declining:
                return .red500
            case .maintaining:
                return .yellow500
            }
        }
    }
    
    // MARK: - Performance Metric Card
    struct PerformanceMetricCard: View {
        let title: String
        let value: String
        let subtitle: String
        let icon: String
        let iconColor: Color
        let backgroundColor: Color
        
        init(
            title: String,
            value: String,
            subtitle: String,
            icon: String,
            iconColor: Color = .primary,
            backgroundColor: Color = .surfaceDim
        ) {
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.icon = icon
            self.iconColor = iconColor
            self.backgroundColor = backgroundColor
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.appTitleLargeEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(title)
                        .font(.appTitleSmall)
                        .foregroundColor(.text02)
                    
                    Text(subtitle)
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                }
            }
            .padding(16)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}
