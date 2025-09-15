import Foundation
import SwiftUI

// MARK: - Date and Calendar Logic Helper
class DateCalendarLogic {
    
    // MARK: - Calendar Configuration
    private static var calendar: Calendar {
        return AppDateFormatter.shared.getUserCalendar()
    }
    
    // MARK: - Month Navigation
    static func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    static func firstDayOfMonth(from date: Date) -> Int {
        // Create a date for the first day of the current month
        let firstDayComponents = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, etc.)
        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate how many empty cells we need at the start
        // Using user's preferred first day of the week:
        let emptyCells = (weekdayOfFirstDay - calendar.firstWeekday + 7) % 7
        
        return emptyCells
    }
    
    static func daysInMonth(from date: Date) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 0
    }
    
    static func isToday(day: Int, currentDate: Date) -> Bool {
        let today = Date()
        let todayDay = calendar.component(.day, from: today)
        let todayMonth = calendar.component(.month, from: today)
        let todayYear = calendar.component(.year, from: today)
        
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        return day == todayDay && currentMonth == todayMonth && currentYear == todayYear
    }
    
    // MARK: - Weekday Names
    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    static func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
    }
    
    // MARK: - Date Validation
    static func isDateInPast(_ date: Date) -> Bool {
        let today = Date()
        let targetDate = DateUtils.startOfDay(for: date)
        let todayStart = DateUtils.startOfDay(for: today)
        return targetDate < todayStart
    }
    
    static func isDateInFuture(_ date: Date) -> Bool {
        let today = Date()
        let targetDate = DateUtils.startOfDay(for: date)
        let todayStart = DateUtils.startOfDay(for: today)
        return targetDate > todayStart
    }
    
    // MARK: - Date Range Calculations
    static func getMonthDateRange(from date: Date) -> (start: Date, end: Date)? {
        let monthComponents = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return nil
        }
        return (start: monthStart, end: monthEnd)
    }
    
    static func getWeekDateRange(from date: Date) -> (start: Date, end: Date)? {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return nil
        }
        return (start: weekInterval.start, end: weekInterval.end)
    }
    
    // MARK: - Date Navigation
    static func addMonth(to date: Date, months: Int) -> Date? {
        return calendar.date(byAdding: .month, value: months, to: date)
    }
    
    static func addWeek(to date: Date, weeks: Int) -> Date? {
        return calendar.date(byAdding: .weekOfYear, value: weeks, to: date)
    }
    
    static func addDay(to date: Date, days: Int) -> Date? {
        return calendar.date(byAdding: .day, value: days, to: date)
    }
    
    // MARK: - Date Components
    static func getDayOfMonth(from date: Date) -> Int {
        return calendar.component(.day, from: date)
    }
    
    static func getMonth(from date: Date) -> Int {
        return calendar.component(.month, from: date)
    }
    
    static func getYear(from date: Date) -> Int {
        return calendar.component(.year, from: date)
    }
    
    static func getWeekday(from date: Date) -> Int {
        return calendar.component(.weekday, from: date)
    }
    
    static func getWeekOfYear(from date: Date) -> Int {
        return calendar.component(.weekOfYear, from: date)
    }
    
    // MARK: - Date Comparison
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    static func isSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        let month1 = calendar.component(.month, from: date1)
        let month2 = calendar.component(.month, from: date2)
        let year1 = calendar.component(.year, from: date1)
        let year2 = calendar.component(.year, from: date2)
        return month1 == month2 && year1 == year2
    }
    
    static func isSameWeek(_ date1: Date, _ date2: Date) -> Bool {
        let week1 = calendar.component(.weekOfYear, from: date1)
        let week2 = calendar.component(.weekOfYear, from: date2)
        let year1 = calendar.component(.year, from: date1)
        let year2 = calendar.component(.year, from: date2)
        return week1 == week2 && year1 == year2
    }
    
    // MARK: - Leap Year
    static func isLeapYear(_ year: Int) -> Bool {
        let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let daysInYear = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        return daysInYear == 366
    }
}
