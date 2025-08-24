import SwiftUI
import CoreData

struct ProgressTabView: View {
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    @State private var selectedHabit: Habit?
    @State private var showingHabitSelector = false
    @State private var selectedTimePeriod: Int = 0 // 0: Daily, 1: Weekly, 2: Monthly
    @State private var selectedProgressDate: Date = Date() // Date for viewing progress
    @State private var showingDatePicker = false // Control date picker modal
    @State private var currentInsightPage: Int = 0 // For unified insights card pagination
    @State private var selectedWeekStartDate: Date = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        let today = Date()
        // Get the start of the current week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return weekStart
    }()
    @State private var showingAllReminders = false // Control reminders sheet
    @State private var showingWeekPicker = false // Control week picker modal
    @State private var showingMonthPicker = false
    let habits: [Habit]
    
    // Use the calendar helper
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    

    
    init(habits: [Habit]) {
        self.habits = habits
    }
    
    // MARK: - Computed Properties
    private var timePeriodTitle: String {
        switch selectedTimePeriod {
        case 0:
            return "Daily Progress"
        case 1:
            return "Weekly Progress"
        case 2:
            return calendarHelper.monthYearString()
        default:
            return "Weekly Progress"
        }
    }
    
    // Formatted date for progress tab (similar to Home tab)
    private var formattedProgressDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedProgressDate)
    }
    
    // Check if selected date is today
    private var isTodaySelected: Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(selectedProgressDate, inSameDayAs: today)
    }
    
    // Daily progress ring view
    private var dailyProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: CGFloat(getSelectedDateCompletionPercentage()))
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: getSelectedDateCompletionPercentage())
            
            Text("\(Int(getSelectedDateCompletionPercentage() * 100))%")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // Helper struct for today's reminders
    private struct TodaysReminder: Identifiable {
        let id = UUID()
        let habitName: String
        let reminderTime: Date
        let formattedTime: String
        let reminder: ReminderItem
        let habit: Habit
        
        init(habitName: String, reminderTime: Date, reminder: ReminderItem, habit: Habit) {
            self.habitName = habitName
            self.reminderTime = reminderTime
            self.reminder = reminder
            self.habit = habit
            
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            self.formattedTime = formatter.string(from: reminderTime)
        }
    }
    
    // Get today's reminders from habits scheduled for today only
    private func getTodaysReminders() -> [TodaysReminder] {
        var todaysReminders: [TodaysReminder] = []
        let calendar = Calendar.current
        let now = Date()
        
        for habit in habits {
            // First check if this habit is scheduled for today
            let isScheduledForToday = shouldShowHabitOnDate(habit, date: selectedProgressDate)
            
            // Only include reminders from habits that are scheduled for today
            if isScheduledForToday && !habit.reminders.isEmpty {
                for reminder in habit.reminders {
                    // Only include active reminders
                    if reminder.isActive {
                        // Create reminder time for the selected date
                        let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
                        let selectedDateComponents = calendar.dateComponents([.year, .month, .day], from: selectedProgressDate)
                        
                        var fullReminderDateComponents = DateComponents()
                        fullReminderDateComponents.year = selectedDateComponents.year
                        fullReminderDateComponents.month = selectedDateComponents.month
                        fullReminderDateComponents.day = selectedDateComponents.day
                        fullReminderDateComponents.hour = reminderComponents.hour
                        fullReminderDateComponents.minute = reminderComponents.minute
                        
                        if let fullReminderDate = calendar.date(from: fullReminderDateComponents) {
                            // If we're viewing today, only show reminders that haven't passed yet
                            let isToday = calendar.isDate(selectedProgressDate, inSameDayAs: now)
                            let hasNotPassedToday = !isToday || fullReminderDate >= now
                            
                            if hasNotPassedToday {
                                todaysReminders.append(TodaysReminder(
                                    habitName: habit.name,
                                    reminderTime: reminder.time,
                                    reminder: reminder,
                                    habit: habit
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // Sort reminders by time (earliest first)
        return todaysReminders.sorted { $0.reminderTime < $1.reminderTime }
    }
    
    // Toggle reminder active status
    private func toggleReminder(_ reminder: ReminderItem, in habit: Habit) {
        // Create a new Habit instance with updated reminders
        let updatedReminders = habit.reminders.map { existingReminder in
            if existingReminder.id == reminder.id {
                // Create a new ReminderItem with toggled isActive status
                return ReminderItem(
                    time: existingReminder.time,
                    isActive: !existingReminder.isActive
                )
            }
            return existingReminder
        }
        
        // Create a new Habit instance with the updated reminders
        let updatedHabit = Habit(
            id: habit.id,
            name: habit.name,
            description: habit.description,
            icon: habit.icon,
            color: habit.color,
            habitType: habit.habitType,
            schedule: habit.schedule,
            goal: habit.goal,
            reminder: habit.reminder,
            startDate: habit.startDate,
            endDate: habit.endDate,
            isCompleted: habit.isCompleted,
            streak: habit.streak,
            createdAt: habit.createdAt,
            reminders: updatedReminders,
            baseline: habit.baseline,
            target: habit.target,
            completionHistory: habit.completionHistory,
            actualUsage: habit.actualUsage
        )
        
        // Update the habit in Core Data
        coreDataAdapter.updateHabit(updatedHabit)
    }
    
    // MARK: - Calendar Helper Functions
    // Moved to ProgressCalendarHelper.swift
    
    // Weekly date range string
    private var weeklyDateRangeString: String {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: startOfWeek)
        let endString = formatter.string(from: endOfWeek)
        
        return "\(startString) - \(endString)"
    }
    
    // Check if current week is selected
    private var isCurrentWeekSelected: Bool {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        let today = Date()
        // Get the start of the current week (Monday)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return calendar.isDate(selectedWeekStartDate, inSameDayAs: currentWeekStart)
    }
    
    // Get weekly date range string for a specific week
    private func getWeeklyDateRangeString(for weekStartDate: Date) -> String {
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStartDate)
        let endString = formatter.string(from: endOfWeek)
        
        return "\(startString) - \(endString)"
    }
    
    // Monthly completion helper functions
    private func getMonthlyCompletedHabitsCount() -> Int {
        return ProgressCalculationHelper.monthlyCompletedHabits(
            habits: habits,
            currentDate: calendarHelper.currentDate,
            selectedHabitType: .formation
        )
    }
    
    private func getMonthlyTotalHabitsCount() -> Int {
        return ProgressTrendHelper.monthlyTotalHabits(
            habits: habits,
            selectedHabitType: .formation
        )
    }
    
    private func getMonthlyCompletionPercentage() -> Double {
        let completed = getMonthlyCompletedHabitsCount()
        let total = getMonthlyTotalHabitsCount()
        guard total > 0 else { return 0.0 }
        return Double(completed) / Double(total)
    }
    
    // Monthly insights helper functions
    private func getTopPerformingHabit() -> Habit? {
        return ProgressTrendHelper.topPerformingHabit(
            habits: habits,
            selectedHabitType: .formation,
            currentDate: calendarHelper.currentDate
        )
    }
    
    private func getMonthlyHabitCompletionRate(for habit: Habit) -> Double {
        return ProgressCalculationHelper.monthlyHabitCompletionRate(
            for: habit,
            currentDate: calendarHelper.currentDate
        )
    }
    
    private func getProgressTrendColor() -> Color {
        return ProgressTrendHelper.progressTrendColor(for: ProgressTrendHelper.progressTrend(
            currentMonthRate: getMonthlyCompletionPercentage(),
            previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                habits: habits,
                currentDate: calendarHelper.currentDate,
                selectedHabitType: .formation
            )
        ))
    }
    
    private func getProgressTrendIcon() -> String {
        return ProgressTrendHelper.progressTrendIcon(for: ProgressTrendHelper.progressTrend(
            currentMonthRate: getMonthlyCompletionPercentage(),
            previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                habits: habits,
                currentDate: calendarHelper.currentDate,
                selectedHabitType: .formation
            )
        ))
    }
    
    private func getProgressTrendText() -> String {
        return ProgressTrendHelper.progressTrendText(for: ProgressTrendHelper.progressTrend(
            currentMonthRate: getMonthlyCompletionPercentage(),
            previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                habits: habits,
                currentDate: calendarHelper.currentDate,
                selectedHabitType: .formation
            )
        ))
    }
    
    private func getProgressTrendDescription() -> String {
        return ProgressTrendHelper.progressTrendDescription(for: ProgressTrendHelper.progressTrend(
            currentMonthRate: getMonthlyCompletionPercentage(),
            previousMonthRate: ProgressCalculationHelper.previousMonthCompletionRate(
                habits: habits,
                currentDate: calendarHelper.currentDate,
                selectedHabitType: .formation
            )
        ))
    }
    
    // MARK: - Overall Progress Section
    private var overallProgressSection: some View {
        VStack(spacing: 0) {
            switch selectedTimePeriod {
            case 0: // Daily
                dailyProgressSection
            case 1: // Weekly
                weeklyProgressSection
            case 2: // Monthly
                monthlyProgressSection
            default:
                weeklyProgressSection
            }
        }
        .onChange(of: selectedTimePeriod) { _, newValue in
            // Haptic feedback when switching tabs
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    // MARK: - Daily Progress Section
    private var dailyProgressSection: some View {
        VStack(spacing: 0) {
            // Date Section (similar to Home tab)
            HStack {
                // Date text with chevron down icon - acts as a button
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack(spacing: 8) {
                        Text(formattedProgressDate)
                            .font(.appTitleMediumEmphasised)
                            .lineSpacing(8)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .opacity(0.7)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Today button (shown when selected date is not today)
                if !isTodaySelected {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.08)) {
                            selectedProgressDate = Date()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(.iconReplay)
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
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
//            .background(.red)
            
            // Daily Progress Summary
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Progress")
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.white)
                            
                        Text("\(getTodaysCompletedHabitsCount()) of \(getTodaysTotalHabitsCount()) habits completed")
                                .font(.appBodyMedium)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                    // Daily progress ring
                    dailyProgressRing
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.primary)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
            }
            
            // Today's Reminders Section
            VStack(spacing: 8) {
                // Header with "See more" button
                HStack {
                    Text("Today's reminders")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                    
                    Button(action: {
                        // Show all reminders (both active and inactive)
                        showingAllReminders = true
                    }) {
                        HStack(spacing: 4) {
                            Text("See more")
                                .font(.appBodyMedium)
                                .foregroundColor(.primaryFocus)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primaryFocus)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Today's reminders list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Get today's reminders from all habits
                        let todaysReminders = getTodaysReminders()
                        
                        if !todaysReminders.isEmpty {
                            // Display actual reminders
                            ForEach(todaysReminders, id: \.id) { reminder in
                                Button(action: {
                                    // TODO: Handle reminder tap
                                    print("📅 Reminder tapped for habit: \(reminder.habitName)")
                                }) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Header with icon and title
                                        HStack(spacing: 12) {
                                            // Icon with background circle - larger for better touch target
                        ZStack {
                            Circle()
                                                    .fill(Color.primary.opacity(0.12))
                                                    .frame(width: 36, height: 36)
                                                
                                                Image("Icon-Bell_Filled")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            // Title with better typography and spacing
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(reminder.habitName)
                                                    .font(.appTitleSmallEmphasised)
                                                    .foregroundColor(.onPrimaryContainer)
                                                    .lineLimit(1)
                                                
                                                // Subtitle for better hierarchy
                                                Text("Daily reminder")
                                                    .font(.appBodySmall)
                                                    .foregroundColor(.text03)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        // Time with enhanced styling and better spacing
                                        HStack(spacing: 8) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.text03)
                                                .frame(width: 18)
                                            
                                            Text(reminder.formattedTime)
                                                .font(.appBodyMediumEmphasised)
                                                .foregroundColor(.text01)
                                                .fontWeight(.semibold)
                                            
                                            Spacer()
                                            
                                            // Toggle for reminder status
                                            Toggle("", isOn: Binding(
                                                get: { reminder.reminder.isActive },
                                                set: { newValue in
                                                    toggleReminder(reminder.reminder, in: reminder.habit)
                                                }
                                            ))
                                                .toggleStyle(SwitchToggleStyle(tint: .primary))
                                                .scaleEffect(0.8)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .frame(width: 220, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.surface,
                                                        Color.surface.opacity(0.95)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                                            colors: [
                                                                Color.primary.opacity(0.1),
                                                                Color.primary.opacity(0.05)
                                                            ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                                        lineWidth: 1.5
                                                    )
                                            )
                                    )
                                }
                                .scaleEffect(0.98)
                                .animation(.easeInOut(duration: 0.1), value: true)
                            }
                        } else {
                            // Empty state when no reminders - simple, cute, and beautiful
                            HStack(spacing: 16) {
                                // Cute bell icon with soft background
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.primary.opacity(0.08),
                                                    Color.primary.opacity(0.04)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                )
                                .frame(width: 48, height: 48)
                                    
                                    Image("Icon-Bell_Filled")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.primary.opacity(0.7))
                                }
                                
                                // Simple, friendly text
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("All caught up! 🎉")
                                        .font(.appTitleSmallEmphasised)
                                        .foregroundColor(.onPrimaryContainer)
                                    
                                    Text("No reminders for today")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.text03)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.surface,
                                                Color.surface.opacity(0.98)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                        .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.primary.opacity(0.08),
                                                        Color.primary.opacity(0.04)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .padding(.top, 24)
        }
    }
    
    // MARK: - Weekly Progress Section
    private var weeklyProgressSection: some View {
        VStack(spacing: 0) {
            // Add top spacing to separate from tabs
            Spacer()
                .frame(height: 20)
            
            // Weekly Calendar
            VStack(spacing: 8) {
                // Animation state for grid appear animation
                @State var gridAppearAnimation = true
                
                // Calendar header with week range and This week button
                HStack {
                    HStack(spacing: 4) {
                        Text(getWeeklyDateRangeString(for: selectedWeekStartDate))
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .opacity(0.7)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("📅 Week picker button tapped")
                        showingWeekPicker = true
                    }
                    
                    Spacer()
                    
                    if !isCurrentWeekSelected {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                var calendar = Calendar.current
                                calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
                                let today = Date()
                                // Get the start of the current week (Monday)
                                let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
                                selectedWeekStartDate = weekStart
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(.iconReplay)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.primaryFocus)
                                Text("This week")
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
                        .padding(.trailing, 4) // Add some trailing padding to prevent clipping
                    }
                }
                .padding(.bottom, 12)
                .clipped() // Ensure no clipping occurs
                
                // Weekly Calendar Grid (7 days in a row) - matching monthly calendar style
                VStack(spacing: 8) {
                    // Days of week header - using same style as monthly calendar
                CalendarGridComponents.WeekdayHeader()
                
                    // Week days grid - using LazyVGrid for perfect alignment with monthly calendar
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(0..<7, id: \.self) { dayOffset in
                            let currentDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: selectedWeekStartDate) ?? Date()
                            let isToday = Calendar.current.isDateInToday(currentDay)
                            let dayNumber = Calendar.current.component(.day, from: currentDay)
                            
                            CalendarGridComponents.CalendarDayCell(
                                day: dayNumber,
                                progress: getDayProgress(for: currentDay),
                                isToday: isToday,
                                isSelected: false,
                                isCurrentMonth: true,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedProgressDate = currentDay
                                        selectedTimePeriod = 0 // Switch to daily view
                                    }
                                }
                            )
                            .id("weekday-\(dayOffset)")
                            .opacity(gridAppearAnimation ? 1 : 0)
                            .offset(y: gridAppearAnimation ? 0 : 20)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(dayOffset) * 0.02),
                                value: gridAppearAnimation
                            )
                        }
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                            gridAppearAnimation = true
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            // Only trigger week change for horizontal swipes
                            if abs(value.translation.width) > abs(value.translation.height) {
                                if value.translation.width > threshold {
                                    // Swipe right - go to previous week
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedWeekStartDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStartDate) ?? selectedWeekStartDate
                                    }
                                } else if value.translation.width < -threshold {
                                    // Swipe left - go to next week
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedWeekStartDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStartDate) ?? selectedWeekStartDate
                                    }
                                }
                            }
                        }
                )
            }
            .clipped()
            .padding(20)
            .background(Color.surface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.outline3, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            
            // Add spacing between weekly calendar and weekly progress card
            Spacer()
                .frame(height: 16)
            
            // Weekly Progress Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Completion")
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.white)
                        
                        Text("\(getWeeklyCompletedHabitsCount()) of \(getWeeklyTotalHabitsCount()) habits completed")
                            .font(.appBodyMedium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Weekly progress ring (similar to daily)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: getWeeklyCompletionPercentage())
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: getWeeklyCompletionPercentage())
                        
                        Text("\(Int(getWeeklyCompletionPercentage() * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            
            // Add spacing before unified insights
            Spacer()
                .frame(height: 20)
            
            // Unified insights card
            unifiedInsightsCard
        }
    }
    
    // MARK: - Monthly Progress Section
    private var monthlyProgressSection: some View {
        VStack(spacing: 0) {
            // Add top spacing to separate from tabs
            Spacer()
                .frame(height: 20)
            
            // Monthly Calendar
            monthlyCalendarSection
            
            // Add spacing between monthly calendar and monthly progress card
            Spacer()
                .frame(height: 16)
            
            // Monthly Progress Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Progress")
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.white)
                        
                        Text("\(getMonthlyCompletedHabitsCount()) of \(getMonthlyTotalHabitsCount()) habits completed")
                            .font(.appBodyMedium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Monthly progress ring (similar to daily)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: getMonthlyCompletionPercentage())
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white, Color.white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: getMonthlyCompletionPercentage())
                        
                        Text("\(Int(getMonthlyCompletionPercentage() * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            
            // Add spacing before unified insights
            Spacer()
                .frame(height: 20)
            
            // Unified insights card
            unifiedInsightsCard
        }
    }
    
    // MARK: - Unified Insights Card
    private var unifiedInsightsCard: some View {
        VStack(spacing: 0) {
            // Header with title and page control
            HStack {
                Text(insightTitles[currentInsightPage])
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                
                // Page control
                HStack(spacing: 8) {
                    ForEach(0..<insightTitles.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentInsightPage ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentInsightPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentInsightPage)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Bottom stroke below header
            Divider()
                .background(Color.outline3.opacity(0.3))
            
            // Content area with native page swiping
            TabView(selection: $currentInsightPage) {
                habitSpotlightContent
                    .tag(0)
                
                progressTrendContent
                    .tag(1)
                
                challengeCornerContent
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(minHeight: 180)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentInsightPage = (currentInsightPage + 1) % insightTitles.count
                }
                // Haptic feedback for tap navigation
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .onChange(of: currentInsightPage) { _, newPage in
                // Haptic feedback for swipe navigation
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Insight Content Pages
    private var insightTitles: [String] {
        ["Habit Spotlight", "Progress Trends", "Challenge Corner"]
    }
    
    private var habitSpotlightContent: some View {
        VStack(spacing: 0) {
            if let topHabit = getTopPerformingHabit() {
                // Main content
                HStack(spacing: 20) {
                    // Star icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Superstar Habit")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        
                        Text(topHabit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        let rate = getMonthlyHabitCompletionRate(for: topHabit)
                        Text("\(Int(rate * 100))% completion rate")
                            .font(.appBodyMedium)
                            .foregroundColor(.yellow)
                            .fontWeight(.semibold)
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
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yellow)
                        
                        Text("You're on fire! Keep this momentum going! 🔥")
                            .font(.appBodySmall)
                            .foregroundColor(.text03)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow.opacity(0.5))
                    
                    Text("Keep building habits to see your superstar!")
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var progressTrendContent: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 20) {
                // Trend icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [getProgressTrendColor().opacity(0.25), getProgressTrendColor().opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: getProgressTrendIcon())
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(getProgressTrendColor())
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly Progress")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(getProgressTrendColor().opacity(0.1))
                        )
                    
                    Text(getProgressTrendText())
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                        .lineLimit(2)
                    
                    Text(getProgressTrendDescription())
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Bottom trend analysis section
            VStack(spacing: 8) {
                Divider()
                    .background(Color.outline3.opacity(0.3))
                
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(getProgressTrendColor())
                    
                    Text("Your progress pattern shows consistent improvement!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
    }
    
    private var challengeCornerContent: some View {
        VStack(spacing: 0) {
            if let mostDifficultHabit = getMostDifficultHabit() {
                // Main content
                HStack(spacing: 20) {
                    // Challenge icon
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
                        
                        Text(mostDifficultHabit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        Text(getMotivationalMessage(for: mostDifficultHabit))
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
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.7))
                    
                    Text("No challenges right now - you're crushing it!")
                        .font(.appBodyMedium)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
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
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
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
    
    // MARK: - Helper Methods for Daily Progress (using selected date)
    private func getTodaysCompletedHabitsCount() -> Int {
        return habits.filter { habit in
            let progress = habit.getProgress(for: selectedProgressDate)
            let goalAmount = ProgressCalculationHelper.parseGoalAmount(from: habit.goal)
            return progress >= goalAmount
        }.count
    }
    
    private func getTodaysTotalHabitsCount() -> Int {
        return habits.filter { habit in
            // Match Home tab logic: check date range first
            let selected = DateUtils.startOfDay(for: selectedProgressDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            guard selected >= start && selected <= end else {
                return false
            }
            
            // Then check if habit should show on this date using same logic as Home tab
            return shouldShowHabitOnDate(habit, date: selectedProgressDate)
        }.count
    }
    
    // Daily progress percentage for selected date (overall progress across all habits)
    private func getSelectedDateCompletionPercentage() -> Double {
        return ProgressCalculationHelper.getDayProgress(
            for: selectedProgressDate,
            habits: habits,
            selectedHabitType: .formation,
            selectedHabit: nil
        )
    }
    
    // MARK: - Habit Scheduling Logic (matches Home tab)
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let weekday = DateUtils.weekday(for: date)
        
        // Check if the date is before the habit start date
        if date < DateUtils.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
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
        case "Monday":
            return weekday == 2
        case "Tuesday":
            return weekday == 3
        case "Wednesday":
            return weekday == 4
        case "Thursday":
            return weekday == 5
        case "Friday":
            return weekday == 6
        case "Saturday":
            return weekday == 7
        case "Sunday":
            return weekday == 1
        default:
            // Handle custom schedules like "Every Monday, Wednesday, Friday"
            if habit.schedule.lowercased().contains("every") && habit.schedule.lowercased().contains("day") {
                // First check if it's an "Every X days" schedule
                if let dayCount = extractDayCount(from: habit.schedule) {
                    // Handle "Every X days" schedules
                    let startDate = DateUtils.startOfDay(for: habit.startDate)
                    let targetDate = DateUtils.startOfDay(for: date)
                    let daysSinceStart = DateUtils.daysBetween(startDate, targetDate)
                    
                    // Check if the target date falls on the schedule
                    return daysSinceStart >= 0 && daysSinceStart % dayCount == 0
                } else {
                    // Extract weekdays from schedule (like "Every Monday, Wednesday, Friday")
                    let weekdays = extractWeekdays(from: habit.schedule)
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
                    let weekStart = DateUtils.startOfWeek(for: date)
                    let weekEnd = DateUtils.endOfWeek(for: date)
                    return date >= weekStart && date <= weekEnd
                }
                return false
            }
            // Check if schedule contains multiple weekdays separated by commas
            if habit.schedule.contains(",") {
                let weekdays = extractWeekdays(from: habit.schedule)
                return weekdays.contains(weekday)
            }
            // For any unrecognized schedule format, don't show the habit
            return false
        }
    }
    
    // MARK: - Schedule Parsing Helper Functions
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
        // Weekday names for parsing
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var weekdays: Set<Int> = []
        let lowercasedSchedule = schedule.lowercased()
        
        for (index, dayName) in weekdayNames.enumerated() {
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
    
    private func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
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
            contentBackground: .surface2
        ) {
                VStack(spacing: 0) {
                // Fixed Header Section
                    habitSelectorHeader
                    .padding(.top, 16)
                    .background(Color.white)
                    
                // Scrollable Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                    // Overall Progress Section with Monthly Calendar
                    overallProgressSection
                    
                    // Habit-Specific Insights (only show when habit selected)
                    if let selectedHabit = selectedHabit {
                        // Show only essential insights for selected habit
                        VStack(spacing: 20) {
                            // Just the time recommendation - most actionable insight
                            bestTimeRecommendationSimplified(for: selectedHabit)
                                    .padding(.horizontal, 16)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollDisabled(false)
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "scrollView")
            }
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
        .sheet(isPresented: $showingAllReminders) {
            AllRemindersView(habits: habits, coreDataAdapter: coreDataAdapter)
        }
        .overlay(
            // Week Selection Modal
            showingWeekPicker ? AnyView(
                WeekPickerModal(
                    selectedWeekStartDate: $selectedWeekStartDate,
                    isPresented: $showingWeekPicker
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingWeekPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Month Selection Modal
            showingMonthPicker ? AnyView(
                MonthPickerModal(
                    selectedMonth: Binding(
                        get: { calendarHelper.currentDate },
                        set: { newDate in
                            calendarHelper.setDate(newDate)
                        }
                    ),
                    isPresented: $showingMonthPicker
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingMonthPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Date Selection Modal
            showingDatePicker ? AnyView(
                DatePickerModal(
                    selectedDate: $selectedProgressDate,
                    isPresented: $showingDatePicker
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingDatePicker)
            ) : AnyView(EmptyView())
        )
    }
    
    // MARK: - Habit Selector Header
    private var habitSelectorHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Progress")
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
            .padding(.horizontal, 16)
            
            // Time Period Tabs - Custom implementation to match Home/Habits tab behavior
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Button(action: {
                        selectedTimePeriod = index
                    }) {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(["Daily", "Weekly", "Monthly"][index])
                                    .font(.appTitleSmallEmphasised)
                                    .foregroundColor(selectedTimePeriod == index ? .text03 : .text04)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .overlay(
                                // Bottom stroke - only show for selected tabs
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(.text03)
                                        .frame(height: 4)
                                }
                                .opacity(selectedTimePeriod == index ? 1 : 0)
                            )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Spacer to push tabs to the left
                Spacer()
                
                // Additional spacer on the right
                Spacer()
            }
            .background(Color.white)
            .overlay(
                // Bottom stroke for the entire tab bar
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.outline3)
                        .frame(height: 1)
                }
            )
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
            .padding(.horizontal, 16)
            
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
    
    // MARK: - Weekly Progress Helper Methods
    private func getWeeklyCompletedHabitsCount() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return habits.filter { habit in
            // Check if this habit has any completions during the week
            let hasWeeklyCompletions = habit.completionHistory.contains { keyValue in
                let dateString = keyValue.key
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                if let completionDate = dateFormatter.date(from: dateString) {
                    return completionDate >= weekStart && completionDate <= today
                }
                return false
            }
            
            // If habit has completions, check if it meets the weekly goal
            if hasWeeklyCompletions {
                let weeklyCompletions = habit.completionHistory.filter { keyValue in
                    let dateString = keyValue.key
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    if let completionDate = dateFormatter.date(from: dateString) {
                        return completionDate >= weekStart && completionDate <= today
                    }
                    return false
                }
                
                let totalWeeklyProgress = weeklyCompletions.values.reduce(0, +)
                let weeklyGoal = ProgressCalculationHelper.parseGoalAmount(from: habit.goal) * 7 // Weekly goal (daily goal × 7)
                return totalWeeklyProgress >= weeklyGoal
            }
            
            return false
        }.count
    }
    
    private func getWeeklyTotalHabitsCount() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        return habits.reduce(0) { total, habit in
            let startDate = habit.startDate
            let endDate = habit.endDate ?? weekEnd
            
            // Check if habit is active during this week
            if startDate <= weekEnd && endDate >= weekStart {
                // Count days in the week where this habit should be active
                var count = 0
                var currentDate = weekStart
                
                while currentDate <= weekEnd {
                    if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                        count += 1
                    }
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
                
                return total + count
            }
            return total
        }
    }
    
    private func getWeeklyCompletionPercentage() -> Double {
        let total = getWeeklyTotalHabitsCount()
        guard total > 0 else { return 0.0 }
        return Double(getWeeklyCompletedHabitsCount()) / Double(total)
    }
    
    // Get day progress for a specific date
    private func getDayProgress(for date: Date) -> Double {
        return ProgressCalculationHelper.getDayProgress(
            for: date,
            habits: habits,
            selectedHabitType: .formation,
            selectedHabit: selectedHabit
        )
    }
    
    // MARK: - Monthly Calendar Section
    private var monthlyCalendarSection: some View {
        VStack(spacing: 8) {
            // Calendar header with month/year and Today button
            HStack {
                HStack(spacing: 4) {
                    Text(calendarHelper.monthYearString())
                        .font(.appTitleMedium)
                        .foregroundColor(.text01)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .opacity(0.7)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingMonthPicker = true
                }
                
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
        .background(Color.surface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.outline3, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - All Reminders View
struct AllRemindersView: View {
    let habits: [Habit]
    let coreDataAdapter: CoreDataAdapter
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with close button, title, and description
                VStack(spacing: 16) {
                    // Close button
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.text03)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.outline3.opacity(0.1))
                                )
                        }
                        
                        Spacer()
                    }
                    
                    // Title
                    Text("All Reminders")
                        .font(.appHeadlineSmallEmphasised)
                        .foregroundColor(.text01)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Description
                    Text("Manage all your habit reminders")
                        .font(.appTitleSmall)
                        .foregroundColor(.text05)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                // Reminders list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(habits, id: \.id) { habit in
                            if !habit.reminders.isEmpty {
                                VStack(spacing: 12) {
                                    // Habit header
                                    HStack {
                                        HStack(spacing: 12) {
                                            // Habit icon
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(habit.color.opacity(0.15))
                                                    .frame(width: 30, height: 30)
                                                
                                                if habit.icon.hasPrefix("Icon-") {
                                                    Image(habit.icon)
                                                        .resizable()
                                                        .frame(width: 16, height: 16)
                                                        .foregroundColor(habit.color)
                                                } else if habit.icon == "None" {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.outline3)
                                                        .frame(width: 12, height: 12)
                                                } else {
                                                    Text(habit.icon)
                                                        .font(.system(size: 14))
                                                }
                                            }
                                            
                                            Text(habit.name)
                                                .font(.appTitleSmallEmphasised)
                                                .foregroundColor(.text01)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(habit.reminders.count) reminder\(habit.reminders.count == 1 ? "" : "s")")
                                            .font(.appBodySmall)
                                            .foregroundColor(.text03)
                                    }
                                    
                                    // Reminders for this habit
                                    VStack(spacing: 8) {
                                        ForEach(habit.reminders, id: \.id) { reminder in
                                            ReminderRowView(
                                                reminder: reminder,
                                                habit: habit,
                                                coreDataAdapter: coreDataAdapter
                                            )
                                        }
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(habit.color.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Reminder Row View
struct ReminderRowView: View {
    let reminder: ReminderItem
    let habit: Habit
    let coreDataAdapter: CoreDataAdapter
    
    var body: some View {
        HStack(spacing: 12) {
            // Time icon
            ZStack {
                Circle()
                    .fill(habit.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(habit.color)
            }
            
            // Time and status
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(reminder.time))
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.text01)
                
                Text(reminder.isActive ? "Active" : "Inactive")
                    .font(.appBodySmall)
                    .foregroundColor(reminder.isActive ? .green : .text03)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { reminder.isActive },
                set: { newValue in
                    toggleReminder(reminder, in: habit)
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: habit.color))
            .scaleEffect(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(reminder.isActive ? habit.color.opacity(0.05) : Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    reminder.isActive ? habit.color.opacity(0.2) : Color.outline3.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    private func toggleReminder(_ reminder: ReminderItem, in habit: Habit) {
        // Create a new Habit instance with updated reminders
        let updatedReminders = habit.reminders.map { existingReminder in
            if existingReminder.id == reminder.id {
                // Create a new ReminderItem with toggled isActive status
                return ReminderItem(
                    time: existingReminder.time,
                    isActive: !existingReminder.isActive
                )
            }
            return existingReminder
        }
        
        // Create a new Habit instance with the updated reminders
        let updatedHabit = Habit(
            id: habit.id,
            name: habit.name,
            description: habit.description,
            icon: habit.icon,
            color: habit.color,
            habitType: habit.habitType,
            schedule: habit.schedule,
            goal: habit.goal,
            reminder: habit.reminder,
            startDate: habit.startDate,
            endDate: habit.endDate,
            isCompleted: habit.isCompleted,
            streak: habit.streak,
            createdAt: habit.createdAt,
            reminders: updatedReminders,
            baseline: habit.baseline,
            target: habit.target,
            completionHistory: habit.completionHistory,
            actualUsage: habit.actualUsage
        )
        
        // Update the habit in Core Data
        coreDataAdapter.updateHabit(updatedHabit)
    }
}

#Preview {
    ProgressTabView(habits: [])
        .environmentObject(CoreDataAdapter.shared)
} 




