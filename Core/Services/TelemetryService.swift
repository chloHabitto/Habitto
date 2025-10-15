import Foundation
import OSLog

// MARK: - TelemetryService

/// Centralized telemetry service for tracking migration and dual-write operations
@MainActor
final class TelemetryService: ObservableObject {
  
  // MARK: - Lifecycle
  
  private init() {
    logger.info("📊 TelemetryService: Initialized")
  }
  
  // MARK: - Internal
  
  static let shared = TelemetryService()
  
  // MARK: - Counters
  
  private var counters: [String: Int] = [:]
  private var timers: [String: Date] = [:]
  private let logger = Logger(subsystem: "com.habitto.app", category: "TelemetryService")
  
  // MARK: - Counter Methods
  
  /// Increment a counter
  func increment(_ key: String) {
    self.counters[key, default: 0] += 1
    logger.debug("📊 Telemetry: \(key) = \(self.counters[key] ?? 0)")
  }
  
  /// Decrement a counter
  func decrement(_ key: String) {
    self.counters[key, default: 0] = max(0, (self.counters[key] ?? 0) - 1)
    logger.debug("📊 Telemetry: \(key) = \(self.counters[key] ?? 0)")
  }
  
  /// Set a counter value
  func set(_ key: String, value: Int) {
    counters[key] = value
    logger.debug("📊 Telemetry: \(key) = \(value)")
  }
  
  /// Get a counter value
  func get(_ key: String) -> Int {
    counters[key] ?? 0
  }
  
  // MARK: - Timer Methods
  
  /// Start a timer
  func startTimer(_ key: String) {
    timers[key] = Date()
    logger.debug("📊 Telemetry: Started timer for \(key)")
  }
  
  /// End a timer and log duration
  func endTimer(_ key: String) -> TimeInterval? {
    guard let startTime = timers[key] else {
      logger.warning("⚠️ Telemetry: No start time found for timer \(key)")
      return nil
    }
    
    let duration = Date().timeIntervalSince(startTime)
    timers.removeValue(forKey: key)
    
    logger.info("📊 Telemetry: Timer \(key) completed in \(String(format: "%.2f", duration))s")
    return duration
  }
  
  /// End a timer and increment a counter with the duration
  func endTimerAndIncrement(_ key: String, counterKey: String) -> TimeInterval? {
    guard let duration = endTimer(key) else { return nil }
    
    // Store duration in milliseconds
    let durationMs = Int(duration * 1000)
    set("\(counterKey)_ms", value: durationMs)
    
    return duration
  }
  
  // MARK: - Event Logging
  
  /// Log an event with optional data
  func logEvent(_ event: String, data: [String: Any] = [:]) {
    let dataString = data.isEmpty ? "" : " | Data: \(data)"
    logger.info("📊 Telemetry Event: \(event)\(dataString)")
    
    // Also increment counter for the event
    increment(event)
  }
  
  /// Log an error event
  func logError(_ event: String, error: Error, data: [String: Any] = [:]) {
    var errorData = data
    errorData["error"] = error.localizedDescription
    errorData["error_code"] = (error as NSError).code
    
    logEvent("\(event).error", data: errorData)
  }
  
  // MARK: - Migration-Specific Telemetry
  
  /// Log dual-write operations
  func logDualWrite(_ operation: String, success: Bool, error: Error? = nil) {
    let event = "dualwrite.habit.\(operation).\(success ? "success" : "failed")"
    
    if let error = error {
      logError(event, error: error)
    } else {
      increment(event)
    }
  }
  
  /// Log backfill operations
  func logBackfill(_ operation: String, count: Int? = nil, error: Error? = nil) {
    let event = "backfill.\(operation)"
    
    if let error = error {
      logError(event, error: error)
    } else {
      increment(event)
      if let count = count {
        set("\(event).items", value: count)
      }
    }
  }
  
  /// Log Firestore operations
  func logFirestore(_ operation: String, success: Bool, error: Error? = nil) {
    let event = "firestore.\(operation).\(success ? "success" : "failed")"
    
    if let error = error {
      logError(event, error: error)
    } else {
      increment(event)
    }
  }
  
  // MARK: - Debug Methods
  
  /// Get all counters
  func getAllCounters() -> [String: Int] {
    counters
  }
  
  /// Get all active timers
  func getActiveTimers() -> [String: Date] {
    timers
  }
  
  /// Reset all telemetry data
  func reset() {
    counters.removeAll()
    timers.removeAll()
    logger.info("📊 TelemetryService: Reset all data")
  }
  
  /// Export telemetry data for debugging
  func exportData() -> [String: Any] {
    return [
      "counters": counters,
      "active_timers": timers.mapValues { $0.timeIntervalSince1970 },
      "timestamp": Date().timeIntervalSince1970
    ]
  }
}