//
//  NowProvider.swift
//  Habitto
//
//  Deterministic time handling for testability
//

import Foundation

// MARK: - NowProvider

/// Protocol for providing current time (testable via dependency injection)
protocol NowProvider {
  /// Get the current date/time
  func now() -> Date
}

// MARK: - SystemNowProvider

/// Production implementation that returns actual system time
struct SystemNowProvider: NowProvider {
  func now() -> Date {
    Date()
  }
}

// MARK: - FixedNowProvider

/// Test implementation that returns a fixed time
struct FixedNowProvider: NowProvider {
  let fixedDate: Date
  
  func now() -> Date {
    fixedDate
  }
}

// MARK: - OffsetNowProvider

/// Test implementation that offsets from system time
struct OffsetNowProvider: NowProvider {
  let offset: TimeInterval
  
  func now() -> Date {
    Date().addingTimeInterval(offset)
  }
}


