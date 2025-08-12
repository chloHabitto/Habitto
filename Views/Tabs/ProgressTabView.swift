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
        VStack(spacing: 16) {
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
                    
                    Image(systemName: "chevron.down")
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
                .frame(minHeight: 240)
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
                }
                .frame(maxWidth: .infinity, alignment: .top)
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
