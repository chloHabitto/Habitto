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
        WhiteSheetContainer(
            headerContent: {
                AnyView(
        VStack(spacing: 0) {
                        // Filter Header
                        VStack(spacing: 16) {
            HStack {
                                // Dynamic Title/Filter
                Button(action: {
                                    showingHabitSelector = true
                }) {
                    HStack(spacing: 8) {
                                        Text(selectedHabit?.name ?? "All habits")
                            .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                                        Image(systemName: "chevron.down")
                                                .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.onPrimaryContainer)
                                    }
        }
        .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 16)
                            .padding(.top, 12)
                            
                            // Period Filter Tabs
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                                    VStack(spacing: 2) {
                    Button(action: {
                                            // Haptic feedback when switching tabs
                                            UISelectionFeedbackGenerator().selectionChanged()
                        selectedTimePeriod = index
                    }) {
                            HStack(spacing: 4) {
                                                Text(["Daily", "Weekly", "Yearly"][index])
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
                                                .opacity(selectedTimePeriod == index ? 1 : 0) // Only show stroke for selected tabs
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                                    }
                                    .animation(nil, value: selectedTimePeriod == index)
                }
                
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
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 20) {
                    // Third Filter - Date Selection (Daily, Weekly, and Yearly)
                    if selectedTimePeriod == 0 || selectedTimePeriod == 1 || selectedTimePeriod == 2 { // Daily, Weekly, or Yearly tab
            HStack {
                            // Date Selection Button
                            Button(action: {
                                print("🔍 DEBUG: Button action triggered! selectedTimePeriod: \(selectedTimePeriod)")
                                // Handle tap based on period
                                if selectedTimePeriod == 0 { // Daily
                                    print("🔍 DEBUG: Setting showingDatePicker to true")
                                    showingDatePicker = true
                                    print("🔍 DEBUG: showingDatePicker is now: \(showingDatePicker)")
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
                            .buttonStyle(PlainButtonStyle())
                
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
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Dynamic Content based on both filters
        VStack(spacing: 16) {
                        Text("Progress Content")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                        
                        Text("This is a \(getPeriodText()) progress about \(getHabitText()) \(getDateText())")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 40)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingHabitSelector) {
            HabitSelectorView(
                selectedHabit: $selectedHabit
            )
        }
        .overlay(
            ZStack {
                if showingDatePicker {
                    print("🔍 DEBUG: Overlay showing DatePickerModal")
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
        )
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
            return "for \(selectedProgressDate.get(.year))"
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
    
    // MARK: - Progress Card Helper Functions
    
    /// Get the count of scheduled habits for the selected date
    private func getScheduledHabitsCount() -> Int {
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: selectedProgressDate)
        }.count
    }
    
    /// Get the count of completed habits for the selected date
    private func getCompletedHabitsCount() -> Int {
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: selectedProgressDate) && 
            habit.isCompleted(for: selectedProgressDate)
        }.count
    }
    
    /// Get the actual progress percentage (0.0 to 1.0) based on progress, not just completion
    private func getProgressPercentage() -> Double {
        let scheduledHabits = getScheduledHabitsForDate(selectedProgressDate)
        if scheduledHabits.isEmpty { return 0.0 }
        
        var totalProgress = 0.0
        var totalGoal = 0.0
        
        for habit in scheduledHabits {
            let goalAmount = parseGoalAmount(from: habit.goal)
            let progress = habit.getProgress(for: selectedProgressDate)
            
            totalGoal += Double(goalAmount)
            totalProgress += Double(progress)
        }
        
        return totalGoal > 0 ? min(totalProgress / totalGoal, 1.0) : 0.0
    }
    
    /// Parse goal amount from goal string (e.g., "8 times per day" -> 8)
    private func parseGoalAmount(from goalString: String) -> Int {
        let components = goalString.lowercased().components(separatedBy: " ")
        for component in components {
            if let amount = Int(component), amount > 0 {
                return amount
            }
        }
        return 1 // Default to 1 if no number found
    }
    
    /// Get a motivational subtitle based on progress
    private func getProgressSubtitle() -> String {
        let percentage = getProgressPercentage()
        let scheduledCount = getScheduledHabitsCount()
        
        if scheduledCount == 0 {
            return "No habits scheduled for this date"
        }
        
        if percentage == 1.0 {
            return "Perfect! All habits completed! 🎉"
        } else if percentage >= 0.8 {
            return "Great progress! Almost there! 💪"
        } else if percentage >= 0.5 {
            return "Good progress! Keep going! ✨"
        } else if percentage > 0 {
            return "Getting started! Every step counts! 🌱"
                                                } else {
            return "Ready to start your habits! 🚀"
        }
    }
    

    
    /// Get scheduled habits for a specific date
    private func getScheduledHabitsForDate(_ date: Date) -> [Habit] {
        return habits.filter { habit in
            StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
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




