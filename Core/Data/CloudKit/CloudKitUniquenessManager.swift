import Foundation
import SwiftData
import OSLog

/// Manages uniqueness constraints for CloudKit sync
///
/// **Purpose:** Ensures data integrity when CloudKit sync is enabled
/// **Why:** CloudKit doesn't enforce unique constraints, but SwiftData does locally.
/// This manager adds application-level uniqueness checks and post-sync deduplication.
///
/// **Usage:**
/// ```swift
/// // Before creating a habit
/// if let existing = try CloudKitUniquenessManager.shared.ensureUniqueHabit(
///   id: newHabitId,
///   in: modelContext
/// ) {
///   return existing  // Use existing instead of creating duplicate
/// }
///
/// // After CloudKit sync
/// try CloudKitUniquenessManager.shared.deduplicateAll(in: modelContext)
/// ```
@MainActor
final class CloudKitUniquenessManager {
  // MARK: - Singleton
  
  static let shared = CloudKitUniquenessManager()
  
  // MARK: - Properties
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "UniquenessManager")
  
  // MARK: - Lifecycle
  
  private init() {
    logger.info("✅ CloudKitUniquenessManager initialized")
  }
  
  // MARK: - HabitData Uniqueness
  
  /// Ensures HabitData ID is unique before insert
  ///
  /// - Parameters:
  ///   - id: The UUID to check for uniqueness
  ///   - context: The ModelContext to search in
  /// - Returns: Existing HabitData if duplicate found, nil if unique
  /// - Throws: Errors from fetch operations
  func ensureUniqueHabit(
    id: UUID,
    in context: ModelContext
  ) throws -> HabitData? {
    let predicate = #Predicate<HabitData> { habit in
      habit.id == id
    }
    let request = FetchDescriptor<HabitData>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingHabit = existing.first {
      logger.warning("⚠️ Duplicate HabitData found with id: \(id.uuidString), name: '\(existingHabit.name)'")
      return existingHabit  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - CompletionRecord Uniqueness
  
  /// Ensures CompletionRecord is unique before insert
  ///
  /// - Parameters:
  ///   - userId: User ID for the completion
  ///   - habitId: Habit ID for the completion
  ///   - dateKey: Date key (yyyy-MM-dd format)
  ///   - context: The ModelContext to search in
  /// - Returns: Existing CompletionRecord if duplicate found, nil if unique
  /// - Throws: Errors from fetch operations
  func ensureUniqueCompletion(
    userId: String,
    habitId: UUID,
    dateKey: String,
    in context: ModelContext
  ) throws -> CompletionRecord? {
    let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
    
    let predicate = #Predicate<CompletionRecord> { record in
      record.userIdHabitIdDateKey == uniqueKey
    }
    let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingRecord = existing.first {
      logger.info("ℹ️ Duplicate CompletionRecord found for habit \(habitId.uuidString) on \(dateKey), returning existing")
      return existingRecord  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - DailyAward Uniqueness
  
  /// Ensures DailyAward is unique before insert
  ///
  /// - Parameters:
  ///   - userId: User ID for the award
  ///   - dateKey: Date key (yyyy-MM-dd format)
  ///   - context: The ModelContext to search in
  /// - Returns: Existing DailyAward if duplicate found, nil if unique
  /// - Throws: Errors from fetch operations
  func ensureUniqueDailyAward(
    userId: String,
    dateKey: String,
    in context: ModelContext
  ) throws -> DailyAward? {
    let uniqueKey = "\(userId)#\(dateKey)"
    
    let predicate = #Predicate<DailyAward> { award in
      award.userIdDateKey == uniqueKey
    }
    let request = FetchDescriptor<DailyAward>(predicate: predicate)
    let existing = try context.fetch(request)
    
    if let existingAward = existing.first {
      logger.info("ℹ️ Duplicate DailyAward found for user \(userId) on \(dateKey), returning existing")
      return existingAward  // Return existing instead of creating duplicate
    }
    
    return nil  // No duplicate, safe to create
  }
  
  // MARK: - Deduplication (Post-Sync Cleanup)
  
  /// Removes duplicate habits after CloudKit sync
  ///
  /// **Strategy:** Keep the most recently updated habit, delete others
  ///
  /// - Parameter context: The ModelContext to deduplicate in
  /// - Throws: Errors from fetch or save operations
  func deduplicateHabits(in context: ModelContext) throws {
    logger.info("🔍 Starting habit deduplication...")
    
    // Group habits by ID
    let allHabits = try context.fetch(FetchDescriptor<HabitData>())
    let grouped = Dictionary(grouping: allHabits) { $0.id }
    
    var duplicatesRemoved = 0
    
    for (id, habits) in grouped where habits.count > 1 {
      logger.warning("⚠️ Found \(habits.count) duplicate habits with id: \(id.uuidString)")
      
      // Keep the most recently updated one
      let sorted = habits.sorted { $0.updatedAt > $1.updatedAt }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Log details
      logger.info("   Keeping: '\(keep.name)' (updated: \(keep.updatedAt))")
      for duplicate in duplicates {
        logger.info("   Removing: '\(duplicate.name)' (updated: \(duplicate.updatedAt))")
      }
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate habits")
    } else {
      logger.info("✅ No duplicate habits found")
    }
  }
  
  /// Removes duplicate completion records after CloudKit sync
  ///
  /// **Strategy:** Keep the most recently updated completion, delete others
  ///
  /// - Parameter context: The ModelContext to deduplicate in
  /// - Throws: Errors from fetch or save operations
  func deduplicateCompletions(in context: ModelContext) throws {
    logger.info("🔍 Starting completion deduplication...")
    
    // Group completions by unique key
    let allCompletions = try context.fetch(FetchDescriptor<CompletionRecord>())
    let grouped = Dictionary(grouping: allCompletions) { $0.userIdHabitIdDateKey }
    
    var duplicatesRemoved = 0
    
    for (key, completions) in grouped where completions.count > 1 {
      logger.warning("⚠️ Found \(completions.count) duplicate completions with key: \(key)")
      
      // Keep the most recently updated one
      let sorted = completions.sorted { 
        ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) 
      }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Log details
      let updatedStr = keep.updatedAt?.description ?? "unknown"
      logger.info("   Keeping: completion (updated: \(updatedStr), progress: \(keep.progress))")
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate completions")
    } else {
      logger.info("✅ No duplicate completions found")
    }
  }
  
  /// Removes duplicate daily awards after CloudKit sync
  ///
  /// **Strategy:** Keep the award with highest XP (or most recent if tied)
  ///
  /// - Parameter context: The ModelContext to deduplicate in
  /// - Throws: Errors from fetch or save operations
  func deduplicateDailyAwards(in context: ModelContext) throws {
    logger.info("🔍 Starting daily award deduplication...")
    
    // Group awards by unique key
    let allAwards = try context.fetch(FetchDescriptor<DailyAward>())
    let grouped = Dictionary(grouping: allAwards) { $0.userIdDateKey }
    
    var duplicatesRemoved = 0
    
    for (key, awards) in grouped where awards.count > 1 {
      logger.warning("⚠️ Found \(awards.count) duplicate awards with key: \(key)")
      
      // Keep the one with highest XP (or most recent if tied)
      let sorted = awards.sorted { 
        if $0.xpGranted != $1.xpGranted {
          return $0.xpGranted > $1.xpGranted
        }
        return $0.createdAt > $1.createdAt
      }
      let keep = sorted.first!
      let duplicates = Array(sorted.dropFirst())
      
      // Log details
      logger.info("   Keeping: award with \(keep.xpGranted) XP (created: \(keep.createdAt))")
      
      // Delete duplicates
      for duplicate in duplicates {
        context.delete(duplicate)
        duplicatesRemoved += 1
      }
    }
    
    if duplicatesRemoved > 0 {
      try context.save()
      logger.info("✅ Removed \(duplicatesRemoved) duplicate awards")
    } else {
      logger.info("✅ No duplicate awards found")
    }
  }
  
  /// Run all deduplication checks
  ///
  /// **Usage:** Call this after CloudKit sync completes to clean up any duplicates
  ///
  /// - Parameter context: The ModelContext to deduplicate in
  /// - Throws: Errors from fetch or save operations
  func deduplicateAll(in context: ModelContext) throws {
    logger.info("🔄 Running full deduplication check...")
    try deduplicateHabits(in: context)
    try deduplicateCompletions(in: context)
    try deduplicateDailyAwards(in: context)
    logger.info("✅ Deduplication complete")
  }
  
  // MARK: - Statistics
  
  /// Get statistics about potential duplicates (for monitoring)
  ///
  /// - Parameter context: The ModelContext to check
  /// - Returns: Dictionary with counts of potential duplicates
  func getDuplicateStatistics(in context: ModelContext) throws -> [String: Int] {
    var stats: [String: Int] = [:]
    
    // Check habits
    let allHabits = try context.fetch(FetchDescriptor<HabitData>())
    let habitGroups = Dictionary(grouping: allHabits) { $0.id }
    let duplicateHabits = habitGroups.filter { $0.value.count > 1 }.count
    stats["duplicateHabits"] = duplicateHabits
    
    // Check completions
    let allCompletions = try context.fetch(FetchDescriptor<CompletionRecord>())
    let completionGroups = Dictionary(grouping: allCompletions) { $0.userIdHabitIdDateKey }
    let duplicateCompletions = completionGroups.filter { $0.value.count > 1 }.count
    stats["duplicateCompletions"] = duplicateCompletions
    
    // Check awards
    let allAwards = try context.fetch(FetchDescriptor<DailyAward>())
    let awardGroups = Dictionary(grouping: allAwards) { $0.userIdDateKey }
    let duplicateAwards = awardGroups.filter { $0.value.count > 1 }.count
    stats["duplicateAwards"] = duplicateAwards
    
    return stats
  }
}

