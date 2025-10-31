import Foundation
import SwiftData
import OSLog

// MARK: - ProgressEventService

/// Service for creating and managing ProgressEvents
///
/// Responsibilities:
/// - Create ProgressEvents for habit completion changes
/// - Calculate materialized views from events
/// - Generate device IDs and operation IDs
/// - Handle timezone-safe date calculations
@MainActor
final class ProgressEventService {
    // MARK: - Singleton
    
    static let shared = ProgressEventService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "ProgressEventService")
    private let deviceId: String
    private let timezoneIdentifier: String
    
    // MARK: - Initialization
    
    private init() {
        self.deviceId = DeviceIdProvider.shared.currentDeviceId
        self.timezoneIdentifier = TimeZone.current.identifier
        
        logger.info("ProgressEventService initialized - deviceId: \(self.deviceId), timezone: \(self.timezoneIdentifier)")
    }
    
    // MARK: - Event Creation
    
    /// Create a progress event for a habit completion change
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date of the completion (local date)
    ///   - dateKey: The date key in format "yyyy-MM-dd"
    ///   - eventType: The type of progress change
    ///   - progressDelta: The change in progress value
    ///   - userId: The user identifier
    ///   - note: Optional note attached to the event
    ///   - metadata: Optional JSON metadata string
    ///
    /// - Returns: The created ProgressEvent
    /// - Throws: Error if event creation fails
    func createEvent(
        habitId: UUID,
        date: Date,
        dateKey: String,
        eventType: ProgressEventType,
        progressDelta: Int,
        userId: String,
        note: String? = nil,
        metadata: String? = nil
    ) async throws -> ProgressEvent {
        logger.info("Creating ProgressEvent: habitId=\(habitId.uuidString), dateKey=\(dateKey), type=\(eventType.rawValue), delta=\(progressDelta)")
        
        // Validate dateKey format
        let dateKeyRegex = "^\\d{4}-\\d{2}-\\d{2}$"
        guard dateKey.range(of: dateKeyRegex, options: .regularExpression) != nil else {
            let error = ProgressEventError.invalidDateKey(dateKey)
            logger.error("Invalid dateKey format: \(dateKey)")
            throw error
        }
        
        // Calculate UTC day boundaries for timezone safety
        let calendar = Calendar.current
        let timezone = TimeZone.current
        
        // Get start and end of day in local timezone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            let error = ProgressEventError.dateCalculationFailed
            logger.error("Failed to calculate day end for date: \(date)")
            throw error
        }
        
        // Convert to UTC for storage (ensures timezone-safe grouping)
        let utcDayStart = dayStart.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayStart)))
        let utcDayEnd = dayEnd.addingTimeInterval(-TimeInterval(timezone.secondsFromGMT(for: dayEnd)))
        
        // Create event
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
            note: note,
            metadata: metadata
        )
        
        // Validate event before saving
        let validation = event.validate()
        guard validation.isValid else {
            let error = ProgressEventError.validationFailed(validation.errors)
            logger.error("Event validation failed: \(validation.errors.joined(separator: ", "))")
            throw error
        }
        
        // Save to SwiftData
        let modelContext = SwiftDataContainer.shared.modelContext
        
        // Check for duplicate operationId (idempotency check)
        let existingEventDescriptor = ProgressEvent.eventByOperationId(event.operationId)
        let existingEvents = try? modelContext.fetch(existingEventDescriptor)
        
        if let existing = existingEvents?.first {
            logger.info("Event with operationId \(event.operationId.prefix(20))... already exists, returning existing event")
            return existing
        }
        
        // Insert and save
        modelContext.insert(event)
        try modelContext.save()
        
        logger.info("✅ Created ProgressEvent: id=\(event.id.prefix(20))..., operationId=\(event.operationId.prefix(20))...")
        
        // ✅ PRIORITY 3: Schedule sync after creating event
        Task {
            await SyncEngine.shared.scheduleSyncIfNeeded()
        }
        
        return event
    }
    
    // MARK: - Materialized View Calculation
    
    /// Apply events to calculate materialized progress state
    ///
    /// This method calculates the current progress for a habit on a specific date
    /// by summing all ProgressEvents for that habit+date combination.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - dateKey: The date key in format "yyyy-MM-dd"
    ///   - goalAmount: The goal amount for this habit (to determine completion status)
    ///   - modelContext: The SwiftData model context
    ///
    /// - Returns: A tuple containing (progress: Int, isCompleted: Bool)
    /// - Throws: Error if calculation fails
    func applyEvents(
        habitId: UUID,
        dateKey: String,
        goalAmount: Int,
        modelContext: ModelContext
    ) async throws -> (progress: Int, isCompleted: Bool) {
        logger.info("Applying events for habitId=\(habitId.uuidString), dateKey=\(dateKey)")
        
        // Fetch all events for this habit+date
        let descriptor = ProgressEvent.eventsForHabitDate(habitId: habitId, dateKey: dateKey)
        let events = try modelContext.fetch(descriptor)
        
        logger.info("Found \(events.count) events for habitId=\(habitId.uuidString), dateKey=\(dateKey)")
        
        // Sum progress deltas to get current progress
        let totalProgress = events.reduce(0) { $0 + $1.progressDelta }
        
        // Ensure progress doesn't go negative
        let progress = max(0, totalProgress)
        
        // Determine completion status based on goal
        let isCompleted = progress >= goalAmount
        
        logger.info("Calculated progress=\(progress), isCompleted=\(isCompleted) from \(events.count) events")
        
        return (progress, isCompleted)
    }
    
    /// Calculate progress from events with fallback to legacy completionHistory
    ///
    /// This is the main method for getting habit progress. It prioritizes events
    /// but falls back to completionHistory for backward compatibility.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - dateKey: The date key in format "yyyy-MM-dd"
    ///   - goalAmount: The goal amount for this habit
    ///   - legacyProgress: Fallback progress from completionHistory (if no events exist)
    ///
    /// - Returns: A tuple containing (progress: Int, isCompleted: Bool)
    /// - Note: Accesses ModelContext internally since this method is @MainActor
    func calculateProgressFromEvents(
        habitId: UUID,
        dateKey: String,
        goalAmount: Int,
        legacyProgress: Int? = nil
    ) async -> (progress: Int, isCompleted: Bool) {
        // Access ModelContext directly since we're @MainActor
        let modelContext = SwiftDataContainer.shared.modelContext
        do {
            // Try to calculate from events first
            let result = try await applyEvents(
                habitId: habitId,
                dateKey: dateKey,
                goalAmount: goalAmount,
                modelContext: modelContext
            )
            
            // If we got a result from events, use it
            if result.progress > 0 || legacyProgress == nil {
                logger.info("✅ Using event-sourced progress: \(result.progress) for habitId=\(habitId.uuidString), dateKey=\(dateKey)")
                return result
            }
            
            // If events exist but progress is 0, check if we have any events at all
            let descriptor = ProgressEvent.eventsForHabitDate(habitId: habitId, dateKey: dateKey)
            let events = (try? modelContext.fetch(descriptor)) ?? []
            
            if !events.isEmpty {
                // Events exist and calculated to 0, use that
                logger.info("✅ Using event-sourced progress (0) for habitId=\(habitId.uuidString), dateKey=\(dateKey)")
                return result
            }
            
            // No events exist, fall back to legacy
            logger.info("⚠️ No events found, falling back to legacy progress: \(legacyProgress ?? 0)")
            let progress = legacyProgress ?? 0
            return (progress, progress >= goalAmount)
            
        } catch {
            logger.error("❌ Failed to calculate progress from events: \(error.localizedDescription)")
            // Fall back to legacy on error
            let progress = legacyProgress ?? 0
            return (progress, progress >= goalAmount)
        }
    }
    
}

// MARK: - Event Type Detection Helper

/// Determine event type from progress change
///
/// This is a standalone function (not part of ProgressEventService) to avoid
/// @MainActor isolation issues when called from other actors.
///
/// - Parameters:
///   - oldProgress: Previous progress value
///   - newProgress: New progress value
///   - goalAmount: Goal amount for completion determination
///
/// - Returns: The appropriate ProgressEventType
func eventTypeForProgressChange(
    oldProgress: Int,
    newProgress: Int,
    goalAmount: Int
) -> ProgressEventType {
    let delta = newProgress - oldProgress
    
    if delta == 0 {
        // No change - shouldn't happen, but handle gracefully
        return .increment
    }
    
    // Check if this is a toggle (crossing completion threshold)
    let wasCompleted = oldProgress >= goalAmount
    let isCompleted = newProgress >= goalAmount
    
    if !wasCompleted && isCompleted {
        // Just completed (crossed threshold from incomplete to complete)
        return .toggleComplete
    } else if wasCompleted && !isCompleted {
        // Just uncompleted (crossed threshold from complete to incomplete)
        return .toggleComplete
    } else if delta > 0 {
        // Increment (within same completion state)
        return .increment
    } else {
        // Decrement (within same completion state)
        return .decrement
    }
}

// MARK: - ProgressEventError

enum ProgressEventError: LocalizedError {
    case invalidDateKey(String)
    case dateCalculationFailed
    case validationFailed([String])
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidDateKey(let dateKey):
            return "Invalid dateKey format: \(dateKey). Expected yyyy-MM-dd"
        case .dateCalculationFailed:
            return "Failed to calculate UTC day boundaries"
        case .validationFailed(let errors):
            return "Event validation failed: \(errors.joined(separator: ", "))"
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        }
    }
}

