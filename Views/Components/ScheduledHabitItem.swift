import SwiftUI
import UIKit

struct ScheduledHabitItem: View {
    let habit: Habit
    let selectedDate: Date
    var onRowTap: (() -> Void)? = nil
    var onProgressChange: ((Habit, Date, Int) -> Void)? = nil
    
    @State private var currentProgress: Int = 0
    @State private var dragOffset: CGFloat = 0
    
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
            
            // Goal Progress
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentProgress)/\(habit.goal)")
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
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
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
                }
        )
        .onTapGesture {
            onRowTap?()
        }
        .onAppear {
            currentProgress = habit.getProgress(for: selectedDate)
        }
        .onChange(of: habit.getProgress(for: selectedDate)) { oldProgress, newProgress in
            currentProgress = newProgress
        }
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
