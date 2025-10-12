//
//  LocalDateFormatter.swift
//  Habitto
//
//  Date ↔ "YYYY-MM-DD" conversions in Europe/Amsterdam timezone
//

import Foundation

// MARK: - LocalDateFormatter

/// Handles conversion between Date and "YYYY-MM-DD" strings in a specific timezone
struct LocalDateFormatter {
  // MARK: Lifecycle
  
  init(
    nowProvider: NowProvider = SystemNowProvider(),
    timeZoneProvider: TimeZoneProvider = AmsterdamTimeZoneProvider())
  {
    self.nowProvider = nowProvider
    self.timeZoneProvider = timeZoneProvider
    
    // Configure ISO 8601 formatter for "YYYY-MM-DD"
    self.formatter = DateFormatter()
    self.formatter.dateFormat = "yyyy-MM-dd"
    self.formatter.locale = Locale(identifier: "en_US_POSIX")
    self.formatter.timeZone = timeZoneProvider.timeZone()
  }
  
  // MARK: Internal
  
  let nowProvider: NowProvider
  let timeZoneProvider: TimeZoneProvider
  
  /// Convert Date to "YYYY-MM-DD" string in configured timezone
  func dateToString(_ date: Date) -> String {
    formatter.string(from: date)
  }
  
  /// Convert "YYYY-MM-DD" string to Date at midnight in configured timezone
  func stringToDate(_ string: String) -> Date? {
    formatter.date(from: string)
  }
  
  /// Get current local date as "YYYY-MM-DD" string
  func today() -> String {
    dateToString(nowProvider.now())
  }
  
  /// Get current Date at start of day (midnight) in configured timezone
  func todayDate() -> Date {
    let todayString = today()
    return stringToDate(todayString) ?? nowProvider.now()
  }
  
  /// Check if two dates are on the same local day
  func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    dateToString(date1) == dateToString(date2)
  }
  
  /// Add days to a date string
  func addDays(_ days: Int, to dateString: String) -> String? {
    guard let date = stringToDate(dateString) else { return nil }
    let calendar = Calendar(identifier: .gregorian)
    guard let newDate = calendar.date(byAdding: .day, value: days, to: date) else {
      return nil
    }
    return dateToString(newDate)
  }
  
  /// Get start of day (midnight) for a given date in configured timezone
  func startOfDay(_ date: Date) -> Date {
    let dateString = dateToString(date)
    return stringToDate(dateString) ?? date
  }
  
  // MARK: Private
  
  private let formatter: DateFormatter
}

// MARK: - DST Testing Helpers

extension LocalDateFormatter {
  /// Test helper: Check if a date is during DST transition
  func isDSTTransition(_ date: Date) -> Bool {
    let tz = timeZoneProvider.timeZone()
    let nextDay = date.addingTimeInterval(86400) // +24 hours
    return tz.secondsFromGMT(for: date) != tz.secondsFromGMT(for: nextDay)
  }
  
  /// Test helper: Get DST offset for a date
  func dstOffset(_ date: Date) -> Int {
    Int(timeZoneProvider.timeZone().daylightSavingTimeOffset(for: date))
  }
}

