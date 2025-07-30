import SwiftUI

struct GoalAchievementCard: View {
    let habitGoal: HabitGoal
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: habitGoal.habit.icon)
                    .font(.title3)
                    .foregroundColor(habitGoal.habit.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(habitGoal.habit.color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habitGoal.habit.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                        .fontWeight(.medium)
                    
                    Text("Goal: \(Int(habitGoal.goal.amount)) \(habitGoal.goal.unit)")
                        .font(.appCaptionMedium)
                        .foregroundColor(.text05)
                }
                
                Spacer()
                
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
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(goalHitRateColor.opacity(0.1))
                )
            }
            
            // Progress Section
            HStack(spacing: 16) {
                // Current Average
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(.appCaptionMedium)
                        .foregroundColor(.text05)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("\(Int(habitGoal.currentAverage))")
                            .font(.appTitleLarge)
                            .foregroundColor(.text01)
                            .fontWeight(.bold)
                        
                        Text(habitGoal.goal.unit)
                            .font(.appCaptionMedium)
                            .foregroundColor(.text05)
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(.outline)
                    .frame(width: 1, height: 40)
                
                // Target
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.appCaptionMedium)
                        .foregroundColor(.text05)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("\(Int(habitGoal.goal.amount))")
                            .font(.appTitleLarge)
                            .foregroundColor(.text03)
                            .fontWeight(.bold)
                        
                        Text(habitGoal.goal.unit)
                            .font(.appCaptionMedium)
                            .foregroundColor(.text05)
                    }
                }
                
                Spacer()
                
                // Achievement Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(achievementStatus)
                        .font(.appCaptionMedium)
                        .foregroundColor(achievementStatusColor)
                        .fontWeight(.medium)
                    
                    Text(achievementMessage)
                        .font(.appCaptionSmall)
                        .foregroundColor(.text05)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            // Progress Bar
            ProgressView(value: habitGoal.goalHitRate, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: goalHitRateColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
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