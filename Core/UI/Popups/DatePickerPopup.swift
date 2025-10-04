import SwiftUI
import MijickPopups

// MARK: - Date Picker Popup (MijickPopups Version)
struct DatePickerPopup: BottomPopup {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @State private var tempSelectedDate: Date
    @State private var currentMonth: Date = Date()
    
    init(selectedDate: Binding<Date>, onDateSelected: @escaping (Date) -> Void) {
        print("📅 DatePickerPopup: Initializing with date: \(selectedDate.wrappedValue)")
        self._selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._tempSelectedDate = State(initialValue: selectedDate.wrappedValue)
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.text03)
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            // Header
            HStack {
                Button("Cancel") {
                    Task { await dismissLastPopup() }
                }
                .font(.appButtonText1)
                .foregroundColor(.text02)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.surfaceContainer)
                .cornerRadius(12)
                
                Spacer()
                
                Text("Select Date")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("Done") {
                    confirmSelection()
                }
                .font(.appButtonText1)
                .foregroundColor(.onPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Custom Calendar
            VStack(spacing: 16) {
                // Month navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceContainer)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.surfaceContainer)
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceContainer)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                
                // Weekday headers
                HStack {
                    ForEach(weekdayHeaders, id: \.self) { day in
                        Text(day)
                            .font(.appBodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(.text02)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
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
                .padding(.horizontal, 24)
                
                // Reset to today button
                if !isTodaySelected {
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            resetToToday()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.appBodyMedium)
                            Text("Reset to today")
                                .font(.appBodyMedium)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.surfaceContainer)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            
            Spacer(minLength: 0)
            
            // Selected date display - always at bottom
            VStack(spacing: 12) {
                // Selected date info
                VStack(spacing: 4) {
                    Text("Selected Date")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                    
                    Text(dateText(from: tempSelectedDate))
                        .font(.appTitleLargeEmphasised)
                        .foregroundColor(.text01)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                // Confirm button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        confirmSelection()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Confirm Selection")
                            .font(.appButtonText1)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400) // Reduced height to ensure it fits
        .onAppear {
            print("📅 DatePickerPopup: onAppear called - popup should be visible now")
            print("📅 DatePickerPopup: Current month set to: \(currentMonth)")
            currentMonth = tempSelectedDate
        }
        .background(Color.surface) // Ensure background is set
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
            .cornerRadius(24)
            .tapOutsideToDismissPopup(true)
            .enableDragGesture(true)
            .heightMode(.auto)
            .backgroundColor(.black.opacity(0.4))
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
                        .frame(width: 36, height: 36)
                        .shadow(color: .primary.opacity(0.3), radius: 4, x: 0, y: 2)
                } else if isToday {
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                
                // Date text
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.appBodyMedium)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(
                        isSelected ? .onPrimary :
                        isToday ? .primary :
                        isCurrentMonth ? .text01 : .text03
                    )
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
