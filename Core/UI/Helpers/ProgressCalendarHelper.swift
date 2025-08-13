import Foundation
import SwiftUI

class ProgressCalendarHelper: ObservableObject {
    @Published var currentDate = Date()
    
    // MARK: - Calendar Navigation
    func previousMonth() {
        let calendar = Calendar.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        if let newDate = calendar.date(byAdding: .month, value: -1, to: firstDayOfCurrentMonth) {
            withAnimation(.none) {
                currentDate = newDate
            }
        }
    }
    
    func nextMonth() {
        let calendar = Calendar.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        if let newDate = calendar.date(byAdding: .month, value: 1, to: firstDayOfCurrentMonth) {
            withAnimation(.none) {
                currentDate = newDate
            }
        }
    }
    
    func goToToday() {
        withAnimation(.easeInOut(duration: 0.08)) {
            currentDate = Date()
        }
    }
    
    // MARK: - Calendar Calculations
    func monthYearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
    
    func firstDayOfMonth() -> Int {
        var calendar = Calendar.current
        
        // Set Monday as the first day of the week
        calendar.firstWeekday = 2 // 2 = Monday
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        // Get the weekday of the first day of the month (1 = Sunday, 2 = Monday, etc.)
        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate how many empty cells we need at the start
        // Since we want Monday as the first day of the week:
        // - If first day is Monday (weekday = 2), we need 0 empty cells
        // - If first day is Tuesday (weekday = 3), we need 1 empty cell
        // - If first day is Sunday (weekday = 1), we need 6 empty cells
        let emptyCells = (weekdayOfFirstDay - calendar.firstWeekday + 7) % 7
        
        // Debug: Let's see what's happening
        print("🔍 Calendar Debug:")
        print("   Current Date: \(currentDate)")
        print("   First Day of Month: \(firstDayOfMonth)")
        print("   Weekday of First Day: \(weekdayOfFirstDay) (1=Sun, 2=Mon, 3=Tue, etc.)")
        print("   First Weekday Setting: \(calendar.firstWeekday) (2=Monday)")
        print("   Empty Cells Needed: \(emptyCells)")
        print("   Days in Month: \(daysInMonth())")
        print("   Total Grid Cells: \(emptyCells + daysInMonth())")
        
        return emptyCells
    }
    
    func daysInMonth() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentDate)
        let days = range?.count ?? 0
        
        // Debug: Show days in month calculation
        print("📅 Days in Month Debug:")
        print("   Current Date: \(currentDate)")
        print("   Days Range: \(range?.description ?? "nil")")
        print("   Days Count: \(days)")
        
        return days
    }
    
    func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) else {
            return false
        }
        
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let dayDateComponents = calendar.dateComponents([.year, .month, .day], from: dateForDay)
        
        return todayComponents.year == dayDateComponents.year && 
               todayComponents.month == dayDateComponents.month && 
               todayComponents.day == dayDateComponents.day
    }
    
    func isCurrentMonth() -> Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(currentDate, equalTo: today, toGranularity: .month)
    }
    
    func isTodayInCurrentMonth() -> Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(today, equalTo: currentDate, toGranularity: .month)
    }
    
    func dateForDay(_ day: Int) -> Date? {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        return calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date())
    }
}
