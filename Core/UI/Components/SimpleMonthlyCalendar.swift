import SwiftUI

// MARK: - Simple Monthly Calendar

struct SimpleMonthlyCalendar: View {
  // MARK: Internal

  @Binding var selectedDate: Date

  let userHabits: [Habit]

  var body: some View {
    VStack(spacing: 16) {
      // Month/Year Header with navigation buttons
      HStack {
        // Month/Year text aligned to the left
        Text(monthYearString)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)

        Spacer()

        // Today button on the right (shown when not on current month)
        if showingTodayButton {
          Button(action: {
            goToToday()
          }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
              Text("Today")
                .font(.appLabelMedium)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(16)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .frame(height: 44) // Fixed height to prevent layout shifts
      .padding(.horizontal, 20)
      .padding(.top, 16)

      // Days of week header
      HStack(spacing: 0) {
        ForEach(weekdayNames, id: \.self) { day in
          Text(day)
            .font(.appLabelMedium)
            .foregroundColor(.text04)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 8)

      // Calendar grid with swipe gestures
      VStack(spacing: 8) {
        ForEach(0 ..< 6, id: \.self) { weekIndex in
          HStack(spacing: 0) {
            ForEach(0 ..< 7, id: \.self) { dayIndex in
              let dateIndex = (weekIndex * 7) + dayIndex
              let date = calendarDays[dateIndex]

              if let date {
                let calendar = AppDateFormatter.shared.getUserCalendar()
                let day = calendar.component(.day, from: date)
                let isCurrentMonth = calendar.isDate(
                  date,
                  equalTo: currentMonth,
                  toGranularity: .month)
                let isToday = calendar.isDate(date, inSameDayAs: Date())
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let completionPercentage = calculateCompletionPercentage(for: date)

                CalendarGridComponents.CalendarDayCell(
                  day: day,
                  progress: completionPercentage,
                  isToday: isToday,
                  isSelected: isSelected,
                  isCurrentMonth: isCurrentMonth,
                  isVacationDay: false,
                  onTap: {
                    selectedDate = date
                  })
                  .frame(maxWidth: .infinity)
              } else {
                Color.clear
                  .frame(width: 40, height: 40)
                  .frame(maxWidth: .infinity)
              }
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
      .animation(.easeInOut(duration: 0.3), value: currentMonth)
      .offset(x: dragOffset)
      .simultaneousGesture(
        DragGesture(minimumDistance: 20)
          .onChanged { value in
            // Only start visual feedback if drag is significant
            if abs(value.translation.width) > 10 {
              dragOffset = value.translation
                .width * 0.3 // Scale down the movement for subtle effect
            }
          }
          .onEnded { value in
            let threshold: CGFloat = 50
            let velocity = value.velocity.width

            // Reset drag offset with animation
            withAnimation(.easeOut(duration: 0.2)) {
              dragOffset = 0
            }

            // Only change month if drag was significant
            if abs(value.translation.width) > threshold || abs(velocity) > 500 {
              if value.translation.width > 0 {
                // Swipe right - go to previous month
                print("📅 Calendar: Swipe right detected - going to previous month")
                withAnimation(.easeInOut(duration: 0.3)) {
                  changeMonth(by: -1)
                }
              } else {
                // Swipe left - go to next month
                print("📅 Calendar: Swipe left detected - going to next month")
                withAnimation(.easeInOut(duration: 0.3)) {
                  changeMonth(by: 1)
                }
              }
            } else {
              print(
                "📅 Calendar: Swipe gesture too small - translation: \(value.translation.width), velocity: \(velocity)")
            }
          })
    }
    .background(.surface3)
    .cornerRadius(24)
    .onAppear {
      updateTodayButtonVisibility()
    }
  }

  // MARK: - Month Navigation

  func changeMonth(by value: Int) {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
      currentMonth = newMonth
      updateTodayButtonVisibility()
    }
  }

  // MARK: Private

  @State private var currentMonth = Date()
  @State private var showingTodayButton = false
  @State private var dragOffset: CGFloat = 0

  private var weekdayNames: [String] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    if calendar.firstWeekday == 1 { // Sunday
      return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    } else { // Monday
      return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
  }

  // MARK: - Helper Properties and Functions

  private var monthYearString: String {
    AppDateFormatter.shared.formatMonthYear(currentMonth)
  }

  private var calendarDays: [Date?] {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth

    // Find the first day of the week based on user preference
    let firstWeekday = calendar.component(.weekday, from: startOfMonth)
    let daysFromFirstWeekday = (firstWeekday - calendar.firstWeekday + 7) % 7
    let firstDisplayDate = calendar.date(
      byAdding: .day,
      value: -daysFromFirstWeekday,
      to: startOfMonth) ?? startOfMonth

    var days: [Date?] = []
    var currentDate = firstDisplayDate

    // Generate 42 days (6 weeks)
    for _ in 0 ..< 42 {
      days.append(currentDate)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }

    return days
  }

  // MARK: - Completion Percentage Calculation

  private func calculateCompletionPercentage(for date: Date) -> Double {
    guard !userHabits.isEmpty else { return 0.0 }

    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = calendar.startOfDay(for: Date())
    let targetDate = calendar.startOfDay(for: date)

    // Don't show progress for future dates
    if targetDate > today {
      return 0.0
    }

    var totalScheduled = 0
    var totalCompleted = 0

    for habit in userHabits {
      if StreakDataCalculator.shouldShowHabitOnDate(habit, date: targetDate) {
        totalScheduled += 1
        if habit.isCompleted(for: targetDate) {
          totalCompleted += 1
        }
      }
    }

    if totalScheduled == 0 {
      return 0.0
    }

    return Double(totalCompleted) / Double(totalScheduled)
  }

  private func goToToday() {
    let today = Date()
    _ = AppDateFormatter.shared.getUserCalendar()

    currentMonth = today
    selectedDate = today
    updateTodayButtonVisibility()
  }

  private func updateTodayButtonVisibility() {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = Date()
    let isCurrentMonth = calendar.isDate(today, equalTo: currentMonth, toGranularity: .month)

    withAnimation(.easeInOut(duration: 0.2)) {
      showingTodayButton = !isCurrentMonth
    }
  }
}
