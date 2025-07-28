import SwiftUI

struct HomeTabView: View {
    @Binding var selectedDate: Date
    @Binding var selectedStatsTab: Int
    @State private var currentWeekOffset: Int = 0
    @State private var scrollPosition: Int? = 0
    @State private var lastHapticWeek: Int = 0
    @State private var isDragging: Bool = false
    @State private var selectedHabit: Habit? = nil
    let habits: [Habit]
    let onToggleHabit: (Habit) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            habitsListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .roundedTopBackground()
        .onAppear {
            // Ensure selectedDate is set to today when the view appears
            let today = Calendar.current.startOfDay(for: Date())
            if selectedDate != today {
                selectedDate = today
            }
        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            dateSection
            weeklyCalendar
            statsRowSection
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 0)
        .frame(alignment: .top)
        .roundedTopBackground()
    }
    
    @ViewBuilder
    private var statsRowSection: some View {
        statsTabBar
            .padding(.horizontal, 0)
            .padding(.top, 2)
            .padding(.bottom, 0)
    }
    
    @ViewBuilder
    private var statsTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<stats.count, id: \.self) { idx in
                statsTabButton(for: idx)

            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    @ViewBuilder
    private func statsTabButton(for idx: Int) -> some View {
        VStack(spacing: 0) {
            Button(action: { 
                if idx != 3 { // Only allow clicking for non-fourth tabs
                    selectedStatsTab = idx 
                }
            }) {
                HStack(spacing: 4) {
                    Text(stats[idx].0)
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx == 3 ? 0 : 1) // Make fourth tab text invisible
                    Text("\(stats[idx].1)")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(selectedStatsTab == idx ? .text03 : .text04)
                        .opacity(idx == 3 ? 0 : 1) // Make fourth tab text invisible
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: idx == 3 ? .infinity : nil) // Only expand the fourth tab (index 3)
            .disabled(idx == 3) // Disable clicking for fourth tab
            
            // Bottom stroke for each tab
            Rectangle()
                .fill(selectedStatsTab == idx ? .text03 : .divider)
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: selectedStatsTab)
        }
    }
    

    
    @ViewBuilder
    private var habitsListSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if habitsForSelectedDate.isEmpty {
                    emptyStateView
                } else {
                    habitsListView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .font(.appDisplaySmall)
                .foregroundColor(.secondary)
            Text("No habits yet")
                .font(.appButtonText2)
                .foregroundColor(.secondary)
            Text("Create your first habit to get started")
                .font(.appBodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private var habitsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(habitsForSelectedDate) { habit in
                habitRow(habit)
            }
        }
    }
    
    private func habitRow(_ habit: Habit) -> some View {
        ScheduledHabitItem(
            habit: habit,
            isCompleted: Binding(
                get: { habit.isCompleted },
                set: { _ in onToggleHabit(habit) }
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedHabit = habit
        }
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
            ("Done", habitsForDate.filter { $0.isCompleted }.count),
            ("New", habitsForDate.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: selectedDate) }.count)
        ]
    }
    

    
         // MARK: - Date Section
     private var dateSection: some View {
         HStack {
             Text(formattedCurrentDate)
                                                 .font(.appTitleLargeEmphasised)
                 .lineSpacing(8)
                 .foregroundColor(.primary)
             
             Spacer()
             
             HStack(spacing: 4) {
                 // Today button (shown when not on current week or selected date is not today)
                 let calendar = Calendar.current
                 let today = Date()
                 let isTodayInCurrentWeek = daysOfWeek(for: currentWeekOffset).contains { date in
                     calendar.isDate(date, inSameDayAs: today)
                 }
                 let isTodaySelected = calendar.isDate(selectedDate, inSameDayAs: today)
                 
                 if !isTodayInCurrentWeek || !isTodaySelected {
                     Button(action: {
                         withAnimation(.easeInOut(duration: 0.08)) {
                             selectedDate = Date()
                         }
                     }) {
                         HStack(spacing: 4) {
                             Image("Icon-replay")
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(-100...100, id: \.self) { weekOffset in
                        weekView(for: weekOffset, width: UIScreen.main.bounds.width - 16)
                            .frame(width: UIScreen.main.bounds.width - 16)
                            .id(weekOffset)
                            .onAppear {
                                // Week appeared
                            }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { oldValue, newValue in
                if let newValue = newValue {
                    currentWeekOffset = newValue
                }
            }
            .onAppear {
                // Ensure we're on the current week
                scrollPosition = 0
                currentWeekOffset = 0
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        // Handle drag gesture if needed
                    }
                    .onEnded { _ in
                        // Handle drag gesture end if needed
                    }
            )
        }
        .frame(height: 72)
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
    
    private func weekView(for weekOffset: Int, width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(daysOfWeek(for: weekOffset), id: \.self) { date in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        selectedDate = date
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(dayAbbreviation(for: date))
                            .font(.appLabelSmall)
                            .foregroundColor(textColor(for: date))
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(dateFont(for: date))
                            .foregroundColor(textColor(for: date))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(backgroundColor(for: date))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    // Optional: Add any specific logic for when dates appear
                }
            }
        }
        .frame(width: width)
        .padding(.horizontal, 20)
    }
    
    private func backgroundColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates to start of day for comparison
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedSelected = calendar.startOfDay(for: selectedDate)
        

        
        // Check for today's date (highest priority)
        if normalizedDate == normalizedToday {
            print("🎯 Today's date found! Using green background")
            print("🎯 Date: \(date)")
            print("🎯 Normalized date: \(normalizedDate)")
            print("🎯 Normalized today: \(normalizedToday)")
            return .success // Use success color (green500) for maximum visibility
        }
        
        // Debug: Print all dates being processed
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("📅 Processing date: \(formatter.string(from: date))")
        print("📅 Is today? \(normalizedDate == normalizedToday)")
        print("📅 Is selected? \(normalizedDate == normalizedSelected)")
        
        // Check if this is the selected date (but not today)
        if normalizedDate == normalizedSelected {
            return .secondary
        }
        
        // Default - no background
        return Color.clear
    }
    
    private func textColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates to start of day for comparison
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedSelected = calendar.startOfDay(for: selectedDate)
        
        // If this is today, use white text for contrast against green background
        if normalizedDate == normalizedToday {
            return .white
        }
        
        // If this is the selected date (but not today), use text01 for better contrast
        if normalizedDate == normalizedSelected {
            return .text01
        }
        
        // For all other dates, use text04
        return .text04
    }
    
    private func dateFont(for date: Date) -> Font {
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates to start of day for comparison
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedSelected = calendar.startOfDay(for: selectedDate)
        
        // If this is today or the selected date, use emphasized font
        if normalizedDate == normalizedToday || normalizedDate == normalizedSelected {
            return .appLabelLargeEmphasised
        }
        
        // For all other dates, use regular font
        return .appLabelLarge
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
            print("❌ Failed to get week start for weekOffset: \(weekOffset)")
            return []
        }
        
        // Calculate the target week based on offset
        // weekOffset 0 = current week, -1 = previous week, +1 = next week
        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart) else {
            print("❌ Failed to calculate target week for weekOffset: \(weekOffset)")
            return []
        }
        
        // Generate 7 days starting from the target week start (Monday)
        let dates = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: targetWeekStart)
        }
        
        // Debug: Print the dates for this week
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("📅 Week \(weekOffset) dates: \(dates.map { formatter.string(from: $0) })")
        print("📅 Today: \(formatter.string(from: Date()))")
        print("📅 Selected date: \(formatter.string(from: selectedDate))")
        
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



 

