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

    let currentMode = CompletionMode.current

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

      // ✅ SKIP FEATURE: Filter out skipped habits from streak calculation
      let activeHabits = scheduledHabits.filter { !$0.isSkipped(for: checkDate) }
      
      guard !activeHabits.isEmpty else {
        // All habits were skipped - treat as "no habits scheduled" (neutral day)
        // Doesn't break streak, doesn't count towards streak
        skippedUnsheduledDays += 1
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        continue
      }

      processedDays += 1

      // ✅ CRITICAL FIX: Use habit.meetsStreakCriteria(for:) which respects Streak Mode setting
      // This method respects the user's CompletionMode (full vs partial) for streak calculation
      // while isCompleted(for:) remains for UI display purposes only
      let allComplete = activeHabits.allSatisfy { habit in
        habit.meetsStreakCriteria(for: checkDate)
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

  /// Calculates the longest streak from all completion records in history
  /// This finds the maximum consecutive days where all scheduled habits were completed
  static func computeLongestStreakFromHistory(
    habits: [Habit],
    completionRecords: [CompletionRecord],
    calendar: Calendar = .current
  ) -> Int {
    guard !habits.isEmpty else {
      return 0
    }
    
    let currentMode = CompletionMode.current
    
    let today = DateUtils.startOfDay(for: Date())
    let defaultStartDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
    let earliestHabitStart = habits
      .map { calendar.startOfDay(for: $0.startDate) }
      .min() ?? defaultStartDate
    let startDate = max(defaultStartDate, earliestHabitStart)
    
    var longestStreak = 0
    var currentStreak = 0
    var checkDate = startDate
    var completedDates: [String] = []
    var longestStreakStartDate: Date?
    var longestStreakEndDate: Date?
    
    while checkDate <= today {
      let dateKey = Habit.dateKey(for: checkDate)
      let scheduledHabits = habits.filter {
        HabitSchedulingLogic.shouldShowHabitOnDate($0, date: checkDate, habits: habits)
      }
      
      guard !scheduledHabits.isEmpty else {
        // No habits scheduled - doesn't break streak, but doesn't count either
        checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        continue
      }
      
      // ✅ SKIP FEATURE: Filter out skipped habits from longest streak calculation
      let activeHabits = scheduledHabits.filter { !$0.isSkipped(for: checkDate) }
      let skippedCount = scheduledHabits.count - activeHabits.count
      
      guard !activeHabits.isEmpty else {
        // All habits were skipped - doesn't break streak, but doesn't count either
        checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        continue
      }
      
      // Check completion status for each active (non-skipped) habit
      var completedHabits: [String] = []
      var incompleteHabits: [String] = []
      
      for habit in activeHabits {
        let isComplete = habit.meetsStreakCriteria(for: checkDate)
        if isComplete {
          completedHabits.append(habit.name)
        } else {
          incompleteHabits.append(habit.name)
        }
      }
      
      let allComplete = incompleteHabits.isEmpty
      let completionCount = completedHabits.count
      let totalCount = scheduledHabits.count
      
      // Check completion status
      if allComplete {
        currentStreak += 1
        completedDates.append(dateKey)
        
        if currentStreak > longestStreak {
          longestStreak = currentStreak
          longestStreakEndDate = checkDate
          longestStreakStartDate = calendar.date(byAdding: .day, value: -(currentStreak - 1), to: checkDate)
        }
      } else {
        currentStreak = 0
      }
      
      checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
    }
    
    print("📊 LONGEST_STREAK: Calculation complete")
    print("   Total completed dates found: \(completedDates.count)")
    print("   Longest consecutive sequence: \(longestStreak) days")
    if longestStreak > 0, let start = longestStreakStartDate, let end = longestStreakEndDate {
      print("   Longest streak period: \(Habit.dateKey(for: start)) to \(Habit.dateKey(for: end))")
      if longestStreak <= 10 {
        print("   Dates in longest streak: \(completedDates.suffix(longestStreak).joined(separator: ", "))")
      } else {
        let streakDates = completedDates.suffix(longestStreak)
        print("   First 5 dates: \(streakDates.prefix(5).joined(separator: ", "))")
        print("   Last 5 dates: \(streakDates.suffix(5).joined(separator: ", "))")
      }
    }
    
    return longestStreak
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

