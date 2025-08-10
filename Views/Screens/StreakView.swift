import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var streakStatistics = StreakStatistics(currentStreak: 0, bestStreak: 0, averageStreak: 0, completionRate: 0, consistencyRate: 0)
    
    // Performance optimization: Cache expensive data
    @State private var yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] = []
    @State private var isDataLoaded: Bool = false
    @State private var isLoadingProgress: Double = 0.0
    @State private var isCalculating: Bool = false
    @EnvironmentObject var homeViewState: HomeViewState
    
    private var userHabits: [Habit] {
        let habits = homeViewState.habits
        print("🔍 STREAK VIEW: userHabits computed property called - count: \(habits.count)")
        return habits
    }
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    
    // Swipe to dismiss animation state
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissing = false
    
    // Performance optimization: Pagination for large datasets
    @State private var currentYearlyPage = 0
    private let yearlyItemsPerPage = 50
    
    // Date selection state
    @State private var selectedWeekStartDate: Date = Date.currentWeekStartDate()
    @State private var selectedMonth: Date = Date.currentMonthStartDate()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showingCalendar = false
    @State private var showingMonthPicker = false
    @State private var showingYearPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            StreakHeaderView(onDismiss: { dismiss() })
                .zIndex(1)
            
                        // Fixed Primary Background Content (Non-scrollable)
            VStack(spacing: 16) {
                    // Main Streak Display
                MainStreakDisplayView(currentStreak: streakStatistics.currentStreak)
                    
                    // Streak Summary Cards
                StreakSummaryCardsView(
                    bestStreak: streakStatistics.bestStreak,
                    averageStreak: streakStatistics.averageStreak
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .offset(y: -20)
            .opacity(dragOffset < 0 ? max(0, 1.0 + (dragOffset / 100.0)) : 1.0)
            
            // White sheet that expands to bottom (with its own internal scrolling)
            GeometryReader { geometry in
                    WhiteSheetContainer(
                        title: "Habit Streak",
                        rightButton: {
                            AnyView(
                                Button(action: {
                                    // More button action
                                }) {
                                    Image("Icon-moreDots")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                                .buttonStyle(PlainButtonStyle())
                            )
                    },
                    showGrabber: true
                ) {
                    VStack(spacing: 0) {
                        // Fixed Header Section (Title + More Button + Tabs)
                        VStack(spacing: 16) {
                            // Progress tabs - isolated from drag animations
                            ZStack {
                                UnifiedTabBarView(
                                    tabs: [
                                        TabItem(title: "Weekly"),
                                        TabItem(title: "Monthly"),
                                        TabItem(title: "Yearly")
                                    ],
                                    selectedIndex: selectedProgressTab,
                                    style: .underline
                                ) { index in
                                    selectedProgressTab = index
                                }
                            }
                            .allowsHitTesting(true)
                            .animation(nil, value: selectedProgressTab)
                            .animation(nil, value: dragOffset)
                        }
                        .animation(nil, value: dragOffset)
                        
                        // Scrollable Content Section
                        ScrollView {
                            VStack(spacing: 16) {
                                                        // Date range selector - show week for weekly, month for monthly, year for yearly
                        DateRangeSelectorView(
                            displayText: selectedProgressTab == 2 ? "Year \(selectedYear)" : (selectedProgressTab == 1 ? selectedMonth.monthText() : selectedWeekStartDate.weekRangeText()),
                            onTap: { 
                                if selectedProgressTab == 2 {
                                    showingYearPicker = true
                                } else if selectedProgressTab == 1 {
                                    showingMonthPicker = true
                                } else {
                                    showingCalendar = true
                                }
                            },
                            showDownChevron: true
                        )
                        
                        // Debug: Print current week info
                        .onAppear {
                            print("🔍 STREAK VIEW DEBUG - Current week start: \(DateUtils.dateKey(for: selectedWeekStartDate)) | Week range: \(selectedWeekStartDate.weekRangeText())")
                        }
                                
                                // Calendar content based on selected tab
                                Group {
                                    if selectedProgressTab == 0 {
                                        // Weekly view
                                        WeeklyCalendarGridView(
                                            userHabits: userHabits,
                                            selectedWeekStartDate: selectedWeekStartDate
                                        )
                                    } else if selectedProgressTab == 1 {
                                        // Monthly view
                                        MonthlyCalendarGridView(
                                            userHabits: userHabits,
                                            selectedMonth: selectedMonth
                                        )
                                    } else {
                                        // Yearly view
                                        YearlyCalendarGridView(
                                            userHabits: userHabits,
                                            selectedWeekStartDate: selectedWeekStartDate,
                                            yearlyHeatmapData: yearlyHeatmapData,
                                            isDataLoaded: isDataLoaded,
                                            isLoadingProgress: isLoadingProgress
                                        )
                                    }
                                }
                            
                            // Summary Statistics - Only show for Weekly tab, not Monthly or Yearly
                            if selectedProgressTab == 0 {
                                SummaryStatisticsView(
                                    completionRate: streakStatistics.completionRate,
                                    bestStreak: streakStatistics.bestStreak,
                                    consistencyRate: streakStatistics.consistencyRate
                                )
                            }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height + (dragOffset < 0 ? abs(dragOffset) : 0)
                )
                    .offset(y: dragOffset)
                .ignoresSafeArea(.container, edges: .bottom)
            }
                                                .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let translation = value.translation.height
                                        if translation < 0 { // Dragging up
                            dragOffset = max(translation, -234) // 16 points more header space (250 - 16)
                                        } else { // Dragging down
                                            dragOffset = min(translation, 0) // Limit downward drag
                                        }
                                    }
                                    .onEnded { value in
                                        let translation = value.translation.height
                                        let velocity = value.velocity.height
                                        
                                        if translation < -150 || velocity < -300 { // Increased expand threshold
                                                isExpanded = true
                                            dragOffset = -234 // 16 points more header space (250 - 16)
                                        } else if translation > 25 || velocity > 300 { // Collapse threshold
                                                isExpanded = false
                                                dragOffset = 0
                                        } else { // Return to current state
                                            dragOffset = isExpanded ? -234 : 0
                                        }
                                    }
                            )
                }
        .background(Color.primary)
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.primary
                .frame(height: 0)
        }
        .onAppear {
            setupNotificationObserver()
            loadData()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HabitProgressUpdated"))) { _ in
            print("🔍 STREAK VIEW DEBUG - Received HabitProgressUpdated notification via onReceive, refreshing data...")
            // Force refresh the data when habit progress changes
            isDataLoaded = false
            loadData()
        }
        .onChange(of: userHabits) { oldHabits, newHabits in
            print("🔍 STREAK VIEW DEBUG - userHabits changed - Old count: \(oldHabits.count), New count: \(newHabits.count)")
            // Force refresh when habits change
            isDataLoaded = false
            loadData()
        }
        .onChange(of: selectedYear) { oldYear, newYear in
            print("🔍 STREAK VIEW DEBUG - selectedYear changed - Old year: \(oldYear), New year: \(newYear)")
            // Force refresh yearly data when year changes
            if selectedProgressTab == 2 {
                isDataLoaded = false
                loadData()
            }
        }
        .overlay(
            // Pop-up Modal for week selection
            showingCalendar ? AnyView(
                WeekPickerModal(
                    selectedWeekStartDate: $selectedWeekStartDate,
                    isPresented: $showingCalendar
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingCalendar)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Pop-up Modal for month selection
            showingMonthPicker ? AnyView(
                MonthPickerModal(
                    selectedMonth: $selectedMonth,
                    isPresented: $showingMonthPicker
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingMonthPicker)
            ) : AnyView(EmptyView())
        )
        .overlay(
            // Pop-up Modal for year selection
            showingYearPicker ? AnyView(
                YearPickerModal(
                    selectedYear: $selectedYear,
                    isPresented: $showingYearPicker
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.3), value: showingYearPicker)
            ) : AnyView(EmptyView())
        )
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
        print("🔍 STREAK VIEW DEBUG - loadData() called with isDataLoaded: \(isDataLoaded)")
        
        // Debug: Print current habit data for troubleshooting
        print("🔍 STREAK VIEW DEBUG - Loading data for \(userHabits.count) habits")
        for habit in userHabits {
            let todayKey = DateUtils.dateKey(for: Date())
            let todayProgress = habit.getProgress(for: Date())
            print("🔍 STREAK VIEW DEBUG - Habit: '\(habit.name)' | Schedule: '\(habit.schedule)' | StartDate: \(DateUtils.dateKey(for: habit.startDate)) | Today(\(todayKey)) Progress: \(todayProgress) | CompletionHistory keys: \(habit.completionHistory.keys.sorted())")
        }
        
        // Calculate streak statistics from actual user data
        streakStatistics = StreakDataCalculator.calculateStreakStatistics(from: userHabits)
        
        // Load data on background thread to avoid blocking UI
        loadYearlyData()
    }
    
    // MARK: - Notification Handling
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HabitProgressUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔍 STREAK VIEW DEBUG - Received HabitProgressUpdated notification, refreshing data...")
            // Force refresh the data when habit progress changes
            isDataLoaded = false
            loadData()
        }
    }
    
    private func loadYearlyData() {
        // Performance optimization: Use async background processing
        isCalculating = true
        isLoadingProgress = 0.0
        
        Task {
            let yearlyData = await StreakDataCalculator.generateYearlyDataFromHabitsAsync(
                self.userHabits,
                startIndex: self.currentYearlyPage * self.yearlyItemsPerPage,
                itemsPerPage: self.yearlyItemsPerPage,
                forYear: self.selectedYear
            ) { progress in
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isLoadingProgress = progress
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.yearlyHeatmapData = yearlyData
                self.isDataLoaded = true
                self.isCalculating = false
                self.isLoadingProgress = 0.0
            }
        }
    }
    

    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress tabs
            ProgressTabsView(selectedTab: selectedProgressTab) { index in
                selectedProgressTab = index
            }
            
            // Date range selector
            DateRangeSelectorView(
                displayText: selectedWeekStartDate.weekRangeText(),
                onTap: { showingCalendar = true },
                showDownChevron: true
            )
            
            // Content based on selected tab
            if selectedProgressTab == 0 {
                // Weekly view
                WeeklyCalendarGridView(
                    userHabits: userHabits,
                    selectedWeekStartDate: selectedWeekStartDate
                )
                            } else if selectedProgressTab == 1 {
                    // Monthly view
                    MonthlyCalendarGridView(
                        userHabits: userHabits,
                        selectedMonth: selectedMonth
                    )
            } else {
                // Yearly view
                YearlyCalendarGridView(
                    userHabits: userHabits,
                    selectedWeekStartDate: selectedWeekStartDate,
                    yearlyHeatmapData: yearlyHeatmapData,
                    isDataLoaded: isDataLoaded,
                    isLoadingProgress: isLoadingProgress
                )
            }
        }
        .padding(.bottom, 16)
        .background(
            // Extended background that covers the revealed area during swipe
            Color(.systemBackground)
                .frame(width: UIScreen.main.bounds.width + abs(dismissOffset), height: UIScreen.main.bounds.height)
                .offset(x: dismissOffset < 0 ? dismissOffset : 0)
        )
        .offset(x: dismissOffset)
        .opacity(isDismissing ? 0 : 1)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow rightward swipes (positive translation)
                    if value.translation.width > 0 {
                        dismissOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    // Swipe right to dismiss (like back button)
                    if value.translation.width > 100 && abs(value.translation.height) < 100 {
                        // Animate the dismiss
                        withAnimation(.easeOut(duration: 0.25)) {
                            dismissOffset = UIScreen.main.bounds.width
                            isDismissing = true
                        }
                        // Dismiss immediately without animation after our animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            // Dismiss without any animation
                            dismiss()
                        }
                    } else {
                        // Snap back if swipe wasn't far enough
                        withAnimation(.spring()) {
                            dismissOffset = 0
                        }
                    }
                }
        )
    }
    

}

#Preview {
    StreakView()
        .environmentObject(HomeViewState())
}

