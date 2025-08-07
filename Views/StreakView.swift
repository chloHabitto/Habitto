import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var streakStatistics = StreakStatistics(currentStreak: 0, bestStreak: 0, averageStreak: 0, completionRate: 0, consistencyRate: 0)
    
    // Performance optimization: Cache expensive data
    @State private var yearlyHeatmapData: [[Int]] = []
    @State private var isDataLoaded = false
    let userHabits: [Habit]
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    
    // Performance optimization: Pagination for large datasets
    @State private var currentYearlyPage = 0
    private let yearlyItemsPerPage = 50
    
    // Date selection state
    @State private var selectedWeekStartDate: Date = Date.currentWeekStartDate()
    @State private var showingCalendar = false
    
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
                        }
                                    ) {
                    VStack(spacing: 0) {
                        // Fixed Header Section (Title + More Button + Tabs)
                        VStack(spacing: 16) {
                            // Progress tabs
                            ProgressTabsView(selectedTab: selectedProgressTab) { index in
                                selectedProgressTab = index
                            }
                        }
                        
                        // Scrollable Content Section
                        ScrollView {
                            VStack(spacing: 16) {
                                // Date range selector
                                DateRangeSelectorView(
                                    weekRangeText: selectedWeekStartDate.weekRangeText(),
                                    onTap: { showingCalendar = true }
                                )
                                
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
                                        MonthlyCalendarGridView(userHabits: userHabits)
                                    } else {
                                        // Yearly view
                                        YearlyCalendarGridView(
                                            userHabits: userHabits,
                                            yearlyHeatmapData: yearlyHeatmapData,
                                            isDataLoaded: isDataLoaded
                                        )
                                    }
                                }
                                
                                // Summary Statistics
                                SummaryStatisticsView(
                                    completionRate: streakStatistics.completionRate,
                                    bestStreak: streakStatistics.bestStreak,
                                    consistencyRate: streakStatistics.consistencyRate
                                )
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
                            dragOffset = max(translation, -250) // 12 points more header space (262 - 12)
                                        } else { // Dragging down
                                            dragOffset = min(translation, 0) // Limit downward drag
                                        }
                                    }
                                    .onEnded { value in
                                        let translation = value.translation.height
                                        let velocity = value.velocity.height
                                        
                                        if translation < -150 || velocity < -300 { // Increased expand threshold
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isExpanded = true
                                dragOffset = -250 // 12 points more header space (262 - 12)
                                            }
                                        } else if translation > 25 || velocity > 300 { // Collapse threshold
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isExpanded = false
                                                dragOffset = 0
                                            }
                                        } else { // Return to current state
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                dragOffset = isExpanded ? -250 : 0
                                            }
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
            loadData()
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
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
        // Calculate streak statistics from actual user data
        streakStatistics = StreakDataCalculator.calculateStreakStatistics(from: userHabits)
        
        // Load data on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let yearlyData = StreakDataCalculator.generateYearlyDataFromHabits(
                self.userHabits,
                startIndex: self.currentYearlyPage * self.yearlyItemsPerPage,
                itemsPerPage: self.yearlyItemsPerPage
            )
            
            DispatchQueue.main.async {
                self.yearlyHeatmapData = yearlyData
                self.isDataLoaded = true
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
                weekRangeText: selectedWeekStartDate.weekRangeText(),
                onTap: { showingCalendar = true }
            )
            
            // Content based on selected tab
            Group {
                if selectedProgressTab == 0 {
                    // Weekly view
                    WeeklyCalendarGridView(
                        userHabits: userHabits,
                        selectedWeekStartDate: selectedWeekStartDate
                    )
                } else if selectedProgressTab == 1 {
                    // Monthly view
                    MonthlyCalendarGridView(userHabits: userHabits)
                } else {
                    // Yearly view
                    YearlyCalendarGridView(
                        userHabits: userHabits,
                        yearlyHeatmapData: yearlyHeatmapData,
                        isDataLoaded: isDataLoaded
                    )
                }
            }
        }
        .padding(.bottom, 16)
    }
    

}

#Preview {
    StreakView(userHabits: [])
}

