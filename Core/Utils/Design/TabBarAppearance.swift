import SwiftUI
import UIKit

enum TabBarAppearance {
  static func configure() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    
    // Background color (use surfaceTabBar)
    appearance.backgroundColor = UIColor(named: "appSurfaceTabBar")
    
    // Selected state
    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(named: "appBottomeNavIcon_Active")
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appBottomeNavIcon_Active") ?? .label
    ]
    
    // Normal/unselected state
    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(named: "appBottomeNavIcon_Inactive")
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(named: "appBottomeNavIcon_Inactive") ?? .secondaryLabel
    ]
    
    // Apply to all tab bars
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }
}

