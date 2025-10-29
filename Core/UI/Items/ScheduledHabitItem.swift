import SwiftUI
import UIKit

struct ScheduledHabitItem: View {
  // MARK: Internal

  let habit: Habit
  let selectedDate: Date
  var onRowTap: (() -> Void)?
  var onProgressChange: ((Habit, Date, Int) -> Void)?
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?
  var onCompletionDismiss: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      // ColorMark
      Rectangle()
        .fill(habit.color.color.opacity(0.7))
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

        Text(progressDisplayText)
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
              .fill(habit.color.color.opacity(isCompletingAnimation ? 1.0 : 0.7))
              .frame(
                width: min(geometry.size.width * progressPercentage, geometry.size.width),
                height: isCompletingAnimation ? 8 : 6)
              .opacity(isVacationDay ? 0.6 : 1.0)
              .scaleEffect(isCompletingAnimation ? 1.05 : 1.0)
              .animation(
                .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1),
                value: isCompletingAnimation)
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
        .fill(backgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(.outline3, lineWidth: 2))
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
      .animation(.easeInOut(duration: 0.2), value: dragOffset))
    .onTapGesture {
      onRowTap?()
    }
    .gesture(
      DragGesture(minimumDistance: 20, coordinateSpace: .local)
        .onChanged { value in
          withAnimation(.interactiveSpring()) {
            dragOffset = value.translation.width
          }
          if abs(value.translation.width) > 10 {
            hasDragged = true
          }
        }
        .onEnded { value in
          let translationX = value.translation.width
          let velocityX = value.velocity.width

          // Swipe thresholds
          let threshold: CGFloat = 50
          let velocityThreshold: CGFloat = 200

          let isRightSwipe = (translationX > threshold && velocityX > 0) || velocityX >
            velocityThreshold
          let isLeftSwipe = (translationX < -threshold && velocityX < 0) || velocityX <
            -velocityThreshold

          // Reset drag state
          withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = 0
            hasDragged = false
          }

          if isRightSwipe {
            handleRightSwipe()
          } else if isLeftSwipe {
            handleLeftSwipe()
          }
        })
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
        ])
    }
    .onAppear {
      // Initialize currentProgress with the actual saved progress from the habit
      let initialProgress = habit.getProgress(for: selectedDate)
      withAnimation(.easeInOut(duration: 0.2)) {
        currentProgress = initialProgress
      }

      // Force a small delay to ensure everything is properly initialized
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let updatedProgress = habit.getProgress(for: selectedDate)
        if updatedProgress != currentProgress {
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
    .onChange(of: habit.completionHistory) { _, _ in
      // Don't override local updates that are in progress
      guard !isLocalUpdateInProgress else { return }

      // ✅ FIX: If user just made a change, wait longer before accepting external updates
      if let lastUpdate = lastUserUpdateTimestamp,
         Date().timeIntervalSince(lastUpdate) < 1.0 {
        print("🔍 RACE FIX: Ignoring completionHistory update within 1s of user action")
        return
      }

      let newProgress = habit.getProgress(for: selectedDate)
      withAnimation(.easeInOut(duration: 0.2)) {
        currentProgress = newProgress
      }
    }
    .onChange(of: habit) { _, newHabit in
      // Don't override local updates that are in progress
      guard !isLocalUpdateInProgress else { return }

      // ✅ FIX: If user just made a change, wait longer before accepting external updates
      if let lastUpdate = lastUserUpdateTimestamp,
         Date().timeIntervalSince(lastUpdate) < 1.0 {
        print("🔍 RACE FIX: Ignoring habit update within 1s of user action")
        return
      }

      // Sync currentProgress when the habit object itself changes
      let newProgress = newHabit.getProgress(for: selectedDate)
      if newProgress != currentProgress {
        withAnimation(.easeInOut(duration: 0.2)) {
          currentProgress = newProgress
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .habitProgressUpdated)) { notification in
      // Don't override local updates that are in progress
      guard !isLocalUpdateInProgress else { return }

      // ✅ FIX: If user just made a change, wait longer before accepting external updates
      if let lastUpdate = lastUserUpdateTimestamp,
         Date().timeIntervalSince(lastUpdate) < 1.0 {
        print("🔍 RACE FIX: Ignoring habitProgressUpdated notification within 1s of user action")
        return
      }

      // Listen for habit progress updates from the repository
      if let updatedHabitId = notification.userInfo?["habitId"] as? UUID,
         updatedHabitId == habit.id
      {
        let newProgress = habit.getProgress(for: selectedDate)
        withAnimation(.easeInOut(duration: 0.2)) {
          currentProgress = newProgress
        }
      }
    }
    .sheet(isPresented: $showingCompletionSheet) {
      HabitCompletionBottomSheet(
        isPresented: $showingCompletionSheet,
        habit: habit,
        completionDate: selectedDate,
        onDismiss: {
          // End completion flow in CompletionStateManager
          let completionManager = CompletionStateManager.shared
          completionManager.endCompletionFlow(for: habit.id)

          // Reset flags immediately
          isCompletingHabit = false
          isProcessingCompletion = false

          // Data is already saved when completion happened, no need to save again

          // Call the original completion dismiss handler
          onCompletionDismiss?()
        })
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(40)
        .onDisappear { }
    }
  }

  // MARK: Private

  @State private var currentProgress = 0
  @State private var dragOffset: CGFloat = 0
  @State private var showingActionSheet = false
  @State private var showingCompletionSheet = false
  @State private var isCompletingHabit = false
  @State private var isCompletingAnimation = false
  @State private var hasDragged = false
  @State private var isProcessingCompletion = false
  @State private var isUpdatingProgress = false // ✅ FIX: Prevent concurrent progress updates
  @State private var lastInteractionTime = Date.distantPast // ✅ FIX: Debounce rapid interactions
  @State private var isLocalUpdateInProgress =
    false // ✅ FIX: Prevent onChange listeners from overriding local updates
  @State private var lastUserUpdateTimestamp: Date? = nil // ✅ FIX: Track when user last made a change

  /// Computed property for background color to simplify complex expression
  private var backgroundColor: Color {
    if dragOffset > 30 {
      Color.green.opacity(0.2)
    } else if dragOffset < -30 {
      Color.red.opacity(0.2)
    } else {
      .surface
    }
  }

  /// Computed property for progress percentage (allows over-completion display)
  private var progressPercentage: Double {
    let goalAmount = extractNumericGoalAmount(from: habit.goal)
    guard goalAmount > 0 else { return 0.0 }
    // Use local currentProgress for immediate UI feedback
    let percentage = Double(currentProgress) / Double(goalAmount)
    // Allow over-completion display (e.g., 150% for 3/2 progress)
    return percentage
  }

  /// Computed property for progress display text
  /// ✅ UNIVERSAL RULE: Both types display progress/goal (NOT progress/baseline!)
  private var progressDisplayText: String {
    // ✅ BOTH habit types show: currentProgress / goalAmount
    // For Breaking habits: "0/10" where 10 comes from "Goal: 10 times/everyday"
    // baseline and current fields are DISPLAY-ONLY (for statistics, not progress)
    return "\(currentProgress)/\(extractGoalAmount(from: habit.goal))"
  }

  /// Computed property to check if it's a vacation day and vacation is currently active
  private var isVacationDay: Bool {
    VacationManager.shared.isActive && VacationManager.shared.isVacationDay(selectedDate)
  }

  /// Computed property to check if habit has reminders
  private var hasReminders: Bool {
    !habit.reminders.isEmpty
  }

  /// Computed property to check if all reminders for today are completed
  private var areRemindersCompleted: Bool {
    guard hasReminders else { return false }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: selectedDate)
    let now = Date()

    // Check if all reminders for today have passed
    return habit.reminders.allSatisfy { reminder in
      let reminderTime = calendar.dateComponents([.hour, .minute], from: reminder.time)
      let todayWithReminderTime = calendar.date(
        bySettingHour: reminderTime.hour ?? 0,
        minute: reminderTime.minute ?? 0,
        second: 0,
        of: today) ?? today

      return now > todayWithReminderTime
    }
  }

  /// Computed property for completion button using animated checkbox
  private var completionButton: some View {
    AnimatedCheckbox(
      isChecked: isHabitCompleted(),
      accentColor: isVacationDay ? .grey400 : habit.color.color,
      isAnimating: isCompletingAnimation,
      action: {
        if !isVacationDay {
          toggleHabitCompletion()
        }
      })
      .disabled(isVacationDay)
      .opacity(isVacationDay ? 0.6 : 1.0)
  }

  /// Computed property for reminder icon
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

  /// Helper function to extract goal amount without schedule
  private func extractGoalAmount(from goal: String) -> String {
    // Goal format is typically "X unit on frequency" (e.g., "1 time on Monday, Tuesday")
    // For legacy habits, it might still be "X unit per frequency"
    // For frequency-based habits, it's "X unit frequency" (e.g., "1 time once a week", "1 time 3 days a week")
    // We want to extract just "X unit" part

    // Try splitting by " on " first (current format for day-based schedules)
    var components = goal.components(separatedBy: " on ")
    if components.count >= 2 {
      return components[0] // Return "X unit" part
    }

    // Try splitting by " per " for legacy habits
    components = goal.components(separatedBy: " per ")
    if components.count >= 2 {
      return components[0] // Return "X unit" part
    }

    // Handle frequency-based schedules using regex to match patterns like:
    // "once a week", "twice a week", "3 days a week", "5 times per week", etc.
    let regexPatterns = [
      #"\s+(once|twice)\s+a\s+(week|month)"#,  // "once a week", "twice a month"
      #"\s+\d+\s+days?\s+a\s+(week|month)"#,   // "3 days a week", "1 day a month"
      #"\s+\d+\s+times?\s+(per|a)\s+week"#,    // "3 times per week", "2 times a week"
      #"\s+(everyday|weekdays|weekends)"#,      // "everyday", "weekdays", "weekends"
    ]
    
    for pattern in regexPatterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
         let match = regex.firstMatch(in: goal, options: [], range: NSRange(location: 0, length: goal.count))
      {
        // Extract the part before the frequency pattern
        let beforeFrequency = (goal as NSString).substring(to: match.range.location)
        return beforeFrequency.trimmingCharacters(in: .whitespaces)
      }
    }

    return goal // Fallback to original goal if format is unexpected
  }

  /// Helper function to extract numeric goal amount for comparison
  /// ✅ UNIVERSAL RULE: Both Formation and Breaking habits parse the "goal" field
  /// baseline, current, target, actualUsage are DISPLAY-ONLY fields
  private func extractNumericGoalAmount(from goal: String) -> Int {
    let goalString = extractGoalAmount(from: goal)

    // Extract the first number from the goal string
    let numbers = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
      .compactMap { Int($0) }

    // ✅ BOTH habit types use the same logic - parse the "goal" field
    // For Breaking habits: "Goal: 10 times/everyday" → 10 (NOT baseline/current!)
    // Return the first number found, or default to 1 if none found
    return numbers.first ?? 1
  }

  /// Helper function to check if habit is completed for the selected date
  private func isHabitCompleted() -> Bool {
    // Use local currentProgress for immediate UI feedback
    let goalAmount = extractNumericGoalAmount(from: habit.goal)
    return currentProgress >= goalAmount
  }

  /// Helper function for circle button - INSTANT TOGGLE complete/uncomplete
  /// ✅ Circle button = Quick action: "Mark done" or "Undo completion"
  /// Design: Instant jump to goal (complete) or reset to 0 (uncomplete)
  /// Note: Swipe gestures (+1/-1) are still available for gradual progress tracking
  private func completeHabit() {
    let goalAmount = extractNumericGoalAmount(from: habit.goal)
    
    print("🔘 CIRCLE_BUTTON: Current=\(currentProgress), Goal=\(goalAmount)")
    
    // Determine new progress: instant toggle
    let newProgress: Int
    let isCompleting: Bool
    
    if currentProgress < goalAmount {
      // ✅ INSTANT COMPLETE: Jump to goal
      newProgress = goalAmount
      isCompleting = true
      print("🔘 CIRCLE_BUTTON: Instant complete - jumping from \(currentProgress) to \(goalAmount)")
    } else {
      // ✅ INSTANT UNCOMPLETE: Reset to 0
      newProgress = 0
      isCompleting = false
      print("🔘 CIRCLE_BUTTON: Instant uncomplete - resetting from \(currentProgress) to 0")
    }
    
    // Prevent onChange listeners from overriding this update
    isLocalUpdateInProgress = true
    
    // Update local state immediately for instant UI feedback
    withAnimation(.easeInOut(duration: 0.2)) {
      currentProgress = newProgress
    }
    
    // Save to repository
    onProgressChange?(habit, selectedDate, newProgress)
    
    // Record timestamp of this user action
    lastUserUpdateTimestamp = Date()
    
    // Release lock after persistence
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isLocalUpdateInProgress = false
    }
    
    // Show difficulty sheet when completing (not when uncompleting)
    if isCompleting {
      let completionManager = CompletionStateManager.shared
      guard !completionManager.isShowingCompletionSheet(for: habit.id) else {
        return
      }
      
      completionManager.startCompletionFlow(for: habit.id)
      isCompletingHabit = true
      isProcessingCompletion = true
      showingCompletionSheet = true
      
      print("🎉 CIRCLE_BUTTON: Goal reached for \(habit.name) (\(newProgress)/\(goalAmount))")
    }
    
    // Haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: isCompleting ? .medium : .light)
    impactFeedback.impactOccurred()
  }

  // MARK: - Completion Handlers

  private func toggleHabitCompletion() {
    if isHabitCompleted() {
      // Currently completed, so uncomplete it
      uncompleteHabit()
    } else {
      // Currently not completed, so complete it
      completeHabit()
    }
  }

  private func uncompleteHabit() {
    // Set progress to 0 (uncompleted)
    let newProgress = 0

    // Prevent onChange listeners from overriding this update
    isLocalUpdateInProgress = true

    // Update UI immediately
    withAnimation(.easeInOut(duration: 0.2)) {
      currentProgress = newProgress
    }

    // Save progress data
    if let progressCallback = onProgressChange {
      progressCallback(habit, selectedDate, newProgress)
    }

    // Record timestamp of this user action
    lastUserUpdateTimestamp = Date()

    // ✅ FIX: Clear CompletionStateManager when uncompleting to allow re-completion
    let completionManager = CompletionStateManager.shared
    completionManager.endCompletionFlow(for: habit.id)
    
    // Reset completion flags
    isCompletingHabit = false
    isProcessingCompletion = false

    // ✅ FIX: Increase delay from 0.1s to 0.5s to ensure persistence completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isLocalUpdateInProgress = false
    }

    // Haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    impactFeedback.impactOccurred()
  }

  // MARK: - Swipe Handlers

  private func handleRightSwipe() {
    // Debounce rapid interactions
    let now = Date()
    let timeSinceLastInteraction = now.timeIntervalSince(lastInteractionTime)
    guard timeSinceLastInteraction > 0.05 else {
      return
    }
    lastInteractionTime = now

    // Prevent concurrent progress updates
    guard !isUpdatingProgress else {
      return
    }

    isUpdatingProgress = true
    isLocalUpdateInProgress = true

    // Swipe right - always increase progress by 1 (no clamping)
    let newProgress = currentProgress + 1

    // Update UI immediately
    withAnimation(.easeInOut(duration: 0.2)) {
      currentProgress = newProgress
    }

    // Save progress data
    if let progressCallback = onProgressChange {
      progressCallback(habit, selectedDate, newProgress)
    }

    // Record timestamp of this user action
    lastUserUpdateTimestamp = Date()

    // ✅ FIX: Increase delay from 0.1s to 0.5s to ensure persistence completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isUpdatingProgress = false
      isLocalUpdateInProgress = false
    }

    // Check if habit is completed and show completion sheet
    let goalAmount = extractNumericGoalAmount(from: habit.goal)
    if newProgress >= goalAmount {
      showCompletionSheet()
    }

    // Haptic feedback for increase
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
  }

  private func handleLeftSwipe() {
    // Debounce rapid interactions
    let now = Date()
    let timeSinceLastInteraction = now.timeIntervalSince(lastInteractionTime)
    guard timeSinceLastInteraction > 0.05 else {
      return
    }
    lastInteractionTime = now

    // Prevent concurrent progress updates
    guard !isUpdatingProgress else {
      return
    }

    isUpdatingProgress = true
    isLocalUpdateInProgress = true

    // Swipe left - decrease progress by 1 (minimum 0)
    let newProgress = max(0, currentProgress - 1)

    // Update UI immediately
    withAnimation(.easeInOut(duration: 0.2)) {
      currentProgress = newProgress
    }

    // Save progress data
    if let progressCallback = onProgressChange {
      progressCallback(habit, selectedDate, newProgress)
    }

    // Record timestamp of this user action
    lastUserUpdateTimestamp = Date()

    // ✅ FIX: Increase delay from 0.1s to 0.5s to ensure persistence completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isUpdatingProgress = false
      isLocalUpdateInProgress = false
    }

    // Haptic feedback for decrease
    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    impactFeedback.impactOccurred()
  }

  private func showCompletionSheet() {
    // Use CompletionStateManager to prevent race conditions
    let completionManager = CompletionStateManager.shared
    guard !completionManager.isShowingCompletionSheet(for: habit.id) else {
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
        isCompletingAnimation = false
      }
    }

    // Show completion sheet immediately
    showingCompletionSheet = true
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
        endDate: nil),
      selectedDate: Date())

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
        endDate: nil),
      selectedDate: Date())

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
        endDate: nil),
      selectedDate: Date())
  }
  .padding()
  .background(.surface2)
}
