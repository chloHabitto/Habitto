import SwiftUI

// MARK: - ToastConstants

/// Constants for toast message positioning and styling
enum ToastConstants {
  /// Bottom padding for toast messages when using native SwiftUI TabView
  /// The native TabView already positions content above the tab bar,
  /// so we only need a small margin from the bottom of the content area.
  static let bottomPadding: CGFloat = 16
}
