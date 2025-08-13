import Foundation

extension Date {
    func weekRangeText() -> String {
        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: self) ?? self
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        
        let startText = formatter.string(from: self)
        let endText = formatter.string(from: weekEndDate)
        
        return "\(startText) - \(endText)"
    }
    
    static func currentWeekStartDate() -> Date {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let today = Date()
        // Get the start of the current week (using user's preference)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return weekStart
    }
    
    static func currentMonthStartDate() -> Date {
        let calendar = Calendar.current
        let today = Date()
        // Get the start of the current month
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        return monthStart
    }
    
    func monthText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
} 