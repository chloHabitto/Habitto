import SwiftUI

struct HomeTabView: View {
    @Binding var selectedDate: Date
    @Binding var selectedStatsTab: Int
    @State private var currentWeekOffset: Int = 0

    @State private var lastHapticWeek: Int = 0
    @State private var isDragging: Bool = false
    @State private var selectedHabit: Habit? = nil
    
    let habits: [Habit]
    let onToggleHabit: (Habit, Date) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    let onSetProgress: ((Habit, Date, Int) -> Void)?
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
            // Ensure selectedDate is set to today when the view appears
            let today = Calendar.current.startOfDay(for: Date())
            if selectedDate != today {
                selectedDate = today
            }
        }

        .fullScreenCover(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: selectedDate, onDeleteHabit: onDeleteHabit)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Swipe right to dismiss (like back button)
                            if value.translation.width > 100 && abs(value.translation.height) < 100 {
                                selectedHabit = nil
                            }
                        }
                )
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
            LazyVStack(alignment: .leading, spacing: 12) {
                if habitsForSelectedDate.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(Array(habitsForSelectedDate.enumerated()), id: \.element.id) { index, habit in
                        habitRow(habit)
                            .id("home-habit-\(habit.id)-\(index)") // Performance optimization: Stable ID
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 100)
        }
        .refreshable {
            // Refresh habits data when user pulls down
            await refreshHabits()
        }
        .scrollIndicators(.hidden) // Hide scroll indicators for cleaner look
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
    

    
    private func habitRow(_ habit: Habit) -> some View {
        return ScheduledHabitItem(
            habit: habit,
            selectedDate: selectedDate,
            onRowTap: {
                selectedHabit = habit
            },
            onProgressChange: { habit, date, progress in
                // Use the new progress setting method that properly saves to Core Data
                onSetProgress?(habit, date, progress)
            },
            onEdit: {
                selectedHabit = habit
            },
            onDelete: {
                onDeleteHabit?(habit)
            }
        )
    }
    
    private var habitsForSelectedDate: [Habit] {
        // Calculate filtered habits for the selected date
        let filteredHabits = habits.filter { habit in
            let selected = DateUtils.startOfDay(for: selectedDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            guard selected >= start && selected <= end else {
                return false
            }
            
            return shouldShowHabitOnDate(habit, date: selectedDate)
        }
        
        // Filter by completion status based on selected tab
        let finalFilteredHabits = filteredHabits.filter { habit in
            let progress = habit.getProgress(for: selectedDate)
            
            // Debug logging for progress values
            // print("🔍 HomeTabView: Habit '\(habit.name)' has progress \(progress) for \(DateUtils.dateKey(for: selectedDate))") // Removed as per edit hint
            
            switch selectedStatsTab {
            case 0: // Total tab - show all habits
                return true
            case 1: // Undone tab - show only habits with 0 progress
                let shouldShow = progress == 0
                // print("🔍 HomeTabView: Undone tab - Habit '\(habit.name)' should show: \(shouldShow)") // Removed as per edit hint
                return shouldShow
            case 2: // Done tab - show only habits with progress > 0
                let shouldShow = progress > 0
                // print("🔍 HomeTabView: Done tab - Habit '\(habit.name)' should show: \(shouldShow)") // Removed as per edit hint
                return shouldShow
            default:
                return true
            }
        }
        
        // print("🔍 HomeTabView: Final filtered habits count: \(finalFilteredHabits.count) for tab \(selectedStatsTab)") // Removed as per edit hint
        return finalFilteredHabits
    }
    
    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
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
            let shouldShow = weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
            return shouldShow
        case "Weekends":
            let shouldShow = weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
            return shouldShow
        case "Monday":
            let shouldShow = weekday == 2
            return shouldShow
        case "Tuesday":
            let shouldShow = weekday == 3
            return shouldShow
        case "Wednesday":
            let shouldShow = weekday == 4
            return shouldShow
        case "Thursday":
            let shouldShow = weekday == 5
            return shouldShow
        case "Friday":
            let shouldShow = weekday == 6
            return shouldShow
        case "Saturday":
            let shouldShow = weekday == 7
            return shouldShow
        case "Sunday":
            let shouldShow = weekday == 1
            return shouldShow
        default:
            // print("🔍 Checking schedule: \(habit.schedule)") // Removed as per edit hint
            // Handle custom schedules like "Every Monday, Wednesday, Friday"
            if habit.schedule.lowercased().contains("every") && habit.schedule.lowercased().contains("day") {
                // First check if it's an "Every X days" schedule
                if let dayCount = extractDayCount(from: habit.schedule) {
                    // Handle "Every X days" schedules
                    let startDate = DateUtils.startOfDay(for: habit.startDate)
                    let targetDate = DateUtils.startOfDay(for: date)
                    let daysSinceStart = DateUtils.daysBetween(startDate, targetDate)
                    
                    // Check if the target date falls on the schedule
                    let shouldShow = daysSinceStart >= 0 && daysSinceStart % dayCount == 0
                    return shouldShow
                } else {
                    // Extract weekdays from schedule (like "Every Monday, Wednesday, Friday")
                    let weekdays = extractWeekdays(from: habit.schedule)
                    // print("🔍 Schedule: \(habit.schedule), Weekdays: \(weekdays), Current weekday: \(weekday)") // Removed as per edit hint
                    return weekdays.contains(weekday)
                }
            } else if habit.schedule.contains("days a week") {
                // Handle frequency schedules like "2 days a week"
                return shouldShowHabitWithFrequency(habit: habit, date: date)
            } else if habit.schedule.contains("days a month") {
                // Handle monthly frequency schedules like "3 days a month"
                return shouldShowHabitWithMonthlyFrequency(habit: habit, date: date)
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
            // Check if schedule contains multiple weekdays separated by commas
            if habit.schedule.contains(",") {
                let weekdays = extractWeekdays(from: habit.schedule)
                // print("🔍 Comma-separated schedule: \(habit.schedule), Weekdays: \(weekdays), Current weekday: \(weekday)") // Removed as per edit hint
                return weekdays.contains(weekday)
            }
            // For any unrecognized schedule format, don't show the habit (safer default)
            // print("🔍 Schedule didn't match any patterns, NOT showing habit: \(habit.schedule)") // Removed as per edit hint
            return false
        }
    }
    
    private func extractDayCount(from schedule: String) -> Int? {
        let pattern = #"every (\d+) days?"#
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
        let lowercasedSchedule = schedule.lowercased()
        
        for (index, dayName) in Self.weekdayNames.enumerated() {
            let dayNameLower = dayName.lowercased()
            if lowercasedSchedule.contains(dayNameLower) {
                // Calendar weekday is 1-based, where 1 = Sunday
                let weekdayNumber = index + 1
                weekdays.insert(weekdayNumber)
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
    
    private func extractDaysPerWeek(from schedule: String) -> Int? {
        let pattern = #"(\d+) days a week"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    // MARK: - Frequency-based Habit Logic
    
    private func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
        guard let daysPerWeek = extractDaysPerWeek(from: habit.schedule) else {
            return false
        }
        
        let today = Date()
        let targetDate = DateUtils.startOfDay(for: date)
        let todayStart = DateUtils.startOfDay(for: today)
        
        // If the target date is in the past, don't show the habit
        if targetDate < todayStart {
            return false
        }
        
        // For frequency-based habits, show the habit on the first N days starting from today
        let daysFromToday = DateUtils.daysBetween(todayStart, targetDate)
        return daysFromToday >= 0 && daysFromToday < daysPerWeek
    }
    
    private func calculateHabitInstances(habit: Habit, daysPerWeek: Int, targetDate: Date) -> [HabitInstance] {
        let calendar = Calendar.current
        
        // For frequency-based habits, we need to create instances that include today
        // Start from today and work backwards to find the appropriate instances
        let today = Date()
        let todayStart = DateUtils.startOfDay(for: today)
        
        // Initialize habit instances for this week
        var habitInstances: [HabitInstance] = []
        
        // Create initial habit instances starting from today
        // print("🔍 Creating \(daysPerWeek) habit instances starting from today: \(todayStart)") // Removed as per edit hint
        for i in 0..<daysPerWeek {
            if let instanceDate = calendar.date(byAdding: .day, value: i, to: todayStart) {
                let instance = HabitInstance(
                    id: "\(habit.id)_\(i)",
                    originalDate: instanceDate,
                    currentDate: instanceDate,
                    isCompleted: false
                )
                habitInstances.append(instance)
                // print("🔍 Created instance \(i): \(instanceDate)") // Removed as per edit hint
            }
        }
        
        // Apply sliding logic based on completion history
        for i in 0..<habitInstances.count {
            var instance = habitInstances[i]
            
            // Check if this instance was completed on its original date
                            let originalDateKey = Habit.dateKey(for: instance.originalDate)
            let originalProgress = habit.completionHistory[originalDateKey] ?? 0
            
            if originalProgress > 0 {
                // Instance was completed on its original date
                instance.isCompleted = true
                habitInstances[i] = instance
                continue
            }
            
            // Instance was not completed, so it slides forward
            var currentDate = instance.originalDate
            var isCompleted = false
            
            // Slide the instance forward until it's completed or reaches the end of the week
            while currentDate <= DateUtils.endOfWeek(for: targetDate) {
                let dateKey = Habit.dateKey(for: currentDate)
                let progress = habit.completionHistory[dateKey] ?? 0
                
                if progress > 0 {
                    // Instance was completed on this date
                    isCompleted = true
                    instance.currentDate = currentDate
                    break
                }
                
                // Move to next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            // Update instance
            instance.currentDate = currentDate
            instance.isCompleted = isCompleted
            habitInstances[i] = instance
        }
        
        // Return instances that should appear on the target date
        return habitInstances.filter { instance in
            let instanceDate = DateUtils.startOfDay(for: instance.currentDate)
            let targetDateStart = DateUtils.startOfDay(for: targetDate)
            return instanceDate == targetDateStart && !instance.isCompleted
        }
    }
    
    // Helper struct to track habit instances
    private struct HabitInstance {
        let id: String
        let originalDate: Date
        var currentDate: Date
        var isCompleted: Bool
    }
    
    private func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
        // For now, implement a simple monthly frequency
        // This can be enhanced later with more sophisticated logic
        let calendar = Calendar.current
        let today = Date()
        let targetDate = DateUtils.startOfDay(for: date)
        let todayStart = DateUtils.startOfDay(for: today)
        
        // If the target date is in the past, don't show the habit
        if targetDate < todayStart {
            return false
        }
        
        // Extract days per month from schedule
        let pattern = #"(\d+) days a month"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: habit.schedule, options: [], range: NSRange(location: 0, length: habit.schedule.count)) else {
            return false
        }
        
        let range = match.range(at: 1)
        let daysPerMonthString = (habit.schedule as NSString).substring(with: range)
        guard let daysPerMonth = Int(daysPerMonthString) else {
            return false
        }
        
        // For monthly frequency, show the habit on the first N days of each month
        let dayOfMonth = calendar.component(.day, from: targetDate)
        return dayOfMonth <= daysPerMonth
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
                            .foregroundColor(dayLabelColor(for: date))
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(dateFont(for: date))
                            .foregroundColor(dayNumberColor(for: date))
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
    
    private func dayLabelColor(for date: Date) -> Color {
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
        
        // For all other dates (past and future), use text04 for day labels
        return .text04
    }
    
    private func dayNumberColor(for date: Date) -> Color {
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
        
        // If this is a past date, use text06
        if normalizedDate < normalizedToday {
            return .text06
        }
        
        // For future dates, use text04
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
        return AppDateFormatter.shared.formatDisplayDate(selectedDate)
    }
    
    private func daysOfWeek(for weekOffset: Int) -> [Date] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
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
    
    // Refresh habits data when user pulls down
    private func refreshHabits() async {
        // Add a small delay to make the refresh feel more responsive
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Refresh habits data from Core Data
        await MainActor.run {
            // Force reload habits from Core Data
            CoreDataAdapter.shared.loadHabits(force: true)
            
            // Provide haptic feedback for successful refresh
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Additional success feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
}
