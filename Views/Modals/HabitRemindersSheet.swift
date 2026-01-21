import SwiftUI

// MARK: - HabitRemindersSheet

struct HabitRemindersSheet: View {
  // MARK: Internal
  
  let habit: Habit
  let onUpdate: (Habit) -> Void
  
  @Environment(\.dismiss) private var dismiss
  @AppStorage("habitReminderEnabled") private var habitRemindersEnabled = true
  
  var body: some View {
    VStack(spacing: 0) {
      // Header Section
      headerSection
      
      Divider()
        .padding(.horizontal, 24)
      
      // Content Section
      if habit.reminders.isEmpty {
        emptyStateSection
      } else {
        remindersListSection
      }
      
      Spacer()
      
      // Add Reminder Button (always visible at bottom)
      addReminderButton
    }
    .padding(.top, 8)
    .padding(.bottom, 24)
    .background(Color.appSurface01Variant)
    .ignoresSafeArea(edges: .bottom)
    .sheet(isPresented: $showingAddSheet) {
      AddReminderSheet(
        initialTime: reminderToEdit?.time ?? defaultReminderTime(),
        isEditing: reminderToEdit != nil,
        onSave: { selectedTime in
          saveReminderTime(selectedTime)
        }
      )
      .presentationDetents([.height(500)])
      .presentationDragIndicator(.visible)
    }
    .alert("Delete Reminder", isPresented: $showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        reminderToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let reminder = reminderToDelete {
          deleteReminder(reminder)
          reminderToDelete = nil
        }
      }
    } message: {
      Text("Are you sure you want to delete this reminder?")
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 16) {
      // Close button
      HStack {
        Spacer()
        
        Button(action: {
          dismiss()
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(.text07)
            .frame(width: 44, height: 44)
        }
      }
      .padding(.top, 8)
      .padding(.horizontal, 24)
      
      // Habit Icon + Name
      HStack(spacing: 12) {
        // Habit Icon
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .fill(habit.color.color.opacity(0.15))
            .frame(width: 48, height: 48)
          
          if habit.icon.hasPrefix("Icon-") {
            Image(habit.icon)
              .resizable()
              .frame(width: 24, height: 24)
              .foregroundColor(habit.color.color)
          } else if habit.icon == "None" {
            RoundedRectangle(cornerRadius: 8)
              .fill(habit.color.color)
              .frame(width: 24, height: 24)
          } else {
            Text(habit.icon)
              .font(.system(size: 24))
          }
        }
        
        // Habit Name
        Text(habit.name)
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.text01)
        
        Spacer()
      }
      .padding(.horizontal, 24)
      
      // Warning banner when habit reminders are disabled
      if !habitRemindersEnabled {
        Button(action: {
          showingNotificationsSettings = true
        }) {
          HStack(spacing: 8) {
            Text("⚠️")
              .font(.system(size: 14))
            
            Text("Reminders off")
              .font(.appBodySmall)
              .foregroundColor(.text01)
            
            Text("·")
              .font(.appBodySmall)
              .foregroundColor(.text04)
            
            Text("Enable")
              .font(.appBodySmall)
              .foregroundColor(.primary)
            
            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.orange.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 24)
      }
    }
    .padding(.bottom, 20)
  }
  
  // MARK: - Empty State Section
  
  private var emptyStateSection: some View {
    VStack(spacing: 16) {
      Spacer()
      
      Image("Icon-Bell_Outlined")
        .renderingMode(.template)
        .resizable()
        .frame(width: 48, height: 48)
        .foregroundColor(.text04)
      
      Text("No reminders set")
        .font(.appBodyMediumEmphasised)
        .foregroundColor(.text02)
      
      Text("Add a reminder to stay on track with this habit")
        .font(.appBodySmall)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      
      Spacer()
    }
    .padding(.top, 40)
  }
  
  // MARK: - Reminders List Section
  
  private var remindersListSection: some View {
    ScrollView {
      VStack(spacing: 12) {
        ForEach(habit.reminders, id: \.id) { reminder in
          reminderRow(for: reminder)
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 16)
    }
  }
  
  private func reminderRow(for reminder: ReminderItem) -> some View {
    HStack(spacing: 16) {
      // Time text
      Text(formatReminderTime(reminder.time))
        .font(.appBodyLarge)
        .foregroundColor(habitRemindersEnabled ? .text01 : .text04)
      
      Spacer()
      
      // Edit button
      Button(action: {
        reminderToEdit = reminder
        showingAddSheet = true
      }) {
        Image("Icon-Pen_Filled")
          .renderingMode(.template)
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(habitRemindersEnabled ? .appText01 : .text05)
          .padding(8)
      }
      .disabled(!habitRemindersEnabled)
      
      // Delete button
      Button(action: {
        reminderToDelete = reminder
        showingDeleteConfirmation = true
      }) {
        Image("Icon-TrashBin3_Filled")
          .renderingMode(.template)
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(.red)
          .padding(8)
      }
      .disabled(!habitRemindersEnabled)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color.surfaceContainer.opacity(habitRemindersEnabled ? 0.5 : 0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .opacity(habitRemindersEnabled ? 1.0 : 0.6)
  }
  
  // MARK: - Add Reminder Button
  
  private var addReminderButton: some View {
    Button(action: {
      reminderToEdit = nil
      showingAddSheet = true
    }) {
      HStack {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(habitRemindersEnabled ? .primary : .text04)
        
        Text("Add Reminder")
          .font(.appLabelLargeEmphasised)
          .foregroundColor(habitRemindersEnabled ? .primary : .text04)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(Color.primaryContainer.opacity(habitRemindersEnabled ? 1.0 : 0.5))
      .clipShape(RoundedRectangle(cornerRadius: 30))
    }
    .buttonStyle(PlainButtonStyle())
    .padding(.horizontal, 24)
    .disabled(!habitRemindersEnabled)
  }
  
  // MARK: Private
  
  @State private var showingAddSheet = false
  @State private var reminderToEdit: ReminderItem? = nil
  @State private var showingDeleteConfirmation = false
  @State private var reminderToDelete: ReminderItem? = nil
  @State private var showingNotificationsSettings = false
  
  private func formatReminderTime(_ time: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: time)
  }
  
  private func defaultReminderTime() -> Date {
    let calendar = Calendar.current
    let now = Date()
    
    // Round up to the next hour
    let components = calendar.dateComponents([.hour], from: now)
    let nextHour = (components.hour ?? 9) + 1
    
    return calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
  }
  
  private func saveReminderTime(_ time: Date) {
    let updatedReminders: [ReminderItem]
    
    if let existingReminder = reminderToEdit {
      // Update existing reminder
      updatedReminders = habit.reminders.map { reminder in
        if reminder.id == existingReminder.id {
          var updated = reminder
          updated.time = time
          return updated
        }
        return reminder
      }
    } else {
      // Add new reminder
      let newReminder = ReminderItem(time: time, isActive: true)
      updatedReminders = habit.reminders + [newReminder]
    }
    
    // Create updated habit
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
      completionTimestamps: habit.completionTimestamps,
      difficultyHistory: habit.difficultyHistory,
      actualUsage: habit.actualUsage,
      goalHistory: habit.goalHistory,
      lastSyncedAt: habit.lastSyncedAt,
      syncStatus: habit.syncStatus,
      skippedDays: habit.skippedDays
    )
    
    // Update notifications
    NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
    
    // Notify parent
    onUpdate(updatedHabit)
    
    // Clear selected reminder
    reminderToEdit = nil
    
    // Haptic feedback
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
  
  private func deleteReminder(_ reminder: ReminderItem) {
    let updatedReminders = habit.reminders.filter { $0.id != reminder.id }
    
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
      completionTimestamps: habit.completionTimestamps,
      difficultyHistory: habit.difficultyHistory,
      actualUsage: habit.actualUsage,
      goalHistory: habit.goalHistory,
      lastSyncedAt: habit.lastSyncedAt,
      syncStatus: habit.syncStatus,
      skippedDays: habit.skippedDays
    )
    
    // Update notifications for the habit
    NotificationManager.shared.updateNotifications(for: updatedHabit, reminders: updatedReminders)
    
    onUpdate(updatedHabit)
    
    // Haptic feedback
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }
}

#Preview {
  HabitRemindersSheet(
    habit: Habit(
      name: "Morning Meditation",
      description: "Start the day mindfully",
      icon: "🧘",
      color: .purple,
      habitType: .formation,
      schedule: "Everyday",
      goal: "1 time on everyday",
      reminder: "9:00 AM",
      startDate: Date(),
      endDate: nil
    ),
    onUpdate: { _ in }
  )
  .presentationDetents([.large])
  .presentationDragIndicator(.visible)
}
