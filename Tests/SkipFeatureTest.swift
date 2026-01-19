import Foundation

/// Test suite for Skip Feature - Phase 2: Streak Calculation
/// Verifies that skipped days preserve streaks without incrementing the counter

class SkipFeatureTest {
  
  /// Test Case 1: Skipped day in the middle of a streak
  /// Expected: Streak continues through skipped day
  /// Pattern: ✅ ✅ ⏭️ ✅ ✅ (today)
  /// Expected Streak: 4 (skipped day doesn't increment, but doesn't break)
  static func testSkippedDayPreservesStreak() {
    print("\n🧪 TEST: Skipped day preserves streak")
    
    var habit = createTestHabit(name: "Test Habit - Skip Preserves")
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Day -4: Completed
    if let day4Ago = calendar.date(byAdding: .day, value: -4, to: today) {
      habit.markCompleted(for: day4Ago)
      print("  ✅ Day -4: Completed")
    }
    
    // Day -3: Completed
    if let day3Ago = calendar.date(byAdding: .day, value: -3, to: today) {
      habit.markCompleted(for: day3Ago)
      print("  ✅ Day -3: Completed")
    }
    
    // Day -2: SKIPPED
    if let day2Ago = calendar.date(byAdding: .day, value: -2, to: today) {
      habit.skip(for: day2Ago, reason: .medical, note: "Doctor's appointment")
      print("  ⏭️  Day -2: Skipped (medical)")
    }
    
    // Day -1: Completed
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
      habit.markCompleted(for: yesterday)
      print("  ✅ Day -1: Completed")
    }
    
    // Today: Completed
    habit.markCompleted(for: today)
    print("  ✅ Today: Completed")
    
    // Calculate streak
    let streak = habit.calculateTrueStreak()
    print("  📊 Calculated Streak: \(streak)")
    print("  ✓ Expected: 4 (4 completed days, skipped day doesn't count but preserves streak)")
    
    assert(streak == 4, "❌ FAIL: Expected streak of 4, got \(streak)")
    print("  ✅ PASS: Streak correctly calculated as \(streak)")
  }
  
  /// Test Case 2: Today is skipped
  /// Expected: Streak preserved from previous days
  /// Pattern: ✅ ✅ ✅ ⏭️ (today)
  /// Expected Streak: 3 (yesterday's streak preserved)
  static func testTodaySkippedPreservesStreak() {
    print("\n🧪 TEST: Today skipped preserves previous streak")
    
    var habit = createTestHabit(name: "Test Habit - Today Skip")
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Day -3: Completed
    if let day3Ago = calendar.date(byAdding: .day, value: -3, to: today) {
      habit.markCompleted(for: day3Ago)
      print("  ✅ Day -3: Completed")
    }
    
    // Day -2: Completed
    if let day2Ago = calendar.date(byAdding: .day, value: -2, to: today) {
      habit.markCompleted(for: day2Ago)
      print("  ✅ Day -2: Completed")
    }
    
    // Day -1: Completed
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
      habit.markCompleted(for: yesterday)
      print("  ✅ Day -1: Completed")
    }
    
    // Today: SKIPPED
    habit.skip(for: today, reason: .weather, note: "Bad weather")
    print("  ⏭️  Today: Skipped (weather)")
    
    // Calculate streak
    let streak = habit.calculateTrueStreak()
    print("  📊 Calculated Streak: \(streak)")
    print("  ✓ Expected: 3 (previous 3 completed days)")
    
    assert(streak == 3, "❌ FAIL: Expected streak of 3, got \(streak)")
    print("  ✅ PASS: Streak correctly calculated as \(streak)")
  }
  
  /// Test Case 3: Multiple skipped days in a row
  /// Expected: Streak preserved through all skipped days
  /// Pattern: ✅ ✅ ⏭️ ⏭️ ✅ (today)
  /// Expected Streak: 3 (3 completed days, 2 skipped days don't break)
  static func testMultipleSkippedDaysPreserveStreak() {
    print("\n🧪 TEST: Multiple skipped days preserve streak")
    
    var habit = createTestHabit(name: "Test Habit - Multiple Skips")
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Day -4: Completed
    if let day4Ago = calendar.date(byAdding: .day, value: -4, to: today) {
      habit.markCompleted(for: day4Ago)
      print("  ✅ Day -4: Completed")
    }
    
    // Day -3: Completed
    if let day3Ago = calendar.date(byAdding: .day, value: -3, to: today) {
      habit.markCompleted(for: day3Ago)
      print("  ✅ Day -3: Completed")
    }
    
    // Day -2: SKIPPED
    if let day2Ago = calendar.date(byAdding: .day, value: -2, to: today) {
      habit.skip(for: day2Ago, reason: .travel, note: "Business trip")
      print("  ⏭️  Day -2: Skipped (travel)")
    }
    
    // Day -1: SKIPPED
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
      habit.skip(for: yesterday, reason: .travel, note: "Still traveling")
      print("  ⏭️  Day -1: Skipped (travel)")
    }
    
    // Today: Completed
    habit.markCompleted(for: today)
    print("  ✅ Today: Completed")
    
    // Calculate streak
    let streak = habit.calculateTrueStreak()
    print("  📊 Calculated Streak: \(streak)")
    print("  ✓ Expected: 3 (3 completed days, 2 skipped days preserve chain)")
    
    assert(streak == 3, "❌ FAIL: Expected streak of 3, got \(streak)")
    print("  ✅ PASS: Streak correctly calculated as \(streak)")
  }
  
  /// Test Case 4: Missed day breaks streak (not skipped)
  /// Expected: Streak breaks on missed day
  /// Pattern: ✅ ✅ ❌ ✅ (today)
  /// Expected Streak: 1 (only today)
  static func testMissedDayBreaksStreak() {
    print("\n🧪 TEST: Missed day (not skipped) breaks streak")
    
    var habit = createTestHabit(name: "Test Habit - Missed Day")
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Day -3: Completed
    if let day3Ago = calendar.date(byAdding: .day, value: -3, to: today) {
      habit.markCompleted(for: day3Ago)
      print("  ✅ Day -3: Completed")
    }
    
    // Day -2: Completed
    if let day2Ago = calendar.date(byAdding: .day, value: -2, to: today) {
      habit.markCompleted(for: day2Ago)
      print("  ✅ Day -2: Completed")
    }
    
    // Day -1: MISSED (not skipped, not completed)
    if let _ = calendar.date(byAdding: .day, value: -1, to: today) {
      // Don't mark as completed or skipped
      print("  ❌ Day -1: Missed (not completed, not skipped)")
    }
    
    // Today: Completed
    habit.markCompleted(for: today)
    print("  ✅ Today: Completed")
    
    // Calculate streak
    let streak = habit.calculateTrueStreak()
    print("  📊 Calculated Streak: \(streak)")
    print("  ✓ Expected: 1 (only today, streak broken by missed day)")
    
    assert(streak == 1, "❌ FAIL: Expected streak of 1, got \(streak)")
    print("  ✅ PASS: Streak correctly calculated as \(streak)")
  }
  
  /// Helper: Create a test habit
  private static func createTestHabit(name: String) -> Habit {
    let calendar = Calendar.current
    let startDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    
    return Habit(
      name: name,
      description: "Test habit for skip feature",
      icon: "checkmark.circle.fill",
      color: CodableColor(.blue),
      habitType: .formation,
      schedule: "everyday",
      goal: "1 time on everyday",
      reminder: "None",
      startDate: startDate
    )
  }
  
  /// Run all tests
  static func runAllTests() {
    print("\n" + String(repeating: "=", count: 60))
    print("🧪 SKIP FEATURE TEST SUITE - Phase 2: Streak Calculation")
    print(String(repeating: "=", count: 60))
    
    testSkippedDayPreservesStreak()
    testTodaySkippedPreservesStreak()
    testMultipleSkippedDaysPreserveStreak()
    testMissedDayBreaksStreak()
    
    print("\n" + String(repeating: "=", count: 60))
    print("✅ ALL TESTS PASSED")
    print(String(repeating: "=", count: 60) + "\n")
  }
}

// MARK: - Usage Instructions
/*
 To run these tests, add the following code to your app:
 
 #if DEBUG
 SkipFeatureTest.runAllTests()
 #endif
 
 Or run individual tests:
 
 #if DEBUG
 SkipFeatureTest.testSkippedDayPreservesStreak()
 #endif
 */
