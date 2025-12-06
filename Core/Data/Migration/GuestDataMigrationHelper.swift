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
      // ✅ CRITICAL FIX: Find habits that don't have the new userId
      // This handles both empty userId and old anonymous user IDs
      
      // First, get all habits that already belong to the current user
      let userHabitsDescriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate<HabitData> { habit in
          habit.userId == userId
        }
      )
      let existingUserHabits = try modelContext.fetch(userHabitsDescriptor)
      
      // Find habits that need migration (not already migrated)
      let allHabitsDescriptor = FetchDescriptor<HabitData>()
      let allHabits = try modelContext.fetch(allHabitsDescriptor)
      let existingUserHabitIds = Set(existingUserHabits.map { $0.id })
      
      // Filter: habits that don't belong to current user
      let guestHabits = allHabits.filter { !existingUserHabitIds.contains($0.id) && $0.userId != userId }
      
      if !guestHabits.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(guestHabits.count) habits to migrate")
        logger.info("🔄 GuestMigration: Migrating \(guestHabits.count) habits...")
        
        // Group by old userId for logging
        let byOldUserId = Dictionary(grouping: guestHabits) { $0.userId }
        for (oldUserId, habits) in byOldUserId {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          print("   Migrating \(habits.count) habits from userId '\(oldUserIdDisplay)'")
        }
        
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
        print("ℹ️ [GUEST_MIGRATION] No habits found to migrate (all habits already belong to current user)")
      }
      
      // Get all user habits (including newly migrated ones) for later steps
      let allUserHabits = try modelContext.fetch(userHabitsDescriptor)
      
      // 2. Migrate ALL CompletionRecords (including standalone ones not linked via relationship)
      // ✅ CRITICAL FIX: Find records where userId != newUserId but habitId matches user's habits
      // This handles cases where habits were migrated but records still have old userId
      
      // Use the user habits we already fetched (or fetch again if needed)
      let userHabits = allUserHabits.isEmpty ? try modelContext.fetch(userHabitsDescriptor) : allUserHabits
      let userHabitIds = Set(userHabits.map { $0.id })
      
      print("🔍 [GUEST_MIGRATION] Found \(userHabits.count) habits for current user")
      print("   Habit IDs: \(userHabitIds.map { $0.uuidString.prefix(8) }.joined(separator: ", "))...")
      
      // Find all CompletionRecords that match user's habits but have different userId
      let allCompletionsDescriptor = FetchDescriptor<CompletionRecord>()
      let allCompletions = try modelContext.fetch(allCompletionsDescriptor)
      
      // Filter: records where habitId matches user's habits AND userId != newUserId
      let orphanedRecords = allCompletions.filter { record in
        userHabitIds.contains(record.habitId) && record.userId != userId
      }
      
      if !orphanedRecords.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(orphanedRecords.count) orphaned completion records to migrate")
        print("   Records have userId != '\(userId.prefix(8))...' but match user's habits")
        logger.info("🔄 GuestMigration: Migrating \(orphanedRecords.count) orphaned completion records...")
        
        // Group by old userId for logging
        let byOldUserId = Dictionary(grouping: orphanedRecords) { $0.userId }
        for (oldUserId, records) in byOldUserId {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          print("   Migrating \(records.count) records from userId '\(oldUserIdDisplay)'")
        }
        
        // Store old userIds before migration for verification
        let oldUserIdsBeforeMigration = Set(orphanedRecords.map { $0.userId })
        
        for record in orphanedRecords {
          record.userId = userId
          record.userIdHabitIdDateKey = "\(userId)#\(record.habitId.uuidString)#\(record.dateKey)"
          completionRecordsMigrated += 1
        }
        
        try modelContext.save()
        
        // Verify migration by checking that records now have new userId
        let verifyDescriptor = FetchDescriptor<CompletionRecord>(
          predicate: #Predicate<CompletionRecord> { record in
            userHabitIds.contains(record.habitId) && record.userId == userId
          }
        )
        let verifiedRecords = try modelContext.fetch(verifyDescriptor)
        
        print("✅ [GUEST_MIGRATION] Migrated \(completionRecordsMigrated) completion records successfully")
        print("   ✅ Verification: \(verifiedRecords.count) records now have userId '\(userId.prefix(8))...'")
        print("   ✅ Old userIds migrated from: \(oldUserIdsBeforeMigration.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." }.joined(separator: ", "))")
        logger.info("✅ GuestMigration: Migrated \(completionRecordsMigrated) completion records (verified: \(verifiedRecords.count))")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No orphaned completion records found to migrate")
      }
      
      // 3. Migrate DailyAwards
      // ✅ CRITICAL FIX: Find awards where userId != newUserId (orphaned awards)
      let allAwardsDescriptor = FetchDescriptor<DailyAward>()
      let allAwards = try modelContext.fetch(allAwardsDescriptor)
      
      // Filter: awards where userId != newUserId
      let orphanedAwards = allAwards.filter { $0.userId != userId }
      
      if !orphanedAwards.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(orphanedAwards.count) orphaned daily awards to migrate")
        print("   Awards have userId != '\(userId.prefix(8))...'")
        logger.info("🔄 GuestMigration: Migrating \(orphanedAwards.count) orphaned daily awards...")
        
        // Group by old userId for logging
        let byOldUserId = Dictionary(grouping: orphanedAwards) { $0.userId }
        for (oldUserId, awards) in byOldUserId {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          let xp = awards.reduce(0) { $0 + $1.xpGranted }
          print("   Migrating \(awards.count) awards from userId '\(oldUserIdDisplay)' (Total XP: \(xp))")
        }
        
        // Store old userIds before migration for verification
        let oldUserIdsBeforeMigration = Set(orphanedAwards.map { $0.userId })
        
        for award in orphanedAwards {
          award.userId = userId
          award.userIdDateKey = "\(userId)#\(award.dateKey)"
          totalMigratedXP += award.xpGranted
          dailyAwardsMigrated += 1
        }
        
        try modelContext.save()
        
        // Verify migration by checking that awards now have new userId
        let verifyAwardsDescriptor = FetchDescriptor<DailyAward>(
          predicate: #Predicate<DailyAward> { award in
            award.userId == userId
          }
        )
        let verifiedAwards = try modelContext.fetch(verifyAwardsDescriptor)
        let verifiedXP = verifiedAwards.reduce(0) { $0 + $1.xpGranted }
        
        print("✅ [GUEST_MIGRATION] Migrated \(dailyAwardsMigrated) daily awards successfully")
        print("   ✅ Total XP migrated: \(totalMigratedXP)")
        print("   ✅ Verification: \(verifiedAwards.count) awards now have userId '\(userId.prefix(8))...'")
        print("   ✅ Verified total XP: \(verifiedXP)")
        print("   ✅ Old userIds migrated from: \(oldUserIdsBeforeMigration.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." }.joined(separator: ", "))")
        logger.info("✅ GuestMigration: Migrated \(dailyAwardsMigrated) daily awards with \(totalMigratedXP) total XP (verified: \(verifiedAwards.count) awards, \(verifiedXP) XP)")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No orphaned daily awards found to migrate")
      }
      
      // 4. Migrate UserProgressData
      // ✅ CRITICAL FIX: Find progress where userId != newUserId (orphaned progress)
      let allProgressDescriptor = FetchDescriptor<UserProgressData>()
      let allProgress = try modelContext.fetch(allProgressDescriptor)
      
      // Filter: progress where userId != newUserId
      let orphanedProgress = allProgress.filter { $0.userId != userId }
      
      // If there are multiple orphaned progress records, merge them into one
      if !orphanedProgress.isEmpty {
        print("🔄 [GUEST_MIGRATION] Found \(orphanedProgress.count) orphaned user progress records to migrate")
        logger.info("🔄 GuestMigration: Migrating \(orphanedProgress.count) orphaned user progress records...")
        
        // Find or create progress for current user
        let userProgressDescriptor = FetchDescriptor<UserProgressData>(
          predicate: #Predicate<UserProgressData> { progress in
            progress.userId == userId
          }
        )
        var userProgress = try modelContext.fetch(userProgressDescriptor).first
        
        // If no user progress exists, use the first orphaned one
        if userProgress == nil, let firstOrphaned = orphanedProgress.first {
          userProgress = firstOrphaned
          print("   Using orphaned progress as base: XP=\(firstOrphaned.xpTotal), Level=\(firstOrphaned.level)")
        }
        
        // Merge all orphaned progress into user progress
        if let userProgress = userProgress {
          var maxXP = userProgress.xpTotal
          var maxLevel = userProgress.level
          var maxStreak = userProgress.streakDays
          
          for orphaned in orphanedProgress {
            if orphaned.xpTotal > maxXP {
              maxXP = orphaned.xpTotal
              maxLevel = orphaned.level
            }
            if orphaned.streakDays > maxStreak {
              maxStreak = orphaned.streakDays
            }
            
            // If this is not the one we're keeping, delete it
            if orphaned != userProgress {
              modelContext.delete(orphaned)
            }
          }
          
          // Store old values before migration for verification
          let oldUserIdsBeforeMigration = Set(orphanedProgress.map { $0.userId })
          
          // Update user progress with merged values
          userProgress.xpTotal = maxXP
          userProgress.level = maxLevel
          userProgress.streakDays = maxStreak
          userProgress.userId = userId
          
          try modelContext.save()
          
          // Verify migration by checking that progress now has new userId
          let verifyProgressDescriptor = FetchDescriptor<UserProgressData>(
            predicate: #Predicate<UserProgressData> { progress in
              progress.userId == userId
            }
          )
          let verifiedProgress = try modelContext.fetch(verifyProgressDescriptor).first
          
          print("✅ [GUEST_MIGRATION] Migrated user progress successfully")
          print("   ✅ Migrated XP: \(maxXP), Level: \(maxLevel), Streak: \(maxStreak)")
          if let verified = verifiedProgress {
            print("   ✅ Verification: UserProgressData now has userId '\(userId.prefix(8))...'")
            print("   ✅ Verified XP: \(verified.xpTotal), Level: \(verified.level)")
          }
          print("   ✅ Old userIds migrated from: \(oldUserIdsBeforeMigration.map { $0.isEmpty ? "EMPTY" : $0.prefix(8) + "..." }.joined(separator: ", "))")
          logger.info("✅ GuestMigration: Migrated user progress (XP: \(maxXP), Level: \(maxLevel)) - verified: \(verifiedProgress != nil)")
        }
      } else {
        print("ℹ️ [GUEST_MIGRATION] No orphaned user progress found to migrate")
      }
      
      // 5. Re-establish completionHistory relationships
      // ✅ CRITICAL FIX: After migrating CompletionRecords, re-link them to HabitData
      print("🔄 [GUEST_MIGRATION] Re-establishing completionHistory relationships...")
      logger.info("🔄 GuestMigration: Re-establishing completionHistory relationships...")
      
      var relationshipsFixed = 0
      for habitData in userHabits {
        // Find all CompletionRecords for this habit with the new userId
        let habitId = habitData.id
        let recordsDescriptor = FetchDescriptor<CompletionRecord>(
          predicate: #Predicate<CompletionRecord> { record in
            record.habitId == habitId && record.userId == userId
          }
        )
        let records = try modelContext.fetch(recordsDescriptor)
        
        // Clear existing relationship and re-add all records
        habitData.completionHistory.removeAll()
        for record in records {
          habitData.completionHistory.append(record)
        }
        
        if !records.isEmpty {
          relationshipsFixed += 1
          print("   ✅ Linked \(records.count) CompletionRecords to habit '\(habitData.name)'")
        }
      }
      
      if relationshipsFixed > 0 {
        try modelContext.save()
        print("✅ [GUEST_MIGRATION] Re-established relationships for \(relationshipsFixed) habits")
        logger.info("✅ GuestMigration: Re-established relationships for \(relationshipsFixed) habits")
      } else {
        print("ℹ️ [GUEST_MIGRATION] No relationships needed to be re-established")
      }
      
      // Summary log
      print("📊 [GUEST_MIGRATION] Migration Summary:")
      print("   ✅ Habits: \(guestHabits.count)")
      print("   ✅ Completion Records: \(completionRecordsMigrated)")
      print("   ✅ Daily Awards: \(dailyAwardsMigrated)")
      print("   ✅ Total XP from Awards: \(totalMigratedXP)")
      print("   ✅ Relationships Fixed: \(relationshipsFixed)")
      if let progress = try modelContext.fetch(FetchDescriptor<UserProgressData>(
        predicate: #Predicate<UserProgressData> { $0.userId == userId }
      )).first {
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

