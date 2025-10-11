import SwiftUI

// MARK: - ProgressOverviewCharts

struct ProgressOverviewCharts: View {
  let selectedHabitType: HabitType
  let selectedPeriod: TimePeriod
  let cachedHabitsWithProgress: [HabitProgress]

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text("Progress Overview")
          .font(.appTitleLarge)
          .fontWeight(.bold)
          .foregroundColor(.text01)

        Spacer()

        Image(systemName: "info.circle")
          .font(.system(size: 16))
          .foregroundColor(.text06)
          .help("Shows your overall progress trends for this period")
      }

      if cachedHabitsWithProgress.isEmpty {
        EmptyStateView(
          icon: selectedHabitType == .formation
            ? "chart.line.uptrend.xyaxis"
            : "chart.line.downtrend.xyaxis",
          message: "No progress data for this period")
      } else {
        VStack(spacing: 16) {
          // Overall Progress Chart
          OverallProgressChart()

          // Success Rate Chart
          SuccessRateChart()
        }
      }
    }
  }
}

// MARK: - OverallProgressChart

struct OverallProgressChart: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Overall Progress")
        .font(.appTitleMedium)
        .foregroundColor(.text01)

      // Placeholder for progress chart
      RoundedRectangle(cornerRadius: 12)
        .fill(.surface)
        .frame(height: 200)
        .overlay(
          VStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
              .font(.system(size: 40))
              .foregroundColor(.primary)
            Text("Progress Chart")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
          })
    }
  }
}

// MARK: - SuccessRateChart

struct SuccessRateChart: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Success Rate")
        .font(.appTitleMedium)
        .foregroundColor(.text01)

      // Placeholder for success rate chart
      RoundedRectangle(cornerRadius: 12)
        .fill(.surface)
        .frame(height: 150)
        .overlay(
          VStack {
            Image(systemName: "chart.pie")
              .font(.system(size: 40))
              .foregroundColor(.primary)
            Text("Success Rate Chart")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
          })
    }
  }
}
