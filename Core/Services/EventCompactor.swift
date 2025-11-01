import BackgroundTasks
import Foundation
import OSLog
import SwiftData

// MARK: - Background Task Identifiers

extension String {
  fileprivate static let eventCompactionTaskIdentifier = "com.habitto.app.event-compaction"
}

// MARK: - EventCompactionConfig

/// Configuration for event compaction
public struct EventCompactionConfig: Codable {
  /// Age threshold in days for compaction (default: 7)
  public var compactionAgeDays: Int
  
  /// Whether compaction is enabled
  public var isEnabled: Bool
  
  /// Preferred time for compaction (3 AM local time)
  public var preferredTime: Date
  
  public init(
    compactionAgeDays: Int = 7,
    isEnabled: Bool = true,
    preferredTime: Date? = nil
  ) {
    self.compactionAgeDays = compactionAgeDays
    self.isEnabled = isEnabled
    
    // Default to 3 AM local time
    if let preferredTime = preferredTime {
      self.preferredTime = preferredTime
    } else {
      let calendar = Calendar.current
      let now = Date()
      var components = calendar.dateComponents([.year, .month, .day], from: now)
      components.hour = 3
      components.minute = 0
      components.second = 0
      self.preferredTime = calendar.date(from: components) ?? now
    }
  }
  
  /// Load from UserDefaults
  public static func load(userId: String) -> EventCompactionConfig {
    let userDefaults = UserDefaults.standard
    let key = "\(userId)_EventCompactionConfig"
    
    if let data = userDefaults.data(forKey: key),
       let config = try? JSONDecoder().decode(EventCompactionConfig.self, from: data) {
      return config
    }
    
    return EventCompactionConfig() // Default configuration
  }
  
  /// Save to UserDefaults
  public func save(userId: String) {
    let userDefaults = UserDefaults.standard
    let key = "\(userId)_EventCompactionConfig"
    
    if let data = try? JSONEncoder().encode(self) {
      userDefaults.set(data, forKey: key)
    }
  }
}

// MARK: - EventCompactor

/// Actor responsible for compacting old ProgressEvents into CompletionRecords
///
/// Event compaction is an optimization that:
/// 1. Finds events older than the threshold (default: 7 days)
/// 2. Calculates final progress from event deltas
/// 3. Updates CompletionRecord with final values
/// 4. Deletes old events to reduce storage
///
/// This preserves the materialized view (CompletionRecord) while removing
/// the granular event history after it's no longer needed for conflict resolution.
actor EventCompactor {
  // MARK: - Properties
  
  private let logger = Logger(subsystem: "com.habitto.app", category: "EventCompactor")
  private var config: EventCompactionConfig
  private let userId: String
  
  // MARK: - Initialization
  
  init(userId: String) {
    self.userId = userId
    self.config = EventCompactionConfig.load(userId: userId)
  }
  
  // MARK: - Configuration
  
  /// Update compaction configuration
  func updateConfig(_ newConfig: EventCompactionConfig) {
    self.config = newConfig
    self.config.save(userId: self.userId)
    logger.info("Event compaction config updated: ageDays=\(self.config.compactionAgeDays), enabled=\(self.config.isEnabled)")
  }
  
  /// Get current configuration
  func getConfig() -> EventCompactionConfig {
    return self.config
  }
  
  // MARK: - Compaction Logic
  
  /// Compact old events into CompletionRecords
  ///
  /// This method:
  /// 1. Finds all events older than compactionAgeDays
  /// 2. Groups by habitId + dateKey
  /// 3. Calculates final progress by summing progressDelta
  /// 4. Updates or creates CompletionRecord with final values
  /// 5. Deletes compacted events
  ///
  /// - Returns: CompactionResult with statistics
  func compactOldEvents() async throws -> CompactionResult {
    guard self.config.isEnabled else {
      logger.info("Event compaction is disabled, skipping")
      return CompactionResult(
        eventsProcessed: 0,
        recordsUpdated: 0,
        eventsDeleted: 0,
        error: nil
      )
    }
    
    logger.info("Starting event compaction: ageThreshold=\(self.config.compactionAgeDays) days")
    
    let calendar = Calendar.current
    let now = Date()
    let cutoffDate = calendar.date(byAdding: .day, value: -self.config.compactionAgeDays, to: now) ?? now
    let currentUserId = self.userId // Capture for use in predicate
    
    // Fetch events on MainActor
    let eventDataArray = await MainActor.run {
      let modelContext = SwiftDataContainer.shared.modelContext
      
      let predicate = #Predicate<ProgressEvent> { event in
        event.createdAt < cutoffDate &&
        event.synced == true &&
        event.deletedAt == nil &&
        event.userId == currentUserId  // Use captured value
      }
      
      // Pass sortBy in initializer
      let descriptor = FetchDescriptor<ProgressEvent>(
        predicate: predicate,
        sortBy: [SortDescriptor(\.createdAt, order: .forward)]
      )
      
      let events = (try? modelContext.fetch(descriptor)) ?? []
      
      // Extract Sendable data from events
      return events.map { event in
        EventData(
          id: event.id,
          habitId: event.habitId,
          dateKey: event.dateKey,
          progressDelta: event.progressDelta,
          createdAt: event.createdAt
        )
      }
    }
    
    guard !eventDataArray.isEmpty else {
      logger.info("No events found for compaction")
      return CompactionResult(
        eventsProcessed: 0,
        recordsUpdated: 0,
        eventsDeleted: 0,
        error: nil
      )
    }
    
    logger.info("Found \(eventDataArray.count) events to compact")
    
    // Group events by habitId + dateKey (process in actor)
    var eventsByHabitDate: [String: [EventData]] = [:]
    for eventData in eventDataArray {
      let key = "\(eventData.habitId.uuidString)_\(eventData.dateKey)"
      eventsByHabitDate[key, default: []].append(eventData)
    }
    
    // Calculate compaction updates (process in actor)
    let updates: [CompactionUpdate] = eventsByHabitDate.compactMap { (key, events) in
      // Calculate final progress from events
      let finalProgress = events.reduce(0) { $0 + $1.progressDelta }
      
      // Get habitId and dateKey from key
      let components = key.split(separator: "_", maxSplits: 1)
      guard components.count == 2,
            let habitId = UUID(uuidString: String(components[0])),
            let dateKey = String(components[1]) as String? else {
        logger.warning("Invalid key format: \(key), skipping")
        return nil
      }
      
      let eventIds = events.map { $0.id }
      return CompactionUpdate(
        habitId: habitId,
        dateKey: dateKey,
        finalProgress: finalProgress,
        eventIds: eventIds,
        needsNewRecord: false // Will check on MainActor
      )
    }
    
    // Fetch habit goals on MainActor for isCompleted calculation
    let habitGoals = await MainActor.run { () -> [UUID: Int] in
      let modelContext = SwiftDataContainer.shared.modelContext
      let uniqueHabitIds = Set(updates.map { $0.habitId })
      var goals: [UUID: Int] = [:]
      
      for habitId in uniqueHabitIds {
        let predicate = #Predicate<HabitData> { habit in
          habit.id == habitId && habit.userId == currentUserId
        }
        let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
        if let habit = (try? modelContext.fetch(descriptor))?.first {
          let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
          goals[habitId] = goalAmount
        }
      }
      
      return goals
    }
    
    // Apply updates on MainActor and return statistics
    // Capture logger for use in MainActor.run closure (Logger is Sendable)
    let compactionLogger = self.logger
    let (recordsUpdated, eventsDeleted) = try await MainActor.run { () -> (Int, Int) in
      let modelContext = SwiftDataContainer.shared.modelContext
      var recordsUpdated = 0
      var eventsDeleted = 0
      
      for update in updates {
        let recordUniqueKey = "\(currentUserId)#\(update.habitId.uuidString)#\(update.dateKey)"
        let recordPredicate = #Predicate<CompletionRecord> { record in
          record.userIdHabitIdDateKey == recordUniqueKey
        }
        let recordDescriptor = FetchDescriptor<CompletionRecord>(predicate: recordPredicate)
        
        let existingRecords = (try? modelContext.fetch(recordDescriptor)) ?? []
        
        if let existingRecord = existingRecords.first {
          // Update existing record with final progress
          existingRecord.progress = max(0, update.finalProgress) // Ensure non-negative
          
          // Update isCompleted based on goal
          if let goalAmount = habitGoals[update.habitId] {
            existingRecord.isCompleted = update.finalProgress >= goalAmount
          }
          
          recordsUpdated += 1
          compactionLogger.debug("Updated CompletionRecord: habitId=\(update.habitId.uuidString), dateKey=\(update.dateKey), progress=\(update.finalProgress)")
        } else {
          // Create new CompletionRecord if it doesn't exist
          compactionLogger.warning("No CompletionRecord found for habitId=\(update.habitId.uuidString), dateKey=\(update.dateKey), creating one")
          
          // Parse dateKey to Date
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd"
          dateFormatter.timeZone = TimeZone.current
          
          if let date = dateFormatter.date(from: update.dateKey) {
            let record = CompletionRecord(
              userId: currentUserId,
              habitId: update.habitId,
              date: date,
              dateKey: update.dateKey,
              isCompleted: false,
              progress: max(0, update.finalProgress)
            )
            modelContext.insert(record)
            recordsUpdated += 1
          }
        }
        
        // Delete events after updating record
        for eventId in update.eventIds {
          let eventPredicate = #Predicate<ProgressEvent> { event in
            event.id == eventId
          }
          let eventDescriptor = FetchDescriptor<ProgressEvent>(predicate: eventPredicate)
          if let event = (try? modelContext.fetch(eventDescriptor))?.first {
            modelContext.delete(event)
            eventsDeleted += 1
          }
        }
      }
      
      // Save all changes
      try modelContext.save()
      
      return (recordsUpdated, eventsDeleted)
    }
    
    logger.info("Event compaction completed: processed=\(eventDataArray.count), updated=\(recordsUpdated), deleted=\(eventsDeleted)")
    
    return CompactionResult(
      eventsProcessed: eventDataArray.count,
      recordsUpdated: recordsUpdated,
      eventsDeleted: eventsDeleted,
      error: nil
    )
  }
  
  
  // MARK: - Scheduling
  
  /// Schedule next compaction at preferred time (3 AM local time)
  func scheduleNextCompaction() {
    logger.info("📅 EventCompactor: scheduleNextCompaction() called")
    print("📅 EventCompactor: scheduleNextCompaction() called")
    
    guard config.isEnabled else {
      logger.info("Event compaction is disabled, not scheduling")
      print("⏭️ EventCompactor: Compaction disabled, skipping schedule")
      return
    }
    
    let calendar = Calendar.current
    let now = Date()
    
    // Get preferred time components
    let preferredComponents = calendar.dateComponents([.hour, .minute], from: config.preferredTime)
    
    // Calculate next occurrence at preferred time
    var nextDateComponents = calendar.dateComponents([.year, .month, .day], from: now)
    nextDateComponents.hour = preferredComponents.hour ?? 3
    nextDateComponents.minute = preferredComponents.minute ?? 0
    nextDateComponents.second = 0
    
    var nextDate = calendar.date(from: nextDateComponents) ?? now
    
    // If the time has already passed today, schedule for tomorrow
    if nextDate <= now {
      nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
    }
    
    let request = BGAppRefreshTaskRequest(identifier: .eventCompactionTaskIdentifier)
    request.earliestBeginDate = nextDate
    
    do {
      try BGTaskScheduler.shared.submit(request)
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      logger.info("✅ Event compaction scheduled for: \(formatter.string(from: nextDate)) (age threshold: \(self.config.compactionAgeDays) days)")
      print("📅 EventCompactor: ✅ Scheduled compaction for \(formatter.string(from: nextDate)) (age threshold: \(self.config.compactionAgeDays) days)")
    } catch {
      logger.error("Failed to schedule event compaction: \(error.localizedDescription)")
      print("❌ EventCompactor: Failed to schedule - \(error.localizedDescription)")
    }
  }
  
  /// Manual compaction trigger for testing (compacts events older than specified days)
  func compactNow(ageThresholdDays: Int? = nil) async throws -> CompactionResult {
    logger.info("🔧 EventCompactor: Manual compaction triggered")
    print("🔧 EventCompactor: Manual compaction triggered")
    
    // Temporarily override compaction age if specified
    let originalAge = config.compactionAgeDays
    let shouldRestore = ageThresholdDays != nil
    
    if let ageThresholdDays = ageThresholdDays {
      var tempConfig = config
      tempConfig.compactionAgeDays = ageThresholdDays
      updateConfig(tempConfig)
    }
    
    // Perform compaction
    let result = try await compactOldEvents()
    
    // Restore original config if we temporarily changed it
    if shouldRestore {
      var restoredConfig = getConfig()
      restoredConfig.compactionAgeDays = originalAge
      updateConfig(restoredConfig)
    }
    
    return result
  }
  
  /// Cancel scheduled compaction
  func cancelScheduledCompaction() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: .eventCompactionTaskIdentifier)
    logger.info("Event compaction cancelled")
  }
  
  // MARK: - Background Task Handler (Static)
  
  /// Register background task handler
  /// This should be called from AppDelegate.didFinishLaunchingWithOptions
  static func registerBackgroundTaskHandler() {
    let logger = Logger(subsystem: "com.habitto.app", category: "EventCompactor")
    logger.info("Registering event compaction background task handler")
    
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: .eventCompactionTaskIdentifier,
      using: nil
    ) { task in
      handleCompactionTask(task: task as! BGAppRefreshTask)
    }
    
    logger.info("✅ Event compaction background task handler registered")
  }
  
  /// Handle background compaction task
  private static func handleCompactionTask(task: BGAppRefreshTask) {
    let logger = Logger(subsystem: "com.habitto.app", category: "EventCompactor")
    logger.info("Background event compaction task started")
    
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      logger.warning("Background event compaction task expired")
    }
    
    Task {
      do {
        // Get current user ID
        let userId = await CurrentUser().idOrGuest
        
        // Skip compaction for guest users (optional - can enable if needed)
        guard !CurrentUser.isGuestId(userId) else {
          logger.info("Skipping event compaction for guest user")
          task.setTaskCompleted(success: true)
          return
        }
        
        // Create compactor and run compaction
        let compactor = EventCompactor(userId: userId)
        let result = try await compactor.compactOldEvents()
        
        // Schedule next compaction
        await compactor.scheduleNextCompaction()
        
        logger.info("Event compaction completed: processed=\(result.eventsProcessed), updated=\(result.recordsUpdated), deleted=\(result.eventsDeleted)")
        task.setTaskCompleted(success: true)
        
      } catch {
        logger.error("Event compaction failed: \(error.localizedDescription)")
        task.setTaskCompleted(success: false)
      }
    }
  }
}

// MARK: - Sendable Event Data

/// Sendable struct to pass event data across actor boundaries
private struct EventData: Sendable {
  let id: String
  let habitId: UUID
  let dateKey: String
  let progressDelta: Int
  let createdAt: Date
}

/// Sendable struct to hold compaction updates
private struct CompactionUpdate: Sendable {
  let habitId: UUID
  let dateKey: String
  let finalProgress: Int
  let eventIds: [String]
  let needsNewRecord: Bool
}

// MARK: - CompactionResult

/// Result of event compaction operation
public struct CompactionResult {
  /// Number of events processed
  public let eventsProcessed: Int
  
  /// Number of CompletionRecords updated
  public let recordsUpdated: Int
  
  /// Number of events deleted
  public let eventsDeleted: Int
  
  /// Error if compaction failed
  public let error: Error?
  
  public init(
    eventsProcessed: Int,
    recordsUpdated: Int,
    eventsDeleted: Int,
    error: Error?
  ) {
    self.eventsProcessed = eventsProcessed
    self.recordsUpdated = recordsUpdated
    self.eventsDeleted = eventsDeleted
    self.error = error
  }
}

