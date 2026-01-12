import SwiftUI

// MARK: - ScrollOffsetPreferenceKey

/// Shared PreferenceKey for tracking scroll offset across the app.
/// Used by WhiteSheetContainer and HabitDetailView for scroll-responsive header behavior.
struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
