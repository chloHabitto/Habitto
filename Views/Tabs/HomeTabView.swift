import SwiftUI
import Combine
import SwiftData
import ViewAnimator

// Note: AuthenticationManager and CurrentUser are automatically available
// through the app's module since they're in the same target

struct HomeTabView: View {
    @Binding var selectedDate: Date
    @Binding var selectedStatsTab: Int
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentWeekOffset: Int = 0

    @State private var lastHapticWeek: Int = 0
    @State private var isDragging: Bool = false
    @State private var selectedHabit: Habit? = nil
    @State private var showCelebration: Bool = false
    @State private var showingCancelVacationAlert: Bool = false
    @State private var deferResort: Bool = false
    @State private var sortedHabits: [Habit] = []
    @State private var cancellables = Set<AnyCancellable>()
    @State private var lastHabitJustCompleted = false
    
    // ✅ PHASE 5: Prefetch completion status to prevent N+1 queries
    @State private var completionStatusMap: [UUID: Bool] = [:]
    
    #if DEBUG
    // Runtime tracking: verify service is called exactly once per flow
    @State private var debugGrantCalls: Int = 0
    @State private var debugRevokeCalls: Int = 0
    #endif
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var eventBus = EventBus.shared
    @StateObject private var awardService: DailyAwardService
    
    let habits: [Habit]
    let isLoadingHabits: Bool
    let onToggleHabit: (Habit, Date) -> Void
    let onUpdateHabit: ((Habit) -> Void)?
    let onSetProgress: ((Habit, Date, Int) -> Void)?
    let onDeleteHabit: ((Habit) -> Void)?
    let onCompletionDismiss: (() -> Void)?
    
    init(selectedDate: Binding<Date>, selectedStatsTab: Binding<Int>, habits: [Habit], isLoadingHabits: Bool, onToggleHabit: @escaping (Habit, Date) -> Void, onUpdateHabit: ((Habit) -> Void)?, onSetProgress: ((Habit, Date, Int) -> Void)?, onDeleteHabit: ((Habit) -> Void)?, onCompletionDismiss: (() -> Void)?) {
        self._selectedDate = selectedDate
        self._selectedStatsTab = selectedStatsTab
        self.habits = habits
        self.isLoadingHabits = isLoadingHabits
        self.onToggleHabit = onToggleHabit
        self.onUpdateHabit = onUpdateHabit
        self.onSetProgress = onSetProgress
        self.onDeleteHabit = onDeleteHabit
        self.onCompletionDismiss = onCompletionDismiss
        // Initialize DailyAwardService with proper error handling
        do {
            let container = try ModelContainer(for: DailyAward.self)
            self._awardService = StateObject(wrappedValue: DailyAwardService(modelContext: ModelContext(container)))
        } catch {
            // Fallback: create a new container as last resort
            // This should not happen in normal circumstances
            print("⚠️ HomeTabView: Failed to create ModelContainer for DailyAward: \(error)")
            // Create a minimal container for testing/fallback
            do {
                let fallbackContainer = try ModelContainer(for: DailyAward.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                self._awardService = StateObject(wrappedValue: DailyAwardService(modelContext: ModelContext(fallbackContainer)))
            } catch {
                // If even the fallback fails, create a dummy service
                print("❌ HomeTabView: Critical error - cannot create ModelContainer: \(error)")
                // This will cause a runtime error, but it's better than a crash
                fatalError("Cannot initialize DailyAwardService: \(error)")
            }
        }
        
        // Subscribe to event bus - will be handled in onAppear
    }
    
    // Performance optimization: Cached regex patterns
    private static let dayCountRegex = try? NSRegularExpression(pattern: "Every (\\d+) days?", options: .caseInsensitive)
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        mainContent
            .onAppear {
                let today = DateUtils.today()
                if Calendar.current.isDate(selectedDate, inSameDayAs: today) {
                    // No update needed
                } else {
                    selectedDate = today
                }
                
                // Initialize sorted habits
                resortHabits()
                
                // ✅ PHASE 5: Prefetch completion status to prevent N+1 queries
                Task {
                    await prefetchCompletionStatus()
                }
                
                // Subscribe to event bus
                eventBus.publisher()
                    .receive(on: DispatchQueue.main)
                    .sink { event in
                        switch event {
                        case .dailyAwardGranted(let dateKey):
                            print("🎯 STEP 12: Received dailyAwardGranted event for \(dateKey)")
                            print("🎯 STEP 12: Setting showCelebration = true")
                            showCelebration = true
                        case .dailyAwardRevoked(let dateKey):
                            print("🎯 STEP 12: Received dailyAwardRevoked event for \(dateKey)")
                            print("🎯 STEP 12: Setting showCelebration = false")
                            showCelebration = false
                        }
                    }
                    .store(in: &cancellables)
            }
            .onChange(of: habits) { oldHabits, newHabits in
                handleHabitsChange(oldHabits: oldHabits, newHabits: newHabits)
            }
            .fullScreenCover(item: $selectedHabit, content: habitDetailView)
            .overlay(celebrationOverlay)
            .onChange(of: habitsForSelectedDate) { oldHabits, newHabits in
                handleHabitsForSelectedDateChange(oldHabits, newHabits)
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                handleSelectedDateChange(oldDate, newDate)
                // ✅ PHASE 5: Refetch completion status when date changes
                Task {
                    await prefetchCompletionStatus()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .vacationModeEnded), perform: handleVacationModeEnded)
            .alert("Cancel Vacation", isPresented: $showingCancelVacationAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Vacation", role: .destructive) {
                    VacationManager.shared.cancelVacationForDate(selectedDate)
                }
            } message: {
                Text("Are you sure you want to end vacation mode for this date? This will resume all habit tracking.")
            }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        WhiteSheetContainer(
            headerContent: { AnyView(headerContent) },
            rightButton: { AnyView(rightButtonContent) }
        ) {
            habitsListSection
        }
    }
    
    // MARK: - Header Content
    @ViewBuilder
    private var headerContent: some View {
        AnyView(
            VStack(spacing: 0) {
                ExpandableCalendar(selectedDate: $selectedDate)
                statsRowSection
            }
            .overlay(headerOverlay, alignment: .bottom)
        )
    }
    
    @ViewBuilder
    private var headerOverlay: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.outline3)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Right Button Content
    @ViewBuilder
    private var rightButtonContent: some View {
        AnyView(
            HStack(spacing: 2) {
                addButton
                notificationButton
            }
        )
    }
    
    @ViewBuilder
    private var addButton: some View {
        Button(action: {
            // TODO: Add create habit action
            print("➕ Add habit button tapped")
        }) {
            Image("Icon-AddCircle_Filled")
                .renderingMode(.template)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.onPrimary)
        }
        .frame(width: 44, height: 44)
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var notificationButton: some View {
        Button(action: {
            // TODO: Add notification action
            print("🔔 Notification button tapped")
        }) {
            Image("Icon-Bell_Filled")
                .renderingMode(.template)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.onPrimary)
        }
        .frame(width: 44, height: 44)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Celebration Overlay
    @ViewBuilder
    private var celebrationOverlay: some View {
        Group {
            if showCelebration {
                CelebrationView(
                    isPresented: $showCelebration,
                    onDismiss: {
                        // Celebration dismissed, ready for next time
                    }
                )
            }
        }
    }
    
    // MARK: - Habit Detail View
    @ViewBuilder
    private func habitDetailView(for habit: Habit) -> some View {
        HabitDetailView(habit: habit, onUpdateHabit: onUpdateHabit, selectedDate: selectedDate, onDeleteHabit: onDeleteHabit)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Swipe right to dismiss (like back button)
                        if value.translation.width > 100 && abs(value.translation.height) < 100 {
                            selectedHabit = nil
                        }
                    }
            )
            .onAppear {
                print("🎯 HomeTabView: HabitDetailView appeared for habit: \(habit.name)")
            }
    }
    
    // MARK: - Event Handlers
    
    private func handleHabitsChange(oldHabits: [Habit], newHabits: [Habit]) {
        // Resort habits when the habits array changes
        print("🔄 HomeTabView: Habits changed from \(oldHabits.count) to \(newHabits.count)")
        resortHabits()
    }
    
    private func handleHabitsForSelectedDateChange(_ oldHabits: [Habit], _ newHabits: [Habit]) {
        // Remove automatic celebration check - now triggered by bottom sheet dismissal
    }
    
    private func handleSelectedDateChange(_ oldDate: Date, _ newDate: Date) {
        // Reset celebration when date changes
        showCelebration = false
    }
    
    private func handleVacationModeEnded(_ notification: Notification) {
        // Refresh UI when vacation mode ends
        // Vacation mode ended notification received
        // This will trigger a view update to reflect the new vacation state
    }
    
    
    @ViewBuilder
    private var statsRowSection: some View {
        // Tabs are hidden as requested
        EmptyView()
    }
    
    @ViewBuilder
    private var statsTabBar: some View {
        tabsView
    }
    
    @ViewBuilder
    private var tabsView: some View {
        let tabs = TabItem.createHomeStatsTabs(
            totalCount: stats.indices.contains(0) ? stats[0].1 : 0,
            undoneCount: stats.indices.contains(1) ? stats[1].1 : 0,
            doneCount: stats.indices.contains(2) ? stats[2].1 : 0
        )
        

        
        // Ensure tabs are always rendered, even if stats are empty
        if tabs.isEmpty {
            // Fallback tabs if something goes wrong
            let fallbackTabs = [
                TabItem(title: "Total", value: "0"),
                TabItem(title: "Undone", value: "0"),
                TabItem(title: "Done", value: "0")
            ]
            
            UnifiedTabBarView(
                tabs: fallbackTabs,
                selectedIndex: selectedStatsTab,
                style: .underline
            ) { index in
                // Haptic feedback when switching tabs
                UISelectionFeedbackGenerator().selectionChanged()
                selectedStatsTab = index
            }
        } else {
            UnifiedTabBarView(
                tabs: tabs,
                selectedIndex: selectedStatsTab,
                style: .underline
            ) { index in
                // Haptic feedback when switching tabs
                UISelectionFeedbackGenerator().selectionChanged()
                selectedStatsTab = index // All tabs are now clickable
            }
        }
    }
    

    

    
    @ViewBuilder
    private var habitsListSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // Vacation status indicator - first item in scrollable view
                if VacationManager.shared.isActive && VacationManager.shared.isVacationDay(selectedDate) {
                    HStack(spacing: 8) {
                        Image("Icon-Vacation_Filled")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.onSecondary)
                        Text("On Vacation")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.onSecondary)
                        
                        // Cancel vacation button
                        Button(action: {
                            showingCancelVacationAlert = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.onSecondary.opacity(0.4))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.secondaryContainer)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
                
                if habits.isEmpty && !isLoadingHabits {
                    // No habits created in the app at all
                    HabitEmptyStateView.noHabitsYet()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if sortedHabits.isEmpty && !isLoadingHabits {
                    // No habits for the selected tab/date
                    emptyStateViewForTab
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if isLoadingHabits {
                    // Show loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading habits...")
                            .font(.appBodyMedium)
                            .foregroundColor(.text02)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                } else {
                    ForEach(Array(sortedHabits.enumerated()), id: \.element.id) { index, habit in
                        habitRow(habit)
                            .animateViewAnimatorStyle(
                                index: index,
                                animation: .slideFromBottom(offset: 20),
                                config: .fast
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 100)
        }
        .refreshable {
            // Refresh habits data when user pulls down
            await refreshHabits()
        }
        .scrollIndicators(.hidden) // Hide scroll indicators for cleaner look
    }
    
    @ViewBuilder
    private var emptyStateViewForTab: some View {
        switch selectedStatsTab {
        case 0: // Total tab
            HabitEmptyStateView(
                imageName: "Habit-List-Empty-State@4x",
                title: "No habits for today",
                subtitle: "Create a habit to get started"
            )
        case 1: // Undone tab
            HabitEmptyStateView(
                imageName: "Today-Habit-List-Empty-State@4x",
                title: "All habits completed!",
                subtitle: "Great job! All your habits are done for today"
            )
        case 2: // Done tab
            HabitEmptyStateView(
                imageName: "Habit-List-Empty-State@4x",
                title: "No completed habits",
                subtitle: "Start building your streak today"
            )
        default:
            HabitEmptyStateView.noHabitsToday()
        }
    }
    

    
    private func habitRow(_ habit: Habit) -> some View {
        return ScheduledHabitItem(
            habit: habit,
            selectedDate: selectedDate,
            onRowTap: {
                print("🎯 HomeTabView: Row tapped for habit: \(habit.name)")
                selectedHabit = habit
                print("🎯 HomeTabView: selectedHabit set to: \(selectedHabit?.name ?? "nil")")
            },
            onProgressChange: { habit, date, progress in
                // Use the new progress setting method that properly saves to Core Data
                onSetProgress?(habit, date, progress)
                
                // Handle completion/uncompletion
                if progress > 0 {
                    onHabitCompleted(habit)
                } else {
                    onHabitUncompleted(habit)
                }
                
                // ✅ PHASE 5: Update completion status map after progress change
                Task {
                    await prefetchCompletionStatus()
                }
            },
            onEdit: {
                selectedHabit = habit
            },
            onDelete: {
                onDeleteHabit?(habit)
            },
            onCompletionDismiss: {
                onDifficultySheetDismissed()
                onCompletionDismiss?()
            }
        )
    }
    
    private var habitsForSelectedDate: [Habit] {
        // Calculate filtered habits for the selected date
        
        let filteredHabits = habits.filter { habit in
            let selected = DateUtils.startOfDay(for: selectedDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            guard selected >= start && selected <= end else {
                return false
            }
            
            return shouldShowHabitOnDate(habit, date: selectedDate)
        }
        
        // Since tabs are hidden, show all habits (like the Total tab was doing)
        // Sort habits so completed ones appear at the bottom
        let finalFilteredHabits = filteredHabits.sorted { habit1, habit2 in
            // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
            let habit1Completed = completionStatusMap[habit1.id] ?? false
            let habit2Completed = completionStatusMap[habit2.id] ?? false
            
            // If one is completed and the other isn't, put the incomplete one first
            if habit1Completed != habit2Completed {
                return !habit1Completed && habit2Completed
            }
            
            // If both have the same completion status, maintain original order
            return false
        }
        
        return finalFilteredHabits
    }
    
    // MARK: - Base Habits for Stats Calculation (No Tab Filtering)
    private var baseHabitsForSelectedDate: [Habit] {
        // Calculate filtered habits for the selected date (only by date/schedule, no tab filtering)
        let filteredHabits = habits.filter { habit in
            let selected = DateUtils.startOfDay(for: selectedDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            guard selected >= start && selected <= end else {
                return false
            }
            
            let shouldShow = shouldShowHabitOnDate(habit, date: selectedDate)
            return shouldShow
        }
        

        
        return filteredHabits
    }
    
    private func getWeekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
    }
    
    private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
        let weekday = DateUtils.weekday(for: date)
        
        // Check if the date is before the habit start date
        if date < DateUtils.startOfDay(for: habit.startDate) {
            return false
        }
        
        // Check if the date is after the habit end date (if set)
        // Use >= to be inclusive of the end date
        if let endDate = habit.endDate, date > DateUtils.endOfDay(for: endDate) {
            return false
        }
        
        switch habit.schedule.lowercased() {
        case "everyday", "every day":
            return true
        case "weekdays":
            let shouldShow = weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
            return shouldShow
        case "weekends":
            let shouldShow = weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
            return shouldShow
        case "monday", "mon":
            let shouldShow = weekday == 2
            return shouldShow
        case "tuesday", "tue":
            let shouldShow = weekday == 3
            return shouldShow
        case "wednesday", "wed":
            let shouldShow = weekday == 4
            return shouldShow
        case "thursday", "thu":
            let shouldShow = weekday == 5
            return shouldShow
        case "friday", "fri":
            let shouldShow = weekday == 6
            return shouldShow
        case "saturday", "sat":
            let shouldShow = weekday == 7
            return shouldShow
        case "sunday", "sun":
            let shouldShow = weekday == 1
            return shouldShow
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
                    let shouldShow = daysSinceStart >= 0 && daysSinceStart % dayCount == 0
                    return shouldShow
                } else {
                    // Extract weekdays from schedule (like "Every Monday, Wednesday, Friday")
                    let weekdays = extractWeekdays(from: habit.schedule)
                    let shouldShow = weekdays.contains(weekday)
                    return shouldShow
                }
            } else if habit.schedule.contains("days a week") {
                // Handle frequency schedules like "2 days a week"
                let shouldShow = shouldShowHabitWithFrequency(habit: habit, date: date)
                return shouldShow
            } else if habit.schedule.contains("days a month") {
                // Handle monthly frequency schedules like "3 days a month"
                let shouldShow = shouldShowHabitWithMonthlyFrequency(habit: habit, date: date)
                return shouldShow
            } else if habit.schedule.contains("times per week") {
                // Handle "X times per week" schedules
                let schedule = habit.schedule.lowercased()
                let timesPerWeek = extractTimesPerWeek(from: schedule)
                
                if timesPerWeek != nil {
                    // For now, show the habit if it's within the week
                    // This is a simplified implementation
                    let weekStart = DateUtils.startOfWeek(for: date)
                    let weekEnd = DateUtils.endOfWeek(for: date)
                    let isInWeek = date >= weekStart && date <= weekEnd
                    return isInWeek
                }
                return false
            }
            // Check if schedule contains multiple weekdays separated by commas
            if habit.schedule.contains(",") {
                let weekdays = extractWeekdays(from: habit.schedule)
                let shouldShow = weekdays.contains(weekday)
                return shouldShow
            }
            // For any unrecognized schedule format, don't show the habit (safer default)
            return false
        }
    }
    
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
        // Performance optimization: Use cached weekday names
        var weekdays: Set<Int> = []
        let lowercasedSchedule = schedule.lowercased()
        
        for (index, dayName) in Self.weekdayNames.enumerated() {
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
    
    // MARK: - Frequency-based Habit Logic
    
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
    
    private func calculateHabitInstances(habit: Habit, daysPerWeek: Int, targetDate: Date) -> [HabitInstance] {
        let calendar = Calendar.current
        
        // For frequency-based habits, we need to create instances that include today
        // Start from today and work backwards to find the appropriate instances
        let today = Date()
        let todayStart = DateUtils.startOfDay(for: today)
        
        // Initialize habit instances for this week
        var habitInstances: [HabitInstance] = []
        
        // Create initial habit instances starting from today
        // print("🔍 Creating \(daysPerWeek) habit instances starting from today: \(todayStart)") // Removed as per edit hint
        for i in 0..<daysPerWeek {
            if let instanceDate = calendar.date(byAdding: .day, value: i, to: todayStart) {
                let instance = HabitInstance(
                    id: "\(habit.id)_\(i)",
                    originalDate: instanceDate,
                    currentDate: instanceDate
                )
                habitInstances.append(instance)
                // print("🔍 Created instance \(i): \(instanceDate)") // Removed as per edit hint
            }
        }
        
        // Apply sliding logic based on completion history
        for i in 0..<habitInstances.count {
            var instance = habitInstances[i]
            
            // Check if this instance was completed on its original date
                            let originalDateKey = Habit.dateKey(for: instance.originalDate)
            let originalProgress = habit.completionHistory[originalDateKey] ?? 0
            
            if originalProgress > 0 {
                // Instance was completed on its original date
                // ❌ REMOVED: Direct assignment in Phase 4
                // instance.isCompleted = true  // Now computed via isCompleted(for:)
                habitInstances[i] = instance
                continue
            }
            
            // Instance was not completed, so it slides forward
            var currentDate = instance.originalDate
            
            // Slide the instance forward until it's completed or reaches the end of the week
            while currentDate <= DateUtils.endOfWeek(for: targetDate) {
                let dateKey = Habit.dateKey(for: currentDate)
                let progress = habit.completionHistory[dateKey] ?? 0
                
                if progress > 0 {
                    // Instance was completed on this date
                    instance.currentDate = currentDate
                    break
                }
                
                // Move to next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            // Update instance
            instance.currentDate = currentDate
            // ❌ REMOVED: Direct assignment in Phase 4
            // instance.isCompleted = foundCompletion  // Now computed via isCompleted(for:)
            habitInstances[i] = instance
        }
        
        // Return instances that should appear on the target date
        return habitInstances.filter { instance in
            let instanceDate = DateUtils.startOfDay(for: instance.currentDate)
            let targetDateStart = DateUtils.startOfDay(for: targetDate)
            return instanceDate == targetDateStart && !instance.isCompleted(for: habit)
        }
    }
    
    // Helper struct to track habit instances
    private struct HabitInstance {
        let id: String
        let originalDate: Date
        var currentDate: Date
        // ❌ REMOVED: Denormalized field in Phase 4
        // var isCompleted: Bool  // Use computed property instead
        
        /// Computed completion status based on habit completion history
        func isCompleted(for habit: Habit) -> Bool {
            let dateKey = Habit.dateKey(for: currentDate)
            let progress = habit.completionHistory[dateKey] ?? 0
            return progress > 0
        }
    }
    
    private func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
        // For now, implement a simple monthly frequency
        // This can be enhanced later with more sophisticated logic
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
    
    private var stats: [(String, Int)] {
        // Calculate stats from baseHabitsForSelectedDate (no tab filtering) to avoid circular dependency
        let habitsForDate = baseHabitsForSelectedDate
        return [
            ("Total", habitsForDate.count),
            // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
            ("Undone", habitsForDate.filter { !(completionStatusMap[$0.id] ?? false) }.count),
            ("Done", habitsForDate.filter { completionStatusMap[$0.id] ?? false }.count)
        ]
    }
    

    
    // ✅ PHASE 5: Prefetch completion status to prevent N+1 queries
    private func prefetchCompletionStatus() async {
        guard let userId = AuthenticationManager.shared.currentUser?.uid else {
            print("⚠️ HomeTabView: No user ID for prefetch")
            return
        }
        
        let dateKey = Habit.dateKey(for: selectedDate)
        
        // Single query to get all completion records for today
        let request: FetchDescriptor<CompletionRecord> = FetchDescriptor(
            predicate: #Predicate { 
                $0.userId == userId && 
                $0.dateKey == dateKey
            }
        )
        
        do {
            let completions = try modelContext.fetch(request)
            
            // Build completion status map
            var statusMap: [UUID: Bool] = [:]
            for completion in completions {
                statusMap[completion.habitId] = completion.isCompleted
            }
            
            await MainActor.run {
                self.completionStatusMap = statusMap
            }
            
            print("✅ HomeTabView: Prefetched completion status for \(completions.count) habits")
            
            // ✅ FIX: Check if all habits are already completed for today
            await checkAndTriggerCelebrationIfAllCompleted()
        } catch {
            print("❌ HomeTabView: Failed to prefetch completion status: \(error)")
        }
    }
    
    // ✅ FIX: Check if all habits are completed and trigger celebration
    private func checkAndTriggerCelebrationIfAllCompleted() async {
        // Only check if we're viewing today
        let today = DateUtils.today()
        guard Calendar.current.isDate(selectedDate, inSameDayAs: today) else {
            print("🎯 checkAndTriggerCelebrationIfAllCompleted: Not today, skipping check")
            return
        }
        
        // Get habits for today
        let todayHabits = baseHabitsForSelectedDate
        
        // Check if all habits are completed
        let allCompleted = todayHabits.allSatisfy { habit in
            completionStatusMap[habit.id] == true
        }
        
        if allCompleted && !todayHabits.isEmpty {
            print("🎉 checkAndTriggerCelebrationIfAllCompleted: All habits completed! Triggering celebration")
            
            // Trigger the celebration by calling DailyAwardService
            let userId = getCurrentUserId()
            
            let result = await awardService.grantIfAllComplete(date: selectedDate, userId: userId, callSite: "app_launch_check")
            print("🎯 checkAndTriggerCelebrationIfAllCompleted: grantIfAllComplete result: \(result)")
            
            if result {
                print("🎉 checkAndTriggerCelebrationIfAllCompleted: Celebration triggered successfully!")
            }
        } else {
            print("🎯 checkAndTriggerCelebrationIfAllCompleted: Not all habits completed (\(todayHabits.filter { !(completionStatusMap[$0.id] ?? false) }.count) remaining)")
        }
    }
    
    // Refresh habits data when user pulls down
    private func refreshHabits() async {
        // Add a small delay to make the refresh feel more responsive
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Refresh habits data from Core Data
        // Force reload habits from Core Data
        await HabitRepository.shared.loadHabits(force: true)
        
        // ✅ PHASE 5: Refetch completion status after refresh
        await prefetchCompletionStatus()
        
        // Provide haptic feedback for successful refresh
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Additional success feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    
    // MARK: - Sorting Logic
    private func resortHabits() {
        guard !deferResort else { return }
        
        let todayHabits = habits.filter { habit in
            let selected = DateUtils.startOfDay(for: selectedDate)
            let start = DateUtils.startOfDay(for: habit.startDate)
            let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
            
            guard selected >= start && selected <= end else {
                return false
            }
            
            return shouldShowHabitOnDate(habit, date: selectedDate)
        }
        
        // Sort: Incomplete first by originalOrder, then completed by completedAt then originalOrder
        sortedHabits = todayHabits.sorted(by: { habit1, habit2 in
            // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
            let isCompleted1 = completionStatusMap[habit1.id] ?? false
            let isCompleted2 = completionStatusMap[habit2.id] ?? false
            
            if isCompleted1 != isCompleted2 {
                return !isCompleted1 // Incomplete first
            }
            
            if isCompleted1 && isCompleted2 {
                // Both completed, sort by completedAt then originalOrder
                let completedAt1 = habit1.completionHistory[DateKey.key(for: selectedDate)] ?? 0
                let completedAt2 = habit2.completionHistory[DateKey.key(for: selectedDate)] ?? 0
                
                if completedAt1 != completedAt2 {
                    return completedAt1 > completedAt2 // More recent first
                }
            }
            
            // Fallback to name order
            return habit1.name < habit2.name
        })
    }
    
    // MARK: - Habit Completion Logic
    private func onHabitCompleted(_ habit: Habit) {
        // Mark complete and present difficulty sheet
        deferResort = true
        
        // ✅ FIX: Update completion status map immediately for this habit
        // This ensures the last habit detection works correctly
        completionStatusMap[habit.id] = true
        
        // Check if this is the last habit to be completed
        // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
        let remainingHabits = baseHabitsForSelectedDate.filter { h in
            h.id != habit.id && !(completionStatusMap[h.id] ?? false)
        }
        
        if remainingHabits.isEmpty {
            // This is the last habit - set flag and let difficulty sheet be shown
            // The celebration will be triggered after the difficulty sheet is dismissed
            onLastHabitCompleted()
            // Don't set selectedHabit = nil here - let the difficulty sheet show
        } else {
            // Present difficulty sheet (existing logic)
            // Don't set selectedHabit here as it triggers habit detail screen
            // The difficulty sheet will be shown by the ScheduledHabitItem
        }
    }
    
    private func onHabitUncompleted(_ habit: Habit) {
        // ✅ FIX: Update completion status map immediately for this habit
        // This ensures the last habit detection works correctly
        completionStatusMap[habit.id] = false
        
        // Call award service
        Task {
            #if DEBUG
            debugRevokeCalls += 1
            print("🔍 DEBUG: onHabitUncompleted - revoke call #\(debugRevokeCalls)")
            #endif
            
            _ = await awardService.revokeIfAnyIncomplete(date: selectedDate, userId: getCurrentUserId(), callSite: "ui_habit_uncompleted")
        }
        
        // Resort immediately
        deferResort = false
        resortHabits()
    }
    
    private func onDifficultySheetDismissed() {
        deferResort = false
        resortHabits()
        
        // Check if the last habit was just completed
        if lastHabitJustCompleted {
            // ✅ CORRECT: Call DailyAwardService to grant XP for completing all habits
            // This is the ONLY place where XP should be awarded for habit completion
            // Do NOT call XPManager methods directly - always use DailyAwardService
            let dateKey = DateKey.key(for: selectedDate)
            let userId = getCurrentUserId()
            print("🎉 STEP 2: Last habit completion sheet dismissed! Granting daily award for \(dateKey)")
            print("🎯 STEP 2: userId = \(userId)")
            
            Task {
                #if DEBUG
                debugGrantCalls += 1
                print("🔍 DEBUG: onDifficultySheetDismissed - grant call #\(debugGrantCalls) from ui_sheet_dismiss")
                if debugGrantCalls > 1 {
                    print("⚠️ WARNING: Multiple grant calls detected! Call #\(debugGrantCalls)")
                    print("⚠️ Stack trace:")
                    Thread.callStackSymbols.forEach { print("  \($0)") }
                }
                #endif
                
                print("🎯 STEP 3: Calling DailyAwardService.grantIfAllComplete()")
                let result = await awardService.grantIfAllComplete(date: selectedDate, userId: userId, callSite: "ui_sheet_dismiss")
                print("🎯 STEP 3: grantIfAllComplete result: \(result)")
                
                // Check XP after award
                let currentXP = XPManager.shared.userProgress.totalXP
                print("🎯 STEP 4: Current XP after award: \(currentXP)")
                print("🎯 STEP 4: XPManager level: \(XPManager.shared.userProgress.currentLevel)")
            }
            
            // Reset the flag
            lastHabitJustCompleted = false
        }
    }
    
    private func onLastHabitCompleted() {
        deferResort = false
        resortHabits()
        
        // Set flag to trigger celebration when difficulty sheet is dismissed
        lastHabitJustCompleted = true
        
        // Note: XP will be awarded in onDifficultySheetDismissed() after the difficulty sheet is dismissed
        print("🎉 STEP 1: Last habit completed! Will award XP after difficulty sheet is dismissed")
        print("🎯 STEP 1: lastHabitJustCompleted = \(lastHabitJustCompleted)")
    }
    
    private func getCurrentUserId() -> String {
        // Note: Authentication system access needs to be implemented
        let userId = "debug_user_id"
        print("🎯 USER SCOPING: HomeTabView.getCurrentUserId() = \(userId) (debug mode)")
        return userId
    }
}
