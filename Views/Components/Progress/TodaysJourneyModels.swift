//
//  TodaysJourneyModels.swift
//  Habitto
//
//  Data models for the "Today's Journey" timeline on the Progress tab.
//  Represents habit completion status throughout the day.
//

import Foundation

// MARK: - JourneyItemStatus

enum JourneyItemStatus: Equatable {
  case completed
  case pending
}

// MARK: - JourneyHabitItem

struct JourneyHabitItem: Identifiable {
  let id: UUID
  let habit: Habit
  let status: JourneyItemStatus
  let completionTime: Date?
  let difficulty: Int?
  let currentStreak: Int
  let isAtRisk: Bool
}

// MARK: - Helper Functions

enum TodaysJourneyHelpers {
  /// Estimates completion time from habit's `completionTimestamps` history.
  /// Averages completion time for the same weekday as `targetDate`.
  /// Returns nil if no historical data exists for that weekday.
  static func getEstimatedCompletionTime(for habit: Habit, targetDate: Date = Date()) -> Date? {
    let calendar = Calendar.current
    let targetWeekday = calendar.component(.weekday, from: targetDate)
    var secondsSinceMidnight: [TimeInterval] = []

    for (dateKey, timestamps) in habit.completionTimestamps {
      guard let date = DateUtils.date(from: dateKey),
            calendar.component(.weekday, from: date) == targetWeekday,
            !timestamps.isEmpty
      else { continue }

      let dayStart = calendar.startOfDay(for: date)
      let lastTimestamp = timestamps.last!
      let seconds = lastTimestamp.timeIntervalSince(dayStart)
      secondsSinceMidnight.append(seconds)
    }

    guard !secondsSinceMidnight.isEmpty else { return nil }

    let averageSeconds = secondsSinceMidnight.reduce(0, +) / Double(secondsSinceMidnight.count)
    let targetDayStart = calendar.startOfDay(for: targetDate)
    return targetDayStart.addingTimeInterval(averageSeconds)
  }

  /// Returns true if the habit has a streak > 0 and is not completed today.
  /// Uses `computedStreak()` and completion status for today.
  static func isStreakAtRisk(for habit: Habit) -> Bool {
    let today = Date()
    let streak = habit.computedStreak()
    let completedToday = habit.isCompletedForDate(today)
    return streak > 0 && !completedToday
  }
}
