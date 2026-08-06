import SwiftUI

// MARK: - NotificationsView

struct NotificationsView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Main content with save button
        ZStack(alignment: .bottom) {
          ScrollView {
            VStack(spacing: 24) {
              // Habit Reminder Section
              habitReminderSection

              // Plan Reminder Section
              planReminderSection

              // Completion Reminder Section
              completionReminderSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 140) // Extra bottom padding for save button
          }

          // Save button at bottom
          saveButton
        }
      }
      .background(Color("appSurface01Variant02"))
      .navigationTitle("more.notifications.title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .heavy))
              .foregroundColor(.appInverseSurface70)
              .foregroundColor(.text01)
          }
        }
      }
    }
    .onAppear {
      loadReminderSettings()
    }
    .alert("more.notifications.turnOffHabitRemindersTitle".localized, isPresented: $showHabitReminderConfirmation) {
      Button("common.cancel".localized, role: .cancel) {
        // Keep toggle ON - do nothing
      }
      Button("more.notifications.turnOff".localized, role: .destructive) {
        // Confirm turning OFF
        habitReminderEnabled = pendingHabitReminderState
      }
    } message: {
      Text(
        "more.notifications.turnOffHabitRemindersMessage".localized)
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  // Plan Reminder State
  @State private var originalPlanReminderEnabled = true
  @State private var originalPlanReminderTime = Date().settingHour(8).settingMinute(0)
  @State private var planReminderEnabled = true
  @State private var planReminderTime = Date().settingHour(8).settingMinute(0)

  // Completion Reminder State
  @State private var originalCompletionReminderEnabled = true
  @State private var originalCompletionReminderTime = Date().settingHour(20).settingMinute(30)
  @State private var completionReminderEnabled = true
  @State private var completionReminderTime = Date().settingHour(20).settingMinute(30)

  // Habit Reminder State
  @State private var originalHabitReminderEnabled = true
  @State private var habitReminderEnabled = true

  // Alert state for habit reminder confirmation
  @State private var showHabitReminderConfirmation = false
  @State private var pendingHabitReminderState = false

  /// Check if any changes were made
  private var hasChanges: Bool {
    planReminderEnabled != originalPlanReminderEnabled ||
      planReminderTime != originalPlanReminderTime ||
      completionReminderEnabled != originalCompletionReminderEnabled ||
      completionReminderTime != originalCompletionReminderTime ||
      habitReminderEnabled != originalHabitReminderEnabled
  }

  // MARK: - Plan Reminder Section

  private var planReminderSection: some View {
    VStack(spacing: 0) {
      // Options container
      VStack(spacing: 0) {
        // Plan Reminder Toggle
        planReminderToggleRow

        if planReminderEnabled {
          Divider()
            .background(Color(.systemGray4))
            .padding(.leading, 20)

          planReminderTimeRow
        }
      }
      .background(Color("appSurface02Variant"))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
  }

  // MARK: - Habit Reminder Section

  private var habitReminderSection: some View {
    VStack(spacing: 0) {
      // Options container
      VStack(spacing: 0) {
        // Habit Reminder Toggle
        habitReminderToggleRow
      }
      .background(Color("appSurface02Variant"))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
  }

  // MARK: - Completion Reminder Section

  private var completionReminderSection: some View {
    VStack(spacing: 0) {
      // Options container
      VStack(spacing: 0) {
        // Completion Reminder Toggle
        completionReminderToggleRow

        if completionReminderEnabled {
          Divider()
            .background(Color(.systemGray4))
            .padding(.leading, 20)

          completionReminderTimeRow
        }
      }
      .background(Color("appSurface02Variant"))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
  }

  // MARK: - Plan Reminder Toggle Row

  private var planReminderToggleRow: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("more.notifications.planReminder".localized)
          .font(.appTitleMedium)
          .foregroundColor(.text01)

        Text("more.notifications.planReminderSubtitle".localized)
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Toggle("", isOn: $planReminderEnabled)
        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
        .scaleEffect(0.8)
        .padding(.trailing, 0)
        .fixedSize()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .accessibilityLabel("more.notifications.planReminderToggleA11y".localized)
    .accessibilityHint("Enables or disables daily plan reminders")
  }

  // MARK: - Habit Reminder Toggle Row

  private var habitReminderToggleRow: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("more.notifications.habitReminders".localized)
          .font(.appTitleMedium)
          .foregroundColor(.text01)

        Text("more.notifications.habitRemindersSubtitle".localized)
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .fixedSize(horizontal: false, vertical: true)

        if habitReminderEnabled {
          Text(
            "💡 Add reminders to individual habits in their detail screens to receive notifications.")
            .font(.appBodySmall)
            .foregroundColor(.text05)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Toggle("", isOn: Binding(
        get: { habitReminderEnabled },
        set: { newValue in
          if !newValue, habitReminderEnabled {
            // User is trying to turn OFF - show confirmation
            pendingHabitReminderState = newValue
            showHabitReminderConfirmation = true
          } else {
            // User is turning ON - allow immediately
            habitReminderEnabled = newValue
          }
        }))
        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
        .scaleEffect(0.8)
        .padding(.trailing, 0)
        .fixedSize()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .accessibilityLabel("more.notifications.habitRemindersToggleA11y".localized)
    .accessibilityHint("Enables or disables individual habit reminders")
  }

  // MARK: - Plan Reminder Time Row

  private var planReminderTimeRow: some View {
    HStack(spacing: 16) {
      Text("more.notifications.reminderTime".localized)
        .font(.appTitleMedium)
        .foregroundColor(.text01)

      Spacer()

      DatePicker(
        "",
        selection: $planReminderTime,
        displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
        .labelsHidden()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .accessibilityLabel("more.notifications.planReminderTimeA11y".localized)
    .accessibilityHint("Set the time for daily plan reminders")
  }

  // MARK: - Completion Reminder Toggle Row

  private var completionReminderToggleRow: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("more.notifications.completionReminder".localized)
          .font(.appTitleMedium)
          .foregroundColor(.text01)

        Text("more.notifications.completionReminderSubtitle".localized)
          .font(.appBodyMedium)
          .foregroundColor(.text04)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Toggle("", isOn: $completionReminderEnabled)
        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
        .scaleEffect(0.8)
        .padding(.trailing, 0)
        .fixedSize()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .accessibilityLabel("more.notifications.completionReminderToggleA11y".localized)
    .accessibilityHint("Enables or disables daily completion reminders")
  }

  // MARK: - Completion Reminder Time Row

  private var completionReminderTimeRow: some View {
    HStack(spacing: 16) {
      Text("more.notifications.reminderTime".localized)
        .font(.appTitleMedium)
        .foregroundColor(.text01)

      Spacer()

      DatePicker(
        "",
        selection: $completionReminderTime,
        displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
        .labelsHidden()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .accessibilityLabel("more.notifications.completionReminderTimeA11y".localized)
    .accessibilityHint("Set the time for daily completion reminders")
  }

  // MARK: - Save Button

  private var saveButton: some View {
    HStack {
      HabittoButton.largeFillPrimary(
        text: "common.save".localized,
        state: hasChanges ? .default : .disabled,
        action: saveChanges)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 40)
  }

  // MARK: - Debug Helper

  private func printPendingNotificationsCount() async {
    let center = UNUserNotificationCenter.current()
    let requests = await center.pendingNotificationRequests()

    let habitReminders = requests.filter { $0.identifier.contains("habit_reminder_") }
    let planReminders = requests.filter { $0.identifier.contains("plan_reminder") }
    let completionReminders = requests.filter { $0.identifier.contains("completion_reminder") }

    print("\n📊 PENDING NOTIFICATIONS STATUS:")
    print("   🔔 Habit reminders: \(habitReminders.count)")
    print("   📋 Plan reminders: \(planReminders.count)")
    print("   ✅ Completion reminders: \(completionReminders.count)")
    print("   📱 Total pending: \(requests.count)\n")
  }

  // MARK: - Save Action

  private func saveChanges() {

    // Log what changed
    if planReminderEnabled != originalPlanReminderEnabled {
      print(
        "📋 Plan Reminder: \(originalPlanReminderEnabled ? "ON" : "OFF") → \(planReminderEnabled ? "ON ✅" : "OFF 🔇")")
    }
    if completionReminderEnabled != originalCompletionReminderEnabled {
      print(
        "✅ Completion Reminder: \(originalCompletionReminderEnabled ? "ON" : "OFF") → \(completionReminderEnabled ? "ON ✅" : "OFF 🔇")")
    }
    if habitReminderEnabled != originalHabitReminderEnabled {
      print(
        "🔔 Habit Reminders: \(originalHabitReminderEnabled ? "ON" : "OFF") → \(habitReminderEnabled ? "ON ✅" : "OFF 🔇")")
    }
    if planReminderTime != originalPlanReminderTime {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      print(
        "⏰ Plan Reminder Time: \(formatter.string(from: originalPlanReminderTime)) → \(formatter.string(from: planReminderTime))")
    }
    if completionReminderTime != originalCompletionReminderTime {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      print(
        "⏰ Completion Reminder Time: \(formatter.string(from: originalCompletionReminderTime)) → \(formatter.string(from: completionReminderTime))")
    }

    // Update original values to reflect the new saved state
    originalPlanReminderEnabled = planReminderEnabled
    originalPlanReminderTime = planReminderTime
    originalCompletionReminderEnabled = completionReminderEnabled
    originalCompletionReminderTime = completionReminderTime
    originalHabitReminderEnabled = habitReminderEnabled

    // Save to UserDefaults
    print("\n💾 Saving preferences to UserDefaults...")
    UserDefaults.standard.set(planReminderEnabled, forKey: "planReminderEnabled")
    UserDefaults.standard.set(completionReminderEnabled, forKey: "completionReminderEnabled")
    UserDefaults.standard.set(habitReminderEnabled, forKey: "habitReminderEnabled")
    UserDefaults.standard.set(planReminderTime, forKey: "planReminderTime")
    UserDefaults.standard.set(completionReminderTime, forKey: "completionReminderTime")
    print("✅ Preferences saved successfully\n")

    // Schedule daily reminders based on new settings
    Task { @MainActor in
      print("\n" + String(repeating: "-", count: 60))
      print("🔄 RESCHEDULING: Starting notification updates...")
      print(String(repeating: "-", count: 60))

      print("\n1️⃣ Rescheduling daily reminders (plan & completion)...")
      NotificationManager.shared.rescheduleDailyReminders()
      print("   ✅ Daily reminders updated\n")

      // Handle habit reminders enable/disable
      if habitReminderEnabled != originalHabitReminderEnabled {
        if habitReminderEnabled {
          // Habit reminders were just ENABLED - reschedule all existing habits
          print("2️⃣ 🔔 Habit reminders ENABLED - scheduling all habit notifications...")
          NotificationManager.shared.rescheduleAllHabitReminders()
          print("   ✅ All habit notifications scheduled\n")
        } else {
          // Habit reminders were just DISABLED - remove all habit notifications
          print("2️⃣ 🔇 Habit reminders DISABLED - removing all habit notifications...")
          NotificationManager.shared.removeAllHabitReminders()

          // Wait a moment for removal to complete, then verify
          try? await Task.sleep(nanoseconds: 500_000_000)
          await printPendingNotificationsCount()
          print("   ✅ All habit notifications removed\n")
        }
      }

      print(String(repeating: "=", count: 60))
      print("✅ NOTIFICATION SETTINGS: All changes applied successfully!")
      print(String(repeating: "=", count: 60) + "\n")
    }

    // Dismiss the view
    dismiss()
  }

  // MARK: - Data Persistence

  private func loadReminderSettings() {
    print("\n" + String(repeating: "=", count: 60))
    print("📥 NOTIFICATION SETTINGS: Loading preferences from UserDefaults")
    print(String(repeating: "=", count: 60))

    // Default to true if key doesn't exist (first time)
    let planEnabled = UserDefaults.standard.object(forKey: "planReminderEnabled") as? Bool ?? true
    let completionEnabled = UserDefaults.standard.object(forKey: "completionReminderEnabled") as? Bool ?? true
    let habitEnabled = UserDefaults.standard.object(forKey: "habitReminderEnabled") as? Bool ?? true

    print("📋 Plan Reminder: \(planEnabled ? "ON ✅" : "OFF 🔇")")
    print("✅ Completion Reminder: \(completionEnabled ? "ON ✅" : "OFF 🔇")")
    print("🔔 Habit Reminders: \(habitEnabled ? "ON ✅" : "OFF 🔇")")

    // Set both original and current values
    originalPlanReminderEnabled = planEnabled
    planReminderEnabled = planEnabled

    originalCompletionReminderEnabled = completionEnabled
    completionReminderEnabled = completionEnabled

    originalHabitReminderEnabled = habitEnabled
    habitReminderEnabled = habitEnabled

    // Load times
    if let planTime = UserDefaults.standard.object(forKey: "planReminderTime") as? Date {
      originalPlanReminderTime = planTime
      planReminderTime = planTime
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      print("⏰ Plan Reminder Time: \(formatter.string(from: planTime))")
    }
    if let completionTime = UserDefaults.standard
      .object(forKey: "completionReminderTime") as? Date
    {
      originalCompletionReminderTime = completionTime
      completionReminderTime = completionTime
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      print("⏰ Completion Reminder Time: \(formatter.string(from: completionTime))")
    }

    print(String(repeating: "=", count: 60) + "\n")

    // Also check current pending notifications
    Task {
      await printPendingNotificationsCount()
    }
  }
}

// MARK: - Date Extensions

extension Date {
  func settingHour(_ hour: Int) -> Date {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: self)
    components.hour = hour
    components.minute = 0
    components.second = 0
    return calendar.date(from: components) ?? self
  }

  func settingMinute(_ minute: Int) -> Date {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
    components.minute = minute
    components.second = 0
    return calendar.date(from: components) ?? self
  }
}

#Preview {
  NotificationsView()
}
