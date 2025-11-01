import Foundation
import SwiftData
import OSLog
import UIKit

/// Migration service to convert existing CompletionRecord entries to event-sourced ProgressEvent records
///
/// This migration:
/// 1. Fetches all CompletionRecord entries with progress > 0
/// 2. For each record, creates a synthetic ProgressEvent:
///    - type: .bulkAdjust (for migration/correction)
///    - amount: currentProgress value
///    - operationId: "migration_{recordId}"
///    - deviceId: "migration"
/// 3. Updates CompletionRecord.eventIds to reference the new event (if such field exists)
/// 4. Runs as a one-time migration (tracked in migration state)
class MigrateCompletionsToEvents {
  // MARK: - Lifecycle
  
  private init() { }
  
  // MARK: - Internal
  
  static let shared = MigrateCompletionsToEvents()
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "MigrateCompletionsToEvents")
  
  /// Checks if migration is needed and performs it if necessary
  func performMigrationIfNeeded() async {
    guard !isMigrationCompleted() else {
      logger.info("🔄 MIGRATION: Completion to Event migration already completed")
      return
    }
    
    logger.info("🔄 MIGRATION: Starting completion to event migration...")
    
    // Log migration start for crash debugging
    CrashlyticsService.shared.logMigrationStart(migrationName: "CompletionsToEvents")
    
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      // Fetch all CompletionRecord entries with progress > 0
      let predicate = #Predicate<CompletionRecord> { record in
        record.progress > 0
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      
      guard let completionRecords = try? modelContext.fetch(descriptor) else {
        logger.error("❌ MIGRATION: Failed to fetch CompletionRecord entries")
        return
      }
      
      logger.info("🔄 MIGRATION: Found \(completionRecords.count) completion records to migrate")
      CrashlyticsService.shared.setValue("\(completionRecords.count)", forKey: "migration_completion_count")
      
      var migratedCount = 0
      var skippedCount = 0
      
      // Get device ID for migration (use a consistent identifier)
      let deviceId = "migration_\(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")"
      let timezoneIdentifier = TimeZone.current.identifier
      
      for record in completionRecords {
        // Check if event already exists for this record (idempotency)
        let operationId = "migration_\(record.userIdHabitIdDateKey)"
        
        let eventPredicate = #Predicate<ProgressEvent> { event in
          event.operationId == operationId
        }
        let eventDescriptor = FetchDescriptor<ProgressEvent>(predicate: eventPredicate)
        
        // Check if event already exists (idempotency check)
        // Use optional chaining: if fetch succeeds and array is not empty, skip
        if let existingEvents = try? modelContext.fetch(eventDescriptor), !existingEvents.isEmpty {
          // Event already exists, skip
          skippedCount += 1
          continue
        }
        
        // Calculate UTC day boundaries for the date
        let utcDayBoundaries = calculateUTCDayBoundaries(for: record.date)
        
        // Create synthetic ProgressEvent
        // Use .bulkAdjust for migration events (as specified in ProgressEventType enum)
        let event = ProgressEvent(
          habitId: record.habitId,
          dateKey: record.dateKey,
          eventType: .bulkAdjust,
          progressDelta: record.progress, // The amount is the current progress value
          userId: record.userId,
          deviceId: deviceId,
          timezoneIdentifier: timezoneIdentifier,
          utcDayStart: utcDayBoundaries.start,
          utcDayEnd: utcDayBoundaries.end,
          note: "Migrated from CompletionRecord",
          metadata: "{\"migration\":true,\"originalCreatedAt\":\"\(record.createdAt.iso8601)\"}",
          operationId: operationId
        )
        
        // Use the record's original createdAt as the event's occurredAt
        event.occurredAt = record.createdAt
        event.createdAt = record.createdAt
        
        // Mark as synced=false so it will be synced to Firestore
        event.synced = false
        
        // Insert event (this doesn't throw, so no do-catch needed)
        modelContext.insert(event)
        migratedCount += 1
        
        // Log progress every 100 records
        if migratedCount % 100 == 0 {
          logger.info("🔄 MIGRATION: Migrated \(migratedCount) records...")
        }
      }
      
      // Save all changes
      do {
        try modelContext.save()
        logger.info("✅ MIGRATION: Successfully migrated \(migratedCount) completion records to events")
        logger.info("⏭️ MIGRATION: Skipped \(skippedCount) records (already migrated)")
        
        // Mark migration as completed
        markMigrationCompleted()
        
        // Log migration success
        CrashlyticsService.shared.logMigrationComplete(migrationName: "CompletionsToEvents")
        CrashlyticsService.shared.setValue("\(migratedCount)", forKey: "migration_completion_migrated")
        CrashlyticsService.shared.setValue("\(skippedCount)", forKey: "migration_completion_skipped")
        
      } catch {
        logger.error("❌ MIGRATION: Failed to save migrated events: \(error.localizedDescription)")
        CrashlyticsService.shared.logMigrationFailed(migrationName: "CompletionsToEvents", error: error)
      }
    }
  }
  
  /// Resets migration status (for testing purposes)
  func resetMigrationStatus() {
    userDefaults.removeObject(forKey: migrationKey)
    userDefaults.synchronize()
    logger.info("🔄 MIGRATION: Migration status reset")
  }
  
  // MARK: - Private
  
  private let migrationKey = "completions_to_events_migration_completed"
  private let userDefaults = UserDefaults.standard
  
  /// Checks if the migration has already been completed
  private func isMigrationCompleted() -> Bool {
    userDefaults.bool(forKey: migrationKey)
  }
  
  /// Marks the migration as completed
  private func markMigrationCompleted() {
    userDefaults.set(true, forKey: migrationKey)
    userDefaults.synchronize()
  }
  
  /// Calculate UTC day boundaries for a given date
  /// Returns the start and end of the day in UTC
  private func calculateUTCDayBoundaries(for date: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let utcTimeZone = TimeZone(identifier: "UTC")!
    
    // Convert date to UTC
    var utcCalendar = calendar
    utcCalendar.timeZone = utcTimeZone
    
    // Get start of day in UTC
    let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
    guard let utcDayStart = utcCalendar.date(from: components) else {
      // Fallback: use the date itself as start, and add 24 hours for end
      let fallbackStart = date
      let fallbackEnd = date.addingTimeInterval(86400) // 24 hours
      return (fallbackStart, fallbackEnd)
    }
    
    // Get end of day (start of next day) in UTC
    guard let utcDayEnd = utcCalendar.date(byAdding: .day, value: 1, to: utcDayStart) else {
      // Fallback: add 24 hours to start
      let fallbackEnd = utcDayStart.addingTimeInterval(86400)
      return (utcDayStart, fallbackEnd)
    }
    
    return (utcDayStart, utcDayEnd)
  }
}

// MARK: - Date ISO8601 Extension

private extension Date {
  /// Convert date to ISO8601 string
  var iso8601: String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: self)
  }
}

