//
//  WidgetTimezoneTest.swift
//  Habitto
//
//  Test to demonstrate timezone mismatch between app and widget
//

import Foundation

/// Test to show date key generation differences between app and widget timezones
struct WidgetTimezoneTest {
    
    static func runTest() {
        print("=" * 80)
        print("WIDGET TIMEZONE MISMATCH TEST")
        print("=" * 80)
        print()
        
        // Test cases: Different UTC times that could cause mismatches
        let testCases: [(utcTime: String, description: String)] = [
            ("2026-01-12 18:30:00 +0000", "6:30 PM UTC on Jan 12"),
            ("2026-01-11 23:30:00 +0000", "11:30 PM UTC on Jan 11 (edge case)"),
            ("2026-01-12 00:30:00 +0000", "12:30 AM UTC on Jan 12 (midnight)"),
            ("2026-01-12 22:30:00 +0000", "10:30 PM UTC on Jan 12"),
            ("2026-01-11 22:30:00 +0000", "10:30 PM UTC on Jan 11"),
        ]
        
        // Simulate Amsterdam timezone (UTC+1 in winter, UTC+2 in summer)
        // For January, it's UTC+1
        let amsterdamTimeZone = TimeZone(identifier: "Europe/Amsterdam") ?? TimeZone.current
        let utcTimeZone = TimeZone(secondsFromGMT: 0)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Parse as UTC
        
        for (utcTimeString, description) in testCases {
            guard let testDate = dateFormatter.date(from: utcTimeString) else {
                print("❌ Failed to parse date: \(utcTimeString)")
                continue
            }
            
            print("📅 Test Case: \(description)")
            print("   UTC Time: \(utcTimeString)")
            print()
            
            // Calculate what time it is in Amsterdam
            let amsterdamFormatter = DateFormatter()
            amsterdamFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            amsterdamFormatter.timeZone = amsterdamTimeZone
            let amsterdamTimeString = amsterdamFormatter.string(from: testDate)
            print("   Amsterdam Time: \(amsterdamTimeString)")
            print()
            
            // Generate date keys using both timezones
            let appDateKey = generateDateKey(date: testDate, timeZone: amsterdamTimeZone)
            let widgetDateKey = generateDateKey(date: testDate, timeZone: utcTimeZone)
            
            print("   📱 APP (TimeZone.current ≈ Amsterdam):")
            print("      Timezone: \(amsterdamTimeZone.identifier)")
            print("      Date Key: '\(appDateKey)'")
            print()
            
            print("   📦 WIDGET (UTC):")
            print("      Timezone: UTC")
            print("      Date Key: '\(widgetDateKey)'")
            print()
            
            // Check for mismatch
            if appDateKey != widgetDateKey {
                print("   ⚠️  MISMATCH DETECTED!")
                print("      App stored:    completionStatus['\(appDateKey)'] = true")
                print("      Widget looks:  completionStatus['\(widgetDateKey)'] → NOT FOUND ❌")
                print("      Result: Widget will show incomplete day even though app marked it complete!")
            } else {
                print("   ✅ Keys match - no issue")
            }
            
            print()
            print("-" * 80)
            print()
        }
        
        print("=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print()
        print("The widget uses UTC timezone but the app uses local timezone (TimeZone.current).")
        print("This causes date key mismatches when:")
        print("  - User is in timezone ahead of UTC (e.g., Amsterdam UTC+1)")
        print("  - Time is late evening/night (after 11 PM UTC)")
        print()
        print("FIX: Change widget's formatDateKey() to use TimeZone.current instead of UTC")
        print("=" * 80)
    }
    
    /// Generate date key using specified timezone (simulates DateUtils.dateKey or widget formatDateKey)
    private static func generateDateKey(date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

// Helper extension for string repetition
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
