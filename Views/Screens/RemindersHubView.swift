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
  
  // MARK: - Settings Sheet
  
  @State private var showingNotificationsSettings = false
  
  // MARK: - Add Reminder Sheet
  
  @State private var showingAddReminderSheet = false
  @State private var habitToAddReminder: Habit? = nil
  
  // MARK: - Expandable Habit Rows
  
  @State private var expandedHabitId: UUID? = nil
  
  // MARK: - Edit Reminder
  
  @State private var reminderToEdit: ReminderItem? = nil
  @State private var showingEditReminderSheet = false
  
  // MARK: - Delete Reminder
  
  @State private var reminderToDelete: ReminderItem? = nil
  @State private var habitForReminderDeletion: Habit? = nil
  @State private var showingReminderDeleteConfirmation = false
  
  // MARK: - Global Reminder Setting
  
  @AppStorage("habitReminderEnabled") private var habitRemindersEnabled = true
  
  // MARK: - Date Selection
  
  @State private var selectedDate: Date = Date()
  
  // MARK: - Skip Reminder State
  // Key: "dateKey_reminderId" (e.g., "2026-01-21_uuid")
  // Value: true if skipped for that date
  @State private var skippedReminders: Set<String> = []
  
  // For confirmation alert
  @State private var reminderToSkip: ReminderWithHabit? = nil
  @State private var showingSkipConfirmation = false
  
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
  
  // MARK: - Warning Banner
  
  @ViewBuilder
  private var remindersDisabledBanner: some View {
    if !habitRemindersEnabled {
      Button(action: {
        showingNotificationsSettings = true
      }) {
        HStack(spacing: 12) {
          // Warning icon
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 18))
            .foregroundColor(.orange)
          
          // Text content
          VStack(alignment: .leading, spacing: 2) {
            Text("Habit reminders are off")
              .font(.appBodyMediumEmphasised)
              .foregroundColor(.text01)
            
            Text("Turn on in Settings")
              .font(.appBodySmall)
              .foregroundColor(.text04)
          }
          
          Spacer()
          
          // Arrow
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.text04)
        }
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color.orange.opacity(0.1))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
      }
      .buttonStyle(PlainButtonStyle())
      .padding(.horizontal, 20)
    }
  }
  
  // MARK: - Body
  
  var body: some View {
    NavigationView {
      ZStack {
        Color("appSurface01Variant02")
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Warning banner (only shows when reminders disabled)
          remindersDisabledBanner
            .padding(.top, 8)
            .padding(.bottom, habitRemindersEnabled ? 0 : 8)
          
          // Tab segmented control
          tabSegmentedControl
            .padding(.top, habitRemindersEnabled ? 24 : 8)
            .padding(.bottom, 20)
          
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
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            showingNotificationsSettings = true
          }) {
            Image(systemName: "gearshape.fill")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
          }
        }
      }
      .sheet(isPresented: $showingNotificationsSettings) {
        NotificationsView()
      }
      .sheet(isPresented: $showingAddReminderSheet) {
        if let habit = habitToAddReminder {
          AddReminderSheet(
            initialTime: defaultReminderTime(),
            isEditing: false,
            onSave: { selectedTime in
              addReminderToHabit(habit, time: selectedTime)
            }
          )
          .presentationDetents([.height(500)])
          .presentationDragIndicator(.visible)
        }
      }
      .sheet(isPresented: $showingEditReminderSheet) {
        if let reminder = reminderToEdit, let habit = habitToAddReminder {
          AddReminderSheet(
            initialTime: reminder.time,
            isEditing: true,
            onSave: { newTime in
              updateReminder(reminder, in: habit, newTime: newTime)
            }
          )
          .presentationDetents([.height(500)])
          .presentationDragIndicator(.visible)
        }
      }
      .alert("Delete Reminder", isPresented: $showingReminderDeleteConfirmation) {
        Button("Cancel", role: .cancel) {
          reminderToDelete = nil
          habitForReminderDeletion = nil
        }
        Button("Delete", role: .destructive) {
          if let reminder = reminderToDelete, let habit = habitForReminderDeletion {
            deleteReminder(reminder, from: habit)
          }
        }
      } message: {
        Text("Are you sure you want to delete this reminder?")
      }
      .alert("Skip Reminder", isPresented: $showingSkipConfirmation) {
        Button("Cancel", role: .cancel) {
          reminderToSkip = nil
        }
        Button("Skip for Today", role: .destructive) {
          confirmSkipReminder()
        }
      } message: {
        if let reminder = reminderToSkip {
          Text("Skip the \(formatTime(reminder.reminder.time)) reminder for \(reminder.habit.name) on \(formatSelectedDateLabel(selectedDate))?")
        } else {
          Text("Skip this reminder for today?")
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
    let isSkipped = isReminderSkipped(reminderWithHabit.reminder)
    
    return Button(action: {
      // Navigate to habit detail
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
        
        // Habit name + time + skipped status
        VStack(alignment: .leading, spacing: 2) {
          Text(reminderWithHabit.habit.name)
            .font(.appBodyMediumEmphasised)
            .foregroundColor(isSkipped ? .text04 : .onPrimaryContainer)
          
          HStack(spacing: 4) {
            Text(formatTime(reminderWithHabit.reminder.time))
              .font(.appBodySmall)
              .foregroundColor(.text04)
            
            if isSkipped {
              Text("·")
                .font(.appBodySmall)
                .foregroundColor(.text04)
              
              Text("Skipped")
                .font(.appBodySmall)
                .foregroundColor(.orange)
            }
          }
        }
        
        Spacer()
        
        // Completion checkmark (if completed on selected date)
        if isHabitCompletedOnDate(reminderWithHabit.habit) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 22))
        }
        
        // Toggle for skip/enable reminder
        Toggle("", isOn: Binding(
          get: { !isSkipped },  // Toggle is ON when NOT skipped
          set: { newValue in
            if !newValue {
              // User is turning OFF (skipping)
              toggleSkipReminder(reminderWithHabit)
            } else {
              // User is turning ON (un-skipping) - no confirmation needed
              let key = skipKey(for: reminderWithHabit.reminder, on: selectedDate)
              skippedReminders.remove(key)
              UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
          }
        ))
        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
        .labelsHidden()
        .scaleEffect(0.8)  // Slightly smaller to fit nicely
        .onTapGesture {
          // Prevent row tap when toggle is tapped
        }
      }
      .padding(16)
      .opacity(isSkipped ? 0.7 : 1.0)
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
      .padding(.top, 8)
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
      VStack(spacing: 0) {
        // Day name (SUN, MON, etc.) - matches Home screen styling
        Text(formatDayName(date).uppercased())
          .font(.system(size: 10, weight: .bold))
          .frame(height: 16)
          .foregroundColor(isSelected ? .appOnPrimary80 : .appText06)
        
        // Day number
        Text(formatDayNumber(date))
          .font(.appBodyMedium)
          .foregroundColor(isSelected ? .onPrimary : .text04)
        
        // Today indicator dot
        Circle()
          .fill(isToday ? (isSelected ? Color.onPrimary : Color.primary) : Color.clear)
          .frame(width: 6, height: 6)
      }
      .frame(width: 44, height: 64)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.primary : Color.clear)
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
    VStack(spacing: 12) {
      ForEach(allActiveHabits) { habit in
        expandableHabitReminderRow(habit)
      }
    }
    .padding(.horizontal, 20)
  }
  
  private func expandableHabitReminderRow(_ habit: Habit) -> some View {
    let isExpanded = expandedHabitId == habit.id
    
    return VStack(spacing: 0) {
      // Main row (always visible)
      Button(action: {
        withAnimation(.easeInOut(duration: 0.25)) {
          if expandedHabitId == habit.id {
            expandedHabitId = nil  // Collapse
          } else {
            expandedHabitId = habit.id  // Expand
          }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }) {
        HStack(spacing: 12) {
          // Habit icon
          habitIconView(for: habit)
          
          // Info
          VStack(alignment: .leading, spacing: 2) {
            Text(habit.name)
              .font(.appBodyMediumEmphasised)
              .foregroundColor(.text01)
            
            let count = habit.reminders.count
            Text(count == 0 ? "No reminders" : 
                 count == 1 ? "1 reminder" : 
                 "\(count) reminders")
              .font(.appBodySmall)
              .foregroundColor(.text04)
          }
          
          Spacer()
          
          // Chevron (rotates when expanded)
          Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.text04)
            .rotationEffect(.degrees(isExpanded ? -180 : 0))
        }
        .padding(16)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
      
      // Expanded content (reminders list)
      if isExpanded {
        expandedRemindersList(for: habit)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Color("appSurface02Variant"))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color("appOutline1Variant"), lineWidth: 1)
    )
  }
  
  private func habitIconView(for habit: Habit) -> some View {
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
  }
  
  @ViewBuilder
  private func expandedRemindersList(for habit: Habit) -> some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, 16)
      
      VStack(spacing: 8) {
        // Existing reminders
        if !habit.reminders.isEmpty {
          ForEach(habit.reminders) { reminder in
            reminderItemRow(reminder, habit: habit)
          }
        }
        
        // Add button
        Button(action: {
          habitToAddReminder = habit
          showingAddReminderSheet = true
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
          HStack {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.appPrimary)
            Text("Add Reminder")
              .font(.appBodyMedium)
              .foregroundColor(.appPrimary)
            Spacer()
          }
          .padding(.vertical, 12)
          .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.vertical, 8)
    }
  }
  
  private func reminderItemRow(_ reminder: ReminderItem, habit: Habit) -> some View {
    HStack(spacing: 12) {
      // Time
      Text(formatTime(reminder.time))
        .font(.appBodyMedium)
        .foregroundColor(.text01)
      
      Spacer()
      
      // Edit button
      Button(action: {
        reminderToEdit = reminder
        habitToAddReminder = habit
        showingEditReminderSheet = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }) {
        Image("Icon-Pen_Filled")
          .renderingMode(.template)
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(.appText01)
          .padding(8)
      }
      .buttonStyle(PlainButtonStyle())
      
      // Delete button
      Button(action: {
        reminderToDelete = reminder
        habitForReminderDeletion = habit
        showingReminderDeleteConfirmation = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }) {
        Image("Icon-TrashBin3_Filled")
          .renderingMode(.template)
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(.red)
          .padding(8)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }
  
  // MARK: - Skip Reminder Helpers
  
  /// Generate a unique key for reminder+date combination
  private func skipKey(for reminder: ReminderItem, on date: Date) -> String {
    let dateKey = formatDateKey(date)
    return "\(dateKey)_\(reminder.id.uuidString)"
  }
  
  /// Format date as key string (e.g., "2026-01-21")
  private func formatDateKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
  
  /// Check if reminder is skipped for selected date
  private func isReminderSkipped(_ reminder: ReminderItem) -> Bool {
    let key = skipKey(for: reminder, on: selectedDate)
    return skippedReminders.contains(key)
  }
  
  /// Toggle skip state for a reminder on selected date
  private func toggleSkipReminder(_ reminderWithHabit: ReminderWithHabit) {
    let key = skipKey(for: reminderWithHabit.reminder, on: selectedDate)
    
    if skippedReminders.contains(key) {
      // Un-skip: remove from set
      skippedReminders.remove(key)
      // Re-schedule notification for this reminder today
      // (Optional: implement if needed)
      
      // Haptic feedback
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    } else {
      // Skip: show confirmation first
      reminderToSkip = reminderWithHabit
      showingSkipConfirmation = true
    }
  }
  
  /// Confirm skipping the reminder
  private func confirmSkipReminder() {
    guard let reminderWithHabit = reminderToSkip else { return }
    
    let key = skipKey(for: reminderWithHabit.reminder, on: selectedDate)
    skippedReminders.insert(key)
    
    // Cancel the notification for this specific reminder on this date
    cancelNotificationForReminder(reminderWithHabit.reminder, on: selectedDate)
    
    // Haptic feedback
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    
    // Clear the pending skip
    reminderToSkip = nil
  }
  
  /// Cancel notification for a specific reminder on a specific date
  private func cancelNotificationForReminder(_ reminder: ReminderItem, on date: Date) {
    // Visual skip state is the main feature
    // Actual notification cancellation can be implemented later if needed
  }
  
  /// Optional: Clean up old skip states to keep memory clean for long sessions
  private func cleanupOldSkipStates() {
    let currentDateKey = formatDateKey(selectedDate)
    skippedReminders = skippedReminders.filter { $0.hasPrefix(currentDateKey) }
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
  
  /// Get a sensible default time for new reminders (e.g., 9:00 AM or next hour)
  private func defaultReminderTime() -> Date {
    let calendar = Calendar.current
    let now = Date()
    
    // Round up to the next hour
    let components = calendar.dateComponents([.hour], from: now)
    let nextHour = (components.hour ?? 9) + 1
    
    return calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
  }
  
  /// Add a new reminder to a habit and save
  private func addReminderToHabit(_ habit: Habit, time: Date) {
    // Create new reminder
    let newReminder = ReminderItem(time: time, isActive: true)
    let updatedReminders = habit.reminders + [newReminder]
    
    saveUpdatedReminders(updatedReminders, for: habit)
    
    // Clear state
    habitToAddReminder = nil
    
    print("✅ RemindersHubView: Added reminder to habit '\(habit.name)' at \(time)")
  }
  
  /// Update an existing reminder with new time
  private func updateReminder(_ reminder: ReminderItem, in habit: Habit, newTime: Date) {
    let updatedReminders = habit.reminders.map { r in
      if r.id == reminder.id {
        var updated = r
        updated.time = newTime
        return updated
      }
      return r
    }
    
    saveUpdatedReminders(updatedReminders, for: habit)
    
    // Clear state
    reminderToEdit = nil
    habitToAddReminder = nil
    
    print("✅ RemindersHubView: Updated reminder in habit '\(habit.name)' to \(newTime)")
  }
  
  /// Delete a reminder from a habit
  private func deleteReminder(_ reminder: ReminderItem, from habit: Habit) {
    let updatedReminders = habit.reminders.filter { $0.id != reminder.id }
    saveUpdatedReminders(updatedReminders, for: habit)
    
    // Clear state
    reminderToDelete = nil
    habitForReminderDeletion = nil
    
    print("✅ RemindersHubView: Deleted reminder from habit '\(habit.name)'")
  }
  
  /// Save updated reminders to a habit
  private func saveUpdatedReminders(_ reminders: [ReminderItem], for habit: Habit) {
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
      reminders: reminders,
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
      skippedDays: habit.skippedDays
    )
    
    Task {
      do {
        try await habitRepository.updateHabit(updatedHabit)
        
        // Update notifications
        NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: reminders)
        
        // Haptic feedback for success
        await MainActor.run {
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
      } catch {
        print("❌ RemindersHubView: Failed to update reminders: \(error)")
      }
    }
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
