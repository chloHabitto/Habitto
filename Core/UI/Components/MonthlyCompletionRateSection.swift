import SwiftUI

struct MonthlyCompletionRateSection: View {
    let monthlyCompletionRate: Double
    let monthlyCompletedHabits: Int
    let monthlyTotalHabits: Int
    let topPerformingHabit: Habit?
    let needsAttentionHabit: Habit?
    let progressTrendColor: Color
    let progressTrendIcon: String
    let progressTrendText: String
    let progressTrendDescription: String
    let monthlyHabitCompletionRate: (Habit) -> Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Monthly Progress")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Completion rate card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Circular progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.primaryContainer, lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: monthlyCompletionRate)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        // Percentage text
                        Text("\(Int(monthlyCompletionRate * 100))%")
                            .font(.appLabelMedium)
                            .foregroundColor(.text01)
                            .fontWeight(.semibold)
                    }
                    
                    // Progress details
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Completion Rate")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                        
                        Text("\(monthlyCompletedHabits) of \(monthlyTotalHabits) habits")
                            .font(.appBodySmall)
                            .foregroundColor(.text02)
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.outline3, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Habit Performance Breakdown Section
            HabitPerformanceBreakdownSection(
                topPerformingHabit: topPerformingHabit,
                needsAttentionHabit: needsAttentionHabit,
                progressTrendColor: progressTrendColor,
                progressTrendIcon: progressTrendIcon,
                progressTrendText: progressTrendText,
                progressTrendDescription: progressTrendDescription,
                monthlyHabitCompletionRate: monthlyHabitCompletionRate
            )
        }
    }
}

// MARK: - Habit Performance Breakdown Section
struct HabitPerformanceBreakdownSection: View {
    let topPerformingHabit: Habit?
    let needsAttentionHabit: Habit?
    let progressTrendColor: Color
    let progressTrendIcon: String
    let progressTrendText: String
    let progressTrendDescription: String
    let monthlyHabitCompletionRate: (Habit) -> Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Habit Performance")
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.onPrimaryContainer)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Performance breakdown cards
            VStack(spacing: 12) {
                // Top Performing Habit
                HabitPerformanceCard(
                    icon: "star.fill",
                    iconColor: .green,
                    title: "Top Performing",
                    habitName: topPerformingHabit?.name ?? "No habits",
                    completionRate: topPerformingHabit.map { monthlyHabitCompletionRate($0) } ?? 0,
                    accentColor: .green
                )
                
                // Needs Attention Habit
                HabitPerformanceCard(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "Needs Attention",
                    habitName: needsAttentionHabit?.name ?? "No habits",
                    completionRate: needsAttentionHabit.map { monthlyHabitCompletionRate($0) } ?? 0,
                    accentColor: .orange
                )
                
                // Progress Trend
                HabitPerformanceCard(
                    icon: progressTrendIcon,
                    iconColor: progressTrendColor,
                    title: "Progress Trend",
                    habitName: progressTrendText,
                    completionRate: 0,
                    accentColor: progressTrendColor,
                    showCompletionRate: false,
                    subtitle: progressTrendDescription
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Individual Performance Card
struct HabitPerformanceCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let habitName: String
    let completionRate: Double
    let accentColor: Color
    let showCompletionRate: Bool
    let subtitle: String?
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        habitName: String,
        completionRate: Double,
        accentColor: Color,
        showCompletionRate: Bool = true,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.habitName = habitName
        self.completionRate = completionRate
        self.accentColor = accentColor
        self.showCompletionRate = showCompletionRate
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Habit details
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appLabelSmall)
                    .foregroundColor(.text02)
                
                Text(habitName)
                    .font(.appBodyMedium)
                    .foregroundColor(.text01)
                    .lineLimit(1)
                
                if showCompletionRate {
                    Text("\(Int(completionRate * 100))% completion")
                        .font(.appLabelSmall)
                        .foregroundColor(accentColor)
                } else if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.appLabelSmall)
                        .foregroundColor(accentColor)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outline3, lineWidth: 1)
        )
    }
}
