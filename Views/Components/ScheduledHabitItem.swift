import SwiftUI
import UIKit

struct ScheduledHabitItem: View {
    let habit: Habit
    let selectedDate: Date
    var onRowTap: (() -> Void)? = nil
    var onProgressChange: ((Habit, Date, Int) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var currentProgress: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habit)
            
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
            
            // Goal Progress
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentProgress)/\(extractGoalAmount(from: habit.goal))")
                    .font(.appTitleSmallEmphasised)
                    .foregroundColor(.text05)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 80, alignment: .trailing)
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
        .contentShape(Rectangle())
        .offset(x: dragOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    // Only respond to horizontal drags (ignore vertical scrolling)
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    // Only process if it was primarily a horizontal gesture
                    if abs(value.translation.width) > abs(value.translation.height) {
                        let threshold: CGFloat = 50
                        let translationX = value.translation.width
                        
                        if translationX > threshold {
                            // Swipe right - increase progress
                            currentProgress += 1
                            onProgressChange?(habit, selectedDate, currentProgress)
                            
                            // Haptic feedback for increase
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        } else if translationX < -threshold {
                            // Swipe left - decrease progress
                            currentProgress = max(0, currentProgress - 1)
                            onProgressChange?(habit, selectedDate, currentProgress)
                            
                            // Haptic feedback for decrease
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        // Reset drag offset with animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    } else {
                        // Reset drag offset if it was a vertical gesture
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            onRowTap?()
        }
        .onLongPressGesture {
            showingActionSheet = true
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text(habit.name),
                message: Text("Choose an action"),
                buttons: [
                    .default(Text("Edit")) {
                        onEdit?()
                    },
                    .destructive(Text("Delete")) {
                        onDelete?()
                    },
                    .cancel()
                ]
            )
        }
        .onAppear {
            currentProgress = habit.getProgress(for: selectedDate)
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // Only update progress if the date actually changed
            let calendar = Calendar.current
            let oldDay = calendar.startOfDay(for: oldDate)
            let newDay = calendar.startOfDay(for: newDate)
            
            if oldDay != newDay {
                currentProgress = habit.getProgress(for: selectedDate)
            }
        }
    }
    
    // Helper function to extract goal amount without schedule
    private func extractGoalAmount(from goal: String) -> String {
        // Goal format is typically "X unit on frequency" (e.g., "1 time on 1 times a week")
        // We want to extract just "X unit" part
        let components = goal.components(separatedBy: " on ")
        if components.count >= 2 {
            return components[0] // Return "X unit" part
        }
        return goal // Fallback to original goal if format is unexpected
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
                goal: "5 times",
                reminder: "No reminder",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 0
            ),
            selectedDate: Date()
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
            selectedDate: Date()
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
            selectedDate: Date()
        )
    }
    .padding()
    .background(.surface2)
} 
