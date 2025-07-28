import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: HomeView.Tab
    let onCreateHabit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.93, green: 0.93, blue: 0.94)) // #ECECEF
                .frame(height: 1)
            HStack {
                tabBarItem(icon: selectedTab == .home ? "Icon-home-filled" : "Icon-home-outlined", title: "Home", tab: .home)
                tabBarItem(icon: selectedTab == .habits ? "Icon-book-filled" : "Icon-book-outlined", title: "Habits", tab: .habits)
                tabBarItem(icon: selectedTab == .progress ? "Icon-chart-filled" : "Icon-chart-outlined", title: "Progress", tab: .progress)
                tabBarItem(icon: selectedTab == .more ? "Icon-more-filled" : "Icon-more-outlined", title: "More", tab: .more)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
    }
    
    private func tabBarItem(icon: String, title: String, tab: HomeView.Tab) -> some View {
        let selectedColor = Color(red: 0.10, green: 0.10, blue: 0.10) // #191919
        return Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(selectedTab == tab ? selectedColor : Color(red: 0.29, green: 0.32, blue: 0.44))
                Text(title)
                    .font(.appLabelSmallEmphasised)
                    .lineLimit(1)
                    .foregroundColor(selectedTab == tab ? selectedColor : Color(red: 0.29, green: 0.32, blue: 0.44))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 
