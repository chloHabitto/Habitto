import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var averageStreak = 0
    @State private var completionRate = 0
    @State private var consistencyRate = 0
    
    // Performance optimization: Cache expensive data
    @State private var yearlyHeatmapData: [[Int]] = []
    @State private var isDataLoaded = false
    @State private var userHabits: [Habit] = []
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    
    // Performance optimization: Pagination for large datasets
    @State private var currentYearlyPage = 0
    private let yearlyItemsPerPage = 50
    
    private let progressTabs = ["Weekly", "Monthly", "Yearly", "Dummy"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            headerSection
                .background(Color.primary)
                .zIndex(1)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Main Streak Display
                    mainStreakDisplay
                    
                    // Streak Summary Cards
                    streakSummaryCards
                    
                    // White sheet that expands to bottom
                    WhiteSheetContainer(
                        title: "Habit Streak",
                        rightButton: {
                            AnyView(
                                Button(action: {
                                    // More button action
                                }) {
                                    Image("Icon-moreDots")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                                .buttonStyle(PlainButtonStyle())
                            )
                        }
                    ) {
                        VStack(spacing: 0) {
                            // Progress Section
                            progressSection
                            
                            // Summary Statistics
                            summaryStatistics
                            
                            // Spacer to fill remaining space
                            Spacer(minLength: 0)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let translation = value.translation.height
                                if translation < 0 { // Dragging up
                                    dragOffset = max(translation, -150) // Upward drag limit
                                } else { // Dragging down
                                    dragOffset = min(translation, 0) // Limit downward drag
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                let velocity = value.velocity.height
                                
                                if translation < -75 || velocity < -300 { // Expand threshold
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isExpanded = true
                                        dragOffset = -150
                                    }
                                } else if translation > 25 || velocity > 300 { // Collapse threshold
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isExpanded = false
                                        dragOffset = 0
                                    }
                                } else { // Return to current state
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        dragOffset = isExpanded ? -150 : 0
                                    }
                                }
                            }
                    )
                }
            }
        }
        .background(
            VStack(spacing: 0) {
                Color.primary
                Color.white
            }
        )
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaInset(edge: .top) {
            Color.clear
                .frame(height: 0)
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
        // Load user habits first
        userHabits = Habit.loadHabits()
        
        // Calculate streak statistics from actual user data
        calculateStreakStatistics()
        
        // Load data on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let yearlyData = generateYearlyDataFromUserHabits()
            
            DispatchQueue.main.async {
                self.yearlyHeatmapData = yearlyData
                self.isDataLoaded = true
            }
        }
    }
    
    // MARK: - Streak Statistics Calculation
    private func calculateStreakStatistics() {
        guard !userHabits.isEmpty else {
            currentStreak = 0
            bestStreak = 0
            averageStreak = 0
            completionRate = 0
            consistencyRate = 0
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate current streak (average of all habits)
        let totalCurrentStreak = userHabits.reduce(0) { $0 + $1.streak }
        currentStreak = userHabits.isEmpty ? 0 : totalCurrentStreak / userHabits.count
        
        // Calculate best streak (highest streak among all habits)
        bestStreak = userHabits.map { $0.streak }.max() ?? 0
        
        // Calculate average streak
        let totalStreak = userHabits.reduce(0) { $0 + $1.streak }
        averageStreak = userHabits.isEmpty ? 0 : totalStreak / userHabits.count
        
        // Calculate completion rate (percentage of habits completed today)
        let completedHabitsToday = userHabits.filter { $0.isCompleted(for: today) }.count
        completionRate = userHabits.isEmpty ? 0 : (completedHabitsToday * 100) / userHabits.count
        
        // Calculate consistency rate (average completion rate over the last 7 days)
        let last7Days = (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
        
        let totalCompletions = last7Days.reduce(0) { total, date in
            total + userHabits.filter { $0.isCompleted(for: date) }.count
        }
        
        let totalPossible = userHabits.count * 7
        consistencyRate = totalPossible > 0 ? (totalCompletions * 100) / totalPossible : 0
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Main Streak Display
    private var mainStreakDisplay: some View {
        VStack(spacing: 16) {
            // Large circle with flame icon
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Flame icon (using custom Icon-fire)
                Image("Icon-fire")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.warning, ColorPrimitives.yellow400],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Streak count
            Text("\(currentStreak) days")
                .font(.appDisplaySmallEmphasised)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Streak Summary Cards
    private var streakSummaryCards: some View {
        HStack(spacing: 0) {
            // Best streak card
            streakCard(
                icon: "Icon-starBadge",
                iconColor: .warning,
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            // Divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1)
                .frame(height: 60)
            
            // Average streak card
            streakCard(
                icon: "Icon-medalBadge",
                iconColor: ColorPrimitives.yellow400,
                value: "\(averageStreak) days",
                label: "Average streak"
            )
        }
        .background(.surfaceContainer)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private func streakCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if icon.hasPrefix("Icon-") {
                    // Custom image
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor)
                } else {
                    // System icon
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                }
                
                Text(value)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
            }
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress tabs
            progressTabsView
            
            // Date range selector
            dateRangeSelector
                .padding(.horizontal, 16)
            
            // Content based on selected tab
            Group {
                if selectedProgressTab == 0 {
                    // Weekly view
                    weeklyCalendarGrid
                } else if selectedProgressTab == 1 {
                    // Monthly view
                    monthlyCalendarGrid
                } else {
                    // Yearly view
                    yearlyCalendarGrid
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var progressTabsView: some View {
        HStack(spacing: 0) {
            ForEach(0..<progressTabs.count, id: \.self) { index in
                VStack(spacing: 0) {
                    if index == 3 { // Dummy tab
                        // Non-clickable dummy tab with zero opacity text
                        Text(progressTabs[index])
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.text04)
                            .opacity(0) // Zero opacity
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        // Regular clickable tabs
                        Button(action: {
                            selectedProgressTab = index
                        }) {
                            Text(progressTabs[index])
                                .font(.appTitleSmallEmphasised)
                                .foregroundColor(selectedProgressTab == index ? .text03 : .text04)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Bottom stroke for each tab
                    Rectangle()
                        .fill(selectedProgressTab == index ? .text03 : .divider)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: selectedProgressTab)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .horizontal)
    }
    
    private var dateRangeSelector: some View {
        HStack {
            Text("June 09 - June 15")
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            
            Image(systemName: "chevron.down")
                .font(.appBodySmall)
                .foregroundColor(.text04)
            
            Spacer()
        }
    }
    
    // MARK: - Weekly Calendar Grid
    private var weeklyCalendarGrid: some View {
        VStack(spacing: 12) {
            // Days of week header
            HStack(spacing: 0) {
                // Empty space for habit names
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if userHabits.isEmpty {
                // Empty state for no habits
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.circle")
                        .font(.appDisplaySmall)
                        .foregroundColor(.secondary)
                    Text("No habits yet")
                        .font(.appButtonText2)
                        .foregroundColor(.secondary)
                    Text("Create habits to see your progress")
                        .font(.appBodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                // Habit rows with heatmap
                ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                    HStack(spacing: 0) {
                        // Habit name
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(habit.color)
                                .frame(width: 8, height: 8)
                                .cornerRadius(2)
                            
                            Text(habit.name)
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                        }
                        .frame(width: 80, alignment: .leading)
                        
                        // Heatmap cells
                        ForEach(0..<7, id: \.self) { dayIndex in
                            heatmapCell(intensity: getWeeklyHeatmapIntensity(for: habit, dayIndex: dayIndex))
                        }
                    }
                }
                
                // Total row
                HStack(spacing: 0) {
                    Text("Total")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text01)
                        .frame(width: 80, alignment: .leading)
                    
                    ForEach(0..<7, id: \.self) { dayIndex in
                        heatmapCell(intensity: getWeeklyTotalIntensity(dayIndex: dayIndex))
                    }
                }
            }
        }
    }
    
    // MARK: - Monthly Calendar Grid
    private var monthlyCalendarGrid: some View {
        VStack(spacing: 12) {
            // Days of week header
            HStack(spacing: 0) {
                // Empty space for habit names
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if userHabits.isEmpty {
                // Empty state for no habits
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.circle")
                        .font(.appDisplaySmall)
                        .foregroundColor(.secondary)
                    Text("No habits yet")
                        .font(.appButtonText2)
                        .foregroundColor(.secondary)
                    Text("Create habits to see your progress")
                        .font(.appBodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                // Month weeks (4-5 weeks)
                ForEach(0..<5, id: \.self) { weekIndex in
                    HStack(spacing: 0) {
                        // Week label
                        Text("Week \(weekIndex + 1)")
                            .font(.appBodySmall)
                            .foregroundColor(.text04)
                            .frame(width: 80, alignment: .leading)
                        
                        // Week heatmap cells
                        ForEach(0..<7, id: \.self) { dayIndex in
                            heatmapCell(intensity: getMonthlyHeatmapIntensity(weekIndex: weekIndex, dayIndex: dayIndex))
                        }
                    }
                }
                
                // Total row
                HStack(spacing: 0) {
                    Text("Total")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text01)
                        .frame(width: 80, alignment: .leading)
                    
                    ForEach(0..<7, id: \.self) { dayIndex in
                        heatmapCell(intensity: getMonthlyTotalIntensity(dayIndex: dayIndex))
                    }
                }
            }
        }
    }
    
    // MARK: - Yearly Calendar Grid (Optimized)
    private var yearlyCalendarGrid: some View {
        VStack(spacing: 12) {
            if userHabits.isEmpty {
                // Empty state for no habits
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.circle")
                        .font(.appDisplaySmall)
                        .foregroundColor(.secondary)
                    Text("No habits yet")
                        .font(.appButtonText2)
                        .foregroundColor(.secondary)
                    Text("Create habits to see your yearly progress")
                        .font(.appBodyMedium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else if isDataLoaded {
                // Habit rows with yearly heatmap (365 days)
                ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                    VStack(spacing: 6) {
                        // Habit name
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(habit.color)
                                .frame(width: 8, height: 8)
                                .cornerRadius(2)
                            
                            Text(habit.name)
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Yearly heatmap (365 rectangles) - Optimized rendering
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 30), spacing: 0) {
                            ForEach(0..<365, id: \.self) { dayIndex in
                                heatmapCell(intensity: yearlyHeatmapData[index][dayIndex])
                                    .frame(height: 4)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .padding(.vertical, 6)
                }
            } else {
                // Loading placeholder
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading heatmap data...")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func heatmapCell(intensity: Int) -> some View {
        Rectangle()
            .fill(heatmapColor(for: intensity))
            .cornerRadius(2)
    }
    
    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            return .surfaceContainer
        case 1:
            return ColorPrimitives.green500.opacity(0.3)
        case 2:
            return ColorPrimitives.green500.opacity(0.6)
        case 3:
            return ColorPrimitives.green500
        default:
            return .surfaceContainer
        }
    }
    
    // MARK: - Heatmap Data Generation from User Habits
    private func getWeeklyHeatmapIntensity(for habit: Habit, dayIndex: Int) -> Int {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this day index (0 = Monday, 6 = Sunday)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // Convert to Monday-based (0 = Monday)
        let daysToSubtract = daysFromMonday - dayIndex
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Check if habit was completed on this date
        if habit.isCompleted(for: targetDate) {
            return 3 // High intensity for completed days
        }
        
        // Check if habit should have been scheduled on this date
        if shouldShowHabitOnDate(habit, date: targetDate) {
            return 1 // Low intensity for scheduled but not completed days
        }
        
        return 0 // No intensity for non-scheduled days
    }
    
    private func getWeeklyTotalIntensity(dayIndex: Int) -> Int {
        // Calculate total intensity for the day across all habits
        let totalIntensity = userHabits.reduce(0) { total, habit in
            total + getWeeklyHeatmapIntensity(for: habit, dayIndex: dayIndex)
        }
        return min(totalIntensity, 3)
    }
    
    private func getMonthlyHeatmapIntensity(weekIndex: Int, dayIndex: Int) -> Int {
        let calendar = Calendar.current
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate the date for this week and day
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weeksToSubtract = weekIndex
        let daysToSubtract = daysFromMonday - dayIndex + (weeksToSubtract * 7)
        let targetDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        
        // Count completed habits for this date
        let completedCount = userHabits.filter { $0.isCompleted(for: targetDate) }.count
        return min(completedCount, 3)
    }
    
    private func getMonthlyTotalIntensity(dayIndex: Int) -> Int {
        // Calculate monthly total intensity
        let totalIntensity = userHabits.reduce(0) { total, habit in
            total + getMonthlyHeatmapIntensity(weekIndex: 0, dayIndex: dayIndex)
        }
        return min(totalIntensity, 3)
    }
    
    private func generateYearlyDataFromUserHabits() -> [[Int]] {
        var yearlyData: [[Int]] = []
        
        // Performance optimization: Process habits in batches
        let startIndex = currentYearlyPage * yearlyItemsPerPage
        let endIndex = min(startIndex + yearlyItemsPerPage, userHabits.count)
        let habitsToProcess = Array(userHabits[startIndex..<endIndex])
        
        for habit in habitsToProcess {
            var habitYearlyData: [Int] = []
            
            // Generate 365 days of data based on actual completion history
            let calendar = Calendar.current
            let today = Calendar.current.startOfDay(for: Date())
            let startOfYear = calendar.dateInterval(of: .year, for: today)?.start ?? today
            
            for day in 0..<365 {
                let targetDate = calendar.date(byAdding: .day, value: day - 364, to: today) ?? today
                let intensity = generateYearlyIntensity(for: habit, date: targetDate)
                habitYearlyData.append(intensity)
            }
            
            yearlyData.append(habitYearlyData)
        }
        
        return yearlyData
    }
    
    private var hasMoreYearlyData: Bool {
        return (currentYearlyPage + 1) * yearlyItemsPerPage < userHabits.count
    }
    
    private func generateYearlyIntensity(for habit: Habit, date: Date) -> Int {
        let calendar = Calendar.current
        
        // Check if habit was created before this date
        if date < calendar.startOfDay(for: habit.startDate) {
            return 0
        }
        
        // Check if habit was completed on this date
        if habit.isCompleted(for: date) {
            return 3 // High intensity for completed days
        }
        
        // Check if habit should have been scheduled on this date
        if shouldShowHabitOnDate(habit, date: date) {
            return 1 // Low intensity for scheduled but not completed days
        }
        
        return 0 // No intensity for non-scheduled days
    }
    
    // Helper function to check if habit should be shown on a specific date
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
            
        case let schedule where schedule.hasPrefix("Every "):
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
    
    // MARK: - Summary Statistics
    private var summaryStatistics: some View {
        HStack(spacing: 0) {
            // Completion card
            statisticCard(
                value: "\(completionRate)%",
                label: "Completion"
            )
            
            // Best streak card
            statisticCard(
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            // Consistency card
            statisticCard(
                value: "\(consistencyRate)%",
                label: "Consistency"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func statisticCard(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.surfaceContainer)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StreakView()
}