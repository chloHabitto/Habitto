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
  
  static func configureTabBarItems() {
    // This needs to be called after the TabView is rendered
    // We access the UITabBar through the window
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootViewController = window.rootViewController else {
        print("⚠️ TabBarAppearance: Could not find window or root view controller")
        return
      }
      
      // Try to find UITabBarController first (SwiftUI TabView uses this)
      var tabBarController: UITabBarController?
      if let tabBarVC = rootViewController as? UITabBarController {
        tabBarController = tabBarVC
      } else if let navController = rootViewController as? UINavigationController,
                 let tabBarVC = navController.viewControllers.first(where: { $0 is UITabBarController }) as? UITabBarController {
        tabBarController = tabBarVC
      } else {
        // Search through view controller hierarchy
        tabBarController = findTabBarController(in: rootViewController)
      }
      
      if let tabBar = tabBarController?.tabBar {
        configureTabItems(in: tabBar)
      } else if let tabBar = findTabBar(in: rootViewController.view) {
        configureTabItems(in: tabBar)
      } else {
        print("⚠️ TabBarAppearance: Could not find UITabBar")
      }
    }
  }
  
  private static func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
    guard let viewController = viewController else { return nil }
    if let tabBarController = viewController as? UITabBarController {
      return tabBarController
    }
    if let navController = viewController as? UINavigationController {
      for child in navController.viewControllers {
        if let tabBarController = findTabBarController(in: child) {
          return tabBarController
        }
      }
    }
    for child in viewController.children {
      if let tabBarController = findTabBarController(in: child) {
        return tabBarController
      }
    }
    return nil
  }
  
  private static func findTabBar(in view: UIView?) -> UITabBar? {
    guard let view = view else { return nil }
    if let tabBar = view as? UITabBar { return tabBar }
    for subview in view.subviews {
      if let tabBar = findTabBar(in: subview) { return tabBar }
    }
    return nil
  }
  
  private static func configureTabItems(in tabBar: UITabBar) {
    guard let items = tabBar.items, items.count == 4 else {
      print("⚠️ TabBarAppearance: Expected 4 tab items, found \(tabBar.items?.count ?? 0)")
      return
    }
    
    // Home tab
    items[0].image = UIImage(named: "Icon-home-outlined")?.withRenderingMode(.alwaysTemplate)
    items[0].selectedImage = UIImage(named: "Icon-home-filled")?.withRenderingMode(.alwaysTemplate)
    
    // Progress tab
    items[1].image = UIImage(named: "Icon-chart-outlined")?.withRenderingMode(.alwaysTemplate)
    items[1].selectedImage = UIImage(named: "Icon-chart-filled")?.withRenderingMode(.alwaysTemplate)
    
    // Habits tab
    items[2].image = UIImage(named: "Icon-book-outlined")?.withRenderingMode(.alwaysTemplate)
    items[2].selectedImage = UIImage(named: "Icon-book-filled")?.withRenderingMode(.alwaysTemplate)
    
    // More tab
    items[3].image = UIImage(named: "Icon-more-outlined")?.withRenderingMode(.alwaysTemplate)
    items[3].selectedImage = UIImage(named: "Icon-more-filled")?.withRenderingMode(.alwaysTemplate)
    
    print("✅ TabBarAppearance: Tab bar items configured with outlined/filled icons")
  }
}
