import SwiftUI

// MARK: - MascotPlaceholderView

/// Placeholder for mascot: blue circle with eyes. Replace with "mascot-face" asset when available.
struct MascotPlaceholderView: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(Color("appPrimary").opacity(0.9))
        .frame(width: size, height: size)

      HStack(spacing: size * 0.15) {
        Circle()
          .fill(Color.white)
          .frame(width: size * 0.15, height: size * 0.15)
        Circle()
          .fill(Color.white)
          .frame(width: size * 0.15, height: size * 0.15)
      }
      .offset(y: -size * 0.08)
    }
    .accessibilityHidden(true)
  }
}
