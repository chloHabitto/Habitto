import SwiftUI
import UIKit

// MARK: - TabBarAppearanceModifier

/// View modifier that ensures custom tab bar colors are applied to SwiftUI TabView
/// Uses the image-based approach: bakes unselected color into image with .alwaysOriginal,
/// while keeping selected as .alwaysTemplate so SwiftUI's .tint() applies
struct TabBarAppearanceModifier: ViewModifier {
  @Environment(\.colorScheme) var colorScheme
  
  func body(content: Content) -> some View {
    content
      .tint(Color("appBottomeNavIcon_Active")) // Selected color via SwiftUI
      .onAppear {
        configureTabBarAppearance()
      }
      .onChange(of: colorScheme) { _, _ in
        // Reapply when theme changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          configureTabBarAppearance()
        }
      }
  }
  
  private func configureTabBarAppearance() {
    guard let unselectedColor = UIColor(named: "appBottomeNavIcon_Inactive"),
          let selectedColor = UIColor(named: "appBottomeNavIcon_Active"),
          let unselectedTextColor = UIColor(named: "appText03"),
          let selectedTextColor = UIColor(named: "appPrimary") else {
      print("❌ [TAB_BAR] Failed to load color assets")
      return
    }
    
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    
    // Text colors work fine via appearance
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: unselectedTextColor
    ]
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: selectedTextColor
    ]
    
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    
    // Find and configure tab bar items with the image trick
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.configureTabBarItemImages(
        unselectedColor: unselectedColor,
        selectedColor: selectedColor
      )
    }
  }
  
  private func configureTabBarItemImages(unselectedColor: UIColor, selectedColor: UIColor) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
    
    for window in windowScene.windows {
      findAndConfigureTabBar(in: window, unselectedColor: unselectedColor, selectedColor: selectedColor)
    }
  }
  
  private func findAndConfigureTabBar(in view: UIView, unselectedColor: UIColor, selectedColor: UIColor) {
    if let tabBar = view as? UITabBar {
      print("🎨 [TAB_BAR] Found UITabBar with \(tabBar.items?.count ?? 0) items")
      
      tabBar.items?.enumerated().forEach { index, item in
        print("🎨 [TAB_BAR] Configuring item \(index): \(item.title ?? "no title")")
        
        if let originalImage = item.image {
          // Unselected: Bake the color in with .alwaysOriginal
          let unselectedImage = originalImage
            .withTintColor(unselectedColor, renderingMode: .alwaysOriginal)
          
          // Selected: Use template so tint color applies
          let selectedImage = originalImage
            .withRenderingMode(.alwaysTemplate)
          
          item.image = unselectedImage
          item.selectedImage = selectedImage
          
          print("🎨 [TAB_BAR] ✅ Applied colors to item \(index)")
        }
      }
      
      // Force refresh
      tabBar.setNeedsLayout()
      tabBar.layoutIfNeeded()
    }
    
    for subview in view.subviews {
      findAndConfigureTabBar(in: subview, unselectedColor: unselectedColor, selectedColor: selectedColor)
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
