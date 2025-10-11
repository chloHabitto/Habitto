import Foundation
import SwiftData
import SwiftUI

// MARK: - XPDiagnostic

// Run this in your app to diagnose the XP issue

@MainActor
class XPDiagnostic {
  static func runFullDiagnostic() async {
    print("🔍 XP DIAGNOSTIC: Starting comprehensive analysis...")

    // 1. Check current XP state
    let xpManager = XPManager.shared
    print("📊 Current XP State:")
    print("  Total XP: \(xpManager.userProgress.totalXP)")
    print("  Current Level: \(xpManager.userProgress.currentLevel)")
    print("  Daily XP: \(xpManager.userProgress.dailyXP)")

    // 2. Check user ID consistency
    let debugUserId = "debug_user_id"
    print("\n👤 User ID Analysis:")
    print("  Debug User ID: \(debugUserId)")

    // 3. Check if you have any DailyAward records
    print("\n🏆 DailyAward Analysis:")
    // This would need to be run in a view with ModelContext
    print("  (Run this in a view with @Environment(\\.modelContext) to check DailyAwards)")

    // 4. Check habit completion status
    print("\n✅ Habit Completion Analysis:")
    let habits = HabitRepository.shared.habits
    print("  Total habits: \(habits.count)")

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    let yesterdayKey = Habit.dateKey(for: yesterday)
    print("  Yesterday's date key: \(yesterdayKey)")

    var completedHabits = 0
    for habit in habits {
      let isCompleted = habit.isCompleted(for: yesterday)
      print("  Habit '\(habit.name)': \(isCompleted ? "✅ Completed" : "❌ Not completed")")
      if isCompleted {
        completedHabits += 1
      }
    }

    print("  Completed habits yesterday: \(completedHabits)/\(habits.count)")
    let allCompleted = completedHabits == habits.count && !habits.isEmpty
    print("  All habits completed yesterday: \(allCompleted ? "✅ YES" : "❌ NO")")

    // 5. Recommendations
    print("\n💡 Recommendations:")
    if xpManager.userProgress.totalXP == 0 {
      print("  ❌ You have 0 XP - this suggests the XP award system didn't trigger")
      if allCompleted {
        print("  🔧 Since all habits were completed yesterday, you should have received 50 XP")
        print("  🔧 The issue is likely a user ID mismatch or the award system not being called")
      } else {
        print("  ℹ️  Not all habits were completed yesterday, so no XP was awarded")
      }
    } else {
      print("  ✅ You have \(xpManager.userProgress.totalXP) XP")
    }

    print("\n🔧 Next Steps:")
    print("  1. Check if DailyAwardService was called when you completed habits")
    print("  2. Verify user ID consistency across the system")
    print("  3. Manually trigger XP award if needed")
  }
}

// MARK: - Manual XP Fix

extension XPDiagnostic {
  @MainActor
  static func manuallyAwardYesterdayXP() async {
    print("🔧 MANUAL XP FIX: Awarding XP for yesterday's completion")

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    let yesterdayKey = Habit.dateKey(for: yesterday)
    let userId = "debug_user_id"

    print("  Date: \(yesterdayKey)")
    print("  User ID: \(userId)")

    // Check if all habits were completed yesterday
    let habits = HabitRepository.shared.habits
    var completedHabits = 0

    for habit in habits {
      let isCompleted = habit.isCompleted(for: yesterday)
      if isCompleted {
        completedHabits += 1
      }
    }

    let allCompleted = completedHabits == habits.count && !habits.isEmpty
    print("  All habits completed: \(allCompleted)")

    if allCompleted {
      // Manually update XPManager
      let xpManager = XPManager.shared
      let xpToAward = 50 // Standard daily completion XP

      print("  Awarding \(xpToAward) XP...")
      xpManager.updateXPFromDailyAward(xpGranted: xpToAward, dateKey: yesterdayKey)

      print("  ✅ XP awarded! New total: \(xpManager.userProgress.totalXP)")
    } else {
      print("  ❌ Cannot award XP - not all habits were completed yesterday")
    }
  }
}
