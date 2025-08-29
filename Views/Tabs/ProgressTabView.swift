import SwiftUI

struct ProgressTabView: View {
    // MARK: - State
    @State private var selectedTimePeriod = 0
    @State private var selectedHabit: Habit?
    @State private var selectedProgressDate = Date()
    @State private var showingHabitSelector = false
    @State private var showingDatePicker = false
    @State private var showingWeekPicker = false
    @State private var showingYearPicker = false
    @State private var selectedWeekStartDate: Date = Date()
    
    // MARK: - Environment
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    
    // MARK: - Computed Properties
    private var habits: [Habit] {
        coreDataAdapter.habits
    }
    
    var body: some View {
        ZStack {
            WhiteSheetContainer(
            headerContent: {
                AnyView(
                    VStack(spacing: 0) {
                        // First Filter - Habit Selection
                        HStack {
                            Button(action: {
                                showingHabitSelector = true
                            }) {
                                HStack(spacing: 8) {
                                    Text(selectedHabit?.name ?? "All habits")
                                        .font(.appTitleMediumEmphasised)
                                        .foregroundColor(.onPrimaryContainer)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.onPrimaryContainer)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Second Filter - Period Selection
                        UnifiedTabBarView(
                            tabs: [
                                TabItem(title: "Daily"),
                                TabItem(title: "Weekly"),
                                TabItem(title: "Yearly")
                            ],
                            selectedIndex: selectedTimePeriod,
                            style: .underline,
                            expandToFullWidth: true
                        ) { index in
                            selectedTimePeriod = index
                            // Haptic feedback
                            let impactFeedback = UISelectionFeedbackGenerator()
                            impactFeedback.selectionChanged()
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 0)
                    }
                )
            }
        ) {
            // Content area
            ScrollView {
                    VStack(spacing: 20) {
                        // Third Filter - Date Selection (only for Daily/Weekly/Yearly)
                        if selectedTimePeriod == 0 || selectedTimePeriod == 1 || selectedTimePeriod == 2 {
                            HStack {
                                Button(action: {
                                    print("🔍 DEBUG: Date button tapped! selectedTimePeriod: \(selectedTimePeriod)")
                                    if selectedTimePeriod == 0 { // Daily
                                        showingDatePicker = true
                                    } else if selectedTimePeriod == 1 { // Weekly
                                        showingWeekPicker = true
                                    } else if selectedTimePeriod == 2 { // Yearly
                                        showingYearPicker = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text(selectedTimePeriod == 0 ? formatDate(selectedProgressDate) :
                                             selectedTimePeriod == 1 ? formatWeek(selectedWeekStartDate) :
                                             formatYear(selectedProgressDate))
                                            .font(.appBodyMedium)
                                            .foregroundColor(.text01)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.text02)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.outline3, lineWidth: 1)
                                            )
                                    )
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Today's Progress Card - Only show when "All habits" is selected and "Daily" tab is active
                        if selectedHabit == nil && selectedTimePeriod == 0 {
                            VStack(alignment: .leading, spacing: 20) {
                                // Today's Progress Card
                                HStack(spacing: 20) {
                                    // Left side: Text content (vertically centered)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Today's Progress")
                                            .font(.appTitleMediumEmphasised)
                                            .foregroundColor(.onPrimaryContainer)
                                        
                                        Text("\(getCompletedHabitsCount()) of \(getScheduledHabitsCount()) habits completed")
                                            .font(.appBodySmall)
                                            .foregroundColor(.primaryFocus)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Right side: Progress ring (vertically centered)
                                    ProgressChartComponents.CircularProgressRing(
                                        progress: getProgressPercentage(),
                                        size: 52
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    Image("Light-gradient-BG@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipped()
                                        .allowsHitTesting(false)  // ← FIXED: Prevents touch interference
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Reminders Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack {
                                Text("Reminders")
                                    .font(.appTitleMediumEmphasised)
                                    .foregroundColor(.onPrimaryContainer)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Reminders Carousel
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<5) { index in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: "bell.fill")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primaryFocus)
                                                
                                                Spacer()
                                                
                                                Text("9:00 AM")
                                                    .font(.appBodySmall)
                                                    .foregroundColor(.text02)
                                            }
                                            
                                            Text("Morning Routine")
                                                .font(.appBodyMedium)
                                                .foregroundColor(.onPrimaryContainer)
                                                .lineLimit(2)
                                            
                                            Text("Daily")
                                                .font(.appBodySmall)
                                                .foregroundColor(.text02)
                                        }
                                        .padding(16)
                                        .frame(width: 160)
                                        .background(Color.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Difficulty Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack {
                                Text("Difficulty")
                                    .font(.appTitleMediumEmphasised)
                                    .foregroundColor(.onPrimaryContainer)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Difficulty Cards
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<3) { index in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: index == 0 ? "1.circle.fill" : index == 1 ? "2.circle.fill" : "3.circle.fill")
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(index == 0 ? .green : index == 1 ? .orange : .red)
                                            
                                                Spacer()
                                                
                                                Text("\(index + 1)")
                                                    .font(.appBodySmall)
                                                    .foregroundColor(.text02)
                                            }
                                            
                                            Text(index == 0 ? "Easy" : index == 1 ? "Medium" : "Hard")
                                                .font(.appBodyMedium)
                                                .foregroundColor(.onPrimaryContainer)
                                                .lineLimit(2)
                                            
                                            Text("\(Int.random(in: 1...5)) habits")
                                                .font(.appBodySmall)
                                                .foregroundColor(.text02)
                                        }
                                        .padding(16)
                                        .frame(width: 140)
                                        .background(Color.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Bottom spacing
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .sheet(isPresented: $showingHabitSelector) {
                HabitSelectorView(
                    selectedHabit: $selectedHabit
                )
            }
            
            // Overlay for modals
            if showingDatePicker {
                DatePickerModal(
                    selectedDate: $selectedProgressDate,
                    isPresented: $showingDatePicker
                )
            }
            
            if showingWeekPicker {
                WeekPickerModal(
                    selectedWeekStartDate: $selectedWeekStartDate,
                    isPresented: $showingWeekPicker
                )
                .onChange(of: selectedWeekStartDate) { _, newValue in
                    selectedProgressDate = newValue
                }
            }
            
            if showingYearPicker {
                YearPickerModal(
                    selectedYear: Binding(
                        get: { Calendar.current.component(.year, from: selectedProgressDate) },
                        set: { newYear in
                            let calendar = Calendar.current
                            let currentComponents = calendar.dateComponents([.month, .day], from: selectedProgressDate)
                            var newComponents = DateComponents()
                            newComponents.year = newYear
                            newComponents.month = currentComponents.month ?? 1
                            newComponents.day = currentComponents.day ?? 1
                            selectedProgressDate = calendar.date(from: newComponents) ?? selectedProgressDate
                        }
                    ),
                    isPresented: $showingYearPicker
                )
            }
        }
    }
    
    // MARK: - Helper Functions for Dynamic Content
    private func getPeriodText() -> String {
        switch selectedTimePeriod {
        case 0: return "daily"
        case 1: return "weekly"
        case 2: return "yearly"
        default: return "daily"
        }
    }
    
    private func getHabitText() -> String {
        return selectedHabit?.name ?? "all habits"
    }
    
    private func getDateText() -> String {
        switch selectedTimePeriod {
        case 0: // Daily
            return "on \(formatDate(selectedProgressDate))"
        case 1: // Weekly
            return "for \(formatWeek(selectedWeekStartDate))"
        case 2: // Yearly
            return "for \(Calendar.current.component(.year, from: selectedProgressDate))"
        default:
            return "on \(formatDate(selectedProgressDate))"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatWeek(_ date: Date) -> String {
        // Use the same calendar and calculation as WeekPickerModal
        let calendar = AppDateFormatter.shared.getUserCalendar()
        
        // Get the start of the week using user's preference
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        
        // Get the end of the week by adding 6 days (same as WeekPickerModal)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        // Format both dates using the same format as WeekPickerModal
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStart)
        let endString = formatter.string(from: weekEnd)
        
        return "\(startString) - \(endString)"
    }
    
    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Progress Calculation Functions
    private func getScheduledHabitsCount() -> Int {
        let scheduledHabits = coreDataAdapter.habits.filter { habit in
            // Only count habits that are scheduled for the selected date
            return StreakDataCalculator.shouldShowHabitOnDate(habit, date: selectedProgressDate)
        }
        
        return scheduledHabits.count
    }
    
    private func getCompletedHabitsCount() -> Int {
        let scheduledHabits = getScheduledHabitsForDate(selectedProgressDate)
        let completedHabits = scheduledHabits.filter { habit in
            // Check if the habit is completed for the selected date
            let progress = coreDataAdapter.getProgress(for: habit, date: selectedProgressDate)
            return progress > 0
        }
        
        return completedHabits.count
    }
    
    private func getProgressPercentage() -> Double {
        let scheduledCount = getScheduledHabitsCount()
        guard scheduledCount > 0 else { return 0.0 }
        
        let completedCount = getCompletedHabitsCount()
        return Double(completedCount) / Double(scheduledCount)
    }
    
    // MARK: - Progress Subtitle Functions
    private func parseGoalAmount(from goalString: String) -> Int {
        // Extract numeric value from goal string (e.g., "3 times" -> 3)
        let numbers = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        return numbers.first ?? 1
    }
    
    private func getProgressSubtitle() -> String {
        let scheduledCount = getScheduledHabitsCount()
        let completedCount = getCompletedHabitsCount()
        
        if scheduledCount == 0 {
            return "No habits scheduled for today"
        } else if completedCount == scheduledCount {
            return "All habits completed! 🎉"
        } else if completedCount > 0 {
            let percentage = Int(getProgressPercentage() * 100)
            if percentage >= 80 {
                return "Great progress! Almost there! 💪"
            } else if percentage >= 50 {
                return "Good progress! Keep going! 🔥"
            } else if percentage > 0 {
                return "Getting started! Every step counts! 🌱"
            } else {
                return "Ready to start your habits! 🚀"
            }
        } else {
            return "Ready to start your habits! 🚀"
        }
    }
    
    // MARK: - Helper Functions for Scheduled Habits
    private func getScheduledHabitsForDate(_ date: Date) -> [Habit] {
        return coreDataAdapter.habits.filter { habit in
            return StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
        }
    }
}

// MARK: - Date Extension
extension Date {
    func get(_ component: Calendar.Component) -> Int {
        return Calendar.current.component(component, from: self)
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(CoreDataAdapter.shared)
}