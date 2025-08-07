import SwiftUI

// MARK: - Streak Header Components
struct StreakHeaderView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Streak Display
struct MainStreakDisplayView: View {
    let currentStreak: Int
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image("Icon-fire")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.warning, Color("yellow400")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("\(currentStreak) days")
                .font(.appHeadlineMediumEmphasised)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Streak Summary Cards
struct StreakSummaryCardsView: View {
    let bestStreak: Int
    let averageStreak: Int
    
    var body: some View {
        HStack(spacing: 0) {
            StreakCardView(
                icon: "Icon-starBadge",
                iconColor: .warning,
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            Rectangle()
                .fill(.outline)
                .frame(width: 1)
                .frame(height: 60)
            
            StreakCardView(
                icon: "Icon-medalBadge",
                iconColor: Color("yellow400"),
                value: "\(averageStreak) days",
                label: "Average streak"
            )
        }
        .background(.surfaceContainer)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

struct StreakCardView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if icon.hasPrefix("Icon-") {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor)
                } else {
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                }
                
                Text(value)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
            }
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .padding(.horizontal, 12)
    }
}

// MARK: - Progress Tabs
struct ProgressTabsView: View {
    let selectedTab: Int
    let onTabSelected: (Int) -> Void
    
    private let tabs = ["Weekly", "Monthly", "Yearly", "Dummy"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                VStack(spacing: 0) {
                    if index == 3 { // Dummy tab
                        Text(tabs[index])
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.text04)
                            .opacity(0)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Button(action: { onTabSelected(index) }) {
                            Text(tabs[index])
                                .font(.appTitleSmallEmphasised)
                                .foregroundColor(selectedTab == index ? .text03 : .text04)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Rectangle()
                        .fill(selectedTab == index ? .text03 : .divider)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .horizontal)
    }
}

// MARK: - Date Range Selector
struct DateRangeSelectorView: View {
    let weekRangeText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(weekRangeText)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Image(systemName: "chevron.down")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }
}

// MARK: - Calendar Empty State View
struct CalendarEmptyStateView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .font(.appDisplaySmall)
                .foregroundColor(.secondary)
            Text(title)
                .font(.appButtonText2)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.appBodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Heatmap Cell
struct HeatmapCellView: View {
    let intensity: Int
    
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 32, height: 32)
            .overlay(
                Rectangle()
                    .fill(heatmapColor(for: intensity))
                    .frame(width: 24, height: 24)
                    .cornerRadius(6)
            )
    }
    
    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            return .surfaceContainer
        case 1:
            return Color("green500").opacity(0.3)
        case 2:
            return Color("green500").opacity(0.6)
        case 3:
            return Color("green500")
        default:
            return .surfaceContainer
        }
    }
}



// MARK: - Summary Statistics
struct SummaryStatisticsView: View {
    let completionRate: Int
    let bestStreak: Int
    let consistencyRate: Int
    
    var body: some View {
        HStack(spacing: 0) {
            StatisticCardView(value: "\(completionRate)%", label: "Completion")
            
            Rectangle()
                .fill(.outline)
                .frame(width: 1)
                .frame(height: 60)
            
            StatisticCardView(value: "\(bestStreak) days", label: "Best streak")
            
            Rectangle()
                .fill(.outline)
                .frame(width: 1)
                .frame(height: 60)
            
            StatisticCardView(value: "\(consistencyRate)%", label: "Consistency")
        }
        .background(.surfaceContainer)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct StatisticCardView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
    }
} 
