import SwiftUI
import CoreData

struct ProgressTabView: View {
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    @State private var selectedHabit: Habit?
    @State private var showingHabitSelector = false
    @State private var selectedProgressTab: ProgressTab = .daily
    let habits: [Habit]
    
    // Use the calendar helper
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    
    // MARK: - Progress Tab Enum
    enum ProgressTab: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    

    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Calendar Helper Functions
    // Moved to ProgressCalendarHelper.swift
    
    // MARK: - Today's Progress Summary (Simplified Card)
    private var todaysProgressSummary: some View {
        Group {
            if !habits.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Progress")
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.white)
                            
                            Text("\(getTodaysCompletedHabitsCount()) of \(getTodaysTotalHabitsCount()) habits completed today")
                                .font(.appBodyMedium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Circular progress ring on the right
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 6)
                                .frame(width: 48, height: 48)
                            
                            Circle()
                                .trim(from: 0, to: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.0), value: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits))
                            
                            Text("\(Int(ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits) * 100))%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Overall Progress Section
    private var overallProgressSection: some View {
        VStack(spacing: 0) {
            // Monthly Calendar
            VStack(spacing: 8) {
                // Calendar header with month/year and Today button
                HStack {
                    Text(calendarHelper.monthYearString())
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    if !calendarHelper.isCurrentMonth() || !calendarHelper.isTodayInCurrentMonth() {
                        Button(action: calendarHelper.goToToday) {
                            HStack(spacing: 4) {
                                Image(.iconReplay)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.primaryFocus)
                                Text("This month")
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
                .padding(.bottom, 12)
                
                // Days of week header
                CalendarGridComponents.WeekdayHeader()
                
                // Calendar grid
                CalendarGridComponents.CalendarGrid(
                    firstDayOfMonth: calendarHelper.firstDayOfMonth(),
                    daysInMonth: calendarHelper.daysInMonth(),
                    currentDate: calendarHelper.currentDate,
                    selectedDate: Date(),
                    getDayProgress: { day in
                        ProgressCalculationHelper.getDayProgress(
                            day: day,
                            currentDate: calendarHelper.currentDate,
                            habits: habits,
                            selectedHabitType: .formation, // Default to formation type
                            selectedHabit: selectedHabit
                        )
                    },
                    onDayTap: { day in
                        // Add haptic feedback when selecting a date
                        let selectionFeedback = UISelectionFeedbackGenerator()
                        selectionFeedback.selectionChanged()
                        
                        // Create a date for the selected day in the current month
                        if let dateForDay = calendarHelper.dateForDay(day) {
                            // Here you can add logic to handle the selected date
                            // For now, we'll just print it to console
                            print("Selected date: \(dateForDay)")
                        }
                    }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            // Only trigger month change for horizontal swipes
                            if abs(value.translation.width) > abs(value.translation.height) {
                                if value.translation.width > threshold {
                                    // Swipe right - go to previous month
                                    calendarHelper.previousMonth()
                                } else if value.translation.width < -threshold {
                                    // Swipe left - go to next month
                                    calendarHelper.nextMonth()
                                }
                            }
                        }
                )
            }
            .padding(20)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.outline3, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Spacing between monthly calendar and progress card
            Spacer()
                .frame(height: 12)
            
            // Monthly Completion Rate Section
            MonthlyCompletionRateSection(
                monthlyCompletionRate: ProgressCalculationHelper.monthlyCompletionRate(
                    habits: habits,
                    currentDate: calendarHelper.currentDate,
                    selectedHabitType: .formation, // Default to formation type
                    selectedHabit: selectedHabit
                ),
                monthlyCompletedHabits: ProgressCalculationHelper.monthlyCompletedHabits(
                    habits: habits,
                    currentDate: calendarHelper.currentDate,
                    selectedHabitType: .formation // Default to formation type
                ),
                monthlyTotalHabits: ProgressTrendHelper.monthlyTotalHabits(
                    habits: habits,
                    selectedHabitType: .formation // Default to formation type
                ),
                topPerformingHabit: ProgressTrendHelper.topPerformingHabit(
                    habits: habits,
                    selectedHabitType: .formation, // Default to formation type
                    currentDate: calendarHelper.currentDate
                ),
                needsAttentionHabit: ProgressTrendHelper.needsAttentionHabit(
                    habits: habits,
                    selectedHabitType: .formation, // Default to formation type
                    currentDate: calendarHelper.currentDate
                ),
                progressTrendColor: ProgressTrendHelper.progressTrendColor(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation, // Default to formation type
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation // Default to formation type
                    )
                )),
                progressTrendIcon: ProgressTrendHelper.progressTrendIcon(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation, // Default to formation type
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation // Default to formation type
                    )
                )),
                progressTrendText: ProgressTrendHelper.progressTrendIcon(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation, // Default to formation type
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation // Default to formation type
                    )
                )),
                progressTrendDescription: ProgressTrendHelper.progressTrendDescription(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation, // Default to formation type
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: .formation // Default to formation type
                    )
                )),
                monthlyHabitCompletionRate: { habit in
                    ProgressCalculationHelper.monthlyHabitCompletionRate(
                        for: habit,
                        currentDate: calendarHelper.currentDate
                    )
                }
            )
        }
        .padding(.top, 20)
    }
    
    // MARK: - Enhanced Difficulty Insights Section
    private var difficultyInsightsSection: some View {
        VStack(spacing: 12) {
            // Enhanced section header
            HStack {
                Text("Challenge Corner")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Enhanced difficulty card with better visual design
            if let mostDifficultHabit = getMostDifficultHabit() {
                enhancedDifficultyCard(habit: mostDifficultHabit)
            }
        }
    }
    
    // MARK: - Enhanced Difficulty Card
    private func enhancedDifficultyCard(habit: Habit) -> some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Enhanced icon with better gradient and animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.25), Color.orange.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                // Enhanced content with better typography and spacing
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Biggest Challenge")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                    
                    Text(habit.name)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                        .lineLimit(2)
                    
                    Text(getMotivationalMessage(for: habit))
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom motivational section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("Tip: Break it into smaller steps!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Motivational Message Helper
    private func getMotivationalMessage(for habit: Habit) -> String {
        let messages = [
            "Every challenge makes you stronger! 💪",
            "You've got this! Keep going! 🚀",
            "Small progress is still progress! ✨",
            "This challenge will make you unstoppable! 🔥",
            "You're building resilience! 🌟"
        ]
        return messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Simplified Difficulty Helper
    private func getMostDifficultHabit() -> Habit? {
        // For now, return the first habit as a placeholder
        // This can be enhanced later with actual difficulty analysis
        return habits.first
    }
    
    // MARK: - Helper Methods for Today's Progress
    private func getTodaysCompletedHabitsCount() -> Int {
        let today = Date()
        return habits.filter { habit in
            let progress = habit.getProgress(for: today)
            let goalAmount = ProgressCalculationHelper.parseGoalAmount(from: habit.goal)
            return progress >= goalAmount
        }.count
    }
    
    private func getTodaysTotalHabitsCount() -> Int {
        let today = Date()
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: today)
        }.count
    }
    
    // MARK: - Helper Methods for Enhanced Insights
    private func getAllCompletionRecords() -> [CompletionRecordEntity] {
        var allRecords: [CompletionRecordEntity] = []
        for habit in habits {
            let records = getCompletionRecords(for: habit)
            allRecords.append(contentsOf: records)
        }
        return allRecords
    }
    
    private func getAllDifficultyLogs() -> [DifficultyLogEntity] {
        // Use CoreDataAdapter to fetch all difficulty logs
        // Return empty array if coreDataAdapter is not available (e.g., in previews)
        return coreDataAdapter.fetchAllDifficultyLogs()
    }

    
    var body: some View {
        WhiteSheetContainer(
            // title: "Progress"
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Progress Title and Tabs
                    progressTitleAndTabs
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Content based on selected tab
                    switch selectedProgressTab {
                    case .daily:
                        dailyProgressContent
                    case .weekly:
                        weeklyProgressContent
                    case .monthly:
                        monthlyProgressContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.bottom, 40)
            }
            .scrollDisabled(false)
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "scrollView")
        }
        .onChange(of: selectedHabit) { _, newHabit in
            if let habit = newHabit {
                print("🔍 CALENDAR STATE DEBUG - Calendar displaying for selected habit: '\(habit.name)'")
                print("🔍 CALENDAR STATE DEBUG - Selected habit completion history: \(habit.completionHistory)")
                print("🔍 CALENDAR STATE DEBUG - Selected habit goal: '\(habit.goal)'")
                
                if habit.completionHistory.isEmpty {
                    print("🔍 CALENDAR STATE DEBUG - WARNING: Selected habit has no completion history!")
                    print("🔍 CALENDAR STATE DEBUG - This is why the calendar shows no progress rings.")
                    print("🔍 CALENDAR STATE DEBUG - The habit needs to have progress logged to show in the calendar.")
                }
            } else {
                print("🔍 CALENDAR STATE DEBUG - Calendar displaying for overall progress")
            }
        }
        .sheet(isPresented: $showingHabitSelector) {
            HabitSelectorView(selectedHabit: $selectedHabit)
        }
    }
    
    // MARK: - Progress Title and Tabs
    private var progressTitleAndTabs: some View {
        VStack(spacing: 20) {
            // Progress Title
            HStack {
                Text("Progress")
                    .font(.appTitleLargeEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            
            // Progress Tabs
            HStack(spacing: 0) {
                ForEach(ProgressTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedProgressTab = tab
                    }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.appBodyMedium)
                                .foregroundColor(selectedProgressTab == tab ? .primary : .text03)
                            
                            // Underline for selected tab
                            Rectangle()
                                .fill(selectedProgressTab == tab ? Color.primary : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Daily Progress Content
    private var dailyProgressContent: some View {
        VStack(spacing: 20) {
            // Today's Progress Card
            todaysProgressSummary
        }
    }
    
    // MARK: - Weekly Progress Content
    private var weeklyProgressContent: some View {
        VStack(spacing: 20) {
            // Empty for now
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.text04)
                
                Text("Weekly Progress")
                    .font(.appTitleMedium)
                    .foregroundColor(.text02)
                
                Text("Coming soon!")
                    .font(.appBodyMedium)
                    .foregroundColor(.text03)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }
    
    // MARK: - Monthly Progress Content
    private var monthlyProgressContent: some View {
        VStack(spacing: 20) {
            // Habit Selector Header
            habitSelectorHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            // Overall Progress Section with Monthly Calendar
            overallProgressSection
            
            // Enhanced Insights (only show when "All habits" selected)
            if selectedHabit == nil {
                VStack(spacing: 20) {
                    // Challenge Corner - Your biggest challenge
                    difficultyInsightsSection
                    
                    // Time Magic - Your time patterns
                    TimeInsightsSection(habit: nil, completionRecords: getAllCompletionRecords())
                    
                    // Pattern Magic - Your consistency patterns
                    PatternInsightsSection(habit: nil, completionRecords: getAllCompletionRecords(), difficultyLogs: getAllDifficultyLogs())
                }
                .padding(.top, 20)
            }
            
            // Habit-Specific Insights (only show when habit selected)
            if let selectedHabit = selectedHabit {
                // Show only essential insights for selected habit
                VStack(spacing: 20) {
                    // Just the time recommendation - most actionable insight
                    bestTimeRecommendationSimplified(for: selectedHabit)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Habit Selector Header
    private var habitSelectorHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Monthly Progress")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                
                Button(action: {
                    showingHabitSelector = true
                }) {
                    HStack(spacing: 8) {
                        Text(selectedHabit?.name ?? "All habits")
                            .font(.appBodyMedium)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.text04)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primaryContainer)
                    )
                }
            }
        }
    }
    
    // MARK: - Habit-Specific Insights Section
    private func habitSpecificInsightsSection(for habit: Habit) -> some View {
        VStack(spacing: 20) {
            // Habit Overview Card
            habitOverviewCard(for: habit)
            
            // Time Pattern Analysis
            timePatternAnalysisCard(for: habit)
            
            // Progress Metrics
            progressMetricsCard(for: habit)
        }
    }
    
    // MARK: - Habit Overview Card
    private func habitOverviewCard(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Habit Overview")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                
                // Habit icon or emoji
                Text(habit.icon)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Goal:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text(habit.goal)
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                }
                
                HStack {
                    Text("Current Streak:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(habit.streak) days")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Best Streak:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(habit.streak) days")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
    }
    
    // MARK: - Time Pattern Analysis Card
    private func timePatternAnalysisCard(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text("Time Pattern Analysis")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            // Get completion records for this habit
            let completionRecords = getCompletionRecords(for: habit)
            let timeAnalysis = TimeBlockHelper.analyzeTimePatterns(for: habit, completionRecords: completionRecords)
            
            if timeAnalysis.isEmpty {
                Text("Complete this habit a few times to see time pattern insights")
                    .font(.appBodySmall)
                    .foregroundColor(.text03)
                    .italic()
            } else {
                VStack(spacing: 12) {
                    ForEach(timeAnalysis.prefix(3), id: \.timeBlock) { analysis in
                        HStack {
                            Image(systemName: analysis.timeBlock.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .frame(width: 24)
                            
                            Text(analysis.timeBlock.displayName)
                                .font(.appBodyMedium)
                                .foregroundColor(.onPrimaryContainer)
                            
                            Spacer()
                            
                            Text("\(analysis.completionCount)/\(analysis.totalOpportunities)")
                                .font(.appBodySmall)
                                .foregroundColor(.text02)
                            
                            Text(analysis.successRatePercentage)
                                .font(.appBodyMediumEmphasised)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primaryContainer.opacity(0.1))
                        )
                    }
                }
                
                if let insight = TimeBlockHelper.getTimeBlockInsight(for: habit, completionRecords: completionRecords) {
                    Text(insight)
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .padding(.top, 8)
                        .italic()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
    }
    
    // MARK: - Progress Metrics Card
    private func progressMetricsCard(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text("Progress Metrics")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("This Month:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    let monthlyRate = ProgressCalculationHelper.getHabitMonthlyCompletionRate(for: habit, currentDate: Date())
                    Text("\(Int(monthlyRate * 100))%")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("This Week:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    let weeklyRate = ProgressCalculationHelper.getHabitWeeklyCompletionRate(for: habit, currentDate: Date())
                    Text("\(Int(weeklyRate * 100))%")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Today's Progress:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    let todayProgress = ProgressCalculationHelper.getHabitSpecificProgress(for: habit, date: Date())
                    Text("\(Int(todayProgress * 100))%")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
    }
    
    // MARK: - Personalized Recommendations Section
    private func personalizedRecommendationsSection(for habit: Habit?) -> some View {
        VStack(spacing: 20) {
            // Personalized Recommendations header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("Personalized Recommendations")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if let selectedHabit = habit {
                // Habit-specific recommendations
                habitSpecificRecommendations(for: selectedHabit)
            } else {
                // General recommendations for all habits
                generalRecommendations
            }
        }
    }
    
    // MARK: - Habit-Specific Recommendations
    private func habitSpecificRecommendations(for habit: Habit) -> some View {
        VStack(spacing: 16) {
            // Best Time Recommendation
            bestTimeRecommendation(for: habit)
            
            // Success Pattern Insights
            successPatternInsights(for: habit)
            
            // Weekly Optimization Tips
            weeklyOptimizationTips(for: habit)
        }
    }
    
    // MARK: - Best Time Recommendation
    private func bestTimeRecommendation(for habit: Habit) -> some View {
        let completionRecords = getCompletionRecords(for: habit)
        let timeAnalysis = TimeBlockHelper.analyzeTimePatterns(for: habit, completionRecords: completionRecords)
        let bestTimeBlock = timeAnalysis.first
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Best Time to Complete")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            if let bestTime = bestTimeBlock, bestTime.successRate > 0.5 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: bestTime.timeBlock.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Text("\(bestTime.timeBlock.displayName)s are your best time!")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Spacer()
                    }
                    
                    Text("You complete this habit \(bestTime.successRatePercentage) of the time during \(bestTime.timeBlock.displayName.lowercased())s")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                    
                    Text("💡 Try to schedule this habit for \(bestTime.timeBlock.displayName.lowercased())s when possible")
                        .font(.appBodySmall)
                        .foregroundColor(.primary)
                        .italic()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primaryContainer.opacity(0.1))
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not enough data yet")
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                    
                    Text("Complete this habit a few more times to get personalized time recommendations")
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .italic()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.outline3.opacity(0.1))
                )
            }
        }
    }
    
    // MARK: - Success Pattern Insights
    private func successPatternInsights(for habit: Habit) -> some View {
        let completionRecords = getCompletionRecords(for: habit)
        let monthlyRate = ProgressCalculationHelper.getHabitMonthlyCompletionRate(for: habit, currentDate: Date())
        let weeklyRate = ProgressCalculationHelper.getHabitWeeklyCompletionRate(for: habit, currentDate: Date())
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Success Patterns")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("This Month:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(Int(monthlyRate * 100))%")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("This Week:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(Int(weeklyRate * 100))%")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.primary)
                }
                
                // Success insight
                if monthlyRate > 0.8 {
                    Text("🎯 Excellent! You're consistently successful with this habit")
                        .font(.appBodySmall)
                        .foregroundColor(.green)
                        .italic()
                } else if monthlyRate > 0.6 {
                    Text("👍 Good progress! You're building consistency")
                        .font(.appBodySmall)
                        .foregroundColor(.primary)
                        .italic()
                } else if monthlyRate > 0.3 {
                    Text("💪 Keep going! Every completion builds momentum")
                        .font(.appBodySmall)
                        .foregroundColor(.orange)
                        .italic()
                } else {
                    Text("🌟 Starting is the hardest part. You've got this!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .italic()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - Weekly Optimization Tips
    private func weeklyOptimizationTips(for habit: Habit) -> some View {
        let completionRecords = getCompletionRecords(for: habit)
        let timeAnalysis = TimeBlockHelper.analyzeTimePatterns(for: habit, completionRecords: completionRecords)
        let bestTimeBlock = timeAnalysis.first
        let worstTimeBlock = timeAnalysis.last
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("This Week's Strategy")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let bestTime = bestTimeBlock, let worstTime = worstTimeBlock, bestTime.successRate > 0.5 {
                    Text("🎯 **Focus on \(bestTime.timeBlock.displayName.lowercased())s**")
                        .font(.appBodyMedium)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("Schedule this habit during your most successful time: \(bestTime.timeBlock.displayName.lowercased())s")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                    
                    if worstTime.successRate < 0.3 {
                        Text("⚠️ **Avoid \(worstTime.timeBlock.displayName.lowercased())s**")
                            .font(.appBodyMedium)
                            .foregroundColor(.orange)
                        
                        Text("This time has lower success rate (\(worstTime.successRatePercentage))")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
                    }
                } else {
                    Text("📅 **Build Consistency**")
                        .font(.appBodyMedium)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("Focus on completing this habit at the same time each day to build a routine")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                }
                
                Text("💡 **Pro Tip**: Set a daily reminder for your chosen time")
                    .font(.appBodySmall)
                    .foregroundColor(.primary)
                    .italic()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - General Recommendations
    private var generalRecommendations: some View {
        VStack(spacing: 16) {
            // Overall Progress Insights
            overallProgressInsights
            
            // Best Performing Habit
            bestPerformingHabitInsight
            
            // Habit Optimization Tips
            habitOptimizationTips
            
            // Weekly Strategy
            weeklyStrategy
        }
    }
    
    // MARK: - Overall Progress Insights
    private var overallProgressInsights: some View {
        let todayCompleted = getTodaysCompletedHabitsCount()
        let todayTotal = getTodaysTotalHabitsCount()
        let todayProgress = todayTotal > 0 ? Double(todayCompleted) / Double(todayTotal) : 0.0
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Today's Progress")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Completed:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(todayCompleted) of \(todayTotal) habits")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                }
                
                if todayProgress > 0.8 {
                    Text("🎉 Amazing day! You're on fire!")
                        .font(.appBodySmall)
                        .foregroundColor(.green)
                        .italic()
                } else if todayProgress > 0.6 {
                    Text("👍 Great progress! Keep the momentum going")
                        .font(.appBodySmall)
                        .foregroundColor(.primary)
                        .italic()
                } else if todayProgress > 0.3 {
                    Text("💪 Good start! Every habit completed counts")
                        .font(.appBodySmall)
                        .foregroundColor(.orange)
                        .italic()
                } else {
                    Text("🌟 Tomorrow is a new opportunity to build habits")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .italic()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - Best Performing Habit Insight
    private var bestPerformingHabitInsight: some View {
        let bestHabit = getBestPerformingHabit()
        let longestStreakHabit = getHabitWithLongestStreak()
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                
                Text("Top Performers")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let best = bestHabit {
                    let monthlyRate = ProgressCalculationHelper.getHabitMonthlyCompletionRate(for: best, currentDate: Date())
                    
                    HStack {
                        Text("🏆 Best This Month:")
                            .font(.appBodyMedium)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Spacer()
                        
                        Text("\(Int(monthlyRate * 100))%")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(best.name) - \(best.goal)")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .italic()
                }
                
                if let longest = longestStreakHabit, longest.streak > 0 {
                    HStack {
                        Text("🔥 Longest Streak:")
                            .font(.appBodyMedium)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Spacer()
                        
                        Text("\(longest.streak) days")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.primary)
                    }
                    
                    Text("\(longest.name) - \(longest.goal)")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .italic()
                }
                
                Text("💡 **Tip**: Learn from your most successful habits")
                    .font(.appBodySmall)
                    .foregroundColor(.primary)
                    .italic()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - Habit Optimization Tips
    private var habitOptimizationTips: some View {
        let totalHabits = habits.count
        let activeHabits = habits.filter { $0.streak > 0 }.count
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Habit Optimization")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Habits:")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("\(activeHabits) of \(totalHabits)")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                }
                
                if activeHabits == totalHabits {
                    Text("🎯 Perfect! All habits are active and building momentum")
                        .font(.appBodySmall)
                        .foregroundColor(.green)
                        .italic()
                } else if activeHabits > totalHabits / 2 {
                    Text("💪 Strong foundation! Focus on the inactive habits")
                        .font(.appBodySmall)
                        .foregroundColor(.primary)
                        .italic()
                } else {
                    Text("🌟 Start with 1-2 habits to build momentum")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .italic()
                }
                
                Text("💡 **Tip**: Focus on consistency over quantity")
                    .font(.appBodySmall)
                    .foregroundColor(.primary)
                    .italic()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - Weekly Strategy
    private var weeklyStrategy: some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("This Week's Strategy")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("📅 **Plan Your Week**")
                    .font(.appBodyMedium)
                    .foregroundColor(.onPrimaryContainer)
                
                Text("Schedule your most challenging habits during your peak energy times")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                
                Text("🎯 **Focus Areas**")
                    .font(.appBodyMedium)
                    .foregroundColor(.onPrimaryContainer)
                
                Text("• Complete 1 habit each day to build momentum")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                
                Text("• Use the calendar to track your progress")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                
                Text("• Celebrate small wins to stay motivated")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                
                Text("💡 **Pro Tip**: Review your progress at the end of each week")
                    .font(.appBodySmall)
                    .foregroundColor(.primary)
                    .italic()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surface)
            )
        }
    }
    
    // MARK: - Helper Methods
    private func getCompletionRecords(for habit: Habit) -> [CompletionRecordEntity] {
        // Get completion records from Core Data
        // Return empty array if Core Data is not available (e.g., in previews)
        let context = CoreDataManager.shared.context
        
        // Check if the context is valid and ready
        guard context.persistentStoreCoordinator?.persistentStores.isEmpty == false else {
            print("⚠️ Warning: Core Data persistent stores not loaded")
            return []
        }
        
        let request: NSFetchRequest<CompletionRecordEntity> = CompletionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "habit.id == %@", habit.id as CVarArg)
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching completion records: \(error)")
            return []
        }
    }
    
    // MARK: - Simplified Insights
    private func bestTimeRecommendationSimplified(for habit: Habit) -> some View {
        let completionRecords = getCompletionRecords(for: habit)
        let timeAnalysis = TimeBlockHelper.analyzeTimePatterns(for: habit, completionRecords: completionRecords)
        let bestTimeBlock = timeAnalysis.first
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("Quick Tip")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            
            if let bestTime = bestTimeBlock, bestTime.successRate > 0.5 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: bestTime.timeBlock.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                        
                        Text("\(bestTime.timeBlock.displayName)s work best for you")
                            .font(.appBodyMediumEmphasised)
                            .foregroundColor(.onPrimaryContainer)
                        
                        Spacer()
                    }
                    
                    Text("You complete this habit \(bestTime.successRatePercentage) of the time during \(bestTime.timeBlock.displayName.lowercased())s")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primaryContainer.opacity(0.1))
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep going!")
                        .font(.appBodyMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("Complete this habit a few more times to get personalized insights")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surface)
                )
            }
        }
    }
    

    
    // MARK: - Helper Methods for Recommendations
    private func getBestPerformingHabit() -> Habit? {
        return habits.max { habit1, habit2 in
            let rate1 = ProgressCalculationHelper.getHabitMonthlyCompletionRate(for: habit1, currentDate: Date())
            let rate2 = ProgressCalculationHelper.getHabitMonthlyCompletionRate(for: habit2, currentDate: Date())
            return rate1 < rate2
        }
    }
    
    private func getHabitWithLongestStreak() -> Habit? {
        return habits.max { $0.streak < $1.streak }
    }
}

#Preview {
    ProgressTabView(habits: [])
        .environmentObject(CoreDataAdapter.shared)
} 


