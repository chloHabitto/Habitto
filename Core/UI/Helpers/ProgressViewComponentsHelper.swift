import SwiftUI

class ProgressViewComponentsHelper {
  // MARK: - Today's Progress Container

  static func todaysProgressContainer(habits: [Habit]) -> some View {
    Group {
      if !habits.isEmpty {
        VStack(alignment: .leading, spacing: 20) {
          ProgressChartComponents.ProgressCard(
            title: "Today's Goal Progress",
            subtitle: "Great progress! Keep building your habits!",
            progress: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits),
            progressRingSize: 52)
        }
        .padding(.horizontal, 20)
      }
    }
  }

  // MARK: - Overall Progress Header

  static func overallProgressHeader(
    selectedHabit: Habit?,
    onTap: @escaping () -> Void) -> some View
  {
    Button(action: onTap) {
      HStack(spacing: 0) {
        if let selectedHabit {
          HabitIconView(habit: selectedHabit)
            .frame(width: 38, height: 54)
        } else {
          ZStack {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.primary.opacity(0.15))
              .frame(width: 30, height: 30)

            Image(systemName: "chart.bar.fill")
              .font(.system(size: 14))
              .foregroundColor(.primary)
          }
          .frame(width: 38, height: 54)
        }

        Spacer()
          .frame(width: 8)

        Text(selectedHabit?.name ?? "Overall")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.onPrimaryContainer)

        Spacer()
          .frame(width: 12)

        Image(systemName: "chevron.down")
          .font(.appLabelMedium)
          .foregroundColor(.primaryFocus)

        Spacer()
      }
    }
    .buttonStyle(PlainButtonStyle())
    .padding(.horizontal, 20)
  }

  // MARK: - Calendar Header

  static func calendarHeader(
    monthYearString: String,
    isCurrentMonth: Bool,
    isTodayInCurrentMonth: Bool,
    onTodayTap: @escaping () -> Void) -> some View
  {
    HStack {
      Text(monthYearString)
        .font(.appTitleMedium)
        .foregroundColor(.text01)
        .id("month-header-\(monthYearString)")

      Spacer()

      if !isCurrentMonth || !isTodayInCurrentMonth {
        Button(action: onTodayTap) {
          HStack(spacing: 4) {
            Image(.iconReplay)
              .resizable()
              .frame(width: 12, height: 12)
              .foregroundColor(.primaryFocus)
            Text("Today")
              .font(.appLabelMedium)
              .foregroundColor(.primaryFocus)
          }
          .padding(.leading, 12)
          .padding(.trailing, 8)
          .padding(.top, 4)
          .padding(.bottom, 4)
          .overlay(
            RoundedRectangle(cornerRadius: .infinity)
              .stroke(.primaryFocus, lineWidth: 1))
        }
      }
    }
    .padding(.bottom, 16)
  }

  // MARK: - Calendar Container

  static func calendarContainer(
    monthYearString: String,
    firstDayOfMonth: Int,
    daysInMonth: Int,
    currentDate: Date,
    getDayProgress: @escaping (Int) -> Double,
    onDayTap: @escaping (Int) -> Void,
    onSwipeGesture: @escaping (DragGesture.Value) -> Void) -> some View
  {
    VStack(spacing: 12) {
      CalendarGridComponents.WeekdayHeader()

      CalendarGridComponents.CalendarGrid(
        firstDayOfMonth: firstDayOfMonth,
        daysInMonth: daysInMonth,
        currentDate: currentDate,
        selectedDate: Date(),
        getDayProgress: getDayProgress,
        onDayTap: onDayTap)
        .frame(minHeight: 200)
    }
    .padding(20)
    .background(Color.surface)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.outline3, lineWidth: 1))
    .padding(.horizontal, 20)
    .id("calendar-container-\(monthYearString)")
    .transition(.asymmetric(
      insertion: .move(edge: .trailing).combined(with: .opacity),
      removal: .move(edge: .leading).combined(with: .opacity)))
    .simultaneousGesture(
      DragGesture()
        .onChanged { value in
          if abs(value.translation.width) > abs(value.translation.height) {
            // Horizontal swipe detected - prevent vertical scrolling interference
          }
        }
        .onEnded(onSwipeGesture))
  }

  // MARK: - Performance Overview Title

  static func performanceOverviewTitle(
    selectedHabitType: HabitType,
    selectedPeriod: TimePeriod) -> String
  {
    switch selectedHabitType {
    case .formation:
      switch selectedPeriod {
      case .today:
        "Today's Building Habits"
      case .week:
        "This Week's Building Habits"
      case .year:
        "This Year's Building Habits"
      case .all:
        "All-Time Building Habits"
      }

    case .breaking:
      switch selectedPeriod {
      case .today:
        "Today's Reduction Progress"
      case .week:
        "This Week's Reduction Progress"
      case .year:
        "This Year's Reduction Progress"
      case .all:
        "All-Time Reduction Progress"
      }
    }
  }

  // MARK: - Empty State Messages

  static func emptyStateMessage(for habitType: HabitType) -> String {
    switch habitType {
    case .formation:
      "No habit building data for this period"
    case .breaking:
      "No habit breaking data for this period"
    }
  }

  static func goalEmptyStateMessage(for habitType: HabitType) -> String {
    switch habitType {
    case .formation:
      "No goal data for this period"
    case .breaking:
      "No reduction data for this period"
    }
  }

  static func insightEmptyStateMessage(for habitType: HabitType) -> String {
    switch habitType {
    case .formation:
      "No habit building data for this period"
    case .breaking:
      "No habit breaking data for this period"
    }
  }

  // MARK: - Goal Achievement Title

  static func goalAchievementTitle(
    selectedHabitType: HabitType,
    selectedPeriod: TimePeriod) -> String
  {
    switch selectedHabitType {
    case .formation:
      switch selectedPeriod {
      case .today:
        "Today's Goal Achievement"
      case .week:
        "This Week's Goal Achievement"
      case .year:
        "This Year's Goal Achievement"
      case .all:
        "All-Time Goal Achievement"
      }

    case .breaking:
      switch selectedPeriod {
      case .today:
        "Today's Reduction Analysis"
      case .week:
        "This Week's Reduction Analysis"
      case .year:
        "This Year's Reduction Analysis"
      case .all:
        "All-Time Reduction Analysis"
      }
    }
  }

  // MARK: - Dynamic Insight Helpers

  static func getBuildingInsightTitle(for period: TimePeriod) -> String {
    switch period {
    case .today:
      "Your best habit today"
    case .week:
      "Your best habit this week"
    case .year:
      "Your best habit this year"
    case .all:
      "Your best habit overall"
    }
  }

  static func getBuildingInsightDescription(
    for habit: HabitProgress,
    period: TimePeriod) -> String
  {
    switch period {
    case .all,
         .today,
         .week,
         .year:
      "\(habit.habit.name) (\(Int(habit.completionPercentage))% completion)"
    }
  }

  static func getBreakingInsightTitle(for period: TimePeriod) -> String {
    switch period {
    case .today:
      "Best reduction today"
    case .week:
      "You avoided sugary drinks 6/7 days this week"
    case .year:
      "Best reduction this year"
    case .all:
      "Best reduction overall"
    }
  }

  static func getBreakingInsightDescription(
    for habit: HabitProgress,
    period: TimePeriod) -> String
  {
    switch period {
    case .today:
      return "\(habit.habit.name) (\(Int(habit.completionPercentage))% reduction success)"

    case .week:
      let daysAvoided = Int((habit.completionPercentage / 100.0) * 7.0)
      return "\(habit.habit.name) (\(daysAvoided)/7 days avoided)"

    case .all,
         .year:
      return "\(habit.habit.name) (\(Int(habit.completionPercentage))% reduction success)"
    }
  }
}
