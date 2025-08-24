import SwiftUI

// MARK: - Date Picker Modal
struct DatePickerModal: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @State private var tempSelectedDate: Date
    @State private var currentMonth: Date = Date()
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        self._tempSelectedDate = State(initialValue: selectedDate.wrappedValue)
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("Select Date")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    Button("Done") {
                        selectedDate = tempSelectedDate
                        isPresented = false
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Custom Calendar
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
                        ForEach(weekdayHeaders, id: \.self) { day in
                            Text(day)
                                .font(.appLabelMedium)
                                .foregroundColor(.text04)
                                .frame(height: 32)
                        }
                        
                        // Calendar days
                        ForEach(calendarDays, id: \.self) { date in
                            if let date = date {
                                CustomCalendarDayView(
                                    date: date,
                                    isSelected: Calendar.current.isDate(date, inSameDayAs: tempSelectedDate),
                                    isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                                    isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
                                )
                                .onTapGesture {
                                    tempSelectedDate = date
                                }
                            } else {
                                Color.clear
                                    .frame(height: 32)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .id(monthYearString) // Force re-render when month changes
                }
                .frame(height: 300)
                .padding(.horizontal, 20)
                
                // Reset button - only show if date is different from today
                if !isTodaySelected {
                    Button(action: {
                        resetToToday()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.appBodyMedium)
                            Text("Reset to today")
                                .font(.appBodyMedium)
                        }
                        .foregroundColor(.text02)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
                
                // Selected date display
                Button(action: {
                    selectedDate = tempSelectedDate
                    isPresented = false
                }) {
                    VStack(spacing: 8) {
                        Text("Selected Date")
                            .font(.appBodyMedium)
                            .foregroundColor(.surface)
                        
                        Text(dateText(from: tempSelectedDate))
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.surface)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(.surface)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .frame(maxHeight: 480)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            currentMonth = tempSelectedDate
        }
    }
    
    // MARK: - Helper Properties and Functions
    
    private var weekdayHeaders: [String] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if calendar.firstWeekday == 2 { // Monday
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        } else { // Sunday
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }
    
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
        
        // Generate 6 weeks worth of dates (42 days) to ensure we cover the entire month
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func changeMonth(by value: Int) {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
            }
        }
    }
    
    private var isTodaySelected: Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(tempSelectedDate, inSameDayAs: today)
    }
    
    private func resetToToday() {
        tempSelectedDate = Date()
        currentMonth = Date()
    }
    
    private func dateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Custom Calendar Day View
struct CustomCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.appBodyMedium)
                .foregroundColor(textColor)
        }
        .frame(height: 32)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .primary
        } else if isToday {
            return .primary.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .surface
        } else if isToday {
            return .primary
        } else if isCurrentMonth {
            return .text01
        } else {
            return .text06
        }
    }
}

#Preview {
    DatePickerModal(
        selectedDate: .constant(Date()),
        isPresented: .constant(true)
    )
}
