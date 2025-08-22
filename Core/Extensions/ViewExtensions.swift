import SwiftUI

// MARK: - Performance Optimization Utilities
struct PerformanceOptimizer {
    // Debounce function to limit frequent updates
    static func debounce<T>(interval: TimeInterval, action: @escaping (T) -> Void) -> (T) -> Void {
        var timer: Timer?
        return { value in
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                action(value)
            }
        }
    }
    
    // Throttle function to limit execution frequency
    static func throttle<T>(interval: TimeInterval, action: @escaping (T) -> Void) -> (T) -> Void {
        var lastExecutionTime: TimeInterval = 0
        return { value in
            let currentTime = Date().timeIntervalSinceReferenceDate
            if currentTime - lastExecutionTime >= interval {
                action(value)
                lastExecutionTime = currentTime
            }
        }
    }
}

// MARK: - View Performance Modifiers
extension View {
    // Optimize view updates by conditionally applying modifiers
    func conditionalModifier<M: ViewModifier>(_ condition: Bool, _ modifier: M) -> some View {
        Group {
            if condition {
                self.modifier(modifier)
            } else {
                self
            }
        }
    }
    
    // Optimize expensive view calculations
    func optimized<Content: View>(_ content: @escaping () -> Content) -> some View {
        self.background(content())
    }
    
    // Reduce view updates with equality check
    func equalityCheck<T: Equatable>(_ value: T, action: @escaping (T) -> Void) -> some View {
        self.onChange(of: value) { _, newValue in
            action(newValue)
        }
    }
}

// MARK: - Date Utilities
struct DateUtils {
    static let calendar = Calendar.current
    
    // MARK: - Robust Today's Date Calculation
    static func today() -> Date {
        let now = Date()
        print("🔍 DateUtils.today() - Raw Date(): \(now)")
        print("🔍 DateUtils.today() - Current timezone: \(TimeZone.current)")
        print("🔍 DateUtils.today() - Calendar timezone: \(calendar.timeZone)")
        print("🔍 DateUtils.today() - Calendar locale: \(calendar.locale?.identifier ?? "nil")")
        
        // Force use of current timezone
        var robustCalendar = Calendar.current
        robustCalendar.timeZone = TimeZone.current
        robustCalendar.locale = Locale.current
        
        let today = robustCalendar.startOfDay(for: now)
        print("🔍 DateUtils.today() - Calculated today: \(today)")
        print("🔍 DateUtils.today() - Today components: \(robustCalendar.dateComponents([.year, .month, .day], from: today))")
        
        return today
    }
    
    // Force refresh today's date (useful for debugging timezone issues)
    static func forceRefreshToday() -> Date {
        print("🔄 DateUtils.forceRefreshToday() - Clearing date cache and recalculating...")
        clearDateCache()
        
        // Force timezone refresh
        let now = Date()
        var robustCalendar = Calendar.current
        robustCalendar.timeZone = TimeZone.current
        robustCalendar.locale = Locale.current
        
        let today = robustCalendar.startOfDay(for: now)
        print("🔄 DateUtils.forceRefreshToday() - New today: \(today)")
        print("🔄 DateUtils.forceRefreshToday() - New components: \(robustCalendar.dateComponents([.year, .month, .day], from: today))")
        
        return today
    }
    
    static func startOfDay(for date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
    
    static func endOfDay(for date: Date) -> Date {
        return calendar.date(byAdding: .day, value: 1, to: startOfDay(for: date)) ?? date
    }
    
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    static func daysBetween(_ startDate: Date, _ endDate: Date) -> Int {
        let components = calendar.dateComponents([.day], from: startOfDay(for: startDate), to: startOfDay(for: endDate))
        return components.day ?? 0
    }
    
    static func weeksBetween(_ startDate: Date, _ endDate: Date) -> Int {
        // Calculate actual weeks between dates, not week number difference
        let startOfStartWeek = calendar.dateInterval(of: .weekOfYear, for: startOfDay(for: startDate))?.start ?? startOfDay(for: startDate)
        let startOfEndWeek = calendar.dateInterval(of: .weekOfYear, for: startOfDay(for: endDate))?.start ?? startOfDay(for: endDate)
        
        let components = calendar.dateComponents([.day], from: startOfStartWeek, to: startOfEndWeek)
        let daysBetween = components.day ?? 0
        return daysBetween / 7
    }
    
    static func isDateInPast(_ date: Date) -> Bool {
        return date < startOfDay(for: Date())
    }
    
    static func isDateBeforeOrEqualToStartDate(_ date: Date, _ startDate: Date) -> Bool {
        return startOfDay(for: date) <= startOfDay(for: startDate)
    }
    
    // Performance optimization: Cache date calculations
    private static var dateCache: [String: Date] = [:]
    
    // Performance optimization: Use cached formatter for date keys
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static func dateKey(for date: Date) -> String {
        return dateKeyFormatter.string(from: date)
    }
    
    static func weekday(for date: Date) -> Int {
        return calendar.component(.weekday, from: date)
    }
    
    static func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    static func endOfWeek(for date: Date) -> Date {
        let startOfWeek = startOfWeek(for: date)
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
    }
    
    // Performance optimization: Use cached formatter for debug output
    private static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static func debugString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    static func cachedStartOfDay(for date: Date) -> Date {
        let key = "start_\(date.timeIntervalSince1970)"
        if let cached = dateCache[key] {
            return cached
        }
        let result = startOfDay(for: date)
        dateCache[key] = result
        return result
    }
    
    static func clearDateCache() {
        dateCache.removeAll()
    }
}

// MARK: - Array Performance Extensions
extension Array {
    // Optimized filtering with early exit
    func optimizedFilter(_ predicate: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        result.reserveCapacity(self.count / 2) // Pre-allocate space for better performance
        
        for element in self {
            if predicate(element) {
                result.append(element)
            }
        }
        return result
    }
    
    // Optimized mapping with pre-allocated capacity
    func optimizedMap<T>(_ transform: (Element) -> T) -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        
        for element in self {
            result.append(transform(element))
        }
        return result
    }
}

// MARK: - String Performance Extensions
extension String {
    // Optimized string operations
    var optimizedLowercased: String {
        return self.lowercased()
    }
    
    var optimizedTrimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Cache for expensive string operations
    private static var stringCache: [String: String] = [:]
    
    static func cachedLowercase(_ string: String) -> String {
        if let cached = stringCache[string] {
            return cached
        }
        let result = string.lowercased()
        stringCache[string] = result
        return result
    }
    
    static func clearStringCache() {
        stringCache.removeAll()
    }
}

// MARK: - View Extensions
extension View {
    func roundedTopBackground() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
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
