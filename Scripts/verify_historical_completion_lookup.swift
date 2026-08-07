#!/usr/bin/env swift
/**
 Focused repro for PR3: off-main historical completion lookups.

 Simulates:
 1) Legacy bug: off-main historical query returns nil → falls back to empty in-memory dict → false
 2) Fixed map path: prefetched [dateKey: progress] + shared isProgressComplete → correct true
 3) Vacation remapping still applied before map lookup
 4) Sync main-thread path and map path agree for the same progress/goal

 Run: swift Scripts/verify_historical_completion_lookup.swift
 */

import Foundation

// MARK: - Shared comparison (mirrors Habit.isProgressComplete)

func isProgressComplete(progress: Int, goalAmount: Int) -> Bool {
  goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)
}

// MARK: - Simulated completion lookup

struct SimulatedHabit {
  var completionHistory: [String: Int] = [:]
  var vacationDays: Set<String> = []
  var vacationActive = false

  static func dateKey(for date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  /// Legacy off-main behavior: SwiftData query returns nil → empty dict → wrong
  func isCompletedLegacyOffMain(for date: Date, goalAmount: Int) -> Bool {
    let checkDate = effectiveCompletionCheckDate(for: date)
    let key = Self.dateKey(for: checkDate)
    // Off-main: pretend SwiftData returned nil
    let progress = completionHistory[key] ?? 0
    return isProgressComplete(progress: progress, goalAmount: goalAmount)
  }

  /// Fixed map path (vacation remapped, then map lookup + shared comparison)
  func isCompletedWithMap(
    for date: Date,
    goalAmount: Int,
    progressByDateKey: [String: Int]
  ) -> Bool {
    let checkDate = effectiveCompletionCheckDate(for: date)
    let key = Self.dateKey(for: checkDate)
    let progress = progressByDateKey[key] ?? completionHistory[key] ?? 0
    return isProgressComplete(progress: progress, goalAmount: goalAmount)
  }

  /// Main-thread path: "SwiftData" hit with same progress the map would have
  func isCompletedMainThread(
    for date: Date,
    goalAmount: Int,
    swiftDataProgress: Int?
  ) -> Bool {
    let checkDate = effectiveCompletionCheckDate(for: date)
    let key = Self.dateKey(for: checkDate)
    if let swiftDataProgress {
      return isProgressComplete(progress: swiftDataProgress, goalAmount: goalAmount)
    }
    let progress = completionHistory[key] ?? 0
    return isProgressComplete(progress: progress, goalAmount: goalAmount)
  }

  private func effectiveCompletionCheckDate(for date: Date) -> Date {
    guard vacationActive else { return date }
    let key = Self.dateKey(for: date)
    guard vacationDays.contains(key) else { return date }

    let calendar = Calendar.current
    var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
    while vacationDays.contains(Self.dateKey(for: checkDate)) {
      guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
      checkDate = prev
    }
    return checkDate
  }
}

// MARK: - Repro

func runRepro() -> Int {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: Date())
  guard let historical = calendar.date(byAdding: .day, value: -3, to: today),
        let vacationDay = calendar.date(byAdding: .day, value: -1, to: today),
        let preVacation = calendar.date(byAdding: .day, value: -2, to: today)
  else {
    print("FAIL: could not build test dates")
    return 1
  }

  let historicalKey = SimulatedHabit.dateKey(for: historical)
  let preVacationKey = SimulatedHabit.dateKey(for: preVacation)
  let goal = 3
  let storedProgress = 3

  // In-memory dict empty for historical (the real bug condition)
  var habit = SimulatedHabit(completionHistory: [:])
  var prefetchMap: [String: Int] = [:]
  prefetchMap[historicalKey] = storedProgress
  prefetchMap[preVacationKey] = storedProgress

  // 1) Legacy off-main → false (wrong)
  let legacy = habit.isCompletedLegacyOffMain(for: historical, goalAmount: goal)
  // 2) Map path → true (correct)
  let mapped = habit.isCompletedWithMap(
    for: historical,
    goalAmount: goal,
    progressByDateKey: prefetchMap)
  // 3) Main-thread SwiftData → true
  let mainThread = habit.isCompletedMainThread(
    for: historical,
    goalAmount: goal,
    swiftDataProgress: storedProgress)

  print("historical dateKey=\(historicalKey) progress=\(storedProgress) goal=\(goal)")
  print("legacyOffMain=\(legacy) mapPath=\(mapped) mainThread=\(mainThread)")

  guard legacy == false else {
    print("FAIL: expected legacy off-main to be false when dict is empty")
    return 1
  }
  guard mapped == true, mainThread == true, mapped == mainThread else {
    print("FAIL: map and main-thread paths must both be true and agree")
    return 1
  }

  // 4) Vacation remapping: vacation day should use pre-vacation completion from map
  habit.vacationActive = true
  habit.vacationDays = [SimulatedHabit.dateKey(for: vacationDay)]
  let vacationMapped = habit.isCompletedWithMap(
    for: vacationDay,
    goalAmount: goal,
    progressByDateKey: prefetchMap)
  print("vacationDay remap → completed=\(vacationMapped) (expects true via \(preVacationKey))")
  guard vacationMapped == true else {
    print("FAIL: vacation remapping did not consult pre-vacation map entry")
    return 1
  }

  // Reset vacation for the detached-style streak walk
  habit.vacationActive = false
  habit.vacationDays = []

  // 5) Shared comparison edge cases
  guard isProgressComplete(progress: 0, goalAmount: 0) == false else {
    print("FAIL: progress 0 / goal 0 should be incomplete")
    return 1
  }
  guard isProgressComplete(progress: 1, goalAmount: 0) == true else {
    print("FAIL: progress > 0 / goal 0 should be complete")
    return 1
  }
  guard isProgressComplete(progress: 2, goalAmount: 3) == false else {
    print("FAIL: progress < goal should be incomplete")
    return 1
  }

  // 6) Simulate streak-style Task.detached: many dates against one prefetch map
  var streakDays = 0
  for offset in 1...10 {
    guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
    let key = SimulatedHabit.dateKey(for: day)
    let dayMap = [key: storedProgress]
    if habit.isCompletedWithMap(for: day, goalAmount: goal, progressByDateKey: dayMap) {
      streakDays += 1
    }
  }
  print("detached-style streak walk daysCompleted=\(streakDays) (expects 10)")
  guard streakDays == 10 else {
    print("FAIL: batched map walk should see all 10 historical completions")
    return 1
  }

  print("PASS: historical completion map path matches main-thread; vacation remap works; legacy off-main was wrong")
  return 0
}

exit(Int32(runRepro()))
