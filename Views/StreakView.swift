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
    let userHabits: [Habit]
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    
    // Performance optimization: Pagination for large datasets
    @State private var currentYearlyPage = 0
    private let yearlyItemsPerPage = 50
    
    // Date selection state
    @State private var selectedWeekStartDate: Date = {
        let calendar = Calendar.current
        let today = Date()
        // Get the start of the current week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return weekStart
    }()
    @State private var showingCalendar = false
    
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
                                            dragOffset = max(translation, -300) // Increased upward drag limit
                                        } else { // Dragging down
                                            dragOffset = min(translation, 0) // Limit downward drag
                                        }
                                    }
                                    .onEnded { value in
                                        let translation = value.translation.height
                                        let velocity = value.velocity.height
                                        
                                        if translation < -150 || velocity < -300 { // Increased expand threshold
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isExpanded = true
                                                dragOffset = -300
                                            }
                                        } else if translation > 25 || velocity > 300 { // Collapse threshold
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isExpanded = false
                                                dragOffset = 0
                                            }
                                        } else { // Return to current state
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                dragOffset = isExpanded ? -300 : 0
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
        .sheet(isPresented: $showingCalendar) {
            WeekPickerSheet(selectedWeekStartDate: $selectedWeekStartDate)
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
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
        
        // Calculate current streak using improved streak calculation
        let totalCurrentStreak = userHabits.reduce(0) { $0 + $1.calculateTrueStreak() }
        currentStreak = userHabits.isEmpty ? 0 : totalCurrentStreak / userHabits.count
        
        // Calculate best streak (highest streak among all habits)
        bestStreak = userHabits.map { $0.calculateTrueStreak() }.max() ?? 0
        
        // Calculate average streak
        let totalStreak = userHabits.reduce(0) { $0 + $1.calculateTrueStreak() }
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
                            colors: [.warning, Color("yellow400")],
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
                iconColor: Color("yellow400"),
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
        Button(action: {
            showingCalendar = true
        }) {
            HStack {
                Text(weekRangeText)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Image(systemName: "chevron.down")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var weekRangeText: String {
        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: selectedWeekStartDate) ?? selectedWeekStartDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        
        let startText = formatter.string(from: selectedWeekStartDate)
        let endText = formatter.string(from: weekEndDate)
        
        return "\(startText) - \(endText)"
    }
    
    // MARK: - Weekly Calendar Grid
    private var weeklyCalendarGrid: some View {
        Group {
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
                // Proper table structure using bordered container
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        // Empty space for habit names
                        Rectangle()
                            .fill(.clear)
                            .frame(maxWidth: .infinity)
                            .padding(.leading, 8)
                            .border(.outline, width: 1)
                        
                                            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.appBodyMedium)
                            .foregroundColor(.text04)
                            .frame(width: 32)
                            .frame(height: 32)
                            .border(.outline, width: 1)
                    }
                    }
                    
                    // Habit rows
                    ForEach(Array(userHabits.enumerated()), id: \.element.id) { index, habit in
                        HStack(spacing: 0) {
                            // Habit name cell
                            HStack(spacing: 8) {
                                // Small habit icon for streak view
                                ZStack {
                                    if habit.icon.hasPrefix("Icon-") {
                                        // Asset icon
                                        Image(habit.icon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(habit.color)
                                    } else if habit.icon == "None" {
                                        // No icon selected - show colored rounded rectangle
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(habit.color)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        // Emoji or system icon
                                        Text(habit.icon)
                                            .font(.system(size: 16))
                                    }
                                }
                                
                                Text(habit.name)
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.trailing, 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 32)
                            .padding(.leading, 8)
                            .border(.outline, width: 1)
                            
                            // Heatmap cells
                            ForEach(0..<7, id: \.self) { dayIndex in
                                                            heatmapCell(intensity: getWeeklyHeatmapIntensity(for: habit, dayIndex: dayIndex))
                                .frame(height: 32)
                                .border(.outline, width: 1)
                            }
                        }
                    }
                    
                    // Total row
                    HStack(spacing: 0) {
                                            Text("Total")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text01)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                        .padding(.leading, 8)
                        .border(.outline, width: 1)
                        
                        ForEach(0..<7, id: \.self) { dayIndex in
                                                    heatmapCell(intensity: getWeeklyTotalIntensity(dayIndex: dayIndex))
                            .frame(height: 32)
                            .border(.outline, width: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
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
                    .frame(maxWidth: .infinity)
                
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
                    HStack(spacing: 4) {
                        // Week label
                        Text("Week \(weekIndex + 1)")
                            .font(.appBodySmall)
                            .foregroundColor(.text04)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Week heatmap cells
                        ForEach(0..<7, id: \.self) { dayIndex in
                            heatmapCell(intensity: getMonthlyHeatmapIntensity(weekIndex: weekIndex, dayIndex: dayIndex))
                        }
                    }
                }
                
                // Total row
                HStack(spacing: 4) {
                    Text("Total")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.text01)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
        // Transparent container with 4pt internal padding
        Rectangle()
            .fill(.clear) // Transparent background
            .frame(width: 32, height: 32) // 24 + 4 + 4 = 32 to accommodate padding
            .overlay(
                Rectangle()
                    .fill(heatmapColor(for: intensity))
                    .frame(width: 24, height: 24)
                    .cornerRadius(6)
            )
    }
    
    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            return .surfaceContainer
        case 1:
            return Color("green500").opacity(0.3)
        case 2:
            return Color("green500").opacity(0.6)
        case 3:
            return Color("green500")
        default:
            return .surfaceContainer
        }
    }
    
    // MARK: - Heatmap Data Generation from User Habits
    private func getWeeklyHeatmapIntensity(for habit: Habit, dayIndex: Int) -> Int {
        let calendar = Calendar.current
        let weekStartDate = calendar.startOfDay(for: selectedWeekStartDate)
        
        // Calculate the date for this day index (0 = Monday, 6 = Sunday)
        let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: weekStartDate) ?? weekStartDate
        
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
            let _ = calendar.dateInterval(of: .year, for: today)?.start ?? today
            
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
        // Use endOfDay to be inclusive of the end date
        if let endDate = habit.endDate, date > calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate {
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
            // If we can't extract day count, don't show the habit
            return false
            
        case let schedule where schedule.hasPrefix("Every ") && !schedule.contains("days"):
            // Handle specific weekdays like "Every Monday, Wednesday" (but not "Every X days")
            let weekdays = extractWeekdays(from: schedule)
            return weekdays.contains(weekday)
            
        case let schedule where schedule.contains("times a week"):
            // Handle "X times a week" format (e.g., "1 times a week", "2 times a week")
            if let timesPerWeek = extractTimesPerWeek(from: schedule) {
                let startDate = calendar.startOfDay(for: habit.startDate)
                let selectedDate = calendar.startOfDay(for: date)
                let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startDate, to: selectedDate).weekOfYear ?? 0
                return weeksSinceStart >= 0 && weeksSinceStart % timesPerWeek == 0
            }
            // If we can't extract times per week, don't show the habit
            return false
            
        default:
            // For any other schedule, show the habit
            return true
        }
    }
    
    private func extractDayCount(from schedule: String) -> Int? {
        // Extract number from "Every X days" format
        let pattern = #"Every (\d+) days?"#
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
    
    private func extractTimesPerWeek(from schedule: String) -> Int? {
        // Extract number from "X times a week" format
        let pattern = #"(\d+)\s+times\s+a\s+week"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: schedule, options: [], range: NSRange(location: 0, length: schedule.count)) else {
            return nil
        }
        
        let range = match.range(at: 1)
        let numberString = (schedule as NSString).substring(with: range)
        return Int(numberString)
    }
    
    // MARK: - Summary Statistics
    private var summaryStatistics: some View {
        HStack(spacing: 12) {
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
    StreakView(userHabits: [])
}

// MARK: - Week Picker Sheet
struct WeekPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWeekStartDate: Date
    @State private var tempSelectedWeekStartDate: Date
    @State private var selectedDateRange: ClosedRange<Date>?
    
    init(selectedWeekStartDate: Binding<Date>) {
        self._selectedWeekStartDate = selectedWeekStartDate
        self._tempSelectedWeekStartDate = State(initialValue: selectedWeekStartDate.wrappedValue)
        
        // Initialize selected range based on the current week
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStartDate.wrappedValue)?.start ?? selectedWeekStartDate.wrappedValue
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let range = weekStart...weekEnd
        self._selectedDateRange = State(initialValue: range)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Custom Calendar for week selection
                CustomWeekSelectionCalendar(
                    selectedWeekStartDate: $tempSelectedWeekStartDate,
                    selectedDateRange: $selectedDateRange
                )
                .frame(height: 400)
                
                // Selected week display
                if let range = selectedDateRange {
                    VStack(spacing: 8) {
                        Text("Selected Week")
                            .font(.appBodyMedium)
                            .foregroundColor(.text04)
                        
                        Text(weekRangeText(from: range))
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                    }
                    .padding()
                    .background(.surfaceContainer)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedWeekStartDate = tempSelectedWeekStartDate
                        dismiss()
                    }
                }
            }
        }
    }
    

    
    private func weekRangeText(from range: ClosedRange<Date>) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        
        let startText = formatter.string(from: range.lowerBound)
        let endText = formatter.string(from: range.upperBound)
        
        return "\(startText) - \(endText)"
    }
}

// MARK: - Custom Week Selection Calendar
struct CustomWeekSelectionCalendar: View {
    @Binding var selectedWeekStartDate: Date
    @Binding var selectedDateRange: ClosedRange<Date>?
    @State private var currentMonth: Date = Date()
    
    var body: some View {
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
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 0), count: 7), spacing: 0) {
                // Day headers
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.appLabelMedium)
                        .foregroundColor(.text04)
                        .frame(height: 32)
                }
                
                // Calendar days
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: isDateInSelectedWeek(date),
                            isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            weekPosition: getWeekPosition(for: date)
                        )
                        .onTapGesture {
                            selectWeek(for: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            initializeCurrentWeek()
        }
    }
    
    // MARK: - Helper Functions
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        
        // Find Monday of the first week
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysFromMonday = (firstWeekday == 1) ? 6 : firstWeekday - 2
        let firstDisplayDate = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfMonth) ?? startOfMonth
        
        var days: [Date?] = []
        var currentDate = firstDisplayDate
        
        // Generate 42 days (6 weeks)
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isDateInSelectedWeek(_ date: Date) -> Bool {
        guard let range = selectedDateRange else { return false }
        return range.contains(date)
    }
    
    private func getWeekPosition(for date: Date) -> WeekPosition {
        guard let range = selectedDateRange, range.contains(date) else { return .none }
        
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: range.lowerBound) {
            return .start
        } else if calendar.isDate(date, inSameDayAs: range.upperBound) {
            return .end
        } else {
            return .middle
        }
    }
    
    private func selectWeek(for date: Date) {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedWeekStartDate = weekStart
            selectedDateRange = weekStart...weekEnd
        }
    }
    
    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
            }
        }
    }
    
    private func initializeCurrentWeek() {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        selectedWeekStartDate = weekStart
        selectedDateRange = weekStart...weekEnd
        currentMonth = today
    }
}

// MARK: - Week Position Enum
enum WeekPosition {
    case none, start, middle, end
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let weekPosition: WeekPosition
    
    var body: some View {
        ZStack {
            // Background extension for start date
            if weekPosition == .start {
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(.primaryContainer)
                        .frame(width: 16, height: 32)
                }
            }
            
            // Background extension for end date
            if weekPosition == .end {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.primaryContainer)
                        .frame(width: 16, height: 32)
                    Spacer()
                }
            }
            
            // Main day view
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.appBodyMedium)
                .foregroundColor(textColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor)
                .clipShape(backgroundShape)
                .overlay(
                    backgroundShape
                        .stroke(isToday && !isSelected ? Color.primary : Color.clear, lineWidth: 1)
                )
        }
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var textColor: Color {
        switch weekPosition {
        case .start, .end:
            return .onPrimary
        case .middle:
            return .onPrimaryContainer
        case .none:
            if isToday {
                return .primary
            } else {
                return .text01
            }
        }
    }
    
    private var backgroundColor: Color {
        switch weekPosition {
        case .start, .end:
            return Color.primary
        case .middle:
            return .primaryContainer
        case .none:
            if isToday && !isSelected {
                return Color.primary.opacity(0.1)
            } else {
                return .clear
            }
        }
    }
    
    private var backgroundShape: some Shape {
        switch weekPosition {
        case .start, .end, .none:
            return AnyShape(Circle())
        case .middle:
            return AnyShape(Rectangle())
        }
    }
}

