import SwiftUI

struct ProgressSelectorComponents: View {
  // MARK: Internal

  let selectedHabitType: HabitType
  let selectedPeriod: TimePeriod
  let habits: [Habit]
  let onHabitTypeChanged: (HabitType) -> Void
  let onPeriodChanged: (TimePeriod) -> Void

  var body: some View {
    VStack(spacing: 0) {
      // MARK: - Habit Type Selector

      habitTypeSelector
        .padding(.top, 2)
        .padding(.bottom, 8)

      // MARK: - Period Selector

      periodSelector
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }
  }

  // MARK: Private

  private var periodStats: [(String, TimePeriod?)] {
    [
      ("Today", .today),
      ("Week", .week),
      ("Year", .year),
      ("All", .all)
    ]
  }

  private var habitTypeSelector: some View {
    UnifiedTabBarView(
      tabs: TabItem.createHabitTypeTabs(
        buildingCount: habits.filter { $0.habitType == .formation }.count,
        breakingCount: habits.filter { $0.habitType == .breaking }.count),
      selectedIndex: selectedHabitType == .formation ? 0 : 1,
      style: .underline)
    { index in
      onHabitTypeChanged(index == 0 ? .formation : .breaking)
    }
  }

  private var periodSelector: some View {
    UnifiedTabBarView(
      tabs: TabItem.createPeriodTabs(),
      selectedIndex: periodStats.firstIndex { $0.1 == selectedPeriod } ?? 0,
      style: .pill)
    { index in
      if let period = periodStats[index].1 {
        onPeriodChanged(period)
      }
    }
  }
}
