import SwiftUI
import CoreData

struct ProgressTabView: View {
    let habits: [Habit]
    
    @EnvironmentObject private var coreDataAdapter: CoreDataAdapter
    @State private var selectedTimePeriod = 0
    @State private var selectedHabit: Habit?
    @State private var selectedProgressDate = Date()
    @State private var showingHabitSelector = false
    @State private var showingMonthPicker = false
    
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Habit Selector Header
                    habitSelectorHeader
                    
                    // Tab Content
                    if selectedTimePeriod == 0 {
                        // Daily Tab
                        dailyProgressSection
                    } else if selectedTimePeriod == 1 {
                        // Weekly Tab
                        weeklyProgressSection
                    } else {
                        // Monthly Tab
                        monthlyProgressSection
                    }
                }
                .padding(.top, 20)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingHabitSelector) {
                HabitSelectorView(
                    selectedHabit: $selectedHabit
                )
            }
        }
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
            
            // Time Period Tabs
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
                
                Spacer()
                Spacer()
            }
            .background(Color.white)
            .overlay(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.outline3)
                        .frame(height: 1)
                }
            )
        }
    }
    
    // MARK: - Daily Progress Section
    private var dailyProgressSection: some View {
        VStack(spacing: 20) {
            // Conditional Logic: Only show progress card when no habit is selected OR when selected habit is scheduled for the date
            if selectedHabit == nil || shouldShowHabitOnDate(selectedHabit!, date: selectedProgressDate) {
                // Today's Progress Summary
                dailyProgressCard
                    .padding(.bottom, 16)
                
                // New Reminders Section
                remindersSection
                
                // New Difficulty Section
                difficultySection
            } else {
                // Show empty state when habit is selected but not scheduled for this date
                VStack(spacing: 16) {
                    // Cute calendar icon with soft background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.primaryContainer.opacity(0.3),
                                        Color.primaryContainer.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Not scheduled for today")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .multilineTextAlignment(.center)
                        
                        Text("This habit isn't scheduled for the selected date. Try selecting a different date or choose a different habit.")
                            .font(.appBodyMedium)
                            .foregroundColor(.text03)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Daily Progress Card
    private var dailyProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.appTitleSmallEmphasised)
                        .foregroundColor(.text01)
                    
                    Text("\(getTodaysCompletedHabitsCount()) of \(getTodaysTotalHabitsCount()) habits completed")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                }
                
                Spacer()
                
                // Daily progress ring
                dailyProgressRing
            }
            .padding(20)
            .background(
                Image("Light-gradient-BG@4x")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.outline3, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Daily Progress Ring
    private var dailyProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.outline3.opacity(0.3), lineWidth: 8)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: getTodaysProgressPercentage())
                .stroke(
                    LinearGradient(
                        colors: [Color.primary, Color.primaryContainer],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: getTodaysProgressPercentage())
            
            Text("\(Int(getTodaysProgressPercentage() * 100))%")
                .font(.appLabelMedium)
                .foregroundColor(.text01)
        }
    }
    
    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Reminders")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("See more >") {
                    // TODO: Navigate to reminders view
                }
                .font(.appBodySmall)
                .foregroundColor(.text07)
            }
            .padding(.horizontal, 20)
            
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let todaysReminders = getTodaysReminders()
                    
                    if todaysReminders.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.outline3.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.text03)
                            }
                            
                            Text("No reminders today")
                                .font(.appBodySmall)
                                .foregroundColor(.text03)
                                .lineLimit(1)
                        }
                        .frame(width: 141, height: 114)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.outline3, lineWidth: 1)
                                )
                        )
                    } else {
                        ForEach(todaysReminders, id: \.id) { reminder in
                            reminderCard(for: reminder)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Reminder Card
    private func reminderCard(for reminder: ReminderDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit icon
            ZStack {
                Circle()
                    .fill(reminder.habit.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                if reminder.habit.icon.hasPrefix("Icon-") {
                    Image(reminder.habit.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(reminder.habit.color)
                } else if reminder.habit.icon == "None" {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.outline3)
                        .frame(width: 12, height: 12)
                } else {
                    Text(reminder.habit.icon)
                        .font(.system(size: 14))
                }
            }
            
            // Habit name
            Text(reminder.habitName)
                .font(.appBodyMediumEmphasised)
                .foregroundColor(.text01)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Time row with toggle
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.text03)
                    
                    Text(reminder.formattedTime)
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { reminder.reminder.isActive },
                    set: { _ in toggleReminder(reminder) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: reminder.habit.color))
                .scaleEffect(0.8)
            }
        }
        .frame(width: 141, height: 114, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Difficulty Section
    private var difficultySection: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Difficulty")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                Button("See more >") {
                    // TODO: Navigate to difficulty view
                }
                .font(.appBodySmall)
                .foregroundColor(.text07)
            }
            .padding(.horizontal, 20)
            
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let difficulties = getDifficultiesForSelectedDate()
                    
                    if difficulties.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.outline3.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.text03)
                            }
                            
                            Text("No difficulty data")
                                .font(.appBodySmall)
                                .foregroundColor(.text03)
                                .lineLimit(1)
                        }
                        .frame(width: 141, height: 114)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.outline3, lineWidth: 1)
                                )
                        )
                    } else {
                        ForEach(difficulties, id: \.id) { difficulty in
                            difficultyCard(for: difficulty)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.top, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Difficulty Card
    private func difficultyCard(for difficulty: TodaysDifficulty) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Habit icon
            ZStack {
                Circle()
                    .fill(difficulty.habit.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                if difficulty.habit.icon.hasPrefix("Icon-") {
                    Image(difficulty.habit.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(difficulty.habit.color)
                } else if difficulty.habit.icon == "None" {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.outline3)
                        .frame(width: 12, height: 12)
                } else {
                    Text(difficulty.habit.icon)
                        .font(.system(size: 14))
                }
            }
            
            // Habit name
            Text(difficulty.habitName)
                .font(.appBodyMediumEmphasised)
                .foregroundColor(.text01)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Difficulty row
            HStack {
                HStack(spacing: 8) {
                    difficultyImageView(for: difficulty.difficultyLevel)
                    
                    Text(difficulty.difficultyText)
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.text03)
                    
                    Text(difficulty.completionTime)
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 141, height: 114, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Weekly Progress Section
    private var weeklyProgressSection: some View {
        VStack(spacing: 20) {
            // Weekly progress content
            Text("Weekly Progress")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Monthly Progress Section
    private var monthlyProgressSection: some View {
        VStack(spacing: 20) {
            // Monthly progress content
            Text("Monthly Progress")
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Functions
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        // TODO: Implement proper logic to check if habit is scheduled for the given date
        return true // Placeholder - implement actual logic
    }
    
    private func getTodaysCompletedHabitsCount() -> Int {
        // Count only habits that are scheduled for today AND were completed
        return habits.filter { habit in
            // Check if habit is scheduled for today
            let isScheduledToday = shouldShowHabitOnDate(habit, date: selectedProgressDate)
            
            // Check if habit was completed today
            let dateKey = DateUtils.dateKey(for: selectedProgressDate)
            let wasCompleted = (habit.completionHistory[dateKey] ?? 0) > 0
            
            return isScheduledToday && wasCompleted
        }.count
    }
    
    private func getTodaysTotalHabitsCount() -> Int {
        // Count only habits that are scheduled for today
        return habits.filter { habit in
            shouldShowHabitOnDate(habit, date: selectedProgressDate)
        }.count
    }
    
    private func getTodaysProgressPercentage() -> Double {
        let total = getTodaysTotalHabitsCount()
        guard total > 0 else { return 0.0 }
        return Double(getTodaysCompletedHabitsCount()) / Double(total)
    }
    
    private func getTodaysReminders() -> [ReminderDisplayItem] {
        // TODO: Implement actual logic
        return [] // Placeholder
    }
    
    private func getDifficultiesForSelectedDate() -> [TodaysDifficulty] {
        // TODO: Implement actual logic
        return [] // Placeholder
    }
    
    private func toggleReminder(_ reminder: ReminderDisplayItem) {
        // TODO: Implement actual logic
    }
    
    private func difficultyImageView(for level: DifficultyLevel) -> some View {
        // TODO: Implement actual logic
        Image(systemName: "chart.line.downtrend.xyaxis")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.text03)
    }
}

// MARK: - Supporting Types
struct ReminderDisplayItem {
    let id = UUID()
    let habit: Habit
    let habitName: String
    let formattedTime: String
    let reminder: ReminderItem
}

struct TodaysDifficulty {
    let id = UUID()
    let habit: Habit
    let habitName: String
    let difficultyLevel: DifficultyLevel
    let difficultyText: String
    let completionTime: String
}

enum DifficultyLevel {
    case easy, medium, hard
}

// MARK: - Preview
#Preview {
    ProgressTabView(habits: [])
        .environmentObject(CoreDataAdapter.shared)
} 




