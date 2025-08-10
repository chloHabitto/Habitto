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
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        let today = Date()
        // Get the start of the current week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return weekStart
    }
} 