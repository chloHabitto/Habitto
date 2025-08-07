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
    let onToggleHabit: (Habit, Date) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    let onDeleteHabit: ((Habit) -> Void)?
    
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
            print("🏠 HomeTabView: Total habits passed: \(habits.count)")
            print("🏠 HomeTabView: Selected date: \(selectedDate)")
            
            // Ensure selectedDate is set to today when the view appears
            let today = Calendar.current.startOfDay(for: Date())
            if selectedDate != today {
                selectedDate = today
            }
            
            print("🏠 HomeTabView: Pre-calculated stats - Total: \(stats.indices.contains(0) ? stats[0].1 : 0), Undone: \(stats.indices.contains(1) ? stats[1].1 : 0), Done: \(stats.indices.contains(2) ? stats[2].1 : 0)")
            
            // Debug: Print each habit's details
            for (index, habit) in habits.enumerated() {
                print("🏠 HomeTabView: Habit \(index): \(habit.name), startDate: \(habit.startDate), schedule: '\(habit.schedule)'")
                print("🏠 HomeTabView: Habit \(index): goal: '\(habit.goal)', habitType: \(habit.habitType)")
            }
        }
        .onChange(of: habits.count) { oldCount, newCount in
            // Only clear cache if habits actually changed (not just count)
            print("🏠 HomeTabView: Habits count changed from \(oldCount) to \(newCount)")
            
            // Check if habits array content actually changed by comparing IDs
            let oldHabitIds = Set(habits.prefix(oldCount).map { $0.id })
            let newHabitIds = Set(habits.prefix(newCount).map { $0.id })
            
            if oldHabitIds != newHabitIds {
                print("🏠 HomeTabView: Habits content changed, clearing cache")
                cachedHabitsForDate = []
                lastCalculatedDate = nil
                cachedStats = []
                lastCalculatedStatsDate = nil
            }
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // Only clear cache if date actually changed significantly
            let calendar = Calendar.current
            let oldDay = calendar.startOfDay(for: oldDate)
            let newDay = calendar.startOfDay(for: newDate)
            
            if oldDay != newDay {
                print("🏠 HomeTabView: Selected date changed from \(oldDate) to \(newDate), clearing cache")
                cachedHabitsForDate = []
                lastCalculatedDate = nil
            }
        }
        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: selectedDate, onDeleteHabit: onDeleteHabit)
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
        let tabs = TabItem.createHomeStatsTabs(
            totalCount: stats.indices.contains(0) ? stats[0].1 : 0,
            undoneCount: stats.indices.contains(1) ? stats[1].1 : 0,
            doneCount: stats.indices.contains(2) ? stats[2].1 : 0
        )
        
        UnifiedTabBarView(
            tabs: tabs,
            selectedIndex: selectedStatsTab,
            style: .underline
        ) { index in
            selectedStatsTab = index // All tabs are now clickable
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
        return ScheduledHabitItem(
            habit: habit,
            selectedDate: selectedDate,
            onRowTap: {
                print("📱 Row tapped for habit: \(habit.name)")
                selectedHabit = habit
            },
            onProgressChange: { habit, date, progress in
                print("🔄 Progress changed for habit: \(habit.name) to \(progress)")
                // Update the habit's progress
                var updatedHabit = habit
                let dateKey = DateUtils.dateKey(for: date)
                updatedHabit.completionHistory[dateKey] = progress
                onUpdateHabit?(updatedHabit)
            },
            onEdit: {
                print("✏️ Edit tapped for habit: \(habit.name)")
                selectedHabit = habit
            },
            onDelete: {
                print("🗑️ Delete tapped for habit: \(habit.name)")
                onDeleteHabit?(habit)
            }
        )
    }
    
    private var habitsForSelectedDate: [Habit] {
        // Use cached result if available and date hasn't changed
        if let lastDate = lastCalculatedDate, lastDate == selectedDate {
            return cachedHabitsForDate
        }
        
        // Calculate filtered habits for the selected date
        let filteredHabits = habits.filter { habit in
            let selected = DateUtils.startOfDay(for: selectedDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            // First check if the date is within the habit period
            guard selected >= start && selected <= end else {
                return false
            }
            
            // Then check if the habit should appear on this specific date based on schedule
            let shouldShow = shouldShowHabitOnDate(habit, date: selectedDate)
            return shouldShow
        }
        
        // Update cache for future use
        if lastCalculatedDate != selectedDate {
            DispatchQueue.main.async {
                self.cachedHabitsForDate = filteredHabits
                self.lastCalculatedDate = self.selectedDate
            }
        }
        
        return filteredHabits
    }
    
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let weekday = DateUtils.weekday(for: date)
        
        // Check if the date is before the habit start date
        if date < DateUtils.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        // Use >= to be inclusive of the end date
        if let endDate = habit.endDate, date > DateUtils.endOfDay(for: endDate) {
            return false
        }
        
        switch habit.schedule {
        case "Everyday":
            return true
        case "Weekdays":
            return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
        case "Weekends":
            return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
        default:
            // Handle custom schedules like "Every Monday, Wednesday, Friday"
            if habit.schedule.contains("Every") && habit.schedule.contains("day") {
                // Extract weekdays from schedule
                let weekdays = extractWeekdays(from: habit.schedule)
                return weekdays.contains(weekday)
            } else if habit.schedule.contains("Every") && habit.schedule.contains("days") {
                // Handle "Every X days" schedules
                guard let dayCount = extractDayCount(from: habit.schedule) else {
                    return false
                }
                
                let startDate = DateUtils.startOfDay(for: habit.startDate)
                let targetDate = DateUtils.startOfDay(for: date)
                let daysSinceStart = DateUtils.daysBetween(startDate, targetDate)
                
                // Check if the target date falls on the schedule
                return daysSinceStart >= 0 && daysSinceStart % dayCount == 0
            } else if habit.schedule.contains("times per week") {
                // Handle "X times per week" schedules
                let schedule = habit.schedule.lowercased()
                let timesPerWeek = extractTimesPerWeek(from: schedule)
                
                if timesPerWeek != nil {
                    // For now, show the habit if it's within the week
                    // This is a simplified implementation
                    let weekStart = DateUtils.startOfWeek(for: date)
                    let weekEnd = DateUtils.endOfWeek(for: date)
                    let isInWeek = date >= weekStart && date <= weekEnd
                    return isInWeek
                }
                return false
            }
            // For any other schedule, show the habit
            return true
        }
    }
    
    private func extractDayCount(from schedule: String) -> Int? {
        let pattern = #"Every (\d+) days?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
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
    
    private func extractTimesPerWeek(from schedule: String) -> Int? {
        let pattern = #"(\d+) times per week"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    private var stats: [(String, Int)] {
        // Calculate stats directly from habitsForSelectedDate to ensure they're always up to date
        let habitsForDate = habitsForSelectedDate
        return [
            ("Total", habitsForDate.count),
            ("Undone", habitsForDate.filter { $0.getProgress(for: selectedDate) == 0 }.count),
            ("Done", habitsForDate.filter { $0.getProgress(for: selectedDate) > 0 }.count)
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
            
            // Add haptic feedback when scrolling between weeks
            if oldValue != newValue {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
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
            ForEach(daysOfWeek(for: weekOffset), id: \.timeIntervalSince1970) { date in
                Button(action: {
                    // Add haptic feedback when selecting a date
                    let selectionFeedback = UISelectionFeedbackGenerator()
                    selectionFeedback.selectionChanged()
                    
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
            return .primary // Use primary color for today's date
        }
        
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
    
    // MARK: - Stats Update Function
    private func updateStats() {
        let habitsForDate = habitsForSelectedDate
        cachedStats = [
            ("Total", habitsForDate.count),
            ("Undone", habitsForDate.filter { !$0.isCompleted(for: selectedDate) }.count),
            ("Done", habitsForDate.filter { $0.isCompleted(for: selectedDate) }.count),
            ("New", habitsForDate.filter { DateUtils.isSameDay($0.createdAt, selectedDate) }.count)
        ]
        lastCalculatedStatsDate = selectedDate
        
        print("🏠 HomeTabView: Updated stats - Total: \(cachedStats.indices.contains(0) ? cachedStats[0].1 : 0), Undone: \(cachedStats.indices.contains(1) ? cachedStats[1].1 : 0), Done: \(cachedStats.indices.contains(2) ? cachedStats[2].1 : 0)")
    }
}
