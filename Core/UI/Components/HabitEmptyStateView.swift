import SwiftUI

// MARK: - HabitEmptyStateView

struct HabitEmptyStateView: View {
  // MARK: Lifecycle

  init(
    imageName: String,
    title: String,
    subtitle: String,
    imageHeight: CGFloat = 120,
    verticalPadding: CGFloat = 40,
    spacing: CGFloat = 4)
  {
    self.imageName = imageName
    self.title = title
    self.subtitle = subtitle
    self.imageHeight = imageHeight
    self.verticalPadding = verticalPadding
    self.spacing = spacing
  }

  // MARK: Internal

  let imageName: String
  let title: String
  let subtitle: String
  let imageHeight: CGFloat
  let verticalPadding: CGFloat
  let spacing: CGFloat

  var body: some View {
    VStack(spacing: spacing) {
      Image(imageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: imageHeight)

      // Add custom spacing above title
      Spacer()
        .frame(height: 8)

      Text(title)
        .font(.appTitleLargeEmphasised)
        .foregroundColor(.text04)
        .multilineTextAlignment(.center)

      Text(subtitle)
        .font(.appTitleSmall)
        .foregroundColor(.text06)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, verticalPadding)
  }
}

// MARK: - Predefined Empty States

extension HabitEmptyStateView {
  /// Empty state for when no habits exist at all
  static func noHabitsYet() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "Habit-List-Empty-State@4x",
      title: "No habits yet",
      subtitle: "Create your first habit to get started")
  }

  /// Empty state for when no habits are scheduled for today
  static func noHabitsToday() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "Today-Habit-List-Empty-State@4x",
      title: "No habits today",
      subtitle: "Let's relax and enjoy the day!")
  }

  /// Empty state for when no habits are scheduled for a specific date
  static func noHabitsForDate(_ date: Date) -> HabitEmptyStateView {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium

    return HabitEmptyStateView(
      imageName: "Today-Habit-List-Empty-State@4x",
      title: "No habits for \(formatter.string(from: date))",
      subtitle: "Take a break or plan ahead!")
  }

  /// Empty state for when no completed habits exist
  static func noCompletedHabits() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "Habit-List-Empty-State@4x",
      title: "No completed habits",
      subtitle: "Start building your streak today!")
  }

  /// Empty state for when no progress data exists
  static func noProgressData() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "Habit-List-Empty-State@4x",
      title: "No progress data",
      subtitle: "Complete some habits to see your progress")
  }

  /// Empty state for when no search results are found
  static func noSearchResults() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "Habit-List-Empty-State@4x",
      title: "No results found",
      subtitle: "Try adjusting your search terms")
  }

  /// Empty state for coming soon features
  static func comingSoon() -> HabitEmptyStateView {
    HabitEmptyStateView(
      imageName: "comingSoon",
      title: "Coming Soon",
      subtitle: "We're working on this feature")
  }
}

#Preview {
  VStack(spacing: 20) {
    HabitEmptyStateView.noHabitsYet()
    HabitEmptyStateView.noHabitsToday()
    HabitEmptyStateView.noCompletedHabits()
  }
  .padding()
  .background(Color.surface2)
}
