import SwiftUI

// MARK: - Calendar Grid Components
struct CalendarGridComponents {
    
    // MARK: - Calendar Day Cell
    struct CalendarDayCell: View {
        let day: Int
        let progress: Double
        let isToday: Bool
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                    
                    // Progress ring
                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    // Day number
                    Text("\(day)")
                        .font(.appLabelSmall)
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 32, height: 32)
            .buttonStyle(PlainButtonStyle())
        }
        
        private var backgroundColor: Color {
            if isToday {
                return .primary
            } else if isSelected {
                return .secondary
            } else {
                return Color.clear
            }
        }
        
        private var textColor: Color {
            if isToday {
                return .white
            } else if isSelected {
                return .text01
            } else {
                return .text01
            }
        }
    }
    
    // MARK: - Calendar Header
    struct CalendarHeader: View {
        let monthYearString: String
        let onPrevious: () -> Void
        let onNext: () -> Void
        
        var body: some View {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.appLabelMedium)
                        .foregroundColor(.text01)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.appLabelMedium)
                        .foregroundColor(.text01)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Weekday Header
    struct WeekdayHeader: View {
        private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        var body: some View {
            HStack(spacing: 0) {
                ForEach(weekdayNames, id: \.self) { day in
                    Text(day)
                        .font(.appLabelSmall)
                        .foregroundColor(.text02)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Calendar Grid
    struct CalendarGrid: View {
        let firstDayOfMonth: Int
        let daysInMonth: Int
        let currentDate: Date
        let selectedDate: Date
        let getDayProgress: (Int) -> Double
        let onDayTap: (Int) -> Void
        
        var body: some View {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Empty cells for days before the first day of the month
                ForEach(0..<firstDayOfMonth, id: \.self) { _ in
                    Color.clear
                        .frame(height: 32)
                }
                
                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    let progress = getDayProgress(day)
                    let isToday = CalendarGridComponents.isToday(day: day, currentDate: currentDate)
                    let isSelected = CalendarGridComponents.isSelected(day: day, currentDate: currentDate, selectedDate: selectedDate)
                    
                    CalendarDayCell(
                        day: day,
                        progress: progress,
                        isToday: isToday,
                        isSelected: isSelected
                    ) {
                        onDayTap(day)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    static func isToday(day: Int, currentDate: Date) -> Bool {
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
    
    static func isSelected(day: Int, currentDate: Date, selectedDate: Date) -> Bool {
        let calendar = Calendar.current
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) else {
            return false
        }
        
        return calendar.isDate(dateForDay, inSameDayAs: selectedDate)
    }
    
    static func firstDayOfMonth(from date: Date) -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return weekday - 1
    }
    
    static func daysInMonth(from date: Date) -> Int {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone.current
        
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 0
    }
    
    static func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}
