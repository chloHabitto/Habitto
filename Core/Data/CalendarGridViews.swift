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
              .background(Color.surface3)
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
                  .stroke(.outline3, lineWidth: 1))

            ForEach(Array(weeklyDayHeaders.enumerated()), id: \.offset) { index, day in
              Text(day)
                .font(.appLabelSmallEmphasised)
                .foregroundColor(.text02)
                .frame(width: 24, height: 24)
                .background(Color.surface3)
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
                    .stroke(.outline3, lineWidth: 1))
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          // Habit rows - Performance optimization: Lazy loading with modern styling
          LazyVStack(spacing: 0) {
            ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
              HStack(spacing: 0) {
                // Habit name cell with modern styling
                HStack(spacing: 12) {
                  HabitIconInlineView(habit: habit)

                  Text(habit.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .frame(height: 36)
                .padding(.leading, 8)
                .background(.surface3)
                .overlay(
                  Rectangle()
                    .stroke(.outline3, lineWidth: 1))

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
                    .background(.surface3)
                    .overlay(
                      Rectangle()
                        .stroke(.outline3, lineWidth: 1))
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .id("weekly-habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
            }
          }

          // Total row with modern styling
          HStack(spacing: 0) {
            Text("Total")
              .font(.appBodyMediumEmphasised)
              .foregroundColor(.text01)
              .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
              .frame(height: 32)
              .padding(.leading, 16)
              .background(Color.surface3)
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
                  .stroke(.outline3, lineWidth: 1))

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
                .background(Color.surface3)
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
                    .stroke(.outline3, lineWidth: 1))
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

  var body: some View {
    VStack(spacing: 12) {
      if userHabits.isEmpty {
        CalendarEmptyStateView(
          title: "No habits yet",
          subtitle: "Create habits to see your monthly progress")
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        // Individual habit tables with monthly heatmaps
        LazyVStack(spacing: 16) {
          ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
            VStack(spacing: 0) {
              // Habit header
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

              // Weekly heatmap table for this habit
              monthlyHeatmapTable(for: habit)

              // Summary statistics row
              summaryStatisticsView(for: habit)
                .padding(.horizontal, 16)
              .padding(.top, 12)
              .padding(.bottom, 16)
            }
            .background(
              RoundedRectangle(cornerRadius: 24)
                .fill(.surface3))
            .overlay(
              RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0))
            .id("month-habit-\(habit.id)-\(index)")
          }
        }
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
  private func monthlyHeatmapTable(for habit: Habit) -> some View {
    VStack(spacing: 0) {
      // Header row with day labels
      HStack(spacing: 0) {
        // Empty cell for top-left corner - must match week label cell exactly
        Rectangle()
          .fill(.clear)
          .frame(minWidth: 0, maxWidth: .infinity)
          .frame(height: 24)
          .background(Color.surface3)
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
              .stroke(.outline3, lineWidth: 1))

        // Day headers - must match heatmap cells exactly
        ForEach(Array(dayHeaders.enumerated()), id: \.offset) { index, day in
          Text(day)
            .font(.appBodyMediumEmphasised)
            .foregroundColor(.text02)
            .frame(width: 24, height: 24)
            .background(Color.surface3)
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
                .stroke(.outline3, lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Week rows with heatmap cells - calculate actual weeks in the selected month
      ForEach(0 ..< numberOfWeeksInMonth, id: \.self) { weekIndex in
        HStack(spacing: 0) {
          // Week label cell - must match empty corner cell exactly
          Text("Week \(weekIndex + 1)")
            .font(.appBodyMedium)
            .foregroundColor(.text01)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .frame(height: 36)
                    .background(.surface3)
            .overlay(
              Rectangle()
                .stroke(.outline3, lineWidth: 1))

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
                    .background(.surface3)
              .overlay(
                Rectangle()
                  .stroke(.outline3, lineWidth: 1))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      // Total row with rounded bottom corners
      HStack(spacing: 0) {
        Text("Total")
          .font(.appBodyMediumEmphasised)
          .foregroundColor(.text01)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
          .frame(height: 32)
          .background(Color.surface3)
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
              .stroke(.outline3, lineWidth: 1))

        ForEach(0 ..< 7, id: \.self) { dayIndex in
          MonthlyTotalEmojiCell(
            habit: habit,
            dayIndex: dayIndex,
            numberOfWeeks: numberOfWeeksInMonth,
            selectedMonth: selectedMonth,
            getMonthlyHeatmapDataForHabit: getMonthlyHeatmapDataForHabit)
            .frame(width: 24, height: 32)
            .background(Color.surface3)
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
                .stroke(.outline3, lineWidth: 1))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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
          .font(.appTitleMedium)
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
          .font(.appTitleMedium)
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
          .font(.appTitleMedium)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(.surfaceContainer)
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
              // Habit header
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

              // Yearly heatmap for this habit
              yearlyHeatmapTable(for: habit, index: index)

              // Summary statistics row
              summaryStatisticsView(for: habit)
                .padding(.horizontal, 16)
              .padding(.top, 12)
              .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 24)
                .fill(.surface3))
            .overlay(
              RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0))
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
          .font(.appTitleMedium)
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
          .font(.appTitleMedium)
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
          .font(.appTitleMedium)
          .foregroundColor(.text01)
        Text("Consistency")
          .font(.appBodySmall)
          .foregroundColor(.text04)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 16)
    .background(.surfaceContainer)
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

// MARK: - WeeklyTotalEmojiCell

struct WeeklyTotalEmojiCell: View {
  // MARK: Internal

  let completionPercentage: Double
  let isScheduled: Bool
  let isUpcoming: Bool
  let dayIndex: Int
  let weekStartDate: Date

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
          .frame(width: 20, height: 20)
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
