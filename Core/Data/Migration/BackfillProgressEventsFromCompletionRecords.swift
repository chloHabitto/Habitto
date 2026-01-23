import Foundation
import SwiftData
import OSLog

/// Migration service to backfill missing ProgressEvents from CompletionRecords
///
/// This migration:
/// 1. Fetches all CompletionRecord entries with progress > 0
/// 2. For each record, calculates current progress from existing ProgressEvents
/// 3. If CompletionRecord.progress > calculated progress:
///    - Creates synthetic BACKFILL event with delta = (record.progress - calculated)
///    - Uses deterministic ID for idempotency
///    - Marks as synced=true (don't upload to Firestore)
/// 4. Runs as a one-time migration (tracked in UserDefaults)
class BackfillProgressEventsFromCompletionRecords {
  // MARK: - Lifecycle
  
  private init() { }
  
  // MARK: - Internal
  
  static let shared = BackfillProgressEventsFromCompletionRecords()
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "BackfillProgressEvents")
  
  private let migrationKey = "backfillProgressEventsMigrationV1Completed"
  
  /// Checks if migration is needed and performs it if necessary
  func performMigrationIfNeeded() async {
    guard !isMigrationCompleted() else {
      logger.info("🔄 BACKFILL: Migration already completed")
      return
    }
    
    logger.info("🔄 BACKFILL: Starting migration...")
    
    // Log migration start for crash debugging
    CrashlyticsService.shared.logMigrationStart(migrationName: "BackfillProgressEvents")
    
    await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      // Fetch all CompletionRecord entries with progress > 0
      let predicate = #Predicate<CompletionRecord> { record in
        record.progress > 0
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      
      guard let completionRecords = try? modelContext.fetch(descriptor) else {
        logger.error("❌ BACKFILL: Failed to fetch CompletionRecord entries")
        return
      }
      
      logger.info("🔄 BACKFILL: Checking \(completionRecords.count) CompletionRecords")
      CrashlyticsService.shared.setValue("\(completionRecords.count)", forKey: "backfill_completion_count")
      
      var eventsCreated = 0
      var skippedCount = 0
      let errors = 0
      
      // Get device ID for backfill events (use a consistent identifier)
      let deviceId = "BACKFILL_MIGRATION"
      let timezoneIdentifier = TimeZone.current.identifier
      
      for record in completionRecords {
        // Calculate current progress from existing ProgressEvents
        let eventDescriptor = ProgressEvent.eventsForHabitDateUser(
          habitId: record.habitId,
          dateKey: record.dateKey,
          userId: record.userId
        )
        let existingEvents = (try? modelContext.fetch(eventDescriptor)) ?? []
        
        // Sum progress deltas from existing events
        let calculatedProgress = existingEvents.reduce(0) { $0 + $1.progressDelta }
        
        // Only create backfill event if record.progress > calculated
        guard record.progress > calculatedProgress else {
          // Progress matches - no backfill needed
          skippedCount += 1
          continue
        }
        
        // Calculate delta needed to reach record.progress
        let delta = record.progress - calculatedProgress
        
        // Check if backfill event already exists (idempotency)
        let backfillOperationId = "backfill_\(record.habitId.uuidString)_\(record.dateKey)"
        let existingBackfillDescriptor = ProgressEvent.eventByOperationId(backfillOperationId)
        let existingBackfillEvents = (try? modelContext.fetch(existingBackfillDescriptor)) ?? []
        
        if !existingBackfillEvents.isEmpty {
          // Backfill event already exists, skip
          skippedCount += 1
          continue
        }
        
        // Calculate UTC day boundaries for the date
        let utcDayBoundaries = calculateUTCDayBoundaries(for: record.date)
        
        // Get deterministic sequence number for backfill events
        // Use a high sequence number to ensure it doesn't conflict with real events
        let sequenceNumber = EventSequenceCounter.shared.nextSequence(
          deviceId: deviceId,
          dateKey: record.dateKey
        )
        
        // Create synthetic BACKFILL ProgressEvent
        let event = ProgressEvent(
          habitId: record.habitId,
          dateKey: record.dateKey,
          eventType: .backfill,
          progressDelta: delta,
          userId: record.userId,
          deviceId: deviceId,
          timezoneIdentifier: timezoneIdentifier,
          utcDayStart: utcDayBoundaries.start,
          utcDayEnd: utcDayBoundaries.end,
          sequenceNumber: sequenceNumber,
          note: "Backfilled from CompletionRecord - missing historical events",
          metadata: "{\"backfill\":true,\"originalProgress\":\(record.progress),\"calculatedProgress\":\(calculatedProgress)}",
          operationId: backfillOperationId
        )
        
        // Use the record's original createdAt as the event's occurredAt
        event.occurredAt = record.createdAt
        event.createdAt = record.createdAt
        
        // Mark as synced=true (don't upload to Firestore - this is local reconciliation)
        event.synced = true
        event.lastSyncedAt = Date()
        event.isRemote = false
        
        // Insert event
        modelContext.insert(event)
        eventsCreated += 1
        
        logger.info("✅ BACKFILL: Created event for habitId=\(record.habitId.uuidString.prefix(8))..., dateKey=\(record.dateKey), delta=\(delta)")
        
        // Log progress every 100 records
        if eventsCreated % 100 == 0 {
          logger.info("🔄 BACKFILL: Created \(eventsCreated) events...")
        }
      }
      
      // Save all changes
      do {
        try modelContext.save()
        logger.info("🎉 BACKFILL: Complete - created \(eventsCreated) events, skipped \(skippedCount) (already correct), errors: \(errors)")
        
        // Mark migration as completed
        markMigrationCompleted()
        
        // Log migration success
        CrashlyticsService.shared.logMigrationComplete(migrationName: "BackfillProgressEvents")
        CrashlyticsService.shared.setValue("\(eventsCreated)", forKey: "backfill_events_created")
        CrashlyticsService.shared.setValue("\(skippedCount)", forKey: "backfill_skipped")
        CrashlyticsService.shared.setValue("\(errors)", forKey: "backfill_errors")
        
      } catch {
        logger.error("❌ BACKFILL: Failed to save backfilled events: \(error.localizedDescription)")
        CrashlyticsService.shared.logMigrationFailed(migrationName: "BackfillProgressEvents", error: error)
      }
    }
  }
  
  // MARK: - Private Helpers
  
  private func isMigrationCompleted() -> Bool {
    return UserDefaults.standard.bool(forKey: migrationKey)
  }
  
  private func markMigrationCompleted() {
    UserDefaults.standard.set(true, forKey: migrationKey)
    UserDefaults.standard.synchronize()
  }
  
  /// Calculate UTC day boundaries for a given date
  private func calculateUTCDayBoundaries(for date: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    
    // Convert to UTC
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
    
    // Get start of day in local timezone
    let dayStart = calendar.startOfDay(for: date)
    
    // Convert to UTC
    let utcDayStart = utcCalendar.startOfDay(for: dayStart)
    
    // Calculate end of day (start of next day)
    guard let utcDayEnd = utcCalendar.date(byAdding: .day, value: 1, to: utcDayStart) else {
      // Fallback to 24 hours later
      return (start: utcDayStart, end: utcDayStart.addingTimeInterval(86400))
    }
    
    return (start: utcDayStart, end: utcDayEnd)
  }
}
