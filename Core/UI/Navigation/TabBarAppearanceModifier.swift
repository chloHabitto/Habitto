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
    
    // Also apply to existing tab bars in the window hierarchy
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        windowScene.windows.forEach { window in
          findAndConfigureTabBar(in: window)
        }
      }
    }
  }
  
  private func findAndConfigureTabBar(in view: UIView) {
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
    }
    
    for subview in view.subviews {
      findAndConfigureTabBar(in: subview)
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
    // Find and configure tab bar in the view hierarchy
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        windowScene.windows.forEach { window in
          configureTabBar(in: window)
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

