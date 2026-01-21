import MijickPopups
import SwiftUI

struct AllRemindersPopup: View {
  // MARK: Internal

  let selectedDate: Date
  let reminders: [ProgressTabView.ReminderWithHabit]
  let isReminderEnabled: (ReminderItem, Date) -> Bool
  let isReminderTimePassed: (ReminderItem, Date) -> Bool
  let toggleReminder: (ReminderItem, Date) -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("All Reminders")
          .font(.appTitleMediumEmphasised)
          .foregroundColor(.onPrimaryContainer)

        Spacer()

        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .black))
            .foregroundColor(.navy200)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 24)

      // Reminders list
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(reminders, id: \.id) { reminder in
            reminderCard(for: reminder)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
  }

  // MARK: Private

  // MARK: - Helper Functions

  private func reminderCard(for reminderWithHabit: ProgressTabView.ReminderWithHabit) -> some View {
    let isEnabled = isReminderEnabled(reminderWithHabit.reminder, selectedDate)
    let isTimePassed = isReminderTimePassed(reminderWithHabit.reminder, selectedDate)

    return HStack(spacing: 12) {
      // Habit Icon
      HabitIconView(habit: reminderWithHabit.habit)
        .frame(width: 40, height: 40)

      // Habit Name and Time
      VStack(alignment: .leading, spacing: 4) {
        Text(reminderWithHabit.habit.name)
          .font(.appBodyMedium)
          .foregroundColor(.onPrimaryContainer)
          .lineLimit(1)

        Text(formatReminderTime(reminderWithHabit.reminder.time))
          .font(.appBodySmall)
          .foregroundColor(.text02)
      }

      Spacer()

      // Toggle Button
      Toggle("", isOn: Binding(
        get: { isEnabled },
        set: { _ in
          if !isTimePassed {
            toggleReminder(reminderWithHabit.reminder, selectedDate)
          }
        }))
        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
        .scaleEffect(0.8)
        .disabled(isTimePassed)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.surface)
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color.outline3, lineWidth: 1)))
    .opacity(isTimePassed ? 0.6 : 1.0)
  }

  private func formatReminderTime(_ time: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: time)
  }
}

// MARK: - Supporting Types

// Note: ReminderWithHabit struct is defined in ProgressTabView.swift
