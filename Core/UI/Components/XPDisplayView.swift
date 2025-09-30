import SwiftUI

// MARK: - AnyShape Helper
struct AnyShape: Shape, @unchecked Sendable {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}

/// A reusable component for displaying XP information
struct XPDisplayView: View {
    let xp: Int
    let isAnimated: Bool
    let style: XPStyle
    
    @State private var animatedXP: Int = 0
    
    init(xp: Int, isAnimated: Bool = false, style: XPStyle = .compact) {
        self.xp = xp
        self.isAnimated = isAnimated
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: style.spacing) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(style.iconFont)
            
            Text("\(isAnimated ? animatedXP : xp) XP")
                .font(style.textFont)
                .foregroundColor(style.textColor)
                .fontWeight(style.fontWeight)
        }
        .padding(style.padding)
        .background(style.background)
        .overlay(style.overlay)
        .clipShape(style.clipShape)
        .onAppear {
            if isAnimated {
                animateXP()
            }
        }
    }
    
    private func animateXP() {
        let steps = 20
        let stepSize = max(1, xp / steps)
        let duration = 1.0
        let stepDuration = duration / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    animatedXP = min(step * stepSize, xp)
                }
            }
        }
    }
}

// MARK: - XP Display Styles
enum XPStyle {
    case compact
    case prominent
    case minimal
    case celebration
    
    var spacing: CGFloat {
        switch self {
        case .compact: return 4
        case .prominent: return 8
        case .minimal: return 2
        case .celebration: return 8
        }
    }
    
    var iconFont: Font {
        switch self {
        case .compact: return .caption
        case .prominent: return .title3
        case .minimal: return .caption2
        case .celebration: return .title2
        }
    }
    
    var textFont: Font {
        switch self {
        case .compact: return .caption
        case .prominent: return .title3
        case .minimal: return .caption2
        case .celebration: return .appTitleMedium
        }
    }
    
    var textColor: Color {
        switch self {
        case .compact: return .primary
        case .prominent: return .primary
        case .minimal: return .secondary
        case .celebration: return .yellow
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .compact: return .medium
        case .prominent: return .semibold
        case .minimal: return .regular
        case .celebration: return .bold
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .compact: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        case .prominent: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .minimal: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        case .celebration: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        }
    }
    
    var background: some View {
        switch self {
        case .compact:
            return AnyView(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
        case .prominent:
            return AnyView(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
        case .minimal:
            return AnyView(Color.clear)
        case .celebration:
            return AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.6))
            )
        }
    }
    
    var overlay: some View {
        switch self {
        case .compact, .prominent, .minimal:
            return AnyView(Color.clear)
        case .celebration:
            return AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.yellow.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    var clipShape: AnyShape {
        switch self {
        case .compact, .prominent, .celebration:
            return AnyShape(RoundedRectangle(cornerRadius: 8))
        case .minimal:
            return AnyShape(Rectangle())
        }
    }
}

// MARK: - XP Badge for Navigation/Headers
struct XPBadge: View {
    @ObservedObject var xpManager = XPManager.shared
    
    var body: some View {
        XPDisplayView(
            xp: xpManager.userProgress.totalXP,
            isAnimated: false,
            style: .compact
        )
    }
}

// MARK: - Daily XP Progress
struct DailyXPProgress: View {
    @ObservedObject var xpManager = XPManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today's XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(xpManager.userProgress.dailyXP)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Simple progress bar (could be enhanced with daily XP goals)
            if xpManager.userProgress.dailyXP > 0 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                    
                    Text("Great job today!")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        XPDisplayView(xp: 1250, style: .compact)
        XPDisplayView(xp: 75, style: .prominent)
        XPDisplayView(xp: 25, style: .minimal)
        XPDisplayView(xp: 150, style: .celebration)
        
        Divider()
        
        XPBadge()
        DailyXPProgress()
    }
    .padding()
}
