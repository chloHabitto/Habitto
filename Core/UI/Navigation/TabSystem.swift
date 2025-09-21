import SwiftUI

// MARK: - Tab Data Models
struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String?
    let isEnabled: Bool
    let data: Any?
    
    init(title: String, value: String? = nil, isEnabled: Bool = true, data: Any? = nil) {
        self.title = title
        self.value = value
        self.isEnabled = isEnabled
        self.data = data
    }
}

enum TabStyle {
    case underline
    case pill
}

// MARK: - Reusable Tab Bar Component
struct UnifiedTabBarView: View {
    let tabs: [TabItem]
    let selectedIndex: Int
    let style: TabStyle
    let onTabSelected: (Int) -> Void
    let expandToFullWidth: Bool
    
    init(
        tabs: [TabItem],
        selectedIndex: Int,
        style: TabStyle = .underline,
        expandToFullWidth: Bool = false,
        onTabSelected: @escaping (Int) -> Void
    ) {
        self.tabs = tabs
        self.selectedIndex = selectedIndex
        self.style = style
        self.expandToFullWidth = expandToFullWidth
        self.onTabSelected = onTabSelected
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: style == .underline ? 0 : 8) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                if style == .underline {
                    UnderlineTabButton(
                        tab: tab,
                        isSelected: selectedIndex == index,
                        onTap: { onTabSelected(index) }
                    )
                } else {
                    PillTabButton(
                        tab: tab,
                        isSelected: selectedIndex == index,
                        onTap: { onTabSelected(index) }
                    )
                }
            }
            
            if !expandToFullWidth {
                // Spacer for both styles to push tabs to the left (only when not expanding to full width)
                Spacer()
                
                // Additional spacer on the right (only when not expanding to full width)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style == .underline ? Color.white : Color.clear)
        .overlay(
            // Bottom stroke for the entire tab bar - only for underline style
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.outline3)
                    .frame(height: 1)
            }
            .opacity(style == .underline ? 1 : 0)
        )
        .animation(nil, value: selectedIndex)
    }
}

// MARK: - Underline Tab Button
struct UnderlineTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Text(tab.title)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(isSelected ? .primary : .text04)
                    
                    if let value = tab.value {
                        Text(value)
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(isSelected ? .primary : .text04)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
//                .background(.red)
                .overlay(
                    // Bottom stroke - only show for selected tabs
                    VStack {
                        Spacer()
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: 4)
                    }
                    .opacity(isSelected ? 1 : 0) // Only show stroke for selected tabs
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .animation(nil, value: isSelected)
    }
}

// MARK: - Pill Tab Button
struct PillTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tab.title)
                .font(.appBodyMedium)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .onPrimary : .text04)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isSelected ? .primary : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isSelected ? .clear : .outline3, lineWidth: 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Convenience Extensions
extension TabItem {
    static func createStatsTabs(activeCount: Int, inactiveCount: Int) -> [TabItem] {
        return [
            TabItem(title: "Active", value: "\(activeCount)"),
            TabItem(title: "Inactive", value: "\(inactiveCount)")
        ]
    }
    
    static func createHabitTypeTabs(buildingCount: Int, breakingCount: Int) -> [TabItem] {
        return [
            TabItem(title: "Habit Building", value: "\(buildingCount)", data: HabitType.formation),
            TabItem(title: "Habit Breaking", value: "\(breakingCount)", data: HabitType.breaking)
        ]
    }
    
    static func createPeriodTabs() -> [TabItem] {
        return [
            TabItem(title: "Today", data: TimePeriod.today),
            TabItem(title: "Week", data: TimePeriod.week),
            TabItem(title: "Year", data: TimePeriod.year),
            TabItem(title: "All", data: TimePeriod.all)
        ]
    }
    
    static func createHomeStatsTabs(totalCount: Int, undoneCount: Int, doneCount: Int) -> [TabItem] {
        return [
            TabItem(title: "Total", value: "\(totalCount)"),
            TabItem(title: "Undone", value: "\(undoneCount)"),
            TabItem(title: "Done", value: "\(doneCount)")
        ]
    }
} 
