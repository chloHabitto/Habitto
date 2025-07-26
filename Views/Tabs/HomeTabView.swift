import SwiftUI

struct HomeTabView: View {
    @Binding var selectedDate: Date
    @Binding var selectedStatsTab: Int
    @Binding var tabWidths: [CGFloat]
    @State private var currentWeekOffset: Int = 0
    @State private var scrollPosition: Int? = 0
    @State private var lastHapticWeek: Int = 0
    @State private var isDragging: Bool = false
    let habits: [Habit]
    let onToggleHabit: (Habit) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 0) {
                dateSection
                weeklyCalendar
                                 VStack(spacing: 0) {
                     // Stats row content (tab bar)
                     VStack(spacing: 0) {
                         HStack(spacing: 0) {
                             ForEach(0..<stats.count, id: \.self) { idx in
                                 Button(action: { selectedStatsTab = idx }) {
                                     HStack(spacing: 4) {
                                         Text(stats[idx].0)
                                             .font(.system(size: 15, weight: .semibold))
                                             .foregroundColor(selectedStatsTab == idx ? selectedColor : unselectedColor)
                                         Text("\(stats[idx].1)")
                                             .font(.system(size: 15, weight: .semibold))
                                             .foregroundColor(selectedStatsTab == idx ? selectedColor : unselectedColor)
                                     }
                                     .padding(.horizontal, 16)
                                     .padding(.vertical, 8)
                                     .background(GeometryReader { geo in
                                         Color.clear
                                             .preference(key: TabWidthPreferenceKey.self, value: [idx: geo.size.width])
                                     })
                                 }
                                 .buttonStyle(PlainButtonStyle())
                             }
                             Spacer()
                         }
                         .background(Color.white)
                         .onPreferenceChange(TabWidthPreferenceKey.self) { value in
                             for (idx, width) in value {
                                 if tabWidths.count > idx {
                                     tabWidths[idx] = width
                                 }
                             }
                         }
                         
                         // Colored underline for selected tab
                         GeometryReader { geo in
                             let xOffset = tabWidths.prefix(selectedStatsTab).reduce(0, +)
                             Rectangle()
                                 .fill(selectedColor)
                                 .frame(width: tabWidths[selectedStatsTab], height: 3)
                                 .offset(x: xOffset, y: 0)
                                 .animation(.easeInOut(duration: 0.2), value: selectedStatsTab)
                         }
                         .frame(height: 3)
                         
                         // Gray underline directly under the colored underline
                         Rectangle()
                             .fill(Color(red: 0.91, green: 0.93, blue: 0.97))
                             .frame(height: 1)
                             .frame(maxWidth: .infinity)
                     }
                     .padding(.horizontal, 0)
                     .padding(.top, 2)
                     .padding(.bottom, 0)
                     .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                 }
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .frame(alignment: .top)
            .roundedTopBackground()
            // Scrollable habits list fills the rest
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if habitsForSelectedDate.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No habits yet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Create your first habit to get started")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(habitsForSelectedDate) { habit in
                                habitRow(habit)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .roundedTopBackground()
        .onAppear {
            print("🏠 HomeTabView appeared!")
        }
    }
    
    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(habit.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if !habit.description.isEmpty {
                    Text(habit.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Streak indicator
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 12))
                Text("\(habit.streak)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // Checkbox
            Button(action: {
                onToggleHabit(habit)
            }) {
                Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(habit.isCompleted ? .green : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var habitsForSelectedDate: [Habit] {
        let filteredHabits = habits.filter { habit in
            let calendar = Calendar.current
            let selected = calendar.startOfDay(for: selectedDate)
            let start = calendar.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            
            // First check if the date is within the habit period
            guard selected >= start && selected <= end else {
                return false
            }
            
            // Then check if the habit should appear on this specific date based on schedule
            return shouldShowHabitOnDate(habit, date: selectedDate)
        }
        
        return filteredHabits
    }
    
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if the date is before the habit start date
        if date < calendar.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        if let endDate = habit.endDate, date > calendar.startOfDay(for: endDate) {
            return false
        }
        
        switch habit.schedule {
        case "Everyday":
            return true
            
        case let schedule where schedule.hasPrefix("Every ") && schedule.contains("days"):
            // Handle "Every X days" format
            if let dayCount = extractDayCount(from: schedule) {
                let startDate = calendar.startOfDay(for: habit.startDate)
                let selectedDate = calendar.startOfDay(for: date)
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: selectedDate).day ?? 0
                return daysSinceStart >= 0 && daysSinceStart % dayCount == 0
            }
            return false
            
        case let schedule where schedule.hasPrefix("Every "):
            // Handle specific weekdays like "Every Monday, Wednesday"
            let weekdays = extractWeekdays(from: schedule)
            return weekdays.contains(weekday)
            
        default:
            // For any other schedule, show the habit
            return true
        }
    }
    
    private func extractDayCount(from schedule: String) -> Int? {
        // Extract number from "Every X days" format
        let pattern = "Every (\\d+) days?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) {
            let range = match.range(at: 1)
            let numberString = (schedule as NSString).substring(with: range)
            return Int(numberString)
        }
        return nil
    }
    
    private func extractWeekdays(from schedule: String) -> Set<Int> {
        // Extract weekdays from "Every Monday, Wednesday" format
        var weekdays: Set<Int> = []
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        
        for (index, dayName) in weekdayNames.enumerated() {
            if schedule.contains(dayName) {
                // Calendar weekday is 1-based, where 1 = Sunday
                weekdays.insert(index + 1)
            }
        }
        
        return weekdays
    }
    
    private var stats: [(String, Int)] {
        let habitsForDate = habitsForSelectedDate
        return [
            ("Total", habitsForDate.count),
            ("Undone", habitsForDate.filter { !$0.isCompleted }.count),
            ("Done", habitsForDate.filter { $0.isCompleted }.count)
        ]
    }
    
    private var selectedColor: Color {
        Color(red: 0.15, green: 0.23, blue: 0.42) // Dark blue to match your theme
    }
    
    private var unselectedColor: Color {
        Color(UIColor.systemGray)
    }
    
         // MARK: - Date Section
     private var dateSection: some View {
         HStack {
             Text(formattedCurrentDate)
                 .font(.system(size: 16, weight: .bold))
                 .lineSpacing(8)
                 .foregroundColor(.primary)
             
             Spacer()
             
             HStack(spacing: 12) {
                 // Today button (shown when selected date is not today)
                 if !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                     Button(action: {
                         withAnimation(.easeInOut(duration: 0.08)) {
                             selectedDate = Date()
                         }
                     }) {
                         HStack(spacing: 4) {
                             Image("Icon-replay")
                                 .resizable()
                                 .frame(width: 12, height: 12)
                             Text("Today")
                                 .font(.system(size: 12, weight: .medium))
                                 .lineSpacing(16)
                         }
                         .foregroundColor(Color(red: 0.11, green: 0.15, blue: 0.30)) // #1C274C
                         .padding(.leading, 8)
                         .padding(.trailing, 12)
                         .padding(.top, 4)
                         .padding(.bottom, 4)
                         .overlay(
                             RoundedRectangle(cornerRadius: .infinity)
                                 .stroke(Color(red: 0.11, green: 0.15, blue: 0.30), lineWidth: 1) // #1C274C
                         )
                     }
                 }
                 
                 Button(action: {}) {
                     Image("Icon-calendar")
                         .resizable()
                         .frame(width: 20, height: 20)
                         .foregroundColor(.secondary)
                 }
                 .frame(width: 44, height: 44)
                 .padding(.trailing, 4)
             }
         }
         .frame(height: 44)
         .padding(.leading, 16)
         .padding(.trailing, 8)
         .padding(.top, 4)
         .padding(.bottom, 0)
     }
    
         // MARK: - Weekly Calendar
     private var weeklyCalendar: some View {
         GeometryReader { geometry in
             ScrollViewReader { proxy in
                 ScrollView(.horizontal, showsIndicators: false) {
                     LazyHStack(spacing: 0) {
                         ForEach(-52...52, id: \.self) { weekOffset in
                             weekView(for: weekOffset, width: geometry.size.width)
                                 .frame(width: geometry.size.width)
                                 .id(weekOffset)
                         }
                     }
                     .scrollTargetLayout()
                     .scrollPosition(id: $scrollPosition)
                 }
                 .scrollTargetBehavior(.paging)
                 .onAppear {
                     print("📱 Weekly calendar appeared!")
                     print("📅 Calendar range: -52 to +52 weeks (104 total weeks)")
                     print("📅 Current week offset: 0")
                     
                     // Scroll to the current week (offset 0) immediately
                     proxy.scrollTo(0, anchor: .center)
                 }
                 .onChange(of: scrollPosition) { oldValue, newValue in
                     if let newPosition = newValue, newPosition != oldValue {
                         // Update current week offset
                         currentWeekOffset = newPosition
                         
                         // Trigger haptic feedback when week changes
                         if newPosition != lastHapticWeek {
                             let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                             impactFeedback.impactOccurred()
                             lastHapticWeek = newPosition
                         }
                     }
                 }
                 .simultaneousGesture(
                     DragGesture()
                         .onChanged { _ in
                             isDragging = true
                         }
                         .onEnded { _ in
                             isDragging = false
                             // Trigger haptic when drag ends
                             let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                             impactFeedback.impactOccurred()
                         }
                 )
                 .onTapGesture {
                     // Trigger haptic on tap as well
                     let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                     impactFeedback.impactOccurred()
                 }
             }
         }
         .frame(height: 72)
         .padding(.horizontal, 8)
         .padding(.top, 4)
         .padding(.bottom, 8)
     }
    
    private func weekView(for weekOffset: Int, width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(daysOfWeek(for: weekOffset), id: \.self) { date in
                VStack(spacing: 4) {
                    Text(dayAbbreviation(for: date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor(for: date))
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor(for: date))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(backgroundColor(for: date))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        selectedDate = date
                    }
                }
                .onAppear {
                    // Debug: Print when each date appears
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    print("📅 Date appeared: \(formatter.string(from: date))")
                    
                    // Test if this is today
                    if Calendar.current.isDate(date, inSameDayAs: Date()) {
                        print("🎯 This is today!")
                    }
                }
            }
        }
        .frame(width: width)
        .padding(.horizontal, 20)
        .onAppear {
            print("📅 Week \(weekOffset) appeared")
        }
    }
    
    private func backgroundColor(for date: Date) -> Color {
        print("🎨 backgroundColor called for date: \(date)")
        
        let calendar = Calendar.current
        let today = Date()
        
        // Debug: Print the dates being compared
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("Comparing: date=\(formatter.string(from: date)), today=\(formatter.string(from: today)), selected=\(formatter.string(from: selectedDate))")
        
        // Normalize dates to start of day for comparison
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedSelected = calendar.startOfDay(for: selectedDate)
        
        // Check if this is the selected date
        if normalizedDate == normalizedSelected {
            print("✅ Selected date match found!")
            return Color(red: 0.70, green: 0.77, blue: 1.0) // #B3C4FF
        }
        
        // Check for today's date (but not selected)
        if normalizedDate == normalizedToday && normalizedDate != normalizedSelected {
            print("✅ Today match found!")
            return Color(red: 0.93, green: 0.95, blue: 1.0) // #EDF1FF
        }
        
        // Default - no background
        return Color.clear
    }
    
    private func textColor(for date: Date) -> Color {
        // All dates use #191919 text
        return Color(red: 0.10, green: 0.10, blue: 0.10) // #191919
    }
    
    // MARK: - Helper Functions
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMMM"
        return formatter.string(from: selectedDate)
    }
    
    private func daysOfWeek(for weekOffset: Int) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        let today = Date()
        
        // Get the start of the week containing today (Monday)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }
        
        // Calculate the target week based on offset
        // weekOffset 0 = current week, -1 = previous week, +1 = next week
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart) else {
            return []
        }
        
        // Generate 7 days starting from the target week start (Monday)
        let dates = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: targetWeekStart)
        }
        
        // Debug: Print the dates for this week
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("Week offset \(weekOffset): \(dates.map { formatter.string(from: $0) })")
        
        return dates
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

struct TabWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

 
