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
              currentMonth = Calendar.current
                .date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }
          }) {
            Image(systemName: "chevron.left")
              .foregroundColor(.text01)
              .frame(width: 44, height: 44)
          }

          Spacer()

          Text(monthYearString(from: currentMonth))
            .font(Font.appTitleMediumEmphasised)
            .foregroundColor(.text01)

          Spacer()

          Button(action: {
            withAnimation {
              currentMonth = Calendar.current
                .date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
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
          // Day headers
          ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
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
                Text("\(Calendar.current.component(.day, from: date))")
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

  /// Helper functions
  private func monthYearString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
  }

  private func daysInMonth() -> [CalendarDay] {
    let calendar = Calendar.current
    let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
    let firstWeekday = calendar.component(.weekday, from: startOfMonth)
    let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0

    var days: [CalendarDay] = []
    var dayIndex = 0

    // Add empty cells for days before the first day of the month
    for _ in 1 ..< firstWeekday {
      days.append(CalendarDay(id: "empty_\(dayIndex)", date: nil))
      dayIndex += 1
    }

    // Add all days in the month
    for day in 1 ... daysInMonth {
      if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
        days.append(CalendarDay(id: "day_\(day)", date: date))
      }
      dayIndex += 1
    }

    // Add empty cells to complete the grid (6 rows * 7 columns = 42 cells)
    while days.count < 42 {
      days.append(CalendarDay(id: "empty_\(dayIndex)", date: nil))
      dayIndex += 1
    }

    return days
  }

  private func dateColor(for date: Date) -> Color {
    let calendar = Calendar.current
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

    let calendar = Calendar.current
    let today = Date()
    return calendar.compare(date, to: today, toGranularity: .day) == .orderedAscending
  }

  private func isDateBeforeOrEqualToStartDate(_ date: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.compare(date, to: startDate, toGranularity: .day) != .orderedDescending
  }

  private func backgroundForDate(_ date: Date) -> Color {
    let calendar = Calendar.current
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
