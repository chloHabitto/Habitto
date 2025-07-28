import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgressTab = 0
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var averageStreak = 0
    @State private var completionRate = 0
    @State private var consistencyRate = 0
    
    private let progressTabs = ["Weekly", "Monthly", "Yearly"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main Streak Display
                    mainStreakDisplay
                    
                    // Streak Summary Cards
                    streakSummaryCards
                    
                    // Content in ZStack with white background
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
                .padding(.bottom, 24)
            }
        }
        .background(Color.primary)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
            }
            
            Spacer()
            
            Text("My streak")
                .font(.appHeadlineMediumEmphasised)
                .foregroundColor(.text01)
            
            Spacer()
            
            // Invisible spacer to center the title
            Image(systemName: "chevron.left")
                .font(.appTitleMedium)
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
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
                
                // Flame icon (using SF Symbol)
                Image(systemName: "flame.fill")
                    .font(.system(size: 48, weight: .medium))
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
                .foregroundColor(.text01)
        }
    }
    
    // MARK: - Streak Summary Cards
    private var streakSummaryCards: some View {
        HStack(spacing: 12) {
            // Best streak card
            streakCard(
                icon: "flame.fill",
                iconColor: .warning,
                value: "\(bestStreak) days",
                label: "Best streak"
            )
            
            // Average streak card
            streakCard(
                icon: "star.fill",
                iconColor: ColorPrimitives.yellow400,
                value: "\(averageStreak) days",
                label: "Average streak"
            )
        }
    }
    
    private func streakCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.appTitleMedium)
                    .foregroundColor(iconColor)
                
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
        .background(.surfaceContainer)
        .cornerRadius(12)
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
            
            // Weekly calendar grid
            weeklyCalendarGrid
        }
        .padding(.vertical, 12)
    }
    
    private var progressTabsView: some View {
        HStack(spacing: 0) {
            ForEach(0..<progressTabs.count, id: \.self) { index in
                Button(action: {
                    selectedProgressTab = index
                }) {
                    Text(progressTabs[index])
                        .font(.appBodyMedium)
                        .foregroundColor(selectedProgressTab == index ? .text01 : .text04)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            VStack {
                                Spacer()
                                if selectedProgressTab == index {
                                    Rectangle()
                                        .fill(Color.primary)
                                        .frame(height: 2)
                                }
                            }
                        )
                }
            }
            
            Spacer()
            
            Button(action: {
                // More options action
            }) {
                Image(systemName: "ellipsis")
                    .font(.appBodyMedium)
                    .foregroundColor(.text04)
                    .padding(.horizontal, 8)
            }
        }
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
            
            // Habit rows
            ForEach(0..<4, id: \.self) { habitIndex in
                HStack(spacing: 0) {
                    // Habit name
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                            .cornerRadius(2)
                        
                        Text("Habit Name")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    // Calendar cells
                    ForEach(0..<7, id: \.self) { dayIndex in
                        Rectangle()
                            .fill(.surfaceContainer)
                            .frame(height: 24)
                            .cornerRadius(4)
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
                    Rectangle()
                        .fill(.surfaceContainer)
                        .frame(height: 24)
                        .cornerRadius(4)
                }
            }
        }
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