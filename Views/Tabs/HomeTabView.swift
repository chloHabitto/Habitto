import SwiftUI

struct HomeTabView: View {
    @Binding var selectedDate: Date
    @Binding var selectedStatsTab: Int
    @State private var currentWeekOffset: Int = 0

    @State private var lastHapticWeek: Int = 0
    @State private var isDragging: Bool = false
    @State private var selectedHabit: Habit? = nil
    
    // Performance optimization: Cache expensive calculations
    @State private var cachedHabitsForDate: [Habit] = []
    @State private var lastCalculatedDate: Date?
    @State private var cachedStats: [(String, Int)] = []
    @State private var lastCalculatedStatsDate: Date?
    let habits: [Habit]
    let onToggleHabit: (Habit) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    
    // Performance optimization: Cached regex patterns
    private static let dayCountRegex = try? NSRegularExpression(pattern: "Every (\\d+) days?", options: .caseInsensitive)
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        WhiteSheetContainer(
            headerContent: {
                AnyView(
                    VStack(spacing: 0) {
                        dateSection
                        weeklyCalendar
                        statsRowSection
                    }
                )
            }
        ) {
            habitsListSection
        }
        .onAppear {
            print("🏠 HomeTabView appeared!")
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
        let today = Calendar.current.startOfDay(for: Date())
        let isCompletedToday = habit.isCompleted(for: today)
        
        return ScheduledHabitItem(
            habit: habit,
            isCompleted: Binding(
                get: { isCompletedToday },
                set: { _ in onToggleHabit(habit) }
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedHabit = habit
        }
    }
    
    private var habitsForSelectedDate: [Habit] {
        // Performance optimization: Use cached result if date hasn't changed
        if lastCalculatedDate != selectedDate {
            let filteredHabits = habits.filter { habit in
                let selected = DateUtils.startOfDay(for: selectedDate)
                let start = DateUtils.startOfDay(for: habit.startDate)
                let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
                
                // First check if the date is within the habit period
                guard selected >= start && selected <= end else {
                    return false
                }
                
                // Then check if the habit should appear on this specific date based on schedule
                return shouldShowHabitOnDate(habit, date: selectedDate)
            }
            
            cachedHabitsForDate = filteredHabits
            lastCalculatedDate = selectedDate
        }
        
        return cachedHabitsForDate
    }
    
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let weekday = DateUtils.weekday(for: date)
        
        // Check if the date is before the habit start date
        if date < DateUtils.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        if let endDate = habit.endDate, date > DateUtils.startOfDay(for: endDate) {
            return false
        }
        
        switch habit.schedule {
        case "Everyday":
            return true
            
        case let schedule where schedule.hasPrefix("Every ") && schedule.contains("days"):
            // Handle "Every X days" format
            if let dayCount = extractDayCount(from: schedule) {
                let startDate = DateUtils.startOfDay(for: habit.startDate)
                let selectedDate = DateUtils.startOfDay(for: date)
                let daysSinceStart = DateUtils.daysBetween(startDate, selectedDate)
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
        // Performance optimization: Use cached regex pattern
        guard let regex = Self.dayCountRegex,
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    private func extractWeekdays(from schedule: String) -> Set<Int> {
        // Performance optimization: Use cached weekday names
        var weekdays: Set<Int> = []
        
        for (index, dayName) in Self.weekdayNames.enumerated() {
            if schedule.contains(dayName) {
                // Calendar weekday is 1-based, where 1 = Sunday
                weekdays.insert(index + 1)
            }
        }
        
        return weekdays
    }
    
    private var stats: [(String, Int)] {
        // Performance optimization: Use cached stats if date hasn't changed
        if lastCalculatedStatsDate != selectedDate {
            let habitsForDate = habitsForSelectedDate
            cachedStats = [
                ("Total", habitsForDate.count),
                ("Undone", habitsForDate.filter { !$0.isCompleted }.count),
                ("Done", habitsForDate.filter { $0.isCompleted }.count),
                ("New", habitsForDate.filter { DateUtils.isSameDay($0.createdAt, selectedDate) }.count)
            ]
            lastCalculatedStatsDate = selectedDate
        }
        
        return cachedStats
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
                             currentWeekOffset = 0
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
        TabView(selection: $currentWeekOffset) {
            ForEach(-100...100, id: \.self) { weekOffset in
                weekView(for: weekOffset, width: UIScreen.main.bounds.width - 16)
                    .frame(width: UIScreen.main.bounds.width - 16)
                    .tag(weekOffset)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: currentWeekOffset) { oldValue, newValue in
            print("📅 TabView selection changed from \(oldValue) to \(newValue)")
        }
        .onAppear {
            print("📅 Calendar onAppear - setting currentWeekOffset to 0")
            currentWeekOffset = 0
            print("📅 Calendar onAppear - currentWeekOffset set to 0")
        }
        .frame(height: 72)
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
    
    private func weekView(for weekOffset: Int, width: CGFloat) -> some View {
        return HStack(spacing: 2) {
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
        
        // Debug: Print all dates being processed (optimized)
        print("🔍 backgroundColor called for date: \(DateUtils.debugString(for: date))")
        print("🔍 Normalized date: \(DateUtils.debugString(for: normalizedDate))")
        print("🔍 Normalized today: \(DateUtils.debugString(for: normalizedToday))")
        print("🔍 Is today? \(normalizedDate == normalizedToday)")
        print("🔍 Week offset: \(currentWeekOffset)")
        
                    // Check for today's date (highest priority)
            if normalizedDate == normalizedToday {
                return ColorPrimitives.navy500 // Use primary color for today's date
            }
        
        // Debug: Print all dates being processed (optimized)
        print("📅 Processing date: \(DateUtils.debugString(for: date))")
        print("📅 Is today? \(normalizedDate == normalizedToday)")
        print("📅 Is selected? \(normalizedDate == normalizedSelected)")
        
        // Check if this is the selected date (but not today)
        if normalizedDate == normalizedSelected {
            print("🔍 Selected date found: \(date)")
            return .secondary
        }
        
        // Default - no background
        print("🔍 Returning clear background for date: \(DateUtils.debugString(for: date))")
        return Color.clear
    }
    
    private func textColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        // Normalize dates to start of day for comparison
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedToday = calendar.startOfDay(for: today)
        let normalizedSelected = calendar.startOfDay(for: selectedDate)
        
        // If this is today, use white text for contrast against primary background
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
        
        // For weekOffset 0, we want the current week that contains today
        // For other offsets, we calculate relative to the current week
        let targetWeekStart: Date
        if weekOffset == 0 {
            // Get today's weekday (1 = Sunday, 2 = Monday, etc.)
            let weekday = calendar.component(.weekday, from: today)
            // Calculate how many days to subtract to get to Monday
            let daysToSubtract = weekday == 1 ? 6 : weekday - 2 // If Sunday, subtract 6; otherwise subtract (weekday - 2)
            targetWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
        } else {
            // For other weeks, calculate relative to the current week
            let weekday = calendar.component(.weekday, from: today)
            let daysToSubtract = weekday == 1 ? 6 : weekday - 2
            let currentWeekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: today)!
            targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart)!
        }
        
        // Generate 7 days starting from the target week start (Monday)
        let dates = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: targetWeekStart)
        }
        

        
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