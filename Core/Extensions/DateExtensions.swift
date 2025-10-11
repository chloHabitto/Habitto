import Foundation

extension Date {
  static func currentWeekStartDate() -> Date {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let today = Date()
    // Get the start of the current week (using user's preference)
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    return weekStart
  }

  static func currentMonthStartDate() -> Date {
    let calendar = Calendar.current
    let today = Date()
    // Get the start of the current month
    let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
    return monthStart
  }

  func weekRangeText() -> String {
    let calendar = AppDateFormatter.shared.getUserCalendar()
    let weekEndDate = calendar.date(byAdding: .day, value: 6, to: self) ?? self

    return AppDateFormatter.shared.formatWeekRange(startDate: self, endDate: weekEndDate)
  }

  func monthText() -> String {
    AppDateFormatter.shared.formatMonthYear(self)
  }
}
