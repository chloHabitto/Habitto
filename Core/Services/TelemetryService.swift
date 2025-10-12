import Foundation
import Combine

/// Telemetry service for tracking operational metrics
///
/// Tracks:
/// - Firestore writes (ok/failed)
/// - Security rules denials
/// - Transaction retries
/// - XP awards
/// - Streak updates
///
/// All counters are in-memory and reset on app restart.
/// Exposed via @Published properties for real-time UI updates.
@MainActor
class TelemetryService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = TelemetryService()
    
    // MARK: - Published Counters
    
    /// Firestore write counters
    @Published private(set) var firestoreWritesOk: Int = 0
    @Published private(set) var firestoreWritesFailed: Int = 0
    
    /// Security rules denial counter
    @Published private(set) var rulesDenials: Int = 0
    
    /// Transaction retry counter
    @Published private(set) var transactionRetries: Int = 0
    
    /// XP award counters
    @Published private(set) var xpAwardsTotal: Int = 0
    @Published private(set) var xpAwardsFailed: Int = 0
    
    /// Streak update counters
    @Published private(set) var streakUpdates: Int = 0
    @Published private(set) var streakUpdatesFailed: Int = 0
    
    /// Completion counters
    @Published private(set) var completionsMarked: Int = 0
    @Published private(set) var completionsFailed: Int = 0
    
    // MARK: - Computed Properties
    
    var totalFirestoreWrites: Int {
        firestoreWritesOk + firestoreWritesFailed
    }
    
    var firestoreWriteSuccessRate: Double {
        guard totalFirestoreWrites > 0 else { return 1.0 }
        return Double(firestoreWritesOk) / Double(totalFirestoreWrites)
    }
    
    var totalXPAwards: Int {
        xpAwardsTotal + xpAwardsFailed
    }
    
    var xpAwardSuccessRate: Double {
        guard totalXPAwards > 0 else { return 1.0 }
        return Double(xpAwardsTotal) / Double(totalXPAwards)
    }
    
    var totalStreakUpdates: Int {
        streakUpdates + streakUpdatesFailed
    }
    
    var streakUpdateSuccessRate: Double {
        guard totalStreakUpdates > 0 else { return 1.0 }
        return Double(streakUpdates) / Double(totalStreakUpdates)
    }
    
    var totalCompletions: Int {
        completionsMarked + completionsFailed
    }
    
    var completionSuccessRate: Double {
        guard totalCompletions > 0 else { return 1.0 }
        return Double(completionsMarked) / Double(totalCompletions)
    }
    
    // MARK: - Initialization
    
    private init() {
        HabittoLogger.telemetry.info("TelemetryService initialized")
    }
    
    // MARK: - Firestore Metrics
    
    func incrementFirestoreWrite(success: Bool) {
        if success {
            firestoreWritesOk += 1
        } else {
            firestoreWritesFailed += 1
        }
    }
    
    func incrementRulesDenial() {
        rulesDenials += 1
    }
    
    func incrementTransactionRetry() {
        transactionRetries += 1
    }
    
    // MARK: - XP Metrics
    
    func incrementXPAward(success: Bool) {
        if success {
            xpAwardsTotal += 1
        } else {
            xpAwardsFailed += 1
        }
    }
    
    // MARK: - Streak Metrics
    
    func incrementStreakUpdate(success: Bool) {
        if success {
            streakUpdates += 1
        } else {
            streakUpdatesFailed += 1
        }
    }
    
    // MARK: - Completion Metrics
    
    func incrementCompletion(success: Bool) {
        if success {
            completionsMarked += 1
        } else {
            completionsFailed += 1
        }
    }
    
    // MARK: - Reset
    
    func resetCounters() {
        firestoreWritesOk = 0
        firestoreWritesFailed = 0
        rulesDenials = 0
        transactionRetries = 0
        xpAwardsTotal = 0
        xpAwardsFailed = 0
        streakUpdates = 0
        streakUpdatesFailed = 0
        completionsMarked = 0
        completionsFailed = 0
        
        HabittoLogger.telemetry.info("Telemetry counters reset")
    }
    
    // MARK: - Summary
    
    func getSummary() -> TelemetrySummary {
        TelemetrySummary(
            firestoreWrites: OperationMetric(
                success: firestoreWritesOk,
                failed: firestoreWritesFailed,
                successRate: firestoreWriteSuccessRate
            ),
            xpAwards: OperationMetric(
                success: xpAwardsTotal,
                failed: xpAwardsFailed,
                successRate: xpAwardSuccessRate
            ),
            streakUpdates: OperationMetric(
                success: streakUpdates,
                failed: streakUpdatesFailed,
                successRate: streakUpdateSuccessRate
            ),
            completions: OperationMetric(
                success: completionsMarked,
                failed: completionsFailed,
                successRate: completionSuccessRate
            ),
            rulesDenials: rulesDenials,
            transactionRetries: transactionRetries
        )
    }
}

// MARK: - Models

struct TelemetrySummary {
    let firestoreWrites: OperationMetric
    let xpAwards: OperationMetric
    let streakUpdates: OperationMetric
    let completions: OperationMetric
    let rulesDenials: Int
    let transactionRetries: Int
    
    var hasIssues: Bool {
        firestoreWrites.successRate < 0.95 ||
        xpAwards.successRate < 0.95 ||
        streakUpdates.successRate < 0.95 ||
        completions.successRate < 0.95 ||
        rulesDenials > 0
    }
}

struct OperationMetric {
    let success: Int
    let failed: Int
    let successRate: Double
    
    var total: Int {
        success + failed
    }
    
    var successPercentage: String {
        String(format: "%.1f%%", successRate * 100)
    }
}

