import SwiftUI

struct AddedHabitItem: View {
  // MARK: Lifecycle

  init(
    habit: Habit,
    isEditMode: Bool = false,
    onEdit: (() -> Void)? = nil,
    onDelete: (() -> Void)? = nil,
    onTap: (() -> Void)? = nil,
    onLongPress: (() -> Void)? = nil)
  {
    self.habit = habit
    self.isEditMode = isEditMode
    self.onEdit = onEdit
    self.onDelete = onDelete
    self.onTap = onTap
    self.onLongPress = onLongPress
  }

  // MARK: Internal

  let habit: Habit
  let isEditMode: Bool
  let onEdit: (() -> Void)?
  let onDelete: (() -> Void)?
  let onTap: (() -> Void)?
  let onLongPress: (() -> Void)?

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // ColorMark
      Rectangle()
        .fill(habit.color.color)
        .frame(width: 8)
        .frame(maxHeight: .infinity)

      // SelectedIcon
      HabitIconView(habit: habit)
        .padding(.top, 8)

      // VStack with title, description, and bottom row
      VStack(spacing: 8) {
        // Top row: Text container and more button
        HStack(spacing: 4) {
          // Text container - tappable area
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(habit.name)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.text02)
                .lineLimit(1)
                .truncationMode(.tail)

              reminderIcon
            }

            Text(habit.description.isEmpty ? "No description" : habit.description)
              .font(.appBodyExtraSmall)
              .foregroundColor(.text05)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
          .contentShape(Rectangle())
          .simultaneousGesture(
            TapGesture(count: 1)
              .onEnded {
                onTap?()
              })
          .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
              .onEnded { _ in
                print("🔍 AddedHabitItem: Long press gesture triggered for habit: \(habit.name)")
                onLongPress?()
              })

          // More button (hidden in edit mode to show native List drag handle)
          if !isEditMode {
            Menu {
              Button(action: {
                onEdit?()
              }) {
                Label("Edit", systemImage: "pencil")
              }

              Button(role: .destructive, action: {
                onDelete?()
              }) {
                Label("Delete", systemImage: "trash")
              }
            } label: {
              Image(.iconMoreVert)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.text05)
                .contentShape(Rectangle())
            }
            .frame(width: 40, height: 40)
          }
        }

        // Bottom row: Goal only
        HStack(spacing: 4) {
          // Goal
          HStack(spacing: 4) {
            Image(.iconFlagFilled)
              .resizable()
              .renderingMode(.template)
              .frame(width: 16, height: 16)
              .foregroundColor(.text05)

            Text(habit.goal)
              .font(.appBodyExtraSmall)
              .foregroundColor(.text05)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
      .padding(.bottom, 14)
    }
    .background(.surface)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(.outline3, lineWidth: 2))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .contentShape(Rectangle())
  }

  // MARK: Private

  /// Computed property to check if habit has reminders
  private var hasReminders: Bool {
    !habit.reminders.isEmpty
  }

  /// Computed property to check if all reminders for today are completed
  private var areRemindersCompleted: Bool {
    guard hasReminders else { return false }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
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

  /// Helper function to format schedule for display
  private func formatScheduleForDisplay(_ schedule: String) -> String {
    switch schedule {
    case "Everyday":
      "Daily"
    case "Weekdays":
      "Weekdays"
    case "Weekends":
      "Weekends"
    case "Friday",
         "Monday",
         "Saturday",
         "Sunday",
         "Thursday",
         "Tuesday",
         "Wednesday":
      "Every \(schedule)"
    case let s where s.contains("times a week"):
      s // Keep as is for now
    case let s where s.contains("times a month"):
      s // Keep as is for now
    case let s where s.hasPrefix("Every ") && s.contains("days"):
      s // Keep as is for now
    default:
      schedule
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    AddedHabitItem(
      habit: Habit(
        name: "Morning Exercise",
        description: "Start the day with a quick workout",
        icon: "🏃‍♂️",
        color: .blue,
        habitType: .formation,
        schedule: "Daily",
        goal: "30 minutes",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil),
      onEdit: {
        print("Edit tapped")
      },
      onDelete: {
        print("Delete tapped")
      },
      onLongPress: {
        print("Long press detected")
      })

    AddedHabitItem(
      habit: Habit(
        name: "Read Books",
        description: "Read at least one chapter every day",
        icon: "📚",
        color: .green,
        habitType: .formation,
        schedule: "Weekdays",
        goal: "1 chapter",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil),
      onEdit: {
        print("Edit tapped")
      },
      onDelete: {
        print("Delete tapped")
      },
      onLongPress: {
        print("Long press detected")
      })
  }
  .padding()
  .background(.surface)
}
