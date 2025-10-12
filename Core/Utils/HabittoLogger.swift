import Foundation
import OSLog

/// Lightweight logger wrapper for Habitto app
///
/// Categories:
/// - `firestore_write`: Firestore write operations
/// - `rules_denied`: Security rules denials
/// - `xp_award`: XP award operations
/// - `streak`: Streak calculations
/// - `telemetry`: Telemetry counters
/// - `error`: Error conditions
/// - `debug`: Debug information
///
/// Usage:
/// ```swift
/// HabittoLogger.firestore.info("Writing habit to Firestore", habit: habitId)
/// HabittoLogger.rules.warning("Security rule denied", operation: "write")
/// HabittoLogger.xp.info("XP awarded", amount: 50, reason: "daily_complete")
/// ```
enum HabittoLogger {
    // MARK: - Categories
    
    /// Firestore write operations
    static let firestore = Logger(subsystem: "com.habitto.app", category: "firestore_write")
    
    /// Security rules denials
    static let rules = Logger(subsystem: "com.habitto.app", category: "rules_denied")
    
    /// XP award operations
    static let xp = Logger(subsystem: "com.habitto.app", category: "xp_award")
    
    /// Streak calculations
    static let streak = Logger(subsystem: "com.habitto.app", category: "streak")
    
    /// Telemetry counters
    static let telemetry = Logger(subsystem: "com.habitto.app", category: "telemetry")
    
    /// Error conditions
    static let error = Logger(subsystem: "com.habitto.app", category: "error")
    
    /// Debug information
    static let debug = Logger(subsystem: "com.habitto.app", category: "debug")
    
    /// General app information
    static let app = Logger(subsystem: "com.habitto.app", category: "app")
    
    // MARK: - Convenience Methods
    
    /// Log a Firestore write operation
    static func logFirestoreWrite(
        _ message: String,
        collection: String,
        documentId: String,
        success: Bool,
        error: Error? = nil
    ) {
        if success {
            firestore.info("✅ \(message) | collection: \(collection) | doc: \(documentId)")
        } else {
            let errorMsg = error?.localizedDescription ?? "Unknown error"
            firestore.error("❌ \(message) | collection: \(collection) | doc: \(documentId) | error: \(errorMsg)")
        }
    }
    
    /// Log a security rules denial
    static func logRulesDenied(
        operation: String,
        path: String,
        reason: String
    ) {
        rules.warning("🚫 Rules denied | op: \(operation) | path: \(path) | reason: \(reason)")
    }
    
    /// Log an XP award
    static func logXPAward(
        amount: Int,
        reason: String,
        userId: String,
        success: Bool,
        error: Error? = nil
    ) {
        if success {
            xp.info("🎁 XP awarded | amount: \(amount) | reason: \(reason) | user: \(userId)")
        } else {
            let errorMsg = error?.localizedDescription ?? "Unknown error"
            xp.error("❌ XP award failed | amount: \(amount) | reason: \(reason) | user: \(userId) | error: \(errorMsg)")
        }
    }
    
    /// Log a streak update
    static func logStreakUpdate(
        habitId: String,
        current: Int,
        longest: Int,
        action: String,
        success: Bool
    ) {
        if success {
            streak.info("🔥 Streak updated | habit: \(habitId) | current: \(current) | longest: \(longest) | action: \(action)")
        } else {
            streak.error("❌ Streak update failed | habit: \(habitId) | action: \(action)")
        }
    }
    
    /// Log a transaction retry
    static func logTransactionRetry(
        operation: String,
        attempt: Int,
        maxAttempts: Int
    ) {
        debug.warning("🔄 Transaction retry | op: \(operation) | attempt: \(attempt)/\(maxAttempts)")
    }
    
    /// Log an error condition
    static func logError(
        _ message: String,
        error: Error,
        context: [String: Any] = [:]
    ) {
        var contextStr = ""
        if !context.isEmpty {
            contextStr = " | context: \(context.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        }
        
        self.error.error("❌ \(message) | error: \(error.localizedDescription)\(contextStr)")
    }
    
    /// Log debug information
    static func logDebug(
        _ message: String,
        metadata: [String: Any] = [:]
    ) {
        var metadataStr = ""
        if !metadata.isEmpty {
            metadataStr = " | \(metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        }
        
        debug.debug("🐛 \(message)\(metadataStr)")
    }
}

// MARK: - Logger Extensions

extension Logger {
    /// Log with emoji prefix for visual distinction
    func info(_ message: String, emoji: String = "ℹ️") {
        self.info("\(emoji) \(message)")
    }
    
    func warning(_ message: String, emoji: String = "⚠️") {
        self.warning("\(emoji) \(message)")
    }
    
    func error(_ message: String, emoji: String = "❌") {
        self.error("\(emoji) \(message)")
    }
    
    func debug(_ message: String, emoji: String = "🐛") {
        self.debug("\(emoji) \(message)")
    }
}

