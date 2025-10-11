import Foundation

/// Comprehensive date utilities for consistent date handling across the app
@MainActor
class DateUtilities {
    static let shared = DateUtilities()
    
    private let calendar: Calendar
    private let iso8601Helper = ISO8601DateHelper.shared
    
    private init() {
        // Use the user's preferred calendar
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
    }
    
    // MARK: - Date Creation and Parsing
    
    /// Create a date from components
    func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)
    }
    
    /// Create a date from a string with multiple format support
    func date(from string: String) -> Date? {
        // Try ISO 8601 first
        if let date = iso8601Helper.dateWithFallback(from: string) {
            return date
        }
        
        // Try common date formats
        let formatters = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "MMM dd, yyyy",
            "MMMM dd, yyyy",
            "EEEE, MMMM dd, yyyy"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale.current
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
    
    /// Get current date
    var now: Date {
        return Date()
    }
    
    /// Get current date as start of day
    var today: Date {
        return startOfDay(for: now)
    }
    
    // MARK: - Date Components
    
    /// Get start of day for a date
    func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    /// Get end of day for a date
    func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
    
    /// Get start of week for a date
    func startOfWeek(for date: Date) -> Date {
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
    
    /// Get end of week for a date
    func endOfWeek(for date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return date }
        return calendar.date(byAdding: .second, value: -1, to: interval.end) ?? date
    }
    
    /// Get start of month for a date
    func startOfMonth(for date: Date) -> Date {
        return calendar.dateInterval(of: .month, for: date)?.start ?? date
    }
    
    /// Get end of month for a date
    func endOfMonth(for date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return date }
        return calendar.date(byAdding: .second, value: -1, to: interval.end) ?? date
    }
    
    /// Get start of year for a date
    func startOfYear(for date: Date) -> Date {
        return calendar.dateInterval(of: .year, for: date)?.start ?? date
    }
    
    /// Get end of year for a date
    func endOfYear(for date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .year, for: date) else { return date }
        return calendar.date(byAdding: .second, value: -1, to: interval.end) ?? date
    }
    
    // MARK: - Date Arithmetic
    
    /// Add days to a date
    func addDays(_ days: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
    
    /// Add weeks to a date
    func addWeeks(_ weeks: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }
    
    /// Add months to a date
    func addMonths(_ months: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
    
    /// Add years to a date
    func addYears(_ years: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .year, value: years, to: date) ?? date
    }
    
    /// Get days between two dates
    func daysBetween(_ startDate: Date, and endDate: Date) -> Int {
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day ?? 0
    }
    
    /// Get weeks between two dates
    func weeksBetween(_ startDate: Date, and endDate: Date) -> Int {
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
        return components.weekOfYear ?? 0
    }
    
    /// Get months between two dates
    func monthsBetween(_ startDate: Date, and endDate: Date) -> Int {
        let components = calendar.dateComponents([.month], from: startDate, to: endDate)
        return components.month ?? 0
    }
    
    // MARK: - Date Comparison
    
    /// Check if two dates are the same day
    func isSameDay(_ date1: Date, as date2: Date) -> Bool {
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    /// Check if two dates are the same week
    func isSameWeek(_ date1: Date, as date2: Date) -> Bool {
        return calendar.isDate(date1, equalTo: date2, toGranularity: .weekOfYear)
    }
    
    /// Check if two dates are the same month
    func isSameMonth(_ date1: Date, as date2: Date) -> Bool {
        return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
    }
    
    /// Check if two dates are the same year
    func isSameYear(_ date1: Date, as date2: Date) -> Bool {
        return calendar.isDate(date1, equalTo: date2, toGranularity: .year)
    }
    
    /// Check if a date is today
    func isToday(_ date: Date) -> Bool {
        return isSameDay(date, as: now)
    }
    
    /// Check if a date is yesterday
    func isYesterday(_ date: Date) -> Bool {
        return isSameDay(date, as: addDays(-1, to: now))
    }
    
    /// Check if a date is tomorrow
    func isTomorrow(_ date: Date) -> Bool {
        return isSameDay(date, as: addDays(1, to: now))
    }
    
    /// Check if a date is in the past
    func isPast(_ date: Date) -> Bool {
        return date < now
    }
    
    /// Check if a date is in the future
    func isFuture(_ date: Date) -> Bool {
        return date > now
    }
    
    // MARK: - Date Formatting
    
    /// Format a date with a custom format
    func format(_ date: Date, with format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    /// Format a date for display (e.g., "Jan 15, 2024")
    func displayString(for date: Date) -> String {
        return format(date, with: "MMM dd, yyyy")
    }
    
    /// Format a date for short display (e.g., "1/15/24")
    func shortDisplayString(for date: Date) -> String {
        return format(date, with: "M/d/yy")
    }
    
    /// Format a date for time display (e.g., "2:30 PM")
    func timeString(for date: Date) -> String {
        return format(date, with: "h:mm a")
    }
    
    /// Format a date for relative display (e.g., "2 days ago", "in 3 hours")
    func relativeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
    
    /// Format a date for relative display with abbreviated units
    func shortRelativeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
    
    // MARK: - Week and Month Utilities
    
    /// Get all days in a week for a given date
    func daysInWeek(for date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        
        var days: [Date] = []
        var currentDate = weekInterval.start
        
        while currentDate < weekInterval.end {
            days.append(currentDate)
            currentDate = addDays(1, to: currentDate)
        }
        
        return days
    }
    
    /// Get all days in a month for a given date
    func daysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        
        var days: [Date] = []
        var currentDate = monthInterval.start
        
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = addDays(1, to: currentDate)
        }
        
        return days
    }
    
    /// Get week number for a date
    func weekNumber(for date: Date) -> Int {
        return calendar.component(.weekOfYear, from: date)
    }
    
    /// Get month number for a date
    func monthNumber(for date: Date) -> Int {
        return calendar.component(.month, from: date)
    }
    
    /// Get year for a date
    func year(for date: Date) -> Int {
        return calendar.component(.year, from: date)
    }
    
    /// Get day of year for a date
    func dayOfYear(for date: Date) -> Int {
        return calendar.component(.dayOfYear, from: date)
    }
    
    // MARK: - Time Zone Utilities
    
    /// Convert date to UTC
    func toUTC(_ date: Date) -> Date {
        let utcTimeZone = TimeZone(identifier: "UTC")!
        let utcOffset = utcTimeZone.secondsFromGMT(for: date)
        return date.addingTimeInterval(TimeInterval(-utcOffset))
    }
    
    /// Convert date from UTC
    func fromUTC(_ date: Date) -> Date {
        let localTimeZone = TimeZone.current
        let localOffset = localTimeZone.secondsFromGMT(for: date)
        return date.addingTimeInterval(TimeInterval(localOffset))
    }
    
    /// Get time zone offset in hours
    func timeZoneOffset() -> Double {
        return Double(TimeZone.current.secondsFromGMT()) / 3600.0
    }
}

// MARK: - Convenience Extensions

extension Date {
    /// Get start of day
    @MainActor
    var startOfDay: Date {
        return DateUtilities.shared.startOfDay(for: self)
    }
    
    /// Get end of day
    @MainActor
    var endOfDay: Date {
        return DateUtilities.shared.endOfDay(for: self)
    }
    
    /// Get start of week
    @MainActor
    var startOfWeek: Date {
        return DateUtilities.shared.startOfWeek(for: self)
    }
    
    /// Get end of week
    @MainActor
    var endOfWeek: Date {
        return DateUtilities.shared.endOfWeek(for: self)
    }
    
    /// Get start of month
    @MainActor
    var startOfMonth: Date {
        return DateUtilities.shared.startOfMonth(for: self)
    }
    
    /// Get end of month
    @MainActor
    var endOfMonth: Date {
        return DateUtilities.shared.endOfMonth(for: self)
    }
    
    /// Check if date is today
    @MainActor
    var isToday: Bool {
        return DateUtilities.shared.isToday(self)
    }
    
    /// Check if date is yesterday
    @MainActor
    var isYesterday: Bool {
        return DateUtilities.shared.isYesterday(self)
    }
    
    /// Check if date is tomorrow
    @MainActor
    var isTomorrow: Bool {
        return DateUtilities.shared.isTomorrow(self)
    }
    
    /// Check if date is in the past
    @MainActor
    var isPast: Bool {
        return DateUtilities.shared.isPast(self)
    }
    
    /// Check if date is in the future
    @MainActor
    var isFuture: Bool {
        return DateUtilities.shared.isFuture(self)
    }
    
    /// Get display string
    @MainActor
    var displayString: String {
        return DateUtilities.shared.displayString(for: self)
    }
    
    /// Get short display string
    @MainActor
    var shortDisplayString: String {
        return DateUtilities.shared.shortDisplayString(for: self)
    }
    
    /// Get time string
    @MainActor
    var timeString: String {
        return DateUtilities.shared.timeString(for: self)
    }
    
    /// Get relative string
    @MainActor
    var relativeString: String {
        return DateUtilities.shared.relativeString(for: self)
    }
    
    /// Get short relative string
    @MainActor
    var shortRelativeString: String {
        return DateUtilities.shared.shortRelativeString(for: self)
    }
}
