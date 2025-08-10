import Foundation

// MARK: - Date Preferences Manager
class DatePreferences: ObservableObject {
    static let shared = DatePreferences()
    
    @Published var dateFormat: DateFormatOption = .dayMonthYear {
        didSet {
            UserDefaults.standard.set(dateFormat.rawValue, forKey: "selectedDateFormat")
        }
    }
    
    @Published var firstDayOfWeek: FirstDayOption = .monday {
        didSet {
            UserDefaults.standard.set(firstDayOfWeek.rawValue, forKey: "selectedFirstDay")
        }
    }
    
    private init() {
        // Load saved preferences
        if let savedDateFormat = UserDefaults.standard.string(forKey: "selectedDateFormat"),
           let format = DateFormatOption(rawValue: savedDateFormat) {
            self.dateFormat = format
        }
        
        if let savedFirstDay = UserDefaults.standard.string(forKey: "selectedFirstDay"),
           let firstDay = FirstDayOption(rawValue: savedFirstDay) {
            self.firstDayOfWeek = firstDay
        }
    }
}

// MARK: - Date Format Options (Updated)
enum DateFormatOption: String, CaseIterable {
    case dayMonthYear = "dayMonthYear"
    case monthDayYear = "monthDayYear"
    case yearMonthDay = "yearMonthDay"
    
    var example: String {
        switch self {
        case .dayMonthYear:
            return "31/12/2025"
        case .monthDayYear:
            return "12/31/2025"
        case .yearMonthDay:
            return "2025-12-31"
        }
    }
    
    var description: String {
        switch self {
        case .dayMonthYear:
            return "Day/Month/Year"
        case .monthDayYear:
            return "Month/Day/Year"
        case .yearMonthDay:
            return "Year/Month/Day"
        }
    }
    
    // Short date format (for display like "Fri, 9 Aug, 2025")
    var shortDateFormat: String {
        switch self {
        case .dayMonthYear:
            return "E, d MMM, yyyy"  // Fri, 9 Aug, 2025
        case .monthDayYear:
            return "E, MMM d, yyyy"  // Fri, Aug 9, 2025
        case .yearMonthDay:
            return "E, yyyy MMM d"   // Fri, 2025 Aug 9
        }
    }
    
    // Numeric date format (for display like "31/12/2025")
    var numericDateFormat: String {
        switch self {
        case .dayMonthYear:
            return "dd/MM/yyyy"      // 09/08/2025
        case .monthDayYear:
            return "MM/dd/yyyy"      // 08/09/2025
        case .yearMonthDay:
            return "yyyy-MM-dd"      // 2025-08-09
        }
    }
}

// MARK: - First Day Options (Updated)
enum FirstDayOption: String, CaseIterable {
    case monday = "Monday"
    case sunday = "Sunday"
}

// MARK: - Centralized Date Formatter
struct AppDateFormatter {
    static let shared = AppDateFormatter()
    
    private init() {}
    
    // Format date for display in lists, cards, etc.
    func formatDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DatePreferences.shared.dateFormat.shortDateFormat
        return formatter.string(from: date)
    }
    
    // Format date numerically (e.g., for compact displays)
    func formatNumericDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DatePreferences.shared.dateFormat.numericDateFormat
        return formatter.string(from: date)
    }
    
    // Check if date is today (considering user's first day preference)
    func isToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: Date())
    }
    
    // Format date with "Today" replacement
    func formatDateWithTodayReplacement(_ date: Date) -> String {
        if isToday(date) {
            return "Today"
        } else {
            return formatDisplayDate(date)
        }
    }
    
    // Get calendar with user's preferred first day
    func getUserCalendar() -> Calendar {
        var calendar = Calendar.current
        let firstWeekday = DatePreferences.shared.firstDayOfWeek == .monday ? 2 : 1
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
