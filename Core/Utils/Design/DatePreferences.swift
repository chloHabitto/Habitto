import Foundation

// MARK: - DatePreferences

class DatePreferences: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Load saved preferences
    if let savedDateFormat = UserDefaults.standard.string(forKey: "selectedDateFormat"),
       let format = DateFormatOption(rawValue: savedDateFormat)
    {
      self.dateFormat = format
    }

    if let savedFirstDay = UserDefaults.standard.string(forKey: "selectedFirstDay"),
       let firstDay = FirstDayOption(rawValue: savedFirstDay)
    {
      self.firstDayOfWeek = firstDay
    }
  }

  // MARK: Internal

  static let shared = DatePreferences()

  @Published var dateFormat: DateFormatOption = .dayMonthYear {
    didSet {
      UserDefaults.standard.set(dateFormat.rawValue, forKey: "selectedDateFormat")
    }
  }

  @Published var firstDayOfWeek: FirstDayOption = .monday {
    didSet {
      UserDefaults.standard.set(firstDayOfWeek.rawValue, forKey: "selectedFirstDay")
    }
  }
}

// MARK: - DateFormatOption

enum DateFormatOption: String, CaseIterable {
  case dayMonthYear
  case monthDayYear
  case yearMonthDay

  // MARK: Internal

  var example: String {
    switch self {
    case .dayMonthYear:
      "31/Dec/2025"
    case .monthDayYear:
      "Dec/31/2025"
    case .yearMonthDay:
      "2025/Dec/31"
    }
  }

  var description: String {
    switch self {
    case .dayMonthYear:
      "Day/Month/Year"
    case .monthDayYear:
      "Month/Day/Year"
    case .yearMonthDay:
      "Year/Month/Day"
    }
  }

  /// Short date format (for display like "Fri, 9 Aug, 2025")
  var shortDateFormat: String {
    switch self {
    case .dayMonthYear:
      "E, d MMM, yyyy" // Fri, 9 Aug, 2025
    case .monthDayYear:
      "E, MMM d, yyyy" // Fri, Aug 9, 2025
    case .yearMonthDay:
      "yyyy, MMM d, E" // 2025, Aug 13, Wed
    }
  }

  /// Create habit date format (for period section like "13 Aug, 2025" or "Aug 13, 2025")
  var createHabitDateFormat: String {
    switch self {
    case .dayMonthYear:
      "d MMM, yyyy" // 13 Aug, 2025
    case .monthDayYear:
      "MMM d, yyyy" // Aug 13, 2025
    case .yearMonthDay:
      "yyyy, MMM d" // 2025, Aug 13
    }
  }

  /// Numeric date format (for display like "31/12/2025")
  var numericDateFormat: String {
    switch self {
    case .dayMonthYear:
      "dd/MM/yyyy" // 09/08/2025
    case .monthDayYear:
      "MM/dd/yyyy" // 08/09/2025
    case .yearMonthDay:
      "yyyy/MM/dd" // 2025-08-09
    }
  }

  /// Month year format (for display like "August 2025")
  var monthYearFormat: String {
    "MMMM yyyy" // Always same format for month/year
  }

  /// Short date for week ranges (for display like "9 Aug" or "Aug 9")
  var shortDateForWeekRange: String {
    switch self {
    case .dayMonthYear:
      "d MMM" // 9 Aug
    case .monthDayYear:
      "MMM d" // Aug 9
    case .yearMonthDay:
      "MMM d" // Aug 9 (same as month/day for consistency)
    }
  }

  /// Year format (always same)
  var yearFormat: String {
    "yyyy"
  }
}

// MARK: - FirstDayOption

enum FirstDayOption: String, CaseIterable {
  case monday = "Monday"
  case sunday = "Sunday"
}

// MARK: - AppDateFormatter

struct AppDateFormatter {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = AppDateFormatter()

  /// Format date for display in lists, cards, etc.
  func formatDisplayDate(_ date: Date) -> String {
    displayDateFormatter.string(from: date)
  }

  /// Format date numerically (e.g., for compact displays)
  func formatNumericDate(_ date: Date) -> String {
    numericDateFormatter.string(from: date)
  }

  /// Check if date is today (considering user's first day preference)
  func isToday(_ date: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.isDate(date, inSameDayAs: Date())
  }

  /// Format date with "Today" replacement
  func formatDateWithTodayReplacement(_ date: Date) -> String {
    if isToday(date) {
      "Today"
    } else {
      formatDisplayDate(date)
    }
  }

  /// Format date for create habit period section
  func formatCreateHabitDate(_ date: Date) -> String {
    createHabitDateFormatter.string(from: date)
  }

  /// Format month and year (e.g., "August 2025")
  func formatMonthYear(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.monthYearFormat
    return formatter.string(from: date)
  }

  /// Format short date for week ranges (e.g., "9 Aug" or "Aug 9")
  func formatShortDateForWeekRange(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.shortDateForWeekRange
    return formatter.string(from: date)
  }

  /// Format year only (e.g., "2025")
  func formatYear(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.yearFormat
    return formatter.string(from: date)
  }

  /// Format week range (e.g., "9 Aug - 15 Aug")
  func formatWeekRange(startDate: Date, endDate: Date) -> String {
    let startString = formatShortDateForWeekRange(startDate)
    let endString = formatShortDateForWeekRange(endDate)
    return "\(startString) - \(endString)"
  }

  /// Get calendar with user's preferred first day
  func getUserCalendar() -> Calendar {
    var calendar = Calendar.current
    let firstWeekday = DatePreferences.shared.firstDayOfWeek == .monday ? 2 : 1
    calendar.firstWeekday = firstWeekday
    return calendar
  }

  // MARK: Private

  /// Reusable DateFormatter instances to prevent memory leaks
  private var displayDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.shortDateFormat
    return formatter
  }

  private var numericDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.numericDateFormat
    return formatter
  }

  private var createHabitDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = DatePreferences.shared.dateFormat.createHabitDateFormat
    return formatter
  }
}
