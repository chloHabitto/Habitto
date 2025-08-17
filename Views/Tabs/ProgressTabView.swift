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
                progressTrendText: ProgressTrendHelper.progressTrendIcon(for: ProgressTrendHelper.progressTrend(
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
    
    // MARK: - Enhanced Difficulty Insights Section
    private var difficultyInsightsSection: some View {
        VStack(spacing: 24) {
            // Enhanced section header with cute icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
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
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
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
                    // Today's Progress Summary (Simplified)
                    todaysProgressSummary
                    
                    // Overall Progress Section with Monthly Calendar
                    overallProgressSection
                    
                    // Difficulty Overview Section
                    difficultyInsightsSection
                        .padding(.top, 20)
                    
                    // Time Patterns Section
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


