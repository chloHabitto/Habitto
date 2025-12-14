//
//  GuestToAuthMigration.swift
//  Habitto
//
//  Migrates guest user data to authenticated user
//

import Foundation
import SwiftData
import OSLog

// MARK: - GuestToAuthMigration

/// Handles migrating guest user data when a user signs in (anonymously or with account)
@MainActor
final class GuestToAuthMigration {
  // MARK: Lifecycle
  
  private init() {}
  
  // MARK: Internal
  
  static let shared = GuestToAuthMigration()
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "GuestToAuthMigration")
  
  /// Migrate guest data to authenticated user if needed
  func migrateGuestDataIfNeeded(from guestUserId: String = "", to authUserId: String) async throws {
    let migrationKey = "GuestToAuthMigration_\(authUserId)"
    
    let container = SwiftDataContainer.shared.modelContainer
    let context = container.mainContext
    
    // ✅ CRITICAL FIX: Verify migration actually completed, not just flag set
    // Check if we've already migrated for this user
    if UserDefaults.standard.bool(forKey: migrationKey) {
      // Verify: Check if any data still exists with the old userId
      var verifyDescriptor = FetchDescriptor<HabitData>()
      if guestUserId.isEmpty {
        verifyDescriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == ""
        }
      } else {
        verifyDescriptor.predicate = #Predicate<HabitData> { habitData in
          habitData.userId == guestUserId
        }
      }
      
      let remainingHabits = try context.fetch(verifyDescriptor)
      
      if remainingHabits.isEmpty {
        // Migration actually completed - no data with old userId exists
        logger.info("✅ Guest data already migrated for user: \(authUserId) (verified)")
        return
      } else {
        // Flag was set but migration didn't complete - data still exists with old userId
        logger.warning("⚠️ Migration flag set but data still exists with old userId!")
        logger.warning("   Found \(remainingHabits.count) habits with userId '\(guestUserId.isEmpty ? "EMPTY" : guestUserId.prefix(8))...'")
        logger.warning("   Re-running migration to fix incomplete migration...")
        // Clear the flag and continue with migration
        UserDefaults.standard.removeObject(forKey: migrationKey)
      }
    }
    
    logger.info("🔄 Starting guest to auth migration...")
    logger.info("   From: \(guestUserId.isEmpty ? "guest (empty)" : guestUserId)")
    logger.info("   To: \(authUserId)")
    
    // Fetch all guest habits
    var guestDescriptor = FetchDescriptor<HabitData>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    
    if guestUserId.isEmpty {
      guestDescriptor.predicate = #Predicate<HabitData> { habitData in
        habitData.userId == ""
      }
    } else {
      guestDescriptor.predicate = #Predicate<HabitData> { habitData in
        habitData.userId == guestUserId
      }
    }
    
    let guestHabits = try context.fetch(guestDescriptor)
    
    guard !guestHabits.isEmpty else {
      logger.info("ℹ️ No guest habits to migrate")
      UserDefaults.standard.set(true, forKey: migrationKey)
      return
    }
    
    logger.info("📦 Found \(guestHabits.count) guest habits to migrate")
    
    // Update each habit's userId
    for habitData in guestHabits {
      let oldUserId = habitData.userId
      habitData.userId = authUserId
      logger.debug("  ✓ Migrated: '\(habitData.name)' from '\(oldUserId)' to '\(authUserId)'")
    }
    
    // Save changes
    try context.save()
    logger.info("✅ Saved migrated habits to SwiftData")
    
    // ✅ PRIORITY 1: Migrate ProgressEvents (event-sourcing source of truth)
    // Must migrate before other data to ensure event-sourcing integrity
    try await migrateProgressEvents(from: guestUserId, to: authUserId, context: context)
    
    // Migrate related data (DailyAwards, etc.)
    try await migrateDailyAwards(from: guestUserId, to: authUserId, context: context)
    try await migrateUserProgress(from: guestUserId, to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Migrate CompletionRecords (needed for XP and streak calculation)
    try await migrateCompletionRecords(from: guestUserId, to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Migrate GlobalStreakModel (needed for streak display)
    try await migrateGlobalStreakModel(from: guestUserId, to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Recalculate and save XP to FirestoreUserProgress
    try await recalculateAndSaveXP(to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Force final save to ensure all changes are persisted
    try context.save()
    logger.info("✅ Final save completed - all migrated data persisted")
    
    // ✅ CRITICAL FIX: Post notification to trigger @Query view refresh
    // This ensures SwiftData @Query views re-evaluate their predicates with the new userId
    await MainActor.run {
      NotificationCenter.default.post(name: .userDataMigrated, object: nil)
      logger.info("✅ Posted userDataMigrated notification - @Query views should refresh")
    }
    
    logger.info("✅ Guest to auth migration complete! Migrated \(guestHabits.count) habits")
    
    // Mark migration as complete
    UserDefaults.standard.set(true, forKey: migrationKey)
  }
  
  // MARK: Private
  
  /// Migrate ProgressEvents from guest to authenticated user
  ///
  /// ✅ PRIORITY 1: ProgressEvents are the source of truth for event-sourcing.
  /// Without this migration, event replay would fail for migrated habits.
  ///
  /// - Parameters:
  ///   - guestUserId: The guest user ID (empty string for true guest)
  ///   - authUserId: The authenticated user ID to migrate to
  ///   - context: The SwiftData ModelContext
  private func migrateProgressEvents(from guestUserId: String, to authUserId: String, context: ModelContext) async throws {
    var descriptor = FetchDescriptor<ProgressEvent>()
    
    if guestUserId.isEmpty {
      descriptor.predicate = #Predicate<ProgressEvent> { event in
        event.userId == ""
      }
    } else {
      descriptor.predicate = #Predicate<ProgressEvent> { event in
        event.userId == guestUserId
      }
    }
    
    let guestEvents = try context.fetch(descriptor)
    
    guard !guestEvents.isEmpty else {
      logger.info("ℹ️ No guest ProgressEvents to migrate")
      return
    }
    
    logger.info("📦 Migrating \(guestEvents.count) ProgressEvents...")
    logger.info("   From: \(guestUserId.isEmpty ? "guest (empty)" : guestUserId)")
    logger.info("   To: \(authUserId)")
    
    var migratedCount = 0
    
    for event in guestEvents {
      // Update userId
      event.userId = authUserId
      
      // ✅ NOTE: operationId doesn't need to be updated
      // operationId format: "{deviceId}_{timestamp}_{uuid}"
      // It's already unique per device+timestamp+uuid, so no userId needed
      // The ProgressEvent.id also doesn't contain userId, so it's fine as-is
      // Format: "evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}"
      
      migratedCount += 1
      
      if migratedCount % 100 == 0 {
        logger.debug("  📊 Migrated \(migratedCount) of \(guestEvents.count) ProgressEvents...")
      }
    }
    
    // Save all changes atomically
    try context.save()
    
    logger.info("✅ Migrated \(migratedCount) ProgressEvents")
    
    // ✅ VERIFICATION: Verify that all events were migrated
    let verifyDescriptor = FetchDescriptor<ProgressEvent>(
      predicate: #Predicate<ProgressEvent> { event in
        event.userId == (guestUserId.isEmpty ? "" : guestUserId)
      }
    )
    let remainingEvents = try context.fetch(verifyDescriptor)
    
    if !remainingEvents.isEmpty {
      logger.warning("⚠️ WARNING: \(remainingEvents.count) ProgressEvents still have guest userId after migration!")
      logger.warning("   This indicates a migration issue - some events may not have been migrated")
    } else {
      logger.info("✅ VERIFIED: All ProgressEvents successfully migrated (0 remaining with guest userId)")
    }
  }
  
  private func migrateDailyAwards(from guestUserId: String, to authUserId: String, context: ModelContext) async throws {
    var descriptor = FetchDescriptor<DailyAward>()
    
    if guestUserId.isEmpty {
      descriptor.predicate = #Predicate<DailyAward> { award in
        award.userId == ""
      }
    } else {
      descriptor.predicate = #Predicate<DailyAward> { award in
        award.userId == guestUserId
      }
    }
    
    let guestAwards = try context.fetch(descriptor)
    
    guard !guestAwards.isEmpty else {
      logger.info("ℹ️ No guest daily awards to migrate")
      return
    }
    
    logger.info("📦 Migrating \(guestAwards.count) daily awards...")
    
    for award in guestAwards {
      award.userId = authUserId
      award.userIdDateKey = "\(authUserId)#\(award.dateKey)"
    }
    
    try context.save()
    logger.info("✅ Migrated \(guestAwards.count) daily awards")
  }
  
  private func migrateUserProgress(from guestUserId: String, to authUserId: String, context: ModelContext) async throws {
    var descriptor = FetchDescriptor<UserProgressData>()
    
    if guestUserId.isEmpty {
      descriptor.predicate = #Predicate<UserProgressData> { progress in
        progress.userId == ""
      }
    } else {
      descriptor.predicate = #Predicate<UserProgressData> { progress in
        progress.userId == guestUserId
      }
    }
    
    let guestProgress = try context.fetch(descriptor)
    
    guard !guestProgress.isEmpty else {
      logger.info("ℹ️ No guest progress data to migrate")
      return
    }
    
    logger.info("📦 Migrating \(guestProgress.count) progress records...")
    
    for progress in guestProgress {
      progress.userId = authUserId
    }
    
    try context.save()
    logger.info("✅ Migrated \(guestProgress.count) progress records")
  }
  
  private func migrateCompletionRecords(from guestUserId: String, to authUserId: String, context: ModelContext) async throws {
    var descriptor = FetchDescriptor<CompletionRecord>()
    
    if guestUserId.isEmpty {
      descriptor.predicate = #Predicate<CompletionRecord> { record in
        record.userId == ""
      }
    } else {
      descriptor.predicate = #Predicate<CompletionRecord> { record in
        record.userId == guestUserId
      }
    }
    
    let guestRecords = try context.fetch(descriptor)
    
    guard !guestRecords.isEmpty else {
      logger.info("ℹ️ No guest completion records to migrate")
      return
    }
    
    logger.info("📦 Migrating \(guestRecords.count) completion records...")
    
    for record in guestRecords {
      record.userId = authUserId
      logger.debug("  ✓ Migrated CompletionRecord for habitId '\(record.habitId)' from userId '\(guestUserId.isEmpty ? "guest" : guestUserId)' to '\(authUserId)'")
    }
    
    try context.save()
    logger.info("✅ Migrated \(guestRecords.count) completion records")
  }
  
  private func migrateGlobalStreakModel(from guestUserId: String, to authUserId: String, context: ModelContext) async throws {
    var descriptor = FetchDescriptor<GlobalStreakModel>()
    
    if guestUserId.isEmpty {
      descriptor.predicate = #Predicate<GlobalStreakModel> { streak in
        streak.userId == ""
      }
    } else {
      descriptor.predicate = #Predicate<GlobalStreakModel> { streak in
        streak.userId == guestUserId
      }
    }
    
    let guestStreaks = try context.fetch(descriptor)
    
    guard !guestStreaks.isEmpty else {
      logger.info("ℹ️ No guest streak data to migrate")
      return
    }
    
    logger.info("📦 Migrating \(guestStreaks.count) streak record(s)...")
    
    // If there's already a streak model for the authenticated user, merge the data
    let authStreakDescriptor = FetchDescriptor<GlobalStreakModel>(
      predicate: #Predicate<GlobalStreakModel> { streak in
        streak.userId == authUserId
      }
    )
    let existingAuthStreak = try context.fetch(authStreakDescriptor).first
    
    if let guestStreak = guestStreaks.first {
      if let existingStreak = existingAuthStreak {
        // Merge: use the higher streak value
        existingStreak.currentStreak = max(existingStreak.currentStreak, guestStreak.currentStreak)
        existingStreak.longestStreak = max(existingStreak.longestStreak, guestStreak.longestStreak)
        // Use the most recent lastCompleteDate
        if let guestDate = guestStreak.lastCompleteDate,
           let existingDate = existingStreak.lastCompleteDate {
          existingStreak.lastCompleteDate = guestDate > existingDate ? guestDate : existingDate
        } else if guestStreak.lastCompleteDate != nil {
          existingStreak.lastCompleteDate = guestStreak.lastCompleteDate
        }
        logger.info("  ✓ Merged guest streak (current: \(guestStreak.currentStreak)) with existing streak (current: \(existingStreak.currentStreak))")
      } else {
        // Update guest streak's userId
        guestStreak.userId = authUserId
        logger.info("  ✓ Migrated streak: current=\(guestStreak.currentStreak), longest=\(guestStreak.longestStreak)")
      }
    }
    
    try context.save()
    logger.info("✅ Migrated streak data")
  }
  
  /// Recalculate XP from migrated DailyAwards and save to FirestoreUserProgress
  private func recalculateAndSaveXP(to authUserId: String, context: ModelContext) async throws {
    logger.info("🔄 Recalculating XP from migrated DailyAwards...")
    
    // Fetch all DailyAwards for the authenticated user
    let descriptor = FetchDescriptor<DailyAward>(
      predicate: #Predicate<DailyAward> { award in
        award.userId == authUserId
      },
      sortBy: [SortDescriptor(\.dateKey, order: .forward)]
    )
    
    let awards = try context.fetch(descriptor)
    
    guard !awards.isEmpty else {
      logger.info("ℹ️ No DailyAwards found for XP calculation")
      return
    }
    
    // Calculate total XP from all awards
    let totalXP = awards.reduce(0) { $0 + $1.xpGranted }
    logger.info("📊 Calculated totalXP=\(totalXP) from \(awards.count) awards")
    
    // Calculate level (using XPManager's formula: level = sqrt(totalXP / 300) + 1)
    let levelBaseXP = 300
    let level = Int(sqrt(Double(totalXP) / Double(levelBaseXP))) + 1
    logger.info("📊 Calculated level=\(level)")
    
    // Calculate today's XP
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    let todayKey = dateFormatter.string(from: Date())
    
    let todayAwards = awards.filter { $0.dateKey == todayKey }
    let dailyXP = todayAwards.reduce(0) { $0 + $1.xpGranted }
    logger.info("📊 Calculated dailyXP=\(dailyXP) for today (\(todayKey))")
    
    // Save to FirestoreUserProgress
    let progress = FirestoreUserProgress(
      totalXP: totalXP,
      level: level,
      dailyXP: dailyXP,
      lastUpdated: Date()
    )
    
    do {
      try await FirestoreService.shared.saveUserProgress(progress)
      logger.info("✅ Saved XP progress to Firestore: totalXP=\(totalXP), level=\(level), dailyXP=\(dailyXP)")
      
      // Reload XPManager to sync the new progress
      await MainActor.run {
        XPManager.shared.loadUserProgress()
      }
    } catch {
      logger.error("❌ Failed to save XP progress to Firestore: \(error.localizedDescription)")
      // Don't throw - migration can continue even if Firestore save fails
    }
  }
}

