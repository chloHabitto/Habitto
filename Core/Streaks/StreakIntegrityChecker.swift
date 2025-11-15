import Foundation
import OSLog
import SwiftData

/// Snapshot of the last known streak state used for integrity comparisons.
struct StreakIntegritySnapshot: Codable {
  let userId: String
  let timestamp: Date
  let currentStreak: Int
  let longestStreak: Int
  let lastCompleteDate: Date?
  let completionChecksum: String
}

/// Periodically audits the persisted streak state to detect regressions before users notice.
@MainActor
final class StreakIntegrityChecker {
  static let shared = StreakIntegrityChecker()

  private let logger = Logger(subsystem: "com.habitto.app", category: "StreakIntegrityChecker")
  private let defaults = UserDefaults.standard
  private let snapshotsKey = "streak_integrity_snapshots_v1"
  private let lastAuditKeyPrefix = "streak_integrity_last_audit_"
  private let auditInterval: TimeInterval = 60 * 60 * 6 // every 6 hours

  private init() {}

  func handleSnapshot(_ snapshot: StreakIntegritySnapshot) {
    var snapshots = loadSnapshots()
    if let previous = snapshots[snapshot.userId] {
      detectRegression(previous: previous, current: snapshot)
    }

    snapshots[snapshot.userId] = snapshot
    saveSnapshots(snapshots)

    maybeRunAudit(for: snapshot)
  }

  private func detectRegression(previous: StreakIntegritySnapshot, current: StreakIntegritySnapshot) {
    guard previous.completionChecksum == current.completionChecksum else {
      // Underlying completion data changed; jumps are expected.
      return
    }

    guard current.currentStreak <= previous.currentStreak else { return }

    if current.currentStreak < previous.currentStreak {
      logger.error(
        "⚠️ Streak regression detected: previous=\(previous.currentStreak) current=\(current.currentStreak)")
      TelemetryService.shared.logEvent(
        "streak.integrity.regression",
        data: [
          "previous": previous.currentStreak,
          "current": current.currentStreak,
          "user": anonymizedUserId(previous.userId)
        ])
    }
  }

  private func maybeRunAudit(for snapshot: StreakIntegritySnapshot) {
    let lastAuditKey = lastAuditKeyPrefix + snapshot.userId
    let now = Date()
    if let lastRun = defaults.object(forKey: lastAuditKey) as? Date,
      now.timeIntervalSince(lastRun) < auditInterval
    {
      return
    }

    defaults.set(now, forKey: lastAuditKey)

    let userId = snapshot.userId
    Task { [self] in
      await self.performAudit(for: userId)
    }
  }

  private func performAudit(for userId: String) async {
    self.logger.info("🔍 Running streak audit for user \(self.anonymizedUserId(userId))")

    let modelContext = SwiftDataContainer.shared.modelContext

    do {
      var habitsDescriptor = FetchDescriptor<HabitData>(
        predicate: #Predicate { habit in
          habit.userId == userId
        }
      )
      habitsDescriptor.includePendingChanges = true
      let habitDataList = try modelContext.fetch(habitsDescriptor)
      let habits = habitDataList.map { $0.toHabit() }

      var completionDescriptor = FetchDescriptor<CompletionRecord>()
      completionDescriptor.includePendingChanges = true
      let allRecords = try modelContext.fetch(completionDescriptor)
      let filteredRecords = allRecords.filter { record in
        if userId.isEmpty || userId == "guest" {
          return record.userId.isEmpty || record.userId == "guest"
        }
        return record.userId == userId
      }.filter { $0.isCompleted }

      let result = StreakCalculator.computeCurrentStreak(
        habits: habits,
        completionRecords: filteredRecords)

      TelemetryService.shared.logEvent(
        "streak.integrity.audit",
        data: [
          "user": anonymizedUserId(userId),
          "streak": result.currentStreak,
          "daysProcessed": result.processedDayCount
        ])
    } catch {
      logger.error("❌ Failed to run streak audit: \(String(describing: error))")
      TelemetryService.shared.logError("streak.integrity.audit", error: error)
    }
  }

  private func loadSnapshots() -> [String: StreakIntegritySnapshot] {
    guard let data = defaults.data(forKey: snapshotsKey) else {
      return [:]
    }

    do {
      return try JSONDecoder().decode([String: StreakIntegritySnapshot].self, from: data)
    } catch {
      logger.error("❌ Failed to decode streak snapshots: \(String(describing: error))")
      return [:]
    }
  }

  private func saveSnapshots(_ snapshots: [String: StreakIntegritySnapshot]) {
    do {
      let data = try JSONEncoder().encode(snapshots)
      defaults.set(data, forKey: snapshotsKey)
    } catch {
      logger.error("❌ Failed to encode streak snapshots: \(String(describing: error))")
    }
  }

  private func anonymizedUserId(_ userId: String) -> String {
    guard !userId.isEmpty else { return "guest" }
    return String(userId.prefix(6))
  }
}

