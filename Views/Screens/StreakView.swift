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
    
    // Swipe to dismiss animation state
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissing = false
    
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
                .zIndex(10)
            
            // Fixed Primary Background Content (Non-scrollable)
            VStack(spacing: 16) {
                // Main Streak Display
                MainStreakDisplayView(currentStreak: streakStatistics.currentStreak)
                
                // Streak Summary Cards
                StreakSummaryCardsView(
                    bestStreak: streakStatistics.bestStreak,
                    averageStreak: streakStatistics.averageStreak
                )
                
                // Coming soon empty state
                HabitEmptyStateView.comingSoon()
                    .padding(.top, 40)
                
                // Spacer to push content to top
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary)
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
                startIndex: 0, // Always start from beginning for yearly view
                itemsPerPage: self.userHabits.count, // Load all habits at once
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
                
                // Debug: Print data structure
                print("🔍 YEARLY DATA LOADED - Habits: \(self.userHabits.count), Data arrays: \(yearlyData.count)")
                for (index, habitData) in yearlyData.enumerated() {
                    print("🔍 YEARLY DATA DEBUG - Habit \(index): \(habitData.count) days")
                }
            }
        }
    }
}

#Preview {
    StreakView()
        .environmentObject(HomeViewState())
}
