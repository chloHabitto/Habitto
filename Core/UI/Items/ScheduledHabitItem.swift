import SwiftUI
import UIKit

struct ScheduledHabitItem: View {
    let habit: Habit
    let selectedDate: Date
    var onRowTap: (() -> Void)? = nil
    var onProgressChange: ((Habit, Date, Int) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onCompletionDismiss: (() -> Void)? = nil
    
    @State private var currentProgress: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showingActionSheet = false
    @State private var showingCompletionSheet = false
    @State private var isCompletingHabit = false
    @State private var isCompletingAnimation = false
    @State private var hasDragged = false
    @State private var isProcessingCompletion = false
    @State private var isUpdatingProgress = false // ✅ FIX: Prevent concurrent progress updates
    @State private var lastInteractionTime: Date = Date.distantPast // ✅ FIX: Debounce rapid interactions
    
    
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
    
    // Computed property for progress percentage (allows over-completion display)
    private var progressPercentage: Double {
        let goalAmount = extractNumericGoalAmount(from: habit.goal)
        guard goalAmount > 0 else { return 0.0 }
        // Use local currentProgress for immediate UI feedback
        let percentage = Double(currentProgress) / Double(goalAmount)
        // Allow over-completion display (e.g., 150% for 3/2 progress)
        return percentage
    }
    
    // Computed property to check if it's a vacation day and vacation is currently active
    private var isVacationDay: Bool {
        VacationManager.shared.isActive && VacationManager.shared.isVacationDay(selectedDate)
    }
    
    // Computed property for completion button using animated checkbox
    private var completionButton: some View {
        
        return AnimatedCheckbox(
            isChecked: isHabitCompleted(),
            accentColor: isVacationDay ? .grey400 : habit.color,
            isAnimating: isCompletingAnimation,
            action: {
                if !isVacationDay {
                    completeHabit()
                }
            }
        )
        .disabled(isVacationDay)
        .opacity(isVacationDay ? 0.6 : 1.0)
    }
    
    // Computed property to check if habit has reminders
    private var hasReminders: Bool {
        return !habit.reminders.isEmpty
    }
    
    // Computed property to check if all reminders for today are completed
    private var areRemindersCompleted: Bool {
        guard hasReminders else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)
        let now = Date()
        
        // Check if all reminders for today have passed
        return habit.reminders.allSatisfy { reminder in
            let reminderTime = calendar.dateComponents([.hour, .minute], from: reminder.time)
            let todayWithReminderTime = calendar.date(bySettingHour: reminderTime.hour ?? 0, 
                                                    minute: reminderTime.minute ?? 0, 
                                                    second: 0, 
                                                    of: today) ?? today
            
            return now > todayWithReminderTime
        }
    }
    
    // Computed property for reminder icon
    private var reminderIcon: some View {
        Group {
            if hasReminders {
                Image(areRemindersCompleted ? "Icon-Bell_Filled" : "Icon-BellOn_Filled")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                    .foregroundColor(.yellow100)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // ColorMark
            Rectangle()
                .fill(habit.color.opacity(0.7))
                .frame(width: 8)
                .frame(maxHeight: .infinity)
            
            // SelectedIcon
            HabitIconView(habit: habit)
            
            // VStack with title, progress text, and progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.appTitleMediumEmphasised)
                        .foregroundColor(.text02)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    reminderIcon
                }
                
                Text("\(habit.getProgress(for: selectedDate))/\(extractGoalAmount(from: habit.goal))")
                    .font(.appBodySmall)
                    .foregroundColor(.text05)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.outline3.opacity(0.3))
                            .frame(height: 6)
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(habit.color.opacity(isCompletingAnimation ? 1.0 : 0.7))
                            .frame(
                                width: min(geometry.size.width * progressPercentage, geometry.size.width),
                                height: isCompletingAnimation ? 8 : 6
                            )
                            .opacity(isVacationDay ? 0.6 : 1.0)
                            .scaleEffect(isCompletingAnimation ? 1.05 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1), value: isCompletingAnimation)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80) // Fixed height for consistency
            
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
            RoundedRectangle(cornerRadius: 20)
                .stroke(.outline3, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    print("🔄 Drag onChanged: translation=\(value.translation), velocity=\(value.velocity)")
                    dragOffset = value.translation.width
                    hasDragged = true
                }
                .onEnded { value in
                    print("🔄 Drag onEnded: translation=\(value.translation), velocity=\(value.velocity)")
                    let translationX = value.translation.width
                    let velocityX = value.velocity.width
                    
                    print("🔄 TranslationX: \(translationX), VelocityX: \(velocityX)")
                    
                    // More responsive threshold-based detection with velocity fallback
                    let threshold: CGFloat = 5
                    let velocityThreshold: CGFloat = 100
                    
                    // Check both translation and velocity for more reliable detection
                    let isRightSwipe = translationX > threshold || (translationX > 0 && velocityX > velocityThreshold)
                    let isLeftSwipe = translationX < -threshold || (translationX < 0 && velocityX < -velocityThreshold)
                    
                    if isRightSwipe {
                        // ✅ FIX: Debounce rapid interactions
                        let now = Date()
                        let timeSinceLastInteraction = now.timeIntervalSince(lastInteractionTime)
                        guard timeSinceLastInteraction > 0.2 else {
                            print("🎯 COMPLETION_FLOW: Interaction too rapid, debouncing (timeSinceLast: \(timeSinceLastInteraction))")
                            return
                        }
                        lastInteractionTime = now
                        
                        // ✅ FIX: Prevent concurrent progress updates
                        guard !isUpdatingProgress else {
                            print("🎯 COMPLETION_FLOW: Progress update already in progress, skipping swipe")
                            return
                        }
                        
                        isUpdatingProgress = true
                        
                        // Swipe right - increase progress by 1, clamped to goal
                        let goalAmount = extractNumericGoalAmount(from: habit.goal)
                        let newProgress = min(currentProgress + 1, goalAmount)
                        let _ = "debug_user_id" // TODO: Get actual user ID hash
                        
                        print("🎯 COMPLETION_FLOW: Swipe right - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), source=swipe, oldCount=\(currentProgress), newCount=\(newProgress), goal=\(goalAmount), reachedGoal=\(newProgress >= goalAmount)")
                        
                        // Update UI immediately
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentProgress = newProgress
                        }
                        
                        // Save progress data
                        print("🎯 COMPLETION_FLOW: Saving progress data: \(newProgress)")
                        onProgressChange?(habit, selectedDate, newProgress)
                        
                        // Reset update flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isUpdatingProgress = false
                        }
                        
                        // Check if habit is completed and show completion sheet
                        if newProgress >= goalAmount {
                            // ✅ FIX: Use CompletionStateManager to prevent race conditions
                            let completionManager = CompletionStateManager.shared
                            guard !completionManager.isShowingCompletionSheet(for: habit.id) else {
                                print("🎯 COMPLETION_FLOW: Completion sheet already showing for \(habit.name), skipping")
                                return
                            }
                            
                            completionManager.startCompletionFlow(for: habit.id)
                            isCompletingHabit = true
                            isProcessingCompletion = true
                            
                            // Fun completion animation for swipe
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.1)) {
                                isCompletingAnimation = true
                            }
                            
                            // Reset animation after completion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    self.isCompletingAnimation = false
                                }
                            }
                            
                            // Show completion sheet immediately
                            print("🎯 COMPLETION_FLOW: Showing completion sheet immediately")
                            showingCompletionSheet = true
                        }
                        
                        // Haptic feedback for increase
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // UI should update automatically due to @State currentProgress
                    } else if isLeftSwipe {
                        // ✅ FIX: Debounce rapid interactions
                        let now = Date()
                        let timeSinceLastInteraction = now.timeIntervalSince(lastInteractionTime)
                        guard timeSinceLastInteraction > 0.2 else {
                            print("🎯 COMPLETION_FLOW: Interaction too rapid, debouncing (timeSinceLast: \(timeSinceLastInteraction))")
                            return
                        }
                        lastInteractionTime = now
                        
                        // ✅ FIX: Prevent concurrent progress updates
                        guard !isUpdatingProgress else {
                            print("🎯 COMPLETION_FLOW: Progress update already in progress, skipping swipe")
                            return
                        }
                        
                        isUpdatingProgress = true
                        
                        // Swipe left - decrease progress by 1 (minimum 0)
                        let newProgress = max(0, currentProgress - 1)
                        let _ = "debug_user_id" // TODO: Get actual user ID hash
                        
                        print("🎯 COMPLETION_FLOW: Swipe left - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), source=swipe, oldCount=\(currentProgress), newCount=\(newProgress), goal=\(extractNumericGoalAmount(from: habit.goal)), reachedGoal=false")
                        
                        // Update UI immediately
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentProgress = newProgress
                        }
                        
                        // Call the callback to save the progress
                        print("🎯 COMPLETION_FLOW: Saving progress data: \(newProgress)")
                        onProgressChange?(habit, selectedDate, newProgress)
                        
                        // Reset update flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isUpdatingProgress = false
                        }
                        
                        // Haptic feedback for decrease
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        // UI should update automatically due to @State currentProgress
                    } else {
                        print("🔄 Swipe not strong enough: translationX=\(translationX)")
                    }
                    
                    // Always reset drag offset and hasDragged flag
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                    hasDragged = false
                }
        )
        .onTapGesture {
            // Only trigger tap if no drag has occurred and not processing completion
            if !hasDragged && !isProcessingCompletion {
                print("🎯 ScheduledHabitItem: Row tapped for \(habit.name)")
                onRowTap?()
            } else {
                print("🎯 ScheduledHabitItem: Tap ignored due to drag gesture or completion processing")
            }
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
            print("🔄 ScheduledHabitItem: onProgressChange callback is \(onProgressChange != nil ? "available" : "nil")")
            withAnimation(.easeInOut(duration: 0.2)) {
                currentProgress = initialProgress
            }
            
            // Force a small delay to ensure everything is properly initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let updatedProgress = habit.getProgress(for: selectedDate)
                if updatedProgress != currentProgress {
                    print("🔄 ScheduledHabitItem: Progress updated after delay from \(currentProgress) to \(updatedProgress)")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentProgress = updatedProgress
                    }
                }
            }
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // Only update progress if the date actually changed
            let calendar = Calendar.current
            let oldDay = calendar.startOfDay(for: oldDate)
            let newDay = calendar.startOfDay(for: newDate)
            
            if oldDay != newDay {
                let newProgress = habit.getProgress(for: selectedDate)
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentProgress = newProgress
                }
            }
        }
        .onChange(of: habit.completionHistory) { oldHistory, newHistory in
            let newProgress = habit.getProgress(for: selectedDate)
            print("🎯 ScheduledHabitItem: completionHistory changed for \(habit.name), updating currentProgress from \(currentProgress) to \(newProgress)")
            withAnimation(.easeInOut(duration: 0.2)) {
                currentProgress = newProgress
            }
        }
        .onChange(of: habit) { oldHabit, newHabit in
            // Sync currentProgress when the habit object itself changes
            let newProgress = newHabit.getProgress(for: selectedDate)
            if newProgress != currentProgress {
                print("🎯 ScheduledHabitItem: habit object changed for \(newHabit.name), syncing currentProgress from \(currentProgress) to \(newProgress)")
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentProgress = newProgress
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .habitProgressUpdated)) { notification in
            // Listen for habit progress updates from the repository
            if let updatedHabitId = notification.userInfo?["habitId"] as? UUID,
               updatedHabitId == habit.id {
                let newProgress = habit.getProgress(for: selectedDate)
                print("🎯 ScheduledHabitItem: Received progress update for \(habit.name), syncing currentProgress from \(currentProgress) to \(newProgress)")
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentProgress = newProgress
                }
            }
        }
            .sheet(isPresented: $showingCompletionSheet) {
                HabitCompletionBottomSheet(
                    isPresented: $showingCompletionSheet,
                    habit: habit,
                onDismiss: {
                    let _ = "debug_user_id" // TODO: Get actual user ID hash
                    print("🎯 COMPLETION_FLOW: Sheet dismissed - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), sheetAction=close, reorderTriggered=true")
                    
                    // ✅ FIX: End completion flow in CompletionStateManager
                    let completionManager = CompletionStateManager.shared
                    completionManager.endCompletionFlow(for: habit.id)
                    
                    // Reset flags immediately
                    isCompletingHabit = false
                    isProcessingCompletion = false
                    
                    // Data is already saved when completion happened, no need to save again
                    print("🎯 COMPLETION_FLOW: Data already saved on completion, triggering reorder")
                    
                    // Call the original completion dismiss handler
                    onCompletionDismiss?()
                }
                )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
            .onDisappear {
                print("🎯 ScheduledHabitItem: Sheet disappeared for habit: \(habit.name)")
            }
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
        // Use local currentProgress for immediate UI feedback
        let goalAmount = extractNumericGoalAmount(from: habit.goal)
        return currentProgress >= goalAmount
    }
    
    // Helper function to toggle habit completion
    private func completeHabit() {
        let isCompleted = isHabitCompleted()
        let goalAmount = extractNumericGoalAmount(from: habit.goal)
        let _ = "debug_user_id" // TODO: Get actual user ID hash
        
        print("🎯 COMPLETION_FLOW: Circle tap - habitId=\(habit.id), dateKey=\(Habit.dateKey(for: selectedDate)), source=circle, oldCount=\(currentProgress), goal=\(goalAmount), reachedGoal=\(!isCompleted)")
        
        if isCompleted {
            // If already completed, uncomplete it (set progress to 0)
            print("🎯 COMPLETION_FLOW: Uncompleting habit \(habit.name)")
            
            // Update local state immediately for instant UI feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                currentProgress = 0
            }
            
            // Then save to data model
            onProgressChange?(habit, selectedDate, 0)
            
            // Haptic feedback for uncompletion
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            } else {
                // If not completed, complete it immediately
                print("🎯 COMPLETION_FLOW: Completing habit \(habit.name) - setting progress to goal")
                
                // ✅ FIX: Use CompletionStateManager to prevent race conditions
                let completionManager = CompletionStateManager.shared
                guard !completionManager.isShowingCompletionSheet(for: habit.id) else {
                    print("🎯 COMPLETION_FLOW: Completion sheet already showing for \(habit.name), skipping")
                    return
                }
                
                completionManager.startCompletionFlow(for: habit.id)
                isCompletingHabit = true
                isProcessingCompletion = true
                
                // Update local state immediately for instant UI feedback
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentProgress = goalAmount
                }
                
                // Save completion data immediately
                print("🎯 COMPLETION_FLOW: Saving completion data immediately: \(goalAmount)")
                onProgressChange?(habit, selectedDate, goalAmount)
                
                // Haptic feedback for completion
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Show completion sheet immediately (no delay)
                print("🎯 COMPLETION_FLOW: Showing completion sheet immediately")
                showingCompletionSheet = true
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
                endDate: nil
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
                endDate: nil
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
                endDate: nil
            ),
            selectedDate: Date()
        )
    }
    .padding()
    .background(.surface2)
} 
