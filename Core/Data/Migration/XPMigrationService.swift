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
    logger.info("🚀 Starting XP migration to Firestore...")
    
    // Check if already completed
    if await isMigrationComplete() {
      logger.info("✅ XP migration already completed, skipping")
      return
    }
    
    do {
      // Step 1: Migrate DailyAwards
      let migratedAwards = try await migrateDailyAwards(modelContext: modelContext)
      logger.info("✅ Migrated \(migratedAwards) daily awards")
      
      // Step 2: Calculate and migrate current progress
      try await migrateCurrentProgress(modelContext: modelContext)
      logger.info("✅ Migrated current progress")
      
      // Step 3: Mark migration as complete
      try await FirestoreService.shared.markXPMigrationComplete()
      logger.info("✅ XP migration completed successfully")
      
    } catch {
      logger.error("❌ XP migration failed: \(error)")
      throw error
    }
  }
  
  // MARK: Private
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "XPMigrationService")
  
  /// Migrate all DailyAward entities from SwiftData to Firestore
  private func migrateDailyAwards(modelContext: ModelContext) async throws -> Int {
    logger.info("📊 Migrating DailyAward entities...")
    
    // Fetch all DailyAward entities
    let descriptor = FetchDescriptor<DailyAward>(
      sortBy: [SortDescriptor(\.date, order: .forward)]
    )
    
    let awards = try modelContext.fetch(descriptor)
    logger.info("Found \(awards.count) DailyAward entities to migrate")
    
    var migratedCount = 0
    
    for award in awards {
      do {
        // Convert to Firestore model
        let firestoreAward = FirestoreDailyAward(from: award)
        
        // Save to Firestore
        try await FirestoreService.shared.saveDailyAward(firestoreAward)
        migratedCount += 1
        
        // Log progress every 10 awards
        if migratedCount % 10 == 0 {
          logger.info("Migrated \(migratedCount)/\(awards.count) awards...")
        }
      } catch {
        logger.warning("Failed to migrate award for date \(award.dateKey): \(error)")
        // Continue with next award
      }
    }
    
    logger.info("✅ Successfully migrated \(migratedCount) daily awards")
    return migratedCount
  }
  
  /// Calculate total XP from DailyAwards and migrate current progress
  private func migrateCurrentProgress(modelContext: ModelContext) async throws {
    logger.info("📊 Calculating current progress from DailyAwards...")
    
    // Fetch all DailyAward entities for current user
    // Note: Need to get current userId from AuthenticationManager
    guard let userId = await getCurrentUserId() else {
      logger.warning("No authenticated user, skipping progress migration")
      return
    }
    
    let predicate = #Predicate<DailyAward> { award in
      award.userId == userId
    }
    
    let descriptor = FetchDescriptor<DailyAward>(predicate: predicate)
    let awards = try modelContext.fetch(descriptor)
    
    // Calculate total XP
    let totalXP = awards.reduce(0) { $0 + $1.xp }
    
    // Calculate level (using XPManager's formula)
    let levelBaseXP = 300
    let level = Int(sqrt(Double(totalXP) / Double(levelBaseXP))) + 1
    
    // Get today's XP (awards from today)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    let todayKey = dateFormatter.string(from: Date())
    
    let todayAwards = awards.filter { $0.dateKey == todayKey }
    let dailyXP = todayAwards.reduce(0) { $0 + $1.xp }
    
    // Create Firestore progress
    let progress = FirestoreUserProgress(
      totalXP: totalXP,
      level: level,
      dailyXP: dailyXP,
      lastUpdated: Date()
    )
    
    // Save to Firestore
    try await FirestoreService.shared.saveUserProgress(progress)
    
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

