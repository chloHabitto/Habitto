import Foundation

/// Date utility functions for consistent date handling across the app
struct DateUtils {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Convert date to "yyyy-MM-dd" string
    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    /// Convert "yyyy-MM-dd" string to date
    static func date(from dateKey: String) -> Date? {
        dateFormatter.date(from: dateKey)
    }
    
    /// Get start of day for date
    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    /// Get end of day for date
    static func endOfDay(for date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? date
    }
    
    /// Get start of week (Monday) for date
    static func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Get end of week (Sunday) for date
    static func endOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return date
        }
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
    }
    
    /// Calculate days between two dates
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}

