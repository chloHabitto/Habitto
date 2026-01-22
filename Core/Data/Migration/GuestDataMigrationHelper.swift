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
    
    logger.info("🔄 GuestMigration: FORCING migration (manual trigger) for user \(userId.prefix(8))...")
    
    // Clear the migration flag to allow re-migration
    UserDefaults.standard.removeObject(forKey: newMigrationKey)
    logger.info("   ✅ Cleared migration flag")
    
    // Run the migration
    await runCompleteMigration(userId: userId)
  }
  
  /// Run the complete migration (habits + completions + awards + progress)
  static func runCompleteMigration(userId: String) async {
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
        logger.info("✅ GuestMigration: Migrated \(guestHabits.count) habits")
      }
      
      // Get all user habits (including newly migrated ones) for later steps
      let allUserHabits = try modelContext.fetch(userHabitsDescriptor)
      
      // 2. Migrate ALL CompletionRecords (including standalone ones not linked via relationship)
      // ✅ CRITICAL FIX: Find records where userId != newUserId but habitId matches user's habits
      // This handles cases where habits were migrated but records still have old userId
      
      // Use the user habits we already fetched (or fetch again if needed)
      let userHabits = allUserHabits.isEmpty ? try modelContext.fetch(userHabitsDescriptor) : allUserHabits
      let userHabitIds = Set(userHabits.map { $0.id })
      
      
      // Find all CompletionRecords that match user's habits but have different userId
      let allCompletionsDescriptor = FetchDescriptor<CompletionRecord>()
      let allCompletions = try modelContext.fetch(allCompletionsDescriptor)
      
      // Filter: records where habitId matches user's habits AND userId != newUserId
      let orphanedRecords = allCompletions.filter { record in
        userHabitIds.contains(record.habitId) && record.userId != userId
      }
      
      if !orphanedRecords.isEmpty {
        print("   Records have userId != '\(userId.prefix(8))...' but match user's habits")
        logger.info("🔄 GuestMigration: Migrating \(orphanedRecords.count) orphaned completion records...")
        
        // Group by old userId for logging
        let byOldUserId = Dictionary(grouping: orphanedRecords) { $0.userId }
        for (oldUserId, records) in byOldUserId {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          print("   Migrating \(records.count) records from userId '\(oldUserIdDisplay)'")
        }
        
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
        
        logger.info("✅ GuestMigration: Migrated \(completionRecordsMigrated) completion records (verified: \(verifiedRecords.count))")
      }
      
      // 3. Migrate DailyAwards
      // ✅ CRITICAL FIX: Find awards where userId != newUserId (orphaned awards)
      let allAwardsDescriptor = FetchDescriptor<DailyAward>()
      let allAwards = try modelContext.fetch(allAwardsDescriptor)
      
      // Filter: awards where userId != newUserId
      let orphanedAwards = allAwards.filter { $0.userId != userId }
      
      if !orphanedAwards.isEmpty {
        print("   Awards have userId != '\(userId.prefix(8))...'")
        logger.info("🔄 GuestMigration: Migrating \(orphanedAwards.count) orphaned daily awards...")
        
        // Group by old userId for logging
        let byOldUserId = Dictionary(grouping: orphanedAwards) { $0.userId }
        for (oldUserId, awards) in byOldUserId {
          let oldUserIdDisplay = oldUserId.isEmpty ? "EMPTY STRING" : "\(oldUserId.prefix(8))..."
          let xp = awards.reduce(0) { $0 + $1.xpGranted }
          print("   Migrating \(awards.count) awards from userId '\(oldUserIdDisplay)' (Total XP: \(xp))")
        }
        
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
        
        logger.info("✅ GuestMigration: Migrated \(dailyAwardsMigrated) daily awards with \(totalMigratedXP) total XP (verified: \(verifiedAwards.count) awards, \(verifiedXP) XP)")
      }
      
      // 4. Migrate UserProgressData
      // ✅ CRITICAL FIX: Find progress where userId != newUserId (orphaned progress)
      let allProgressDescriptor = FetchDescriptor<UserProgressData>()
      let allProgress = try modelContext.fetch(allProgressDescriptor)
      
      // Filter: progress where userId != newUserId
      let orphanedProgress = allProgress.filter { $0.userId != userId }
      
      // If there are multiple orphaned progress records, merge them into one
      if !orphanedProgress.isEmpty {
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
          if let _ = verifiedProgress {
            print("   ✅ Verification: UserProgressData now has userId '\(userId.prefix(8))...'")
            logger.info("✅ GuestMigration: Migrated user progress (XP: \(maxXP), Level: \(maxLevel)) - verified: \(verifiedProgress != nil)")
          }
        }
      }
      
      // 5. Re-establish completionHistory relationships
      // ✅ CRITICAL FIX: After migrating CompletionRecords, re-link them to HabitData
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
      }
      
      // Summary log
      logger.info("📊 GuestMigration: Summary - \(guestHabits.count) habits, \(completionRecordsMigrated) completions, \(dailyAwardsMigrated) awards, \(totalMigratedXP) XP")
      
      // Mark migration as complete
      let newMigrationKey = "guest_to_anonymous_complete_migrated_\(userId)"
      UserDefaults.standard.set(true, forKey: newMigrationKey)
      logger.info("✅ GuestMigration: COMPLETE migration finished for user \(userId.prefix(8))...")
      
    } catch {
      logger.error("❌ GuestMigration: Failed to migrate guest data: \(error.localizedDescription)")
    }
  }
}

