import SwiftUI

// MARK: - Calendar Grid Components
struct CalendarGridComponents {
    
    // MARK: - Enhanced Calendar Day Cell
    struct CalendarDayCell: View {
        let day: Int
        let progress: Double
        let isToday: Bool
        let isSelected: Bool
        let isCurrentMonth: Bool
        let isVacationDay: Bool
        let onTap: () -> Void
        
        // Animation states
        @State private var isPressed = false
        @State private var progressAnimation = 0.0
        @State private var scale: CGFloat = 1.0
        
        var body: some View {
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                // Animate progress ring
                withAnimation(.easeInOut(duration: 0.8)) {
                    progressAnimation = progress
                }
                
                onTap()
            }) {
                ZStack {
                    // Enhanced background with gradients
                    if isVacationDay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    } else if isToday {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                    } else if isCurrentMonth {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                    }
                    
                    // Enhanced progress ring with animations
                    if isCurrentMonth {
                        ZStack {
                            // Background progress ring
                            Circle()
                                .stroke(
                                    Color.outline3.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .frame(width: 32, height: 32)
                            
                            // Animated progress ring
                            Circle()
                                .trim(from: 0, to: progressAnimation)
                                .stroke(
                                    progressRingGradient,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.8), value: progressAnimation)
                        }
                    }
                    
                    // Enhanced day number with better typography
                    Text("\(day)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 40, height: 40)
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(scale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
            .onAppear {
                // Animate progress ring on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        progressAnimation = progress
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10) {
                // Long press for detailed view (future enhancement)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
            }
        }
        
        private var backgroundColor: Color {
            if isToday {
                return .primary
            } else if isSelected {
                return .secondary
            } else if isCurrentMonth {
                return Color.clear
            } else {
                return Color.clear
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
                return .outline2
            }
        }
        
        private var progressRingGradient: LinearGradient {
            if progress > 0 {
                // Progress - beautiful pastel blue gradient
                return LinearGradient(
                    colors: [Color.pastelBlue500, Color.pastelBlue500.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // No progress - subtle outline
                return LinearGradient(
                    colors: [Color.outline3, Color.outline3.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    // MARK: - Enhanced Calendar Header
    struct CalendarHeader: View {
        let monthYearString: String
        let onPrevious: () -> Void
        let onNext: () -> Void
        
        @State private var previousButtonScale: CGFloat = 1.0
        @State private var nextButtonScale: CGFloat = 1.0
        
        var body: some View {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        previousButtonScale = 0.9
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            previousButtonScale = 1.0
                        }
                    }
                    onPrevious()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .scaleEffect(previousButtonScale)
                
                Spacer()
                
                Text(monthYearString)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.surface.opacity(0.5))
                    )
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        nextButtonScale = 0.9
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            nextButtonScale = 1.0
                        }
                    }
                    onNext()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .scaleEffect(nextButtonScale)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Enhanced Weekday Header
    struct WeekdayHeader: View {
        private var weekdayNames: [String] {
            let calendar = AppDateFormatter.shared.getUserCalendar()
            if calendar.firstWeekday == 1 { // Sunday
                return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            } else { // Monday
                return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            }
        }
        
        var body: some View {
            HStack(spacing: 8) {
                ForEach(weekdayNames, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.text02)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.surface.opacity(0.3))
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
        }
    }
    
    // MARK: - Enhanced Calendar Grid
    struct CalendarGrid: View {
        let firstDayOfMonth: Int
        let daysInMonth: Int
        let currentDate: Date
        let selectedDate: Date
        let getDayProgress: (Int) -> Double
        let onDayTap: (Int) -> Void
        
        @State private var gridAppearAnimation = false
        
        var body: some View {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                // Previous month overflow days
                ForEach(0..<firstDayOfMonth, id: \.self) { index in
                    let previousMonthDay = CalendarGridComponents.getPreviousMonthDay(index: index, firstDayOfMonth: firstDayOfMonth, currentDate: currentDate)
                    CalendarDayCell(
                        day: previousMonthDay,
                        progress: 0.0,
                        isToday: false,
                        isSelected: false,
                        isCurrentMonth: false,
                        isVacationDay: false
                    ) {
                        // No action for overflow days
                    }
                    .id("prev-\(index)")
                    .opacity(0.3)
                }
                
                // Day cells for current month
                ForEach(1...daysInMonth, id: \.self) { day in
                    let progress = getDayProgress(day)
                    let isToday = CalendarGridComponents.isToday(day: day, currentDate: currentDate)
                    let isSelected = CalendarGridComponents.isSelected(day: day, currentDate: currentDate, selectedDate: selectedDate)
                    let isVacationDay = VacationManager.shared.isVacationDay(CalendarGridComponents.getDateForDay(day: day, currentDate: currentDate))
                    
                    CalendarDayCell(
                        day: day,
                        progress: progress,
                        isToday: isToday,
                        isSelected: isSelected,
                        isCurrentMonth: true,
                        isVacationDay: isVacationDay
                    ) {
                        onDayTap(day)
                    }
                    .id("day-\(day)")
                    .opacity(gridAppearAnimation ? 1 : 0)
                    .offset(y: gridAppearAnimation ? 0 : 20)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(Double(day) * 0.02),
                        value: gridAppearAnimation
                    )
                }
                
                // Next month overflow days
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
                        isCurrentMonth: false,
                        isVacationDay: false
                    ) {
                        // No action for overflow days
                    }
                    .id("next-\(index)")
                    .opacity(0.3)
                }
                
                // Empty cells to complete week
                let totalGridCells = firstDayOfMonth + daysInMonth + nextMonthDaysNeeded
                let currentWeekCells = totalGridCells % 7
                let emptyCellsToCompleteWeek = currentWeekCells > 0 ? (7 - currentWeekCells) : 0
                
                ForEach(0..<emptyCellsToCompleteWeek, id: \.self) { index in
                    Color.clear
                        .frame(height: 40)
                        .id("empty-\(index)")
                }
            }
            .animation(nil, value: firstDayOfMonth) // Disable month change animation
            .animation(nil, value: daysInMonth) // Disable month change animation
            .onAppear {
                // Trigger grid appear animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    gridAppearAnimation = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions (unchanged)
    static func isToday(day: Int, currentDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: monthComponents) else {
            return false
        }
        
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
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfMonth = calendar.date(from: monthComponents) else {
            return false
        }
        
        guard let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) else {
            return false
        }
        
        return calendar.isDate(dateForDay, inSameDayAs: selectedDate)
    }
    
    static func firstDayOfMonth(from date: Date) -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        
        let firstDayComponents = calendar.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = calendar.date(from: firstDayComponents) else { 
            return 0 
        }
        
        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDayOfMonth)
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
    
    static func getDateForDay(day: Int, currentDate: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? currentDate
    }
    
    static func getPreviousMonthDay(index: Int, firstDayOfMonth: Int, currentDate: Date) -> Int {
        let calendar = Calendar.current
        
        let monthComponents = calendar.dateComponents([.year, .month], from: currentDate)
        guard let firstDayOfCurrentMonth = calendar.date(from: monthComponents) else {
            return 1
        }
        
        let daysToSubtract = firstDayOfMonth - index
        
        guard let overflowDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfCurrentMonth) else {
            return 1
        }
        
        return calendar.component(.day, from: overflowDate)
    }
}
