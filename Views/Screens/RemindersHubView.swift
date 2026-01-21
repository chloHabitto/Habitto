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
  
  // MARK: - Tab Selection
  
  enum ReminderTab: Int, CaseIterable {
    case schedule = 0
    case habits = 1
  }
  
  @State private var selectedTab: ReminderTab = .schedule
  
  // MARK: - Date Selection
  
  @State private var selectedDate: Date = Date()
  
  // MARK: - Computed Properties
  
  /// Get all reminders for selected date, sorted by time
  private var remindersForSelectedDate: [ReminderWithHabit] {
    let scheduledHabits = habitRepository.habits.filter { habit in
      StreakDataCalculator.shouldShowHabitOnDate(habit, date: selectedDate)
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
      ZStack {
        Color("appSurface01Variant02")
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Tab segmented control
          tabSegmentedControl
            .padding(.top, 16)
            .padding(.bottom, 12)
          
          // Tab content
          if selectedTab == .schedule {
            scheduleTabContent
          } else {
            habitsTabContent
          }
        }
      }
      .navigationTitle("Reminders")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.text01)
          }
        }
      }
    }
  }
  
  // MARK: - Tab Segmented Control
  
  private var tabSegmentedControl: some View {
    HStack(spacing: 8) {
      tabButton(
        title: "Schedule",
        count: remindersForSelectedDate.count,
        tab: .schedule
      )
      tabButton(
        title: "Habits",
        count: allActiveHabits.count,
        tab: .habits
      )
      Spacer()
    }
    .padding(.horizontal, 20)
  }
  
  private func tabButton(title: String, count: Int, tab: ReminderTab) -> some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedTab = tab
      }
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }) {
      HStack(spacing: 4) {
        if selectedTab == tab {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.appOnPrimaryContainer)
        }
        Text("\(title) (\(count))")
          .font(selectedTab == tab ? .appLabelMediumEmphasised : .appLabelMedium)
          .foregroundColor(selectedTab == tab ? .appOnPrimaryContainer : .appText03)
      }
      .padding(.leading, selectedTab == tab ? 16 : 12)
      .padding(.trailing, 12)
      .frame(height: 32)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(selectedTab == tab ? Color.appPrimaryContainer : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(selectedTab == tab ? Color.clear : Color.appOutline02, lineWidth: 1)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  // MARK: - Schedule Tab Content
  
  private var scheduleTabContent: some View {
    VStack(spacing: 0) {
      // Date strip
      dateStripSection
        .padding(.bottom, 16)
      
      // Reminders list
      if remindersForSelectedDate.isEmpty {
        Spacer()
        emptyStateForSchedule
        Spacer()
      } else {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(Array(remindersForSelectedDate.enumerated()), id: \.element.id) { index, reminderWithHabit in
              scheduleReminderRow(for: reminderWithHabit)
              
              if index < remindersForSelectedDate.count - 1 {
                Divider()
                  .padding(.leading, 76)
              }
            }
          }
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(Color("appSurface02Variant"))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color("appOutline1Variant"), lineWidth: 1)
          )
          .padding(.horizontal, 20)
          .padding(.bottom, 40)
        }
      }
    }
  }
  
  private func scheduleReminderRow(for reminderWithHabit: ReminderWithHabit) -> some View {
    Button(action: {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      navigateToHabitDetail(reminderWithHabit.habit)
    }) {
      HStack(spacing: 12) {
        // Habit icon
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(reminderWithHabit.habit.color.color.opacity(0.15))
            .frame(width: 44, height: 44)
          
          if reminderWithHabit.habit.icon.hasPrefix("Icon-") {
            Image(reminderWithHabit.habit.icon)
              .resizable()
              .frame(width: 22, height: 22)
              .foregroundColor(reminderWithHabit.habit.color.color)
          } else if reminderWithHabit.habit.icon == "None" {
            RoundedRectangle(cornerRadius: 4)
              .fill(reminderWithHabit.habit.color.color)
              .frame(width: 22, height: 22)
          } else {
            Text(reminderWithHabit.habit.icon)
              .font(.system(size: 22))
          }
        }
        
        // Habit name + time
        VStack(alignment: .leading, spacing: 2) {
          Text(reminderWithHabit.habit.name)
            .font(.appBodyMediumEmphasised)
            .foregroundColor(.onPrimaryContainer)
          
          Text(formatTime(reminderWithHabit.reminder.time))
            .font(.appBodySmall)
            .foregroundColor(.text04)
        }
        
        Spacer()
        
        // Completion checkmark (if completed on selected date)
        if isHabitCompletedOnDate(reminderWithHabit.habit) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 22))
        }
      }
      .padding(16)
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private var emptyStateForSchedule: some View {
    VStack(spacing: 12) {
      Image("Icon-Bell_Filled")
        .renderingMode(.template)
        .resizable()
        .frame(width: 48, height: 48)
        .foregroundColor(.text04)
      
      Text("No reminders")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text02)
      
      Text("No reminders scheduled for \(formatSelectedDateLabel(selectedDate))")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 40)
  }
  
  // MARK: - Date Strip
  
  private var dateStripSection: some View {
    VStack(spacing: 12) {
      // Week day strip
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(datesForCurrentWeek, id: \.self) { date in
              dateCell(for: date)
                .id(date)
            }
          }
          .padding(.horizontal, 20)
        }
        .onAppear {
          // Scroll to selected date
          proxy.scrollTo(selectedDate, anchor: .center)
        }
      }
      
      // Selected date label + reminder count
      HStack {
        Text(formatSelectedDateLabel(selectedDate))
          .font(.appBodyMediumEmphasised)
          .foregroundColor(.text01)
        
        Text("·")
          .foregroundColor(.text04)
        
        Text("\(remindersForSelectedDate.count) reminder\(remindersForSelectedDate.count == 1 ? "" : "s")")
          .font(.appBodyMedium)
          .foregroundColor(.text04)
        
        Spacer()
      }
      .padding(.horizontal, 20)
    }
  }
  
  private func dateCell(for date: Date) -> some View {
    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
    let isToday = Calendar.current.isDateInToday(date)
    
    return Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedDate = date
      }
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }) {
      VStack(spacing: 4) {
        // Day name (Mon, Tue, etc.)
        Text(formatDayName(date))
          .font(.appBodySmall)
          .foregroundColor(isSelected ? .appOnPrimaryContainer : .text04)
        
        // Day number
        Text(formatDayNumber(date))
          .font(.appBodyMediumEmphasised)
          .foregroundColor(isSelected ? .appOnPrimaryContainer : .text01)
        
        // Today indicator dot
        Circle()
          .fill(isToday ? (isSelected ? Color.appOnPrimaryContainer : Color("navy500")) : Color.clear)
          .frame(width: 6, height: 6)
      }
      .frame(width: 44, height: 64)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color("navy500") : Color.clear)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  // MARK: - Date Helper Properties
  
  private var datesForCurrentWeek: [Date] {
    let calendar = Calendar.current
    let today = Date()
    
    // Get start of week (Sunday or Monday based on locale)
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
      return []
    }
    
    // Generate 7 days for the week
    var dates: [Date] = []
    for dayOffset in 0..<7 {
      if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) {
        dates.append(date)
      }
    }
    
    return dates
  }
  
  // MARK: - Habits Tab Content
  
  private var habitsTabContent: some View {
    ScrollView {
      VStack(spacing: 0) {
        // Habits count header
        HStack {
          Text("\(allActiveHabits.count) habit\(allActiveHabits.count == 1 ? "" : "s")")
            .font(.appBodyMedium)
            .foregroundColor(.text04)
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        
        // Habits list
        habitsRemindersList
      }
      .padding(.top, 8)
    }
  }
  
  private var habitsRemindersList: some View {
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
    .padding(.horizontal, 20)
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
  
  // MARK: - Date Formatting Helpers
  
  private func formatDayName(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter.string(from: date)
  }
  
  private func formatDayNumber(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
  }
  
  private func formatSelectedDateLabel(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
  }
  
  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  
  // MARK: - Helper Functions
  
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
    // Only check time if selected date is today
    guard Calendar.current.isDateInToday(selectedDate) else {
      return false // Future/past dates - nothing has "passed"
    }
    
    let calendar = Calendar.current
    let now = Date()
    
    let reminderDateTime = calendar.date(
      bySettingHour: calendar.component(.hour, from: reminder.time),
      minute: calendar.component(.minute, from: reminder.time),
      second: 0,
      of: selectedDate
    ) ?? selectedDate
    
    return now > reminderDateTime
  }
  
  private func isHabitCompletedOnDate(_ habit: Habit) -> Bool {
    let progress = habitRepository.getProgress(for: habit, date: selectedDate)
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
