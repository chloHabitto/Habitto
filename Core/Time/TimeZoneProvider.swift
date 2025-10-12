//
//  TimeZoneProvider.swift
//  Habitto
//
//  Centralized timezone management for Europe/Amsterdam
//

import Foundation

// MARK: - TimeZoneProvider

/// Protocol for providing timezone (testable via dependency injection)
protocol TimeZoneProvider {
  /// Get the timezone to use for date calculations
  func timeZone() -> TimeZone
}

// MARK: - AmsterdamTimeZoneProvider

/// Production implementation returning Europe/Amsterdam timezone
struct AmsterdamTimeZoneProvider: TimeZoneProvider {
  func timeZone() -> TimeZone {
    TimeZone(identifier: "Europe/Amsterdam") ?? TimeZone.current
  }
}

// MARK: - FixedTimeZoneProvider

/// Test implementation for specific timezone testing
struct FixedTimeZoneProvider: TimeZoneProvider {
  let fixedTimeZone: TimeZone
  
  func timeZone() -> TimeZone {
    fixedTimeZone
  }
}

// MARK: - SystemTimeZoneProvider

/// Implementation that uses system timezone (for comparison testing)
struct SystemTimeZoneProvider: TimeZoneProvider {
  func timeZone() -> TimeZone {
    TimeZone.current
  }
}


