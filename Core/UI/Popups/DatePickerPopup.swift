import SwiftUI
import MijickPopups

// MARK: - Date Picker Popup (MijickPopups Version)
struct DatePickerPopup: BottomPopup {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @State private var tempSelectedDate: Date
    @State private var currentMonth: Date = Date()
    
    init(selectedDate: Binding<Date>, onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._tempSelectedDate = State(initialValue: selectedDate.wrappedValue)
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    Task { await dismissLastPopup() }
                }
                .font(.appButtonText1)
                .foregroundColor(.text02)
                
                Spacer()
                
                Text("Select Date")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("Done") {
                    confirmSelection()
                }
                .font(.appButtonText1)
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
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
                        .font(.appHeadlineMedium)
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.text01)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                
                // Weekday headers
                HStack {
                    ForEach(weekdayHeaders, id: \.self) { day in
                        Text(day)
                            .font(.appLabelSmall)
                            .foregroundColor(.text04)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            DatePickerCalendarDayView(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: tempSelectedDate),
                                isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                                isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
                            ) {
                                tempSelectedDate = date
                            }
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 40)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Reset to today button
                if !isTodaySelected {
                    Button(action: {
                        resetToToday()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.appBodyMedium)
                            Text("Reset to today")
                                .font(.appBodyMedium)
                        }
                        .foregroundColor(.text02)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
            Spacer(minLength: 0)
            
            // Selected date display - always at bottom
            Button(action: {
                confirmSelection()
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
                .cornerRadius(20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .onAppear {
            currentMonth = tempSelectedDate
        }
    }
    
    // MARK: - Helper Functions
    
    private func confirmSelection() {
        selectedDate = tempSelectedDate
        onDateSelected(tempSelectedDate)
        Task { await dismissLastPopup() }
    }
    
    private func resetToToday() {
        let today = Date()
        tempSelectedDate = today
        currentMonth = today
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
    
    private func dateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    // MARK: - MijickPopups Configuration
    
    func configurePopup(config: BottomPopupConfig) -> BottomPopupConfig {
        config
            .cornerRadius(20)
            .tapOutsideToDismissPopup(true)
            .enableDragGesture(true)
    }
}

// MARK: - Date Picker Calendar Day View
struct DatePickerCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle for selected date
                if isSelected {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Date text
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.appBodySmall)
                    .foregroundColor(
                        isSelected ? .surface :
                        isToday ? .primary :
                        isCurrentMonth ? .text01 : .text04
                    )
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Usage Example
// To show the date picker popup:
//
// Button("Select Date") {
//     DatePickerPopup(selectedDate: $selectedDate) { date in
//         print("Selected date: \(date)")
//     }
//     .present()
// }
