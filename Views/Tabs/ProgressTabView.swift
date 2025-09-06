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
    // MARK: - State
    @State private var selectedTimePeriod = 0
    @State private var selectedHabit: Habit?
    @State private var selectedProgressDate = Date()
    @State private var showingHabitSelector = false
    @State private var showingDatePicker = false
    @State private var showingWeekPicker = false
    @State private var showingMonthPicker = false
    @State private var showingYearPicker = false
    @State private var selectedWeekStartDate: Date = Date()
    @State private var showingDifficultyExplanation = false
    @State private var testDifficultyValue: Double = 3.0
    @State private var showingAllReminders = false
    
    // Per-date reminder states: [dateKey: [reminderId: isEnabled]]
    @State private var reminderStates: [String: [UUID: Bool]] = [:]
    
    // MARK: - Environment
    @EnvironmentObject var coreDataAdapter: CoreDataAdapter
    @StateObject private var calendarHelper = ProgressCalendarHelper()
    
    // MARK: - Computed Properties
    private var habits: [Habit] {
        coreDataAdapter.habits
    }
    
    private var headerContent: some View {
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
                            .font(.system(size: 12, weight: .medium))
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
    
    var body: some View {
        ZStack {
            WhiteSheetContainer(
                headerContent: {
                    AnyView(headerContent)
                }
            ) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Date Selection
                        dateSelectionSection
                        
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
                                        .allowsHitTesting(false)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Reminders Section - Only show when "All habits" is selected and "Daily" tab is active
                        if selectedHabit == nil && selectedTimePeriod == 0 {
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
                        
                        
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingHabitSelector) {
            habitSelectorSheet
        }
        .overlay(
            // Date Picker Modal
            showingDatePicker ? AnyView(
                DatePickerModal(selectedDate: $selectedProgressDate, isPresented: $showingDatePicker)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingDatePicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Week Picker Modal
            showingWeekPicker ? AnyView(
                WeekPickerModal(selectedWeekStartDate: $selectedWeekStartDate, isPresented: $showingWeekPicker)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingWeekPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Month Picker Modal
            showingMonthPicker ? AnyView(
                MonthPickerModal(selectedMonth: $selectedProgressDate, isPresented: $showingMonthPicker)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingMonthPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Year Picker Modal
            showingYearPicker ? AnyView(
                YearPickerModal(selectedYear: .constant(selectedProgressDate.get(.year)), isPresented: $showingYearPicker)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingYearPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // All Reminders Modal
            showingAllReminders ? AnyView(
                allRemindersModal
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: showingAllReminders)
            ) : AnyView(EmptyView())
        )
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
                        print("🔍 DEBUG: Date button tapped! selectedTimePeriod: \(selectedTimePeriod)")
                        if selectedTimePeriod == 0 { // Daily
                            showingDatePicker = true
                        } else if selectedTimePeriod == 1 { // Weekly
                            showingWeekPicker = true
                        } else if selectedTimePeriod == 2 { // Monthly
                            showingMonthPicker = true
                        } else if selectedTimePeriod == 3 { // Yearly
                            showingYearPicker = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(selectedTimePeriod == 0 ? formatDate(selectedProgressDate) :
                                 selectedTimePeriod == 1 ? formatWeek(selectedWeekStartDate) :
                                 selectedTimePeriod == 2 ? formatMonth(selectedProgressDate) :
                                 formatYear(selectedProgressDate))
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                                .opacity(0.7)
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
                    
                    Spacer()
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
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.outline3, lineWidth: 1)
                )
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
    
    // MARK: - Helper Functions for Calendar
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
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
            let progress = Double(coreDataAdapter.getProgress(for: habit, date: date))
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatWeek(_ date: Date) -> String {
        // Use the same calendar and calculation as WeekPickerModal
        let calendar = AppDateFormatter.shared.getUserCalendar()
        
        // Get the start of the week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekStart)
        let endString = formatter.string(from: weekEnd)
        
        return "\(startString) - \(endString)"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDate(selectedProgressDate, inSameDayAs: Date())
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
            let progress = coreDataAdapter.getProgress(for: habit, date: selectedProgressDate)
            let goalAmount = parseGoalAmount(from: habit.goal)
            return progress >= goalAmount
        }
        
        return completedHabits.count
    }
    
    private func getProgressPercentage() -> Double {
        let scheduledHabits = getScheduledHabitsForDate(selectedProgressDate)
        if scheduledHabits.isEmpty {
            return 0.0
        }
        
        let totalProgress = scheduledHabits.reduce(0.0) { total, habit in
            let progress = coreDataAdapter.getProgress(for: habit, date: selectedProgressDate)
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
    
    private func getCompletionPercentage() -> Double {
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
        return coreDataAdapter.habits.filter { habit in
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
            let difficultyLogs = coreDataAdapter.fetchDifficultyLogs(for: habit)
            let recentLogs = difficultyLogs.filter { log in
                guard let timestamp = log.timestamp else { return false }
                return Calendar.current.isDate(timestamp, inSameDayAs: date)
            }
            
            if let latestLog = recentLogs.last {
                return total + Double(latestLog.difficulty)
            } else {
                return total + 3.0 // Default to Medium if no logs
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