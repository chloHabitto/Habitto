import SwiftUI

// MARK: - CalendarDay

struct CalendarDay: Identifiable {
  let id: String
  let date: Date?
}

// MARK: - PeriodBottomSheet

struct PeriodBottomSheet: View {
  @ObservedObject private var localizationManager = LocalizationManager.shared

  // MARK: Lifecycle

  init(
    isSelectingStartDate: Bool,
    startDate: Date,
    initialDate: Date = Date(),
    onStartDateSelected: @escaping (Date) -> Void,
    onEndDateSelected: @escaping (Date) -> Void,
    onRemoveEndDate: (() -> Void)? = nil,
    onResetStartDate: (() -> Void)? = nil)
  {
    self.isSelectingStartDate = isSelectingStartDate
    self.startDate = startDate
    self._selectedDate = State(initialValue: initialDate)
    self._currentMonth = State(initialValue: initialDate)
    self.onStartDateSelected = onStartDateSelected
    self.onEndDateSelected = onEndDateSelected
    self.onRemoveEndDate = onRemoveEndDate
    self.onResetStartDate = onResetStartDate
  }

  // MARK: Internal

  let isSelectingStartDate: Bool
  let startDate: Date
  let onStartDateSelected: (Date) -> Void
  let onEndDateSelected: (Date) -> Void
  let onRemoveEndDate: (() -> Void)?
  let onResetStartDate: (() -> Void)?

  var body: some View {
    BaseBottomSheet(
      title: isSelectingStartDate ? "create.label.startDate".localized : "create.label.endDate".localized,
      description: "create.period.title".localized,
      onClose: {
        dismiss()
      },
      useSimpleCloseButton: true,
      confirmButton: {
        if isSelectingStartDate {
          onStartDateSelected(selectedDate)
        } else {
          onEndDateSelected(selectedDate)
        }
        dismiss()
      },
      confirmButtonTitle: "create.button.confirm".localized)
    {
      // Custom Calendar View
      VStack(spacing: 24) {
        // Month Navigation
        HStack {
          Button(action: {
            withAnimation {
              let cal = LocalizationManager.shared.getLocalizedCalendar()
              currentMonth = cal.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
          }) {
            Image(systemName: "chevron.left")
              .foregroundColor(.text01)
              .frame(width: 44, height: 44)
          }

          Spacer()

          Text(LocalizationManager.shared.localizedMonthYear(for: currentMonth))
            .font(Font.appTitleMediumEmphasised)
            .foregroundColor(.text01)

          Spacer()

          Button(action: {
            withAnimation {
              let cal = LocalizationManager.shared.getLocalizedCalendar()
              currentMonth = cal.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }
          }) {
            Image(systemName: "chevron.right")
              .foregroundColor(.text01)
              .frame(width: 44, height: 44)
          }
        }
        .padding(.horizontal, 24)

        // Calendar Grid
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
          // Day headers – localized, respect first day of week
          ForEach(LocalizationManager.shared.localizedWeekdayArray(shortForm: true), id: \.self) { day in
            Text(day)
              .font(Font.appLabelMedium)
              .foregroundColor(.text05)
              .frame(height: 32)
          }

          // Calendar days
          ForEach(daysInMonth()) { calendarDay in
            if let date = calendarDay.date {
              Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) {
                  if isSelectingStartDate {
                    // TEMPORARY: Allow past dates for testing
                    selectedDate = date
                  } else if !isSelectingStartDate, !isDateBeforeOrEqualToStartDate(date) {
                    selectedDate = date
                  }
                }
              }) {
                Text("\(userCalendar.component(.day, from: date))")
                  .font(Font.appBodyMedium)
                  .foregroundColor(dateColor(for: date))
                  .frame(width: 40, height: 40)
                  .background(backgroundForDate(date))
                  .clipShape(Circle())
              }
              .frame(width: 48, height: 48)
              .contentShape(Rectangle())
              .disabled((isSelectingStartDate && false) ||
                (!isSelectingStartDate &&
                  isDateBeforeOrEqualToStartDate(
                    date))) // TEMPORARY: Allow past dates for testing
            } else {
              Color.clear
                .frame(width: 40, height: 40)
            }
          }
        }
        .padding(.horizontal, 24)

        // No End Date button (only show when selecting end date)
        if !isSelectingStartDate {
          Button(action: {
            onRemoveEndDate?()
            dismiss()
          }) {
            HStack {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.text04)
              Text("create.period.noEndDate".localized)
                .font(Font.appBodyLarge)
                .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.surfaceContainer)
            .cornerRadius(12)
          }
          .padding(.horizontal, 24)
        }

        // Reset button (only show when selecting start date)
        if isSelectingStartDate {
          Button(action: {
            onResetStartDate?()
            dismiss()
          }) {
            HStack {
              Image(systemName: "arrow.clockwise")
                .foregroundColor(.text04)
              Text("create.button.reset".localized)
                .font(Font.appBodyLarge)
                .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.surfaceContainer)
            .cornerRadius(12)
          }
          .padding(.horizontal, 24)
        }
      }
      .padding(.vertical, 20)

      Spacer()
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var selectedDate: Date
  @State private var currentMonth: Date

  private var userCalendar: Calendar {
    LocalizationManager.shared.getLocalizedCalendar()
  }

  /// Calendar grid respecting user's first day of week (e.g. Monday vs Sunday).
  private func daysInMonth() -> [CalendarDay] {
    let calendar = userCalendar
    let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
    let firstWeekday = calendar.component(.weekday, from: startOfMonth)
    let daysFromFirstWeekday = (firstWeekday - calendar.firstWeekday + 7) % 7
    let firstDisplayDate = calendar.date(
      byAdding: .day,
      value: -daysFromFirstWeekday,
      to: startOfMonth) ?? startOfMonth

    var days: [CalendarDay] = []
    var currentDate = firstDisplayDate
    for i in 0 ..< 42 {
      let inMonth = calendar.isDate(currentDate, equalTo: currentMonth, toGranularity: .month)
      days.append(CalendarDay(id: "day_\(i)", date: inMonth ? currentDate : nil))
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    return days
  }

  private func dateColor(for date: Date) -> Color {
    let calendar = userCalendar
    let today = Date()

    if calendar.isDate(date, inSameDayAs: selectedDate) {
      return .onPrimary
    } else if calendar.isDate(date, inSameDayAs: today) {
      return .primary
    } else if isSelectingStartDate, isDateInPast(date) {
      // TEMPORARY: Show past dates as normal for testing
      return .text01
    } else if !isSelectingStartDate, isDateBeforeOrEqualToStartDate(date) {
      return .text06
    } else {
      return .text01
    }
  }

  private func isDateInPast(_ date: Date) -> Bool {
    // Use feature flag to control past date behavior
    if FeatureFlags.allowPastDates {
      return false // Allow past dates for testing
    }

    let calendar = userCalendar
    let today = Date()
    return calendar.compare(date, to: today, toGranularity: .day) == .orderedAscending
  }

  private func isDateBeforeOrEqualToStartDate(_ date: Date) -> Bool {
    let calendar = userCalendar
    return calendar.compare(date, to: startDate, toGranularity: .day) != .orderedDescending
  }

  private func backgroundForDate(_ date: Date) -> Color {
    let calendar = userCalendar
    let today = Date()

    if calendar.isDate(date, inSameDayAs: selectedDate) {
      return Color(hex: "1C274C")
    } else if calendar.isDate(date, inSameDayAs: today), !calendar.isDate(
      date,
      inSameDayAs: selectedDate)
    {
      return Color(hex: "1C274C").opacity(0.2)
    } else if isSelectingStartDate, isDateInPast(date) {
      // TEMPORARY: Show past dates as normal for testing
      return Color.clear
    } else {
      return Color.clear
    }
  }
}

#Preview {
  PeriodBottomSheet(
    isSelectingStartDate: true,
    startDate: Date(),
    onStartDateSelected: { _ in },
    onEndDateSelected: { _ in },
    onRemoveEndDate: { })
}
