import SwiftUI

// MARK: - Week Position Enum
enum WeekPosition {
    case none, start, middle, end
}

// MARK: - Custom Week Selection Calendar
struct CustomWeekSelectionCalendar: View {
    @Binding var selectedWeekStartDate: Date
    @Binding var selectedDateRange: ClosedRange<Date>?
    @State private var currentMonth: Date = Date()
    
    private var weekdayNames: [String] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if calendar.firstWeekday == 1 { // Sunday
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        } else { // Monday
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.text01)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.text01)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                // Day headers
                ForEach(weekdayNames, id: \.self) { day in
                    Text(day)
                        .font(.appLabelMedium)
                        .foregroundColor(.text04)
                        .frame(height: 32)
                }
                
                // Calendar days
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: isDateInSelectedWeek(date),
                            isToday: AppDateFormatter.shared.getUserCalendar().isDate(date, inSameDayAs: Date()),
                            isCurrentMonth: AppDateFormatter.shared.getUserCalendar().isDate(date, equalTo: currentMonth, toGranularity: .month),
                            weekPosition: getWeekPosition(for: date)
                        )
                        .onTapGesture {
                            selectWeek(for: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .id(monthYearString) // Force re-render when month changes
            // Removed transition animations for better responsiveness
        }
        // .background(Color.green)
        .onAppear {
            initializeCurrentWeek()
        }
    }
    
    // MARK: - Helper Functions
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var calendarDays: [Date?] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        
        // Find the first day of the week based on user preference
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysFromFirstWeekday = (firstWeekday - calendar.firstWeekday + 7) % 7
        let firstDisplayDate = calendar.date(byAdding: .day, value: -daysFromFirstWeekday, to: startOfMonth) ?? startOfMonth
        
        var days: [Date?] = []
        var currentDate = firstDisplayDate
        
        // Generate 42 days (6 weeks)
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isDateInSelectedWeek(_ date: Date) -> Bool {
        guard let range = selectedDateRange else { return false }
        return range.contains(date)
    }
    
    private func getWeekPosition(for date: Date) -> WeekPosition {
        guard let range = selectedDateRange, range.contains(date) else { return .none }
        
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if calendar.isDate(date, inSameDayAs: range.lowerBound) {
            return .start
        } else if calendar.isDate(date, inSameDayAs: range.upperBound) {
            return .end
        } else {
            return .middle
        }
    }
    
    private func selectWeek(for date: Date) {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return }
        
        // Immediate state update without blocking animation for better responsiveness
        selectedWeekStartDate = weekStart
        selectedDateRange = weekStart...weekEnd
    }
    
    private func changeMonth(by value: Int) {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            // Immediate month change without animation for better responsiveness
            currentMonth = newMonth
        }
    }
    
    private func initializeCurrentWeek() {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        selectedWeekStartDate = weekStart
        selectedDateRange = weekStart...weekEnd
        currentMonth = today
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let weekPosition: WeekPosition
    
    var body: some View {
        ZStack {
            // Background extension for start date
            if weekPosition == .start {
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(.primaryContainer)
                        .frame(width: 16, height: 32)
                }
            }
            
            // Background extension for end date
            if weekPosition == .end {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.primaryContainer)
                        .frame(width: 16, height: 32)
                    Spacer()
                }
            }
            
            // Main day view
            Text("\(AppDateFormatter.shared.getUserCalendar().component(.day, from: date))")
                .font(.appBodyMedium)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(backgroundColor)
                .clipShape(backgroundShape)
                .overlay(
                    backgroundShape
                        .stroke(isToday && !isSelected ? Color.primary : Color.clear, lineWidth: 1)
                )
        }
        .opacity(isCurrentMonth ? 1.0 : 0.3)
        // Removed animation for better responsiveness
    }
    
    private var textColor: Color {
        switch weekPosition {
        case .start, .end:
            return .onPrimary
        case .middle:
            return .onPrimaryContainer
        case .none:
            if isToday {
                return .primary
            } else {
                return .text01
            }
        }
    }
    
    private var backgroundColor: Color {
        switch weekPosition {
        case .start, .end:
            return Color.primary
        case .middle:
            return .primaryContainer
        case .none:
            if isToday && !isSelected {
                return Color.primary.opacity(0.1)
            } else {
                return .clear
            }
        }
    }
    
    private var backgroundShape: some Shape {
        switch weekPosition {
        case .start, .end, .none:
            return AnyShape(Circle())
        case .middle:
            return AnyShape(Rectangle())
        }
    }
}