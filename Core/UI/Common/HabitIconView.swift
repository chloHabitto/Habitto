import SwiftUI

struct HabitIconView: View {
  let habit: Habit

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(habit.color.color.opacity(0.15))
        .frame(width: 30, height: 30)

      if habit.icon.hasPrefix("Icon-") {
        // Asset icon
        Image(habit.icon)
          .resizable()
          .frame(width: 14, height: 14)
          .foregroundColor(habit.color.color)
      } else if habit.icon == "None" {
        // No icon selected - show colored rounded rectangle
        RoundedRectangle(cornerRadius: 4)
          .fill(habit.color.color)
          .frame(width: 14, height: 14)
      } else {
        // Emoji or system icon
        Text(habit.icon)
          .font(.system(size: 14))
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 12)
  }
}

#Preview {
  VStack(spacing: 16) {
    HabitIconView(
      habit: Habit(
        name: "Exercise",
        description: "Daily workout",
        icon: "🏃‍♂️",
        color: .blue,
        habitType: .formation,
        schedule: "Daily",
        goal: "30 minutes",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil))

    HabitIconView(
      habit: Habit(
        name: "Read",
        description: "Daily reading",
        icon: "Icon-book-filled",
        color: .green,
        habitType: .formation,
        schedule: "Daily",
        goal: "20 pages",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil))

    HabitIconView(
      habit: Habit(
        name: "Drink Water",
        description: "Stay hydrated",
        icon: "None",
        color: .orange,
        habitType: .formation,
        schedule: "Daily",
        goal: "8 glasses",
        reminder: "No reminder",
        startDate: Date(),
        endDate: nil))
  }
  .padding()
  .background(.surface2)
}
