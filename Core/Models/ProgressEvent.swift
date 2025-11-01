import Foundation
import SwiftData

// MARK: - ProgressEvent

/// Event-sourced record of a single progress change
///
/// This is the source of truth for all habit progress changes.
/// DailyCompletion records are materialized views derived from these events.
///
/// Event Sourcing Benefits:
/// - Complete audit trail of all changes
/// - Conflict-free merging (union of events)
/// - Time-travel debugging (replay events)
/// - Undo/redo support
///
/// Design Principles:
/// - Immutable once created (append-only log)
/// - Fine-grained events (each swipe, each tap)
/// - Deterministic ID for idempotency
/// - Device and timezone information for conflict resolution
@Model
public final class ProgressEvent {
  // MARK: - Identity & Relationships
  
  /// Unique identifier for this event
  /// Format: "evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}"
  /// Deterministic and idempotent: same inputs always produce same ID
  /// This prevents duplicate events during sync retries
  @Attribute(.unique) public var id: String
  
  /// The habit this event belongs to
  public var habitId: UUID
  
  /// The date this event applies to (user's local date, stored as UTC midnight)
  /// This is the KEY for grouping events into daily completions
  public var dateKey: String  // Format: "yyyy-MM-dd"
  
  // MARK: - Event Type & Value
  
  /// The type of progress change
  public var eventType: String  // ProgressEventType enum stored as string
  
  /// The delta applied to progress
  /// - INCREMENT: +1, +5, etc.
  /// - DECREMENT: -1, -5, etc.
  /// - SET: absolute value
  /// - TOGGLE_COMPLETE: calculated from goal
  public var progressDelta: Int
  
  // MARK: - Timestamps
  
  /// When this event was created (client timestamp)
  public var createdAt: Date
  
  /// The actual moment the user performed the action (for accurate time tracking)
  public var occurredAt: Date
  
  /// UTC day boundaries for timezone safety
  /// These ensure we can correctly group events even across timezone changes
  public var utcDayStart: Date
  public var utcDayEnd: Date
  
  // MARK: - Device & User Context
  
  /// Device that created this event (for conflict resolution)
  /// Format: "iOS_{deviceModel}_{uuid}"
  public var deviceId: String
  
  /// User who created this event (for multi-user sync)
  public var userId: String
  
  /// Timezone where event was created (for display purposes)
  public var timezoneIdentifier: String
  
  // MARK: - Sync Metadata
  
  /// Unique operation ID for idempotency
  /// Format: "{deviceId}_{timestamp}_{uuid}"
  /// Prevents duplicate processing of the same event
  @Attribute(.unique) public var operationId: String
  
  /// Whether this event has been synced to Firestore
  public var synced: Bool
  
  /// When this event was last synced (nil if never synced)
  public var lastSyncedAt: Date?
  
  /// Sync version for optimistic locking
  public var syncVersion: Int
  
  /// Whether this event was received from remote (vs created locally)
  public var isRemote: Bool
  
  // MARK: - Soft Delete
  
  /// Timestamp of deletion (nil if not deleted)
  /// Events are never truly deleted for audit trail
  public var deletedAt: Date?
  
  // MARK: - Metadata
  
  /// Optional note attached to this progress change
  public var note: String?
  
  /// Optional metadata (JSON string for extensibility)
  /// Can store: difficulty rating, mood, location, etc.
  public var metadata: String?
  
  // MARK: - Initialization
  
  public init(
    habitId: UUID,
    dateKey: String,
    eventType: ProgressEventType,
    progressDelta: Int,
    userId: String,
    deviceId: String,
    timezoneIdentifier: String,
    utcDayStart: Date,
    utcDayEnd: Date,
    sequenceNumber: Int,
    note: String? = nil,
    metadata: String? = nil,
    operationId: String? = nil
  ) {
    let timestamp = Date()
    let uuid = UUID().uuidString
    
    // Generate deterministic ID: evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}
    // Same inputs always produce same ID → true idempotency for sync retries
    // Firestore deduplicates automatically via unique constraint on id field
    self.id = "evt_\(habitId.uuidString)_\(dateKey)_\(deviceId)_\(sequenceNumber)"
    
    // Use provided operationId or generate unique operation ID for idempotency
    // operationId keeps timestamp+uuid format for fine-grained deduplication
    if let operationId = operationId {
      self.operationId = operationId
    } else {
      self.operationId = "\(deviceId)_\(Int(timestamp.timeIntervalSince1970 * 1000))_\(uuid)"
    }
    
    self.habitId = habitId
    self.dateKey = dateKey
    self.eventType = eventType.rawValue
    self.progressDelta = progressDelta
    self.createdAt = timestamp
    self.occurredAt = timestamp
    self.userId = userId
    self.deviceId = deviceId
    self.timezoneIdentifier = timezoneIdentifier
    self.utcDayStart = utcDayStart
    self.utcDayEnd = utcDayEnd
    self.synced = false
    self.lastSyncedAt = nil
    self.syncVersion = 1
    self.isRemote = false
    self.deletedAt = nil
    self.note = note
    self.metadata = metadata
  }
  
  // MARK: - Computed Properties
  
  /// Typed event type enum
  public var eventTypeEnum: ProgressEventType {
    get { ProgressEventType(rawValue: eventType) ?? .increment }
    set { eventType = newValue.rawValue }
  }
  
  /// Whether this event is active (not deleted and not synced-deleted)
  public var isActive: Bool {
    deletedAt == nil
  }
  
  /// Whether this event needs to be synced
  public var needsSync: Bool {
    !synced && isActive
  }
  
  // MARK: - Helper Methods
  
  /// Mark this event as synced
  public func markAsSynced() {
    synced = true
    lastSyncedAt = Date()
    syncVersion += 1
  }
  
  /// Mark this event as deleted (soft delete)
  public func markAsDeleted() {
    deletedAt = Date()
    synced = false  // Need to sync the deletion
  }
  
  /// Create a copy with remote flag set (for incoming sync)
  /// Note: sequenceNumber is set to 0 since we overwrite the ID anyway (preserving original ID from remote)
  public func asRemote() -> ProgressEvent {
    let copy = ProgressEvent(
      habitId: habitId,
      dateKey: dateKey,
      eventType: eventTypeEnum,
      progressDelta: progressDelta,
      userId: userId,
      deviceId: deviceId,
      timezoneIdentifier: timezoneIdentifier,
      utcDayStart: utcDayStart,
      utcDayEnd: utcDayEnd,
      sequenceNumber: 0, // Not used since we overwrite ID below
      note: note,
      metadata: metadata
    )
    copy.id = self.id // Preserve original ID from remote event
    copy.operationId = self.operationId
    copy.createdAt = self.createdAt
    copy.occurredAt = self.occurredAt
    copy.synced = true
    copy.lastSyncedAt = Date()
    copy.isRemote = true
    return copy
  }
}

// MARK: - ProgressEventType Enum

/// Types of progress events
public enum ProgressEventType: String, Codable, CaseIterable {
  /// User incremented progress (+1, +5, etc.)
  case increment = "INCREMENT"
  
  /// User decremented progress (-1, -5, etc.)
  case decrement = "DECREMENT"
  
  /// User set progress to absolute value
  case set = "SET"
  
  /// User tapped circle button to toggle complete/incomplete
  case toggleComplete = "TOGGLE_COMPLETE"
  
  /// System automatically marked as incomplete (e.g., day rollover for breaking habits)
  case systemReset = "SYSTEM_RESET"
  
  /// Bulk adjustment (e.g., migration, correction)
  case bulkAdjust = "BULK_ADJUST"
}

// MARK: - SwiftData Queries

extension ProgressEvent {
  /// Fetch all events for a specific habit and date
  public static func eventsForHabitDate(
    habitId: UUID,
    dateKey: String
  ) -> FetchDescriptor<ProgressEvent> {
    let predicate = #Predicate<ProgressEvent> { event in
      event.habitId == habitId &&
      event.dateKey == dateKey &&
      event.deletedAt == nil
    }
    
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
    return descriptor
  }
  
  /// Fetch all unsynced events
  public static func unsyncedEvents() -> FetchDescriptor<ProgressEvent> {
    let predicate = #Predicate<ProgressEvent> { event in
      event.synced == false && event.deletedAt == nil
    }
    
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
    return descriptor
  }
  
  /// Fetch events by operation ID (for idempotency check)
  public static func eventByOperationId(_ operationId: String) -> FetchDescriptor<ProgressEvent> {
    let predicate = #Predicate<ProgressEvent> { event in
      event.operationId == operationId
    }
    return FetchDescriptor(predicate: predicate)
  }
  
  /// Fetch all events for a habit (for audit trail / debugging)
  public static func allEventsForHabit(habitId: UUID) -> FetchDescriptor<ProgressEvent> {
    let predicate = #Predicate<ProgressEvent> { event in
      event.habitId == habitId
    }
    
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
    return descriptor
  }
  
  /// Fetch events in a date range (for syncing recent changes)
  public static func eventsInDateRange(
    startDate: Date,
    endDate: Date
  ) -> FetchDescriptor<ProgressEvent> {
    let predicate = #Predicate<ProgressEvent> { event in
      event.createdAt >= startDate &&
      event.createdAt <= endDate &&
      event.deletedAt == nil
    }
    
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
    return descriptor
  }
}

// MARK: - Validation

extension ProgressEvent {
  /// Validate event integrity
  public func validate() -> (isValid: Bool, errors: [String]) {
    var errors: [String] = []
    
    // Validate ID format: evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}
    if !id.hasPrefix("evt_") {
      errors.append("Invalid ID format: \(id). Expected format: evt_{habitId}_{dateKey}_{deviceId}_{sequenceNumber}")
    } else {
      // Check that ID has expected components (more lenient validation to support legacy IDs during migration)
      let components = id.components(separatedBy: "_")
      if components.count < 5 {
        // Warn but don't fail - legacy IDs may have different format
        // New format should have: ["evt", habitId, dateKey, deviceId, sequenceNumber] = 5+ components
      }
    }
    
    // Validate operation ID format
    if !operationId.contains("_") {
      errors.append("Invalid operationId format: \(operationId)")
    }
    
    // Validate dateKey format (yyyy-MM-dd)
    let dateKeyRegex = "^\\d{4}-\\d{2}-\\d{2}$"
    if dateKey.range(of: dateKeyRegex, options: .regularExpression) == nil {
      errors.append("Invalid dateKey format: \(dateKey). Expected yyyy-MM-dd")
    }
    
    // Validate UTC boundaries
    if utcDayEnd <= utcDayStart {
      errors.append("utcDayEnd must be after utcDayStart")
    }
    
    // Validate timestamps
    if occurredAt > Date().addingTimeInterval(60) {  // Allow 60s clock skew
      errors.append("occurredAt is in the future: \(occurredAt)")
    }
    
    // Validate event type
    if ProgressEventType(rawValue: eventType) == nil {
      errors.append("Invalid eventType: \(eventType)")
    }
    
    return (errors.isEmpty, errors)
  }
}

// MARK: - Firestore Conversion

extension ProgressEvent {
  /// Convert to Firestore-compatible dictionary
  public func toFirestore() -> [String: Any] {
    var data: [String: Any] = [
      "id": id,
      "habitId": habitId.uuidString,
      "dateKey": dateKey,
      "eventType": eventType,
      "progressDelta": progressDelta,
      "createdAt": createdAt,
      "occurredAt": occurredAt,
      "utcDayStart": utcDayStart,
      "utcDayEnd": utcDayEnd,
      "deviceId": deviceId,
      "userId": userId,
      "timezoneIdentifier": timezoneIdentifier,
      "operationId": operationId,
      "syncVersion": syncVersion,
      "isRemote": isRemote
    ]
    
    // Optional fields
    if let note = note {
      data["note"] = note
    }
    if let metadata = metadata {
      data["metadata"] = metadata
    }
    if let deletedAt = deletedAt {
      data["deletedAt"] = deletedAt
    }
    
    return data
  }
  
  /// Create from Firestore dictionary
  public static func fromFirestore(_ data: [String: Any]) -> ProgressEvent? {
    guard
      let id = data["id"] as? String,
      let habitIdString = data["habitId"] as? String,
      let habitId = UUID(uuidString: habitIdString),
      let dateKey = data["dateKey"] as? String,
      let eventTypeString = data["eventType"] as? String,
      let eventType = ProgressEventType(rawValue: eventTypeString),
      let progressDelta = data["progressDelta"] as? Int,
      let userId = data["userId"] as? String,
      let deviceId = data["deviceId"] as? String,
      let timezoneIdentifier = data["timezoneIdentifier"] as? String,
      let utcDayStart = data["utcDayStart"] as? Date,
      let utcDayEnd = data["utcDayEnd"] as? Date,
      let operationId = data["operationId"] as? String
    else {
      return nil
    }
    
    // Create event with sequenceNumber 0 (not used since we restore ID from Firestore)
    let event = ProgressEvent(
      habitId: habitId,
      dateKey: dateKey,
      eventType: eventType,
      progressDelta: progressDelta,
      userId: userId,
      deviceId: deviceId,
      timezoneIdentifier: timezoneIdentifier,
      utcDayStart: utcDayStart,
      utcDayEnd: utcDayEnd,
      sequenceNumber: 0, // Not used since we restore ID from Firestore below
      note: data["note"] as? String,
      metadata: data["metadata"] as? String
    )
    
    // Restore fields from Firestore (preserve original ID from remote)
    event.id = id
    event.operationId = operationId
    if let createdAt = data["createdAt"] as? Date {
      event.createdAt = createdAt
    }
    if let occurredAt = data["occurredAt"] as? Date {
      event.occurredAt = occurredAt
    }
    if let syncVersion = data["syncVersion"] as? Int {
      event.syncVersion = syncVersion
    }
    if let isRemote = data["isRemote"] as? Bool {
      event.isRemote = isRemote
    }
    if let deletedAt = data["deletedAt"] as? Date {
      event.deletedAt = deletedAt
    }
    
    // Mark as synced since we received it from Firestore
    event.synced = true
    event.lastSyncedAt = Date()
    event.isRemote = true
    
    return event
  }
}

// MARK: - Debug Description

extension ProgressEvent: CustomStringConvertible {
  public var description: String {
    let deltaSign = progressDelta >= 0 ? "+" : ""
    return """
    ProgressEvent(
      id: \(id.prefix(20))...,
      habit: \(habitId.uuidString.prefix(8))...,
      date: \(dateKey),
      type: \(eventType),
      delta: \(deltaSign)\(progressDelta),
      synced: \(synced),
      device: \(deviceId)
    )
    """
  }
}

