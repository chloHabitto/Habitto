import Foundation
import SwiftData
import OSLog

/// Service for repairing orphaned data (data stuck in wrong userId)
@MainActor
final class DataRepairService {
  static let shared = DataRepairService()
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "DataRepair")
  
  private init() {}
  
  /// Scan for orphaned data and return summary
  func scanForOrphanedData() async throws -> OrphanedDataSummary {
    let modelContext = SwiftDataContainer.shared.modelContext
    let currentUserId = await CurrentUser().idOrGuest
    
    logger.info("🔍 DataRepair: Scanning for orphaned data...")
    logger.info("   Current userId: '\(currentUserId.isEmpty ? "EMPTY (guest)" : currentUserId.prefix(8))...'")
    
    // Get all unique userIds in the database
    let allHabits = try modelContext.fetch(FetchDescriptor<HabitData>())
    let allCompletions = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
    let allAwards = try modelContext.fetch(FetchDescriptor<DailyAward>())
    let allStreaks = try modelContext.fetch(FetchDescriptor<GlobalStreakModel>())
    let allProgress = try modelContext.fetch(FetchDescriptor<UserProgressData>())
    
    // Find all unique userIds (excluding current user)
    var userIds = Set<String>()
    for habit in allHabits {
      if habit.userId != currentUserId && !habit.userId.isEmpty {
        userIds.insert(habit.userId)
      }
    }
    for record in allCompletions {
      if record.userId != currentUserId && !record.userId.isEmpty {
        userIds.insert(record.userId)
      }
    }
    for award in allAwards {
      if award.userId != currentUserId && !award.userId.isEmpty {
        userIds.insert(award.userId)
      }
    }
    for streak in allStreaks {
      if streak.userId != currentUserId && !streak.userId.isEmpty {
        userIds.insert(streak.userId)
      }
    }
    for progress in allProgress {
      if progress.userId != currentUserId && !progress.userId.isEmpty {
        userIds.insert(progress.userId)
      }
    }
    
    logger.info("🔍 DataRepair: Found \(userIds.count) orphaned userId(s)")
    
    // Group data by orphaned userId
    var orphanedDataByUserId: [String: OrphanedDataCount] = [:]
    
    for orphanedUserId in userIds {
      let habits = allHabits.filter { $0.userId == orphanedUserId }
      let completions = allCompletions.filter { $0.userId == orphanedUserId }
      let awards = allAwards.filter { $0.userId == orphanedUserId }
      let streaks = allStreaks.filter { $0.userId == orphanedUserId }
      let progress = allProgress.filter { $0.userId == orphanedUserId }
      
      // Calculate total XP from awards
      let totalXP = awards.reduce(0) { $0 + $1.xpGranted }
      
      orphanedDataByUserId[orphanedUserId] = OrphanedDataCount(
        habits: habits.count,
        completions: completions.count,
        awards: awards.count,
        streaks: streaks.count,
        progress: progress.count,
        totalXP: totalXP
      )
      
      logger.info("   → userId '\(orphanedUserId.prefix(8))...': \(habits.count) habits, \(completions.count) completions, \(awards.count) awards (\(totalXP) XP), \(streaks.count) streaks")
    }
    
    return OrphanedDataSummary(
      currentUserId: currentUserId,
      orphanedUserIds: Array(userIds),
      dataByUserId: orphanedDataByUserId
    )
  }
  
  /// Migrate all orphaned data to current user
  func migrateOrphanedData(from orphanedUserId: String, to currentUserId: String) async throws {
    logger.info("🔄 DataRepair: Migrating orphaned data...")
    logger.info("   From: '\(orphanedUserId.prefix(8))...'")
    logger.info("   To: '\(currentUserId.prefix(8))...'")
    
    // Use existing GuestToAuthMigration which handles all data types
    try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(
      from: orphanedUserId,
      to: currentUserId
    )
    
    logger.info("✅ DataRepair: Migration completed successfully")
  }
  
  /// Migrate all orphaned data from all orphaned userIds
  func migrateAllOrphanedData() async throws -> OrphanedDataRepairResult {
    let summary = try await scanForOrphanedData()
    
    guard !summary.orphanedUserIds.isEmpty else {
      logger.info("ℹ️ DataRepair: No orphaned data found")
      return OrphanedDataRepairResult(
        success: true,
        migratedUserIds: [],
        totalHabits: 0,
        totalXP: 0,
        message: "No orphaned data found"
      )
    }
    
    let currentUserId = summary.currentUserId
    var migratedUserIds: [String] = []
    var totalHabits = 0
    var totalXP = 0
    
    for orphanedUserId in summary.orphanedUserIds {
      if let dataCount = summary.dataByUserId[orphanedUserId] {
        logger.info("🔄 DataRepair: Migrating data from '\(orphanedUserId.prefix(8))...'")
        
        try await migrateOrphanedData(from: orphanedUserId, to: currentUserId)
        
        migratedUserIds.append(orphanedUserId)
        totalHabits += dataCount.habits
        totalXP += dataCount.totalXP
      }
    }
    
    return OrphanedDataRepairResult(
      success: true,
      migratedUserIds: migratedUserIds,
      totalHabits: totalHabits,
      totalXP: totalXP,
      message: "Migrated \(totalHabits) habits and \(totalXP) XP from \(migratedUserIds.count) previous session(s)"
    )
  }
}

// MARK: - Data Models

struct OrphanedDataSummary {
  let currentUserId: String
  let orphanedUserIds: [String]
  let dataByUserId: [String: OrphanedDataCount]
  
  var hasOrphanedData: Bool {
    !orphanedUserIds.isEmpty
  }
  
  var totalHabits: Int {
    dataByUserId.values.reduce(0) { $0 + $1.habits }
  }
  
  var totalXP: Int {
    dataByUserId.values.reduce(0) { $0 + $1.totalXP }
  }
  
  var description: String {
    if !hasOrphanedData {
      return "No orphaned data found"
    }
    
    let habitsText = totalHabits == 1 ? "habit" : "habits"
    let sessionsText = orphanedUserIds.count == 1 ? "previous session" : "previous sessions"
    
    return "Found \(totalHabits) \(habitsText) and \(totalXP) XP from \(orphanedUserIds.count) \(sessionsText)."
  }
}

struct OrphanedDataCount {
  let habits: Int
  let completions: Int
  let awards: Int
  let streaks: Int
  let progress: Int
  let totalXP: Int
}

struct OrphanedDataRepairResult {
  let success: Bool
  let migratedUserIds: [String]
  let totalHabits: Int
  let totalXP: Int
  let message: String
}
