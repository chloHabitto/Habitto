import CryptoKit
import Foundation
import SwiftData

/// Represents the outcome of a streak computation pass.
struct StreakComputationResult {
  let currentStreak: Int
  let lastCompleteDate: Date?
  let processedDayCount: Int
  let skippedUnsheduledDays: Int
  let todayWasComplete: Bool
}

/// Shared utility that owns the canonical streak calculation logic.
enum StreakCalculator {

  /// Computes the user's global streak using the provided habits and completion records.
  ///
  /// - Parameters:
  ///   - habits: Habits scoped to the current user.
  ///   - completionRecords: Completion records filtered to the same user (completed only).
  ///   - today: Reference "today" date (defaults to `Date()`).
  ///   - calendar: Calendar used for day math (defaults to `.current`).
  static func computeCurrentStreak(
    habits: [Habit],
    completionRecords: [CompletionRecord],
    today: Date = Date(),
    calendar: Calendar = .current
  ) -> StreakComputationResult {
    guard !habits.isEmpty else {
      return StreakComputationResult(
        currentStreak: 0,
        lastCompleteDate: nil,
        processedDayCount: 0,
        skippedUnsheduledDays: 0,
        todayWasComplete: false)
    }

    let normalizedToday = DateUtils.startOfDay(for: today)
    var checkDate = normalizedToday
    var currentStreakCount = 0
    var lastCompleteDate: Date?
    var processedDays = 0
    var skippedUnsheduledDays = 0

    let defaultStartDate = calendar.date(byAdding: .day, value: -365, to: normalizedToday) ?? normalizedToday
    let earliestHabitStart = habits
      .map { calendar.startOfDay(for: $0.startDate) }
      .min() ?? defaultStartDate
    let startDate = max(defaultStartDate, earliestHabitStart)

    while checkDate >= startDate {
      let scheduledHabits = habits.filter {
        HabitSchedulingLogic.shouldShowHabitOnDate($0, date: checkDate, habits: habits)
      }

      guard !scheduledHabits.isEmpty else {
        skippedUnsheduledDays += 1
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        continue
      }

      processedDays += 1
      let dateKey = Habit.dateKey(for: checkDate)

      // ✅ CRITICAL FIX: Always use habit.isCompleted(for:) which respects historical goals
      // CompletionRecords may have been created with current goal, not historical goal for that date
      // habit.isCompleted(for:) uses goalHistory to determine the correct goal for each date
      // Example: If goal changed from 1→2 on 15th, then 12th/13th/14th should check against goal=1, not goal=2
      let allComplete = scheduledHabits.allSatisfy { habit in
        habit.isCompleted(for: checkDate)
      }

      if allComplete {
        currentStreakCount += 1
        if lastCompleteDate == nil {
          lastCompleteDate = checkDate
        }
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        continue
      }

      if calendar.isDate(checkDate, inSameDayAs: normalizedToday) {
        // Today is incomplete—skip to yesterday without breaking the streak
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        continue
      }

      break
    }

    let todayWasComplete =
      lastCompleteDate.map { calendar.isDate($0, inSameDayAs: normalizedToday) } ?? false

    return StreakComputationResult(
      currentStreak: currentStreakCount,
      lastCompleteDate: lastCompleteDate,
      processedDayCount: processedDays,
      skippedUnsheduledDays: skippedUnsheduledDays,
      todayWasComplete: todayWasComplete)
  }

  /// Produces a deterministic checksum for the supplied completion records so we can
  /// detect data drift between streak computations.
  static func checksum(for records: [CompletionRecord]) -> String {
    guard !records.isEmpty else { return "empty" }

    let sorted = records.sorted { lhs, rhs in
      if lhs.dateKey == rhs.dateKey {
        return lhs.habitId.uuidString < rhs.habitId.uuidString
      }
      return lhs.dateKey < rhs.dateKey
    }

    let signature = sorted.prefix(256).map { record in
      "\(record.dateKey)#\(record.habitId.uuidString)#\(record.isCompleted ? 1 : 0)"
    }.joined(separator: "|")

    let digest = SHA256.hash(data: Data(signature.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

