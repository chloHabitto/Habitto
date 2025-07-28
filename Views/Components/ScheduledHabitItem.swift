import SwiftUI

struct ScheduledHabitItem: View {
    let habit: Habit
    @Binding var isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.surfaceContainer)
                    .frame(width: 30, height: 30)
                
                if habit.icon.hasPrefix("Icon-") {
                    // Asset icon
                    Image(habit.icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(habit.color)
                } else if habit.icon == "None" {
                    // No icon selected - show colored rounded rectangle
                    RoundedRectangle(cornerRadius: 4)
                        .fill(habit.color)
                        .frame(width: 14, height: 14)
                } else {
                    // Emoji or system icon
                    Text(habit.icon)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            
            // VStack with title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text02)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(habit.description.isEmpty ? "No description" : habit.description)
                    .font(.appBodyExtraSmall)
                    .foregroundColor(.text05)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            
            // CheckBox
            Button(action: {
                isCompleted.toggle()
            }) {
                Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primaryDim)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.leading, 16)
            .padding(.trailing, 8)
        }
        .padding(.trailing, 4)
        .background(.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.outline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 16) {
        ScheduledHabitItem(
            habit: Habit(
                name: "Morning Exercise",
                description: "30 minutes of cardio",
                icon: "🏃‍♂️",
                color: .green,
                habitType: .formation,
                schedule: "Everyday",
                goal: "30 minutes",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            ),
            isCompleted: .constant(false)
        )
        
        ScheduledHabitItem(
            habit: Habit(
                name: "Read Books",
                description: "Read 20 pages daily",
                icon: "📚",
                color: .blue,
                habitType: .formation,
                schedule: "Everyday",
                goal: "20 pages",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: true,
                streak: 5
            ),
            isCompleted: .constant(true)
        )
        
        ScheduledHabitItem(
            habit: Habit(
                name: "Drink Water",
                description: "8 glasses of water per day",
                icon: "💧",
                color: .orange,
                habitType: .formation,
                schedule: "Everyday",
                goal: "8 glasses",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            ),
            isCompleted: .constant(false)
        )
    }
    .padding()
    .background(.surface2)
} 
