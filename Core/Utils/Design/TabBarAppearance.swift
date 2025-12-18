import SwiftUI
import UIKit

enum TabBarAppearance {
  static func configure() {
    // Load colors with validation
    guard let activeColor = UIColor(named: "appBottomeNavIcon_Active"),
          let inactiveColor = UIColor(named: "appBottomeNavIcon_Inactive"),
          let backgroundColor = UIColor(named: "appSurfaceTabBar") else {
      print("⚠️ TabBarAppearance: Failed to load semantic colors!")
      return
    }
    
    // Debug: Print loaded colors
    #if DEBUG
    print("✅ TabBarAppearance: Active color loaded: \(activeColor)")
    print("✅ TabBarAppearance: Inactive color loaded: \(inactiveColor)")
    #endif
    
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = backgroundColor
    
    // Configure ALL layout appearances (stacked, inline, compactInline)
    configureItemAppearance(appearance.stackedLayoutAppearance, activeColor: activeColor, inactiveColor: inactiveColor)
    configureItemAppearance(appearance.inlineLayoutAppearance, activeColor: activeColor, inactiveColor: inactiveColor)
    configureItemAppearance(appearance.compactInlineLayoutAppearance, activeColor: activeColor, inactiveColor: inactiveColor)
    
    // Apply to tab bar
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    
    // iOS 15+ also needs this for when content scrolls under tab bar
    if #available(iOS 15.0, *) {
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
  }
  
  private static func configureItemAppearance(_ itemAppearance: UITabBarItemAppearance, activeColor: UIColor, inactiveColor: UIColor) {
    // Selected state
    itemAppearance.selected.iconColor = activeColor
    itemAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
    
    // Normal/unselected state  
    itemAppearance.normal.iconColor = inactiveColor
    itemAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
    
    // Disabled state (optional but good to have)
    itemAppearance.disabled.iconColor = inactiveColor.withAlphaComponent(0.5)
    itemAppearance.disabled.titleTextAttributes = [.foregroundColor: inactiveColor.withAlphaComponent(0.5)]
  }
}
