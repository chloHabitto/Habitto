import Combine
import SwiftData
import SwiftUI

// Note: AuthenticationManager and CurrentUser are automatically available
// through the app's module since they're in the same target

struct HomeTabView: View {
  // MARK: Lifecycle

  init(
    selectedDate: Binding<Date>,
    selectedStatsTab: Binding<Int>,
    habits: [Habit],
    isLoadingHabits: Bool,
    onToggleHabit: @escaping (Habit, Date) -> Void,
    onUpdateHabit: ((Habit) -> Void)?,
    onSetProgress: ((Habit, Date, Int) -> Void)?,
    onDeleteHabit: ((Habit) -> Void)?,
    onCompletionDismiss: (() -> Void)?,
    onStreakRecalculationNeeded: (() -> Void)? = nil)
  {
    self._selectedDate = selectedDate
    self._selectedStatsTab = selectedStatsTab
    self.habits = habits
    self.isLoadingHabits = isLoadingHabits
    self.onToggleHabit = onToggleHabit
    self.onUpdateHabit = onUpdateHabit
    self.onSetProgress = onSetProgress
    self.onDeleteHabit = onDeleteHabit
    self.onCompletionDismiss = onCompletionDismiss
    self.onStreakRecalculationNeeded = onStreakRecalculationNeeded
    
    // Initialize DailyAwardService
    // Use new Firebase-based DailyAwardService (no ModelContext needed)
    self._awardService = StateObject(wrappedValue: DailyAwardService.shared)

    // Subscribe to event bus - will be handled in onAppear
  }

  // MARK: Internal

  @Binding var selectedDate: Date
  @Binding var selectedStatsTab: Int
  @EnvironmentObject var themeManager: ThemeManager
  
  // ✅ FIX: Use @Environment to properly observe @Observable changes
  @Environment(XPManager.self) private var xpManager

  let habits: [Habit]
  let isLoadingHabits: Bool
  let onToggleHabit: (Habit, Date) -> Void
  let onUpdateHabit: ((Habit) -> Void)?
  let onSetProgress: ((Habit, Date, Int) -> Void)?
  let onDeleteHabit: ((Habit) -> Void)?
  let onCompletionDismiss: (() -> Void)?
  let onStreakRecalculationNeeded: (() -> Void)?

  var body: some View {
    // 🔎 PROBE: Check instance and XP value
    let _ = print("🟢 HomeTabView re-render | xp:", xpManager.totalXP,
                  "| instance:", ObjectIdentifier(xpManager))
    
    return mainContent
      .onAppear {
        let today = LegacyDateUtils.today()
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
          
          // ✅ FIX: Compute initial XP from persisted habit data
          print("✅ INITIAL_XP: Computing XP from loaded habits")
          let completedDaysCount = countCompletedDays()
          await MainActor.run {
            xpManager.publishXP(completedDaysCount: completedDaysCount)  // ✅ Use environment object
          }
          print("✅ INITIAL_XP: Set to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
        }

        // Subscribe to event bus
        eventBus.publisher()
          .receive(on: DispatchQueue.main)
          .sink { event in
            switch event {
            case .dailyAwardGranted(let dateKey):
              print("🎯 STEP 12: Received dailyAwardGranted event for \(dateKey)")

              // ✅ FIX: Delay celebration to ensure sheet is fully dismissed
              // Set delay to 0.8s to ensure difficulty sheet is completely closed
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                print("🎯 STEP 12: Setting showCelebration = true")
                showCelebration = true
              }

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
        // ✅ FIX: Resort habits when date changes to show correct habits for new date
        resortHabits()
        // ✅ PHASE 5: Refetch completion status when date changes
        Task {
          await prefetchCompletionStatus()
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: .vacationModeEnded),
        perform: handleVacationModeEnded)
      .alert("Cancel Vacation", isPresented: $showingCancelVacationAlert) {
        Button("Cancel", role: .cancel) { }
        Button("End Vacation", role: .destructive) {
          VacationManager.shared.cancelVacationForDate(selectedDate)
        }
      } message: {
        Text(
          "Are you sure you want to end vacation mode for this date? This will resume all habit tracking.")
      }
  }

  // MARK: Private

  /// Helper struct to track habit instances
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

  /// Performance optimization: Cached regex patterns
  private static let dayCountRegex = try? NSRegularExpression(
    pattern: "Every (\\d+) days?",
    options: .caseInsensitive)
  private static let weekdayNames = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ]

  @State private var currentWeekOffset = 0

  @State private var lastHapticWeek = 0
  @State private var isDragging = false
  @State private var selectedHabit: Habit? = nil
  @State private var showCelebration = false
  @State private var showingCancelVacationAlert = false
  @State private var deferResort = false
  @State private var sortedHabits: [Habit] = []
  @State private var cancellables = Set<AnyCancellable>()
  @State private var lastHabitJustCompleted = false

  /// ✅ PHASE 5: Prefetch completion status to prevent N+1 queries
  @State private var completionStatusMap: [UUID: Bool] = [:]
  
  /// ✅ FIX: Track processed dates to prevent duplicate XP awards in same session
  @State private var processedDates = Set<String>()
  
  /// ✅ FIX: Prevent concurrent execution of XP check
  @State private var isCheckingXP = false

  #if DEBUG
  // Runtime tracking: verify service is called exactly once per flow
  @State private var debugGrantCalls = 0
  @State private var debugRevokeCalls = 0
  #endif

  // ✅ FIX #12: Use SwiftDataContainer's ModelContext instead of @Environment
  // This prevents parallel database operations from destroying tables
  @StateObject private var eventBus = EventBus.shared
  @StateObject private var awardService: DailyAwardService

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()

  private var habitsForSelectedDate: [Habit] {
    // Calculate filtered habits for the selected date
    let selected = DateUtils.startOfDay(for: selectedDate)

    let filteredHabits = habits.filter { habit in
      let start = DateUtils.startOfDay(for: habit.startDate)
      let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture

      guard selected >= start, selected <= end else {
        return false
      }

      let shouldShow = shouldShowHabitOnDate(habit, date: selectedDate)
      
      // ✅ FIX: Use latest habit data to check completion status (prevent stale data)
      // The habit parameter might be from a closure capture, so fetch fresh data
      let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
      
      // ✅ FIX: Also show if habit was already completed on this date
      // This ensures completed habits stay visible (just marked as done)
      let dateKey = Habit.dateKey(for: selectedDate)
      let progress = latestHabit.completionHistory[dateKey] ?? 0
      let wasCompletedOnThisDate = progress > 0
      
      return shouldShow || wasCompletedOnThisDate
    }

    // Since tabs are hidden, show all habits (like the Total tab was doing)
    // ✅ FIX: Only sort completed habits to bottom if NOT currently completing a habit
    // This prevents the jarring reorder during swipe gestures
    let finalFilteredHabits: [Habit]
    
    if deferResort {
      // Don't reorder while completing - keep original order
      finalFilteredHabits = filteredHabits.sorted { habit1, habit2 in
        // Just use stable secondary sort (by name)
        return habit1.name < habit2.name
      }
    } else {
      // Normal sorting: completed habits at bottom
      finalFilteredHabits = filteredHabits.sorted { habit1, habit2 in
        // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
        let habit1Completed = completionStatusMap[habit1.id] ?? false
        let habit2Completed = completionStatusMap[habit2.id] ?? false

        // If one is completed and the other isn't, put the incomplete one first
        if habit1Completed != habit2Completed {
          return !habit1Completed && habit2Completed
        }

        // ✅ FIX: Use stable secondary sort to prevent array jumping during updates
        return habit1.name < habit2.name
      }
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

      guard selected >= start, selected <= end else {
        return false
      }

      let shouldShow = shouldShowHabitOnDate(habit, date: selectedDate)
      
      // ✅ FIX: Use latest habit data to check completion status (prevent stale data)
      let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
      
      // ✅ FIX: Also show if habit was already completed on this date
      // This ensures completed habits stay visible for stats calculation
      let dateKey = Habit.dateKey(for: selectedDate)
      let wasCompletedOnThisDate = (latestHabit.completionHistory[dateKey] ?? 0) > 0
      
      return shouldShow || wasCompletedOnThisDate
    }

    return filteredHabits
  }

  private var stats: [(String, Int)] {
    // Calculate stats from baseHabitsForSelectedDate (no tab filtering) to avoid circular
    // dependency
    let habitsForDate = baseHabitsForSelectedDate
    return [
      ("Total", habitsForDate.count),
      // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
      ("Undone", habitsForDate.filter { !(completionStatusMap[$0.id] ?? false) }.count),
      ("Done", habitsForDate.filter { completionStatusMap[$0.id] ?? false }.count)
    ]
  }

  // MARK: - Main Content

  @ViewBuilder
  private var mainContent: some View {
    WhiteSheetContainer(
      headerContent: { AnyView(headerContent) },
      rightButton: { AnyView(rightButtonContent) })
    {
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
      .overlay(headerOverlay, alignment: .bottom))
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
      })
  }

  @ViewBuilder
  private var addButton: some View {
    Button(action: {
      // Navigate to create habit flow
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
      // Navigate to notification settings
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
          })
      }
    }
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
      doneCount: stats.indices.contains(2) ? stats[2].1 : 0)

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
        style: .underline)
      { index in
        // Haptic feedback when switching tabs
        UISelectionFeedbackGenerator().selectionChanged()
        selectedStatsTab = index
      }
    } else {
      UnifiedTabBarView(
        tabs: tabs,
        selectedIndex: selectedStatsTab,
        style: .underline)
      { index in
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
        if VacationManager.shared.isActive, VacationManager.shared.isVacationDay(selectedDate) {
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

        if habits.isEmpty, !isLoadingHabits {
          // No habits created in the app at all
          HabitEmptyStateView.noHabitsYet()
            .frame(maxWidth: .infinity, alignment: .center)
        } else if sortedHabits.isEmpty, !isLoadingHabits {
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
                config: .fast)
              .transition(.identity)
          }
          .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sortedHabits.map { $0.id })
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
        subtitle: "Create a habit to get started")

    case 1: // Undone tab
      HabitEmptyStateView(
        imageName: "Today-Habit-List-Empty-State@4x",
        title: "All habits completed!",
        subtitle: "Great job! All your habits are done for today")

    case 2: // Done tab
      HabitEmptyStateView(
        imageName: "Habit-List-Empty-State@4x",
        title: "No completed habits",
        subtitle: "Start building your streak today")

    default:
      HabitEmptyStateView.noHabitsToday()
    }
  }

  // MARK: - Habit Detail View

  @ViewBuilder
  private func habitDetailView(for habit: Habit) -> some View {
    HabitDetailView(
      habit: habit,
      onUpdateHabit: onUpdateHabit,
      selectedDate: selectedDate,
      onDeleteHabit: onDeleteHabit)
      .gesture(
        DragGesture()
          .onEnded { value in
            // Swipe right to dismiss (like back button)
            if value.translation.width > 100, abs(value.translation.height) < 100 {
              selectedHabit = nil
            }
          })
      .onAppear {
        print("🎯 HomeTabView: HabitDetailView appeared for habit: \(habit.name)")
      }
  }

  private func habitRow(_ habit: Habit) -> some View {
    ScheduledHabitItem(
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
        // ✅ FIX: onDifficultySheetDismissed will call onCompletionDismiss after streak update
        onDifficultySheetDismissed()
      })
  }

  // MARK: - Event Handlers

  private func handleHabitsChange(oldHabits: [Habit], newHabits: [Habit]) {
    // Resort habits when the habits array changes
    print("🔄 HomeTabView: Habits changed from \(oldHabits.count) to \(newHabits.count)")
    resortHabits()
  }

  private func handleHabitsForSelectedDateChange(_: [Habit], _: [Habit]) {
    // Remove automatic celebration check - now triggered by bottom sheet dismissal
  }

  private func handleSelectedDateChange(_: Date, _: Date) {
    // Reset celebration when date changes
    showCelebration = false
  }

  private func handleVacationModeEnded(_: Notification) {
    // Refresh UI when vacation mode ends
    // Vacation mode ended notification received
    // This will trigger a view update to reflect the new vacation state
  }

  private func getWeekdayName(_ weekday: Int) -> String {
    switch weekday {
    case 1: "Sunday"
    case 2: "Monday"
    case 3: "Tuesday"
    case 4: "Wednesday"
    case 5: "Thursday"
    case 6: "Friday"
    case 7: "Saturday"
    default: "Unknown"
    }
  }

  /// ✅ REFACTORED: Delegates to shared HabitSchedulingLogic utility
  /// This ensures XP and streak calculations use IDENTICAL scheduling logic
  private func shouldShowHabitOnDate(_ habit: Habit, date: Date) -> Bool {
    return HabitSchedulingLogic.shouldShowHabitOnDate(habit, date: date, habits: habits)
  }

  private func extractDayCount(from schedule: String) -> Int? {
    let pattern = #"every (\d+) days?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
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
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let numberString = (schedule as NSString).substring(with: range)
    return Int(numberString)
  }

  private func extractDaysPerWeek(from schedule: String) -> Int? {
    let lowerSchedule = schedule.lowercased()
    
    // Handle word-based frequencies
    if lowerSchedule.contains("once a week") {
      return 1
    }
    if lowerSchedule.contains("twice a week") {
      return 2
    }
    
    // Handle number-based frequencies like "3 days a week"
    let pattern = #"(\d+) days? a week"#  // Made "s" optional to match both "day" and "days"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
          let match = regex.firstMatch(
            in: schedule,
            options: [],
            range: NSRange(location: 0, length: schedule.count)) else
    {
      return nil
    }

    let range = match.range(at: 1)
    let numberString = (schedule as NSString).substring(with: range)
    return Int(numberString)
  }

  // MARK: - Frequency-based Habit Logic

  private func shouldShowHabitWithFrequency(habit: Habit, date: Date) -> Bool {
    // Verify this is actually a frequency-based schedule (e.g., "3 days a week")
    guard extractDaysPerWeek(from: habit.schedule) != nil else {
      return false
    }

    let calendar = Calendar.current
    let targetDate = calendar.startOfDay(for: date)
    let startDate = calendar.startOfDay(for: habit.startDate)

    // ✅ FIX: For frequency-based habits (e.g., "3 days a week"), the habit should appear EVERY day
    // after the start date. The user decides which days to complete it.
    // Completion tracking will hide it once completed the required number of times that week.
    let isAfterStart = targetDate >= startDate
    
    // Check if habit has ended
    if let endDate = habit.endDate {
      let endDateStart = calendar.startOfDay(for: endDate)
      if targetDate > endDateStart {
        return false
      }
    }
    
    return isAfterStart
  }

  private func calculateHabitInstances(
    habit: Habit,
    daysPerWeek: Int,
    targetDate: Date) -> [HabitInstance]
  {
    let calendar = Calendar.current

    // For frequency-based habits, we need to create instances that include today
    // Start from today and work backwards to find the appropriate instances
    let today = Date()
    let todayStart = DateUtils.startOfDay(for: today)

    // Initialize habit instances for this week
    var habitInstances: [HabitInstance] = []

    // Create initial habit instances starting from today
    // print("🔍 Creating \(daysPerWeek) habit instances starting from today: \(todayStart)") //
    // Removed as per edit hint
    for i in 0 ..< daysPerWeek {
      if let instanceDate = calendar.date(byAdding: .day, value: i, to: todayStart) {
        let instance = HabitInstance(
          id: "\(habit.id)_\(i)",
          originalDate: instanceDate,
          currentDate: instanceDate)
        habitInstances.append(instance)
        // print("🔍 Created instance \(i): \(instanceDate)") // Removed as per edit hint
      }
    }

    // Apply sliding logic based on completion history
    for i in 0 ..< habitInstances.count {
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

  private func shouldShowHabitWithMonthlyFrequency(habit: Habit, date: Date) -> Bool {
    // ✅ CORRECT LOGIC: "5 days a month" means show for 5 days, distributed across remaining days
    // Example: On Oct 28 with 4 days left, show for min(5 needed, 4 remaining) = 4 days
    let calendar = Calendar.current
    let today = Date()
    let targetDate = DateUtils.startOfDay(for: date)
    let todayStart = DateUtils.startOfDay(for: today)

    // Extract days per month from schedule
    let lowerSchedule = habit.schedule.lowercased()
    let daysPerMonth: Int
    
    if lowerSchedule.contains("once a month") {
      daysPerMonth = 1
    } else if lowerSchedule.contains("twice a month") {
      daysPerMonth = 2
    } else {
      // Extract number from "X day(s) a month"
      let pattern = #"(\d+) days? a month"#
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(
              in: habit.schedule,
              options: [],
              range: NSRange(location: 0, length: habit.schedule.count)) else
      {
        return false
      }

      let range = match.range(at: 1)
      let daysPerMonthString = (habit.schedule as NSString).substring(with: range)
      guard let days = Int(daysPerMonthString) else {
        return false
      }
      daysPerMonth = days
    }

    // ✅ FIX: Check if habit was completed on this specific date first
    // This ensures completed habits are considered "scheduled" for that date
    let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
    let dateKey = Habit.dateKey(for: targetDate)
    let wasCompletedOnThisDate = (latestHabit.completionHistory[dateKey] ?? 0) > 0
    
    if wasCompletedOnThisDate {
      print("🔍 MONTHLY FREQUENCY - Habit '\(habit.name)': Was completed on \(dateKey) → true")
      return true
    }

    // If the target date is in the past (and not completed), don't show the habit
    if targetDate < todayStart {
      return false
    }

    // Calculate completions still needed this month
    let completionsThisMonth = countCompletionsForCurrentMonth(habit: habit, currentDate: targetDate)
    let completionsNeeded = daysPerMonth - completionsThisMonth
    
    // If already completed the monthly goal, don't show for future dates
    if completionsNeeded <= 0 {
      print("🔍 MONTHLY FREQUENCY - Habit '\(habit.name)': Goal reached (\(completionsThisMonth)/\(daysPerMonth))")
      return false
    }
    
    // Calculate days remaining in month from today
    let lastDayOfMonth = calendar.dateInterval(of: .month, for: todayStart)?.end ?? todayStart
    let lastDayStart = DateUtils.startOfDay(for: lastDayOfMonth.addingTimeInterval(-1)) // -1 to get last day
    let daysRemainingFromToday = DateUtils.daysBetween(todayStart, lastDayStart) + 1
    
    // Show for minimum of (completions needed, days remaining)
    let daysToShow = min(completionsNeeded, daysRemainingFromToday)
    
    // Check if targetDate is within the next daysToShow days from today
    let daysUntilTarget = DateUtils.daysBetween(todayStart, targetDate)
    let shouldShow = daysUntilTarget >= 0 && daysUntilTarget < daysToShow
    
    print("🔍 MONTHLY FREQUENCY - Habit '\(habit.name)': \(completionsThisMonth)/\(daysPerMonth) done, need \(completionsNeeded) more, \(daysRemainingFromToday) days left, showing for \(daysToShow) days, target in \(daysUntilTarget) days → \(shouldShow)")
    
    return shouldShow
  }
  
  /// Helper: Count how many times a habit was completed in the current month
  /// ✅ FIX: Use fresh habit data from habits array to prevent stale data issues
  private func countCompletionsForCurrentMonth(habit: Habit, currentDate: Date) -> Int {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: currentDate)
    let year = calendar.component(.year, from: currentDate)
    
    // ✅ FIX: Get the latest habit data from the habits array to avoid stale data
    // This prevents the race condition where completionHistory is outdated
    let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
    
    var count = 0
    
    // Iterate through completion history for this month
    for (dateKey, progress) in latestHabit.completionHistory {
      // Parse dateKey format "yyyy-MM-dd"
      let components = dateKey.split(separator: "-")
      guard components.count == 3,
            let keyYear = Int(components[0]),
            let keyMonth = Int(components[1]) else {
        continue
      }
      
      // Check if completion is in the same month and year
      if keyYear == year && keyMonth == month && progress > 0 {
        count += 1
      }
    }
    
    return count
  }

  /// ✅ PHASE 5: Prefetch completion status to prevent N+1 queries
  private func prefetchCompletionStatus() async {
    // ✅ FIX: Build status map from local habit completion history (immediate, no async delay)
    // This is the source of truth and doesn't require SwiftData queries
    var statusMap: [UUID: Bool] = [:]
    for habit in habits {
      statusMap[habit.id] = habit.isCompleted(for: selectedDate)
    }

    await MainActor.run {
      completionStatusMap = statusMap
    }

    print("✅ HomeTabView: Prefetched completion status for \(statusMap.count) habits from local data")
  }

  // MARK: - Derived XP Helpers
  
  /// ✅ PURE FUNCTION: Count how many days have all habits completed
  /// This is the single source of truth for XP calculation
  @MainActor
  private func countCompletedDays() -> Int {
    guard let userId = AuthenticationManager.shared.currentUser?.uid else { return 0 }
    guard !habits.isEmpty else { return 0 }
    
    let calendar = Calendar.current
    let today = LegacyDateUtils.today()
    
    // Find the earliest habit start date
    guard let earliestStartDate = habits.map({ $0.startDate }).min() else { return 0 }
    let startDate = DateUtils.startOfDay(for: earliestStartDate)
    
    var completedCount = 0
    var currentDate = startDate
    
    // ✅ FIX: Get ModelContext for querying CompletionRecords from SwiftData
    let modelContext = SwiftDataContainer.shared.modelContext
    
    // Count all days where all habits are completed
    while currentDate <= today {
      let dateKey = Habit.dateKey(for: currentDate)
      
      // ✅ CRITICAL FIX: Use shared scheduling logic (same as streak calculation)
      let habitsForDate = habits.filter { habit in
        let selected = DateUtils.startOfDay(for: currentDate)
        let start = DateUtils.startOfDay(for: habit.startDate)
        let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture
        
        guard selected >= start, selected <= end else { return false }
        return HabitSchedulingLogic.shouldShowHabitOnDate(habit, date: currentDate, habits: habits)
      }
      
      // ✅ CRITICAL FIX: Check CompletionRecords from SwiftData instead of old completionHistory!
      // This was causing XP to stay at 0 even though CompletionRecords were being created
      var allCompleted = false
      if !habitsForDate.isEmpty {
        // Fetch all CompletionRecords for this date and user
        let descriptor = FetchDescriptor<CompletionRecord>()
        
        do {
          let allRecords = try modelContext.fetch(descriptor)
          let completedRecords = allRecords.filter { $0.dateKey == dateKey && $0.userId == userId && $0.isCompleted }
          
          // ✅ DEBUG: Log detailed info to diagnose XP=0 issue
          print("🔍 XP_DEBUG: Date=\(dateKey)")
          print("   Total CompletionRecords in DB: \(allRecords.count)")
          print("   Matching dateKey '\(dateKey)': \(allRecords.filter { $0.dateKey == dateKey }.count)")
          print("   Matching userId '\(userId)': \(allRecords.filter { $0.userId == userId }.count)")
          print("   isCompleted=true: \(allRecords.filter { $0.isCompleted }.count)")
          print("   Final filtered (complete+matching): \(completedRecords.count)")
          print("   Habits scheduled for this date: \(habitsForDate.count)")
          print("   📊 COMPLETION RATIO: \(completedRecords.count)/\(habitsForDate.count) habits completed")
          
          for record in completedRecords {
            print("     ✅ Record: habitId=\(record.habitId), dateKey=\(record.dateKey), userId=\(record.userId), isCompleted=\(record.isCompleted)")
          }
          
          for habit in habitsForDate {
            let hasRecord = completedRecords.contains(where: { $0.habitId == habit.id })
            print("     \(hasRecord ? "✅" : "❌") Habit '\(habit.name)' (id=\(habit.id)) \(hasRecord ? "HAS" : "MISSING") CompletionRecord")
          }
          
          // Check if all habits for this date have a completed record
          allCompleted = habitsForDate.allSatisfy { habit in
            completedRecords.contains(where: { $0.habitId == habit.id })
          }
          
          if !allCompleted {
            let missingHabits = habitsForDate.filter { habit in
              !completedRecords.contains(where: { $0.habitId == habit.id })
            }
            print("🔍 XP_CALC: \(dateKey) - Missing: \(missingHabits.map { $0.name }.joined(separator: ", "))")
          }
        } catch {
          print("❌ XP_CALC: Failed to fetch CompletionRecords for \(dateKey): \(error)")
          allCompleted = false
        }
      }
      
      if allCompleted {
        completedCount += 1
        print("✅ XP_CALC: [\(dateKey)] ALL \(habitsForDate.count)/\(habitsForDate.count) habits complete - COUNTED! (+50 XP)")
      } else if !habitsForDate.isEmpty {
        print("❌ XP_CALC: [\(dateKey)] NOT all habits complete - SKIPPED (0 XP)")
      }
      
      guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
      currentDate = nextDate
    }
    
    print("🎯 XP_CALC: Total completed days: \(completedCount)")
    return completedCount
  }
  
  /// ❌ DEPRECATED: Old incremental XP approach (replaced by derived XP)
  @available(*, unavailable, message: "Use countCompletedDays() and publishXP() instead")
  private func checkAndAwardMissingXPForPreviousDays() async {
    fatalError("This method is deprecated. Use countCompletedDays() and publishXP() instead.")
  }
  
  /// ❌ DEPRECATED: Old celebration check (replaced by derived XP on toggles)
  @available(*, unavailable, message: "XP is now derived on habit toggles via publishXP()")
  private func checkAndTriggerCelebrationIfAllCompleted() async {
    fatalError("This method is deprecated. XP is now derived on habit toggles via publishXP().")
  }

  /// Refresh habits data when user pulls down
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
    print("🔄 resortHabits() called - deferResort: \(deferResort)")
    guard !deferResort else {
      print("   ⚠️ resortHabits() BLOCKED by deferResort flag")
      return
    }
    print("   ✅ resortHabits() proceeding...")

    let todayHabits = habits.filter { habit in
      let selected = DateUtils.startOfDay(for: selectedDate)
      let start = DateUtils.startOfDay(for: habit.startDate)
      let end = habit.endDate.map { DateUtils.startOfDay(for: $0) } ?? Date.distantFuture

      guard selected >= start, selected <= end else {
        return false
      }

      let shouldShow = shouldShowHabitOnDate(habit, date: selectedDate)
      
      // ✅ FIX: Also include habits that were completed on this date
      // This ensures completed habits stay visible in the sorted list
      let dateKey = Habit.dateKey(for: selectedDate)
      let latestHabit = habits.first(where: { $0.id == habit.id }) ?? habit
      let wasCompletedOnThisDate = (latestHabit.completionHistory[dateKey] ?? 0) > 0
      
      return shouldShow || wasCompletedOnThisDate
    }

    // Sort: Incomplete first by originalOrder, then completed by completedAt then originalOrder
    sortedHabits = todayHabits.sorted(by: { habit1, habit2 in
      // ✅ PHASE 5: Use prefetched completion status to prevent N+1 queries
      let isCompleted1 = completionStatusMap[habit1.id] ?? false
      let isCompleted2 = completionStatusMap[habit2.id] ?? false

      if isCompleted1 != isCompleted2 {
        return !isCompleted1 // Incomplete first
      }

      if isCompleted1, isCompleted2 {
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
    
    print("   ✅ resortHabits() completed - sortedHabits count: \(sortedHabits.count)")
    for (index, habit) in sortedHabits.enumerated() {
      let isComplete = completionStatusMap[habit.id] ?? false
      print("      [\(index)] \(habit.name) - completed: \(isComplete)")
    }
  }

  // MARK: - Habit Completion Logic

  private func onHabitCompleted(_ habit: Habit) {
    let dateKey = Habit.dateKey(for: selectedDate)

    print(
      "🎯 COMPLETION_FLOW: onHabitCompleted - habitId=\(habit.id), dateKey=\(dateKey), userIdHash=debug_user_id")

    // Mark complete and present difficulty sheet
    deferResort = true

    // ✅ FIX: Update completion status map immediately for this habit
    // This ensures the last habit detection works correctly
    completionStatusMap[habit.id] = true

    // ✅ BUG FIX: Calculate completion status on-the-fly from actual habit data (don't use prefetched map)
    let remainingHabits = baseHabitsForSelectedDate.filter { h in
      if h.id == habit.id { return false } // Exclude current habit
      
      // ✅ CRITICAL: Check actual completion from the habits array (source of truth)
      // DON'T use completionStatusMap as it may be stale/prefetched
      let habitData = habits.first(where: { $0.id == h.id }) ?? h
      let dateKey = Habit.dateKey(for: selectedDate)
      
      // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
      // Both check: progress >= goal (extracted from goal string)
      let progress = habitData.completionHistory[dateKey] ?? 0
      let goalAmount = StreakDataCalculator.parseGoalAmount(from: habitData.goal)
      
      let isComplete: Bool
      if goalAmount > 0 {
        isComplete = progress >= goalAmount
        print("  🔍 \(habitData.habitType == .breaking ? "Breaking" : "Formation") habit '\(h.name)': progress=\(progress), goal=\(goalAmount), complete=\(isComplete)")
      } else {
        isComplete = progress > 0
        print("  🔍 Habit '\(h.name)': progress=\(progress) (fallback: any progress)")
      }
      
      // ✅ UNIVERSAL RULE: Both types use completionHistory
      print("🎯 CELEBRATION_CHECK: Habit '\(h.name)' (type=\(h.habitType)) | isComplete=\(isComplete) | progress=\(habitData.completionHistory[dateKey] ?? 0)")
      return !isComplete // Return true if NOT complete
    }

    if remainingHabits.isEmpty {
      // This is the last habit - set flag and let difficulty sheet be shown
      // The celebration will be triggered after the difficulty sheet is dismissed
      print(
        "🎯 COMPLETION_FLOW: Last habit completed - will trigger celebration after sheet dismissal")
      onLastHabitCompleted()
      // Don't set selectedHabit = nil here - let the difficulty sheet show
    } else {
      // Present difficulty sheet (existing logic)
      // Don't set selectedHabit here as it triggers habit detail screen
      // The difficulty sheet will be shown by the ScheduledHabitItem
      print("🎯 COMPLETION_FLOW: Habit completed, \(remainingHabits.count) remaining")
    }
  }

  private func onHabitUncompleted(_ habit: Habit) {
    // ✅ FIX: Update completion status map immediately for this habit
    completionStatusMap[habit.id] = false

    // ✅ FIX: Check if this uncomplete makes the day no longer fully completed
    Task {
      #if DEBUG
      debugRevokeCalls += 1
      print("🔍 DEBUG: onHabitUncompleted - revoke call #\(debugRevokeCalls)")
      #endif

      let dateKey = Habit.dateKey(for: selectedDate)
      print("🎯 UNCOMPLETE_FLOW: Habit '\(habit.name)' uncompleted for \(dateKey)")
      
      // Check if all habits are still completed for this date
      let habitsForDate = baseHabitsForSelectedDate
      let allCompleted = habitsForDate.allSatisfy { h in
        h.id == habit.id ? false : (completionStatusMap[h.id] ?? false)
      }
      
      // ✅ NEW APPROACH: Always recalculate XP from state (idempotent!)
      print("✅ DERIVED_XP: Recalculating XP after uncomplete")
      let completedDaysCount = countCompletedDays()
      await MainActor.run {
        xpManager.publishXP(completedDaysCount: completedDaysCount)  // ✅ Use environment object
      }
      print("✅ DERIVED_XP: XP recalculated to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
      
      // ✅ CRITICAL FIX: Recalculate streak reactively (just like XP)
      // Let the callback trigger a full recalculation from HomeView.updateAllStreaks()
      // This ensures streak always reflects current state, regardless of which day is uncompleted
      print("🔄 DERIVED_STREAK: Recalculating streak after uncomplete")
      await MainActor.run {
        onStreakRecalculationNeeded?()
      }
      print("✅ DERIVED_STREAK: Streak recalculation triggered")
      
      // Clean up DailyAward record if day is no longer complete
      if !allCompleted {
        guard let userId = AuthenticationManager.shared.currentUser?.uid else { return }
        
        let predicate = #Predicate<DailyAward> { award in
          award.userId == userId && award.dateKey == dateKey
        }
        let request = FetchDescriptor<DailyAward>(predicate: predicate)
        
        do {
          // ✅ FIX #12: Use SwiftDataContainer's context
          let modelContext = SwiftDataContainer.shared.modelContext
          let existingAwards = try modelContext.fetch(request)
          for award in existingAwards {
            modelContext.delete(award)
          }
          try modelContext.save()
          print("✅ UNCOMPLETE_FLOW: DailyAward removed for \(dateKey)")
          
          // ✅ REMOVED: No longer calling decrementGlobalStreak() here!
          // The onStreakRecalculationNeeded() callback above handles ALL streak updates
          // This prevents the old early-return logic from interfering with today's uncompletes
          print("✅ UNCOMPLETE_FLOW: Streak will be recalculated by callback (no manual decrement)")
        } catch {
          print("❌ UNCOMPLETE_FLOW: Failed to remove DailyAward: \(error)")
        }
      }
    }

    // Resort immediately
    deferResort = false
    resortHabits()
  }

  private func onDifficultySheetDismissed() {
    let dateKey = Habit.dateKey(for: selectedDate)

    print(
      "🎯 COMPLETION_FLOW: onDifficultySheetDismissed - dateKey=\(dateKey), userIdHash=debug_user_id, lastHabitJustCompleted=\(lastHabitJustCompleted)")

    // ✅ FIX: Wait 1 second before resorting to allow smooth sheet dismissal animation
    Task { @MainActor in
      print("🔄 COMPLETION_FLOW: Starting 1-second delay before resort...")
      print("   deferResort (before delay): \(deferResort)")
      print("   sortedHabits count (before delay): \(sortedHabits.count)")
      
      try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
      
      print("🔄 COMPLETION_FLOW: 1 second passed, now resorting...")
      
      // ✅ FIX: Refresh completion status map BEFORE resorting
      print("   Refreshing completionStatusMap...")
      await prefetchCompletionStatus()
      print("   ✅ completionStatusMap refreshed")
      
      print("   Setting deferResort = false")
      deferResort = false
      
      print("   Calling resortHabits() with animation...")
      withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        resortHabits()
      }
      
      print("✅ COMPLETION_FLOW: Resort completed!")
      print("   sortedHabits count (after resort): \(sortedHabits.count)")
      if !sortedHabits.isEmpty {
        for (index, habit) in sortedHabits.enumerated() {
          let isComplete = completionStatusMap[habit.id] ?? false
          print("   [\(index)] \(habit.name) - completed: \(isComplete)")
        }
      }
    }

    // Check if the last habit was just completed
    if lastHabitJustCompleted {
      // ✅ CORRECT: Call DailyAwardService to grant XP for completing all habits
      // This is the ONLY place where XP should be awarded for habit completion
      // Do NOT call XPManager methods directly - always use DailyAwardService
      let userId = getCurrentUserId()
      print(
        "🎉 COMPLETION_FLOW: Last habit completion sheet dismissed! Granting daily award for \(dateKey)")
      print("🎯 COMPLETION_FLOW: userId = \(userId)")

      Task {
        #if DEBUG
        debugGrantCalls += 1
        print(
          "🔍 DEBUG: onDifficultySheetDismissed - grant call #\(debugGrantCalls) from ui_sheet_dismiss")
        if debugGrantCalls > 1 {
          print("⚠️ WARNING: Multiple grant calls detected! Call #\(debugGrantCalls)")
          print("⚠️ Stack trace:")
          Thread.callStackSymbols.forEach { print("  \($0)") }
        }
        #endif

        print("✅ DERIVED_XP: Recalculating XP from completed days")
        
        // ✅ NEW APPROACH: Derive XP from state (idempotent!)
        let completedDaysCount = countCompletedDays()
        await MainActor.run {
          xpManager.publishXP(completedDaysCount: completedDaysCount)  // ✅ Use environment object
        }
        print("✅ DERIVED_XP: XP set to \(completedDaysCount * 50) (completedDays: \(completedDaysCount))")
        
        // ✅ CRITICAL FIX: Recalculate streak reactively (just like XP)
        // Let the callback trigger a full recalculation from HomeView.updateAllStreaks()
        // This ensures streak always reflects current state
        print("🔄 DERIVED_STREAK: Recalculating streak after completion")
        await MainActor.run {
          onStreakRecalculationNeeded?()
        }
        print("✅ DERIVED_STREAK: Streak recalculation triggered")
        
        do {
          // Still save DailyAward for history tracking
          // ✅ FIX #12: Use SwiftDataContainer's context
          let modelContext = SwiftDataContainer.shared.modelContext
          let dailyAward = DailyAward(
            userId: userId,
            dateKey: dateKey,
            xpGranted: 50,
            allHabitsCompleted: true
          )
          modelContext.insert(dailyAward)
          try modelContext.save()
          print("✅ COMPLETION_FLOW: DailyAward record created for history")
          
          // ✅ REMOVED: No longer calling updateGlobalStreak() here!
          // The onStreakRecalculationNeeded() callback above handles ALL streak updates
          // This prevents duplicate/conflicting streak calculations
          print("✅ COMPLETION_FLOW: Streak will be recalculated by callback (no manual update)")
          
          // Trigger celebration
          showCelebration = true
          print("🎉 COMPLETION_FLOW: Celebration triggered!")
          
          // ✅ REMOVED: No longer posting StreakUpdated notification manually
          // The callback will trigger updateAllStreaks() which updates GlobalStreakModel
          // SwiftUI @Query will automatically pick up the changes
          print("📢 COMPLETION_FLOW: Streak will update automatically via @Query")
        } catch {
          print("❌ COMPLETION_FLOW: Failed to award daily bonus: \(error)")
        }

        // Check XP after award
        let currentXP = xpManager.totalXP  // ✅ Use environment object
        print("🎯 COMPLETION_FLOW: Current XP after award: \(currentXP)")
        print("🎯 COMPLETION_FLOW: XPManager level: \(xpManager.currentLevel)")  // ✅ Use environment object
        
        // ✅ FIX: Call completion callback AFTER streak update completes
        await MainActor.run {
          onCompletionDismiss?()
          print("✅ COMPLETION_FLOW: Called onCompletionDismiss callback")
        }
      }

      // Reset the flag
      lastHabitJustCompleted = false
    } else {
      // ✅ FIX: Call completion callback even if not last habit
      onCompletionDismiss?()
      print("✅ COMPLETION_FLOW: Called onCompletionDismiss callback (not last habit)")
    }
  }

  private func onLastHabitCompleted() {
    deferResort = false
    resortHabits()

    // Set flag to trigger celebration when difficulty sheet is dismissed
    lastHabitJustCompleted = true

    // Note: XP will be awarded in onDifficultySheetDismissed() after the difficulty sheet is
    // dismissed
    print("🎉 STEP 1: Last habit completed! Will award XP after difficulty sheet is dismissed")
    print("🎯 STEP 1: lastHabitJustCompleted = \(lastHabitJustCompleted)")
  }

  private func getCurrentUserId() -> String {
    // ✅ FIX: Use actual userId from AuthenticationManager (same as HomeViewState)
    let userId = AuthenticationManager.shared.currentUser?.uid ?? "debug_user_id"
    print("🎯 USER SCOPING: HomeTabView.getCurrentUserId() = \(userId)")
    return userId
  }
  
  /// Update the global streak when all habits are completed for a day
  /// Returns the new streak value so it can be displayed in the UI immediately
  private func updateGlobalStreak(for userId: String, on date: Date, modelContext: ModelContext) throws -> Int {
    let calendar = Calendar.current
    let normalizedDate = calendar.startOfDay(for: date)
    let dateKey = Habit.dateKey(for: normalizedDate)
    
    print("🔥 STREAK_UPDATE: Updating global streak for \(dateKey)")
    
    // Get or create GlobalStreakModel
    let descriptor = FetchDescriptor<GlobalStreakModel>(
      predicate: #Predicate { streak in
        streak.userId == userId
      }
    )
    
    var streak: GlobalStreakModel
    if let existing = try modelContext.fetch(descriptor).first {
      streak = existing
      print("🔥 STREAK_UPDATE: Found existing streak - current: \(streak.currentStreak), longest: \(streak.longestStreak)")
    } else {
      streak = GlobalStreakModel(userId: userId)
      modelContext.insert(streak)
      print("🔥 STREAK_UPDATE: Created new streak for user \(userId)")
    }
    
    // Check if this is today
    let today = calendar.startOfDay(for: Date())
    let isToday = normalizedDate == today
    
    if isToday {
      // Increment streak for today
      let oldStreak = streak.currentStreak
      streak.incrementStreak(on: normalizedDate)
      let newStreak = streak.currentStreak
      
      try modelContext.save()
      print("✅ STREAK_UPDATE: Streak incremented \(oldStreak) → \(newStreak) for \(dateKey)")
      print("🔥 STREAK_UPDATE: Longest streak: \(streak.longestStreak), Total complete days: \(streak.totalCompleteDays)")
      
      return newStreak
    } else {
      // For past dates, just log a warning
      print("⚠️ STREAK_UPDATE: Completing past date \(dateKey) - streak may need recalculation")
      return streak.currentStreak
    }
  }
  
  /// Decrement the global streak when a previously complete day becomes incomplete
  /// Returns the new streak value so it can be displayed in the UI immediately
  private func decrementGlobalStreak(for userId: String, on date: Date, modelContext: ModelContext) async throws -> Int {
    let calendar = Calendar.current
    let normalizedDate = calendar.startOfDay(for: date)
    let dateKey = Habit.dateKey(for: normalizedDate)
    
    print("🔥 STREAK_REVERSAL: Decrementing global streak for \(dateKey)")
    
    // Get existing GlobalStreakModel
    let descriptor = FetchDescriptor<GlobalStreakModel>(
      predicate: #Predicate { streak in
        streak.userId == userId
      }
    )
    
    guard let streak = try modelContext.fetch(descriptor).first else {
      print("⚠️ STREAK_REVERSAL: No streak found for user \(userId), nothing to decrement")
      return 0
    }
    
    print("🔥 STREAK_REVERSAL: Found existing streak - current: \(streak.currentStreak)")
    
    // Check if this is today
    let today = calendar.startOfDay(for: Date())
    let isToday = normalizedDate == today
    
    if isToday {
      // ✅ CRITICAL FIX: Today's completion status should NOT affect the current streak
      // The streak only counts consecutive PAST completed days (yesterday and before)
      // Today is still in progress, so uncompleting today's habits should not decrement the streak
      print("ℹ️ STREAK_REVERSAL: Uncompleting today's habits - streak unchanged (today doesn't count until midnight)")
      return streak.currentStreak
    } else {
      // ✅ PAST DATE: Recalculate streak from scratch since we changed history
      print("⚠️ STREAK_REVERSAL: Uncompleting past date \(dateKey) - recalculating streak")
      
      // Decrement totalCompleteDays since a past completed day is now incomplete
      streak.totalCompleteDays = max(0, streak.totalCompleteDays - 1)
      
      // Recalculate streak by counting backwards from yesterday
      let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
      var calculatedStreak = 0
      var checkDate = yesterday
      
      // Count consecutive complete days backwards from yesterday
      while checkDate >= normalizedDate {
        // Check if all habits were complete on this date
        // Calculate dateKey outside the predicate (predicates can't call functions)
        let checkDateKey = Habit.dateKey(for: checkDate)
        let descriptor = FetchDescriptor<DailyAward>(
          predicate: #Predicate { award in
            award.userId == userId && award.dateKey == checkDateKey
          }
        )
        
        if let _ = try? modelContext.fetch(descriptor).first {
          calculatedStreak += 1
        } else {
          // First incomplete day found - stop counting
          break
        }
        
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
      }
      
      let oldStreak = streak.currentStreak
      streak.currentStreak = calculatedStreak
      
      try modelContext.save()
      print("✅ STREAK_REVERSAL: Streak recalculated \(oldStreak) → \(calculatedStreak) after uncompleting past date")
      print("🔥 STREAK_REVERSAL: Total complete days: \(streak.totalCompleteDays)")
      
      // Broadcast the new streak value
      await MainActor.run {
        NotificationCenter.default.post(
          name: NSNotification.Name("StreakUpdated"),
          object: nil,
          userInfo: ["newStreak": calculatedStreak]
        )
        print("📢 STREAK_REVERSAL: Posted StreakUpdated notification with newStreak: \(calculatedStreak)")
      }
      
      return calculatedStreak
    }
  }
}
