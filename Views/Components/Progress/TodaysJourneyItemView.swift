//
//  TodaysJourneyItemView.swift
//  Habitto
//
//  Single timeline item for "Today's Journey" – time, spine, habit card.
//

import SwiftUI

struct TodaysJourneyItemView: View {
  let item: JourneyHabitItem
  let index: Int
  let isFirst: Bool
  let isLast: Bool
  /// Estimated completion time for pending items. Nil when no estimate; shown as "—".
  var estimatedTime: Date? = nil

  @State private var hasAppeared = false

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return f
  }()

  private static let amPmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "a"
    return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      timeColumn
      spineColumn
      cardColumn
    }
    .padding(.top, isFirst ? 16 : 0) // Only first item needs top padding; others connect via line above
    .opacity(hasAppeared ? 1 : 0)
    .offset(y: hasAppeared ? 0 : 20)
    .animation(
      .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05),
      value: hasAppeared
    )
    .onAppear { hasAppeared = true }
  }

  // MARK: - Time Column (45pt, right-aligned) - matches TimelineEntryRow

  private var timeColumn: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(timeLine1)
        .font(.appLabelSmall)
        .foregroundColor(item.status == .completed ? .appText02 : .appText05)
      if !timeLine2.isEmpty {
        Text(timeLine2)
          .font(.appLabelSmall)
          .foregroundColor(item.status == .completed ? .appText04 : .appText05)
      }
    }
    .frame(width: 45, alignment: .trailing)
    .padding(.top, isFirst ? 0 : 16) // Align with dot position (line above is 16pt)
  }

  private var timeLine1: String {
    switch item.status {
    case .completed:
      guard let t = item.completionTime else { return "—" }
      return Self.timeFormatter.string(from: t)
    case .inProgress, .pending:
      guard let t = estimatedTime else { return "—" }
      // Only show estimated time if it's still in the future
      let now = Date()
      if t > now {
        return "~" + Self.timeFormatter.string(from: t)
      } else {
        return "—"
      }
    }
  }

  private var timeLine2: String {
    switch item.status {
    case .completed:
      guard let t = item.completionTime else { return "" }
      return Self.amPmFormatter.string(from: t)
    case .inProgress, .pending:
      guard let t = estimatedTime else { return "" }
      // Only show AM/PM if estimated time is still in the future
      let now = Date()
      if t > now {
        return Self.amPmFormatter.string(from: t)
      } else {
        return ""
      }
    }
  }

  // MARK: - Spine Column (24pt) - two-segment approach for connected lines

  private var spineColumn: some View {
    VStack(spacing: 0) {
      // Line ABOVE the dot - connects to previous item
      // Hidden for first item
      if !isFirst {
        lineSegment(position: .above)
          .frame(height: 16) // Matches the row's top padding
      }
      
      // The dot
      timelineNode
      
      // Line BELOW the dot - connects to next item
      // Hidden for last item
      if !isLast {
        lineSegment(position: .below)
      }
    }
    .frame(width: 24)
    .frame(maxHeight: .infinity, alignment: .top) // CRITICAL: Expand to fill row height
  }

  private enum LinePosition {
    case above, below
  }

  private func lineSegment(position: LinePosition) -> some View {
    let isPending = item.status == .pending || item.status == .inProgress
    let lineColor = isPending ? Color.appOutline02 : Color.appPrimaryOpacity10
    
    return GeometryReader { geo in
      if isPending {
        // Dashed line for pending items
        Path { path in
          path.move(to: CGPoint(x: 1.5, y: 0))
          path.addLine(to: CGPoint(x: 1.5, y: geo.size.height))
        }
        .stroke(lineColor, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
      } else {
        // Solid line for completed items
        Rectangle()
          .fill(lineColor)
          .frame(width: 3, height: geo.size.height)
      }
    }
    .frame(width: 3)
    // No .frame(maxHeight: .infinity) here - parent VStack handles expansion
  }

  private var timelineNode: some View {
    let isCompleted = item.status == .completed
    return Circle()
      .fill(isCompleted ? Color.appPrimaryContainerFocus : Color.white)
      .frame(width: 12, height: 12)
      .overlay(
        Circle()
          .stroke(isCompleted ? Color.clear : Color.appOutline02, lineWidth: 2.5)
      )
      .shadow(
        color: isCompleted ? Color.appPrimary.opacity(0.3) : .clear,
        radius: 2,
        y: 1
      )
  }

  // MARK: - Card Column

  private var cardColumn: some View {
    HStack(alignment: .top, spacing: 12) {
      HabitIconView(habit: item.habit)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.habit.name)
          .font(.appLabelLargeEmphasised)
          .foregroundColor(.appText01)
          .lineLimit(2)
          .truncationMode(.tail)
        
        switch item.status {
        case .completed:
          if let difficulty = item.difficulty {
            DifficultyBadge(difficulty: difficulty)
          }
        case .inProgress, .pending:
          // Both show progress content
          progressContent
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      // Checkmark ONLY for completed
      if item.status == .completed {
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 24, height: 24)
          .background(Circle().fill(Color.green))
      }
    }
    .padding(.top, 12)
    .padding(.leading, 12)
    .padding(.trailing, 12)
    .padding(.bottom, 16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.appSurface01Variant)
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.appOutline1Variant, lineWidth: 1)
    )
    .opacity(item.status == .completed ? 1 : 0.8)  // Both pending and inProgress get reduced opacity
    .padding(.top, isFirst ? 0 : 16)
  }
  
  @ViewBuilder
  private var progressContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Progress text
      Text("Progress: \(todayProgress)/\(goalAmount)")
        .font(.appLabelSmall)
        .foregroundColor(.appText05)
      
      // Progress bar
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.appOutline02)
            .frame(height: 6)
          
          RoundedRectangle(cornerRadius: 6)
            .fill(item.habit.color.color)
            .frame(width: geo.size.width * progressPercentage, height: 6)
        }
      }
      .frame(height: 6)
    }
  }
  
  private var todayProgress: Int {
    let dateKey = DateUtils.dateKey(for: Date())
    return item.habit.completionHistory[dateKey] ?? 0
  }
  
  private var goalAmount: Int {
    // Parse the goal string to extract the numeric value
    let goalString = item.habit.goal
    if let number = Int(goalString) {
      return number
    }
    // Try to extract number from strings like "1 session", "20 pages", etc.
    let components = goalString.split(separator: " ")
    if let firstComponent = components.first, let number = Int(firstComponent) {
      return number
    }
    return 1 // Default to 1 if parsing fails
  }
  
  private var progressPercentage: Double {
    let goal = Double(goalAmount)
    let progress = Double(todayProgress)
    return goal > 0 ? min(progress / goal, 1.0) : 0
  }

  @ViewBuilder
  private var metaBadges: some View {
    // Pending state - simpler badges
    if item.currentStreak > 0 {
      if item.isAtRisk {
        // Gentler "protect streak" badge
        protectStreakBadge(count: item.currentStreak)
      } else {
        streakBadge(count: item.currentStreak)
      }
    }
    // No badge if streak is 0 - keep it clean
  }

  private func streakBadge(count: Int) -> some View {
    HStack(spacing: 3) {
      Text("🔥")
        .font(.system(size: 10))
      Text("\(count)d")
        .font(.appLabelSmall)
        .foregroundColor(.white)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.appPrimary)
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func protectStreakBadge(count: Int) -> some View {
    HStack(spacing: 3) {
      Text("🔥")
        .font(.system(size: 10))
      Text("\(count)d")
        .font(.appLabelSmall)
        .foregroundColor(.appText01)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.orange.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

// MARK: - Preview

#Preview {
  let habit1 = Habit(
    name: "Morning meditation",
    description: "Daily practice",
    icon: "🧘",
    color: .purple,
    habitType: .formation,
    schedule: "Daily",
    goal: "1 session",
    reminder: "None",
    startDate: Date(),
    endDate: nil
  )
  let habit2 = Habit(
    name: "Evening reading",
    description: "Read daily",
    icon: "📚",
    color: .blue,
    habitType: .formation,
    schedule: "Daily",
    goal: "20 pages",
    reminder: "None",
    startDate: Date(),
    endDate: nil
  )
  return VStack(spacing: 0) {
    TodaysJourneyItemView(
      item: JourneyHabitItem(
        id: habit1.id,
        habit: habit1,
        status: .completed,
        completionTime: Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: Date()),
        difficulty: 2,
        currentStreak: 5,
        isAtRisk: false
      ),
      index: 0,
      isFirst: false,
      isLast: false,
      estimatedTime: nil
    )
    TodaysJourneyItemView(
      item: JourneyHabitItem(
        id: habit2.id,
        habit: habit2,
        status: .inProgress,
        completionTime: nil,
        difficulty: nil,
        currentStreak: 3,
        isAtRisk: false
      ),
      index: 1,
      isFirst: false,
      isLast: true,
      estimatedTime: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())
    )
  }
  .padding()
  .background(Color.appSurface01)
}
