import SwiftUI

// MARK: - Expandable Calendar Component
struct ExpandableCalendar: View {
    @Binding var selectedDate: Date
    @State private var isExpanded: Bool = false
    @State private var currentWeekOffset: Int = 0
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
        VStack(spacing: 0) {
            // Header with date and chevron
            calendarHeader
            
            // Expandable content
            if isExpanded {
                monthlyCalendarView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                weeklyCalendarView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            // Date text with chevron icon - acts as a button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 0) {
                    Text(formattedCurrentDate)
                        .font(.appTitleMediumEmphasised)
                        .lineSpacing(8)
                        .foregroundColor(.primary)
                    
                    Image(isExpanded ? "Icon-arrowDropUp_Filled" : "Icon-arrowDropDown_Filled")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.navy100)
                        .opacity(1.0)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Today button (shown when not on current week or selected date is not today)
            let calendar = AppDateFormatter.shared.getUserCalendar()
            let today = Date()
            let isTodayInCurrentWeek = daysOfWeek(for: currentWeekOffset).contains { date in
                calendar.isDate(date, inSameDayAs: today)
            }
            let isTodaySelected = calendar.isDate(selectedDate, inSameDayAs: today)
            let isCurrentMonth = calendar.isDate(today, equalTo: currentMonth, toGranularity: .month)
            
            // Show Today button if:
            // 1. Calendar is collapsed (weekly view) and not on current week or today not selected
            // 2. Calendar is expanded (monthly view) and not on current month or today not selected
            if (!isExpanded && (!isTodayInCurrentWeek || !isTodaySelected)) || 
               (isExpanded && (!isCurrentMonth || !isTodaySelected)) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        goToToday()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(.iconReplay)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.primaryFocus)
                        Text("Today")
                            .font(.appLabelMedium)
                            .foregroundColor(.primaryFocus)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: .infinity)
                            .stroke(.primaryFocus, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Weekly Calendar View
    private var weeklyCalendarView: some View {
        TabView(selection: $currentWeekOffset) {
            ForEach(-100...100, id: \.self) { weekOffset in
                weekView(for: weekOffset, width: UIScreen.main.bounds.width - 16)
                    .frame(width: UIScreen.main.bounds.width - 16)
                    .tag(weekOffset)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentWeekOffset) // Enable smooth animation
        .onChange(of: currentWeekOffset) { oldValue, newValue in
            // Add haptic feedback when scrolling between weeks
            if oldValue != newValue {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        .onAppear {
            currentWeekOffset = 0
        }
        .frame(height: 72)
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
    
    // MARK: - Monthly Calendar View
    private var monthlyCalendarView: some View {
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
            .padding(.horizontal, 20)
            
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
                        MonthlyCalendarDayView(
                            date: date,
                            isSelected: AppDateFormatter.shared.getUserCalendar().isDate(date, inSameDayAs: selectedDate),
                            isToday: AppDateFormatter.shared.getUserCalendar().isDate(date, inSameDayAs: Date()),
                            isCurrentMonth: AppDateFormatter.shared.getUserCalendar().isDate(date, equalTo: currentMonth, toGranularity: .month)
                        )
                        .onTapGesture {
                            selectDate(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .id(monthYearString) // Force re-render when month changes
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Helper Properties and Functions
    
    private var formattedCurrentDate: String {
        return AppDateFormatter.shared.formatDisplayDate(selectedDate)
    }
    
    private var monthYearString: String {
        return AppDateFormatter.shared.formatMonthYear(currentMonth)
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
    
    private func daysOfWeek(for weekOffset: Int) -> [Date] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let adjustedWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart) ?? weekStart
        
        var days: [Date] = []
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: adjustedWeekStart) {
                days.append(day)
            }
        }
        return days
    }
    
    private func weekView(for weekOffset: Int, width: CGFloat) -> some View {
        return HStack(spacing: 2) {
            ForEach(daysOfWeek(for: weekOffset), id: \.timeIntervalSince1970) { date in
                let calendar = AppDateFormatter.shared.getUserCalendar()
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: Date())
                
                Button(action: {
                    selectDate(date)
                }) {
                    VStack(spacing: 4) {
                        Text(dayAbbreviation(for: date))
                            .font(.appLabelSmall)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .text04)
                        
                        Text("\(calendar.component(.day, from: date))")
                            .font(.appBodyMedium)
                            .foregroundColor(isSelected ? .white : (isToday ? .primary : .text01))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.primary : (isToday ? Color.primary.opacity(0.1) : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isToday && !isSelected ? Color.primary : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func selectDate(_ date: Date) {
        selectedDate = date
        
        // Auto-collapse if expanded
        if isExpanded {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
        }
        
        // Update week offset to match selected date
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let selectedWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weeksDifference = calendar.dateComponents([.weekOfYear], from: weekStart, to: selectedWeekStart).weekOfYear ?? 0
        currentWeekOffset = weeksDifference
    }
    
    private func goToToday() {
        let today = Date()
        
        // Always collapse to weekly view first
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = false
        }
        
        // Set selected date to today
        selectedDate = today
        
        // Reset to current week (offset 0) - simplified approach
        withAnimation(.easeInOut(duration: 0.2)) {
            currentWeekOffset = 0
        }
        
        // Reset to current month
        currentMonth = today
    }
    
    private func changeMonth(by value: Int) {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

// MARK: - Monthly Calendar Day View
struct MonthlyCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        Text("\(calendar.component(.day, from: date))")
            .font(.appBodyMedium)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isToday && !isSelected ? Color.primary : Color.clear, lineWidth: 1)
            )
            .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .primary
        } else {
            return .text01
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.primary
        } else if isToday && !isSelected {
            return Color.primary.opacity(0.1)
        } else {
            return .clear
        }
    }
}
