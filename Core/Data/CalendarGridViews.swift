import SwiftUI
import SwiftData

// MARK: - Helper Functions

private func pluralizeDay(_ count: Int) -> String {
  if count == 0 {
    "0 day"
  } else if count == 1 {
    "1 day"
  } else {
    "\(count) days"
  }
}

// MARK: - HabitIconInlineView

struct HabitIconInlineView: View {
  let habit: Habit

  var body: some View {
    ZStack {
      if habit.icon.hasPrefix("Icon-") {
        Image(habit.icon)
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundColor(habit.color.color)
      } else if habit.icon == "None" {
        RoundedRectangle(cornerRadius: 5)
          .fill(habit.color.color)
          .frame(width: 16, height: 16)
      } else {
        Text(habit.icon)
          .font(.system(size: 12))
      }
    }
  }
}

// MARK: - WeeklyCalendarGridView

struct WeeklyCalendarGridView: View {
  // MARK: Internal

  let userHabits: [Habit]
  let selectedWeekStartDate: Date

  var body: some View {
    Group {
      if userHabits.isEmpty {
        CalendarEmptyStateView(
          title: "No habits yet",
          subtitle: "Create habits to see your progress")
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        VStack(spacing: 0) {
          // Header row with modern styling
          HStack(spacing: 0) {
            Text("")
              .font(.appBodyMediumEmphasised)
              .foregroundColor(.text01)
              .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
              .frame(height: 24)
              .padding(.leading, 16)
              .clipShape(
                UnevenRoundedRectangle(
                  topLeadingRadius: 12,
                  bottomLeadingRadius: 0,
                  bottomTrailingRadius: 0,
                  topTrailingRadius: 0))
              .overlay(
                UnevenRoundedRectangle(
                  topLeadingRadius: 12,
                  bottomLeadingRadius: 0,
                  bottomTrailingRadius: 0,
                  topTrailingRadius: 0)
                  .stroke(Color("appOutline02Variant"), lineWidth: 1))

            ForEach(Array(weeklyDayHeaders.enumerated()), id: \.offset) { index, day in
              Text(day)
                .font(.appLabelMediumEmphasised)
                .foregroundColor(.text05)
                .frame(width: 24, height: 24)
                .clipShape(
                  UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: index == 6 ? 12 : 0))
                .overlay(
                  UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: index == 6 ? 12 : 0)
                    .stroke(Color("appOutline02Variant"), lineWidth: 1))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          // Habit rows - Performance optimization: Lazy loading with modern styling
          LazyVStack(spacing: 0) {
            ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
              HStack(spacing: 0) {
                // Habit name cell with modern styling
                HStack(spacing: 8) {
                  HabitIconInlineView(habit: habit)

                  Text(habit.name)
                    .font(.appLabelLargeEmphasised)
                    .foregroundColor(.text02)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .frame(height: 36)
                .padding(.leading, 8)
                .overlay(
                  Rectangle()
                    .stroke(Color("appOutline02Variant"), lineWidth: 1))

                // Heatmap cells with modern styling
                ForEach(0 ..< 7, id: \.self) { dayIndex in
                  let heatmapData = StreakDataCalculator.getWeeklyHeatmapData(
                    for: habit,
                    dayIndex: dayIndex,
                    weekStartDate: selectedWeekStartDate)

                  // Debug: Print heatmap data for each cell
                  let _ =
                    print(
                      "🔍 WEEKLY GRID DEBUG - Habit '\(habit.name)' | Day \(dayIndex) | Data: \(heatmapData)")

                  HeatmapCellView(
                    intensity: heatmapData.intensity,
                    isScheduled: heatmapData.isScheduled,
                    completionPercentage: heatmapData.completionPercentage,
                    isVacationDay: VacationManager.shared.isActive && VacationManager.shared
                      .isVacationDay(Calendar.current.date(
                        byAdding: .day,
                        value: dayIndex,
                        to: selectedWeekStartDate) ?? selectedWeekStartDate))
                    .frame(width: 24, height: 36)
                    .overlay(
                      Rectangle()
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .id("weekly-habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
            }
          }

          // Total row with modern styling
          HStack(spacing: 0) {
            Text("Total")
              .font(.appLabelMediumEmphasised)
              .foregroundColor(.text05)
              .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
              .frame(height: 32)
              .clipShape(
                UnevenRoundedRectangle(
                  topLeadingRadius: 0,
                  bottomLeadingRadius: 12,
                  bottomTrailingRadius: 0,
                  topTrailingRadius: 0))
              .overlay(
                UnevenRoundedRectangle(
                  topLeadingRadius: 0,
                  bottomLeadingRadius: 12,
                  bottomTrailingRadius: 0,
                  topTrailingRadius: 0)
                  .stroke(Color("appOutline02Variant"), lineWidth: 1))

            ForEach(0 ..< 7, id: \.self) { dayIndex in
              let totalHeatmapData = StreakDataCalculator.getWeeklyTotalHeatmapData(
                dayIndex: dayIndex,
                habits: userHabits,
                weekStartDate: selectedWeekStartDate)

              // Calculate if this day is upcoming (future)
              let calendar = AppDateFormatter.shared.getUserCalendar()
              let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
              let targetDate = calendar
                .date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
              let today = calendar.startOfDay(for: Date())
              let isUpcoming = targetDate > today

              // Debug: Print total heatmap data for each day
              let _ =
                print(
                  "🔍 WEEKLY TOTAL DEBUG - Day \(dayIndex) | Total Data: \(totalHeatmapData) | IsUpcoming: \(isUpcoming)")

              WeeklyTotalEmojiCell(
                completionPercentage: totalHeatmapData.completionPercentage,
                isScheduled: totalHeatmapData.isScheduled,
                isUpcoming: isUpcoming,
                dayIndex: dayIndex,
                weekStartDate: selectedWeekStartDate)
                .frame(width: 24, height: 32)
                .clipShape(
                  UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                    topTrailingRadius: 0))
                .overlay(
                  UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                    topTrailingRadius: 0)
                    .stroke(Color("appOutline02Variant"), lineWidth: 1))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
      }
    }
  }

  // MARK: Private

  private var weeklyDayHeaders: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["S", "M", "T", "W", "T", "F", "S"]
    } else { // Monday
      return ["M", "T", "W", "T", "F", "S", "S"]
    }
  }
}

// MARK: - MonthlyCalendarGridView

struct MonthlyCalendarGridView: View {
  // MARK: Internal

  let userHabits: [Habit]
  let selectedMonth: Date
  let singleHabit: Habit? // Optional: when provided, show only this habit; when nil, show combined view for all habits

  var body: some View {
    Group {
      if userHabits.isEmpty {
        CalendarEmptyStateView(
          title: "No habits yet",
          subtitle: "Create habits to see your monthly progress")
          .frame(maxWidth: .infinity, alignment: .center)
      } else if let singleHabit = singleHabit {
        // Single habit mode: show calendar grid and stats for one habit
        VStack(spacing: 0) {
          // Weekly heatmap table for this habit
          monthlyHeatmapTable(for: singleHabit, isCombined: false)
            .padding(.top, 16)

          // Summary statistics row
          summaryStatisticsView(for: singleHabit)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(
          RoundedRectangle(cornerRadius: 24)
            .fill(.appSurface01)
            .overlay(
              LinearGradient(
                stops: [
                  Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                  Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.08, y: 0.09),
                endPoint: UnitPoint(x: 0.88, y: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 24))
            ))
        .overlay(
          RoundedRectangle(cornerRadius: 24)
            .stroke(Color("appOutline1Variant"), lineWidth: 2))
      } else {
        // Combined mode: show one combined calendar grid and stats for all habits
        VStack(spacing: 0) {
          // Combined header
          HStack(spacing: 8) {
            Text("All habits")
              .font(.appBodyMedium)
              .foregroundColor(.text01)
              .lineLimit(1)
              .truncationMode(.tail)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 12)

          // Combined weekly heatmap table
          monthlyHeatmapTableCombined()

          // Combined summary statistics row
          summaryStatisticsViewCombined()
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(
          RoundedRectangle(cornerRadius: 24)
            .fill(.appSurface01)
            .overlay(
              LinearGradient(
                stops: [
                  Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                  Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.08, y: 0.09),
                endPoint: UnitPoint(x: 0.88, y: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 24))
            ))
        .overlay(
          RoundedRectangle(cornerRadius: 24)
            .stroke(Color("appOutline1Variant"), lineWidth: 2))
      }
    }
//        .padding(.horizontal, 16)
  }

  // MARK: Private

  private var dayHeaders: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["S", "M", "T", "W", "T", "F", "S"]
    } else { // Monday
      return ["M", "T", "W", "T", "F", "S", "S"]
    }
  }

  /// Calculate the number of weeks in the selected month
  private var numberOfWeeksInMonth: Int {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth)
    let startDate = monthInterval?.start ?? selectedMonth
    let endDate = monthInterval?.end ?? selectedMonth

    // Calculate weeks from start of month to end of month
    var currentDate = startDate
    var weekCount = 0

    while currentDate < endDate {
      weekCount += 1
      currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
    }

    return max(1, weekCount) // At least 1 week
  }

  // MARK: - Weekly Heatmap Table

  @ViewBuilder
  private func monthlyHeatmapTable(for habit: Habit, isCombined: Bool) -> some View {
    VStack(spacing: 0) {
      // Header row with day labels
      HStack(spacing: 0) {
        // Empty cell for top-left corner - must match week label cell exactly
        Rectangle()
          .fill(.clear)
          .frame(minWidth: 0, maxWidth: .infinity)
          .frame(height: 24)
          .clipShape(
            UnevenRoundedRectangle(
              topLeadingRadius: 12,
              bottomLeadingRadius: 0,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0))
          .overlay(
            UnevenRoundedRectangle(
              topLeadingRadius: 12,
              bottomLeadingRadius: 0,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

        // Day headers - must match heatmap cells exactly
        ForEach(Array(dayHeaders.enumerated()), id: \.offset) { index, day in
          Text(day)
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.text05)
            .frame(width: 24, height: 24)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Week rows with heatmap cells - calculate actual weeks in the selected month
      ForEach(0 ..< numberOfWeeksInMonth, id: \.self) { weekIndex in
        HStack(spacing: 0) {
          // Week label cell - must match empty corner cell exactly
          Text("Week \(weekIndex + 1)")
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.text05)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .frame(height: 36)
            .overlay(
              Rectangle()
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

          // Week heatmap cells - must match day headers exactly
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let heatmapData = getMonthlyHeatmapDataForHabit(
              habit: habit,
              weekIndex: weekIndex,
              dayIndex: dayIndex)
            HeatmapCellView(
              intensity: heatmapData.intensity,
              isScheduled: heatmapData.isScheduled,
              completionPercentage: heatmapData.completionPercentage)
              .frame(width: 24, height: 36)
              .overlay(
                Rectangle()
                  .stroke(Color("appOutline02Variant"), lineWidth: 1))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      // Total row with rounded bottom corners
      HStack(spacing: 0) {
        Text("Total")
          .font(.appLabelMediumEmphasised)
          .foregroundColor(.text05)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
          .frame(height: 32)
          .clipShape(
            UnevenRoundedRectangle(
              topLeadingRadius: 0,
              bottomLeadingRadius: 12,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0))
          .overlay(
            UnevenRoundedRectangle(
              topLeadingRadius: 0,
              bottomLeadingRadius: 12,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

        ForEach(0 ..< 7, id: \.self) { dayIndex in
          MonthlyTotalEmojiCell(
            habit: habit,
            dayIndex: dayIndex,
            numberOfWeeks: numberOfWeeksInMonth,
            selectedMonth: selectedMonth,
            getMonthlyHeatmapDataForHabit: getMonthlyHeatmapDataForHabit)
            .frame(width: 24, height: 32)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
  }

  @ViewBuilder
  private func monthlyHeatmapTableCombined() -> some View {
    VStack(spacing: 0) {
      // Header row with day labels
      HStack(spacing: 0) {
        // Empty cell for top-left corner - must match week label cell exactly
        Rectangle()
          .fill(.clear)
          .frame(width: 100)
          .frame(height: 24)
          .clipShape(
            UnevenRoundedRectangle(
              topLeadingRadius: 12,
              bottomLeadingRadius: 0,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0))
          .overlay(
            UnevenRoundedRectangle(
              topLeadingRadius: 12,
              bottomLeadingRadius: 0,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

        // Day headers - must match heatmap cells exactly
        ForEach(Array(dayHeaders.enumerated()), id: \.offset) { index, day in
          Text(day)
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.text05)
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 24)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity)

      // Week rows with heatmap cells - calculate actual weeks in the selected month
      ForEach(0 ..< numberOfWeeksInMonth, id: \.self) { weekIndex in
        HStack(spacing: 0) {
          // Week label cell - must match empty corner cell exactly
          Text("Week \(weekIndex + 1)")
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.appText05)
            .frame(width: 100, alignment: .center)
            .frame(height: 36)
            .overlay(
              Rectangle()
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

          // Week heatmap cells - must match day headers exactly
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let heatmapData = getMonthlyHeatmapDataCombined(
              weekIndex: weekIndex,
              dayIndex: dayIndex)
            HeatmapCellView(
              intensity: heatmapData.intensity,
              isScheduled: heatmapData.isScheduled,
              completionPercentage: heatmapData.completionPercentage)
              .frame(minWidth: 0, maxWidth: .infinity)
              .frame(height: 36)
              .overlay(
                Rectangle()
                  .stroke(Color("appOutline02Variant"), lineWidth: 1))
          }
        }
        .frame(maxWidth: .infinity)
      }

      // Total row with rounded bottom corners
      HStack(spacing: 0) {
        Text("Total")
          .font(.appLabelMediumEmphasised)
          .foregroundColor(.text05)
          .frame(width: 100, alignment: .center)
          .frame(height: 32)
          .clipShape(
            UnevenRoundedRectangle(
              topLeadingRadius: 0,
              bottomLeadingRadius: 12,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0))
          .overlay(
            UnevenRoundedRectangle(
              topLeadingRadius: 0,
              bottomLeadingRadius: 12,
              bottomTrailingRadius: 0,
              topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))

        ForEach(0 ..< 7, id: \.self) { dayIndex in
          MonthlyTotalEmojiCellCombined(
            dayIndex: dayIndex,
            numberOfWeeks: numberOfWeeksInMonth,
            selectedMonth: selectedMonth,
            getMonthlyHeatmapDataCombined: getMonthlyHeatmapDataCombined)
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 32)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0)
                        .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 16)
  }

  // MARK: - Helper View Methods

  @ViewBuilder
  private func summaryStatisticsView(for habit: Habit) -> some View {
    HStack(spacing: 0) {
      // Completion percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateHabitCompletionPercentage(for: habit)))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best streak
      VStack(spacing: 4) {
        Text(pluralizeDay(calculateHabitBestStreak(for: habit)))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateHabitConsistency(for: habit)))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  @ViewBuilder
  private func summaryStatisticsViewCombined() -> some View {
    HStack(spacing: 0) {
      // Completion percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateCombinedCompletionPercentage()))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best streak
      VStack(spacing: 4) {
        Text(pluralizeDay(calculateCombinedBestStreak()))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateCombinedConsistency()))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  /// Calculate heatmap data for a specific habit, week, and day in the selected month
  private func getMonthlyHeatmapDataForHabit(
    habit: Habit,
    weekIndex: Int,
    dayIndex: Int) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double)
  {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth

    // Calculate the first day of the week that contains the month start
    // This respects the user's preferred first day of the week setting
    let monthStartWeekday = calendar.component(.weekday, from: monthStart)
    let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
    let firstWeekdayOfMonth = calendar.date(
      byAdding: .day,
      value: -daysFromFirstWeekday,
      to: monthStart) ?? monthStart

    // Calculate the target date based on week and day indices, starting from the first weekday
    let targetDate = calendar.date(
      byAdding: .day,
      value: (weekIndex * 7) + dayIndex,
      to: firstWeekdayOfMonth) ?? monthStart

    // Debug: Print monthly heatmap calculation details
    let dateKey = DateUtils.dateKey(for: targetDate)
    let weekday = calendar.component(.weekday, from: targetDate)
    let weekdayName = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday"
    ][weekday - 1]
    print(
      "🔍 MONTHLY HEATMAP DEBUG - Habit: '\(habit.name)' | Week: \(weekIndex) | Day: \(dayIndex) | Date: \(dateKey) | Weekday: \(weekdayName) | MonthStart: \(DateUtils.dateKey(for: monthStart)) | FirstWeekday: \(DateUtils.dateKey(for: firstWeekdayOfMonth))")

    // Check if the target date is within the selected month
    let monthEnd = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
    if targetDate >= monthEnd {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
    }

    let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: targetDate)
    if !isScheduled {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
    }

    let completionPercentage = StreakDataCalculator.calculateCompletionPercentage(
      for: habit,
      date: targetDate)
    let intensity = if completionPercentage == 0 {
      0
    } else if completionPercentage < 25 {
      1
    } else if completionPercentage < 50 {
      2
    } else {
      3
    }

    return (intensity: intensity, isScheduled: true, completionPercentage: completionPercentage)
  }

  /// Calculate combined heatmap data for all habits, week, and day in the selected month
  private func getMonthlyHeatmapDataCombined(
    weekIndex: Int,
    dayIndex: Int) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double)
  {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth

    // Calculate the first day of the week that contains the month start
    let monthStartWeekday = calendar.component(.weekday, from: monthStart)
    let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
    let firstWeekdayOfMonth = calendar.date(
      byAdding: .day,
      value: -daysFromFirstWeekday,
      to: monthStart) ?? monthStart

    // Calculate the target date based on week and day indices
    let targetDate = calendar.date(
      byAdding: .day,
      value: (weekIndex * 7) + dayIndex,
      to: firstWeekdayOfMonth) ?? monthStart

    // Check if the target date is within the selected month
    let monthEnd = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
    if targetDate >= monthEnd {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
    }

    // Check if any habit is scheduled for this day
    let scheduledHabits = userHabits.filter { StreakDataCalculator.shouldShowHabitOnDate($0, date: targetDate) }
    let isScheduled = !scheduledHabits.isEmpty

    if !isScheduled {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0)
    }

    // Calculate average completion percentage from scheduled habits
    let totalCompletion = scheduledHabits.reduce(0.0) { total, habit in
      total + StreakDataCalculator.calculateCompletionPercentage(for: habit, date: targetDate)
    }
    let averageCompletion = scheduledHabits.isEmpty
      ? 0.0
      : totalCompletion / Double(scheduledHabits.count)

    // Map completion percentage to intensity
    let intensity = if averageCompletion == 0 {
      0
    } else if averageCompletion < 25 {
      1
    } else if averageCompletion < 50 {
      2
    } else {
      3
    }

    return (intensity: intensity, isScheduled: true, completionPercentage: averageCompletion)
  }

  // MARK: - Helper Functions for Summary Statistics

  private func calculateHabitCompletionPercentage(for habit: Habit) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var totalGoal = 0
    var totalCompleted = 0

    // Calculate for the selected month range
    var currentDate = startDate
    while currentDate <= endDate, currentDate <= today {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        let goalAmount = parseGoalAmount(from: habit.goal)
        let progress = habit.getProgress(for: currentDate)
        totalGoal += goalAmount
        totalCompleted += progress
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalGoal == 0 {
      return habit.isCompleted(for: today) ? 100.0 : 0.0
    }

    return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
  }

  private func calculateHabitCompletedDays(for habit: Habit) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var completedDays = 0
    var currentDate = startDate

    while currentDate <= endDate, currentDate <= today {
      if habit.isCompleted(for: currentDate) {
        completedDays += 1
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    return completedDays
  }

  private func calculateHabitConsistency(for habit: Habit) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var scheduledDays = 0
    var completedDays = 0
    var currentDate = startDate

    while currentDate <= endDate, currentDate <= today {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        scheduledDays += 1
        if habit.isCompleted(for: currentDate) {
          completedDays += 1
        }
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if scheduledDays == 0 {
      return 0.0
    }

    return (Double(completedDays) / Double(scheduledDays)) * 100.0
  }

  private func parseGoalAmount(from goalString: String) -> Int {
    StreakDataCalculator.parseGoalAmount(from: goalString)
  }

  private func calculateHabitBestStreak(for habit: Habit) -> Int {
    // ✅ PERSISTENT BEST STREAK: Use bestStreakEver from HabitData if available
    // This ensures best streak survives even if completion records are lost
    if let habitData = getHabitData(for: habit.id) {
      // For calendar view, we still calculate from the selected month range
      // but we ensure bestStreakEver is updated and use it as a minimum
      let calculatedBest = habitData.calculateAndUpdateBestStreak()
      return calculatedBest
    }
    
    // Fallback: Calculate from selected month range if HabitData not available
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var maxStreak = 0
    var currentStreak = 0
    var currentDate = startDate

    while currentDate <= endDate, currentDate <= today {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        if habit.isCompleted(for: currentDate) {
          currentStreak += 1
          maxStreak = max(maxStreak, currentStreak)
        } else {
          currentStreak = 0
        }
      } else {
        // If habit is not scheduled on this day, reset streak
        currentStreak = 0
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    return maxStreak
  }
  
  /// Helper to get HabitData for a habit ID
  private func getHabitData(for habitId: UUID) -> HabitData? {
    do {
      let context = SwiftDataContainer.shared.modelContext
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { $0.id == habitId }
      )
      return try context.fetch(descriptor).first
    } catch {
      return nil
    }
  }

  // MARK: - Combined Statistics Helper Functions

  private func calculateCombinedCompletionPercentage() -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var totalGoal = 0
    var totalCompleted = 0

    // Calculate for all habits in the selected month range
    var currentDate = startDate
    while currentDate <= endDate, currentDate <= today {
      for habit in userHabits {
        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
          let goalAmount = parseGoalAmount(from: habit.goal)
          let progress = habit.getProgress(for: currentDate)
          totalGoal += goalAmount
          totalCompleted += progress
        }
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalGoal == 0 {
      return 0.0
    }

    return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
  }

  private func calculateCombinedConsistency() -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Use selected month range
    let startDate = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let endDate = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth

    var totalScheduledDays = 0
    var totalCompletedDays = 0
    var currentDate = startDate

    while currentDate <= endDate, currentDate <= today {
      var dayScheduled = false
      var dayCompleted = false

      for habit in userHabits {
        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
          dayScheduled = true
          if habit.isCompleted(for: currentDate) {
            dayCompleted = true
            break // At least one habit completed on this day
          }
        }
      }

      if dayScheduled {
        totalScheduledDays += 1
        if dayCompleted {
          totalCompletedDays += 1
        }
      }

      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalScheduledDays == 0 {
      return 0.0
    }

    return (Double(totalCompletedDays) / Double(totalScheduledDays)) * 100.0
  }

  private func calculateCombinedBestStreak() -> Int {
    // Return the maximum best streak across all habits
    return userHabits.map { calculateHabitBestStreak(for: $0) }.max() ?? 0
  }
}

// MARK: - YearlyCalendarGridView

struct YearlyCalendarGridView: View {
  // MARK: Internal

  let userHabits: [Habit]
  let selectedWeekStartDate: Date
  let yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]]
  let isDataLoaded: Bool
  let isLoadingProgress: Double
  let selectedYear: Int
  let singleHabit: Habit?

  var body: some View {
    VStack(spacing: 12) {
      if userHabits.isEmpty {
        CalendarEmptyStateView(
          title: "No habits yet",
          subtitle: "Create habits to see your yearly progress")
          .frame(maxWidth: .infinity, alignment: .center)
      } else if isDataLoaded {
        // Individual habit tables with yearly heatmaps and statistics
        LazyVStack(spacing: 16) {
          ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
            VStack(spacing: 0) {
              // Habit header - only show when not in single habit mode
              if singleHabit == nil {
                HStack(spacing: 8) {
                  HabitIconInlineView(habit: habit)

                  Text(habit.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
              }

              // Yearly heatmap for this habit
              yearlyHeatmapTable(for: habit, index: index)
                .padding(.top, singleHabit != nil ? 16 : 0)

              // Summary statistics row
              summaryStatisticsView(for: habit)
                .padding(.horizontal, 16)
              .padding(.top, 16)
              .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 24)
                .fill(.appSurface01)
                .overlay(
                  LinearGradient(
                    stops: [
                      Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                      Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                    ],
                    startPoint: UnitPoint(x: 0.08, y: 0.09),
                    endPoint: UnitPoint(x: 0.88, y: 1)
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 24))
                ))
            .overlay(
              RoundedRectangle(cornerRadius: 24)
                .stroke(Color("appOutline1Variant"), lineWidth: 2))
            .id("year-habit-\(habit.id)-\(index)")
          }
        }
      } else {
        // Loading placeholder with progress
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)

          if isLoadingProgress > 0 {
            ProgressView(value: isLoadingProgress)
              .progressViewStyle(LinearProgressViewStyle())
              .frame(width: 200)
          }

          Text("Loading heatmap data...")
            .font(.appBodyMedium)
            .foregroundColor(.text04)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Private

  // MARK: - Yearly Heatmap Table

  @ViewBuilder
  private func yearlyHeatmapTable(for _: Habit, index: Int) -> some View {
    VStack(spacing: 8) {
      // Calculate date components outside of @ViewBuilder
      let calendar = AppDateFormatter.shared.getUserCalendar()
      let daysInYear = calendar.isLeapYear(selectedYear) ? 366 : 365

      // Main heatmap grid - compact grid that respects container padding
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(minimum: 8, maximum: 12), spacing: 1),
          count: 30),
        spacing: 1)
      {
        ForEach(0 ..< daysInYear, id: \.self) { dayIndex in
          // Safely access the heatmap data
          if index < yearlyHeatmapData.count, dayIndex < yearlyHeatmapData[index].count {
            let heatmapData = yearlyHeatmapData[index][dayIndex]
            HeatmapCellView(
              intensity: heatmapData.intensity,
              isScheduled: heatmapData.isScheduled,
              completionPercentage: heatmapData.completionPercentage,
              rectangleSizePercentage: 0.8)
              .aspectRatio(1, contentMode: .fit)
              .cornerRadius(2)
          } else {
            // Fallback for missing data
            Rectangle()
              .fill(.clear)
              .aspectRatio(1, contentMode: .fit)
              .cornerRadius(2)
          }
        }
      }
    }
    .padding(.horizontal, 16)
  }

  // MARK: - Helper View Methods

  @ViewBuilder
  private func summaryStatisticsView(for habit: Habit) -> some View {
    HStack(spacing: 0) {
      // Completion percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateHabitCompletionPercentage(for: habit)))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best streak
      VStack(spacing: 4) {
        Text(pluralizeDay(calculateHabitBestStreak(for: habit)))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateHabitConsistency(for: habit)))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  // MARK: - Helper Functions for Summary Statistics

  private func calculateHabitCompletionPercentage(for habit: Habit) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Calculate for the entire year based on selectedYear parameter
    var components = DateComponents()
    components.year = selectedYear
    components.month = 1
    components.day = 1
    let startOfYear = calendar.date(from: components) ?? Date()
    let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear

    var totalGoal = 0
    var totalCompleted = 0

    // Calculate for the entire year
    var currentDate = startOfYear
    while currentDate <= endOfYear, currentDate <= today {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        let goalAmount = parseGoalAmount(from: habit.goal)
        let progress = habit.getProgress(for: currentDate)
        totalGoal += goalAmount
        totalCompleted += progress
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalGoal == 0 {
      return habit.isCompleted(for: today) ? 100.0 : 0.0
    }

    return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
  }

  private func calculateHabitCompletedDays(for habit: Habit) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Calculate for the entire year based on selectedYear parameter
    var components = DateComponents()
    components.year = selectedYear
    components.month = 1
    components.day = 1
    let startOfYear = calendar.date(from: components) ?? Date()
    let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear

    var completedDays = 0
    var currentDate = startOfYear

    while currentDate <= endOfYear, currentDate <= today {
      if habit.isCompleted(for: currentDate) {
        completedDays += 1
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    return completedDays
  }

  private func calculateHabitConsistency(for habit: Habit) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Calculate for the entire year based on selectedYear parameter
    var components = DateComponents()
    components.year = selectedYear
    components.month = 1
    components.day = 1
    let startOfYear = calendar.date(from: components) ?? Date()
    let endOfYear = calendar.dateInterval(of: .year, for: startOfYear)?.end ?? startOfYear

    var scheduledDays = 0
    var completedDays = 0
    var currentDate = startOfYear

    while currentDate <= endOfYear, currentDate <= today {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
        scheduledDays += 1
        if habit.isCompleted(for: currentDate) {
          completedDays += 1
        }
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if scheduledDays == 0 {
      return 0.0
    }

    return (Double(completedDays) / Double(scheduledDays)) * 100.0
  }

  private func parseGoalAmount(from goalString: String) -> Int {
    StreakDataCalculator.parseGoalAmount(from: goalString)
  }

  private func calculateHabitBestStreak(for habit: Habit) -> Int {
    // ✅ PERSISTENT BEST STREAK: Use bestStreakEver from HabitData if available
    if let habitData = getHabitData(for: habit.id) {
      // Update bestStreakEver by calculating from history, then return the persistent value
      let calculatedBest = habitData.calculateAndUpdateBestStreak()
      return calculatedBest
    }
    
    // Fallback: Use StreakDataCalculator if HabitData not available
    return StreakDataCalculator.calculateBestStreakFromHistory(for: habit)
  }
  
  /// Helper to get HabitData for a habit ID
  private func getHabitData(for habitId: UUID) -> HabitData? {
    do {
      let context = SwiftDataContainer.shared.modelContext
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { $0.id == habitId }
      )
      return try context.fetch(descriptor).first
    } catch {
      return nil
    }
  }
}

// MARK: - MonthlyTotalEmojiCell

struct MonthlyTotalEmojiCell: View {
  // MARK: Internal

  let habit: Habit
  let dayIndex: Int
  let numberOfWeeks: Int
  let selectedMonth: Date
  let getMonthlyHeatmapDataForHabit: (Habit, Int, Int) -> (
    intensity: Int,
    isScheduled: Bool,
    completionPercentage: Double)

  var body: some View {
    // Calculate total completion for this day across completed weeks only
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = calendar.startOfDay(for: Date())

    // Check if ALL weeks have passed for this day column
    let allWeeksPassedForThisDay = (0 ..< numberOfWeeks).allSatisfy { weekIndex in
      // Calculate the date for this week and day using the same logic as the monthly heatmap
      // Use the selectedMonth instead of habit.startDate to get the correct month context
      let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
      let monthStartWeekday = calendar.component(.weekday, from: monthStart)
      let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
      let firstWeekdayOfMonth = calendar.date(
        byAdding: .day,
        value: -daysFromFirstWeekday,
        to: monthStart) ?? monthStart
      let targetDate = calendar.date(
        byAdding: .day,
        value: (weekIndex * 7) + dayIndex,
        to: firstWeekdayOfMonth) ?? monthStart

      // Check if this date is in the past or today
      return targetDate <= today
    }

    // If any week is still upcoming, show upcoming emoji
    if !allWeeksPassedForThisDay {
      Image("022-emoji@4x") // Upcoming day emoji
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .opacity(0.2) // Same opacity as upcoming days
    } else {
      // All weeks have passed, calculate average completion
      let completedWeeks = (0 ..< numberOfWeeks).filter { weekIndex in
        // Calculate the date for this week and day using the same logic
        // Use the selectedMonth instead of habit.startDate to get the correct month context
        let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?
          .start ?? selectedMonth
        let monthStartWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
        let firstWeekdayOfMonth = calendar.date(
          byAdding: .day,
          value: -daysFromFirstWeekday,
          to: monthStart) ?? monthStart
        let targetDate = calendar.date(
          byAdding: .day,
          value: (weekIndex * 7) + dayIndex,
          to: firstWeekdayOfMonth) ?? monthStart

        // Check if this date is in the past or today
        return targetDate <= today
      }

      // Calculate average completion only for completed weeks
      let totalCompletion = completedWeeks.reduce(0.0) { total, weekIndex in
        let heatmapData = getMonthlyHeatmapDataForHabit(habit, weekIndex, dayIndex)
        return total + heatmapData.completionPercentage
      }
      let averageCompletion = completedWeeks.isEmpty
        ? 0.0
        : totalCompletion / Double(completedWeeks.count)

      // Show emoji based on average completion
      let emojiImageName = emojiImageName(for: averageCompletion)

      Image(emojiImageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
    }
  }

  // MARK: Private

  private func emojiImageName(for completionPercentage: Double) -> String {
    if completionPercentage >= 75.0 {
      "004-emoji@4x"
    } else if completionPercentage >= 55.0 {
      "021-emoji@4x"
    } else if completionPercentage >= 35.0 {
      "001-emoji@4x"
    } else if completionPercentage >= 10.0 {
      "024-emoji@4x"
    } else {
      "008-emoji@4x"
    }
  }
}

// MARK: - MonthlyTotalEmojiCellCombined

struct MonthlyTotalEmojiCellCombined: View {
  // MARK: Internal

  let dayIndex: Int
  let numberOfWeeks: Int
  let selectedMonth: Date
  let getMonthlyHeatmapDataCombined: (Int, Int) -> (
    intensity: Int,
    isScheduled: Bool,
    completionPercentage: Double)

  var body: some View {
    // Calculate total completion for this day across completed weeks only
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = calendar.startOfDay(for: Date())

    // Check if ALL weeks have passed for this day column
    let allWeeksPassedForThisDay = (0 ..< numberOfWeeks).allSatisfy { weekIndex in
      // Calculate the date for this week and day using the same logic as the monthly heatmap
      let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
      let monthStartWeekday = calendar.component(.weekday, from: monthStart)
      let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
      let firstWeekdayOfMonth = calendar.date(
        byAdding: .day,
        value: -daysFromFirstWeekday,
        to: monthStart) ?? monthStart
      let targetDate = calendar.date(
        byAdding: .day,
        value: (weekIndex * 7) + dayIndex,
        to: firstWeekdayOfMonth) ?? monthStart

      // Check if this date is in the past or today
      return targetDate <= today
    }

    // If any week is still upcoming, show upcoming emoji
    if !allWeeksPassedForThisDay {
      Image("022-emoji@4x") // Upcoming day emoji
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .opacity(0.2) // Same opacity as upcoming days
    } else {
      // All weeks have passed, calculate average completion
      let completedWeeks = (0 ..< numberOfWeeks).filter { weekIndex in
        // Calculate the date for this week and day using the same logic
        let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?
          .start ?? selectedMonth
        let monthStartWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
        let firstWeekdayOfMonth = calendar.date(
          byAdding: .day,
          value: -daysFromFirstWeekday,
          to: monthStart) ?? monthStart
        let targetDate = calendar.date(
          byAdding: .day,
          value: (weekIndex * 7) + dayIndex,
          to: firstWeekdayOfMonth) ?? monthStart

        // Check if this date is in the past or today
        return targetDate <= today
      }

      // Calculate average completion only for completed weeks
      let totalCompletion = completedWeeks.reduce(0.0) { total, weekIndex in
        let heatmapData = getMonthlyHeatmapDataCombined(weekIndex, dayIndex)
        return total + heatmapData.completionPercentage
      }
      let averageCompletion = completedWeeks.isEmpty
        ? 0.0
        : totalCompletion / Double(completedWeeks.count)

      // Show emoji based on average completion
      let emojiImageName = emojiImageName(for: averageCompletion)

      Image(emojiImageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
    }
  }

  // MARK: Private

  private func emojiImageName(for completionPercentage: Double) -> String {
    if completionPercentage >= 75.0 {
      "004-emoji@4x"
    } else if completionPercentage >= 55.0 {
      "021-emoji@4x"
    } else if completionPercentage >= 35.0 {
      "001-emoji@4x"
    } else if completionPercentage >= 10.0 {
      "024-emoji@4x"
    } else {
      "008-emoji@4x"
    }
  }
}

// MARK: - WeeklyTotalEmojiCell

struct WeeklyTotalEmojiCell: View {
  // MARK: Internal

  let completionPercentage: Double
  let isScheduled: Bool
  let isUpcoming: Bool
  let dayIndex: Int
  let weekStartDate: Date
  let emojiSize: CGFloat

  init(
    completionPercentage: Double,
    isScheduled: Bool,
    isUpcoming: Bool,
    dayIndex: Int,
    weekStartDate: Date,
    emojiSize: CGFloat = 20)
  {
    self.completionPercentage = completionPercentage
    self.isScheduled = isScheduled
    self.isUpcoming = isUpcoming
    self.dayIndex = dayIndex
    self.weekStartDate = weekStartDate
    self.emojiSize = emojiSize
  }

  var body: some View {
    ZStack {
      if isScheduled {
        // Show emoji based on completion percentage or upcoming status
        Image(emojiImageName(
          for: completionPercentage,
          isUpcoming: isUpcoming,
          dayIndex: dayIndex,
          weekStartDate: weekStartDate))
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: emojiSize, height: emojiSize)
          .opacity(isUpcoming ? 0.2 : 1.0)
      } else {
        // Show nothing when no habits are scheduled
        EmptyView()
      }
    }
    .frame(width: 32, height: 32)
  }

  // MARK: Private

  private func emojiImageName(
    for completionPercentage: Double,
    isUpcoming: Bool,
    dayIndex: Int,
    weekStartDate: Date) -> String
  {
    // For upcoming days, always show the upcoming emoji
    if isUpcoming {
      return "022-emoji@4x" // Upcoming day emoji
    }

    // Check if this specific day is today
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let weekStart = calendar.startOfDay(for: weekStartDate)
    let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
    let today = calendar.startOfDay(for: Date())
    let isToday = calendar.isDate(targetDate, inSameDayAs: today)

    // For today specifically: if no habits completed yet, show moderate emoji as "pending"
    if isToday, completionPercentage == 0.0 {
      return "036-emoji@4x" // Show moderate emoji for today when no habits completed yet
    }

    // For past/present days, show completion-based emoji
    let clampedPercentage = max(0.0, min(100.0, completionPercentage))

    if clampedPercentage >= 75.0 {
      return "004-emoji@4x" // 75%+ completion
    } else if clampedPercentage >= 55.0 {
      return "021-emoji@4x" // 55-74% completion
    } else if clampedPercentage >= 35.0 {
      return "001-emoji@4x" // 35-54% completion
    } else if clampedPercentage >= 10.0 {
      return "024-emoji@4x" // 10-34% completion
    } else {
      return "008-emoji@4x" // 0-9% completion
    }
  }
}

// MARK: - IndividualHabitWeeklyProgressView

struct IndividualHabitWeeklyProgressView: View {
  // MARK: Internal

  let habit: Habit
  let selectedWeekStartDate: Date
  var hideHeader: Bool = false

  var body: some View {
    VStack(spacing: 16) {
      // Habit header: Icon + Name | Goal (only show if not hidden)
      if !hideHeader {
        HStack {
          // Habit icon + name
          HStack(spacing: 8) {
            HabitIconInlineView(habit: habit)
            
            Text(habit.name)
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.appText03)
              .lineLimit(1)
          }
          
          Spacer()
          
          // Goal text
          Text(habit.goal)
            .font(.appTitleSmall)
            .foregroundColor(.appText05)
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
      }

      // Weekly stat: Day labels and date rectangles
      VStack(spacing: 8) {
        // Day labels row
        HStack(spacing: 0) {
          ForEach(Array(weeklyDayLabels.enumerated()), id: \.offset) { index, day in
            Text(day)
              .font(.appLabelSmallEmphasised)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, hideHeader ? 16 : 0)

        // Date rectangles row
        HStack(spacing: 0) {
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let date = getDateForDayIndex(dayIndex)
            let dayNumber = getDayNumber(for: date)
            let isCompleted = habit.isCompleted(for: date)
            let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
            
            ZStack {
              // Rectangle background
              RoundedRectangle(cornerRadius: 8)
                .fill(isCompleted && isScheduled ? habit.color.color : Color("appOutline02"))
                .frame(width: 32, height: 32)
              
              // Date number
              Text("\(dayNumber)")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(isCompleted && isScheduled ? Color("appTextDarkFixed") : Color("appOutline06"))
            }
            .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.bottom, 16)
    }
  }

  // MARK: Private

  private var weeklyDayLabels: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    } else { // Monday
      return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }
  }

  private func getDateForDayIndex(_ dayIndex: Int) -> Date {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
    return calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
  }

  private func getDayNumber(for date: Date) -> Int {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    return calendar.component(.day, from: date)
  }
}

// MARK: - IndividualHabitsWeeklyProgressContainer

struct IndividualHabitsWeeklyProgressContainer: View {
  // MARK: Internal

  let habits: [Habit]
  let selectedWeekStartDate: Date
  var selectedHabit: Habit? = nil

  private var filteredHabits: [Habit] {
    if let selectedHabit = selectedHabit {
      return habits.filter { $0.id == selectedHabit.id }
    }
    return habits
  }

  var body: some View {
    VStack(spacing: 16) {
      ForEach(filteredHabits, id: \.id) { habit in
        IndividualHabitWeeklyProgressView(
          habit: habit,
          selectedWeekStartDate: selectedWeekStartDate,
          hideHeader: selectedHabit != nil)
          .background(
            RoundedRectangle(cornerRadius: 24)
              .fill(.appSurface01)
              .overlay(
                LinearGradient(
                  stops: [
                    Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                    Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                  ],
                  startPoint: UnitPoint(x: 0.08, y: 0.09),
                  endPoint: UnitPoint(x: 0.88, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
              ))
          .overlay(
            RoundedRectangle(cornerRadius: 24)
              .stroke(Color("appOutline1Variant"), lineWidth: 2))
      }
    }
  }
}

// MARK: - AllHabitsWeeklyProgressView

struct AllHabitsWeeklyProgressView: View {
  // MARK: Internal

  let habits: [Habit]
  let selectedWeekStartDate: Date

  var body: some View {
    VStack(spacing: 16) {
      // Header: Just "Total" text
      HStack {
        Text("Total")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.appText03)
        
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // Weekly stat: Day labels and emoji icons
      VStack(spacing: 8) {
        // Day labels row
        HStack(spacing: 0) {
          ForEach(Array(weeklyDayLabels.enumerated()), id: \.offset) { index, day in
            Text(day)
              .font(.appLabelSmallEmphasised)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)

        // Emoji icons row (using WeeklyTotalEmojiCell)
        HStack(spacing: 0) {
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let totalHeatmapData = StreakDataCalculator.getWeeklyTotalHeatmapData(
              dayIndex: dayIndex,
              habits: habits,
              weekStartDate: selectedWeekStartDate)

            // Calculate if this day is upcoming (future)
            let calendar = AppDateFormatter.shared.getUserCalendar()
            let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
            let targetDate = calendar
              .date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
            let today = calendar.startOfDay(for: Date())
            let isUpcoming = targetDate > today

            WeeklyTotalEmojiCell(
              completionPercentage: totalHeatmapData.completionPercentage,
              isScheduled: totalHeatmapData.isScheduled,
              isUpcoming: isUpcoming,
              dayIndex: dayIndex,
              weekStartDate: selectedWeekStartDate,
              emojiSize: 28)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.bottom, 12)

      // Stats section (similar to Monthly Calendar Grid & Stats Container)
      weeklyStatsView
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(.appSurface01)
        .overlay(
          LinearGradient(
            stops: [
              Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
              Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0.09),
            endPoint: UnitPoint(x: 0.88, y: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 24))
        ))
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color("appOutline1Variant"), lineWidth: 2))
  }

  // MARK: Private

  private var weeklyDayLabels: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    } else { // Monday
      return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }
  }

  private var weeklyStatsView: some View {
    HStack(spacing: 0) {
      // Completion percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateWeeklyCompletionPercentage()))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best streak
      VStack(spacing: 4) {
        Text(pluralizeDay(calculateWeeklyBestStreak()))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency percentage
      VStack(spacing: 4) {
        Text("\(Int(calculateWeeklyConsistency()))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  private func calculateWeeklyCompletionPercentage() -> Double {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = calendar.startOfDay(for: Date())
    let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

    var totalGoal = 0
    var totalCompleted = 0

    // Calculate for all habits in the selected week
    var currentDate = weekStart
    while currentDate <= weekEnd, currentDate <= today {
      for habit in habits {
        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
          let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
          let progress = habit.getProgress(for: currentDate)
          totalGoal += goalAmount
          totalCompleted += progress
        }
      }
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalGoal == 0 {
      return 0.0
    }

    return min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
  }

  private func calculateWeeklyConsistency() -> Double {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = calendar.startOfDay(for: Date())
    let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

    var totalScheduledDays = 0
    var totalCompletedDays = 0
    var currentDate = weekStart

    while currentDate <= weekEnd, currentDate <= today {
      var dayScheduled = false
      var dayCompleted = false

      for habit in habits {
        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
          dayScheduled = true
          if habit.isCompleted(for: currentDate) {
            dayCompleted = true
            break // At least one habit completed on this day
          }
        }
      }

      if dayScheduled {
        totalScheduledDays += 1
        if dayCompleted {
          totalCompletedDays += 1
        }
      }

      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    if totalScheduledDays == 0 {
      return 0.0
    }

    return (Double(totalCompletedDays) / Double(totalScheduledDays)) * 100.0
  }

  private func calculateWeeklyBestStreak() -> Int {
    // Return the maximum best streak across all habits
    // Use StreakDataCalculator which handles HabitData internally
    return habits.map { habit in
      StreakDataCalculator.calculateBestStreakFromHistory(for: habit)
    }.max() ?? 0
  }
}

// MARK: - IndividualHabitWeeklyProgressView (New Style)

struct IndividualHabitWeeklyProgressViewNew: View {
  // MARK: Internal

  let habit: Habit
  let selectedWeekStartDate: Date

  var body: some View {
    VStack(spacing: 16) {
      // Header: Habit icon + Name | Goal - HIDDEN
      // HStack {
      //   // Habit icon + name
      //   HStack(spacing: 8) {
      //     HabitIconInlineView(habit: habit)
      //     
      //     Text(habit.name)
      //       .font(.appTitleMediumEmphasised)
      //       .foregroundColor(.appText03)
      //       .lineLimit(1)
      //   }
      //   
      //   Spacer()
      //   
      //   // Goal text
      //   Text(habit.goal)
      //     .font(.appTitleSmall)
      //     .foregroundColor(.appText05)
      //     .lineLimit(1)
      // }
      // .padding(.horizontal, 16)
      // .padding(.top, 16)

      // Weekly stat: Day labels and emoji icons
      VStack(spacing: 8) {
        // Day labels row
        HStack(spacing: 0) {
          ForEach(Array(weeklyDayLabels.enumerated()), id: \.offset) { index, day in
            Text(day)
              .font(.appLabelSmallEmphasised)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)

        // Emoji icons row (using WeeklyTotalEmojiCell)
        HStack(spacing: 0) {
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let heatmapData = StreakDataCalculator.getWeeklyTotalHeatmapData(
              dayIndex: dayIndex,
              habits: [habit],
              weekStartDate: selectedWeekStartDate)

            // Calculate if this day is upcoming (future)
            let calendar = AppDateFormatter.shared.getUserCalendar()
            let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
            let targetDate = calendar
              .date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
            let today = calendar.startOfDay(for: Date())
            let isUpcoming = targetDate > today

            WeeklyTotalEmojiCell(
              completionPercentage: heatmapData.completionPercentage,
              isScheduled: heatmapData.isScheduled,
              isUpcoming: isUpcoming,
              dayIndex: dayIndex,
              weekStartDate: selectedWeekStartDate,
              emojiSize: 28)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.bottom, 12)

      // Stats section (similar to Monthly Calendar Grid & Stats Container)
      weeklyStatsView
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(.appSurface01)
        .overlay(
          LinearGradient(
            stops: [
              Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
              Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0.09),
            endPoint: UnitPoint(x: 0.88, y: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 24))
        ))
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color("appOutline1Variant"), lineWidth: 2))
  }

  // MARK: Private

  private var weeklyDayLabels: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    } else { // Monday
      return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }
  }

  private var weeklyStatsView: some View {
    let stats = calculateWeeklyStats()
    
    return HStack(spacing: 0) {
      // Completion percentage
      VStack(spacing: 4) {
        Text("\(Int(stats.completionRate))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best streak
      VStack(spacing: 4) {
        Text(pluralizeDay(stats.bestStreak))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency percentage
      VStack(spacing: 4) {
        Text("\(Int(stats.consistencyRate))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  private func calculateWeeklyStats() -> (
    completionRate: Double, bestStreak: Int, consistencyRate: Double)
  {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
    let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    let today = calendar.startOfDay(for: Date())

    var totalGoal = 0
    var totalCompleted = 0
    var scheduledDays = 0
    var completedDays = 0
    var maxStreak = 0
    var currentStreak = 0

    var currentDate = weekStart
    while currentDate < weekEnd, currentDate <= today {
      let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate)

      if isScheduled {
        scheduledDays += 1

        let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
        let progress = habit.getProgress(for: currentDate)

        totalGoal += goalAmount
        totalCompleted += progress

        if habit.isCompleted(for: currentDate) {
          completedDays += 1
          currentStreak += 1
          maxStreak = max(maxStreak, currentStreak)
        } else {
          currentStreak = 0
        }
      } else {
        currentStreak = 0
      }

      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    let completionRate = totalGoal > 0
      ? min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
      : 0.0

    let consistencyRate = scheduledDays > 0
      ? (Double(completedDays) / Double(scheduledDays)) * 100.0
      : 0.0

    return (completionRate: completionRate, bestStreak: maxStreak, consistencyRate: consistencyRate)
  }
}

// MARK: - IndividualHabitMonthlyProgressView

struct IndividualHabitMonthlyProgressView: View {
  // MARK: Internal

  let habit: Habit
  let selectedMonth: Date
  let cardWidth: CGFloat

  init(habit: Habit, selectedMonth: Date, cardWidth: CGFloat) {
    self.habit = habit
    self.selectedMonth = selectedMonth
    self.cardWidth = cardWidth
  }

  var body: some View {
    VStack(spacing: 12) {
      // Habit header: Icon + Name
      HStack(spacing: 8) {
        HabitIconInlineView(habit: habit)

        Text(habit.name)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.appText03)
          .lineLimit(1)
          .truncationMode(.tail)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // Monthly heatmap without date numbers and day headers
      monthlyHeatmapSimple
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .background(
      RoundedRectangle(cornerRadius: 24)
        .fill(.appSurface01)
        .overlay(
          LinearGradient(
            stops: [
              Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
              Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0.09),
            endPoint: UnitPoint(x: 0.88, y: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 24))
        ))
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color("appOutline1Variant"), lineWidth: 2))
  }

  // MARK: Private

  private var numberOfWeeksInMonth: Int {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth)
    let startDate = monthInterval?.start ?? selectedMonth
    let endDate = monthInterval?.end ?? selectedMonth

    var currentDate = startDate
    var weekCount = 0

    while currentDate < endDate {
      weekCount += 1
      currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
    }

    return max(1, weekCount)
  }

  private var monthlyHeatmapSimple: some View {
    VStack(spacing: 4) {
      // Week rows with heatmap cells
      ForEach(0 ..< numberOfWeeksInMonth, id: \.self) { weekIndex in
        HStack(spacing: 4) {
          ForEach(0 ..< 7, id: \.self) { dayIndex in
            let heatmapData = getMonthlyHeatmapDataForHabit(
              habit: habit,
              weekIndex: weekIndex,
              dayIndex: dayIndex)
            IndividualHabitHeatmapCellView(
              habit: habit,
              intensity: heatmapData.intensity,
              isScheduled: heatmapData.isScheduled,
              completionPercentage: heatmapData.completionPercentage,
              cellSize: calculatedCellSize,
              isInMonth: heatmapData.isInMonth)
          }
        }
      }
    }
  }

  // Calculate cell size based on available card width
  private var calculatedCellSize: CGFloat {
    // Card has 16pt horizontal padding on each side = 32pt total
    let horizontalPadding: CGFloat = 32
    // 7 cells with 6 gaps of 4pt each = 24pt spacing
    let cellSpacing: CGFloat = 24
    // Available width for heatmap
    let availableForCells = cardWidth - horizontalPadding
    // Calculate cell size: (availableWidth - spacing) / 7
    let calculatedSize = (availableForCells - cellSpacing) / 7
    // Ensure minimum size of 16pt and maximum of 24pt for readability
    return max(16, min(24, calculatedSize))
  }

  private func getMonthlyHeatmapDataForHabit(
    habit: Habit,
    weekIndex: Int,
    dayIndex: Int) -> (intensity: Int, isScheduled: Bool, completionPercentage: Double, isInMonth: Bool)
  {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth

    // Calculate the first day of the week that contains the month start
    let monthStartWeekday = calendar.component(.weekday, from: monthStart)
    let daysFromFirstWeekday = (monthStartWeekday - calendar.firstWeekday + 7) % 7
    let firstWeekdayOfMonth = calendar.date(
      byAdding: .day,
      value: -daysFromFirstWeekday,
      to: monthStart) ?? monthStart

    // Calculate the target date based on week and day indices
    let targetDate = calendar.date(
      byAdding: .day,
      value: (weekIndex * 7) + dayIndex,
      to: firstWeekdayOfMonth) ?? monthStart

    // Check if the target date is within the selected month
    let monthEnd = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
    // Check if targetDate is OUTSIDE the selected month (before OR after)
    if targetDate < monthStart || targetDate >= monthEnd {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0, isInMonth: false)
    }

    let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: targetDate)
    if !isScheduled {
      return (intensity: 0, isScheduled: false, completionPercentage: 0.0, isInMonth: true)
    }

    let completionPercentage = StreakDataCalculator.calculateCompletionPercentage(
      for: habit,
      date: targetDate)
    let intensity = if completionPercentage == 0 {
      0
    } else if completionPercentage < 25 {
      1
    } else if completionPercentage < 50 {
      2
    } else {
      3
    }

    return (intensity: intensity, isScheduled: true, completionPercentage: completionPercentage, isInMonth: true)
  }
}

// MARK: - IndividualHabitMonthlyCalendarProgressView

struct IndividualHabitMonthlyCalendarProgressView: View {
  // MARK: Internal

  let habit: Habit
  let selectedMonth: Date
  let singleHabit: Habit?

  var body: some View {
    VStack(spacing: 16) {
      // Habit header: Icon + Name | Goal - only show when not in single habit mode
      if singleHabit == nil {
        HStack {
          // Habit icon + name
          HStack(spacing: 8) {
            HabitIconInlineView(habit: habit)
            
            Text(habit.name)
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.appText03)
              .lineLimit(1)
          }
          
          Spacer()
          
          // Goal text
          Text(habit.goal)
            .font(.appTitleSmall)
            .foregroundColor(.appText05)
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
      }

      // Monthly calendar grid: Day labels and date rectangles
      VStack(spacing: 8) {
        // Day labels row
        HStack(spacing: 0) {
          ForEach(Array(monthlyDayLabels.enumerated()), id: \.offset) { index, day in
            Text(day)
              .font(.appLabelSmallEmphasised)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, singleHabit != nil ? 16 : 0)

        // Calendar grid with dates
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
          // Empty cells for days before month starts
          ForEach(0 ..< firstDayOfMonth, id: \.self) { _ in
            Color.clear
              .frame(width: 32, height: 32)
          }

          // Date cells for the month
          ForEach(1 ... daysInMonth, id: \.self) { day in
            let date = getDateForDay(day)
            let isCompleted = habit.isCompleted(for: date)
            let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
            
            ZStack {
              // Rectangle background
              RoundedRectangle(cornerRadius: 8)
                .fill(isCompleted && isScheduled ? habit.color.color : Color("appOutline02"))
                .frame(width: 32, height: 32)
              
              // Date number
              Text("\(day)")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(isCompleted && isScheduled ? Color("appTextDarkFixed") : Color("appOutline06"))
            }
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.bottom, 16)
    }
  }

  // MARK: Private

  private var monthlyDayLabels: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    } else { // Monday
      return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }
  }

  private var firstDayOfMonth: Int {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    let weekday = calendar.component(.weekday, from: monthStart)
    
    // Convert to 0-based index where 0 = first day of week
    if calendar.firstWeekday == 1 { // Sunday
      return (weekday - 1) % 7
    } else { // Monday
      return (weekday - 2 + 7) % 7
    }
  }

  private var daysInMonth: Int {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let range = calendar.range(of: .day, in: .month, for: selectedMonth)
    return range?.count ?? 30
  }

  private func getDateForDay(_ day: Int) -> Date {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
    return calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
  }
}

// MARK: - IndividualHabitsMonthlyCalendarProgressContainer

struct IndividualHabitsMonthlyCalendarProgressContainer: View {
  // MARK: Internal

  let habits: [Habit]
  let selectedMonth: Date
  let singleHabit: Habit?

  var body: some View {
    VStack(spacing: 16) {
      ForEach(habits, id: \.id) { habit in
        IndividualHabitMonthlyCalendarProgressView(
          habit: habit,
          selectedMonth: selectedMonth,
          singleHabit: singleHabit)
          .background(
            RoundedRectangle(cornerRadius: 24)
              .fill(.appSurface01)
              .overlay(
                LinearGradient(
                  stops: [
                    Gradient.Stop(color: .white.opacity(0.07), location: 0.00),
                    Gradient.Stop(color: .white.opacity(0.03), location: 1.00),
                  ],
                  startPoint: UnitPoint(x: 0.08, y: 0.09),
                  endPoint: UnitPoint(x: 0.88, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
              ))
          .overlay(
            RoundedRectangle(cornerRadius: 24)
              .stroke(Color("appOutline1Variant"), lineWidth: 2))
      }
    }
  }
}

// MARK: - IndividualHabitHeatmapCellView

struct IndividualHabitHeatmapCellView: View {
  let habit: Habit
  let intensity: Int
  let isScheduled: Bool
  let completionPercentage: Double
  let cellSize: CGFloat
  let isInMonth: Bool

  init(
    habit: Habit,
    intensity: Int,
    isScheduled: Bool,
    completionPercentage: Double,
    cellSize: CGFloat = 20,
    isInMonth: Bool = true)
  {
    self.habit = habit
    self.intensity = intensity
    self.isScheduled = isScheduled
    self.completionPercentage = completionPercentage
    self.cellSize = cellSize
    self.isInMonth = isInMonth
  }

  var body: some View {
    let size = cellSize
    let innerSize = size * 0.8

    ZStack {
      // Background
      RoundedRectangle(cornerRadius: 4)
        .fill(.clear)
        .frame(width: size, height: size)

      if !isInMonth {
        // Days outside month: completely invisible
        Color.clear
          .frame(width: innerSize, height: innerSize)
      } else if isScheduled {
        // Show heatmap when scheduled using habit color
        RoundedRectangle(cornerRadius: 4)
          .fill(heatmapColor(for: completionPercentage, habitColor: habit.color.color))
          .frame(width: innerSize, height: innerSize)
      } else {
        // Show empty outline when not scheduled but in month
        RoundedRectangle(cornerRadius: 4)
          .stroke(Color("appOutline03"), lineWidth: 1)
          .frame(width: innerSize, height: innerSize)
      }
    }
    .frame(width: size, height: size)
  }

  private func heatmapColor(for completionPercentage: Double, habitColor: Color) -> Color {
    let clampedPercentage = max(0.0, min(100.0, completionPercentage))

    if clampedPercentage == 0.0 {
      return Color("appOutline02")
    } else {
      // Use habit color for any completion, with intensity based on percentage
      // Higher completion = more intense color
      if clampedPercentage >= 100.0 {
        return habitColor
      } else {
        // Use habit color with opacity based on completion
        let opacity = 0.5 + (clampedPercentage / 100.0) * 0.5
        return habitColor.opacity(opacity)
      }
    }
  }
}

// MARK: - IndividualHabitsMonthlyProgressContainer

struct IndividualHabitsMonthlyProgressContainer: View {
  // MARK: Internal

  let habits: [Habit]
  let selectedMonth: Date

  // MARK: State

  // Initialize with a reasonable default (iPhone width minus padding)
  // Parent has 20pt padding on each side = 40pt total
  // Will be updated by PreferenceKey when GeometryReader measures actual width
  @State private var availableWidth: CGFloat = 335 // ~375pt (iPhone) - 40pt padding

  // Minimum card width based on heatmap requirements:
  // - 7 columns × 20pt cells = 140pt
  // - 6 gaps × 4pt spacing = 24pt
  // - 2 × 16pt horizontal padding = 32pt
  // - Total: ~196pt, rounded to 155pt minimum for comfortable spacing
  private let minCardWidth: CGFloat = 155
  private let gridSpacing: CGFloat = 16
  // Estimated card height: header (~60pt) + heatmap (~100pt for 5 weeks) + padding (~20pt)
  private let estimatedCardHeight: CGFloat = 180

  // MARK: Computed Properties

  private var columnCount: Int {
    return availableWidth >= (minCardWidth * 2 + gridSpacing) ? 2 : 1
  }

  private var rowCount: Int {
    guard !habits.isEmpty else { return 0 }
    return Int(ceil(Double(habits.count) / Double(columnCount)))
  }

  private var totalHeight: CGFloat {
    guard rowCount > 0 else { return 0 }
    return CGFloat(rowCount) * estimatedCardHeight + CGFloat(max(0, rowCount - 1)) * gridSpacing
  }

  private var gridColumns: [GridItem] {
    if columnCount == 2 {
      return [
        GridItem(.flexible(minimum: minCardWidth), spacing: gridSpacing),
        GridItem(.flexible(minimum: minCardWidth), spacing: gridSpacing),
      ]
    } else {
      return [GridItem(.flexible(minimum: minCardWidth))]
    }
  }

  // Calculate card width based on available width and column count
  private var cardWidth: CGFloat {
    if columnCount == 2 {
      // Two columns: (availableWidth - spacing) / 2
      return (availableWidth - gridSpacing) / 2
    } else {
      // Single column: use full width
      return availableWidth
    }
  }

  // MARK: Body

  var body: some View {
    LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
      ForEach(habits, id: \.id) { habit in
        IndividualHabitMonthlyProgressView(
          habit: habit,
          selectedMonth: selectedMonth,
          cardWidth: cardWidth) // Pass calculated cardWidth (non-optional)
      }
    }
    .frame(minHeight: totalHeight, alignment: .top) // Ensure minimum height for ScrollView, align content to top
    .background(
      GeometryReader { geometry in
        Color.clear
          .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
      }
    )
    .onPreferenceChange(WidthPreferenceKey.self) { width in
      // Only update if we get a valid width measurement
      if width > 0 {
        #if DEBUG
        print("📐 Width measured: \(width), previous: \(availableWidth), cardWidth: \(cardWidth)")
        #endif
        availableWidth = width
      }
    }
  }
}

// MARK: - WidthPreferenceKey

private struct WidthPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - IndividualWeeklyCalendarGridView

struct IndividualWeeklyCalendarGridView: View {
  // MARK: Internal

  let habit: Habit
  let selectedWeekStartDate: Date

  var body: some View {
    VStack(spacing: 0) {
      // Header row with day labels only (no first column)
      HStack(spacing: 0) {
        ForEach(Array(weeklyDayHeaders.enumerated()), id: \.offset) { index, day in
          Text(day)
            .font(.appLabelMediumEmphasised)
            .foregroundColor(.text05)
            .frame(width: 40, height: 24) // Larger width for larger cells
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: index == 0 ? 12 : 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: index == 0 ? 12 : 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: index == 6 ? 12 : 0)
              .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Habit row with heatmap cells (no first column with habit name)
      HStack(spacing: 0) {
        ForEach(0 ..< 7, id: \.self) { dayIndex in
          let heatmapData = StreakDataCalculator.getWeeklyHeatmapData(
            for: habit,
            dayIndex: dayIndex,
            weekStartDate: selectedWeekStartDate)

          HeatmapCellView(
            intensity: heatmapData.intensity,
            isScheduled: heatmapData.isScheduled,
            completionPercentage: heatmapData.completionPercentage,
            rectangleSizePercentage: 0.8, // Larger circles (0.8 instead of default 0.5)
            isVacationDay: VacationManager.shared.isActive && VacationManager.shared
              .isVacationDay(Calendar.current.date(
                byAdding: .day,
                value: dayIndex,
                to: selectedWeekStartDate) ?? selectedWeekStartDate))
            .frame(width: 40, height: 48) // Larger frame for larger circles
            .overlay(
              Rectangle()
                .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Total row with emoji cells (no first column with "Total" label)
      HStack(spacing: 0) {
        ForEach(0 ..< 7, id: \.self) { dayIndex in
          let totalHeatmapData = StreakDataCalculator.getWeeklyTotalHeatmapData(
            dayIndex: dayIndex,
            habits: [habit],
            weekStartDate: selectedWeekStartDate)

          // Calculate if this day is upcoming (future)
          let calendar = AppDateFormatter.shared.getUserCalendar()
          let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
          let targetDate = calendar
            .date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
          let today = calendar.startOfDay(for: Date())
          let isUpcoming = targetDate > today

          WeeklyTotalEmojiCell(
            completionPercentage: totalHeatmapData.completionPercentage,
            isScheduled: totalHeatmapData.isScheduled,
            isUpcoming: isUpcoming,
            dayIndex: dayIndex,
            weekStartDate: selectedWeekStartDate,
            emojiSize: 24) // Larger emoji for larger cells
            .frame(width: 40, height: 40) // Larger frame
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: dayIndex == 0 ? 12 : 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0))
            .overlay(
              UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: dayIndex == 0 ? 12 : 0,
                bottomTrailingRadius: dayIndex == 6 ? 12 : 0,
                topTrailingRadius: 0)
              .stroke(Color("appOutline02Variant"), lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
  }

  // MARK: Private

  private var weeklyDayHeaders: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["S", "M", "T", "W", "T", "F", "S"]
    } else { // Monday
      return ["M", "T", "W", "T", "F", "S", "S"]
    }
  }
}

// MARK: - IndividualWeeklyStatsView

struct IndividualWeeklyStatsView: View {
  // MARK: Internal

  let habit: Habit
  let selectedWeekStartDate: Date

  var body: some View {
    let stats = calculateWeeklyStats()

    HStack(spacing: 0) {
      // Completion Rate
      VStack(spacing: 4) {
        Text("\(Int(stats.completionRate))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Completion")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Best Streak
      VStack(spacing: 4) {
        Text(pluralizeDay(stats.bestStreak))
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Best Streak")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)

      // Vertical divider
      Rectangle()
        .fill(.outline3)
        .frame(width: 1, height: 40)

      // Consistency Rate
      VStack(spacing: 4) {
        Text("\(Int(stats.consistencyRate))%")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(Color("appSecondaryContainer03"))
    .cornerRadius(16)
  }

  // MARK: Private

  private func calculateWeeklyStats() -> (
    completionRate: Double, bestStreak: Int, consistencyRate: Double)
  {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let weekStart = calendar.startOfDay(for: selectedWeekStartDate)
    let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    let today = calendar.startOfDay(for: Date())

    var totalGoal = 0
    var totalCompleted = 0
    var scheduledDays = 0
    var completedDays = 0
    var maxStreak = 0
    var currentStreak = 0

    var currentDate = weekStart
    while currentDate < weekEnd, currentDate <= today {
      let isScheduled = StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate)

      if isScheduled {
        scheduledDays += 1

        let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
        let progress = habit.getProgress(for: currentDate)

        totalGoal += goalAmount
        totalCompleted += progress

        if habit.isCompleted(for: currentDate) {
          completedDays += 1
          currentStreak += 1
          maxStreak = max(maxStreak, currentStreak)
        } else {
          currentStreak = 0
        }
      } else {
        currentStreak = 0
      }

      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    let completionRate = totalGoal > 0
      ? min(100.0, (Double(totalCompleted) / Double(totalGoal)) * 100.0)
      : (habit.isCompleted(for: today) ? 100.0 : 0.0)

    let consistencyRate = scheduledDays > 0
      ? (Double(completedDays) / Double(scheduledDays)) * 100.0
      : 0.0

    // For best streak, use HabitData if available for persistent streak
    let bestStreak: Int
    if let habitData = getHabitData(for: habit.id) {
      let calculatedBest = habitData.calculateAndUpdateBestStreak()
      bestStreak = max(maxStreak, calculatedBest)
    } else {
      bestStreak = maxStreak
    }

    return (completionRate: completionRate, bestStreak: bestStreak, consistencyRate: consistencyRate)
  }

  private func getHabitData(for habitId: UUID) -> HabitData? {
    do {
      let context = SwiftDataContainer.shared.modelContext
      let descriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { $0.id == habitId }
      )
      return try context.fetch(descriptor).first
    } catch {
      return nil
    }
  }
}
