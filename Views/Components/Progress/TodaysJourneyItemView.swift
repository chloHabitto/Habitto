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
    HStack(alignment: .top, spacing: 12) {
      timeColumn
      spineColumn
      cardColumn
    }
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
        .foregroundColor(item.status == .completed ? .appText03 : .appText05)
      if !timeLine2.isEmpty {
        Text(timeLine2)
          .font(.appLabelSmall)
          .foregroundColor(item.status == .completed ? .appText03 : .appText05)
      }
    }
    .frame(width: 45, alignment: .trailing)
    .padding(.top, 16)
  }

  private var timeLine1: String {
    switch item.status {
    case .completed:
      guard let t = item.completionTime else { return "—" }
      return Self.timeFormatter.string(from: t)
    case .pending:
      guard let t = estimatedTime else { return "—" }
      return "~" + Self.timeFormatter.string(from: t)
    }
  }

  private var timeLine2: String {
    switch item.status {
    case .completed:
      guard let t = item.completionTime else { return "" }
      return Self.amPmFormatter.string(from: t)
    case .pending:
      guard let t = estimatedTime else { return "" }
      return Self.amPmFormatter.string(from: t)
    }
  }

  // MARK: - Spine Column (24pt) - matches TimelineEntryRow connectorColumn

  private var spineColumn: some View {
    VStack(spacing: 0) {
      if !isFirst {
        spineLine(isPending: item.status == .pending)
      }
      timelineNode
        .padding(.top, 18) // Match TimelineEntryRow dot positioning
      if !isLast {
        spineLine(isPending: item.status == .pending)
      }
    }
    .frame(width: 24)
  }

  private func spineLine(isPending: Bool) -> some View {
    spineLinePath(isPending: isPending)
      .frame(width: 3)
      .frame(minHeight: 24) // Minimum height to extend through card padding
  }

  private func spineLinePath(isPending: Bool) -> some View {
    GeometryReader { geo in
      let h = max(24, geo.size.height) // Ensure minimum height of 24
      Group {
        if isPending {
          Path { p in
            p.move(to: CGPoint(x: 1.5, y: 0))
            p.addLine(to: CGPoint(x: 1.5, y: h))
          }
          .stroke(
            Color.appOutline02,
            style: StrokeStyle(lineWidth: 3, dash: [6, 4])
          )
        } else {
          Rectangle()
            .fill(Color.appPrimary)
            .frame(width: 3, height: h)
        }
      }
      .frame(width: 3, height: h)
    }
    .frame(width: 3)
  }

  private var timelineNode: some View {
    let isCompleted = item.status == .completed
    return Circle()
      .fill(isCompleted ? Color.appPrimary : Color.white)
      .frame(width: 14, height: 14)
      .overlay(
        Circle()
          .stroke(Color.appOutline02, lineWidth: isCompleted ? 0 : 2.5)
      )
      .shadow(
        color: isCompleted ? Color.appPrimary.opacity(0.5) : .clear,
        radius: 3
      )
  }

  // MARK: - Card Column

  private var cardColumn: some View {
    HStack(alignment: .top, spacing: 12) {
      HabitIconView(habit: item.habit)
        .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 8) {
        // Header row
        HStack {
          Text(item.habit.name)
            .font(.appLabelLargeEmphasised)
            .foregroundColor(.appText01)
            .lineLimit(2)
            .truncationMode(.tail)
          
          Spacer()
          
          // Status icon (checkmark when completed)
          if item.status == .completed {
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 24, height: 24)
              .background(Circle().fill(Color.green))
          }
        }
        
        // Meta row with difficulty badge
        VStack(alignment: .leading, spacing: 4) {
          if item.status == .completed {
            if let difficulty = item.difficulty {
              DifficultyBadge(difficulty: difficulty)
            }
          } else {
            // Pending state - show streak badges
            HStack(spacing: 6) {
              metaBadges
            }
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.appSurface4)
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.appOutline02, lineWidth: 1)
    )
    .opacity(item.status == .pending ? 0.8 : 1)
    .padding(.top, 16) // Match TimelineEntryRow entryCard top padding
    .padding(.bottom, isLast ? 0 : 12) // Match TimelineEntryRow entryCard bottom padding
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
        status: .pending,
        completionTime: nil,
        difficulty: nil,
        currentStreak: 3,
        isAtRisk: true
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
