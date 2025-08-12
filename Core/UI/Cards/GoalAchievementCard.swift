import SwiftUI

struct GoalAchievementCard: View {
    let habitGoal: HabitGoal
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habitGoal.habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habitGoal.habit)
            
            // VStack with title, goal info, and progress
            VStack(spacing: 8) {
                // Top row: Text container and badge
                HStack(alignment: .center, spacing: 12) {
                    // Text container
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habitGoal.habit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text02)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text("Goal: \(Int(habitGoal.goal.amount)) \(habitGoal.goal.unit)")
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    
                    // Goal Hit Rate Badge
                    HStack(spacing: 4) {
                        Image(systemName: goalHitRateIcon)
                            .font(.caption2)
                            .foregroundColor(goalHitRateColor)
                        
                        Text("\(Int(habitGoal.goalHitRate * 100))%")
                            .font(.appCaptionMedium)
                            .foregroundColor(goalHitRateColor)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(goalHitRateColor.opacity(0.1))
                    )
                }
            
                // Progress Bar
                ProgressView(value: habitGoal.goalHitRate, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: goalHitRateColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // Bottom row: Current vs Target comparison
                HStack {
                    // Current Average
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(habitGoal.currentAverage))")
                            .font(.appBodyMedium)
                            .foregroundColor(.text01)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text("Current")
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                    }
                    
                    // Dot separator
                    // Circle()
                    //     .fill(.text06)
                    //     .frame(width: 3, height: 3)
                    //     .frame(width: 16, height: 16)
                    
                    // Target
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(habitGoal.goal.amount))")
                            .font(.appBodyMedium)
                            .foregroundColor(.text03)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text("Target")
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                    }
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.trailing, 16)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.outline3, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var goalHitRateIcon: String {
        if habitGoal.goalHitRate >= 1.0 {
            return "checkmark.circle.fill"
        } else if habitGoal.goalHitRate >= 0.7 {
            return "arrow.up.circle.fill"
        } else if habitGoal.goalHitRate >= 0.4 {
            return "minus.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var goalHitRateColor: Color {
        if habitGoal.goalHitRate >= 1.0 {
            return .success
        } else if habitGoal.goalHitRate >= 0.7 {
            return .warning
        } else if habitGoal.goalHitRate >= 0.4 {
            return .primary
        } else {
            return .error
        }
    }
    
    private var achievementStatus: String {
        if habitGoal.goalHitRate >= 1.0 {
            return "Goal Achieved! 🎉"
        } else if habitGoal.goalHitRate >= 0.7 {
            return "On Track"
        } else if habitGoal.goalHitRate >= 0.4 {
            return "Making Progress"
        } else {
            return "Needs Focus"
        }
    }
    
    private var achievementStatusColor: Color {
        if habitGoal.goalHitRate >= 1.0 {
            return .success
        } else if habitGoal.goalHitRate >= 0.7 {
            return .warning
        } else if habitGoal.goalHitRate >= 0.4 {
            return .primary
        } else {
            return .error
        }
    }
    
    private var achievementMessage: String {
        if habitGoal.goalHitRate >= 1.0 {
            return "You've exceeded your goal!"
        } else if habitGoal.goalHitRate >= 0.7 {
            return "Keep up the great work"
        } else if habitGoal.goalHitRate >= 0.4 {
            return "You're getting there"
        } else {
            return "Try adjusting your approach"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GoalAchievementCard(habitGoal: HabitGoal(
            habit: Habit(
                name: "Morning Run",
                description: "Run for 30 minutes",
                icon: "figure.run",
                color: .blue,
                habitType: .formation,
                schedule: "Daily",
                goal: "5 sessions/week",
                reminder: "8:00 AM",
                startDate: Date()
            ),
            goal: Goal(amount: 5, unit: "sessions/week"),
            currentAverage: 5,
            goalHitRate: 1.0
        ))
        
        GoalAchievementCard(habitGoal: HabitGoal(
            habit: Habit(
                name: "Read 30 min",
                description: "Read a book",
                icon: "book.fill",
                color: .green,
                habitType: .formation,
                schedule: "Daily",
                goal: "7 sessions/week",
                reminder: "9:00 PM",
                startDate: Date()
            ),
            goal: Goal(amount: 7, unit: "sessions/week"),
            currentAverage: 3,
            goalHitRate: 0.43
        ))
    }
    .padding()
    .background(.surface2)
} 