//
//  XPMigrationService.swift
//  Habitto
//
//  Service for migrating XP/Progress data from SwiftData to Firestore
//

import Foundation
import SwiftData
import OSLog

// MARK: - XPMigrationService

/// Handles one-time migration of XP data from SwiftData to Firestore
@MainActor
class XPMigrationService {
  // MARK: Lifecycle
  
  private init() { }
  
  // MARK: Internal
  
  static let shared = XPMigrationService()
  
  // MARK: - Migration Status
  
  /// Check if XP migration has been completed
  func isMigrationComplete() async -> Bool {
    do {
      return try await FirestoreService.shared.isXPMigrationComplete()
    } catch {
      logger.error("Failed to check XP migration status: \(error)")
      return false
    }
  }
  
  /// Perform XP migration from SwiftData to Firestore
  func performMigration(modelContext: ModelContext) async throws {
    // Get userId early for logging
    let userId = await getCurrentUserId() ?? "unknown"
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔄 XP_MIGRATION_START: userId=\(userId)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    logger.info("🔄 Starting XP migration for userId: \(userId)")
    
    // ✅ FIX: Yield immediately to let UI update with spinner
    await Task.yield()
    
    // Check if already completed
    if await isMigrationComplete() {
      print("✅ XP_MIGRATION_COMPLETE: Migration already completed, skipping")
      logger.info("✅ XP migration already completed, skipping")
      return
    }
    
    do {
      // Step 1: Migrate DailyAwards
      print("📊 XP_MIGRATION: Step 1 - Migrating DailyAwards...")
      await Task.yield() // Let UI breathe
      let migratedAwards = try await migrateDailyAwards(modelContext: modelContext)
      print("✅ XP_MIGRATION: Step 1 Complete - Migrated \(migratedAwards) daily awards")
      logger.info("✅ Migrated \(migratedAwards) daily awards")
      
      // Step 2: Calculate and migrate current progress
      print("📊 XP_MIGRATION: Step 2 - Calculating and migrating current progress...")
      await Task.yield() // Let UI breathe
      try await migrateCurrentProgress(modelContext: modelContext)
      print("✅ XP_MIGRATION: Step 2 Complete - Migrated current progress")
      logger.info("✅ Migrated current progress")
      
      // Step 3: Mark migration as complete
      print("📊 XP_MIGRATION: Step 3 - Marking migration as complete...")
      await Task.yield() // Let UI breathe
      try await FirestoreService.shared.markXPMigrationComplete()
      print("✅ XP_MIGRATION: Step 3 Complete - Migration marked as complete")
      logger.info("✅ XP migration completed successfully")
      
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      print("✅ XP_MIGRATION_COMPLETE: All data migrated successfully")
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      
    } catch {
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      print("❌ XP_MIGRATION: MIGRATION FAILED!")
      print("   Error: \(error.localizedDescription)")
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      logger.error("❌ XP migration failed: \(error)")
      throw error
    }
  }
  
  // MARK: Private
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "XPMigrationService")
  
  /// Migrate all DailyAward entities from SwiftData to Firestore
  private func migrateDailyAwards(modelContext: ModelContext) async throws -> Int {
    print("🔄 XP_MIGRATION: Fetching DailyAward entities from SwiftData...")
    logger.info("📊 Migrating DailyAward entities...")
    
    // Fetch all DailyAward entities
    // ✅ FIX: Sort by dateKey (stored property) instead of date (computed property)
    // SwiftData can only sort by stored properties, not computed ones
    let descriptor = FetchDescriptor<DailyAward>(
      sortBy: [SortDescriptor(\.dateKey, order: .forward)]
    )
    
    let awards = try modelContext.fetch(descriptor)
    print("🔄 XP_MIGRATION: Found \(awards.count) DailyAwards in SwiftData")
    logger.info("Found \(awards.count) DailyAward entities to migrate")
    
    var migratedCount = 0
    var failedCount = 0
    let totalAwards = awards.count
    
    for (index, award) in awards.enumerated() {
      // ✅ FIX: Yield every award to prevent blocking
      await Task.yield()
      
      do {
        // Convert to Firestore model
        let firestoreAward = FirestoreDailyAward(from: award)
        
        // Save to Firestore
        try await FirestoreService.shared.saveDailyAward(firestoreAward)
        migratedCount += 1
        
        // Log progress every 10 awards or on first/last award
        if index == 0 || index == totalAwards - 1 || (migratedCount % 10 == 0) {
          print("🔄 XP_MIGRATION_PROGRESS: Migrated \(migratedCount)/\(totalAwards) awards")
          logger.info("Migrated \(migratedCount)/\(totalAwards) awards...")
        }
      } catch {
        failedCount += 1
        print("   ⚠️ Failed to migrate award for date \(award.dateKey): \(error.localizedDescription)")
        logger.warning("Failed to migrate award for date \(award.dateKey): \(error)")
        // Continue with next award
      }
    }
    
    print("✅ XP_MIGRATION: Successfully migrated \(migratedCount) daily awards")
    if failedCount > 0 {
      print("⚠️ XP_MIGRATION: Failed to migrate \(failedCount) awards")
    }
    logger.info("✅ Successfully migrated \(migratedCount) daily awards")
    return migratedCount
  }
  
  /// Calculate total XP from DailyAwards and migrate current progress
  private func migrateCurrentProgress(modelContext: ModelContext) async throws {
    print("🔄 XP_MIGRATION: Calculating current progress from DailyAwards...")
    logger.info("📊 Calculating current progress from DailyAwards...")
    
    // Get current user ID
    guard let userId = await getCurrentUserId() else {
      print("⚠️ XP_MIGRATION: No authenticated user, skipping progress migration")
      logger.warning("No authenticated user, skipping progress migration")
      return
    }
    
    print("🔄 XP_MIGRATION: Fetching ALL awards (including those without userId)...")
    
    // ✅ FIX: Fetch ALL DailyAwards, not just ones matching current userId
    // This handles cases where old awards were created before userId was tracked properly
    // or when migrating from guest mode to authenticated mode
    let descriptor = FetchDescriptor<DailyAward>(
      sortBy: [SortDescriptor(\.dateKey, order: .forward)]
    )
    let awards = try modelContext.fetch(descriptor)
    
    print("🔄 XP_MIGRATION: Found \(awards.count) total awards to process")
    logger.info("Found \(awards.count) total awards")
    
    // ✅ FIX: Update userId for all awards to current user during migration
    // This ensures all existing awards are associated with the authenticated user
    var updatedCount = 0
    for award in awards where award.userId != userId {
      award.userId = userId
      award.userIdDateKey = "\(userId)#\(award.dateKey)"
      updatedCount += 1
    }
    
    if updatedCount > 0 {
      try modelContext.save()
      print("🔄 XP_MIGRATION: Updated userId for \(updatedCount) awards")
      logger.info("Updated userId for \(updatedCount) awards to \(userId)")
    }
    
    // Calculate total XP from ALL awards
    let totalXP = awards.reduce(0) { $0 + $1.xp }
    print("🔄 XP_MIGRATION: Calculated totalXP=\(totalXP)")
    
    // Calculate level (using XPManager's formula)
    let levelBaseXP = 300
    let level = Int(sqrt(Double(totalXP) / Double(levelBaseXP))) + 1
    print("🔄 XP_MIGRATION: Calculated level=\(level)")
    
    // Get today's XP (awards from today)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    let todayKey = dateFormatter.string(from: Date())
    
    let todayAwards = awards.filter { $0.dateKey == todayKey }
    let dailyXP = todayAwards.reduce(0) { $0 + $1.xp }
    print("🔄 XP_MIGRATION: Calculated dailyXP=\(dailyXP) for today (\(todayKey))")
    
    // Create Firestore progress
    let progress = FirestoreUserProgress(
      totalXP: totalXP,
      level: level,
      dailyXP: dailyXP,
      lastUpdated: Date()
    )
    
    print("🔄 XP_MIGRATION: Saving progress to Firestore...")
    print("   totalXP: \(progress.totalXP)")
    print("   level: \(progress.level)")
    print("   dailyXP: \(progress.dailyXP)")
    
    // Save to Firestore
    try await FirestoreService.shared.saveUserProgress(progress)
    
    print("✅ XP_MIGRATION: Current progress migrated successfully")
    logger.info("✅ Migrated current progress (totalXP: \(totalXP), level: \(level), dailyXP: \(dailyXP))")
  }
  
  /// Get current user ID from Firebase Auth
  private func getCurrentUserId() async -> String? {
    // Import FirebaseAuth to get current user
    await MainActor.run {
      AuthenticationManager.shared.currentUser?.uid
    }
  }
}

// MARK: - DailyAward Extension for Migration

extension DailyAward {
  /// Computed property to get date from dateKey
  var date: Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    return dateFormatter.date(from: dateKey) ?? createdAt
  }
  
  /// Computed property for XP (backward compatible)
  var xp: Int {
    xpGranted
  }
}

