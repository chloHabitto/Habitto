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
                    if isToday {
                        Circle()
                            .fill(backgroundColor)
                            .frame(width: 30, height: 30)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor)
                    }
                    
                    // Progress ring - always show, but with different colors
                    Circle()
                        .trim(from: 0, to: progress > 0 ? progress : 1.0)
                        .stroke(
                            progress > 0 ? (isToday ? Color.white : Color.primary) : (isToday ? Color.white.opacity(0.7) : Color.outline3),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90))
                    
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
                // Empty cells for days before the first day of the month
                ForEach(0..<firstDayOfMonth, id: \.self) { index in
                    Color.clear
                        .frame(height: 32)
                        .id("empty-start-\(index)")
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
                    .id("day-\(day)")
                    .onAppear {
                        // Debug: Show each day as it appears
                        print("   📅 Day \(day) appeared")
                    }
                }
                
                // Empty cells to complete the grid (always show 6 rows)
                let totalCells = firstDayOfMonth + daysInMonth
                let remainingCells = max(0, 42 - totalCells) // 42 = 6 rows × 7 columns
                ForEach(0..<remainingCells, id: \.self) { index in
                    Color.clear
                        .frame(height: 32)
                        .id("empty-end-\(index)")
                }
            }
            .onAppear {
                // Debug: Show grid layout information
                print("📅 Calendar Grid Debug:")
                print("   First Day Position: \(firstDayOfMonth)")
                print("   Days in Month: \(daysInMonth)")
                print("   Empty Cells at Start: \(firstDayOfMonth)")
                print("   Day Cells: \(daysInMonth)")
                print("   Remaining Empty Cells: \(max(0, 42 - (firstDayOfMonth + daysInMonth)))")
                print("   Total Grid Cells: \(firstDayOfMonth + daysInMonth + max(0, 42 - (firstDayOfMonth + daysInMonth)))")
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
}
