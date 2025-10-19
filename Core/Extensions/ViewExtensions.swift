import SwiftUI

// MARK: - PerformanceOptimizer

enum PerformanceOptimizer {
  /// Debounce function to limit frequent updates
  static func debounce<T>(interval: TimeInterval, action: @escaping (T) -> Void) -> (T) -> Void {
    var timer: Timer?
    return { value in
      timer?.invalidate()
      timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
        action(value)
      }
    }
  }

  /// Throttle function to limit execution frequency
  static func throttle<T>(interval: TimeInterval, action: @escaping (T) -> Void) -> (T) -> Void {
    var lastExecutionTime: TimeInterval = 0
    return { value in
      let currentTime = Date().timeIntervalSinceReferenceDate
      if currentTime - lastExecutionTime >= interval {
        action(value)
        lastExecutionTime = currentTime
      }
    }
  }
}

// MARK: - View Performance Modifiers

extension View {
  /// Optimize view updates by conditionally applying modifiers
  func conditionalModifier(_ condition: Bool, _ modifier: some ViewModifier) -> some View {
    Group {
      if condition {
        self.modifier(modifier)
      } else {
        self
      }
    }
  }

  /// Optimize expensive view calculations
  func optimized(_ content: @escaping () -> some View) -> some View {
    background(content())
  }

  /// Reduce view updates with equality check
  func equalityCheck<T: Equatable>(_ value: T, action: @escaping (T) -> Void) -> some View {
    onChange(of: value) { _, newValue in
      action(newValue)
    }
  }
}

// MARK: - LegacyDateUtils

enum LegacyDateUtils {
  // MARK: Internal

  static let calendar = Calendar.current

  // MARK: - Robust Today's Date Calculation

  static func today() -> Date {
    let now = Date()
    print("🔍 LegacyDateUtils.today() - Raw Date(): \(now)")
    print("🔍 LegacyDateUtils.today() - Current timezone: \(TimeZone.current)")

    // Get today's date components in the current timezone
    let components = calendar.dateComponents([.year, .month, .day], from: now)
    let today = calendar.date(from: components) ?? now

    print("🔍 LegacyDateUtils.today() - Calculated today: \(today)")
    print("🔍 LegacyDateUtils.today() - Today components: \(components)")

    return today
  }

  /// Force refresh today's date (useful for debugging timezone issues)
  static func forceRefreshToday() -> Date {
    print("🔄 LegacyDateUtils.forceRefreshToday() - Clearing date cache and recalculating...")
    clearDateCache()

    // Force timezone refresh
    let now = Date()
    var robustCalendar = Calendar.current
    robustCalendar.timeZone = TimeZone.current
    robustCalendar.locale = Locale.current

    let today = robustCalendar.startOfDay(for: now)
    print("🔄 LegacyDateUtils.forceRefreshToday() - New today: \(today)")
    print(
      "🔄 LegacyDateUtils.forceRefreshToday() - New components: \(robustCalendar.dateComponents([.year, .month, .day], from: today))")

    return today
  }

  static func startOfDay(for date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  static func endOfDay(for date: Date) -> Date {
    calendar.date(byAdding: .day, value: 1, to: startOfDay(for: date)) ?? date
  }

  static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    calendar.isDate(date1, inSameDayAs: date2)
  }

  static func daysBetween(_ startDate: Date, _ endDate: Date) -> Int {
    let components = calendar.dateComponents(
      [.day],
      from: startOfDay(for: startDate),
      to: startOfDay(for: endDate))
    return components.day ?? 0
  }

  static func weeksBetween(_ startDate: Date, _ endDate: Date) -> Int {
    // Calculate actual weeks between dates, not week number difference
    let startOfStartWeek = calendar.dateInterval(of: .weekOfYear, for: startOfDay(for: startDate))?
      .start ?? startOfDay(for: startDate)
    let startOfEndWeek = calendar.dateInterval(of: .weekOfYear, for: startOfDay(for: endDate))?
      .start ?? startOfDay(for: endDate)

    let components = calendar.dateComponents([.day], from: startOfStartWeek, to: startOfEndWeek)
    let daysBetween = components.day ?? 0
    return daysBetween / 7
  }

  static func isDateInPast(_ date: Date) -> Bool {
    date < startOfDay(for: Date())
  }

  static func isDateBeforeOrEqualToStartDate(_ date: Date, _ startDate: Date) -> Bool {
    startOfDay(for: date) <= startOfDay(for: startDate)
  }

  static func dateKey(for date: Date) -> String {
    dateKeyFormatter.string(from: date)
  }

  static func weekday(for date: Date) -> Int {
    calendar.component(.weekday, from: date)
  }

  static func startOfWeek(for date: Date) -> Date {
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components) ?? date
  }

  static func endOfWeek(for date: Date) -> Date {
    let startOfWeek = startOfWeek(for: date)
    return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
  }

  static func debugString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func cachedStartOfDay(for date: Date) -> Date {
    let key = "start_\(date.timeIntervalSince1970)"
    if let cached = dateCache[key] {
      return cached
    }
    let result = startOfDay(for: date)
    dateCache[key] = result
    return result
  }

  static func clearDateCache() {
    dateCache.removeAll()
  }

  // MARK: Private

  /// Performance optimization: Cache date calculations
  private static var dateCache: [String: Date] = [:]

  /// Performance optimization: Use cached formatter for date keys
  private static let dateKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    // ✅ FIX #14: Set timezone and calendar to prevent year 742 bug
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current  // ✅ FIX #15: Corrected typo (timeZone not timezone)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  /// Performance optimization: Use cached formatter for debug output
  private static let debugFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

// MARK: - Array Performance Extensions

extension Array {
  /// Optimized filtering with early exit
  func optimizedFilter(_ predicate: (Element) -> Bool) -> [Element] {
    var result: [Element] = []
    result.reserveCapacity(count / 2) // Pre-allocate space for better performance

    for element in self {
      if predicate(element) {
        result.append(element)
      }
    }
    return result
  }

  /// Optimized mapping with pre-allocated capacity
  func optimizedMap<T>(_ transform: (Element) -> T) -> [T] {
    var result: [T] = []
    result.reserveCapacity(count)

    for element in self {
      result.append(transform(element))
    }
    return result
  }
}

// MARK: - String Performance Extensions

extension String {
  // MARK: Internal

  /// Optimized string operations
  var optimizedLowercased: String {
    lowercased()
  }

  var optimizedTrimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func cachedLowercase(_ string: String) -> String {
    if let cached = stringCache[string] {
      return cached
    }
    let result = string.lowercased()
    stringCache[string] = result
    return result
  }

  static func clearStringCache() {
    stringCache.removeAll()
  }

  // MARK: Private

  /// Cache for expensive string operations
  private static var stringCache: [String: String] = [:]
}

// MARK: - View Extensions

extension View {
  func roundedTopBackground() -> some View {
    background(Color.white)
      .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
  }
}

// MARK: - RoundedCorner

struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius))
    return Path(path.cgPath)
  }
}
