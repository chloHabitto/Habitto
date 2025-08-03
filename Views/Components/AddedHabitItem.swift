import SwiftUI

struct AddedHabitItem: View {
    let habit: Habit
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onTap: (() -> Void)?
    
    init(habit: Habit, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onTap: (() -> Void)? = nil) {
        self.habit = habit
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habit)
            
            // VStack with title, description, and bottom row
            VStack(spacing: 8) {
                // Top row: Text container and more button
                HStack(spacing: 4) {
                    // Text container - tappable area
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
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap?()
                    }
                    
                    // More button with menu - separate from tap gesture
                    Menu {
                        Button(action: {
                            onEdit?()
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            onDelete?()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image("Icon-more_vert")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primaryDim)
                            .contentShape(Rectangle())
                    }
                    .frame(width: 40, height: 40)
                }
                
                                        // Bottom row: Schedule and goal
                        HStack(spacing: 4) {
                            // Schedule
                            HStack(spacing: 4) {
                                Image("Icon-calendarMarked-filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.text05)
                                
                                Text(habit.schedule)
                                    .font(.appBodyExtraSmall)
                                    .foregroundColor(.text05)
                            }
                            
                            // Dot separator
                            Circle()
                                .fill(.text06)
                                .frame(width: 3, height: 3)
                                .frame(width: 16, height: 16)
                            
                            // Goal
                            HStack(spacing: 4) {
                                Image("Icon-flag-filled")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.text05)
                                
                                Text(habit.goal)
                                    .font(.appBodyExtraSmall)
                                    .foregroundColor(.text05)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
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
        AddedHabitItem(
            habit: Habit(
                name: "Morning Exercise",
                description: "Start the day with a quick workout",
                icon: "🏃‍♂️",
                color: .blue,
                habitType: .formation,
                schedule: "Daily",
                goal: "30 minutes",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            ),
            onEdit: {
                print("Edit tapped")
            },
            onDelete: {
                print("Delete tapped")
            }
        )
        
        AddedHabitItem(
            habit: Habit(
                name: "Read Books",
                description: "Read at least one chapter every day",
                icon: "📚",
                color: .green,
                habitType: .formation,
                schedule: "Weekdays",
                goal: "1 chapter",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            ),
            onEdit: {
                print("Edit tapped")
            },
            onDelete: {
                print("Delete tapped")
            }
        )
    }
    .padding()
    .background(.surface)
} 
