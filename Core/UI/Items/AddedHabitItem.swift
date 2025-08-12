import SwiftUI

struct AddedHabitItem: View {
    let habit: Habit
    let isEditMode: Bool
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onTap: (() -> Void)?
    let onLongPress: (() -> Void)?
    

    
    init(habit: Habit, isEditMode: Bool = false, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, onTap: (() -> Void)? = nil, onLongPress: (() -> Void)? = nil) {
        self.habit = habit
        self.isEditMode = isEditMode
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTap = onTap
        self.onLongPress = onLongPress
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
                    .simultaneousGesture(
                        TapGesture(count: 1)
                            .onEnded {
                                onTap?()
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                print("🔍 AddedHabitItem: Long press gesture triggered for habit: \(habit.name)")
                                onLongPress?()
                            }
                    )
                    
                    // More button or reorder handle based on edit mode
                    ZStack {
                        // More button (always present, but hidden when in edit mode)
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
                                .foregroundColor(.text06)
                                .contentShape(Rectangle())
                        }
                        .frame(width: 40, height: 40)
                        .opacity(isEditMode ? 0 : 1)
                        .allowsHitTesting(!isEditMode)
                        
                        // Reorder handle (only visible in edit mode)
                        if isEditMode {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundColor(.text06)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                                .opacity(1)
                                .allowsHitTesting(true)
                        }
                    }
                    
                }
                
                                        // Bottom row: Goal only
                        HStack(spacing: 4) {
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
                .stroke(.outline3, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
    
    // Helper function to format schedule for display
    private func formatScheduleForDisplay(_ schedule: String) -> String {
        switch schedule {
        case "Everyday":
            return "Daily"
        case "Weekdays":
            return "Weekdays"
        case "Weekends":
            return "Weekends"
        case "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday":
            return "Every \(schedule)"
        case let s where s.contains("times a week"):
            return s // Keep as is for now
        case let s where s.contains("times a month"):
            return s // Keep as is for now
        case let s where s.hasPrefix("Every ") && s.contains("days"):
            return s // Keep as is for now
        default:
            return schedule
        }
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
            },
            onLongPress: {
                print("Long press detected")
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
            },
            onLongPress: {
                print("Long press detected")
            }
        )
    }
    .padding()
    .background(.surface)
} 
