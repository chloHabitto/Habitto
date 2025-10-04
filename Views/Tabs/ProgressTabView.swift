import SwiftUI

// MARK: - HabitDifficulty Enum
enum HabitDifficulty: Int, CaseIterable {
        case veryEasy = 1
        case easy = 2
        case medium = 3
        case hard = 4
        case veryHard = 5
        
        var displayName: String {
            switch self {
            case .veryEasy: return "Very Easy"
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            case .veryHard: return "Very Hard"
        }
    }
    
    var color: Color {
        switch self {
        case .veryEasy: return .green
        case .easy: return .mint
        case .medium: return .orange
        case .hard: return .red
        case .veryHard: return .purple
        }
    }
}

// MARK: - Difficulty Arc View
struct DifficultyArcView: View {
    let currentDifficulty: Double
    let size: CGFloat
    
    private var difficultyLevel: HabitDifficulty {
        let roundedValue = Int(round(currentDifficulty))
        return HabitDifficulty(rawValue: roundedValue) ?? .medium
    }
    
    var body: some View {
        ZStack {
            // Background arc - horizontal half-donut from left to right
            Arc(startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                .stroke(Color.outline3.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: size, height: size)
            
            // Difficulty segments - equal length with visible gaps (spanning exactly 180°)
            ForEach(0..<5) { index in
                let startAngle = 180.0 + Double(index) * 36.0
                let endAngle = startAngle + 36.0
                
                Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: false)
                    .stroke(
                        index < difficultyLevel.rawValue ? difficultyLevel.color : Color.outline3.opacity(0.3),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Arc Shape
struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        
        return path
    }
}

struct ProgressTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    // MARK: - State
    @State private var selectedTimePeriod = 0
    @State private var selectedHabit: Habit?
    @State private var selectedProgressDate = Date()
    @State private var showingHabitSelector = false
    @State private var showingDatePicker = false
    @State private var showingWeekPicker = false
    @State private var showingMonthPicker = false
    @State private var showingYearPicker = false
    @State private var selectedWeekStartDate: Date = {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let today = Date()
        return calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }()
    @State private var showingDifficultyExplanation = false
    @State private var testDifficultyValue: Double = 3.0
    @State private var showingAllReminders = false
    @State private var streakStatistics = StreakStatistics(currentStreak: 0, longestStreak: 0, totalCompletionDays: 0)
    @State private var currentHighlightPage = 0
    @State private var currentMonthlyHighlightPage = 0
    
    // Yearly view state variables
    @State private var yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] = []
    @State private var isDataLoaded: Bool = false
    @State private var isLoadingProgress: Double = 0.0
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // Per-date reminder states: [dateKey: [reminderId: isEnabled]]
    @State private var reminderStates: [String: [UUID: Bool]] = [:]
    
    
    // MARK: - Environment
    @EnvironmentObject var habitRepository: HabitRepository
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    
    // MARK: - Computed Properties
    private var habits: [Habit] {
        habitRepository.habits
    }
    
    private var headerContent: some View {
        VStack(spacing: 0) {
                        // First Filter - Habit Selection
            HStack {
                Button(action: {
                                showingHabitSelector = true
                }) {
                    HStack(spacing: 0) {
                                    Text(selectedHabit?.name ?? "All habits")
                            .font(.appTitleMediumEmphasised)
                            .lineSpacing(8)
                                        .foregroundColor(.text02)
                        
                        Image("Icon-arrowDropDown_Filled")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.text04)
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
                    TabItem(title: "Monthly"),
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
            .padding(.top, 16)
                        .padding(.bottom, 0)
                    }
    }
    
    // MARK: - Weekly Content Views
    
    @ViewBuilder
    private var weeklyAllHabitsContent: some View {
        if getActiveHabits().isEmpty {
            // Show empty state when no habits exist
            VStack(spacing: 20) {
                // Weekly Progress Card (still show this)
                weeklyProgressCard
                
                // Empty state instead of calendar grid and analysis card
                HabitEmptyStateView.noHabitsYet()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 20)
        } else {
            // Show normal content when habits exist
            VStack(spacing: 20) {
                // Weekly Progress Card
                weeklyProgressCard
                
                // Weekly Calendar Grid and Stats Container
                VStack(spacing: 0) {
                    // Weekly Calendar Grid
                    WeeklyCalendarGridView(
                        userHabits: getActiveHabits(),
                        selectedWeekStartDate: selectedWeekStartDate
                    )
                    
                    // Summary Statistics
                    WeeklySummaryStatsView(
                        completionRate: 0,
                        bestStreak: streakStatistics.longestStreak,
                        consistencyRate: 0
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .background(Color.grey50)
                .cornerRadius(24)
                
                // Weekly Analysis Card
                weeklyAnalysisCard
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var weeklyIndividualHabitContent: some View {
        VStack(spacing: 20) {
            // Weekly Difficulty Graph
            weeklyDifficultyGraph
            
            // Time Base Completion Chart
            timeBaseCompletionChart
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Monthly Content Views
    
    @ViewBuilder
    private var monthlyAllHabitsContent: some View {
        if getActiveHabitsForSelectedMonth().isEmpty {
            // Show empty state when no habits exist
            VStack(spacing: 20) {
                // Monthly Progress Card (still show this)
                monthlyProgressCard
                
                // Empty state instead of calendar grid
                HabitEmptyStateView.noHabitsYet()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 20)
        } else {
            // Show normal content when habits exist
            VStack(spacing: 20) {
                // Monthly Progress Card
                monthlyProgressCard
                
                // Monthly Calendar Grid
                MonthlyCalendarGridView(
                    userHabits: getActiveHabitsForSelectedMonth(),
                    selectedMonth: selectedProgressDate
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var monthlyIndividualHabitContent: some View {
        VStack(spacing: 20) {
            // Monthly Difficulty Graph
            monthlyDifficultyGraph
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Yearly Content Views
    
    @ViewBuilder
    private var yearlyAllHabitsContent: some View {
        if getActiveHabits().isEmpty {
            // Show empty state when no habits exist
            VStack(spacing: 20) {
                // Empty state for yearly view
                HabitEmptyStateView.noHabitsYet()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 20)
        } else {
            // Show normal content when habits exist
            VStack(spacing: 20) {
                // Yearly Calendar Grid
                YearlyCalendarGridView(
                    userHabits: getActiveHabits(),
                    selectedWeekStartDate: selectedWeekStartDate,
                    yearlyHeatmapData: yearlyHeatmapData,
                    isDataLoaded: isDataLoaded,
                    isLoadingProgress: isLoadingProgress,
                    selectedYear: selectedYear
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var yearlyIndividualHabitContent: some View {
        VStack(spacing: 20) {
            // Yearly Calendar Grid for individual habit
            YearlyCalendarGridView(
                userHabits: [selectedHabit!],
                selectedWeekStartDate: selectedWeekStartDate,
                yearlyHeatmapData: yearlyHeatmapData,
                isDataLoaded: isDataLoaded,
                isLoadingProgress: isLoadingProgress,
                selectedYear: selectedYear
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Reminders Section
    
    @ViewBuilder
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Reminders")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                
                Button(action: {
                    showingAllReminders = true
                }) {
                    HStack(spacing: 4) {
                        Text("See more")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.text02)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Reminders Carousel - Only show active reminders
            if getActiveRemindersForDate(selectedProgressDate).isEmpty {
                // Empty state when no reminders
                VStack(spacing: 16) {
                    Image("Today-Habit-List-Empty-State@4x")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                    
                    VStack(spacing: 4) {
                        Text("No reminders for today")
                            .font(.appTitleLargeEmphasised)
                            .foregroundColor(.text04)
                        
                        Text("You don't have any active reminders scheduled for this date")
                            .font(.appTitleSmall)
                            .foregroundColor(.text06)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 0)
                .padding(.bottom, 40)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(getActiveRemindersForDate(selectedProgressDate), id: \.id) { reminder in
                            reminderCard(for: reminder)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 20) {
            // Date Selection
            dateSelectionSection
            
            // Weekly Content - Only show when "All habits" is selected and "Weekly" tab is active
            if selectedHabit == nil && selectedTimePeriod == 1 {
                weeklyAllHabitsContent
            }
            
            // Weekly Content - Only show when individual habit is selected and "Weekly" tab is active
            if selectedHabit != nil && selectedTimePeriod == 1 {
                weeklyIndividualHabitContent
            }
            
            // Monthly Content - Only show when individual habit is selected and "Monthly" tab is active
            if selectedHabit != nil && selectedTimePeriod == 2 {
                monthlyIndividualHabitContent
            }
            
            // Monthly Content - Only show when "All habits" is selected and "Monthly" tab is active
            if selectedHabit == nil && selectedTimePeriod == 2 {
                monthlyAllHabitsContent
            }
            
            // Yearly Content - Only show when individual habit is selected and "Yearly" tab is active
            if selectedHabit != nil && selectedTimePeriod == 3 {
                yearlyIndividualHabitContent
            }
            
            // Yearly Content - Only show when "All habits" is selected and "Yearly" tab is active
            if selectedHabit == nil && selectedTimePeriod == 3 {
                yearlyAllHabitsContent
            }
            
            // Today's Progress Card - Show when "Daily" tab is active (both "All habits" and individual habits)
            if selectedTimePeriod == 0 {
                todayProgressCard
            }
            
            // Difficulty Section - Only show when individual habit is selected and scheduled for the date
            if selectedHabit != nil && selectedTimePeriod == 0 && getScheduledHabitsCount() > 0 {
                difficultySection
            }
            
            // Reminders Section - Only show when "All habits" is selected and "Daily" tab is active
            if selectedHabit == nil && selectedTimePeriod == 0 {
                remindersSection
            }
        }
    }
    
    var body: some View {
        ZStack {
            WhiteSheetContainer(
                headerContent: {
                    AnyView(headerContent)
                }
            ) {
                ScrollView {
                    mainContentView
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingHabitSelector) {
            habitSelectorSheet
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerModal(
                isPresented: $showingDatePicker,
                selectedDate: $selectedProgressDate
            ) { newDate in
                print("🔍 DEBUG: Date selected: \(newDate)")
                selectedProgressDate = newDate
            }
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerModal(selectedWeekStartDate: $selectedWeekStartDate, isPresented: $showingWeekPicker)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthPickerModal(selectedMonth: $selectedProgressDate, isPresented: $showingMonthPicker)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showingYearPicker) {
            YearPickerModal(selectedYear: $selectedYear, isPresented: $showingYearPicker)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        .overlay(
            // All Reminders Modal
            showingAllReminders ? AnyView(
                allRemindersModal
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingAllReminders)
            ) : AnyView(EmptyView())
        )
        .onAppear {
            // Calculate streak statistics when view appears
            updateStreakStatistics()
            
            // Load yearly data when view appears
            loadYearlyData()
            
        }
        .onChange(of: habitRepository.habits) {
            // Reload yearly data when habits change
            loadYearlyData()
        }
        .onChange(of: selectedWeekStartDate) {
            // Week changed - no action needed
        }
        .onChange(of: selectedYear) {
            // Reload yearly data when year changes
            loadYearlyData()
        }
    }
    
    
    // MARK: - Habit Selector Sheet
    private var habitSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                habitSelectorHeader
                allHabitsOption
                habitList
                Spacer()
            }
            .background(Color(.systemBackground))
        }
        .presentationDetents([.medium, .large])
    }
    
    private var habitSelectorHeader: some View {
                                            HStack {
            Text("Select Habit")
                .font(.appTitleLarge)
                .foregroundColor(.onPrimaryContainer)
            
            Spacer()
            
            Button("Done") {
                showingHabitSelector = false
            }
            .font(.appBodyMedium)
            .foregroundColor(.primaryFocus)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    private var allHabitsOption: some View {
        Button(action: {
            selectedHabit = nil
            showingHabitSelector = false
        }) {
            HStack(spacing: 16) {
                // All habits icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primaryFocus.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primaryFocus)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("All habits")
                        .font(.appTitleMedium)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("View progress for all habits")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
            }
            
            Spacer()
                                                
                if selectedHabit == nil {
                    ZStack {
                        Circle()
                                                    .fill(Color.primaryFocus)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                        Circle()
                        .stroke(Color.outline3.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedHabit == nil ? Color.primaryFocus.opacity(0.05) : Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedHabit == nil ? Color.primaryFocus.opacity(0.2) : Color.outline3.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var habitList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(habits, id: \.id) { habit in
                    habitOption(habit: habit)
                                    }
                                }
                                .padding(.horizontal, 20)
        }
    }
    
    private func habitOption(habit: Habit) -> some View {
        Button(action: {
            selectedHabit = habit
            showingHabitSelector = false
        }) {
            HStack(spacing: 16) {
                // Habit icon
                habitIcon(for: habit)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.appTitleMedium)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("View progress for this habit")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                }
                
                Spacer()
                
                if selectedHabit?.id == habit.id {
                    ZStack {
                        Circle()
                            .fill(habit.color)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Circle()
                        .stroke(Color.outline3.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        .background(
                            RoundedRectangle(cornerRadius: 16)
                    .fill(selectedHabit?.id == habit.id ? habit.color.opacity(0.05) : Color.surface)
            )
                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedHabit?.id == habit.id ? habit.color.opacity(0.2) : Color.outline3.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func habitIcon(for habit: Habit) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(habit.color.opacity(0.15))
                .frame(width: 48, height: 48)
            
            if habit.icon.hasPrefix("Icon-") {
                // Asset icon
                Image(habit.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(habit.color)
            } else if habit.icon == "None" {
                // No icon selected - show colored rounded rectangle
                RoundedRectangle(cornerRadius: 8)
                    .fill(habit.color)
                    .frame(width: 20, height: 20)
            } else {
                // Emoji or system icon
                Text(habit.icon)
                    .font(.system(size: 20))
            }
        }
    }
    
    private var difficultyCard: some View {
        let averageDifficulty = getAverageDifficultyForDate(selectedProgressDate)
        let difficultyInfo = getDifficultyLevel(from: averageDifficulty)
        
        return VStack(alignment: .leading, spacing: 16) {
                                // Header
                                HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Difficulty")
                            .font(.appTitleMediumEmphasised)
                                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("Based on your scheduled habits")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                }
                    
                    Spacer()
                                    
                VStack(alignment: .trailing, spacing: 4) {
                    Text(difficultyInfo.level.displayName)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(difficultyInfo.color)
                    
                    Text("Level \(difficultyInfo.level.rawValue)")
                            .font(.appBodySmall)
                                                .foregroundColor(.text02)
                                        }
                                    }
            
            // Difficulty arc and image
            HStack(spacing: 20) {
                // Half ring showing difficulty levels
                                    DifficultyArcView(
                    currentDifficulty: averageDifficulty,
                    size: 80
                )
                
                // Show image based on difficulty level
                Group {
                    switch difficultyInfo.level {
                    case .veryEasy:
                        Image("Difficulty-VeryEasy@4x")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 80)
                    case .easy:
                        Image("Difficulty-Easy@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    case .medium:
                        Image("Difficulty-Medium@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    case .hard:
                        Image("Difficulty-Hard@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    case .veryHard:
                        Image("Difficulty-VeryHard@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(getDifficultyMessage(for: difficultyInfo.level))
                                                .font(.appBodyMedium)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("Keep up the great work!")
                        .font(.appBodySmall)
                                                .foregroundColor(.text02)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
                                        .padding(.horizontal, 20)
    }
    
    // Date selection section
    private var dateSelectionSection: some View {
        Group {
            if selectedTimePeriod == 0 || selectedTimePeriod == 1 || selectedTimePeriod == 2 || selectedTimePeriod == 3 {
                HStack {
                                        Button(action: {
                        if selectedTimePeriod == 0 { // Daily
                            print("🔍 DEBUG: Date button tapped! selectedTimePeriod: \(selectedTimePeriod)")
                            print("🔍 DEBUG: Attempting to show DatePickerModal...")
                            showingDatePicker = true
                            print("🔍 DEBUG: DatePickerModal showing set to true")
                        } else if selectedTimePeriod == 1 { // Weekly
                            showingWeekPicker = true
                        } else if selectedTimePeriod == 2 { // Monthly
                            showingMonthPicker = true
                        } else if selectedTimePeriod == 3 { // Yearly
                            showingYearPicker = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            // Calendar icon
                            Image(.iconCalendar)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.primaryFocus)
                            
                            // Date text
                            Text(selectedTimePeriod == 0 ? formatDate(selectedProgressDate) :
                                 selectedTimePeriod == 1 ? formatWeek(selectedWeekStartDate) :
                                 selectedTimePeriod == 2 ? formatMonth(selectedProgressDate) :
                                 String(selectedYear))
                                .font(.appBodySmallEmphasised)
                                .foregroundColor(.primaryFocus)
                            
                            // Chevron icon
                            Image(.iconArrowDropDownFilled)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.primaryFocus)
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 12)
                                                .padding(.vertical, 8)
                                                .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.primaryContainer)
                        )
                    }
                    
                    // Spacer between date button and Today/This week/This month/This year button
                    if (selectedHabit == nil && selectedTimePeriod == 0 && !isTodaySelected) || 
                       (selectedHabit == nil && selectedTimePeriod == 1 && !isThisWeekSelected) ||
                       (selectedHabit == nil && selectedTimePeriod == 2 && !isThisMonthSelected) ||
                       (selectedHabit == nil && selectedTimePeriod == 3 && !isThisYearSelected) {
                        Spacer()
                    }
                    
                    // Today button - Only show when "All habits" is selected, Daily tab is active, and different date is selected
                    if selectedHabit == nil && selectedTimePeriod == 0 && !isTodaySelected {
                        Button(action: {
                            selectedProgressDate = Date()
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
                    
                    // This week button - Only show when "All habits" is selected, Weekly tab is active, and different week is selected
                    if selectedHabit == nil && selectedTimePeriod == 1 && !isThisWeekSelected {
                        Button(action: {
                            let calendar = AppDateFormatter.shared.getUserCalendar()
                            let today = Date()
                            selectedWeekStartDate = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
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
                    }
                    
                    // This month button - Only show when "All habits" is selected, Monthly tab is active, and different month is selected
                    if selectedHabit == nil && selectedTimePeriod == 2 && !isThisMonthSelected {
                        Button(action: {
                            selectedProgressDate = Date()
                        }) {
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
                    
                    // This year button - Only show when "All habits" is selected, Yearly tab is active, and different year is selected
                    if selectedHabit == nil && selectedTimePeriod == 3 && !isThisYearSelected {
                        Button(action: {
                            selectedYear = Calendar.current.component(.year, from: Date())
                        }) {
                            HStack(spacing: 4) {
                                Image(.iconReplay)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundColor(.primaryFocus)
                                Text("This year")
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
                    
                    // Spacer to push date button to the left when Today/This week/This month/This year button is not visible
                    if !((selectedHabit == nil && selectedTimePeriod == 0 && !isTodaySelected) || 
                        (selectedHabit == nil && selectedTimePeriod == 1 && !isThisWeekSelected) ||
                        (selectedHabit == nil && selectedTimePeriod == 2 && !isThisMonthSelected) ||
                        (selectedHabit == nil && selectedTimePeriod == 3 && !isThisYearSelected)) {
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // Today's progress section
    
    
    
    // Individual reminder card
    private func reminderCard(for reminderWithHabit: ReminderWithHabit) -> some View {
        let isEnabled = isReminderEnabled(for: reminderWithHabit.reminder, on: selectedProgressDate)
        let isTimePassed = isReminderTimePassed(for: reminderWithHabit.reminder, on: selectedProgressDate)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Top: Habit Icon
            HabitIconView(habit: reminderWithHabit.habit)
                .frame(width: 30, height: 30)
            
            // Middle: Habit Name
            Text(reminderWithHabit.habit.name)
                .font(.appBodyMedium)
                .foregroundColor(.onPrimaryContainer)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Bottom: Reminder Time with Toggle
            HStack {
                Text(formatReminderTime(reminderWithHabit.reminder.time))
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in toggleReminder(for: reminderWithHabit.reminder, on: selectedProgressDate) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .primaryFocus))
                .scaleEffect(0.6)
                .disabled(isTimePassed) // Disable toggle if time has passed
            }
        }
        .padding(16)
        .frame(width: 140, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date Selection
                dateSelectionSection
                
                
                // Difficulty Card - Only show when "All habits" is selected and "Daily" tab is active
                if selectedHabit == nil && selectedTimePeriod == 0 {
                    difficultyCard
                }
                
                // Individual Habit Progress - Show when a specific habit is selected
                if let selectedHabit = selectedHabit {
                    VStack(alignment: .leading, spacing: 20) {
                        // Habit Header
                        HStack {
                            HabitIconView(habit: selectedHabit)
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedHabit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                                Text("Progress for \(getDateText())")
                                    .font(.appBodySmall)
                                    .foregroundColor(.text02)
                            }
                            
                            Spacer()
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.surface)
                        )
                        .padding(.horizontal, 20)
                        
                        // Progress details
                        VStack(alignment: .leading, spacing: 16) {
                            // Progress bar
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Progress")
                        .font(.appBodyMedium)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                                    
                                    Text("\(Int(getProgressPercentage() * 100))%")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.primaryFocus)
                                }
                                
                                ProgressView(value: getProgressPercentage())
                                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryFocus))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                            }
                            
                            // Goal details
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.onPrimaryContainer)
                                
                                Text(selectedHabit.goal)
                                    .font(.appBodySmall)
                                    .foregroundColor(.text02)
                            }
                            
                            // Reminders
                            if !selectedHabit.reminders.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Reminders")
                                        .font(.appBodyMedium)
                                        .foregroundColor(.onPrimaryContainer)
                                    
                                    ForEach(selectedHabit.reminders.filter { $0.isActive }, id: \.id) { reminder in
                                        HStack {
                                            Image(systemName: "bell.fill")
                                                .foregroundColor(.primaryFocus)
                                                .font(.system(size: 12))
                                            
                                            Text(formatReminderTime(reminder.time))
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.surface)
                        )
                        .padding(.horizontal, 20)
                    }
                }
                
                // Empty state
                if habits.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.text03)
                        
                        Text("No habits yet")
                            .font(.appTitleMedium)
                            .foregroundColor(.text01)
                        
                        Text("Create your first habit to start tracking progress")
                        .font(.appBodyMedium)
                            .foregroundColor(.text02)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            // Navigate to create habit
                        }) {
                            Text("Create Habit")
                                .font(.appBodyMediumEmphasised)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            .background(
                                    RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primaryFocus)
                    )
                }
                .padding(.horizontal, 40)
            }
        }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Functions
    private func getActiveHabits() -> [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return habitRepository.habits.filter { habit in
            // Check if habit is currently active (within its period)
            let startDate = calendar.startOfDay(for: habit.startDate)
            let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            
            // Habit is active if today is within its period
            return today >= startDate && today <= endDate
        }
    }
    
    private func getActiveHabitsForSelectedWeek() -> [Habit] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        return habitRepository.habits.filter { habit in
            let habitStart = calendar.startOfDay(for: habit.startDate)
            let habitEnd = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            
            // Habit is active if it overlaps with the selected week
            return habitStart <= weekEnd && habitEnd >= weekStart
        }
    }
    
    private func getActiveHabitsForSelectedMonth() -> [Habit] {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: selectedProgressDate)?.start ?? selectedProgressDate
        let monthEnd = calendar.dateInterval(of: .month, for: selectedProgressDate)?.end ?? selectedProgressDate
        
        return habitRepository.habits.filter { habit in
            let habitStart = calendar.startOfDay(for: habit.startDate)
            let habitEnd = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            
            // Habit is active if it overlaps with the selected month
            return habitStart <= monthEnd && habitEnd >= monthStart
        }
    }
    
    private func updateStreakStatistics() {
        // For weekly tab, use active habits for the selected week
        // For other tabs, use all active habits
        let habitsToUse = selectedTimePeriod == 1 ? getActiveHabitsForSelectedWeek() : getActiveHabits()
        streakStatistics = StreakDataCalculator.calculateStreakStatistics(from: habitsToUse)
    }
    
    // MARK: - Helper Functions for Calendar
    private func formatMonthYear(_ date: Date) -> String {
        return AppDateFormatter.shared.formatMonthYear(date)
    }
    
    private func getFirstDayOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func getDaysInMonth(_ date: Date) -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 30
    }
    
    private func getProgressPercentageForDate(_ date: Date) -> Double {
        let scheduledHabits = getScheduledHabitsForDate(date)
        if scheduledHabits.isEmpty {
            return 0.0
        }
        
        let totalProgress = scheduledHabits.reduce(0.0) { total, habit in
            let progress = Double(habitRepository.getProgress(for: habit, date: date))
            let goalAmount = parseGoalAmount(from: habit.goal)
            return total + min(progress, Double(goalAmount))
        }
        
        let totalGoal = scheduledHabits.reduce(0) { total, habit in
            return total + parseGoalAmount(from: habit.goal)
        }
        
        if totalGoal == 0 {
            return 0.0
        }
        
        return totalProgress / Double(totalGoal)
    }
    
    // MARK: - Helper Functions for Dynamic Content
    private func getPeriodText() -> String {
        switch selectedTimePeriod {
        case 0: return "daily"
        case 1: return "weekly"
        case 2: return "monthly"
        case 3: return "yearly"
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
        case 2: // Monthly
            return "for \(formatMonth(selectedProgressDate))"
        case 3: // Yearly
            return "for \(Calendar.current.component(.year, from: selectedProgressDate))"
        default:
            return "on \(formatDate(selectedProgressDate))"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        return AppDateFormatter.shared.formatDisplayDate(date)
    }
    
    private func formatWeek(_ date: Date) -> String {
        // Use the same calendar and calculation as WeekPickerModal
        let calendar = AppDateFormatter.shared.getUserCalendar()
        
        // Get the start of the week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
        
        return AppDateFormatter.shared.formatWeekRange(startDate: weekStart, endDate: weekEnd)
    }
    
    private func formatMonth(_ date: Date) -> String {
        return AppDateFormatter.shared.formatMonthYear(date)
    }
    
    private func formatYear(_ date: Date) -> String {
        return AppDateFormatter.shared.formatYear(date)
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDate(selectedProgressDate, inSameDayAs: Date())
    }
    
    private var isThisWeekSelected: Bool {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let selectedWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStartDate)?.start ?? selectedWeekStartDate
        return calendar.isDate(currentWeekStart, inSameDayAs: selectedWeekStart)
    }
    
    private var isThisMonthSelected: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let selectedMonth = calendar.component(.month, from: selectedProgressDate)
        let selectedYear = calendar.component(.year, from: selectedProgressDate)
        return currentMonth == selectedMonth && currentYear == selectedYear
    }
    
    private var isThisYearSelected: Bool {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return currentYear == selectedYear
    }
    
    // MARK: - Reminder State Management
    private func getDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func isReminderEnabled(for reminder: ReminderItem, on date: Date) -> Bool {
        let dateKey = getDateKey(for: date)
        return reminderStates[dateKey]?[reminder.id] ?? reminder.isActive
    }
    
    private func isReminderTimePassed(for reminder: ReminderItem, on date: Date) -> Bool {
        let calendar = Calendar.current
        let reminderDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: reminder.time),
                                          minute: calendar.component(.minute, from: reminder.time),
                                          second: 0,
                                          of: date) ?? date
        
        return Date() > reminderDateTime
    }
    
    private func toggleReminder(for reminder: ReminderItem, on date: Date) {
        // Don't allow toggling if the reminder time has already passed
        guard !isReminderTimePassed(for: reminder, on: date) else { return }
        
        let dateKey = getDateKey(for: date)
        if reminderStates[dateKey] == nil {
            reminderStates[dateKey] = [:]
        }
        let currentState = isReminderEnabled(for: reminder, on: date)
        reminderStates[dateKey]?[reminder.id] = !currentState
    }
    
    // MARK: - Yearly Data Management
    private func loadYearlyData() {
        guard !habitRepository.habits.isEmpty else {
            yearlyHeatmapData = []
            isDataLoaded = true
            return
        }
        
        isDataLoaded = false
        isLoadingProgress = 0.0
        
        // Calculate yearly heatmap data asynchronously
        Task {
            let data = await StreakDataCalculator.generateYearlyDataFromHabitsAsync(
                habitRepository.habits,
                startIndex: 0,
                itemsPerPage: habitRepository.habits.count,
                forYear: selectedYear
            ) { progress in
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isLoadingProgress = progress
                }
            }
            
            await MainActor.run {
                yearlyHeatmapData = data
                isDataLoaded = true
                isLoadingProgress = 1.0
            }
        }
    }
    
    // MARK: - Progress Card View
    private var todayProgressCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedHabit != nil && getScheduledHabitsCount() == 0 {
                // Empty state for individual habit not scheduled
                VStack(spacing: 12) {
                    Text("No Progress Today")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text("\(selectedHabit?.name ?? "This habit") is not scheduled for \(formatDate(selectedProgressDate))")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 0)
                .padding(.vertical, 24)
            } else {
                // Progress card (for all habits or scheduled individual habit)
                HStack(spacing: 20) {
                    // Left side: Text content (vertically centered)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Progress")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.onPrimaryContainer)
                        
                        if selectedHabit != nil {
                            Text(getCompletedHabitsCount() == 1 ? "Completed" : "Not completed")
                                .font(.appBodySmall)
                                .foregroundColor(.primaryFocus)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text("\(getCompletedHabitsCount()) of \(getScheduledHabitsCount()) habits completed")
                                .font(.appBodySmall)
                                .foregroundColor(.primaryFocus)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right side: Progress ring (vertically centered)
                    AnimatedCircularProgressRing(
                        progress: getProgressPercentage(),
                        size: 52
                    )
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, selectedHabit != nil && getScheduledHabitsCount() == 0 ? 24 : 12)
        .background(
            Image("Light-gradient-BG@4x")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Weekly Progress Card
    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                // Left side: Text content (vertically centered)
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week's Progress")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text(getWeeklyEncouragingMessage())
                        .font(.appBodySmall)
                        .foregroundColor(.primaryFocus)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side: Progress ring (vertically centered)
                AnimatedCircularProgressRing(
                    progress: getWeeklyProgressPercentage(),
                    size: 52
                )
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Image("Light-gradient-BG@4x")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Weekly Analysis Card
    private var weeklyAnalysisCard: some View {
        VStack(spacing: 0) {
            // Header with title and page controls (inside the card)
            HStack {
                Text("This Week's Highlights")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)

                Spacer()

                // Page controls (dots)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == currentHighlightPage ? Color.primaryFocus : Color.outline3.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .background(
                RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                    .fill(Color.grey50)
            )
            
            // Swipeable content
            TabView(selection: $currentHighlightPage) {
                // Page 0: This Week's Highlights
                habitSpotlightPage
                    .tag(0)
                
                // Page 1: Insights & Tips
                weeklyInsightsPage
                    .tag(1)
                
                // Page 2: Weekly Trends
                weeklyTrendsPage
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 160)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
    }
    
    // MARK: - Weekly Analysis Card Pages
    private var habitSpotlightPage: some View {
        VStack(spacing: 16) {
            if let topHabit = getTopPerformingHabit() {
                // Main content
                HStack(spacing: 16) {
                    // Star icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                    
                    // Content with habit info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Performer")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        
                        Text(topHabit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        let rate = getWeeklyHabitCompletionRate(topHabit)
                        Text("\(Int(rate))% completion this week")
                            .font(.appBodyMedium)
                            .foregroundColor(.yellow)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Bottom motivational section
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("Keep up the excellent work!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                // Empty state when no habits
                VStack(spacing: 12) {
                    Text("No habits to highlight yet")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Text(getTopPerformerEmptyStateMessage())
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var weeklyInsightsPage: some View {
        VStack(spacing: 16) {
            if let strugglingHabit = getStrugglingHabit() {
                // Main content
                HStack(spacing: 16) {
                    // Warning icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.25), Color.red.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    
                    // Content with habit info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Could Use a Nudge")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        
                        Text(strugglingHabit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        let rate = getWeeklyHabitCompletionRate(strugglingHabit)
                        Text("\(Int(rate))% completion this week")
                            .font(.appBodyMedium)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Tip section
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text(getStrugglingHabitTip(for: strugglingHabit))
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                // No struggling habits
                VStack(spacing: 12) {
                    Text("All habits are doing great!")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Text(getNeedsAttentionEmptyStateMessage())
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var weeklyTrendsPage: some View {
        VStack(spacing: 16) {
            if shouldShowWeeklyTrends() {
                // Main content
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Trends")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.1))
                            )
                        
                        Text(getWeeklyTrendTitle())
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        Text(getWeeklyTrendDescription())
                            .font(.appBodyMedium)
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Trend details
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.purple)
                    
                    Text(getWeeklyTrendInsight())
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                // Empty state when no meaningful trends
                VStack(spacing: 12) {
                    Text("No trends to show yet")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Text(getWeeklyTrendsEmptyStateMessage())
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Weekly Trends Helper Functions
    private func shouldShowWeeklyTrends() -> Bool {
        let uniqueHabitsCount = getUniqueHabitsCount()
        let totalPossibleDays = getWeeklyTotalPossibleDays()
        
        // Don't show trends if no habits or no scheduled days
        if uniqueHabitsCount == 0 || totalPossibleDays == 0 {
            return false
        }
        
        // Don't show trends if there's no meaningful data (less than 2 days of data)
        if totalPossibleDays < 2 {
            return false
        }
        
        return true
    }
    
    private func getWeeklyTrendsEmptyStateMessage() -> String {
        if habitRepository.habits.isEmpty {
            return "Create your first habit to start tracking progress!"
        } else {
            // Check if any habits are scheduled this week
            let calendar = Calendar.current
            let weekStart = selectedWeekStartDate
            let hasScheduledHabits = habitRepository.habits.contains { habit in
                for dayOffset in 0..<7 {
                    if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                            return true
                        }
                    }
                }
                return false
            }
            
            if hasScheduledHabits {
                let weeklyMetrics = getWeeklyMetrics()
                if weeklyMetrics.activeDays == 1 {
                    return "You've logged 1 active day. Track a bit more to see trends!"
                } else {
                    return "Complete habits for a few days to see your weekly trends!"
                }
            } else {
                return "No habits scheduled this week. Add schedules to see highlights!"
            }
        }
    }
    
    // MARK: - Progress Calculation Functions
    private func getScheduledHabitsCount() -> Int {
        if let selectedHabit = selectedHabit {
            // For individual habit, check if it's scheduled for the selected date
            return StreakDataCalculator.shouldShowHabitOnDate(selectedHabit, date: selectedProgressDate) ? 1 : 0
        } else {
            // For all habits, count all scheduled habits
        let scheduledHabits = habitRepository.habits.filter { habit in
            return StreakDataCalculator.shouldShowHabitOnDate(habit, date: selectedProgressDate)
        }
        return scheduledHabits.count
        }
    }
    
    private func getCompletedHabitsCount() -> Int {
        if let selectedHabit = selectedHabit {
            // For individual habit, check if it's completed
            if !StreakDataCalculator.shouldShowHabitOnDate(selectedHabit, date: selectedProgressDate) {
                return 0 // Not scheduled, so not completed
            }
            let progress = habitRepository.getProgress(for: selectedHabit, date: selectedProgressDate)
            let goalAmount = parseGoalAmount(from: selectedHabit.goal)
            return progress >= goalAmount ? 1 : 0
        } else {
            // For all habits, count completed habits
        let scheduledHabits = getScheduledHabitsForDate(selectedProgressDate)
        
        let completedHabits = scheduledHabits.filter { habit in
            let progress = habitRepository.getProgress(for: habit, date: selectedProgressDate)
            let goalAmount = parseGoalAmount(from: habit.goal)
            return progress >= goalAmount
        }
        
        return completedHabits.count
        }
    }
    
    private func getProgressPercentage() -> Double {
        if let selectedHabit = selectedHabit {
            // For individual habit, calculate its progress percentage
            if !StreakDataCalculator.shouldShowHabitOnDate(selectedHabit, date: selectedProgressDate) {
                return 0.0 // Not scheduled, so no progress
            }
            let progress = habitRepository.getProgress(for: selectedHabit, date: selectedProgressDate)
            let goalAmount = parseGoalAmount(from: selectedHabit.goal)
            if goalAmount == 0 {
                return 0.0
            }
            return Double(progress) / Double(goalAmount)
        } else {
            // For all habits, calculate overall progress
        let scheduledHabits = getScheduledHabitsForDate(selectedProgressDate)
        if scheduledHabits.isEmpty {
            return 0.0
        }
        
            let totalProgress = scheduledHabits.reduce(0.0) { total, habit in
            let progress = habitRepository.getProgress(for: habit, date: selectedProgressDate)
                return total + Double(progress)
        }
        
            let totalGoal = scheduledHabits.reduce(0.0) { total, habit in
                let goalAmount = parseGoalAmount(from: habit.goal)
                return total + Double(goalAmount)
        }
        
        if totalGoal == 0 {
            return 0.0
        }
        
        return totalProgress / totalGoal
        }
    }
    
    private func getCompletionPercentage() -> Double {
        let scheduledCount = getScheduledHabitsCount()
        guard scheduledCount > 0 else { return 0.0 }
        
        let completedCount = getCompletedHabitsCount()
        return Double(completedCount) / Double(scheduledCount)
    }
    
    // MARK: - Weekly Progress Calculation Functions
    private func getWeeklyScheduledHabitsCount() -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let today = selectedProgressDate
        
        // Only count days from week start up to today (or selected date)
        let daysToCount = min(7, calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0) + 1
        
        var totalScheduled = 0
        for dayOffset in 0..<daysToCount {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let scheduledHabits = habitRepository.habits.filter { habit in
                    StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay)
                }
                totalScheduled += scheduledHabits.count
            }
        }
        return totalScheduled
    }
    
    private func getWeeklyCompletedHabitsCount() -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let today = selectedProgressDate
        
        // Only count days from week start up to today (or selected date)
        let daysToCount = min(7, calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0) + 1
        
        var totalCompleted = 0
        for dayOffset in 0..<daysToCount {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let scheduledHabits = habitRepository.habits.filter { habit in
                    StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay)
                }
                
                for habit in scheduledHabits {
                    let progress = habitRepository.getProgress(for: habit, date: currentDay)
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    if progress >= goalAmount {
                        totalCompleted += 1
                    }
                }
            }
        }
        return totalCompleted
    }
    
    private func getWeeklyProgressPercentage() -> Double {
        let completedDays = getWeeklyCompletedDaysCount()
        let totalPossibleDays = getWeeklyTotalPossibleDays()
        guard totalPossibleDays > 0 else { return 0.0 }
        
        return Double(completedDays) / Double(totalPossibleDays)
    }
    
    private func getWeeklyEncouragingMessage() -> String {
        let progressPercentage = getWeeklyProgressPercentage()
        let completedDays = getWeeklyCompletedDaysCount()
        let totalPossibleDays = getWeeklyTotalPossibleDays()
        
        // Handle edge cases
        if totalPossibleDays == 0 {
            return "No habits scheduled this week yet"
        }
        
        if completedDays == 0 {
            return "Ready to start your week strong! 💪"
        }
        
        // Generate encouraging messages based on completion rate
        switch progressPercentage {
        case 0.9...1.0:
            return ["You're absolutely crushing it! 🔥", "Incredible progress this week! ⭐", "You're on fire! Keep it up! 🚀", "Outstanding work this week! 💯"].randomElement() ?? "Amazing progress!"
            
        case 0.7..<0.9:
            return ["Great job this week! 🌟", "You're doing fantastic! ✨", "Excellent progress! Keep going! 💪", "You're building great momentum! 🎯"].randomElement() ?? "Great progress!"
            
        case 0.5..<0.7:
            return ["Good progress this week! 👍", "You're on the right track! 🎯", "Keep up the good work! 💪", "Every step counts! 🌱"].randomElement() ?? "Good progress!"
            
        case 0.3..<0.5:
            return ["You're making progress! 🌱", "Every habit counts! 💪", "Keep pushing forward! 🎯", "You've got this! ✨"].randomElement() ?? "Keep going!"
            
        case 0.1..<0.3:
            return ["Every small step matters! 🌱", "You're building momentum! 💪", "Progress is progress! 🎯", "Keep taking it one day at a time! ✨"].randomElement() ?? "Keep going!"
            
        default:
            return ["Ready to make this week count! 💪", "Every journey starts with a single step! 🌱", "You've got this! Let's go! 🚀", "Time to build some great habits! ✨"].randomElement() ?? "Let's do this!"
        }
    }
    
    // MARK: - Highlights Configuration
    /// Configuration constants for "This Week's Highlights" calculations
    /// These values control thresholds, minimum data requirements, and comparison safety
    private struct HighlightsConfig {
        /// Minimum scheduled days required for a habit to be considered for "Top Performer" or "Needs Attention"
        /// Prevents low-data habits (e.g., 1/1 = 100%) from beating high-commitment habits (e.g., 6/7 = 86%)
        static let minScheduledDays = 3
        
        /// Hard floor for "clearly struggling" habits - below this threshold, habits are flagged regardless of context
        /// 50 percentage points (0.5) - habits below this are clearly struggling
        static let needsAttentionHardFloor: Double = 0.5
        
        /// Soft floor for "needs attention" - habits above this are considered performing well
        /// 80 percentage points (0.8) - habits above this don't need attention even if below average
        static let needsAttentionSoftFloor: Double = 0.8
        
        /// Minimum difference below average required to flag a habit as "needs attention"
        /// 20 percentage points (0.20) - prevents flagging habits that are only slightly below average
        static let belowAvgDelta: Double = 0.20
        
        /// Threshold for considering all habits as "doing great" in empty state messages
        /// 80 percentage points (0.8) - above this, show celebratory message
        static let greatAvgFloor: Double = 0.80
        
        /// Epsilon for floating-point comparisons to prevent precision issues in tie-breaking
        /// 1e-9 - used in all rate comparisons to ensure stable sorting
        static let floatingPointEpsilon: Double = 1e-9
    }
    
    // MARK: - Habit Spotlight Helper Functions
    
    /// Calculates the top performing habit for "This Week's Highlights"
    /// 
    /// **Purpose**: Shows the habit performing best (but not perfect) this week
    /// 
    /// **Algorithm**:
    /// 1. Calculate completion rate for each habit across the week
    /// 2. Filter out perfect habits (100% completion) to avoid showing them as "top performers"
    /// 3. Apply minimum scheduled days filter (≥3) to prevent low-data habits from skewing results
    /// 4. Sort with comprehensive tie-breaking: rate → scheduled days → completions → UUID
    /// 
    /// **Edge Cases**:
    /// - No habits: Returns `nil` (shows empty state)
    /// - All habits perfect: Returns the one with most scheduled days
    /// - All habits 0% completion: Returns the one with most scheduled days
    /// - Insufficient data: Habits with <3 scheduled days are deprioritized
    /// 
    /// **Example**: Habit A (1/1=100%), Habit B (6/7=86%), Habit C (2/2=100%)
    /// - Habit A excluded (perfect), Habit C excluded (perfect)
    /// - Habit B selected (highest rate among non-perfect, sufficient data)
    /// 
    /// - Returns: The top performing habit, or `nil` if no eligible habits
    private func getTopPerformingHabit() -> Habit? {
        let calendar = Calendar.current
        let weekStart = selectedWeekStartDate
        
        // Step 1: Calculate habit performance data for the week
        // Each habit gets: (habit, scheduled_days, completed_days, completion_rate)
        var habitData: [(habit: Habit, scheduled: Int, completed: Int, rate: Double)] = []
        
        for habit in habitRepository.habits {
            var totalScheduled = 0
            var totalCompleted = 0
            
            for dayOffset in 0..<7 {
                if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                        totalScheduled += 1
                        
                        let progress = habitRepository.getProgress(for: habit, date: currentDay)
                        let goalAmount = parseGoalAmount(from: habit.goal)
                        if progress >= goalAmount {
                            totalCompleted += 1
                        }
                    }
                }
            }
            
            // Only include habits with scheduled days (avoid division by zero)
            if totalScheduled > 0 {
                let completionRate = Double(totalCompleted) / Double(totalScheduled)
                habitData.append((habit: habit, scheduled: totalScheduled, completed: totalCompleted, rate: completionRate))
            }
        }
        
        guard !habitData.isEmpty else { return nil }
        
        // Filter out perfect habits (100% completion) to avoid showing them as "top performers"
        let nonPerfectHabits = habitData.filter { $0.rate < 1.0 }
        let candidatePool = nonPerfectHabits.isEmpty ? habitData : nonPerfectHabits
        
        // Apply minimum scheduled days filter
        let minScheduledCandidates = candidatePool.filter { $0.scheduled >= HighlightsConfig.minScheduledDays }
        let finalCandidates = minScheduledCandidates.isEmpty ? candidatePool : minScheduledCandidates
        
        // Sort with comprehensive tie-breaking rules
        return finalCandidates.max { habit1, habit2 in
            // 1. Primary: completion rate (with floating-point safety)
            if abs(habit1.rate - habit2.rate) > HighlightsConfig.floatingPointEpsilon {
                return habit1.rate < habit2.rate
            }
            
            // 2. Secondary: more scheduled days (more commitment)
            if habit1.scheduled != habit2.scheduled {
                return habit1.scheduled < habit2.scheduled
            }
            
            // 3. Tertiary: more completions (more actual progress)
            if habit1.completed != habit2.completed {
                return habit1.completed < habit2.completed
            }
            
            // 4. Quaternary: stable ID alphabetical (deterministic)
            return habit1.habit.id.uuidString < habit2.habit.id.uuidString
        }?.habit
    }
    
    private func getScheduledDaysCount(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let weekStart = selectedWeekStartDate
        
        var scheduledDays = 0
        for dayOffset in 0..<7 {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                    scheduledDays += 1
                }
            }
        }
        return scheduledDays
    }
    
    private func getTopPerformerEmptyStateMessage() -> String {
        if habitRepository.habits.isEmpty {
            return "Create your first habit to start tracking progress!"
        } else {
            // Check if any habits are scheduled this week
            let calendar = Calendar.current
            let weekStart = selectedWeekStartDate
            let hasScheduledHabits = habitRepository.habits.contains { habit in
                for dayOffset in 0..<7 {
                    if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                            return true
                        }
                    }
                }
                return false
            }
            
            if hasScheduledHabits {
                return "Complete some habits this week to see your top performer!"
            } else {
                return "No habits scheduled this week. Check your habit schedules!"
            }
        }
    }
    
    private func getWeeklyHabitCompletionRate(_ habit: Habit) -> Double {
        let calendar = Calendar.current
        let weekStart = selectedWeekStartDate
        
        var totalScheduled = 0
        var totalCompleted = 0
        
        for dayOffset in 0..<7 {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                    totalScheduled += 1
                    
                    let progress = habitRepository.getProgress(for: habit, date: currentDay)
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    if progress >= goalAmount {
                        totalCompleted += 1
                    }
                }
            }
        }
        
        guard totalScheduled > 0 else { return 0.0 }
        return (Double(totalCompleted) / Double(totalScheduled)) * 100
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
        
        if scheduledCount > 0 {
            if completedCount == scheduledCount {
            return "All habits completed! 🎉"
        } else if completedCount > 0 {
                return "\(completedCount) of \(scheduledCount) habits completed"
            } else {
                return "Ready to start your habits! 🚀"
            }
        } else {
            return "Ready to start your habits! 🚀"
        }
    }
    
    // MARK: - Helper Functions for Scheduled Habits
    private func getScheduledHabitsForDate(_ date: Date) -> [Habit] {
        return habitRepository.habits.filter { habit in
            return StreakDataCalculator.shouldShowHabitOnDate(habit, date: date)
        }
    }
    
    private func getHabitReminderTime(for habit: Habit) -> String {
        // Get the first active reminder time for the habit
        if let firstReminder = habit.reminders.first(where: { $0.isActive }) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: firstReminder.time)
        }
        
        // Fallback to a default time if no reminders
        return "9:00 AM"
    }
    
    // MARK: - Helper Functions for All Reminders
    private struct ReminderWithHabit: Identifiable {
        let id = UUID()
        let reminder: ReminderItem
        let habit: Habit
    }
    
    private func getAllRemindersForDate(_ date: Date) -> [ReminderWithHabit] {
        let scheduledHabits = getScheduledHabitsForDate(date)
        var allReminders: [ReminderWithHabit] = []
        
        for habit in scheduledHabits {
            for reminder in habit.reminders {
                // Show all reminders for the selected date, regardless of their enabled state
                // The toggle will control whether they're actually sent as notifications
                allReminders.append(ReminderWithHabit(reminder: reminder, habit: habit))
            }
        }
        
        // Sort reminders by time
        return allReminders.sorted { $0.reminder.time < $1.reminder.time }
    }
    
    private func getActiveRemindersForDate(_ date: Date) -> [ReminderWithHabit] {
        let scheduledHabits = getScheduledHabitsForDate(date)
        var activeReminders: [ReminderWithHabit] = []
        
        for habit in scheduledHabits {
            for reminder in habit.reminders {
                // Check if reminder is enabled for this specific date AND time hasn't passed yet
                if isReminderEnabled(for: reminder, on: date) && !isReminderTimePassed(for: reminder, on: date) {
                    activeReminders.append(ReminderWithHabit(reminder: reminder, habit: habit))
                }
            }
        }
        
        // Sort reminders by time
        return activeReminders.sorted { $0.reminder.time < $1.reminder.time }
    }
    
    private func formatReminderTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    // MARK: - Difficulty Calculation Functions
    private func getAverageDifficultyForDate(_ date: Date) -> Double {
        let scheduledHabits = getScheduledHabitsForDate(date)
        if scheduledHabits.isEmpty {
            return 3.0 // Default to Medium
        }
        
        let totalDifficulty = scheduledHabits.reduce(0.0) { total, habit in
            let dateKey = Self.dateKey(for: date)
            if let difficulty = habit.difficultyHistory[dateKey] {
                return total + Double(difficulty)
            } else {
                return total + 3.0 // Default to Medium if no difficulty recorded
            }
        }
        
        let habitCount = Double(scheduledHabits.count)
        if habitCount == 0 {
            return 3.0 // Default to Medium
        }
        
        return totalDifficulty / Double(habitCount)
    }
    
    private func getDifficultyLevel(from average: Double) -> (level: HabitDifficulty, color: Color) {
        let roundedValue = Int(round(average))
        let difficulty = HabitDifficulty(rawValue: roundedValue) ?? .medium
        
        return (difficulty, difficulty.color)
    }
    
    private func getDifficultyMessage(for level: HabitDifficulty) -> String {
        switch level {
        case .veryEasy:
            return "You're crushing it! 🚀"
        case .easy:
            return "Great job! 💪"
        case .medium:
            return "You're doing well! 👍"
        case .hard:
            return "Keep pushing through! 🔥"
        case .veryHard:
            return "You're building strength! 💎"
        }
    }
    
    // MARK: - Individual Habit Difficulty Data
    private struct IndividualHabitDifficultyData {
        let difficulty: Double
        let level: HabitDifficulty
        let color: Color
        let hasRecordedDifficulty: Bool
    }
    
    private func getIndividualHabitDifficulty(for habit: Habit, on date: Date) -> IndividualHabitDifficultyData {
        // Get difficulty directly from habit's difficulty history
        let dateKey = Self.dateKey(for: date)
        
        if let difficulty = habit.difficultyHistory[dateKey] {
            let difficultyDouble = Double(difficulty)
            let difficultyInfo = getDifficultyLevel(from: difficultyDouble)
            return IndividualHabitDifficultyData(
                difficulty: difficultyDouble,
                level: difficultyInfo.level,
                color: difficultyInfo.color,
                hasRecordedDifficulty: true
            )
        } else {
            // No difficulty recorded for this date
            return IndividualHabitDifficultyData(
                difficulty: 3.0, // Default to medium
                level: .medium,
                color: .orange,
                hasRecordedDifficulty: false
            )
        }
    }
    
    // Helper function to get date key (same as in Habit model)
    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Individual Habit Difficulty Section
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Difficulty")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Spacer()
                
                Button(action: {
                    // TODO: Add "See more" functionality
                }) {
                    HStack(spacing: 4) {
                        Text("See more")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.text02)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Difficulty Content
            if let selectedHabit = selectedHabit {
                let difficultyData = getIndividualHabitDifficulty(for: selectedHabit, on: selectedProgressDate)
                
                if difficultyData.hasRecordedDifficulty {
                    // Show difficulty section with arc and image
                    VStack(spacing: -130) {
                        // Difficulty arc (centered)
                        DifficultyArcView(
                            currentDifficulty: difficultyData.difficulty,
                            size: 180
                        )
                        
                        // Image, title and other texts in separate VStack
                        VStack(spacing: 16) {
                            // Character image (centered below arc)
                            Group {
                                switch difficultyData.level {
                                case .veryEasy:
                                    Image("Difficulty-VeryEasy@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                case .easy:
                                    Image("Difficulty-Easy@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                case .medium:
                                    Image("Difficulty-Medium@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                case .hard:
                                    Image("Difficulty-Hard@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                case .veryHard:
                                    Image("Difficulty-VeryHard@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 100)
                                }
                            }
                            
                            // Difficulty level text (centered)
                            Text(difficultyData.level.displayName)
                                .font(.appTitleMediumEmphasised)
                                .foregroundColor(difficultyData.color)
                            
                            // Motivational message (centered)
                            Text(getDifficultyMessage(for: difficultyData.level))
                                .font(.appBodyMedium)
                                .foregroundColor(.onPrimaryContainer)
                                .multilineTextAlignment(.center)
                            
                            // "What these stats mean?" link (centered)
                            Button(action: {
                                // TODO: Add explanation functionality
                            }) {
                                Text("What these stats mean?")
                                    .font(.appBodySmall)
                                    .foregroundColor(.text02)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                } else {
                    // Empty state when no difficulty recorded
                    HabitEmptyStateView(
                        imageName: "Habit-List-Empty-State@4x",
                        title: "No Difficulty yet",
                        subtitle: "You can record the difficulty once you complete the habit!"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    // MARK: - All Reminders Modal
    private var allRemindersModal: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingAllReminders = false
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("All Reminders")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAllReminders = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.text02)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Reminders list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(getAllRemindersForDate(selectedProgressDate), id: \.id) { reminder in
                            allRemindersCard(for: reminder)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.surface)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .frame(maxWidth: 400, maxHeight: 600)
            .padding(.horizontal, 20)
        }
    }
    
    // Individual reminder card for "see more" modal
    private func allRemindersCard(for reminderWithHabit: ReminderWithHabit) -> some View {
        let isEnabled = isReminderEnabled(for: reminderWithHabit.reminder, on: selectedProgressDate)
        let isTimePassed = isReminderTimePassed(for: reminderWithHabit.reminder, on: selectedProgressDate)
        
        return HStack(spacing: 12) {
            // Habit Icon
            HabitIconView(habit: reminderWithHabit.habit)
                .frame(width: 40, height: 40)
            
            // Habit Name and Time
            VStack(alignment: .leading, spacing: 4) {
                Text(reminderWithHabit.habit.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.onPrimaryContainer)
                    .lineLimit(1)
                
                Text(formatReminderTime(reminderWithHabit.reminder.time))
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
            }
            
            Spacer()
            
            // Toggle Button
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in 
                    if !isTimePassed {
                        toggleReminder(for: reminderWithHabit.reminder, on: selectedProgressDate)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .primaryFocus))
            .scaleEffect(0.8)
            .disabled(isTimePassed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outline3, lineWidth: 1)
                )
        )
        .opacity(isTimePassed ? 0.6 : 1.0)
    }
    
    // MARK: - Motivational Content Functions
    private func getWeeklyMotivationalTip() -> String {
        let tips = [
            "Try stacking your habits with existing routines for better consistency.",
            "Set specific times for your habits to build stronger neural pathways.",
            "Start with just 2 minutes - small wins lead to big changes.",
            "Track your progress daily to stay motivated and accountable.",
            "Celebrate small victories to reinforce positive behavior patterns.",
            "Focus on one habit at a time until it becomes automatic.",
            "Use habit triggers to remind yourself when to act.",
            "Reflect on your 'why' when motivation feels low."
        ]
        return tips.randomElement() ?? tips[0]
    }
    
    private func getWeeklyMotivationalQuote() -> String {
        let quotes = [
            "Success is the sum of small efforts repeated day in and day out.",
            "The secret of getting ahead is getting started.",
            "You don't have to be great to get started, but you have to get started to be great.",
            "Consistency is the mother of mastery.",
            "Small steps every day lead to big results.",
            "The only impossible journey is the one you never begin.",
            "Progress, not perfection, is the goal.",
            "Your habits shape your identity, and your identity shapes your habits."
        ]
        return quotes.randomElement() ?? quotes[0]
    }
    
    // MARK: - Weekly Insights Helper Functions
    
    /// Calculates the habit that "Could Use a Nudge" for "This Week's Highlights"
    /// 
    /// **Purpose**: Identifies habits that are struggling or significantly underperforming
    /// 
    /// **Algorithm** (Two-Step Logic):
    /// 1. **Step 1 - Clear Struggling**: Find habits <50% completion with ≥3 scheduled days
    /// 2. **Step 2 - Significant Difference**: Among non-struggling habits, only flag if:
    ///    - Significantly below average (≥20 percentage points)
    ///    - Below soft floor (80%)
    ///    - Sufficient data (≥3 scheduled days)
    /// 
    /// **Why Two Steps?**: Prevents false positives when all habits perform similarly well
    /// 
    /// **Edge Cases**:
    /// - All habits perfect: Returns `nil` (shows "All habits are doing great!")
    /// - All habits performing well: Returns `nil` (shows "All habits are performing well!")
    /// - Single habit <50% with 1 day: Returns `nil` (insufficient data)
    /// - All habits 80-95%: Returns `nil` (no significant difference)
    /// 
    /// **Example**: Habits at 90%, 85%, 30% (average 68%)
    /// - Habit at 30% is 38% below average (>20% threshold) → selected
    /// 
    /// **Example**: Habits at 90%, 85%, 80% (average 85%)
    /// - Worst habit at 80% is only 5% below average (<20% threshold) → none selected
    /// 
    /// - Returns: The habit needing attention, or `nil` if no habits need attention
    private func getStrugglingHabit() -> Habit? {
        let calendar = Calendar.current
        let weekStart = selectedWeekStartDate
        
        // Calculate habit performance data
        var habitData: [(habit: Habit, scheduled: Int, completed: Int, rate: Double)] = []
        
        for habit in habitRepository.habits {
            var totalScheduled = 0
            var totalCompleted = 0
            
            for dayOffset in 0..<7 {
                if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                        totalScheduled += 1
                        
                        let progress = habitRepository.getProgress(for: habit, date: currentDay)
                        let goalAmount = parseGoalAmount(from: habit.goal)
                        if progress >= goalAmount {
                            totalCompleted += 1
                        }
                    }
                }
            }
            
            // Only include habits with scheduled days (avoid division by zero)
            if totalScheduled > 0 {
                let completionRate = Double(totalCompleted) / Double(totalScheduled)
                habitData.append((habit: habit, scheduled: totalScheduled, completed: totalCompleted, rate: completionRate))
            }
        }
        
        guard !habitData.isEmpty else { return nil }
        
        // Filter out perfect habits (100% completion)
        let nonPerfectHabits = habitData.filter { $0.rate < 1.0 }
        guard !nonPerfectHabits.isEmpty else { return nil } // All habits are perfect
        
        // Step 1: Find habits that are clearly struggling (< 50% completion)
        let reallyStrugglingHabits = nonPerfectHabits.filter { 
            $0.rate < HighlightsConfig.needsAttentionHardFloor && 
            $0.scheduled >= HighlightsConfig.minScheduledDays 
        }
        
        if !reallyStrugglingHabits.isEmpty {
            // Return the worst among clearly struggling habits
            return reallyStrugglingHabits.min { habit1, habit2 in
                // Primary: lowest completion rate (with floating-point safety)
                if abs(habit1.rate - habit2.rate) > HighlightsConfig.floatingPointEpsilon {
                    return habit1.rate < habit2.rate
                }
                // Secondary: fewer scheduled days (less commitment = more concerning)
                if habit1.scheduled != habit2.scheduled {
                    return habit1.scheduled < habit2.scheduled
                }
                // Tertiary: fewer completions
                if habit1.completed != habit2.completed {
                    return habit1.completed < habit2.completed
                }
                // Quaternary: stable ID alphabetical
                return habit1.habit.id.uuidString < habit2.habit.id.uuidString
            }?.habit
        }
        
        // Step 2: Check for significant differences among non-struggling habits
        let completionRates = nonPerfectHabits.map { $0.rate }
        let averageRate = completionRates.reduce(0, +) / Double(completionRates.count)
        
        // Only show "needs attention" if:
        // 1. There's a significant difference (≥20 percentage points below average)
        // 2. The worst habit is below a soft floor (80%)
        // 3. The worst habit has sufficient data (≥3 scheduled days)
        let worstHabit = nonPerfectHabits.min { $0.rate < $1.rate }
        
        if let worst = worstHabit,
           worst.rate < (averageRate - HighlightsConfig.belowAvgDelta) && // 20 percentage points below average
           worst.rate < HighlightsConfig.needsAttentionSoftFloor && // Below soft floor
           worst.scheduled >= HighlightsConfig.minScheduledDays { // Sufficient data
            return worst.habit
        }
        
        // No habit needs attention
        return nil
    }
    
    private func getNeedsAttentionEmptyStateMessage() -> String {
        if habitRepository.habits.isEmpty {
            return "Create your first habit to start tracking progress!"
        } else {
            // Check if any habits are scheduled this week
            let calendar = Calendar.current
            let weekStart = selectedWeekStartDate
            let hasScheduledHabits = habitRepository.habits.contains { habit in
                for dayOffset in 0..<7 {
                    if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                        if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                            return true
                        }
                    }
                }
                return false
            }
            
            if hasScheduledHabits {
                // Check if all habits are performing well (average ≥80%)
                let weeklyMetrics = getWeeklyMetrics()
                if weeklyMetrics.overallCompletion >= HighlightsConfig.greatAvgFloor {
                    return "All habits are doing great! Keep up the excellent work!"
                } else {
                    return "All habits are performing well this week!"
                }
            } else {
                return "No habits scheduled this week. Check your habit schedules!"
            }
        }
    }
    
    private func getStrugglingHabitTip(for habit: Habit) -> String {
        let tips = [
            "Try breaking this habit into smaller, more manageable steps.",
            "Set a specific time each day to work on this habit.",
            "Consider adjusting your goal to be more achievable.",
            "Find an accountability partner to help you stay consistent.",
            "Remove any obstacles that might be preventing you from completing this habit.",
            "Track your progress daily to stay motivated.",
            "Celebrate small wins to build momentum.",
            "Try habit stacking - attach this habit to something you already do regularly."
        ]
        return tips.randomElement() ?? tips[0]
    }
    
    // MARK: - Weekly Trends Helper Functions
    private func getWeeklyTrendTitle() -> String {
        let progressPercentage = getWeeklyProgressPercentage()
        
        switch progressPercentage {
        case 0.8...1.0:
            return "Outstanding Week!"
        case 0.6..<0.8:
            return "Great Progress"
        case 0.4..<0.6:
            return "Steady Improvement"
        case 0.2..<0.4:
            return "Building Momentum"
        default:
            return "Getting Started"
        }
    }
    
    private func getWeeklyTrendDescription() -> String {
        let uniqueHabitsCount = getUniqueHabitsCount()
        let weeklyMetrics = getWeeklyMetrics()
        
        if uniqueHabitsCount == 0 {
            return "No habits scheduled this week"
        }
        
        let overallCompletion = Int(weeklyMetrics.overallCompletion * 100)
        let perfectDayRate = Int(weeklyMetrics.perfectDayRate * 100)
        
        // Show both overall completion and perfect-day consistency
        if weeklyMetrics.activeDays >= 3 {
            return "\(overallCompletion)% of scheduled actions completed, \(perfectDayRate)% perfect days"
        } else {
            return "\(overallCompletion)% of scheduled actions completed"
        }
    }
    
    // MARK: - Weekly Trends Helper Functions
    private func getUniqueHabitsCount() -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        
        // Get all unique habits that are scheduled at least once this week
        var uniqueHabitIds = Set<UUID>()
        
        for habit in habitRepository.habits {
            // Check if habit is scheduled on any day this week
            for dayOffset in 0..<7 {
                if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay) {
                        uniqueHabitIds.insert(habit.id)
                        break // Found this habit scheduled, no need to check other days
                    }
                }
            }
        }
        
        return uniqueHabitIds.count
    }
    
    private func getWeeklyCompletedDaysCount() -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let today = selectedProgressDate
        
        // Only count days from week start up to today (or selected date)
        let daysToCount = min(7, calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0) + 1
        
        var completedDays = 0
        for dayOffset in 0..<daysToCount {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let scheduledHabits = habitRepository.habits.filter { habit in
                    StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay)
                }
                
                // Count this day as completed if all scheduled habits are completed
                let allCompleted = scheduledHabits.allSatisfy { habit in
                    let progress = habitRepository.getProgress(for: habit, date: currentDay)
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    return progress >= goalAmount
                }
                
                if allCompleted && !scheduledHabits.isEmpty {
                    completedDays += 1
                }
            }
        }
        return completedDays
    }
    
    private func getWeeklyTotalPossibleDays() -> Int {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let today = selectedProgressDate
        
        // Only count days from week start up to today (or selected date)
        let daysToCount = min(7, calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0) + 1
        
        var totalPossibleDays = 0
        for dayOffset in 0..<daysToCount {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let scheduledHabits = habitRepository.habits.filter { habit in
                    StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay)
                }
                
                // Count this day if there are any scheduled habits
                if !scheduledHabits.isEmpty {
                    totalPossibleDays += 1
                }
            }
        }
        return totalPossibleDays
    }
    
    private func getWeeklyTrendInsight() -> String {
        let weeklyMetrics = getWeeklyMetrics()
        
        if weeklyMetrics.activeDays == 0 {
            return "No habits scheduled this week"
        }
        
        let perfectDays = Int(weeklyMetrics.perfectDayRate * Double(weeklyMetrics.activeDays))
        let overallCompletion = Int(weeklyMetrics.overallCompletion * 100)
        
        // Show different insights based on performance
        if weeklyMetrics.overallCompletion >= 0.8 {
            if weeklyMetrics.perfectDayRate >= 0.8 {
                return "Outstanding! \(overallCompletion)% overall, \(perfectDays) perfect days"
            } else {
                return "Great performance! \(overallCompletion)% overall, \(perfectDays) perfect days"
            }
        } else if weeklyMetrics.overallCompletion >= 0.6 {
            return "Good progress! \(overallCompletion)% overall, \(perfectDays) perfect days"
        } else if weeklyMetrics.overallCompletion >= 0.4 {
            return "Building momentum! \(overallCompletion)% overall, \(perfectDays) perfect days"
        } else {
            return "Getting started! \(overallCompletion)% overall, \(perfectDays) perfect days"
        }
    }
    
    // MARK: - Weekly Metrics Calculation
    
    /// Calculates comprehensive weekly performance metrics for "This Week's Highlights"
    /// 
    /// **Purpose**: Provides overall completion rate and perfect-day consistency metrics
    /// 
    /// **Algorithm** (Micro-Averaging):
    /// 1. **Daily Calculation**: For each day, calculate completion ratio (completed/scheduled)
    /// 2. **Overall Completion**: Micro-average = sum(completed) / sum(scheduled)
    /// 3. **Perfect Day Rate**: % of days where ALL scheduled habits were completed
    /// 4. **Variability**: Standard deviation of daily ratios (consistency measure)
    /// 
    /// **Why Micro-Average?**: Prevents quiet days from skewing results
    /// - Macro-average would overweight days with fewer habits
    /// - Micro-average gives equal weight to each scheduled habit instance
    /// 
    /// **Example**: 2 habits × 7 days = 14 total scheduled, completed 12 total, 5 perfect days
    /// - Overall: 12/14 = 86% of scheduled actions completed
    /// - Perfect days: 5/7 = 71% perfect days
    /// - Variability: Standard deviation of daily ratios
    /// 
    /// **Edge Cases**:
    /// - No habits: Returns (0, 0, 0, 0)
    /// - No scheduled days: Returns (0, 0, 0, 0)
    /// - Single day: Perfect day rate = 0 or 1
    /// 
    /// - Returns: Tuple of (overallCompletion, perfectDayRate, activeDays, variability)
    private func getWeeklyMetrics() -> (overallCompletion: Double, perfectDayRate: Double, activeDays: Int, variability: Double) {
        let calendar = Calendar.current
        let weekStart = selectedWeekStartDate
        
        var dailyRatios: [Double] = []
        var perfectDays = 0
        var activeDays = 0
        var totalScheduled = 0
        var totalCompleted = 0
        
        for dayOffset in 0..<7 {
            if let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                let scheduledHabits = habitRepository.habits.filter { habit in
                    StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDay)
                }
                
                guard !scheduledHabits.isEmpty else { continue }
                
                var completedCount = 0
                for habit in scheduledHabits {
                    let progress = habitRepository.getProgress(for: habit, date: currentDay)
                    let goalAmount = parseGoalAmount(from: habit.goal)
                    if progress >= goalAmount {
                        completedCount += 1
                    }
                }
                
                activeDays += 1
                totalScheduled += scheduledHabits.count
                totalCompleted += completedCount
                
                let dayRatio = Double(completedCount) / Double(scheduledHabits.count)
                dailyRatios.append(dayRatio)
                
                // Perfect day = all scheduled habits completed on this day
                if dayRatio == 1.0 {
                    perfectDays += 1
                }
            }
        }
        
        // MICRO-AVERAGE: sum(completed) / sum(scheduled)
        // This prevents quiet days from skewing results by giving equal weight to each scheduled habit instance
        // Alternative (macro-average) would overweight days with fewer habits
        let overallCompletion = totalScheduled > 0 ? Double(totalCompleted) / Double(totalScheduled) : 0.0
        
        // PERFECT-DAY RATE: % of days where ALL scheduled habits were completed
        // This measures consistency of perfect days, not overall performance
        // Example: 5 perfect days out of 7 active days = 71% perfect days
        let perfectDayRate = activeDays > 0 ? Double(perfectDays) / Double(activeDays) : 0.0
        
        // VARIABILITY: Standard deviation of daily ratios (consistency measure)
        // Lower values indicate more consistent daily performance
        // Future use: Could show "steady vs. up-and-down" insights
        let variability = calculateVariability(dailyRatios)
        
        return (overallCompletion: overallCompletion, perfectDayRate: perfectDayRate, activeDays: activeDays, variability: variability)
    }
    
    private func calculateVariability(_ ratios: [Double]) -> Double {
        guard ratios.count > 1 else { return 0.0 }
        
        let mean = ratios.reduce(0, +) / Double(ratios.count)
        let variance = ratios.map { pow($0 - mean, 2) }.reduce(0, +) / Double(ratios.count)
        return sqrt(variance)
    }
    
    // MARK: - Monthly Progress Card
    private var monthlyProgressCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                // Left side: Text content (vertically centered)
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month's Progress")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.onPrimaryContainer)
                    
                    Text(getMonthlyEncouragingMessage())
                        .font(.appBodySmall)
                        .foregroundColor(.primaryFocus)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side: Progress ring (vertically centered)
                AnimatedCircularProgressRing(
                    progress: getMonthlyProgressPercentage(),
                    size: 52
                )
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Image("Light-gradient-BG@4x")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Monthly Analysis Card
    private var monthlyAnalysisCard: some View {
        VStack(spacing: 0) {
            // Header with title and page controls (inside the card)
            HStack {
                Text("This Month's Highlights")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)

                Spacer()

                // Page controls (dots)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == currentMonthlyHighlightPage ? Color.primaryFocus : Color.outline3.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .background(
                RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                    .fill(Color.grey50)
            )
            
            // Swipeable content
            TabView(selection: $currentMonthlyHighlightPage) {
                // Page 0: This Month's Highlights
                monthlyHabitSpotlightPage
                    .tag(0)
                
                // Page 1: Insights & Tips
                monthlyInsightsPage
                    .tag(1)
                
                // Page 2: Monthly Trends
                monthlyTrendsPage
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 160)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
    }
    
    // MARK: - Monthly Analysis Card Pages
    private var monthlyHabitSpotlightPage: some View {
        VStack(spacing: 16) {
            if let topHabit = getTopPerformingHabit() {
                // Main content
                HStack(spacing: 16) {
                    // Star icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.25), Color.blue.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    
                    // Content with habit info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Champion")
                            .font(.appLabelMedium)
                            .foregroundColor(.text02)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                        
                        Text(topHabit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text01)
                            .lineLimit(2)
                        
                        let rate = getMonthlyHabitProgressPercentage(for: topHabit)
                        Text("\(Int(rate * 100))% completion this month")
                            .font(.appBodyMedium)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Bottom motivational section
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("Outstanding monthly consistency!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                // Empty state when no habits
                VStack(spacing: 12) {
                    Text("No habits to highlight yet")
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                    
                    Text("Complete some habits this month to see your champion!")
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var monthlyTrendsPage: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Trend icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [getMonthlyTrendColor().opacity(0.25), getMonthlyTrendColor().opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: getMonthlyTrendIcon())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(getMonthlyTrendColor())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(getMonthlyTrendTitle())
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text(getMonthlyTrendDescription())
                        .font(.appBodyMedium)
                        .foregroundColor(.text02)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            
            // Trend insight with better formatting
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(getMonthlyTrendColor())
                    
                    Text("Monthly Analysis")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                }
                
                Text(getMonthlyTrendInsight())
                    .font(.appBodySmall)
                    .foregroundColor(.text03)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var monthlyInsightsPage: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Lightbulb icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Insights")
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text01)
                    
                    Text("Personalized tips for your journey")
                        .font(.appBodySmall)
                        .foregroundColor(.text02)
                }
                
                Spacer()
            }
            
            // Insight content with better formatting
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text("This Month's Focus")
                        .font(.appLabelMedium)
                        .foregroundColor(.text02)
                }
                
                Text(getMonthlyInsight())
                    .font(.appBodySmall)
                    .foregroundColor(.text03)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Monthly Progress Helper Functions
    private func getMonthlyProgressPercentage() -> Double {
        let scheduledCount = getMonthlyScheduledHabitsCount()
        guard scheduledCount > 0 else { return 0.0 }
        
        let completedCount = getMonthlyCompletedHabitsCount()
        return Double(completedCount) / Double(scheduledCount)
    }
    
    private func getMonthlyEncouragingMessage() -> String {
        let progressPercentage = getMonthlyProgressPercentage()
        let completedCount = getMonthlyCompletedHabitsCount()
        let scheduledCount = getMonthlyScheduledHabitsCount()
        
        // Handle edge cases
        if scheduledCount == 0 {
            return "No habits scheduled this month yet"
        }
        
        if completedCount == 0 {
            return "Ready to start your month strong! 💪"
        }
        
        // Generate encouraging messages based on completion rate
        switch progressPercentage {
        case 0.9...1.0:
            return ["You're absolutely crushing it this month! 🔥", "Incredible progress this month! ⭐", "You're on fire! Keep it up! 🚀", "Outstanding work this month! 💯"].randomElement() ?? "Amazing progress!"
            
        case 0.7..<0.9:
            return ["Great job this month! 🌟", "You're doing fantastic! ✨", "Excellent progress! Keep going! 💪", "You're building great momentum! 🎯"].randomElement() ?? "Great progress!"
            
        case 0.5..<0.7:
            return ["Good progress this month! 👍", "You're on the right track! 🎯", "Keep up the good work! 💪", "Steady progress! 🌱"].randomElement() ?? "Good progress!"
            
        case 0.3..<0.5:
            return ["Making progress this month! 🌱", "Every step counts! 👣", "You're building momentum! ⚡", "Keep pushing forward! 💪"].randomElement() ?? "Making progress!"
            
        default:
            return ["Start small and build momentum! 🌱", "Every habit counts! 💪", "You've got this! 🎯", "Small steps lead to big changes! 🚀"].randomElement() ?? "Keep going!"
        }
    }
    
    private func getMonthlyScheduledHabitsCount() -> Int {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: selectedProgressDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0
        }
        
        var totalScheduled = 0
        for habit in habitRepository.habits {
            var currentDate = monthStart
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    totalScheduled += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        return totalScheduled
    }
    
    private func getMonthlyCompletedHabitsCount() -> Int {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: selectedProgressDate)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)?.addingTimeInterval(-1) else {
            return 0
        }
        
        var totalCompleted = 0
        for habit in habitRepository.habits {
            var currentDate = monthStart
            while currentDate <= monthEnd {
                if StreakDataCalculator.shouldShowHabitOnDate(habit, date: currentDate) {
                    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
                    let progress = habit.getProgress(for: currentDate)
                    if progress >= goalAmount {
                        totalCompleted += 1
                    }
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        return totalCompleted
    }
    
    private func getMonthlyHabitProgressPercentage(for habit: Habit) -> Double {
        return ProgressCalculationLogic.monthlyHabitCompletionRate(for: habit, currentDate: selectedProgressDate)
    }
    
    private func getMonthlyTrendTitle() -> String {
        let progressPercentage = getMonthlyProgressPercentage()
        
        switch progressPercentage {
        case 0.8...1.0:
            return "Outstanding Month!"
        case 0.6..<0.8:
            return "Great Progress"
        case 0.4..<0.6:
            return "Steady Improvement"
        case 0.2..<0.4:
            return "Building Momentum"
        default:
            return "Getting Started"
        }
    }
    
    private func getMonthlyTrendDescription() -> String {
        let progressPercentage = getMonthlyProgressPercentage()
        let completedCount = getMonthlyCompletedHabitsCount()
        let scheduledCount = getMonthlyScheduledHabitsCount()
        
        if scheduledCount == 0 {
            return "No habits scheduled this month"
        }
        
        switch progressPercentage {
        case 0.8...1.0:
            return "\(completedCount) habits completed this month"
        case 0.6..<0.8:
            return "\(completedCount) of \(scheduledCount) habits completed"
        case 0.4..<0.6:
            return "\(completedCount) of \(scheduledCount) habits completed"
        case 0.2..<0.4:
            return "\(completedCount) of \(scheduledCount) habits completed"
        default:
            return "\(completedCount) of \(scheduledCount) habits completed"
        }
    }
    
    private func getMonthlyTrendIcon() -> String {
        let progressPercentage = getMonthlyProgressPercentage()
        
        switch progressPercentage {
        case 0.8...1.0:
            return "arrow.up.circle.fill"
        case 0.6..<0.8:
            return "arrow.up.circle"
        case 0.4..<0.6:
            return "minus.circle"
        case 0.2..<0.4:
            return "arrow.down.circle"
        default:
            return "circle"
        }
    }
    
    private func getMonthlyTrendColor() -> Color {
        let progressPercentage = getMonthlyProgressPercentage()
        
        switch progressPercentage {
        case 0.8...1.0:
            return .green500
        case 0.6..<0.8:
            return .green400
        case 0.4..<0.6:
            return .yellow500
        case 0.2..<0.4:
            return .red400
        default:
            return .grey500
        }
    }
    
    private func getMonthlyTrendInsight() -> String {
        let progressPercentage = getMonthlyProgressPercentage()
        let completedCount = getMonthlyCompletedHabitsCount()
        let scheduledCount = getMonthlyScheduledHabitsCount()
        
        switch progressPercentage {
        case 0.8...1.0:
            return "Outstanding monthly consistency! You've completed \(completedCount) habits with \(Int(progressPercentage * 100))% success rate. This level of dedication is building powerful long-term habits."
        case 0.6..<0.8:
            return "Strong monthly performance! You've completed \(completedCount) of \(scheduledCount) habits. You're building excellent momentum - consider adding one more habit to your routine."
        case 0.4..<0.6:
            return "Good progress this month! You've completed \(completedCount) of \(scheduledCount) habits. Focus on consistency by setting specific times for your habits each day."
        case 0.2..<0.4:
            return "You've completed \(completedCount) of \(scheduledCount) habits this month. Every step counts! Try to complete 2-3 more habits this week to build momentum."
        default:
            return "You've completed \(completedCount) of \(scheduledCount) habits this month. Start small and build momentum - even one completed habit is progress toward your goals!"
        }
    }
    
    private func getMonthlyInsight() -> String {
        let completedCount = getMonthlyCompletedHabitsCount()
        let scheduledCount = getMonthlyScheduledHabitsCount()
        let progressPercentage = getMonthlyProgressPercentage()
        
        if scheduledCount == 0 {
            return "Start your monthly journey by adding 2-3 simple habits. Focus on consistency over complexity - even 5 minutes daily can create lasting change."
        }
        
        if completedCount == 0 {
            return "Begin with one small habit this week. Set a specific time and place for it. Once it feels natural, add another. Small wins build big momentum."
        }
        
        // More specific and actionable insights based on performance
        switch progressPercentage {
        case 0.8...1.0:
            let insights = [
                "You're in the top 10% of habit builders! Consider sharing your success with others or mentoring someone on their journey.",
                "Your consistency is remarkable. This is the perfect time to add a challenging new habit or increase the difficulty of existing ones.",
                "You've mastered the fundamentals. Try habit stacking - attach a new habit to one you already do consistently."
            ]
            return insights.randomElement() ?? insights[0]
            
        case 0.6..<0.8:
            let insights = [
                "Excellent progress! You're building strong neural pathways. Try the '2-minute rule' for any habits you're struggling with.",
                "You're in the consistency sweet spot. Consider adding one more habit or increasing the frequency of your best-performing habit.",
                "Great momentum! Track your energy levels during habit completion to optimize your timing for maximum success."
            ]
            return insights.randomElement() ?? insights[0]
            
        case 0.4..<0.6:
            let insights = [
                "Good foundation! Focus on the 'why' behind each habit. Write down your reasons and review them when motivation dips.",
                "You're building momentum. Try habit bundling - pair a difficult habit with something you enjoy to increase completion rates.",
                "Steady progress! Identify your most successful habit and use its pattern to improve others. What makes it work for you?"
            ]
            return insights.randomElement() ?? insights[0]
            
        case 0.2..<0.4:
            let insights = [
                "Every step counts! Start with the easiest habit and build confidence. Success breeds success.",
                "Focus on one habit at a time. Master it completely before adding another. Quality over quantity wins the long game.",
                "You're learning what works for you. Try different times of day or environments to find your optimal habit conditions."
            ]
            return insights.randomElement() ?? insights[0]
            
        default:
            let insights = [
                "Start with micro-habits - 1 minute of your chosen activity. It's about building the routine, not the duration.",
                "Create a simple trigger for your habit. For example, 'After I brush my teeth, I will do X for 2 minutes.'",
                "Track your progress visually. A simple checkmark on a calendar can provide powerful motivation to maintain streaks."
            ]
            return insights.randomElement() ?? insights[0]
        }
    }
    
    // MARK: - Weekly Difficulty Graph
    private var weeklyDifficultyGraph: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Difficulty Trends")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Text("How challenging this habit felt this week")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
            }
            .padding(.bottom, 8)
            
            // Graph content
            if let habit = selectedHabit {
                let difficultyData = getWeeklyDifficultyData(for: habit)
                
                if difficultyData.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(.outline3)
                        
                        Text("No difficulty data yet")
                            .font(.appBodyMedium)
                            .foregroundColor(.text02)
                        
                        Text("Complete this habit a few times to see your difficulty trends")
                            .font(.appBodySmall)
                            .foregroundColor(.text03)
                            .multilineTextAlignment(.center)
                        
                        // Test button to add sample data
                        Button("Add Sample Data (Test)") {
                            // Add some sample difficulty data for testing
                            let calendar = Calendar.current
                            let today = Date()
                            for i in 0..<3 {
                                if let testDate = calendar.date(byAdding: .day, value: -i, to: today) {
                                    habitRepository.saveDifficultyRating(habitId: habit.id, date: testDate, difficulty: Int32(3 + i))
                                }
                            }
                        }
                        .font(.appBodySmall)
                        .foregroundColor(.primaryFocus)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    // Difficulty chart
                    DifficultyLineChart(
                        data: difficultyData,
                        weekStartDate: selectedWeekStartDate
                    )
                    .frame(height: 200)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
    }
    
    // MARK: - Monthly Difficulty Graph
    private var monthlyDifficultyGraph: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Difficulty Trends")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Text("How challenging this habit felt this month")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
            }
            .padding(.bottom, 8)
            
            // Graph content
            if let habit = selectedHabit {
                let difficultyData = getMonthlyDifficultyData(for: habit)
                
                if difficultyData.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(.outline3)
                        
                        Text("No difficulty data yet")
                            .font(.appBodyMedium)
                            .foregroundColor(.text02)
                        
                        Text("Complete this habit a few times to see your difficulty trends")
                            .font(.appBodySmall)
                            .foregroundColor(.text03)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    // Monthly difficulty chart
                    MonthlyDifficultyChart(
                        data: difficultyData,
                        monthStartDate: selectedProgressDate
                    )
                    .frame(height: 200)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
    }
    
    // MARK: - Time Base Completion Chart
    private var timeBaseCompletionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Time base completion")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                
                Text("When you typically complete this habit")
                    .font(.appBodySmall)
                    .foregroundColor(.text02)
            }
            .padding(.bottom, 8)
            
            // Chart content
            if let habit = selectedHabit {
                let timeData = getTimeBaseCompletionData(for: habit)
                
                if timeData.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 32))
                            .foregroundColor(.outline3)
                        
                        Text("No completion data yet")
                            .font(.appBodyMedium)
                            .foregroundColor(.text02)
                        
                        Text("Complete this habit a few times to see your time patterns")
                            .font(.appBodySmall)
                            .foregroundColor(.text03)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 200)
                } else {
                    TimeBaseCompletionChart(data: timeData)
                        .frame(height: 320)
                        .padding(.bottom, 20)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.outline3, lineWidth: 1.0)
        )
    }
    
    // MARK: - Time Base Completion Data Helper
    private func getTimeBaseCompletionData(for habit: Habit) -> [TimeCompletionData] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        // Get all habit completion records for this week
        let habitLogs = habit.completionHistory.compactMap { (dateString, progress) -> (timestamp: Date, progress: Int)? in
            guard let date = ISO8601DateHelper.shared.date(from: dateString) else { return nil }
            return (timestamp: date, progress: progress)
        }.filter { log in
            return log.timestamp >= weekStart && log.timestamp <= weekEnd
        }
        
        // Define time periods
        let timePeriods = [
            ("Morning", 6, 12),    // 6 AM - 12 PM
            ("Lunch", 12, 14),     // 12 PM - 2 PM
            ("Evening", 14, 20),   // 2 PM - 8 PM
            ("Night", 20, 24)      // 8 PM - 12 AM
        ]
        
        var timeData: [TimeCompletionData] = []
        
        for (periodName, startHour, endHour) in timePeriods {
            // Count completions in this time period
            let completionsInPeriod = habitLogs.filter { log in
                let hour = calendar.component(.hour, from: log.timestamp)
                return hour >= startHour && hour < endHour
            }.count
            
            // Calculate total possible completions (assuming daily habit)
            let totalDays = calendar.dateComponents([.day], from: weekStart, to: weekEnd).day ?? 7
            let completionRate = totalDays > 0 ? Double(completionsInPeriod) / Double(totalDays) : 0.0
            
            timeData.append(TimeCompletionData(
                timePeriod: periodName,
                completionRate: completionRate,
                completionCount: completionsInPeriod,
                totalDays: totalDays
            ))
        }
        
        return timeData
    }
    
    // MARK: - Weekly Difficulty Data Helper
    private func getWeeklyDifficultyData(for habit: Habit) -> [DifficultyDataPoint] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        let weekStart = selectedWeekStartDate
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        // Ensure we include the current day if it's within the week
        let today = Date()
        let adjustedWeekEnd = max(weekEnd, today)
        
        var dataPoints: [DifficultyDataPoint] = []
        
        // Get difficulty logs for the week directly from habit's difficulty history
        var difficultyLogs: [(date: Date, difficulty: Int)] = []
        
        for (dateKey, difficulty) in habit.difficultyHistory {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateKey) else { continue }
            
            if date >= weekStart && date <= adjustedWeekEnd {
                difficultyLogs.append((date: date, difficulty: difficulty))
            }
        }
        
        // Sort by date
        difficultyLogs.sort { $0.date < $1.date }
        
        // Debug: Print week range and found logs
        print("🔍 Week range: \(weekStart) to \(adjustedWeekEnd)")
        print("🔍 Found \(difficultyLogs.count) difficulty logs in this week")
        for log in difficultyLogs {
            print("🔍 Log: \(log.date) - Difficulty: \(log.difficulty)")
        }
        
        // Group by day and get average difficulty for each day
        let groupedByDay = Dictionary(grouping: difficultyLogs) { log in
            calendar.startOfDay(for: log.date)
        }
        
        // Create data points for each day of the week
        for dayOffset in 0..<7 {
            let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            let dayStart = calendar.startOfDay(for: currentDay)
            
            if let dayLogs = groupedByDay[dayStart], !dayLogs.isEmpty {
                // Calculate average difficulty for the day
                let totalDifficulty = dayLogs.reduce(0) { sum, log in
                    sum + log.difficulty
                }
                let averageDifficulty = Double(totalDifficulty) / Double(dayLogs.count)
                
                print("🔍 Day \(dayOffset): \(currentDay) - Has data: \(averageDifficulty)")
                
                dataPoints.append(DifficultyDataPoint(
                    date: currentDay,
                    difficulty: averageDifficulty,
                    hasData: true
                ))
            } else {
                print("🔍 Day \(dayOffset): \(currentDay) - No data")
                dataPoints.append(DifficultyDataPoint(
                    date: currentDay,
                    difficulty: 0,
                    hasData: false
                ))
            }
        }
        
        print("🔍 Total data points created: \(dataPoints.count)")
        return dataPoints
    }
    
    // MARK: - Monthly Difficulty Data Helper
    private func getMonthlyDifficultyData(for habit: Habit) -> [MonthlyDifficultyDataPoint] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        
        // Get the start and end of the current month
        let monthStart = calendar.dateInterval(of: .month, for: selectedProgressDate)?.start ?? selectedProgressDate
        let monthEnd = calendar.dateInterval(of: .month, for: selectedProgressDate)?.end ?? selectedProgressDate
        
        // Ensure we include the current day if it's within the month
        let today = Date()
        let adjustedMonthEnd = min(monthEnd, today)
        
        var dataPoints: [MonthlyDifficultyDataPoint] = []
        
        // Get difficulty logs for the month directly from habit's difficulty history
        var difficultyLogs: [(date: Date, difficulty: Int)] = []
        
        for (dateKey, difficulty) in habit.difficultyHistory {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateKey) else { continue }
            
            if date >= monthStart && date <= adjustedMonthEnd {
                difficultyLogs.append((date: date, difficulty: difficulty))
            }
        }
        
        // Sort by date
        difficultyLogs.sort { $0.date < $1.date }
        
        // Calculate the actual end of the month (not adjusted for today)
        let actualMonthEnd = calendar.dateInterval(of: .month, for: selectedProgressDate)?.end ?? selectedProgressDate
        
        // Debug: Print month range and found logs
        print("🔍 Month range: \(monthStart) to \(adjustedMonthEnd)")
        print("🔍 Actual month end: \(actualMonthEnd)")
        print("🔍 Found \(difficultyLogs.count) difficulty logs in this month")
        
        // Get all weeks in the month - iterate through each week
        var currentWeek = monthStart
        var weekIndex = 0
        
        while currentWeek < actualMonthEnd && weekIndex < 6 { // Max 6 weeks in a month
            let weekStart = calendar.startOfDay(for: currentWeek)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            
            print("🔍 Processing week \(weekIndex + 1): currentWeek=\(currentWeek), weekStart=\(weekStart), weekEnd=\(weekEnd), actualMonthEnd=\(actualMonthEnd)")
            
            // Filter logs for this specific week
            let weekLogs = difficultyLogs.filter { log in
                return log.date >= weekStart && log.date <= weekEnd
            }
            
            if !weekLogs.isEmpty {
                // Calculate average difficulty for the week
                let totalDifficulty = weekLogs.reduce(0) { sum, log in
                    sum + log.difficulty
                }
                let averageDifficulty = Double(totalDifficulty) / Double(weekLogs.count)
                
                print("🔍 Week \(weekIndex + 1): \(weekStart) to \(weekEnd) - Has data: \(averageDifficulty) (from \(weekLogs.count) logs)")
                
                dataPoints.append(MonthlyDifficultyDataPoint(
                    weekStartDate: weekStart,
                    difficulty: averageDifficulty,
                    hasData: true
                ))
            } else {
                print("🔍 Week \(weekIndex + 1): \(weekStart) to \(weekEnd) - No data")
                dataPoints.append(MonthlyDifficultyDataPoint(
                    weekStartDate: weekStart,
                    difficulty: 0,
                    hasData: false
                ))
            }
            
            // Move to next week
            currentWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
            weekIndex += 1
        }
        
        print("🔍 Total monthly data points created: \(dataPoints.count)")
        for (index, point) in dataPoints.enumerated() {
            print("🔍 Monthly data point \(index): Week \(index + 1) - Difficulty: \(point.difficulty), HasData: \(point.hasData)")
        }
        return dataPoints
    }
}

// MARK: - Time Completion Data Point
struct TimeCompletionData: Identifiable {
    let id = UUID()
    let timePeriod: String
    let completionRate: Double
    let completionCount: Int
    let totalDays: Int
}

// MARK: - Time Base Completion Chart
struct TimeBaseCompletionChart: View {
    let data: [TimeCompletionData]
    
    private var timeCompletionBanner: some View {
        let bestTime = data.max(by: { $0.completionRate < $1.completionRate })
        
        guard let bestTime = bestTime else { return AnyView(EmptyView()) }
        
        let isDayTime = bestTime.timePeriod == "Morning" || bestTime.timePeriod == "Afternoon"
        
        return AnyView(
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(bestTime.timePeriod)!")
                        .font(.appBodySmallEmphasised)
                        .foregroundColor(isDayTime ? Color(hex: "296399") : Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("This habit tends to be more successful in the \(bestTime.timePeriod.lowercased())")
                        .font(.appBodySmallEmphasised)
                        .foregroundColor(isDayTime ? Color(hex: "296399") : Color.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(bestTime.timePeriod)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 150, maxHeight: 80)
                    .clipped()
                    .padding(.trailing, -20)
            }
                    .padding(.leading, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: isDayTime ? "C9E5FF" : "121E3D"))
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main chart area with Y-axis labels
            HStack(alignment: .bottom, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(0...4, id: \.self) { index in
                        let percentage = 100 - (index * 25)
                        Text("\(percentage)%")
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                            .frame(height: 40)
                    }
                }
                .frame(width: 40)
                
                // Chart area
                GeometryReader { geometry in
                    ZStack {
                        // Background grid
                        backgroundGrid(in: geometry)
                        
                        // Bars
                        bars(in: geometry)
                    }
                }
                .frame(height: 160)
            }
            
            // X-axis labels
            HStack {
                Spacer().frame(width: 40) // Align with chart area
                
                ForEach(data, id: \.id) { item in
                    Text(item.timePeriod)
                        .font(.appLabelSmall)
                        .foregroundColor(.text02)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Spacer above banner
            Spacer()
                .frame(height: 16)
            
            // Time completion banner
            timeCompletionBanner
        }
    }
    
    private func backgroundGrid(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        return Path { path in
            // Horizontal grid lines (0% at bottom, 100% at top)
            // Align with Y-axis labels (40pt spacing, centered in each row)
            for i in 0...4 {
                let y = height - (CGFloat(4 - i) * 40.0) - 20.0 // 0% line at bottom
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.outline3.opacity(0.3), lineWidth: 0.5)
    }
    
    private func bars(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let barWidth = width / CGFloat(data.count) * 0.7
        
        return ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                // Calculate bar height based on the same coordinate system as grid lines
                // Each grid line is 40pt apart, so we need to scale the completion rate accordingly
                let maxBarHeight = 40.0 * 4 // 4 grid intervals (0% to 100%)
                let barHeight = maxBarHeight * item.completionRate
                
                // Position the bar so it starts exactly at the 0% line
                // The 0% line is at y = height - 20.0 (from the grid calculation)
                let zeroLineY = height - 20.0
                let barY = zeroLineY - barHeight
                
                // Calculate horizontal position - center each bar in its column
                let columnWidth = width / CGFloat(data.count)
                let barX = columnWidth * CGFloat(index) + columnWidth / 2
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0.6)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: barWidth, height: barHeight)
                    .position(x: barX, y: barY + barHeight / 2)
            }
        }
    }
}

// MARK: - Difficulty Data Point
struct DifficultyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let difficulty: Double
    let hasData: Bool
}

// MARK: - Monthly Difficulty Data Point
struct MonthlyDifficultyDataPoint: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let difficulty: Double
    let hasData: Bool
}

// MARK: - Difficulty Line Chart
struct DifficultyLineChart: View {
    let data: [DifficultyDataPoint]
    let weekStartDate: Date
    
    private let calendar = AppDateFormatter.shared.getUserCalendar()
    private var dayNames: [String] {
        let calendar = AppDateFormatter.shared.getUserCalendar()
        if calendar.firstWeekday == 1 { // Sunday
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        } else { // Monday
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main chart area with Y-axis labels
            HStack(alignment: .top, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<5, id: \.self) { level in
                        let difficultyLevel = 5 - level // 5, 4, 3, 2, 1
                        
                        Text(difficultyLabel(for: difficultyLevel))
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                            .frame(height: 140/4, alignment: .center)
                    }
                }
                .frame(width: 60, height: 140)
                
                // Main chart area
                GeometryReader { geometry in
                    ZStack {
                        // Background grid
                        backgroundGrid(in: geometry)
                        
                        // Shaded area under the line
                        shadedArea(in: geometry)
                        
                        // Difficulty line - drawn first so it appears behind the images
                        difficultyLine(in: geometry)
                        
                        // Data points - drawn last so they appear on top of the line
                        dataPoints(in: geometry)
                    }
                }
                .frame(height: 140)
            }
            
            // X-axis labels
            GeometryReader { labelGeometry in
                HStack {
                    // Spacer to align with chart area (accounting for Y-axis labels)
                    Spacer()
                        .frame(width: 60)
                    
                    ZStack {
                        ForEach(0..<7, id: \.self) { index in
                            let dayDate = calendar.date(byAdding: .day, value: index, to: weekStartDate) ?? weekStartDate
                            let dayName = getDayAbbreviation(for: dayDate)
                            
                            // Use the same positioning logic as data points
                            let availableWidth = labelGeometry.size.width - 60 // Subtract spacer width
                            let stepX = availableWidth / CGFloat(6) // 6 steps for 7 days (0-6)
                            let x = CGFloat(index) * stepX
                            
                            Text(dayName)
                                .font(.appLabelSmall)
                                .foregroundColor(.text02)
                                .position(x: x, y: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 20)
            .padding(.top, 16)
        }
    }
    
    private func difficultyLabel(for level: Int) -> String {
        switch level {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return ""
        }
    }
    
    private func getDayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func backgroundGrid(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { level in
                Rectangle()
                    .fill(Color.outline3.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                
                if level < 4 {
                    Spacer()
                }
            }
        }
    }
    
    
    private func shadedArea(in geometry: GeometryProxy) -> some View {
        let validData = data.filter { $0.hasData }
        
        if validData.count < 2 {
            return AnyView(EmptyView())
        }
        
        let width = geometry.size.width
        let height = geometry.size.height
        let stepX = width / CGFloat(data.count - 1)
        
        var path = Path()
        
        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: height))
        
        // Add line points
        for (index, point) in validData.enumerated() {
            let originalIndex = data.firstIndex { $0.date == point.date } ?? index
            let x = CGFloat(originalIndex) * stepX
            // Invert the grid level: difficulty 1 (very easy) at bottom, difficulty 5 (very hard) at top
            let gridLevel = 4 - (Int(point.difficulty) - 1) // Convert 1-5 to 4-0
            let gridSpacing = height / 4.0
            let y = CGFloat(gridLevel) * gridSpacing
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the path to bottom right
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        return AnyView(
            path
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
    
    private func difficultyLine(in geometry: GeometryProxy) -> some View {
        let validData = data.filter { $0.hasData }
        
        if validData.count < 2 {
            return AnyView(EmptyView())
        }
        
        let width = geometry.size.width
        let height = geometry.size.height
        let stepX = width / CGFloat(data.count - 1)
        
        var path = Path()
        
        for (index, point) in validData.enumerated() {
            // Find the original index in the full data array
            let originalIndex = data.firstIndex { $0.date == point.date } ?? index
            let x = CGFloat(originalIndex) * stepX
            // Align with grid lines: difficulty 1 (very easy) at bottom, difficulty 5 (very hard) at top
            // Invert the grid level: difficulty 1 (very easy) at bottom, difficulty 5 (very hard) at top
            let gridLevel = 4 - (Int(point.difficulty) - 1) // Convert 1-5 to 4-0
            let gridSpacing = height / 4.0 // 4 spacings between 5 grid lines
            let y = CGFloat(gridLevel) * gridSpacing
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return AnyView(
            path
                .stroke(
                    Color.blue.opacity(0.9),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
        )
    }
    
    private func dataPoints(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let stepX = width / CGFloat(data.count - 1)
        
        return ForEach(Array(data.enumerated()), id: \.offset) { index, point in
            if point.hasData {
                let x = CGFloat(index) * stepX
                // Align with grid lines: difficulty 1 (very easy) at bottom, difficulty 5 (very hard) at top
                // Invert the grid level: difficulty 1 (very easy) at bottom, difficulty 5 (very hard) at top
                let gridLevel = 4 - (Int(point.difficulty) - 1) // Convert 1-5 to 4-0
                let gridSpacing = height / 4.0 // 4 spacings between 5 grid lines
                let y = CGFloat(gridLevel) * gridSpacing
                
                ZStack {
                    // White background circle with subtle shadow
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Color.grey300, lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Difficulty image
                    Image(difficultyImageName(for: point.difficulty))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                .position(x: x, y: y)
            }
        }
    }
    
    private func difficultyColor(for difficulty: Double) -> Color {
        switch Int(round(difficulty)) {
        case 1: return .green
        case 2: return .mint
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .grey500
        }
    }
    
    private func difficultyImageName(for difficulty: Double) -> String {
        switch Int(round(difficulty)) {
        case 1: return "Difficulty-VeryEasy@4x"
        case 2: return "Difficulty-Easy@4x"
        case 3: return "Difficulty-Medium@4x"
        case 4: return "Difficulty-Hard@4x"
        case 5: return "Difficulty-VeryHard@4x"
        default: return "Difficulty-Medium@4x"
        }
    }
}

// MARK: - Date Extension
extension Date {
    func get(_ component: Calendar.Component) -> Int {
        return Calendar.current.component(component, from: self)
    }
}

// MARK: - Monthly Difficulty Chart
struct MonthlyDifficultyChart: View {
    let data: [MonthlyDifficultyDataPoint]
    let monthStartDate: Date
    
    private let calendar = AppDateFormatter.shared.getUserCalendar()
    
    var body: some View {
        VStack(spacing: 12) {
            // Main chart area with Y-axis labels
            HStack(alignment: .top, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<5, id: \.self) { level in
                        let difficultyLevel = 5 - level // 5, 4, 3, 2, 1
                        
                        Text(difficultyLabel(for: difficultyLevel))
                            .font(.appLabelSmall)
                            .foregroundColor(.text02)
                            .frame(height: 140/4, alignment: .center)
                    }
                }
                .frame(width: 60, height: 140)
                
                // Main chart area
                GeometryReader { geometry in
                    ZStack {
                        // Background grid
                        backgroundGrid(in: geometry)
                        
                        // Shaded area under the line
                        shadedArea(in: geometry)
                        
                        // Difficulty line - drawn first so it appears behind the images
                        difficultyLine(in: geometry)
                        
                        // Data points - drawn last so they appear on top of the line
                        dataPoints(in: geometry)
                    }
                }
                .frame(height: 140)
            }
            
            // X-axis labels
            GeometryReader { labelGeometry in
                HStack {
                    // Spacer to align with chart area (accounting for Y-axis labels)
                    Spacer()
                        .frame(width: 60)
                    
                    ZStack {
                        if data.count > 0 {
                        ForEach(0..<data.count, id: \.self) { index in
                            let weekLabel = "W\(index + 1)"
                                
                                // Apply padding to the chart area, then distribute labels evenly within that space
                                let availableWidth = labelGeometry.size.width - 60 // Subtract spacer width
                                let padding: CGFloat = 20
                                let chartWidth = availableWidth - (padding * 2) // Subtract padding from both sides
                                let stepX = data.count > 1 ? chartWidth / CGFloat(data.count - 1) : 0
                                let x = padding + (CGFloat(index) * stepX) // Start from padding position
                                
                                Text(weekLabel)
                                    .font(.appLabelSmall)
                                    .foregroundColor(.text02)
                                    .position(x: x, y: 10) // Position at bottom of the GeometryReader
                            }
                        } else {
                            // Show placeholder when no data - always show at least one label
                            Text("W1")
                                .font(.appLabelSmall)
                                .foregroundColor(.text02)
                                .position(x: (labelGeometry.size.width - 60) / 2, y: 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 20)
            .padding(.top, 16)
        }
    }
    
    
    private func difficultyLabel(for difficulty: Int) -> String {
        switch difficulty {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return ""
        }
    }
    
    private func difficultyImageName(for difficulty: Double) -> String {
        switch Int(difficulty) {
        case 1: return "Difficulty-VeryEasy@4x"
        case 2: return "Difficulty-Easy@4x"
        case 3: return "Difficulty-Medium@4x"
        case 4: return "Difficulty-Hard@4x"
        case 5: return "Difficulty-VeryHard@4x"
        default: return "Difficulty-Medium@4x"
        }
    }
    
    private func backgroundGrid(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        return Path { path in
            // Horizontal grid lines
            for i in 0...4 {
                let y = CGFloat(i) * (height / 4.0)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.outline3.opacity(0.3), lineWidth: 0.5)
    }
    
    private func shadedArea(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let validData = data.filter { $0.hasData }
        
        guard validData.count > 1 else { 
            return AnyView(EmptyView())
        }
        
        // Use the same padding logic as X-axis labels and data points
        let padding: CGFloat = 20
        let chartWidth = width - (padding * 2)
        let stepX = data.count > 1 ? chartWidth / CGFloat(data.count - 1) : 0
        
        return AnyView(
            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, point) in validData.enumerated() {
                    let originalIndex = data.firstIndex { $0.id == point.id } ?? 0
                    let x = padding + (CGFloat(originalIndex) * stepX) // Start from padding position
                    let gridLevel = 4 - (Int(point.difficulty) - 1)
                    let gridSpacing = height / 4.0
                    let y = CGFloat(gridLevel) * gridSpacing
                    
                    if index == 0 {
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                path.addLine(to: CGPoint(x: width - padding, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }
    
    private func difficultyLine(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let validData = data.filter { $0.hasData }
        
        guard validData.count > 1 else { 
            return AnyView(EmptyView())
        }
        
        // Use the same padding logic as X-axis labels and data points
        let padding: CGFloat = 20
        let chartWidth = width - (padding * 2)
        let stepX = data.count > 1 ? chartWidth / CGFloat(data.count - 1) : 0
        
        return AnyView(
            Path { path in
                for (index, point) in validData.enumerated() {
                    let originalIndex = data.firstIndex { $0.id == point.id } ?? 0
                    let x = padding + (CGFloat(originalIndex) * stepX) // Start from padding position
                    let gridLevel = 4 - (Int(point.difficulty) - 1)
                    let gridSpacing = height / 4.0
                    let y = CGFloat(gridLevel) * gridSpacing
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                Color.blue.opacity(0.9),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        )
    }
    
    private func dataPoints(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        // Use the same padding logic as X-axis labels
        let padding: CGFloat = 20
        let chartWidth = width - (padding * 2)
        let stepX = data.count > 1 ? chartWidth / CGFloat(data.count - 1) : 0
        
        return ForEach(Array(data.enumerated()), id: \.offset) { index, point in
            if point.hasData {
                let x = padding + (CGFloat(index) * stepX) // Start from padding position
                let gridLevel = 4 - (Int(point.difficulty) - 1)
                let gridSpacing = height / 4.0
                let y = CGFloat(gridLevel) * gridSpacing
                
                ZStack {
                    // White background circle with subtle shadow
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Color.grey300, lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Difficulty image
                    Image(difficultyImageName(for: point.difficulty))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                .position(x: x, y: y)
            }
        }
    }
}

// MARK: - Animated Circular Progress Ring
struct AnimatedCircularProgressRing: View {
    let progress: Double
    let size: CGFloat
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle (unfilled part)
            Circle()
                .stroke(Color.primaryContainer, lineWidth: 8)
                .frame(width: size, height: size)
            
            // Progress circle (filled part)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: animatedProgress)
            
            // Percentage text - always show actual progress, not animated value
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.appLabelMediumEmphasised)
                    .foregroundColor(.primaryFocus)
            }
        }
        .onAppear {
            // Always animate when the ring appears
            print("🔄 AnimatedCircularProgressRing onAppear - progress: \(progress)")
            animatedProgress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = progress
                    print("🔄 Animating to progress: \(progress)")
                }
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            // Animate to new progress value
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Helper Functions
private func pluralizeDay(_ count: Int) -> String {
    if count == 0 {
        return "0 day"
    } else if count == 1 {
        return "1 day"
    } else {
        return "\(count) days"
    }
}

// MARK: - Weekly Summary Stats View
struct WeeklySummaryStatsView: View {
    let completionRate: Int
    let bestStreak: Int
    let consistencyRate: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Completion Rate
            VStack(spacing: 4) {
                Text("\(completionRate)%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Completion")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline3)
                .frame(width: 1, height: 40)
            
            // Best Streak
            VStack(spacing: 4) {
                Text(pluralizeDay(bestStreak))
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Best Streak")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
            
            // Vertical divider
            Rectangle()
                .fill(.outline3)
                .frame(width: 1, height: 40)
            
            // Consistency Rate
            VStack(spacing: 4) {
                Text("\(consistencyRate)%")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                Text("Consistency")
                    .font(.appBodySmall)
                    .foregroundColor(.text04)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(.surfaceContainer)
        .cornerRadius(16)
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(HabitRepository.shared)
} 