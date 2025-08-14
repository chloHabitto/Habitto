import SwiftUI

struct ProgressTabView: View {
    @State private var selectedHabitType: HabitType = .formation
    @State private var showingHabitsList = false
    @State private var selectedHabit: Habit? = nil
    let habits: [Habit]
    
    // Use the calendar helper
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    

    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Calendar Helper Functions
    // Moved to ProgressCalendarHelper.swift
    
    // MARK: - Independent Today's Progress Container
    private var independentTodaysProgressContainer: some View {
        Group {
            if !habits.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    ProgressChartComponents.ProgressCard(
                        title: "Today's Goal Progress",
                        subtitle: "Great progress! Keep building your habits!",
                        progress: ProgressCalculationHelper.todaysActualCompletionPercentage(habits: habits),
                        progressRingSize: 52
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Overall Progress Section
    private var overallProgressSection: some View {
        VStack(spacing: 0) {
            // Overall + down chevron header - left aligned
            Button(action: {
                showingHabitsList = true
            }) {
                HStack(spacing: 0) {
                    // Always show an icon - either overall icon or selected habit icon
                    if let selectedHabit = selectedHabit {
                        HabitIconView(habit: selectedHabit)
                            .frame(width: 38, height: 54)
                    } else {
                        // Overall icon when no specific habit is selected - match HabitIconView exactly
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
                    
                    Spacer()
                        .frame(width: 8)
                    
                    Text(selectedHabit?.name ?? "Overall")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                        .frame(width: 12)
                    
                    Image(systemName: showingHabitsList ? "chevron.up" : "chevron.down")
                        .font(.appLabelMedium)
                        .foregroundColor(.primaryFocus)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            
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
                            selectedHabitType: selectedHabitType,
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
                    selectedHabitType: selectedHabitType,
                    selectedHabit: selectedHabit
                ),
                monthlyCompletedHabits: ProgressCalculationHelper.monthlyCompletedHabits(
                    habits: habits,
                    currentDate: calendarHelper.currentDate,
                    selectedHabitType: selectedHabitType
                ),
                monthlyTotalHabits: ProgressTrendHelper.monthlyTotalHabits(
                    habits: habits,
                    selectedHabitType: selectedHabitType
                ),
                topPerformingHabit: ProgressTrendHelper.topPerformingHabit(
                    habits: habits,
                    selectedHabitType: selectedHabitType,
                    currentDate: calendarHelper.currentDate
                ),
                needsAttentionHabit: ProgressTrendHelper.needsAttentionHabit(
                    habits: habits,
                    selectedHabitType: selectedHabitType,
                    currentDate: calendarHelper.currentDate
                ),
                progressTrendColor: ProgressTrendHelper.progressTrendColor(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType,
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType
                    )
                )),
                progressTrendIcon: ProgressTrendHelper.progressTrendIcon(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType,
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType
                    )
                )),
                progressTrendText: ProgressTrendHelper.progressTrendText(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType,
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType
                    )
                )),
                progressTrendDescription: ProgressTrendHelper.progressTrendDescription(for: ProgressTrendHelper.progressTrend(
                    currentMonthRate: ProgressCalculationHelper.monthlyCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType,
                        selectedHabit: selectedHabit
                    ),
                    previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                        habits: habits,
                        currentDate: calendarHelper.currentDate,
                        selectedHabitType: selectedHabitType
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
    
    // MARK: - Difficulty Insights Section
    private var difficultyInsightsSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Difficulty Insights")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Difficulty insights content
            VStack(spacing: 12) {
                // Most difficult habit this month
                if let mostDifficultHabit = getMostDifficultHabit() {
                    difficultyInsightCard(
                        title: "Most Challenging",
                        subtitle: mostDifficultHabit.name,
                        description: "Average difficulty: \(getAverageDifficulty(for: mostDifficultHabit))",
                        color: .red,
                        icon: "exclamationmark.triangle.fill"
                    )
                }
                
                // Difficulty trend
                if let difficultyTrend = getDifficultyTrend() {
                    difficultyInsightCard(
                        title: "Difficulty Trend",
                        subtitle: difficultyTrend.title,
                        description: difficultyTrend.description,
                        color: difficultyTrend.color,
                        icon: difficultyTrend.icon
                    )
                }
                
                // Easy wins
                if let easyWins = getEasyWins() {
                    difficultyInsightCard(
                        title: "Easy Wins",
                        subtitle: "\(easyWins.count) habits",
                        description: "These habits feel easier lately",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Difficulty Insight Card
    private func difficultyInsightCard(
        title: String,
        subtitle: String,
        description: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                
                Text(subtitle)
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text01)
                
                Text(description)
                    .font(.appBodySmall)
                    .foregroundColor(.text03)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.outline3, lineWidth: 1)
        )
    }
    
    // MARK: - Difficulty Data Helpers
    private func getMostDifficultHabit() -> Habit? {
        // Get habits with difficulty data for current month
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        var habitDifficulties: [(habit: Habit, averageDifficulty: Double)] = []
        
        for habit in habits {
            let difficulties = getDifficultiesForHabit(habit, month: currentMonth, year: currentYear)
            if !difficulties.isEmpty {
                let average = difficulties.reduce(0, +) / Double(difficulties.count)
                habitDifficulties.append((habit: habit, averageDifficulty: average))
            }
        }
        
        // Return habit with highest average difficulty
        return habitDifficulties.max(by: { $0.averageDifficulty < $1.averageDifficulty })?.habit
    }
    
    private func getAverageDifficulty(for habit: Habit) -> String {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let difficulties = getDifficultiesForHabit(habit, month: currentMonth, year: currentYear)
        
        if difficulties.isEmpty { return "No data" }
        
        let average = difficulties.reduce(0, +) / Double(difficulties.count)
        let difficultyNames = ["Very Easy", "Easy", "Medium", "Hard", "Very Hard"]
        let index = min(Int(average) - 1, difficultyNames.count - 1)
        return difficultyNames[max(0, index)]
    }
    
    private func getDifficultyTrend() -> (title: String, description: String, color: Color, icon: String)? {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let previousMonth = currentMonth == 1 ? 12 : currentMonth - 1
        let previousYear = currentMonth == 1 ? currentYear - 1 : currentYear
        
        let currentDifficulties = getAllDifficulties(month: currentMonth, year: currentYear)
        let previousDifficulties = getAllDifficulties(month: previousMonth, year: previousYear)
        
        if currentDifficulties.isEmpty || previousDifficulties.isEmpty { return nil }
        
        let currentAverage = currentDifficulties.reduce(0, +) / Double(currentDifficulties.count)
        let previousAverage = previousDifficulties.reduce(0, +) / Double(previousDifficulties.count)
        
        let difference = currentAverage - previousAverage
        
        if difference < -0.5 {
            return ("Getting Easier", "Habits feel less challenging this month", .green, "arrow.down.circle.fill")
        } else if difference > 0.5 {
            return ("Getting Harder", "Habits feel more challenging this month", .orange, "arrow.up.circle.fill")
        } else {
            return ("Stable", "Difficulty level is consistent", .blue, "equal.circle.fill")
        }
    }
    
    private func getEasyWins() -> [Habit]? {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        var easyHabits: [Habit] = []
        
        for habit in habits {
            let difficulties = getDifficultiesForHabit(habit, month: currentMonth, year: currentYear)
            if !difficulties.isEmpty {
                let average = difficulties.reduce(0, +) / Double(difficulties.count)
                if average <= 2.0 { // Easy or Very Easy
                    easyHabits.append(habit)
                }
            }
        }
        
        return easyHabits.isEmpty ? nil : easyHabits
    }
    
    private func getDifficultiesForHabit(_ habit: Habit, month: Int, year: Int) -> [Double] {
        return CoreDataAdapter.shared.fetchDifficultiesForHabit(habit.id, month: month, year: year)
    }
    
    private func getAllDifficulties(month: Int, year: Int) -> [Double] {
        return CoreDataAdapter.shared.fetchAllDifficulties(month: month, year: year)
    }
    
    var body: some View {
        WhiteSheetContainer(
            // title: "Progress"
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Independent Today's Progress Container
                    independentTodaysProgressContainer
                        .padding(.top, 20)
                    
                    // Overall Progress Section with Monthly Calendar
                    overallProgressSection
                    
                    // Difficulty Insights Section
                    difficultyInsightsSection
                        .padding(.top, 20)
                    
                    // Time-Based Insights Section
                    TimeInsightsSection(
                        habit: selectedHabit,
                        completionRecords: selectedHabit != nil ? 
                            CoreDataAdapter.shared.fetchCompletionRecordsWithTimestamps(for: selectedHabit!) :
                            CoreDataAdapter.shared.fetchCompletionRecordsByHabitType(selectedHabitType)
                    )
                    .padding(.top, 20)
                    
                    // Pattern Analysis Section
                    PatternInsightsSection(
                        habit: selectedHabit,
                        completionRecords: selectedHabit != nil ? 
                            CoreDataAdapter.shared.fetchCompletionRecordsWithTimestamps(for: selectedHabit!) :
                            CoreDataAdapter.shared.fetchCompletionRecordsByHabitType(selectedHabitType),
                        difficultyLogs: selectedHabit != nil ? 
                            CoreDataAdapter.shared.fetchDifficultyLogs(for: selectedHabit!) :
                            CoreDataAdapter.shared.fetchAllDifficultyLogs()
                    )
                    .padding(.top, 20)
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
                print("🔍 CALENDAR STATE DEBUG - Calendar displaying for overall progress (habit type: \(selectedHabitType))")
            }
        }
        .sheet(isPresented: $showingHabitsList) {
            HabitsListPopup(
                habits: habits,
                selectedHabit: selectedHabit,
                showingHabitsList: showingHabitsList,
                onHabitSelected: { habit in
                    selectedHabit = habit
                    showingHabitsList = false
                },
                onDismiss: {
                    showingHabitsList = false
                }
            )
        }
    }
}

#Preview {
    ProgressTabView(habits: [])
} 
