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
    
    // Check if we've already migrated for this user
    if UserDefaults.standard.bool(forKey: migrationKey) {
      logger.info("✅ Guest data already migrated for user: \(authUserId)")
      return
    }
    
    logger.info("🔄 Starting guest to auth migration...")
    logger.info("   From: \(guestUserId.isEmpty ? "guest (empty)" : guestUserId)")
    logger.info("   To: \(authUserId)")
    
    let container = SwiftDataContainer.shared.modelContainer
    let context = container.mainContext
    
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
    
    // Migrate related data (DailyAwards, etc.)
    try await migrateDailyAwards(from: guestUserId, to: authUserId, context: context)
    try await migrateUserProgress(from: guestUserId, to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Migrate CompletionRecords (needed for XP and streak calculation)
    try await migrateCompletionRecords(from: guestUserId, to: authUserId, context: context)
    
    // ✅ CRITICAL FIX: Migrate GlobalStreakModel (needed for streak display)
    try await migrateGlobalStreakModel(from: guestUserId, to: authUserId, context: context)
    
    logger.info("✅ Guest to auth migration complete! Migrated \(guestHabits.count) habits")
    
    // Mark migration as complete
    UserDefaults.standard.set(true, forKey: migrationKey)
  }
  
  // MARK: Private
  
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
}

