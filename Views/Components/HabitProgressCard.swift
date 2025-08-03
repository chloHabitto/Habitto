import SwiftUI

struct HabitProgressCard: View {
    let habitProgress: HabitProgress
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habitProgress.habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habitProgress.habit)
            
            // VStack with title, description, and progress info
            VStack(spacing: 8) {
                // Top row: Text container and badge
                HStack(alignment: .center, spacing: 12) {
                    // Text container
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habitProgress.habit.name)
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text02)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .background(.red)
//                    .padding(.top, 16)
                    
                    // Status Label - Different for habit breaking
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
//                .background(.red)
                .padding(.bottom, 4)
                
                // Progress Bar
                ProgressView(value: habitProgress.completionPercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // Bottom row: Progress percentage
                HStack {
                    // Progress percentage
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(habitProgress.completionPercentage))%")
                            .font(.appTitleMediumEmphasised)
                            .foregroundColor(.text05)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text(metricLabel)
                            .font(.appBodyExtraSmall)
                            .foregroundColor(.text05)
                    }
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.trailing, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var progressColor: Color {
        switch habitProgress.status {
        case .workingWell:
            return .success
        case .needsAttention:
            return .warning
        case .atRisk:
            return .error
        case .newHabit:
            return .primary
        case .excellentReduction:
            return .success
        case .goodReduction:
            return .success
        case .moderateReduction:
            return .warning
        case .needsMoreReduction:
            return .error
        }
    }
    
    private var metricLabel: String {
        switch habitProgress.habit.habitType {
        case .formation:
            return "completion"
        case .breaking:
            return "reduction"
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
