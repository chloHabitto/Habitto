import SwiftUI

// MARK: - Supporting Types
enum TimePeriod: CaseIterable {
    case today, week, year, all
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .year: return "Year"
        case .all: return "All"
        }
    }
    
    var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .today:
            return [calendar.startOfDay(for: today)]
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        case .year:
            // For "Year" period, return all dates from the start of the year to today
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            var dates: [Date] = []
            var currentDate = yearStart
            while currentDate <= today {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .all:
            // For "All" period, return all dates from the start of the year to today
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            var dates: [Date] = []
            var currentDate = yearStart
            while currentDate <= today {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    var previousPeriodDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .today:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return [calendar.startOfDay(for: yesterday)]
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: previousWeekStart) }
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: yearStart) ?? yearStart
            var dates: [Date] = []
            var currentDate = previousYearStart
            let previousYearEnd = calendar.dateInterval(of: .year, for: previousYearStart)?.end ?? previousYearStart
            while currentDate < previousYearEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        case .all:
            // For "All" period, return previous year's dates
            let yearStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: yearStart) ?? yearStart
            var dates: [Date] = []
            var currentDate = previousYearStart
            let previousYearEnd = calendar.dateInterval(of: .year, for: previousYearStart)?.end ?? previousYearStart
            while currentDate < previousYearEnd {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return dates
        }
    }
    
    var weeksCount: Int {
        switch self {
        case .today: return 0
        case .week: return 1
        case .year: return 52
        case .all: return 52
        }
    }
}
