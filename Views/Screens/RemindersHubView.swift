import SwiftUI

// MARK: - ReminderWithHabit

struct ReminderWithHabit: Identifiable {
  let id = UUID()
  let reminder: ReminderItem
  let habit: Habit
}

// MARK: - RemindersHubView

struct RemindersHubView: View {
  // MARK: - Environment
  
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var habitRepository: HabitRepository
  
  // MARK: - Computed Properties
  
  /// Get all reminders for today, sorted by time
  private var todaysReminders: [ReminderWithHabit] {
    let today = Date()
    let scheduledHabits = habitRepository.habits.filter { habit in
      StreakDataCalculator.shouldShowHabitOnDate(habit, date: today)
    }
    
    var reminders: [ReminderWithHabit] = []
    for habit in scheduledHabits {
      for reminder in habit.reminders where reminder.isActive {
        reminders.append(ReminderWithHabit(reminder: reminder, habit: habit))
      }
    }
    
    return reminders.sorted { $0.reminder.time < $1.reminder.time }
  }
  
  /// Get all active habits for the "All Habit Reminders" section
  private var allActiveHabits: [Habit] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    return habitRepository.habits.filter { habit in
      let endDate = habit.endDate.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
      return today <= endDate
    }
  }
  
  // MARK: - Body
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Section 1: Today's Reminders
          todayRemindersSection
          
          // Section 2: All Habit Reminders
          allHabitRemindersSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 40)
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("Reminders")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }
  
  // MARK: - Today's Reminders Section
  
  private var todayRemindersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack {
        Text("Today")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        
        Spacer()
        
        Text(formatCurrentDate())
          .font(.appBodyMedium)
          .foregroundColor(.text04)
      }
      
      // Content
      if todaysReminders.isEmpty {
        // Empty state
        todayEmptyState
      } else {
        // Timeline list
        todayRemindersList
      }
    }
  }
  
  private var todayEmptyState: some View {
    VStack(spacing: 12) {
      Image("Icon-Bell_Filled")
        .renderingMode(.template)
        .resizable()
        .frame(width: 40, height: 40)
        .foregroundColor(.text04)
      
      Text("No reminders today")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text02)
      
      Text("Reminders you set for habits will appear here")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
  
  private var todayRemindersList: some View {
    VStack(spacing: 0) {
      ForEach(Array(todaysReminders.enumerated()), id: \.element.id) { index, reminderWithHabit in
        todayReminderRow(reminderWithHabit: reminderWithHabit)
        
        // Divider between rows (not after last row)
        if index < todaysReminders.count - 1 {
          Divider()
            .background(Color("appOutline1Variant"))
            .padding(.horizontal, 16)
        }
      }
    }
    .background(Color("appSurface02Variant"))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color("appOutline1Variant"), lineWidth: 1)
    )
  }
  
  private func todayReminderRow(reminderWithHabit: ReminderWithHabit) -> some View {
    HStack(spacing: 16) {
      // Left: Time and status badge
      VStack(alignment: .leading, spacing: 8) {
        Text(formatTime(reminderWithHabit.reminder.time))
          .font(.appBodyMediumEmphasised)
          .foregroundColor(.text01)
        
        statusBadge(for: reminderWithHabit)
      }
      .frame(width: 100, alignment: .leading)
      
      Spacer()
      
      // Right: Habit icon and name
      HStack(spacing: 12) {
        // Habit icon
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(reminderWithHabit.habit.color.color.opacity(0.15))
            .frame(width: 40, height: 40)
          
          if reminderWithHabit.habit.icon.hasPrefix("Icon-") {
            Image(reminderWithHabit.habit.icon)
              .resizable()
              .frame(width: 18, height: 18)
              .foregroundColor(reminderWithHabit.habit.color.color)
          } else if reminderWithHabit.habit.icon == "None" {
            RoundedRectangle(cornerRadius: 4)
              .fill(reminderWithHabit.habit.color.color)
              .frame(width: 18, height: 18)
          } else {
            Text(reminderWithHabit.habit.icon)
              .font(.system(size: 18))
          }
        }
        
        // Habit name
        Text(reminderWithHabit.habit.name)
          .font(.appBodyMedium)
          .foregroundColor(.text01)
          .lineLimit(2)
      }
    }
    .padding(16)
  }
  
  @ViewBuilder
  private func statusBadge(for reminderWithHabit: ReminderWithHabit) -> some View {
    let isPassed = isReminderTimePassed(reminderWithHabit.reminder)
    let isCompleted = isHabitCompletedToday(reminderWithHabit.habit)
    
    if isPassed && isCompleted {
      // Completed
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 12))
        Text("Completed")
          .font(.appBodySmall)
      }
      .foregroundColor(.green)
    } else if isPassed && !isCompleted {
      // Missed
      HStack(spacing: 4) {
        Text("Missed")
          .font(.appBodySmall)
      }
      .foregroundColor(.red.opacity(0.8))
    } else {
      // Upcoming
      HStack(spacing: 4) {
        Text("Upcoming")
          .font(.appBodySmall)
      }
      .foregroundColor(.text04)
    }
  }
  
  // MARK: - All Habit Reminders Section
  
  private var allHabitRemindersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      Text("All Habit Reminders")
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.text01)
      
      // Content
      if allActiveHabits.isEmpty {
        // Empty state
        allHabitsEmptyState
      } else {
        // Habit list
        allHabitsList
      }
    }
  }
  
  private var allHabitsEmptyState: some View {
    VStack(spacing: 12) {
      Image("Icon-Bell_Filled")
        .renderingMode(.template)
        .resizable()
        .frame(width: 40, height: 40)
        .foregroundColor(.text04)
      
      Text("No habits yet")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text02)
      
      Text("Create a habit to set up reminders")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
  
  private var allHabitsList: some View {
    VStack(spacing: 0) {
      ForEach(Array(allActiveHabits.enumerated()), id: \.element.id) { index, habit in
        habitReminderRow(habit: habit)
        
        // Divider between rows (not after last row)
        if index < allActiveHabits.count - 1 {
          Divider()
            .background(Color("appOutline1Variant"))
            .padding(.horizontal, 16)
        }
      }
    }
    .background(Color("appSurface02Variant"))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color("appOutline1Variant"), lineWidth: 1)
    )
  }
  
  private func habitReminderRow(habit: Habit) -> some View {
    Button(action: {
      navigateToHabitDetail(habit)
    }) {
      HStack(spacing: 16) {
        // Left: Habit icon
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(habit.color.color.opacity(0.15))
            .frame(width: 40, height: 40)
          
          if habit.icon.hasPrefix("Icon-") {
            Image(habit.icon)
              .resizable()
              .frame(width: 18, height: 18)
              .foregroundColor(habit.color.color)
          } else if habit.icon == "None" {
            RoundedRectangle(cornerRadius: 4)
              .fill(habit.color.color)
              .frame(width: 18, height: 18)
          } else {
            Text(habit.icon)
              .font(.system(size: 18))
          }
        }
        
        // Middle: Habit name and reminder info
        VStack(alignment: .leading, spacing: 4) {
          Text(habit.name)
            .font(.appBodyMediumEmphasised)
            .foregroundColor(.onPrimaryContainer)
            .lineLimit(1)
          
          Text(formatReminderInfo(for: habit))
            .font(.appBodySmall)
            .foregroundColor(.text04)
            .lineLimit(1)
        }
        
        Spacer()
        
        // Right: Toggle or Add button
        if habit.reminders.isEmpty {
          Text("Add")
            .font(.appBodySmallEmphasised)
            .foregroundColor(Color("navy500"))
        } else {
          Toggle("", isOn: Binding(
            get: { areRemindersActive(for: habit) },
            set: { enabled in toggleHabitReminders(habit, enabled: enabled) }
          ))
          .toggleStyle(SwitchToggleStyle())
          .controlSize(.mini)
          .scaleEffect(0.75)
          .labelsHidden()
          .onTapGesture {
            // Prevent row tap when toggle is tapped
          }
        }
      }
      .padding(16)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  // MARK: - Helper Functions
  
  private func formatCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: Date())
  }
  
  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  
  private func formatReminderInfo(for habit: Habit) -> String {
    if habit.reminders.isEmpty {
      return "No reminder set"
    }
    
    let activeReminders = habit.reminders.filter { $0.isActive }
    if activeReminders.isEmpty {
      return "No reminder set"
    }
    
    let schedule = formatReminderSchedule(habit)
    let times = activeReminders.map { formatTime($0.time) }.joined(separator: ", ")
    return "\(schedule) · \(times)"
  }
  
  private func formatReminderSchedule(_ habit: Habit) -> String {
    // Parse the schedule string from the habit
    let schedule = habit.schedule.lowercased()
    
    if schedule.contains("everyday") || schedule.contains("daily") {
      return "Daily"
    } else if schedule.contains("weekdays") {
      return "Weekdays"
    } else if schedule.contains("weekends") {
      return "Weekends"
    } else if schedule.contains("custom") {
      // Try to parse custom days
      // This is a simplified version - you may need to enhance based on your schedule format
      return "Custom"
    } else {
      return "Daily"
    }
  }
  
  private func isReminderTimePassed(_ reminder: ReminderItem) -> Bool {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    
    let reminderDateTime = calendar.date(
      bySettingHour: calendar.component(.hour, from: reminder.time),
      minute: calendar.component(.minute, from: reminder.time),
      second: 0,
      of: today
    ) ?? today
    
    return now > reminderDateTime
  }
  
  private func isHabitCompletedToday(_ habit: Habit) -> Bool {
    let progress = habitRepository.getProgress(for: habit, date: Date())
    let goalAmount = parseGoalAmount(from: habit.goal)
    return progress >= goalAmount
  }
  
  private func parseGoalAmount(from goal: String) -> Int {
    // Extract the numeric value from goal string (e.g., "5 times" -> 5)
    let components = goal.components(separatedBy: " ")
    if let firstComponent = components.first,
       let amount = Int(firstComponent) {
      return amount
    }
    return 1 // Default to 1 if parsing fails
  }
  
  private func areRemindersActive(for habit: Habit) -> Bool {
    return habit.reminders.contains { $0.isActive }
  }
  
  private func toggleHabitReminders(_ habit: Habit, enabled: Bool) {
    // Update all reminders for this habit
    var updatedReminders = habit.reminders
    for i in updatedReminders.indices {
      updatedReminders[i].isActive = enabled
    }
    
    // Create a new Habit instance with updated reminders (Habit is immutable)
    let updatedHabit = Habit(
      id: habit.id,
      name: habit.name,
      description: habit.description,
      icon: habit.icon,
      color: habit.color,
      habitType: habit.habitType,
      schedule: habit.schedule,
      goal: habit.goal,
      reminder: habit.reminder,
      startDate: habit.startDate,
      endDate: habit.endDate,
      createdAt: habit.createdAt,
      reminders: updatedReminders,
      baseline: habit.baseline,
      target: habit.target,
      completionHistory: habit.completionHistory,
      completionStatus: habit.completionStatus,
      completionTimestamps: habit.completionTimestamps,
      difficultyHistory: habit.difficultyHistory,
      actualUsage: habit.actualUsage,
      goalHistory: habit.goalHistory,
      lastSyncedAt: habit.lastSyncedAt,
      syncStatus: habit.syncStatus,
      skippedDays: habit.skippedDays)
    
    // Save to repository
    Task {
      do {
        try await habitRepository.updateHabit(updatedHabit)
      } catch {
        print("❌ Failed to update habit reminders: \(error.localizedDescription)")
      }
    }
    
    // Update notifications
    if enabled {
      NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
    } else {
      NotificationManager.shared.removeAllNotifications(for: updatedHabit)
    }
    
    // Haptic feedback
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
  
  private func navigateToHabitDetail(_ habit: Habit) {
    dismiss()
    
    // Post notification to open habit detail
    NotificationCenter.default.post(
      name: NSNotification.Name("OpenHabitDetail"),
      object: nil,
      userInfo: ["habitId": habit.id]
    )
    
    // Haptic feedback
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}

#Preview {
  RemindersHubView()
    .environmentObject(HabitRepository.shared)
}
