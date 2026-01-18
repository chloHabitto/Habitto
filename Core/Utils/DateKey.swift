import Foundation

// MARK: - DateKey

/// Utility for generating date keys in Europe/Amsterdam timezone
///
/// ⚠️ **IMPORTANT TIMEZONE NOTE:**
/// This utility intentionally uses "Europe/Amsterdam" timezone for consistency with:
/// - Historical XP data stored in SwiftData
/// - Existing completion records and streak calculations
/// - Backward compatibility with existing data
///
/// **DO NOT change this timezone without:**
/// 1. Creating a comprehensive data migration plan
/// 2. Migrating all existing date keys in SwiftData/Firestore
/// 3. Testing thoroughly with users in different timezones
/// 4. Updating all dependent code (XPManager, HabitComputed, etc.)
///
/// For new code that needs date keys matching the main app's completion data,
/// use `DateUtils.dateKey(for:)` which uses `TimeZone.current`.
///
/// See TIMEZONE_AUDIT_REPORT.md for full analysis of timezone usage across the codebase.
public enum DateKey {
  // MARK: Public

  /// Returns "YYYY-MM-DD" string for a Date in Europe/Amsterdam timezone
  public static func key(for date: Date) -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents(in: amsterdamTimeZone, from: date)

    guard let year = components.year,
          let month = components.month,
          let day = components.day else
    {
      fatalError("Failed to extract date components")
    }

    return String(format: "%04d-%02d-%02d", year, month, day)
  }

  /// Returns the start of day for a given date in Amsterdam timezone
  public static func startOfDay(for date: Date) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents(in: amsterdamTimeZone, from: date)

    guard let year = components.year,
          let month = components.month,
          let day = components.day else
    {
      fatalError("Failed to extract date components")
    }

    var startComponents = DateComponents()
    startComponents.year = year
    startComponents.month = month
    startComponents.day = day
    startComponents.hour = 0
    startComponents.minute = 0
    startComponents.second = 0
    startComponents.timeZone = amsterdamTimeZone

    return calendar.date(from: startComponents) ?? date
  }

  /// Returns the end of day for a given date in Amsterdam timezone
  public static func endOfDay(for date: Date) -> Date {
    let startOfDay = startOfDay(for: date)
    return startOfDay.addingTimeInterval(24 * 60 * 60 - 1)
  }

  // MARK: Private

  private static let amsterdamTimeZone = TimeZone(identifier: "Europe/Amsterdam")!
}

#if DEBUG
extension DateKey {
  /// Test helper for DST edge cases
  public static func testDSTEdgeCases() {
    let formatter = DateFormatter()
    formatter.timeZone = amsterdamTimeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

    // Test DST transition dates for 2024
    let dstStart = formatter.date(from: "2024-03-31 02:00:00")! // DST starts
    let dstEnd = formatter.date(from: "2024-10-27 02:00:00")! // DST ends

    print("DST Start (2024-03-31 02:00): \(key(for: dstStart))")
    print("DST End (2024-10-27 02:00): \(key(for: dstEnd))")

    // Test midnight edge cases
    let midnight = formatter.date(from: "2024-03-31 00:00:00")!
    let justBeforeMidnight = formatter.date(from: "2024-03-30 23:59:59")!
    let justAfterMidnight = formatter.date(from: "2024-03-31 00:00:01")!

    print("Midnight: \(key(for: midnight))")
    print("Just before midnight: \(key(for: justBeforeMidnight))")
    print("Just after midnight: \(key(for: justAfterMidnight))")
  }
}
#endif
