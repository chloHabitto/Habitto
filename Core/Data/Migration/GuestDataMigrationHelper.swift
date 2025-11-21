//
//  GuestDataMigrationHelper.swift
//  Habitto
//
//  Helper for guest data migration - can be called from anywhere
//

import Foundation
import SwiftData
import OSLog

// MARK: - GuestDataMigrationHelper

/// Helper class for guest data migration that can be called from anywhere
@MainActor
final class GuestDataMigrationHelper {
  private static let logger = Logger(subsystem: "com.habitto.app", category: "GuestDataMigration")
  
  /// Force migration of guest data to anonymous user
  /// This clears the migration flag and runs the complete migration
  static func forceMigration(userId: String) async {
    let newMigrationKey = "guest_to_anonymous_complete_migrated_\(userId)"
    
    print("🔄 [GUEST_MIGRATION] FORCING migration (manual trigger)")
    print("   User ID: \(userId.prefix(8))...")
    logger.info("🔄 GuestMigration: FORCING migration (manual trigger) for user \(userId.prefix(8))...")
    
    // Clear the migration flag to allow re-migration
    UserDefaults.standard.removeObject(forKey: newMigrationKey)
    print("   ✅ Cleared migration flag: \(newMigrationKey)")
    logger.info("   ✅ Cleared migration flag")
    
    // Run the migration
    await runCompleteMigration(userId: userId)
  }
  
  /// Run the complete migration (habits + completions + awards + progress)
  static func runCompleteMigration(userId: String) async {
    print("🔄 [GUEST_MIGRATION] Starting COMPLETE migration to anonymous user")
    print("   Target User ID: \(userId)")
    logger.info("🔄 GuestMigration: Starting COMPLETE migration to anonymous user \(userId.prefix(8))...")
    
    do {
      let modelContext = SwiftDataContainer.shared.modelContext
      var totalMigratedXP = 0
      var completionRecordsMigrated = 0
      var dailyAwardsMigrated = 0
      
      // 1. Migrate HabitData
      let guestHabitsDescriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { habit in
          habit.userId == ""
        }
      )
      let guestHabits = try modelContext.fetch(guestHabitsDescriptor)
      
      if !guestHabits.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(guestHabits.count) guest habits to migrate")
        logger.info("🔄 GuestMigration: Migrating \(guestHabits.count) habits...")
        
        for habitData in guestHabits {
          habitData.userId = userId
          
          // Update CompletionRecords linked via relationship
          for record in habitData.completionHistory {
            record.userId = userId
            record.userIdHabitIdDateKey = "\(userId)#\(record.habitId.uuidString)#\(record.dateKey)"
          }
        }
        
        try modelContext.save()
        print("✅ [GUEST_MIGRATION] Migrated \(guestHabits.count) habits successfully")
        logger.info("✅ GuestMigration: Migrated \(guestHabits.count) habits")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No guest habits found to migrate")
      }
      
      // 2. Migrate ALL CompletionRecords (including standalone ones not linked via relationship)
      let guestCompletionRecordsDescriptor = FetchDescriptor<CompletionRecord>(
        predicate: #Predicate<CompletionRecord> { record in
          record.userId == ""
        }
      )
      let guestCompletionRecords = try modelContext.fetch(guestCompletionRecordsDescriptor)
      
      if !guestCompletionRecords.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(guestCompletionRecords.count) guest completion records to migrate")
        logger.info("🔄 GuestMigration: Migrating \(guestCompletionRecords.count) completion records...")
        
        for record in guestCompletionRecords {
          record.userId = userId
          record.userIdHabitIdDateKey = "\(userId)#\(record.habitId.uuidString)#\(record.dateKey)"
          completionRecordsMigrated += 1
        }
        
        try modelContext.save()
        print("✅ [GUEST_MIGRATION] Migrated \(completionRecordsMigrated) completion records successfully")
        logger.info("✅ GuestMigration: Migrated \(completionRecordsMigrated) completion records")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No guest completion records found to migrate")
      }
      
      // 3. Migrate DailyAwards
      let guestAwardsDescriptor = FetchDescriptor<DailyAward>(
        predicate: #Predicate<DailyAward> { award in
          award.userId == ""
        }
      )
      let guestAwards = try modelContext.fetch(guestAwardsDescriptor)
      
      if !guestAwards.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(guestAwards.count) guest daily awards to migrate")
        logger.info("🔄 GuestMigration: Migrating \(guestAwards.count) daily awards...")
        
        for award in guestAwards {
          award.userId = userId
          award.userIdDateKey = "\(userId)#\(award.dateKey)"
          totalMigratedXP += award.xpGranted
          dailyAwardsMigrated += 1
        }
        
        try modelContext.save()
        print("✅ [GUEST_MIGRATION] Migrated \(dailyAwardsMigrated) daily awards successfully")
        print("   Total XP from migrated awards: \(totalMigratedXP)")
        logger.info("✅ GuestMigration: Migrated \(dailyAwardsMigrated) daily awards with \(totalMigratedXP) total XP")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No guest daily awards found to migrate")
      }
      
      // 4. Migrate UserProgressData
      let guestProgressDescriptor = FetchDescriptor<UserProgressData>(
        predicate: #Predicate<UserProgressData> { progress in
          progress.userId == ""
        }
      )
      let guestProgress = try modelContext.fetch(guestProgressDescriptor).first
      
      if let progress = guestProgress {
        print("🔄 [GUEST_MIGRATION] Found user progress to migrate")
        print("   Current XP: \(progress.xpTotal), Level: \(progress.level), Streak: \(progress.streakDays)")
        logger.info("🔄 GuestMigration: Migrating user progress (XP: \(progress.xpTotal), Level: \(progress.level))...")
        progress.userId = userId
        try modelContext.save()
        print("✅ [GUEST_MIGRATION] Migrated user progress successfully")
        print("   Migrated XP: \(progress.xpTotal), Level: \(progress.level), Streak: \(progress.streakDays)")
        logger.info("✅ GuestMigration: Migrated user progress (XP: \(progress.xpTotal), Level: \(progress.level))")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No guest user progress found to migrate")
      }
      
      // Summary log
      print("📊 [GUEST_MIGRATION] Migration Summary:")
      print("   ✅ Habits: \(guestHabits.count)")
      print("   ✅ Completion Records: \(completionRecordsMigrated)")
      print("   ✅ Daily Awards: \(dailyAwardsMigrated)")
      print("   ✅ Total XP from Awards: \(totalMigratedXP)")
      if let progress = guestProgress {
        print("   ✅ User Progress XP: \(progress.xpTotal)")
      }
      logger.info("📊 GuestMigration: Summary - \(guestHabits.count) habits, \(completionRecordsMigrated) completions, \(dailyAwardsMigrated) awards, \(totalMigratedXP) XP")
      
      // Mark migration as complete
      let newMigrationKey = "guest_to_anonymous_complete_migrated_\(userId)"
      UserDefaults.standard.set(true, forKey: newMigrationKey)
      print("✅ [GUEST_MIGRATION] COMPLETE migration finished for user \(userId.prefix(8))...")
      print("   Migration flag set: \(newMigrationKey)")
      logger.info("✅ GuestMigration: COMPLETE migration finished for user \(userId.prefix(8))...")
      
    } catch {
      print("❌ [GUEST_MIGRATION] FAILED: \(error.localizedDescription)")
      logger.error("❌ GuestMigration: Failed to migrate guest data: \(error.localizedDescription)")
    }
  }
}

