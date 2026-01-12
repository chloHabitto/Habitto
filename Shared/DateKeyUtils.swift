//
//  DateKeyUtils.swift
//  Habitto
//
//  Shared date key utility for app and widget extension
//  This file is included in BOTH the main app target AND HabittoWidgetExtension target
//

import Foundation

// MARK: - CRITICAL TIMEZONE WARNING
//
// ⚠️ DO NOT CHANGE THE TIMEZONE IN THIS FILE ⚠️
//
// This utility MUST use TimeZone.current to match:
// - Core/Utils/DateUtils.dateKey() (main app)
// - Habit.dateKey(for:) (completion data storage)
//
// Changing to UTC or any hardcoded timezone will cause:
// - Widget showing wrong completion status (off-by-one-day errors)
// - Date key mismatches between app and widget
// - User data appearing on wrong dates
//
// Reference: TIMEZONE_AUDIT_REPORT.md (2026-01-12)
// Bug Fix: Widget timezone mismatch causing completion data lookup failures
//
// If you need to change timezone handling, you MUST:
// 1. Update DateUtils.dateKey() in Core/Utils/DateUtils.swift
// 2. Update this file to match
// 3. Test widget date key generation matches app
// 4. Update TIMEZONE_AUDIT_REPORT.md

/// Shared date key utility for consistent date key generation across app and widget
/// 
/// This utility generates date keys in "yyyy-MM-dd" format using the device's local timezone.
/// It is used by both the main app and widget extension to ensure date keys match.
///
/// **Usage:**
/// ```swift
/// let dateKey = DateKeyUtils.dateKey(for: Date())
/// // Returns: "2026-01-12" (in user's local timezone)
/// ```
public struct DateKeyUtils {
    /// Shared DateFormatter instance configured for date key generation
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // ✅ CRITICAL: Must use TimeZone.current to match DateUtils.dateKey()
        // This ensures app and widget generate identical date keys
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX") // Prevent locale issues
        return formatter
    }()
    
    /// Generate date key in format "yyyy-MM-dd" using local timezone
    ///
    /// This matches the behavior of `DateUtils.dateKey(for:)` in the main app.
    /// The widget uses this to ensure date keys match what the app stored.
    ///
    /// - Parameter date: The date to convert to a date key
    /// - Returns: Date key string in format "yyyy-MM-dd" (e.g., "2026-01-12")
    public static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    /// Parse date key back to Date
    ///
    /// Converts a date key string (e.g., "2026-01-12") back to a Date object
    /// at midnight in the local timezone.
    ///
    /// - Parameter dateKey: Date key string in format "yyyy-MM-dd"
    /// - Returns: Date object at midnight in local timezone, or nil if invalid format
    public static func date(from dateKey: String) -> Date? {
        dateFormatter.date(from: dateKey)
    }
}
