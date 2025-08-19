import SwiftUI
import CoreData

struct ProgressTabView: View {
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    @State private var selectedHabit: Habit?
    @State private var showingHabitSelector = false
    let habits: [Habit]
    
    // Use the calendar helper
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    

    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Calendar Helper Functions
    // Moved to ProgressCalendarHelper.swift
    
    // MARK: - Today's Progress Summary (Simplified Card)
    private var todaysProgressSummary: some View {
        Group {
            if !habits.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Progress")
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(.onPrimaryContainer)
                            
                            Text("\(getTodaysCompletedHabitsCount()) of \(getTodaysTotalHabitsCount()) habits completed")
                                .font(.appBodyMedium)
                                .foregroundColor(.text02)
                        }
                        
                        Spacer()
                        
                        // Circular progress ring on the right
                        ZStack {
                            Circle()
                                .stroke(Color.outline3.opacity(0.3), lineWidth: 8)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.primary, Color.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.0), value: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits))
                            
                            Text("\(Int(ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits) * 100))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.outline3.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Overall Progress Section
    private var overallProgressSection: some View {
        VStack(spacing: 0) {
            // Monthly Calendar
            VStack(spacing: 12) {
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
                .padding(.bottom, 16)
                
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
        VStack(spacing: 20) {
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
        .padding(.horizontal, 20)
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

    
    var body: some View {
        WhiteSheetContainer(
            // title: "Progress"
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Habit Selector Header
                    habitSelectorHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Today's Progress Summary (Simplified) - only show when "All habits" selected
                    // if selectedHabit == nil {
                    //     todaysProgressSummary
                    // }
                    
                    // Overall Progress Section with Monthly Calendar
                    overallProgressSection
                    
                    // Habit-Specific Insights (only show when habit selected)
                    if let selectedHabit = selectedHabit {
                        habitSpecificInsightsSection(for: selectedHabit)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    
                    // General Insights (only show when "All habits" selected)
                    if selectedHabit == nil {
                        // Difficulty Overview Section
                        difficultyInsightsSection
                            .padding(.top, 20)
                        
                        // Time Patterns Section
                        TimeInsightsSection(
                            habit: selectedHabit,
                            completionRecords: selectedHabit != nil ? 
                                CoreDataAdapter.shared.fetchCompletionRecordsWithTimestamps(for: selectedHabit!) :
                                CoreDataAdapter.shared.fetchCompletionRecordsByHabitType(.formation) // Default to formation type
                        )
                        .padding(.top, 20)
                        
                        // Pattern Analysis Section
                        PatternInsightsSection(
                            habit: selectedHabit,
                            completionRecords: selectedHabit != nil ? 
                                CoreDataAdapter.shared.fetchCompletionRecordsWithTimestamps(for: selectedHabit!) :
                                CoreDataAdapter.shared.fetchCompletionRecordsByHabitType(.formation), // Default to formation type
                            difficultyLogs: selectedHabit != nil ? 
                                CoreDataAdapter.shared.fetchDifficultyLogs(for: selectedHabit!) :
                                CoreDataAdapter.shared.fetchAllDifficultyLogs()
                        )
                        .padding(.top, 20)
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
    
    // MARK: - Helper Methods
    private func getCompletionRecords(for habit: Habit) -> [CompletionRecordEntity] {
        // Get completion records from Core Data
        let request: NSFetchRequest<CompletionRecordEntity> = CompletionRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "habit.id == %@", habit.id as CVarArg)
        
        do {
            return try CoreDataManager.shared.context.fetch(request)
        } catch {
            print("❌ Error fetching completion records: \(error)")
            return []
        }
    }
}

#Preview {
    ProgressTabView(habits: [])
} 


