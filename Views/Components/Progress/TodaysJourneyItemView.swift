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
    HStack(alignment: .top, spacing: 0) {
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

  // MARK: - Time Column (44pt, right-aligned)

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
    .frame(width: 44, alignment: .trailing)
    .padding(.top, 14)
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

  // MARK: - Spine Column (28pt)

  private var spineColumn: some View {
    VStack(spacing: 0) {
      if !isFirst {
        spineLine(isPending: item.status == .pending)
          .frame(minHeight: 18)
      }
      timelineNode
      if !isLast {
        spineLine(isPending: item.status == .pending)
          .frame(minHeight: 18)
      }
    }
    .frame(width: 28)
  }

  private func spineLine(isPending: Bool) -> some View {
    spineLinePath(isPending: isPending)
      .frame(width: 3)
  }

  private func spineLinePath(isPending: Bool) -> some View {
    GeometryReader { geo in
      let h = max(1, geo.size.height)
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
    HStack(alignment: .center, spacing: 12) {
      HabitIconView(habit: item.habit)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 6) {
        Text(item.habit.name)
          .font(.appBodyMedium)
          .foregroundColor(.appText01)
          .lineLimit(2)
          .truncationMode(.tail)

        HStack(spacing: 6) {
          metaBadges
        }
      }

      Spacer(minLength: 0)

      if item.status == .completed {
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 24, height: 24)
          .background(Circle().fill(Color.appSuccess))
      }
    }
    .padding(12)
    .background(cardBackground)
    .overlay(cardBorder)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .opacity(item.status == .pending ? 0.8 : 1)
    .padding(.leading, 8)
    .padding(.top, 8)
    .padding(.bottom, isLast ? 0 : 8)
  }

  @ViewBuilder
  private var cardBackground: some View {
    if item.status == .completed {
      LinearGradient(
        colors: [
          Color.appSuccess.opacity(0.25),
          Color.appSuccess.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else {
      Color.appSurface01
    }
  }

  @ViewBuilder
  private var cardBorder: some View {
    if item.status == .completed {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.appSuccess, lineWidth: 1)
    } else {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.appOutline02, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
    }
  }

  @ViewBuilder
  private var metaBadges: some View {
    if item.status == .completed {
      if let d = item.difficulty {
        difficultyBadge(difficulty: d)
      }
      if item.currentStreak > 0 {
        streakBadge(count: item.currentStreak)
      }
    } else {
      if let _ = estimatedTime {
        timeHintBadge
      }
      if item.isAtRisk {
        atRiskBadge
      } else if item.currentStreak > 0 {
        streakBadge(count: item.currentStreak)
      }
    }
  }

  private func difficultyBadge(difficulty: Int) -> some View {
    let (label, bg) = difficultyLabelAndColor(difficulty)
    return Text(label)
      .font(.appLabelSmall)
      .foregroundColor(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(bg)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func difficultyLabelAndColor(_ d: Int) -> (String, Color) {
    switch d {
    case 1, 2: return ("Very Easy", Color.appSuccess)
    case 3, 4: return ("Easy", Color.appSuccess)
    case 5, 6: return ("Medium", Color.orange)
    case 7, 8: return ("Hard", Color.red)
    case 9, 10: return ("Very Hard", Color.red)
    default: return ("Medium", Color.orange)
    }
  }

  private func streakBadge(count: Int) -> some View {
    let text = count == 1 ? "1 day streak" : "\(count) days streak"
    return HStack(spacing: 2) {
      Text("🔥")
        .font(.system(size: 10))
      Text(text)
        .font(.appLabelSmall)
        .foregroundColor(.white)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.blue)
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var timeHintBadge: some View {
    Text("Est.")
      .font(.appLabelSmall)
      .foregroundColor(.appText05)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.appSurface03)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var atRiskBadge: some View {
    HStack(spacing: 2) {
      Text("⚠️")
        .font(.system(size: 10))
      Text("At risk")
        .font(.appLabelSmall)
        .foregroundColor(.white)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.orange)
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
