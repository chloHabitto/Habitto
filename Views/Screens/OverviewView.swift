import SwiftUI

struct OverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var streakStatistics = StreakStatistics(currentStreak: 0, longestStreak: 0, totalCompletionDays: 0)
    
    // Performance optimization: Cache expensive data
    @State private var yearlyHeatmapData: [[(intensity: Int, isScheduled: Bool, completionPercentage: Double)]] = []
    @State private var isDataLoaded: Bool = false
    @State private var isLoadingProgress: Double = 0.0
    @State private var isCalculating: Bool = false
    @EnvironmentObject var homeViewState: HomeViewState
    
    private var userHabits: [Habit] {
        let habits = homeViewState.habits
        print("🔍 OVERVIEW VIEW: userHabits computed property called - count: \(habits.count)")
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
    
    // Calendar state
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            StreakHeaderView(onDismiss: { dismiss() })
                .zIndex(10)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 16) {
                    // Main Streak Display
                    MainStreakDisplayView(currentStreak: streakStatistics.currentStreak)
                    
                    // Streak Summary Cards
                    StreakSummaryCardsView(
                        bestStreak: streakStatistics.longestStreak,
                        averageStreak: 0 // Not available in current StreakStatistics
                    )
                    
                    // Monthly Calendar
                    SimpleMonthlyCalendar(
                        selectedDate: $selectedDate,
                        userHabits: userHabits
                    )
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
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
            print("🔍 OVERVIEW VIEW DEBUG - Received HabitProgressUpdated notification via onReceive, refreshing data...")
            // Force refresh the data when habit progress changes
            isDataLoaded = false
            loadData()
        }
        .onChange(of: userHabits) { oldHabits, newHabits in
            print("🔍 OVERVIEW VIEW DEBUG - userHabits changed - Old count: \(oldHabits.count), New count: \(newHabits.count)")
            // Force refresh when habits change
            isDataLoaded = false
            loadData()
        }
        .onChange(of: selectedYear) { oldYear, newYear in
            print("🔍 OVERVIEW VIEW DEBUG - selectedYear changed - Old year: \(oldYear), New year: \(newYear)")
            // Force refresh yearly data when year changes
            if selectedProgressTab == 2 {
                isDataLoaded = false
                loadData()
            }
        }
        .sheet(isPresented: $showingCalendar) {
            WeekPickerModal(
                selectedWeekStartDate: $selectedWeekStartDate,
                isPresented: $showingCalendar
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthPickerModal(
                selectedMonth: $selectedMonth,
                isPresented: $showingMonthPicker
            )
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showingYearPicker) {
            YearPickerModal(
                selectedYear: $selectedYear,
                isPresented: $showingYearPicker
            )
            .presentationDetents([.height(400), .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(32)
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
        print("🔍 OVERVIEW VIEW DEBUG - loadData() called with isDataLoaded: \(isDataLoaded)")
        
        // Debug: Print current habit data for troubleshooting
        print("🔍 OVERVIEW VIEW DEBUG - Loading data for \(userHabits.count) habits")
        for habit in userHabits {
            let todayKey = DateUtils.dateKey(for: Date())
            let todayProgress = habit.getProgress(for: Date())
            print("🔍 OVERVIEW VIEW DEBUG - Habit: '\(habit.name)' | Schedule: '\(habit.schedule)' | StartDate: \(DateUtils.dateKey(for: habit.startDate)) | Today(\(todayKey)) Progress: \(todayProgress) | CompletionHistory keys: \(habit.completionHistory.keys.sorted())")
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
            print("🔍 OVERVIEW VIEW DEBUG - Received HabitProgressUpdated notification, refreshing data...")
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
    OverviewView()
        .environmentObject(HomeViewState())
}
