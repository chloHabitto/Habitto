import SwiftUI
import UIKit

struct TabBarView: View {
  // MARK: Internal

  @Binding var selectedTab: Tab

  let onCreateHabit: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Vacation mode banner
      if VacationManager.shared.isActive {
        HStack(spacing: 6) {
          Image("Icon-Vacation_Filled")
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundColor(.blue)
          Text("Vacation Mode")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .frame(maxWidth: .infinity)
      }

      Rectangle()
        .fill(.outline3)
        .frame(height: 1)
      HStack {
        tabBarItem(
          icon: selectedTab == .home ? "Icon-home-filled" : "Icon-home-outlined",
          title: "Home",
          tab: .home)
        tabBarItem(
          icon: selectedTab == .progress ? "Icon-chart-filled" : "Icon-chart-outlined",
          title: "Progress",
          tab: .progress)
        tabBarItem(
          icon: selectedTab == .habits ? "Icon-book-filled" : "Icon-book-outlined",
          title: "Habits",
          tab: .habits)
        tabBarItem(
          icon: selectedTab == .more ? "Icon-more-filled" : "Icon-more-outlined",
          title: "More",
          tab: .more)
      }
      .padding(.vertical, 2)
      .padding(.horizontal, 8)
      .background(Color.surfaceTabBar.ignoresSafeArea(edges: .bottom))
    }
    .onAppear {
      // Check if running in dark mode
      let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
      print("🔍 TAB BAR DEBUG - System is in dark mode: \(isDarkMode)")
      
      // Check UIColor resolution
      if let activeUIColor = UIColor(named: "appBottomeNavIcon_Active") {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        activeUIColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        print("🔍 TAB BAR DEBUG - Active UIColor RGB: R=\(r), G=\(g), B=\(b)")
      } else {
        print("🔍 TAB BAR DEBUG - ⚠️ Active UIColor 'appBottomeNavIcon_Active' NOT FOUND!")
      }
      
      if let inactiveUIColor = UIColor(named: "appBottomeNavIcon_Inactive") {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        inactiveUIColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        print("🔍 TAB BAR DEBUG - Inactive UIColor RGB: R=\(r), G=\(g), B=\(b)")
      } else {
        print("🔍 TAB BAR DEBUG - ⚠️ Inactive UIColor 'appBottomeNavIcon_Inactive' NOT FOUND!")
      }
      
      // Force resolve with dark trait
      let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
      if let activeUIColor = UIColor(named: "appBottomeNavIcon_Active") {
        let resolvedColor = activeUIColor.resolvedColor(with: darkTraits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolvedColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        print("🔍 TAB BAR DEBUG - Active DARK MODE RGB: R=\(r), G=\(g), B=\(b)")
      }
      
      if let inactiveUIColor = UIColor(named: "appBottomeNavIcon_Inactive") {
        let resolvedColor = inactiveUIColor.resolvedColor(with: darkTraits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolvedColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        print("🔍 TAB BAR DEBUG - Inactive DARK MODE RGB: R=\(r), G=\(g), B=\(b)")
      }
    }
  }

  // MARK: Private

  private func tabBarItem(icon: String, title: String, tab: Tab) -> some View {
    Button(action: {
      // Add haptic feedback when tab is selected
      UISelectionFeedbackGenerator().selectionChanged()
      selectedTab = tab
    }) {
      VStack(spacing: 4) {
        Image(icon)
          .resizable()
          .renderingMode(.template)
          .frame(width: 24, height: 24)
          .foregroundColor(selectedTab == tab ? ColorTokens.bottomNavIconActive : ColorTokens.bottomNavIconInactive)
        Text(title)
          .font(.appLabelSmallEmphasised)
          .lineLimit(1)
          .foregroundColor(selectedTab == tab ? .primary : .text03)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 10)
      .padding(.bottom, 8)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
