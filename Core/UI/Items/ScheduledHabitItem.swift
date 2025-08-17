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
    @State private var showingCompletionSheet = false
    
    // Computed property for background color to simplify complex expression
    private var backgroundColor: Color {
        if dragOffset > 30 {
            return Color.green.opacity(0.2)
        } else if dragOffset < -30 {
            return Color.red.opacity(0.2)
        } else {
            return .surface
        }
    }
    
    // Computed property for completion button to simplify complex expression
    private var completionButton: some View {
        Button(action: {
            completeHabit()
        }) {
            Image(systemName: isHabitCompleted() ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isHabitCompleted() ? .pastelBlue500 : .primaryContainerFocus)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habit.color)
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habit)
            
            // VStack with title and progress
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.appTitleMediumEmphasised)
                    .foregroundColor(.text02)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("\(currentProgress)/\(extractGoalAmount(from: habit.goal))")
                    .font(.appBodyExtraSmall)
                    .foregroundColor(.text05)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            
            // Completion Button
            completionButton
                .padding(.trailing, 8)
        }
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.outline3, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .offset(x: dragOffset)
        .overlay(
            // Progress indicator during swipe
            HStack {
                if dragOffset > 30 {
                    Text("+1")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if dragOffset < -30 {
                    Text("-1")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
            }
            .padding(.leading, 16)
            .opacity(abs(dragOffset) > 30 ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)
        )
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    // Only respond to horizontal drags with a clear horizontal preference
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)
                    
                    // Require significantly more horizontal movement than vertical
                    if horizontalDistance > verticalDistance * 1.5 && horizontalDistance > 10 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)
                    
                    // Only process if it was clearly a horizontal gesture
                    if horizontalDistance > verticalDistance * 1.5 && horizontalDistance > 30 {
                        let threshold: CGFloat = 30
                        let translationX = value.translation.width
                        
                        if translationX > threshold {
                            // Swipe right - increase progress by 1
                            let newProgress = currentProgress + 1
                            print("🔄 ScheduledHabitItem: Swipe right detected for \(habit.name), updating progress from \(currentProgress) to \(newProgress)")
                            currentProgress = newProgress
                            
                            // Call the callback to save the progress
                            onProgressChange?(habit, selectedDate, newProgress)
                            
                            // Check if habit is completed and show completion sheet
                            let goalAmount = extractNumericGoalAmount(from: habit.goal)
                            if newProgress >= goalAmount {
                                showingCompletionSheet = true
                            }
                            
                            // Haptic feedback for increase
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        } else if translationX < -threshold {
                            // Swipe left - decrease progress by 1 (minimum 0)
                            let newProgress = max(0, currentProgress - 1)
                            print("🔄 ScheduledHabitItem: Swipe left detected for \(habit.name), updating progress from \(currentProgress) to \(newProgress)")
                            currentProgress = newProgress
                            
                            // Call the callback to save the progress
                            onProgressChange?(habit, selectedDate, newProgress)
                            
                            // Haptic feedback for decrease
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                    
                    // Always reset drag offset
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture {
            // Trigger the row tap callback when the habit item is tapped
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
            // Initialize currentProgress with the actual saved progress from the habit
            let initialProgress = habit.getProgress(for: selectedDate)
            print("🔄 ScheduledHabitItem: onAppear for \(habit.name), initializing progress to \(initialProgress)")
            currentProgress = initialProgress
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // Only update progress if the date actually changed
            let calendar = Calendar.current
            let oldDay = calendar.startOfDay(for: oldDate)
            let newDay = calendar.startOfDay(for: newDate)
            
            if oldDay != newDay {
                let newProgress = habit.getProgress(for: selectedDate)
                currentProgress = newProgress
            }
        }
        .onChange(of: habit.completionHistory) { oldHistory, newHistory in
            // Update local progress when the habit's completion history changes
            let newProgress = habit.getProgress(for: selectedDate)
            print("🔄 ScheduledHabitItem: completionHistory changed for \(habit.name), updating progress from \(currentProgress) to \(newProgress)")
            currentProgress = newProgress
        }
        .onChange(of: habit) { oldHabit, newHabit in
            // Update local progress when the habit object itself changes
            let newProgress = newHabit.getProgress(for: selectedDate)
            print("🔄 ScheduledHabitItem: habit object changed for \(newHabit.name), updating progress from \(currentProgress) to \(newProgress)")
            currentProgress = newProgress
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HabitProgressUpdated"))) { notification in
            // Listen for progress update notifications to ensure UI stays in sync
            if let habitId = notification.userInfo?["habitId"] as? UUID,
               habitId == habit.id,
               let date = notification.userInfo?["date"] as? Date,
               let progress = notification.userInfo?["progress"] as? Int {
                
                // Only update if it's for the same date
                let calendar = Calendar.current
                let notificationDay = calendar.startOfDay(for: date)
                let selectedDay = calendar.startOfDay(for: selectedDate)
                
                if notificationDay == selectedDay {
                    print("🔄 ScheduledHabitItem: Progress update notification received for \(habit.name), updating from \(currentProgress) to \(progress)")
                    currentProgress = progress
                }
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            HabitCompletionBottomSheet(
                isPresented: $showingCompletionSheet,
                habit: habit
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
        }
    }
    
    // Helper function to extract goal amount without schedule
    private func extractGoalAmount(from goal: String) -> String {
        // Goal format is typically "X unit on frequency" (e.g., "1 time on 1 times a week")
        // For legacy habits, it might still be "X unit per frequency"
        // We want to extract just "X unit" part
        
        // Try splitting by " on " first (current format)
        var components = goal.components(separatedBy: " on ")
        if components.count >= 2 {
            return components[0] // Return "X unit" part
        }
        
        // Try splitting by " per " for legacy habits
        components = goal.components(separatedBy: " per ")
        if components.count >= 2 {
            return components[0] // Return "X unit" part
        }
        
        return goal // Fallback to original goal if format is unexpected
    }
    
    // Helper function to extract numeric goal amount for comparison
    private func extractNumericGoalAmount(from goal: String) -> Int {
        let goalString = extractGoalAmount(from: goal)
        
        // Extract the first number from the goal string
        let numbers = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        // Return the first number found, or default to 1 if none found
        return numbers.first ?? 1
    }
    
    // Helper function to check if habit is completed for the selected date
    private func isHabitCompleted() -> Bool {
        let goalAmount = extractNumericGoalAmount(from: habit.goal)
        return currentProgress >= goalAmount
    }
    
    // Helper function to toggle habit completion
    private func completeHabit() {
        let goalAmount = extractNumericGoalAmount(from: habit.goal)
        
        if isHabitCompleted() {
            // If already completed, uncomplete it (set progress to 0)
            let newProgress = 0
            print("🔄 ScheduledHabitItem: Uncompleting habit \(habit.name), updating progress from \(currentProgress) to \(newProgress)")
            currentProgress = newProgress
            
            // Call the callback to save the progress
            onProgressChange?(habit, selectedDate, newProgress)
            
            // Haptic feedback for uncompletion
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            // If not completed, complete it (set progress to goal amount)
            let newProgress = goalAmount
            print("🔄 ScheduledHabitItem: Completing habit \(habit.name), updating progress from \(currentProgress) to \(newProgress)")
            currentProgress = newProgress
            
            // Call the callback to save the progress
            onProgressChange?(habit, selectedDate, newProgress)
            
            // Show completion sheet
            showingCompletionSheet = true
            
            // Haptic feedback for completion
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
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
