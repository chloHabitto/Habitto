import SwiftUI

// MARK: - AnyShape

struct AnyShape: Shape, @unchecked Sendable {
  // MARK: Lifecycle

  init(_ shape: some Shape) {
    self._path = shape.path(in:)
  }

  // MARK: Internal

  func path(in rect: CGRect) -> Path {
    _path(rect)
  }

  // MARK: Private

  private let _path: (CGRect) -> Path
}

// MARK: - XPDisplayView

/// A reusable component for displaying XP information
struct XPDisplayView: View {
  // MARK: Lifecycle

  init(xp: Int, isAnimated: Bool = false, style: XPStyle = .compact) {
    self.xp = xp
    self.isAnimated = isAnimated
    self.style = style
  }

  // MARK: Internal

  let xp: Int
  let isAnimated: Bool
  let style: XPStyle

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

  // MARK: Private

  @State private var animatedXP = 0

  private func animateXP() {
    let steps = 20
    let stepSize = max(1, xp / steps)
    let duration = 1.0
    let stepDuration = duration / Double(steps)

    for step in 0 ... steps {
      DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
        withAnimation(.easeOut(duration: stepDuration)) {
          animatedXP = min(step * stepSize, xp)
        }
      }
    }
  }
}

// MARK: - XPStyle

enum XPStyle {
  case compact
  case prominent
  case minimal
  case celebration

  // MARK: Internal

  var spacing: CGFloat {
    switch self {
    case .compact: 4
    case .prominent: 8
    case .minimal: 2
    case .celebration: 8
    }
  }

  var iconFont: Font {
    switch self {
    case .compact: .caption
    case .prominent: .title3
    case .minimal: .caption2
    case .celebration: .title2
    }
  }

  var textFont: Font {
    switch self {
    case .compact: .caption
    case .prominent: .title3
    case .minimal: .caption2
    case .celebration: .appTitleMedium
    }
  }

  var textColor: Color {
    switch self {
    case .compact: .primary
    case .prominent: .primary
    case .minimal: .secondary
    case .celebration: .yellow
    }
  }

  var fontWeight: Font.Weight {
    switch self {
    case .compact: .medium
    case .prominent: .semibold
    case .minimal: .regular
    case .celebration: .bold
    }
  }

  var padding: EdgeInsets {
    switch self {
    case .compact: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    case .prominent: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    case .minimal: EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
    case .celebration: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    }
  }

  var clipShape: AnyShape {
    switch self {
    case .celebration,
         .compact,
         .prominent:
      AnyShape(RoundedRectangle(cornerRadius: 8))
    case .minimal:
      AnyShape(Rectangle())
    }
  }

  var background: some View {
    switch self {
    case .compact:
      AnyView(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.secondary.opacity(0.1)))

    case .prominent:
      AnyView(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.yellow.opacity(0.1))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.yellow.opacity(0.3), lineWidth: 1)))

    case .minimal:
      AnyView(Color.clear)

    case .celebration:
      AnyView(
        RoundedRectangle(cornerRadius: 20)
          .fill(.black.opacity(0.6)))
    }
  }

  var overlay: some View {
    switch self {
    case .compact,
         .minimal,
         .prominent:
      AnyView(Color.clear)
    case .celebration:
      AnyView(
        RoundedRectangle(cornerRadius: 20)
          .stroke(.yellow.opacity(0.3), lineWidth: 1))
    }
  }
}

// MARK: - XPBadge

struct XPBadge: View {
  // ✅ FIX: Direct singleton access as computed property - @Observable tracks reads automatically
  private var xpManager: XPManager { XPManager.shared }

  var body: some View {
    XPDisplayView(
      xp: xpManager.totalXP,
      isAnimated: false,
      style: .compact)
  }
}

// MARK: - DailyXPProgress

struct DailyXPProgress: View {
  // ✅ FIX: Direct singleton access as computed property - @Observable tracks reads automatically
  private var xpManager: XPManager { XPManager.shared }

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
        .fill(Color.secondary.opacity(0.05)))
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
