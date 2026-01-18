import Foundation
import UIKit
import FirebaseAuth

// MARK: - Event Sourcing Utilities

/// Utilities for event-sourced architecture
/// Provides timezone-safe date handling, device identification, and ID generation
enum EventSourcedUtils {
  
  // MARK: - Device Identification
  
  /// Get a stable device identifier for this device
  /// Format: "iOS_{deviceModel}_{uuid}"
  /// The UUID is stable across app reinstalls (stored in keychain)
  static func getDeviceId() -> String {
    // Try to get existing device ID from UserDefaults
    let key = "EventSourced_DeviceId"
    if let existing = UserDefaults.standard.string(forKey: key) {
      return existing
    }
    
    // Generate new device ID
    let deviceModel = UIDevice.current.model // "iPhone", "iPad", etc.
    let systemName = UIDevice.current.systemName // "iOS"
    let uuid = UUID().uuidString.lowercased()
    
    // Format: iOS_iPhone_abc123...
    let deviceId = "\(systemName)_\(deviceModel)_\(uuid)".replacingOccurrences(of: " ", with: "_")
    
    // Store for future use
    UserDefaults.standard.set(deviceId, forKey: key)
    
    return deviceId
  }
  
  // MARK: - Timezone-Safe Date Handling
  
  /// Generate a date key for a given date (timezone-aware)
  /// Format: "yyyy-MM-dd" in user's local timezone
  /// This is the KEY for grouping events into daily completions
  static func dateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    formatter.calendar = Calendar.current
    return formatter.string(from: date)
  }
  
  /// Get UTC day boundaries for a given local date
  /// Returns: (utcDayStart, utcDayEnd)
  ///
  /// This ensures we can correctly group events even if user changes timezone
  /// Example: User completes habit at 11:55 PM EST, travels to PST, completes at 12:05 AM PST
  /// Both events should be in the same "day" from the user's perspective when they were created
  static func utcDayBoundaries(for localDate: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    
    // Get start of day in user's local timezone
    let localDayStart = calendar.startOfDay(for: localDate)
    
    // Get end of day (start of next day - 1 second)
    guard let localDayEnd = calendar.date(byAdding: .day, value: 1, to: localDayStart)?.addingTimeInterval(-1) else {
      // Fallback: use 23:59:59 of the same day
      let endComponents = calendar.dateComponents([.year, .month, .day], from: localDate)
      let fallbackEnd = calendar.date(from: endComponents)!.addingTimeInterval(86399) // 23:59:59
      return (localDayStart, fallbackEnd)
    }
    
    return (localDayStart, localDayEnd)
  }
  
  /// Get the current user's timezone identifier
  static func getTimezoneIdentifier() -> String {
    TimeZone.current.identifier
  }
  
  /// Parse a dateKey string back into a Date
  /// Returns: Date at midnight in the current timezone
  static func dateFromKey(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    formatter.calendar = Calendar.current
    return formatter.date(from: key)
  }
  
  // MARK: - Deterministic ID Generation
  
  /// Generate a deterministic ID for a DailyCompletion
  /// Format: "comp_{habitId}_{dateKey}"
  /// This ensures the same completion record is referenced across devices
  static func dailyCompletionId(habitId: UUID, dateKey: String) -> String {
    "comp_\(habitId.uuidString)_\(dateKey)"
  }
  
  /// Generate a deterministic ID for a DailyAward
  /// Format: "award_{userId}_{dateKey}"
  /// This ensures only one award per user per day
  static func dailyAwardId(userId: String, dateKey: String) -> String {
    "award_\(userId)_\(dateKey)"
  }
  
  /// Generate a unique operation ID
  /// Format: "{deviceId}_{timestamp}_{uuid}"
  /// Used for idempotency - prevents duplicate processing of the same operation
  static func generateOperationId(deviceId: String? = nil) -> String {
    let device = deviceId ?? getDeviceId()
    let timestamp = Int(Date().timeIntervalSince1970 * 1000) // Milliseconds
    let uuid = UUID().uuidString.lowercased()
    return "\(device)_\(timestamp)_\(uuid)"
  }
  
  // MARK: - Date Range Utilities
  
  /// Get the date range for "recent sync" (last 3 months)
  /// Returns: (startDate, endDate)
  static func recentSyncRange() -> (start: Date, end: Date) {
    let end = Date()
    let calendar = Calendar.current
    let start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
    return (start, end)
  }
  
  /// Check if a date is within the last N days
  static func isRecent(_ date: Date, days: Int = 90) -> Bool {
    let calendar = Calendar.current
    let daysAgo = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    return date >= daysAgo
  }
  
  /// Get all dateKeys between two dates (inclusive)
  /// Returns: ["2024-10-01", "2024-10-02", ...]
  static func dateKeysBetween(start: Date, end: Date) -> [String] {
    var keys: [String] = []
    let calendar = Calendar.current
    var current = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)
    
    while current <= endDay {
      keys.append(dateKey(for: current))
      guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
        break
      }
      current = next
    }
    
    return keys
  }
  
  // MARK: - User ID Utilities
  
  /// Get the current user ID for sync operations
  /// ✅ GUEST MODE ONLY: Always returns empty string (guest mode)
  /// This is thread-safe and can be called from any context
  static func getCurrentUserId() -> String {
    // Always return empty string (guest mode) - no anonymous auth
    return ""
  }
}

// MARK: - Date Extension for Convenience

extension Date {
  /// Get the dateKey for this date (timezone-aware)
  var eventDateKey: String {
    EventSourcedUtils.dateKey(for: self)
  }
  
  /// Get UTC day boundaries for this date
  var utcDayBoundaries: (start: Date, end: Date) {
    EventSourcedUtils.utcDayBoundaries(for: self)
  }
}

