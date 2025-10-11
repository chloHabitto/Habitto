import SwiftUI

// MARK: - GoalAchievementSection

struct GoalAchievementSection: View {
  let monthlyGoalsMet: Int
  let monthlyTotalGoals: Int
  let monthlyGoalsMetPercentage: Double
  let averageDailyProgress: Double
  let weekOverWeekTrendColor: Color
  let weekOverWeekTrendIcon: String
  let weekOverWeekTrendText: String
  let weekOverWeekTrendDescription: String

  var body: some View {
    VStack(spacing: 16) {
      // Section header
      HStack {
        Text("Goal Achievement")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.onPrimaryContainer)
        Spacer()
      }
      .padding(.horizontal, 20)

      // Goal achievement cards
      VStack(spacing: 12) {
        // Monthly Goals Met
        SimpleGoalAchievementCard(
          icon: "target",
          iconColor: Color.purple,
          title: "Monthly Goals Met",
          mainText: "\(monthlyGoalsMet) of \(monthlyTotalGoals) targets",
          subtitle: "\(Int(monthlyGoalsMetPercentage * 100))% achievement rate",
          accentColor: Color.purple)

        // Average Daily Progress
        SimpleGoalAchievementCard(
          icon: "chart.line.uptrend.xyaxis",
          iconColor: Color.blue,
          title: "Average Daily Progress",
          mainText: "\(Int(averageDailyProgress * 100))% completion",
          subtitle: "Typical daily performance",
          accentColor: Color.blue)

        // Week-over-Week Comparison
        SimpleGoalAchievementCard(
          icon: weekOverWeekTrendIcon,
          iconColor: weekOverWeekTrendColor,
          title: "Week-over-Week",
          mainText: weekOverWeekTrendText,
          subtitle: weekOverWeekTrendDescription,
          accentColor: weekOverWeekTrendColor)
      }
      .padding(.horizontal, 20)
    }
  }
}

// MARK: - SimpleGoalAchievementCard

struct SimpleGoalAchievementCard: View {
  let icon: String
  let iconColor: Color
  let title: String
  let mainText: String
  let subtitle: String
  let accentColor: Color

  var body: some View {
    HStack(spacing: 16) {
      // Icon
      ZStack {
        Circle()
          .fill(iconColor.opacity(0.1))
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 16))
          .foregroundColor(iconColor)
      }

      // Goal details
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.appLabelSmall)
          .foregroundColor(.text02)

        Text(mainText)
          .font(.appBodyMedium)
          .foregroundColor(.text01)

        Text(subtitle)
          .font(.appLabelSmall)
          .foregroundColor(accentColor)
      }

      Spacer()
    }
    .padding(16)
    .background(Color.surface)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.outline3, lineWidth: 1))
  }
}
