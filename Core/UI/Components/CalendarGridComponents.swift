import SwiftUI

// MARK: - Calendar Grid Components
struct CalendarGridComponents {
    
    // MARK: - Calendar Day Cell
    struct CalendarDayCell: View {
        let day: Int
        let progress: Double
        let isToday: Bool
        let isSelected: Bool
        let isCurrentMonth: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // Background
                    if isToday {
                        Circle()
                            .fill(backgroundColor)
                            .frame(width: 30, height: 30)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                    }
                    
                    // Progress ring - only show for current month days
                    if isCurrentMonth {
                        Circle()
                            .trim(from: 0, to: progress > 0 ? progress : 1.0)
                            .stroke(
                                progress > 0 ? (isToday ? Color.white : Color.primary) : (isToday ? Color.white.opacity(0.7) : Color.outline3),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 30, height: 30)
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
            } else if isCurrentMonth {
                return Color.clear
            } else {
                return Color.clear // Overflow days have no background
            }
        }
        
        private var textColor: Color {
            if isToday {
                return .white
            } else if isSelected {
                return .text01
            } else if isCurrentMonth {
                return .text01
            } else {
                return .outline2 // More visible color for overflow days
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
        private let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
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
                // Previous month overflow days
                ForEach(0..<firstDayOfMonth, id: \.self) { index in
                    let previousMonthDay = CalendarGridComponents.getPreviousMonthDay(index: index, firstDayOfMonth: firstDayOfMonth, currentDate: currentDate)
                    CalendarDayCell(
                        day: previousMonthDay,
                        progress: 0.0,
                        isToday: false,
                        isSelected: false,
                        isCurrentMonth: false
                    ) {
                        // No action for overflow days
                    }
                    .id("prev-\(index)")
                }
                
                // Day cells for current month
                ForEach(1...daysInMonth, id: \.self) { day in
                    let progress = getDayProgress(day)
                    let isToday = CalendarGridComponents.isToday(day: day, currentDate: currentDate)
                    let isSelected = CalendarGridComponents.isSelected(day: day, currentDate: currentDate, selectedDate: selectedDate)
                    
                    CalendarDayCell(
                        day: day,
                        progress: progress,
                        isToday: isToday,
                        isSelected: isSelected,
                        isCurrentMonth: true
                    ) {
                        onDayTap(day)
                    }
                    .id("day-\(day)")
                    .onAppear {
                        // Debug: Show each day as it appears
                        print("   📅 Day \(day) appeared")
                    }
                }
                
                // Next month overflow days - only show what's needed to complete the last week
                let totalCells = firstDayOfMonth + daysInMonth
                let cellsInLastWeek = totalCells % 7
                let nextMonthDaysNeeded = cellsInLastWeek > 0 ? (7 - cellsInLastWeek) : 0
                
                ForEach(0..<nextMonthDaysNeeded, id: \.self) { index in
                    let nextMonthDay = index + 1
                    CalendarDayCell(
                        day: nextMonthDay,
                        progress: 0.0,
                        isToday: false,
                        isSelected: false,
                        isCurrentMonth: false
                    ) {
                        // No action for overflow days
                    }
                    .id("next-\(index)")
                }
                
                // Fill remaining cells to complete 6-week grid (if needed)
                let totalGridCells = firstDayOfMonth + daysInMonth + nextMonthDaysNeeded
                let remainingEmptyCells = max(0, 42 - totalGridCells) // 42 = 6 rows × 7 columns
                ForEach(0..<remainingEmptyCells, id: \.self) { index in
                    Color.clear
                        .frame(height: 32)
                        .id("empty-\(index)")
                }
            }
            .onAppear {
                // Debug: Show grid layout information
                let cellsInLastWeek = (firstDayOfMonth + daysInMonth) % 7
                let nextMonthDaysNeeded = cellsInLastWeek > 0 ? (7 - cellsInLastWeek) : 0
                let totalGridCells = firstDayOfMonth + daysInMonth + nextMonthDaysNeeded
                let remainingEmptyCells = max(0, 42 - totalGridCells)
                
                print("📅 Calendar Grid Debug:")
                print("   First Day Position: \(firstDayOfMonth)")
                print("   Days in Month: \(daysInMonth)")
                print("   Previous Month Overflow: \(firstDayOfMonth)")
                print("   Current Month Days: \(daysInMonth)")
                print("   Next Month Overflow: \(nextMonthDaysNeeded)")
                print("   Empty Cells: \(remainingEmptyCells)")
                print("   Total Grid Cells: \(totalGridCells)")
            }
        }
    }
    
    // MARK: - Helper Functions
    static func isToday(day: Int, currentDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the first day of the month
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: monthComponents) else {
            return false
        }
        
        // Calculate the date for the specific day by adding (day - 1) to the first day
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else {
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
        
        // Get the first day of the month
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: monthComponents) else {
            return false
        }
        
        // Calculate the date for the specific day by adding (day - 1) to the first day
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else {
            return false
        }
        
        return calendar.isDate(dateForDay, inSameDayAs: selectedDate)
    }
    
    static func firstDayOfMonth(from date: Date) -> Int {
        var calendar = Calendar.current
        
        // Set Monday as the first day of the week
        calendar.firstWeekday = 2 // 2 = Monday
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: date)
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
        
        return emptyCells
    }
    
    static func daysInMonth(from date: Date) -> Int {
        let calendar = Calendar.current
        
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 0
    }
    
    static func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    static func getPreviousMonthDay(index: Int, firstDayOfMonth: Int, currentDate: Date) -> Int {
        let calendar = Calendar.current
        
        // Get the first day of the current month
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: monthComponents) else {
            return 1
        }
        
        // Calculate how many days we need to go back
        let daysToSubtract = firstDayOfMonth - index
        
        // Get the date for the overflow day
        guard let overflowDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfCurrentMonth) else {
            return 1
        }
        
        // Return the day number
        return calendar.component(.day, from: overflowDate)
    }
}
