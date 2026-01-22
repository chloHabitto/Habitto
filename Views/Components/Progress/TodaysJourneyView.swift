//
//  TodaysJourneyView.swift
//  Habitto
//
//  Main container for "Today's Journey" timeline on the Progress tab.
//  Shows when "All habits" + "Daily" are selected, below the Today's Progress Card.
//

import SwiftUI

struct TodaysJourneyView: View {
  let habits: [Habit]
  let selectedDate: Date

  @State private var journeyItems: [JourneyHabitItem] = []
  @State private var isAnimating = false
  @State private var breathingPhase = false

  private var scheduledHabits: [Habit] {
    habits.filter { StreakDataCalculator.shouldShowHabitOnDate($0, date: selectedDate) }
  }

  private var completedItems: [JourneyHabitItem] {
    journeyItems
      .filter { $0.status == .completed }
      .sorted { (a, b) in
        let t1 = a.completionTime ?? .distantPast
        let t2 = b.completionTime ?? .distantPast
        return t1 < t2
      }
  }

  private var pendingItems: [JourneyHabitItem] {
    journeyItems
      .filter { $0.status == .pending }
      .sorted { (a, b) in
        let e1 = TodaysJourneyHelpers.getEstimatedCompletionTime(for: a.habit, targetDate: selectedDate)
        let e2 = TodaysJourneyHelpers.getEstimatedCompletionTime(for: b.habit, targetDate: selectedDate)
        if let e1, let e2 { return e1 < e2 }
        if e1 != nil { return true }
        if e2 != nil { return false }
        return a.habit.name.localizedCaseInsensitiveCompare(b.habit.name) == .orderedAscending
      }
  }

  private var shouldShowNowMarker: Bool {
    let calendar = Calendar.current
    let isToday = calendar.isDate(selectedDate, inSameDayAs: Date())
    return isToday && !pendingItems.isEmpty
  }

  private var completedCount: Int {
    journeyItems.filter { $0.status == .completed }.count
  }

  private var totalCount: Int {
    journeyItems.count
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      if journeyItems.isEmpty {
        emptyState
      } else if completedCount == totalCount {
        completeState
      } else {
        timelineContent
      }
    }
    .background(Color.appSurface01)
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .stroke(Color.appOutline1Variant, lineWidth: 1)
    )
    .onAppear { loadJourneyItems() }
    .onChange(of: selectedDate) { _, _ in loadJourneyItems() }
    .onChange(of: habits.count) { _, _ in loadJourneyItems() }
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Text("Today's Journey")
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.appText01)

      Spacer()

      Text("\(completedCount) of \(totalCount)")
        .font(.appLabelMedium)
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appPrimaryContainer)
        .clipShape(Capsule())
    }
    .padding(.horizontal, 20)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Text("☀️")
        .font(.system(size: 48))

      Text("Your day awaits!")
        .font(.appTitleMediumEmphasised)
        .foregroundColor(.appText01)

      Text("No habits scheduled for today")
        .font(.appBodySmall)
        .foregroundColor(.appText03)

      HStack(spacing: 16) {
        ForEach(0 ..< 5, id: \.self) { index in
          Circle()
            .stroke(Color.appOutline02, lineWidth: 2)
            .frame(width: 12, height: 12)
            .opacity(breathingOpacity(for: index))
            .animation(
              .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.15),
              value: breathingPhase
            )
        }
      }
      .padding(.top, 8)
    }
    .padding(.vertical, 40)
    .onAppear {
      withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
        breathingPhase = true
      }
    }
  }

  // MARK: - Complete State

  private var completeState: some View {
    VStack(spacing: 16) {
      Text("🏆")
        .font(.system(size: 56))
        .modifier(BounceAnimation())

      Text("Perfect day!")
        .font(.appTitleLargeEmphasised)
        .foregroundColor(.appText01)

      Text("You completed all your habits")
        .font(.appBodySmall)
        .foregroundColor(.appText03)

      HStack(spacing: 6) {
        Text("⭐")
        Text("+50 XP earned")
          .font(.appLabelMediumEmphasised)
      }
      .foregroundColor(Color(red: 0.45, green: 0.26, blue: 0.06))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        LinearGradient(
          colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.7)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(Capsule())

      HStack(spacing: 0) {
        ForEach(0 ..< totalCount, id: \.self) { index in
          Circle()
            .fill(Color.appSuccess)
            .frame(width: 12, height: 12)

          if index < totalCount - 1 {
            Rectangle()
              .fill(Color.appSuccess)
              .frame(width: 20, height: 3)
          }
        }
      }
      .padding(.top, 8)
    }
    .padding(.vertical, 40)
  }

  private func breathingOpacity(for index: Int) -> Double {
    breathingPhase ? 0.9 : 0.35
  }

  // MARK: - Timeline Content

  private var timelineContent: some View {
    VStack(spacing: 0) {
      ForEach(Array(completedItems.enumerated()), id: \.element.id) { index, item in
        TodaysJourneyItemView(
          item: item,
          index: index,
          isFirst: index == 0,
          isLast: index == completedItems.count - 1 && !shouldShowNowMarker,
          estimatedTime: nil
        )
      }

      if shouldShowNowMarker {
        TodaysJourneyNowMarker()
      }

      ForEach(Array(pendingItems.enumerated()), id: \.element.id) { index, item in
        TodaysJourneyItemView(
          item: item,
          index: completedItems.count + 1 + index,
          isFirst: false,
          isLast: index == pendingItems.count - 1,
          estimatedTime: TodaysJourneyHelpers.getEstimatedCompletionTime(for: item.habit, targetDate: selectedDate)
        )
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  // MARK: - Data Loading

  private func loadJourneyItems() {
    let scheduled = scheduledHabits
    let calendar = Calendar.current
    let isToday = calendar.isDate(selectedDate, inSameDayAs: Date())
    let dateKey = Habit.dateKey(for: selectedDate)

    var items: [JourneyHabitItem] = []

    for habit in scheduled {
      let completed = habit.isCompletedForDate(selectedDate)
      let completionTime: Date?
      let difficulty: Int?

      if completed {
        let timestamps = habit.completionTimestamps[dateKey]
        completionTime = timestamps?.last
        difficulty = habit.getDifficulty(for: selectedDate)
      } else {
        completionTime = nil
        difficulty = nil
      }

      let atRisk = isToday ? TodaysJourneyHelpers.isStreakAtRisk(for: habit) : false

      items.append(JourneyHabitItem(
        id: habit.id,
        habit: habit,
        status: completed ? .completed : .pending,
        completionTime: completionTime,
        difficulty: difficulty,
        currentStreak: habit.computedStreak(),
        isAtRisk: atRisk
      ))
    }

    journeyItems = items
  }
}

// MARK: - BounceAnimation

struct BounceAnimation: ViewModifier {
  @State private var isBouncing = false

  func body(content: Content) -> some View {
    content
      .offset(y: isBouncing ? -10 : 0)
      .animation(
        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
        value: isBouncing
      )
      .onAppear { isBouncing = true }
  }
}
