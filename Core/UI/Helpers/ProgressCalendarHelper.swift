import Foundation
import SwiftUI

class ProgressCalendarHelper: ObservableObject {
    @Published var currentDate = Date()
    
    // MARK: - Calendar Navigation
    func previousMonth() {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        if let newDate = calendar.date(byAdding: .month, value: -1, to: firstDayOfCurrentMonth) {
            currentDate = newDate
        }
    }
    
    func nextMonth() {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: firstDayComponents) else { return }
        
        if let newDate = calendar.date(byAdding: .month, value: 1, to: firstDayOfCurrentMonth) {
            currentDate = newDate
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
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: currentDate)
    }
    
    func firstDayOfMonth() -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return weekday - 1
    }
    
    func daysInMonth() -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let range = calendar.range(of: .day, in: .month, for: currentDate)
        return range?.count ?? 0
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
