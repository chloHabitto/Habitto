import SwiftUI

// MARK: - Date Utilities for Performance Optimization
class DateUtils {
    static let calendar = Calendar.current
    static let today = calendar.startOfDay(for: Date())
    
    // Performance optimization: Cached date formatters
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static func isToday(_ date: Date) -> Bool {
        return calendar.startOfDay(for: date) == today
    }
    
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return calendar.startOfDay(for: date1) == calendar.startOfDay(for: date2)
    }
    
    static func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    static func daysBetween(_ startDate: Date, _ endDate: Date) -> Int {
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    static func weekday(for date: Date) -> Int {
        return calendar.component(.weekday, from: date)
    }
    
    static func dateByAdding(days: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
    
    static func dateByAdding(weeks: Int, to date: Date) -> Date {
        return calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }
    
    // Performance optimization: Use cached formatter for date keys
    static func dateKey(for date: Date) -> String {
        return dateKeyFormatter.string(from: date)
    }
    
    // Performance optimization: Use cached formatter for debug output
    static func debugString(for date: Date) -> String {
        return debugFormatter.string(from: date)
    }
}

// MARK: - View Extensions
extension View {
    func roundedTopBackground() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
    }
}

// MARK: - Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
} 
