import SwiftUI
import UIKit

// MARK: - TabBarAppearanceModifier

/// View modifier that ensures custom tab bar colors are applied to SwiftUI TabView
/// This fixes the issue where UITabBarAppearance set in app init is sometimes ignored
struct TabBarAppearanceModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        TabBarAppearanceHelper()
      )
      .onAppear {
        // Re-apply appearance when view appears
        applyTabBarAppearance()
      }
  }
  
  private func applyTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
    
    // Unselected state
    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(named: "appBottomeNavIcon_Inactive")
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appText03") ?? .gray
    ]
    
    // Selected state
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(named: "appBottomeNavIcon_Active")
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appPrimary") ?? .systemBlue
    ]
    
    // Apply to global appearance
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    
    // Apply to existing tab bars and fix image rendering mode
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        windowScene.windows.forEach { window in
          findAndConfigureTabBar(in: window, appearance: appearance)
        }
      }
    }
  }
  
  private func findAndConfigureTabBar(in view: UIView, appearance: UITabBarAppearance) {
    if let tabBar = view as? UITabBar {
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
      
      // CRITICAL: Force each tab bar item's image to use template rendering
      // SwiftUI's Label(title:image:) doesn't always set the correct rendering mode
      tabBar.items?.forEach { item in
        if let image = item.image {
          item.image = image.withRenderingMode(.alwaysTemplate)
        }
        if let selectedImage = item.selectedImage {
          item.selectedImage = selectedImage.withRenderingMode(.alwaysTemplate)
        }
      }
    }
    
    for subview in view.subviews {
      findAndConfigureTabBar(in: subview, appearance: appearance)
    }
  }
}

// MARK: - TabBarAppearanceHelper

/// Helper view that uses UIKit introspection to find and configure tab bars
private struct TabBarAppearanceHelper: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    return view
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
    // Multiple attempts to catch the tab bar after SwiftUI finishes layout
    // SwiftUI can take time to fully render the TabView, so we try multiple times
    for delay in [0.1, 0.3, 0.5] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
          windowScene.windows.forEach { window in
            configureTabBar(in: window)
          }
        }
      }
    }
  }
  
  private func configureTabBar(in view: UIView) {
    if let tabBar = view as? UITabBar {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
      
      appearance.stackedLayoutAppearance.normal.iconColor = UIColor(named: "appBottomeNavIcon_Inactive")
      appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
        .foregroundColor: UIColor(named: "appText03") ?? .gray
      ]
      
      appearance.stackedLayoutAppearance.selected.iconColor = UIColor(named: "appBottomeNavIcon_Active")
      appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
        .foregroundColor: UIColor(named: "appPrimary") ?? .systemBlue
      ]
      
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
      
      // CRITICAL: Force template rendering mode on all tab bar item images
      // This ensures UIKit applies the iconColor from UITabBarAppearance
      tabBar.items?.forEach { item in
        if let image = item.image {
          item.image = image.withRenderingMode(.alwaysTemplate)
        }
        if let selectedImage = item.selectedImage {
          item.selectedImage = selectedImage.withRenderingMode(.alwaysTemplate)
        }
      }
    }
    
    for subview in view.subviews {
      configureTabBar(in: subview)
    }
  }
}

// MARK: - View Extension

extension View {
  /// Applies custom tab bar appearance colors to SwiftUI TabView
  /// Use this modifier on your TabView to ensure custom icon and text colors are applied
  func customTabBarAppearance() -> some View {
    modifier(TabBarAppearanceModifier())
  }
}
