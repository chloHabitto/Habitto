import SwiftUI

struct HabitIconView: View {
  let habit: Habit
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(iconBackgroundColor)
        .frame(width: 40, height: 40)

      if habit.icon.hasPrefix("Icon-") {
        // Asset icon - brighter in dark mode
        Image(habit.icon)
          .resizable()
          .frame(width: 18, height: 18)
          .foregroundColor(iconColor)
      } else if habit.icon == "None" {
        // No icon selected - show colored rounded rectangle - brighter in dark mode
        RoundedRectangle(cornerRadius: 4)
          .fill(iconColor)
          .frame(width: 18, height: 18)
      } else {
        // Emoji or system icon
        Text(habit.icon)
          .font(.system(size: 18))
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 12)
  }
  
  private var iconBackgroundColor: Color {
    // Using appOutline02 color for icon background
    return .outline02
    
    // Previous implementation - commented out for potential reversion:
    // In dark mode, use a much lighter version of the habit color
    // if colorScheme == .dark {
    //   return lightenColor(habit.color.color, by: 0.4).opacity(0.25)
    // } else {
    //   // In light mode, use the original color with 15% opacity
    //   return habit.color.color.opacity(0.15)
    // }
  }
  
  private var iconColor: Color {
    // Make icon color brighter in dark mode
    if colorScheme == .dark {
      return lightenColor(habit.color.color, by: 0.3)
    } else {
      return habit.color.color
    }
  }
  
  private func lightenColor(_ color: Color, by amount: CGFloat) -> Color {
    let uiColor = UIColor(color)
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    
    if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
      // Increase brightness while maintaining hue and saturation
      let newBrightness = min(1.0, brightness + amount)
      return Color(hue: hue, saturation: saturation, brightness: newBrightness, opacity: alpha)
    } else {
      // If color space conversion fails, return original color
      return color
    }
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
