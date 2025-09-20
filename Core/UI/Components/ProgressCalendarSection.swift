import SwiftUI

struct ProgressCalendarSection: View {
    let selectedHabit: Habit?
    let currentDate: Date
    let monthYearString: () -> String
    let firstDayOfMonth: () -> Int
    let daysInMonth: () -> Int
    let isToday: (Int) -> Bool
    let getDayProgress: (Int) -> Double
    let onDateSelected: (Date) -> Void
    let onTodayPressed: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressCalendarHeader(
                selectedHabit: selectedHabit
            )
            
            ProgressCalendarBody(
                currentDate: currentDate,
                monthYearString: monthYearString,
                firstDayOfMonth: firstDayOfMonth,
                daysInMonth: daysInMonth,
                isToday: isToday,
                getDayProgress: getDayProgress,
                onDateSelected: onDateSelected,
                onTodayPressed: onTodayPressed
            )
        }
    }
}

// MARK: - Calendar Header
struct ProgressCalendarHeader: View {
    let selectedHabit: Habit?
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                // Action handled by parent
            }) {
                HStack(spacing: 0) {
                    ProgressCalendarIcon(selectedHabit: selectedHabit)
                    
                    Spacer()
                        .frame(width: 8)
                    
                    Text(selectedHabit?.name ?? "Overall")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                        .frame(width: 12)
                    
                    Image(systemName: "chevron.down")
                        .font(.appLabelMedium)
                        .foregroundColor(.primaryFocus)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            
            // Vacation status indicator
            if VacationManager.shared.isActive {
                HStack(spacing: 6) {
                    Image("Icon-Vacation_Filled")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.blue)
                    Text("Vacation Mode Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Calendar Icon
struct ProgressCalendarIcon: View {
    let selectedHabit: Habit?
    
    var body: some View {
        if let selectedHabit = selectedHabit {
            HabitIconView(habit: selectedHabit)
                .frame(width: 38, height: 54)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 30, height: 30)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .frame(width: 38, height: 54)
        }
    }
}

// MARK: - Calendar Body
struct ProgressCalendarBody: View {
    let currentDate: Date
    let monthYearString: () -> String
    let firstDayOfMonth: () -> Int
    let daysInMonth: () -> Int
    let isToday: (Int) -> Bool
    let getDayProgress: (Int) -> Double
    let onDateSelected: (Date) -> Void
    let onTodayPressed: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressCalendarHeaderRow(
                currentDate: currentDate,
                monthYearString: monthYearString,
                onTodayPressed: onTodayPressed
            )
            
            ProgressCalendarDaysHeader()
            
            ProgressCalendarGrid(
                firstDayOfMonth: firstDayOfMonth,
                daysInMonth: daysInMonth,
                isToday: isToday,
                getDayProgress: getDayProgress,
                onDateSelected: onDateSelected,
                monthYearString: monthYearString
            )
        }
        .padding(20)
        .background(Color.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.outline3, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Calendar Header Row
struct ProgressCalendarHeaderRow: View {
    let currentDate: Date
    let monthYearString: () -> String
    let onTodayPressed: () -> Void
    
    var body: some View {
        HStack {
            Text(monthYearString())
                .font(.appTitleMedium)
                .foregroundColor(.text01)
            
            Spacer()
            
            ProgressCalendarTodayButton(
                currentDate: currentDate,
                onTodayPressed: onTodayPressed
            )
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Today Button
struct ProgressCalendarTodayButton: View {
    let currentDate: Date
    let onTodayPressed: () -> Void
    
    var body: some View {
        let calendar = Calendar.current
        let today = Date()
        let isCurrentMonth = calendar.isDate(currentDate, equalTo: today, toGranularity: .month)
        let isTodayInCurrentMonth = calendar.isDate(today, equalTo: currentDate, toGranularity: .month)
        
        if !isCurrentMonth || !isTodayInCurrentMonth {
            Button(action: onTodayPressed) {
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
        }
    }
}

// MARK: - Days Header
struct ProgressCalendarDaysHeader: View {
    private var weekdayNames: [String] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if calendar.firstWeekday == 1 { // Sunday
            return ["S", "M", "T", "W", "T", "F", "S"]
        } else { // Monday
            return ["M", "T", "W", "T", "F", "S", "S"]
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdayNames.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.appLabelSmall)
                    .foregroundColor(.text02)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Calendar Grid
struct ProgressCalendarGrid: View {
    let firstDayOfMonth: () -> Int
    let daysInMonth: () -> Int
    let isToday: (Int) -> Bool
    let getDayProgress: (Int) -> Double
    let onDateSelected: (Date) -> Void
    let monthYearString: () -> String
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ProgressCalendarEmptyCells(
                firstDayOfMonth: firstDayOfMonth,
                monthYearString: monthYearString
            )
            
            ProgressCalendarDayCells(
                daysInMonth: daysInMonth,
                isToday: isToday,
                getDayProgress: getDayProgress,
                onDateSelected: onDateSelected,
                monthYearString: monthYearString
            )
        }
        .frame(minHeight: 200)
    }
}

// MARK: - Empty Cells
struct ProgressCalendarEmptyCells: View {
    let firstDayOfMonth: () -> Int
    let monthYearString: () -> String
    
    var body: some View {
        let emptyCells = firstDayOfMonth()
        ForEach(0..<emptyCells, id: \.self) { index in
            Text("")
                .frame(width: 32, height: 32)
        }
    }
}

// MARK: - Day Cells
struct ProgressCalendarDayCells: View {
    let daysInMonth: () -> Int
    let isToday: (Int) -> Bool
    let getDayProgress: (Int) -> Double
    let onDateSelected: (Date) -> Void
    let monthYearString: () -> String
    
    var body: some View {
        let totalDays = daysInMonth()
        ForEach(1...totalDays, id: \.self) { day in
            ProgressCalendarDayCell(
                day: day,
                isToday: isToday(day),
                progress: getDayProgress(day),
                onDateSelected: onDateSelected,
                monthYearString: monthYearString
            )
        }
    }
}

// MARK: - Individual Day Cell
struct ProgressCalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let progress: Double
    let onDateSelected: (Date) -> Void
    let monthYearString: () -> String
    
    var body: some View {
        Button(action: {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            
            let calendar = Calendar.current
            let monthComponents = calendar.dateComponents([.year, .month], from: Date())
            if let dateForDay = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(from: monthComponents) ?? Date()) {
                onDateSelected(dateForDay)
            }
        }) {
            ZStack {
                Circle()
                    .fill(isToday ? Color.primary : Color.clear)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .stroke(Color.primaryContainer, lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .opacity(progress > 0 ? 1.0 : 0.0)
                
                Text("\(day)")
                    .font(.appBodySmall)
                    .foregroundColor(isToday ? .onPrimary : .text01)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
