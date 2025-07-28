import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var averageStreak = 0
    @State private var completionRate = 0
    @State private var consistencyRate = 0
    
    // Performance optimization: Cache expensive data
    @State private var yearlyHeatmapData: [[Int]] = []
    @State private var isDataLoaded = false
    
    private let progressTabs = ["Weekly", "Monthly", "Yearly"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header Section
            headerSection
                .background(Color.primary)
                .zIndex(1)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Main Streak Display
                    mainStreakDisplay
                    
                    // Streak Summary Cards
                    streakSummaryCards
                    
                    // White sheet that expands to bottom
                    VStack(spacing: 24) {
                        // Progress Section
                        progressSection
                        
                        // Summary Statistics
                        summaryStatistics
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .roundedTopBackground()
                }
            }
        }
        .background(Color.primary)
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaInset(edge: .top) {
            Color.clear
                .frame(height: 0)
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        guard !isDataLoaded else { return }
        
        // Load data on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let yearlyData = [
                generateYearlyData(),
                generateYearlyData(),
                generateYearlyData()
            ]
            
            DispatchQueue.main.async {
                self.yearlyHeatmapData = yearlyData
                self.isDataLoaded = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Main Streak Display
    private var mainStreakDisplay: some View {
        VStack(spacing: 16) {
            // Large circle with flame icon
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Flame icon (using custom Icon-fire)
                Image("Icon-fire")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.warning, ColorPrimitives.yellow400],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Streak count
            Text("\(currentStreak) days")
                .font(.appDisplaySmallEmphasised)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Streak Summary Cards
    private var streakSummaryCards: some View {
        HStack(spacing: 0) {
            // Best streak card
            streakCard(
                icon: "Icon-starBadge",
                iconColor: .warning,
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            // Divider
            Rectangle()
                .fill(.outline)
                .frame(width: 1)
                .frame(height: 60)
            
            // Average streak card
            streakCard(
                icon: "Icon-medalBadge",
                iconColor: ColorPrimitives.yellow400,
                value: "\(averageStreak) days",
                label: "Average streak"
            )
        }
        .background(.surfaceContainer)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private func streakCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if icon.hasPrefix("Icon-") {
                    // Custom image
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor)
                } else {
                    // System icon
                    Image(systemName: icon)
                        .font(.appTitleMedium)
                        .foregroundColor(iconColor)
                }
                
                Text(value)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text01)
            }
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress title
            HStack {
                Text("Progress")
                    .font(.appHeadlineSmallEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
            }
            
            // Progress tabs
            progressTabsView
            
            // Date range selector
            dateRangeSelector
            
            // Content based on selected tab
            Group {
                if selectedProgressTab == 0 {
                    // Weekly view
                    weeklyCalendarGrid
                } else if selectedProgressTab == 1 {
                    // Monthly view
                    monthlyCalendarGrid
                } else {
                    // Yearly view
                    yearlyCalendarGrid
                }
            }
        }
        .padding(.vertical, 12)
    }
    
    private var progressTabsView: some View {
        HStack(spacing: 0) {
            ForEach(0..<progressTabs.count, id: \.self) { index in
                VStack(spacing: 0) {
                    Button(action: {
                        selectedProgressTab = index
                    }) {
                        Text(progressTabs[index])
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(selectedProgressTab == index ? .text03 : .text04)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Bottom stroke for each tab
                    Rectangle()
                        .fill(selectedProgressTab == index ? .text03 : .divider)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.2), value: selectedProgressTab)
                }
            }
            
            Spacer()
            
            Button(action: {
                // More options action
            }) {
                Image(systemName: "ellipsis")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(height: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    private var dateRangeSelector: some View {
        HStack {
            Text("June 09 - June 15")
                .font(.appBodyMedium)
                .foregroundColor(.text01)
            
            Image(systemName: "chevron.down")
                .font(.appBodySmall)
                .foregroundColor(.text04)
            
            Spacer()
        }
    }
    
    // MARK: - Weekly Calendar Grid
    private var weeklyCalendarGrid: some View {
        VStack(spacing: 12) {
            // Days of week header
            HStack(spacing: 0) {
                // Empty space for habit names
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Habit rows with heatmap
            ForEach(0..<3, id: \.self) { habitIndex in
                HStack(spacing: 0) {
                    // Habit name
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                            .cornerRadius(2)
                        
                        Text(habitNames[habitIndex])
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    // Heatmap cells
                    ForEach(0..<7, id: \.self) { dayIndex in
                        heatmapCell(intensity: heatmapData[habitIndex][dayIndex])
                    }
                }
            }
            
            // Total row
            HStack(spacing: 0) {
                Text("Total")
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.text01)
                    .frame(width: 80, alignment: .leading)
                
                ForEach(0..<7, id: \.self) { dayIndex in
                    heatmapCell(intensity: totalHeatmapData[dayIndex])
                }
            }
        }
    }
    
    // MARK: - Monthly Calendar Grid
    private var monthlyCalendarGrid: some View {
        VStack(spacing: 12) {
            // Days of week header
            HStack(spacing: 0) {
                // Empty space for habit names
                Rectangle()
                    .fill(.clear)
                    .frame(width: 80)
                
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Month weeks (4-5 weeks)
            ForEach(0..<5, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    // Week label
                    Text("Week \(weekIndex + 1)")
                        .font(.appBodySmall)
                        .foregroundColor(.text04)
                        .frame(width: 80, alignment: .leading)
                    
                    // Week heatmap cells
                    ForEach(0..<7, id: \.self) { dayIndex in
                        heatmapCell(intensity: monthlyHeatmapData[weekIndex][dayIndex])
                    }
                }
            }
            
            // Total row
            HStack(spacing: 0) {
                Text("Total")
                    .font(.appBodyMediumEmphasised)
                    .foregroundColor(.text01)
                    .frame(width: 80, alignment: .leading)
                
                ForEach(0..<7, id: \.self) { dayIndex in
                    heatmapCell(intensity: monthlyTotalHeatmapData[dayIndex])
                }
            }
        }
    }
    
    // MARK: - Yearly Calendar Grid (Optimized)
    private var yearlyCalendarGrid: some View {
        VStack(spacing: 12) {
            if isDataLoaded {
                // Habit rows with yearly heatmap (365 days)
                ForEach(0..<3, id: \.self) { habitIndex in
                    VStack(spacing: 6) {
                        // Habit name
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 8)
                                .cornerRadius(2)
                            
                            Text(yearlyHabitNames[habitIndex])
                                .font(.appBodyMedium)
                                .foregroundColor(.text01)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Yearly heatmap (365 rectangles) - Optimized rendering
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 30), spacing: 0) {
                            ForEach(0..<365, id: \.self) { dayIndex in
                                heatmapCell(intensity: yearlyHeatmapData[habitIndex][dayIndex])
                                    .frame(height: 4)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .padding(.vertical, 6)
                }
            } else {
                // Loading placeholder
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading heatmap data...")
                        .font(.appBodyMedium)
                        .foregroundColor(.text04)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func heatmapCell(intensity: Int) -> some View {
        Rectangle()
            .fill(heatmapColor(for: intensity))
            .cornerRadius(2)
    }
    
    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            return .surfaceContainer
        case 1:
            return ColorPrimitives.green500.opacity(0.3)
        case 2:
            return ColorPrimitives.green500.opacity(0.6)
        case 3:
            return ColorPrimitives.green500
        default:
            return .surfaceContainer
        }
    }
    
    private func generateYearlyData() -> [Int] {
        var data: [Int] = []
        for _ in 0..<365 {
            data.append(Int.random(in: 0...3))
        }
        return data
    }
    
    // MARK: - Static Data (Performance optimization)
    private var habitNames: [String] {
        ["Exercise", "Read", "Meditate"]
    }
    
    private var yearlyHabitNames: [String] {
        ["Exercise", "Read", "Meditate"]
    }
    
    private var heatmapData: [[Int]] {
        [
            [3, 2, 3, 1, 2, 3, 0], // Exercise
            [2, 1, 2, 3, 2, 1, 2], // Read
            [1, 3, 2, 2, 3, 2, 1]  // Meditate
        ]
    }
    
    private var totalHeatmapData: [Int] {
        [6, 6, 7, 6, 7, 6, 3] // Sum of each day
    }
    
    private var monthlyHeatmapData: [[Int]] {
        [
            [3, 2, 3, 1, 2, 3, 0], // Week 1
            [2, 1, 2, 3, 2, 1, 2], // Week 2
            [1, 3, 2, 2, 3, 2, 1], // Week 3
            [3, 2, 1, 3, 2, 3, 2], // Week 4
            [2, 3, 2, 1, 2, 1, 3]  // Week 5
        ]
    }
    
    private var monthlyTotalHeatmapData: [Int] {
        [11, 11, 10, 10, 11, 10, 8] // Sum of each day across weeks
    }
    
    // MARK: - Summary Statistics
    private var summaryStatistics: some View {
        HStack(spacing: 12) {
            // Completion card
            statisticCard(
                value: "\(completionRate)%",
                label: "Completion"
            )
            
            // Best streak card
            statisticCard(
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            // Consistency card
            statisticCard(
                value: "\(consistencyRate)%",
                label: "Consistency"
            )
        }
    }
    
    private func statisticCard(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text01)
            
            Text(label)
                .font(.appBodyMedium)
                .foregroundColor(.text01)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.surfaceContainer)
        .cornerRadius(12)
    }
}



#Preview {
    StreakView()
}