import Foundation

// MARK: - ISO8601DateHelper

/// ISO 8601 date formatting utilities for consistent date handling across the app
class ISO8601DateHelper {
  // MARK: Lifecycle

  private init() {
    // Standard ISO 8601 formatter
    self.iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]

    // ISO 8601 with fractional seconds for high precision
    self.iso8601WithFractionalSecondsFormatter = ISO8601DateFormatter()
    iso8601WithFractionalSecondsFormatter.formatOptions = [
      .withInternetDateTime,
      .withDashSeparatorInDate,
      .withFractionalSeconds
    ]
  }

  // MARK: Internal

  static let shared = ISO8601DateHelper()

  // MARK: - Date to String Conversion

  /// Convert Date to ISO 8601 string (standard format)
  func string(from date: Date) -> String {
    iso8601Formatter.string(from: date)
  }

  /// Convert Date to ISO 8601 string with fractional seconds
  func stringWithFractionalSeconds(from date: Date) -> String {
    iso8601WithFractionalSecondsFormatter.string(from: date)
  }

  /// Convert Date to ISO 8601 string for storage (UTC timezone)
  func storageString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
  }

  // MARK: - String to Date Conversion

  /// Convert ISO 8601 string to Date (standard format)
  func date(from string: String) -> Date? {
    iso8601Formatter.date(from: string)
  }

  /// Convert ISO 8601 string with fractional seconds to Date
  func dateWithFractionalSeconds(from string: String) -> Date? {
    iso8601WithFractionalSecondsFormatter.date(from: string)
  }

  /// Convert ISO 8601 string to Date with fallback parsing
  func dateWithFallback(from string: String) -> Date? {
    // Try standard format first
    if let date = iso8601Formatter.date(from: string) {
      return date
    }

    // Try with fractional seconds
    if let date = iso8601WithFractionalSecondsFormatter.date(from: string) {
      return date
    }

    // Try with different timezone formats
    let formatters = [
      createFormatter(options: [.withInternetDateTime, .withDashSeparatorInDate]),
      createFormatter(options: [
        .withInternetDateTime,
        .withDashSeparatorInDate,
        .withFractionalSeconds
      ]),
      createFormatter(options: [
        .withInternetDateTime,
        .withDashSeparatorInDate,
        .withColonSeparatorInTime
      ])
    ]

    for formatter in formatters {
      if let date = formatter.date(from: string) {
        return date
      }
    }

    return nil
  }

  /// Get current date as ISO 8601 string
  func currentDateString() -> String {
    string(from: Date())
  }

  /// Get current date as ISO 8601 string with fractional seconds
  func currentDateStringWithFractionalSeconds() -> String {
    stringWithFractionalSeconds(from: Date())
  }

  /// Validate if a string is a valid ISO 8601 date
  func isValidISO8601Date(_ string: String) -> Bool {
    dateWithFallback(from: string) != nil
  }

  // MARK: Private

  private let iso8601Formatter: ISO8601DateFormatter
  private let iso8601WithFractionalSecondsFormatter: ISO8601DateFormatter

  // MARK: - Helper Methods

  private func createFormatter(options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = options
    return formatter
  }
}

// MARK: - Convenience Extensions

extension Date {
  /// Convert Date to ISO 8601 string using the shared helper
  var iso8601String: String {
    ISO8601DateHelper.shared.string(from: self)
  }

  /// Convert Date to ISO 8601 string with fractional seconds
  var iso8601StringWithFractionalSeconds: String {
    ISO8601DateHelper.shared.stringWithFractionalSeconds(from: self)
  }

  /// Convert Date to ISO 8601 string for storage (UTC)
  var iso8601StorageString: String {
    ISO8601DateHelper.shared.storageString(from: self)
  }
}

extension String {
  /// Convert ISO 8601 string to Date using the shared helper
  var iso8601Date: Date? {
    ISO8601DateHelper.shared.dateWithFallback(from: self)
  }

  /// Check if string is a valid ISO 8601 date
  var isValidISO8601Date: Bool {
    ISO8601DateHelper.shared.isValidISO8601Date(self)
  }
}
