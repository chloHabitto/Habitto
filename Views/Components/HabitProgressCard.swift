import SwiftUI

struct HabitProgressCard: View {
    let habitProgress: HabitProgress
    
    var body: some View {
        HStack(spacing: 12) {
            // Habit Icon
            Image(systemName: habitProgress.habit.icon)
                .font(.title2)
                .foregroundColor(habitProgress.habit.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(habitProgress.habit.color.opacity(0.1))
                )
            
            // Habit Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(habitProgress.habit.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.text01)
                    
                    Spacer()
                    
                    // Trend Arrow
                    Image(systemName: habitProgress.trend.icon)
                        .font(.caption)
                        .foregroundColor(habitProgress.trend.color)
                }
                
                // Progress Bar
                ProgressView(value: habitProgress.completionPercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text("\(Int(habitProgress.completionPercentage))%")
                        .font(.appCaptionMedium)
                        .foregroundColor(.text03)
                    
                    Spacer()
                    
                    // Status Label
                    HStack(spacing: 4) {
                        Image(systemName: habitProgress.status.icon)
                            .font(.caption2)
                            .foregroundColor(habitProgress.status.color)
                        
                        Text(habitProgress.status.label)
                            .font(.appCaptionMedium)
                            .foregroundColor(habitProgress.status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(habitProgress.status.color.opacity(0.1))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var progressColor: Color {
        switch habitProgress.status {
        case .workingWell:
            return .success
        case .needsAttention:
            return .warning
        case .atRisk:
            return .error
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HabitProgressCard(habitProgress: HabitProgress(
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
            period: .week,
            completionPercentage: 90,
            trend: .improving
        ))
        
        HabitProgressCard(habitProgress: HabitProgress(
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
            period: .week,
            completionPercentage: 42,
            trend: .declining
        ))
    }
    .padding()
    .background(.surface2)
} 