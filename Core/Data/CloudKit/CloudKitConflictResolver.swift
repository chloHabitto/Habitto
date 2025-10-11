import CloudKit
import Foundation

// MARK: - CloudKitConflictResolver

/// Handles conflict resolution for CloudKit synchronization
@MainActor
class CloudKitConflictResolver: ObservableObject {
  // MARK: Lifecycle

  init() {
    loadPendingConflicts()
  }

  // MARK: Internal

  static let shared = CloudKitConflictResolver()

  // MARK: - Published Properties

  @Published var pendingConflicts: [ConflictRecord] = []
  @Published var isResolving = false

  // MARK: - Public Methods

  /// Detect conflicts between local and remote records
  func detectConflicts(local: [CloudKitHabit], remote: [CloudKitHabit]) -> [ConflictRecord] {
    var conflicts: [ConflictRecord] = []

    let localDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
    let remoteDict = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })

    for id in Set(localDict.keys).intersection(Set(remoteDict.keys)) {
      guard let localRecord = localDict[id],
            let remoteRecord = remoteDict[id] else { continue }

      // Check if records have been modified since last sync
      if localRecord.lastModified != remoteRecord.lastModified {
        let conflict = ConflictRecord(
          id: UUID(),
          recordType: .habit,
          recordId: id,
          localRecord: localRecord,
          remoteRecord: remoteRecord,
          conflictType: determineConflictType(local: localRecord, remote: remoteRecord),
          detectedAt: Date())
        conflicts.append(conflict)
      }
    }

    pendingConflicts = conflicts
    savePendingConflicts()

    return conflicts
  }

  /// Resolve a specific conflict
  func resolveConflict(
    _ conflict: ConflictRecord,
    using resolution: ConflictResolution) async -> ResolveResult
  {
    isResolving = true
    defer { isResolving = false }

    do {
      let resolvedRecord = try await performResolution(conflict, using: resolution)

      // Remove from pending conflicts
      pendingConflicts.removeAll { $0.id == conflict.id }
      savePendingConflicts()

      return .success(resolvedRecord)

    } catch {
      return .failure(error)
    }
  }

  /// Auto-resolve conflicts using predefined rules
  func autoResolveConflicts() async -> [ResolveResult] {
    var results: [ResolveResult] = []

    for conflict in pendingConflicts {
      let resolution = determineAutoResolution(for: conflict)
      let result = await resolveConflict(conflict, using: resolution)
      results.append(result)
    }

    return results
  }

  /// Get conflict statistics
  func getConflictStatistics() -> ConflictStatistics {
    let totalConflicts = pendingConflicts.count
    let habitConflicts = pendingConflicts.filter { $0.recordType == .habit }.count
    let reminderConflicts = pendingConflicts.filter { $0.recordType == .reminder }.count
    let analyticsConflicts = pendingConflicts.filter { $0.recordType == .analytics }.count

    return ConflictStatistics(
      totalConflicts: totalConflicts,
      habitConflicts: habitConflicts,
      reminderConflicts: reminderConflicts,
      analyticsConflicts: analyticsConflicts,
      oldestConflict: pendingConflicts.map { $0.detectedAt }.min(),
      newestConflict: pendingConflicts.map { $0.detectedAt }.max())
  }

  // MARK: Private

  // MARK: - Private Properties

  private let conflictStorage = ConflictStorage()

  // MARK: - Private Methods

  private func determineConflictType(local: CloudKitHabit, remote: CloudKitHabit) -> ConflictType {
    // Check for different types of conflicts
    if local.name != remote.name || local.description != remote.description {
      return .contentConflict
    }

    if local.completionHistory != remote.completionHistory {
      return .dataConflict
    }

    if local.streak != remote.streak {
      return .calculationConflict
    }

    return .timestampConflict
  }

  private func determineAutoResolution(for conflict: ConflictRecord) -> ConflictResolution {
    switch conflict.conflictType {
    case .contentConflict:
      // For content conflicts, prefer the more recent modification
      if conflict.localRecord.lastModified > conflict.remoteRecord.lastModified {
        .useLocal
      } else {
        .useRemote
      }

    case .dataConflict:
      // For data conflicts, merge the data
      .merge

    case .calculationConflict:
      // For calculation conflicts, recalculate based on merged data
      .recalculate

    case .timestampConflict:
      // For timestamp conflicts, use the more recent
      if conflict.localRecord.lastModified > conflict.remoteRecord.lastModified {
        .useLocal
      } else {
        .useRemote
      }
    }
  }

  private func performResolution(
    _ conflict: ConflictRecord,
    using resolution: ConflictResolution) async throws -> CloudKitHabit
  {
    switch resolution {
    case .useLocal:
      conflict.localRecord

    case .useRemote:
      conflict.remoteRecord

    case .merge:
      try mergeRecords(local: conflict.localRecord, remote: conflict.remoteRecord)

    case .recalculate:
      try recalculateRecord(local: conflict.localRecord, remote: conflict.remoteRecord)
    }
  }

  private func mergeRecords(local: CloudKitHabit, remote: CloudKitHabit) throws -> CloudKitHabit {
    // Merge completion history
    var mergedCompletionHistory = local.completionHistory
    for (date, progress) in remote.completionHistory {
      if let localProgress = mergedCompletionHistory[date] {
        // Use the higher progress value
        mergedCompletionHistory[date] = max(localProgress, progress)
      } else {
        mergedCompletionHistory[date] = progress
      }
    }

    // Merge difficulty history
    var mergedDifficultyHistory = local.difficultyHistory
    for (date, difficulty) in remote.difficultyHistory {
      if let localDifficulty = mergedDifficultyHistory[date] {
        // Use the average difficulty
        mergedDifficultyHistory[date] = (localDifficulty + difficulty) / 2
      } else {
        mergedDifficultyHistory[date] = difficulty
      }
    }

    // Merge actual usage
    var mergedActualUsage = local.actualUsage
    for (date, usage) in remote.actualUsage {
      if let localUsage = mergedActualUsage[date] {
        // Use the higher usage value
        mergedActualUsage[date] = max(localUsage, usage)
      } else {
        mergedActualUsage[date] = usage
      }
    }

    // Use the more recent modification time
    let mergedLastModified = max(local.lastModified, remote.lastModified)

    return CloudKitHabit(
      id: local.id,
      name: local.name, // Prefer local name
      description: local.description, // Prefer local description
      icon: local.icon, // Prefer local icon
      colorHex: local.colorHex, // Prefer local color
      habitType: local.habitType, // Prefer local habit type
      schedule: local.schedule, // Prefer local schedule
      goal: local.goal, // Prefer local goal
      reminder: local.reminder, // Prefer local reminder
      startDate: local.startDate, // Prefer local start date
      endDate: local.endDate ?? remote.endDate, // Use local or remote end date
      isCompleted: local.isCompleted || remote.isCompleted, // True if either is completed
      streak: max(local.streak, remote.streak), // Use higher streak
      createdAt: local.createdAt, // Prefer local creation date
      completionHistory: mergedCompletionHistory,
      difficultyHistory: mergedDifficultyHistory,
      baseline: max(local.baseline, remote.baseline), // Use higher baseline
      target: min(local.target, remote.target), // Use lower target
      actualUsage: mergedActualUsage,
      cloudKitRecordID: local.cloudKitRecordID ?? remote.cloudKitRecordID,
      lastModified: mergedLastModified,
      isDeleted: local.isDeleted && remote.isDeleted // Deleted only if both are deleted
    )
  }

  private func recalculateRecord(
    local: CloudKitHabit,
    remote: CloudKitHabit) throws -> CloudKitHabit
  {
    // Merge the data first
    let merged = try mergeRecords(local: local, remote: remote)

    // Recalculate streak based on merged completion history
    let recalculatedStreak = calculateStreak(from: merged.completionHistory, goal: merged.goal)

    // Recalculate completion status
    let today = Calendar.current.startOfDay(for: Date())
    let todayKey = CloudKitHabit.dateKey(for: today)
    let todayProgress = merged.completionHistory[todayKey] ?? 0
    let goalAmount = parseGoalAmount(from: merged.goal) ?? 1
    let recalculatedIsCompleted = todayProgress >= goalAmount

    return CloudKitHabit(
      id: merged.id,
      name: merged.name,
      description: merged.description,
      icon: merged.icon,
      colorHex: merged.colorHex,
      habitType: merged.habitType,
      schedule: merged.schedule,
      goal: merged.goal,
      reminder: merged.reminder,
      startDate: merged.startDate,
      endDate: merged.endDate,
      isCompleted: recalculatedIsCompleted,
      streak: recalculatedStreak,
      createdAt: merged.createdAt,
      completionHistory: merged.completionHistory,
      difficultyHistory: merged.difficultyHistory,
      baseline: merged.baseline,
      target: merged.target,
      actualUsage: merged.actualUsage,
      cloudKitRecordID: merged.cloudKitRecordID,
      lastModified: Date(), // Update modification time
      isDeleted: merged.isDeleted)
  }

  private func calculateStreak(from completionHistory: [String: Int], goal: String) -> Int {
    let goalAmount = parseGoalAmount(from: goal) ?? 1
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var streak = 0
    var currentDate = today

    while true {
      let dateKey = CloudKitHabit.dateKey(for: currentDate)
      let progress = completionHistory[dateKey] ?? 0

      if progress >= goalAmount {
        streak += 1
        currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
      } else {
        break
      }
    }

    return streak
  }

  private func parseGoalAmount(from goalString: String) -> Int? {
    let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
    for component in components {
      if let amount = Int(component), amount > 0 {
        return amount
      }
    }
    return nil
  }

  private func loadPendingConflicts() {
    pendingConflicts = conflictStorage.loadConflicts()
  }

  private func savePendingConflicts() {
    conflictStorage.saveConflicts(pendingConflicts)
  }
}

// MARK: - ConflictRecord

struct ConflictRecord: Identifiable {
  let id: UUID
  let recordType: CloudKitSchema.RecordType
  let recordId: UUID
  let localRecord: CloudKitHabit
  let remoteRecord: CloudKitHabit
  let conflictType: ConflictType
  let detectedAt: Date
}

// MARK: - ConflictType

enum ConflictType: String, Codable, CaseIterable {
  case contentConflict = "content_conflict"
  case dataConflict = "data_conflict"
  case calculationConflict = "calculation_conflict"
  case timestampConflict = "timestamp_conflict"
}

// MARK: - ConflictResolution

enum ConflictResolution: String, Codable, CaseIterable {
  case useLocal = "use_local"
  case useRemote = "use_remote"
  case merge
  case recalculate
}

// MARK: - ResolveResult

enum ResolveResult {
  case success(CloudKitHabit)
  case failure(Error)
}

// MARK: - ConflictStatistics

struct ConflictStatistics {
  let totalConflicts: Int
  let habitConflicts: Int
  let reminderConflicts: Int
  let analyticsConflicts: Int
  let oldestConflict: Date?
  let newestConflict: Date?
}

// MARK: - ConflictStorage

class ConflictStorage {
  // MARK: Internal

  func saveConflicts(_ conflicts: [ConflictRecord]) {
    // For now, we'll store conflicts in memory only
    // In a real implementation, you might want to use a different storage mechanism
    // that doesn't require Codable conformance
    print("Saving \(conflicts.count) conflicts to memory")
  }

  func loadConflicts() -> [ConflictRecord] {
    // For now, we'll start with an empty array
    // In a real implementation, you might want to use a different storage mechanism
    print("Loading conflicts from memory")
    return []
  }

  func clearConflicts() {
    userDefaults.removeObject(forKey: conflictsKey)
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let conflictsKey = "CloudKitPendingConflicts"
}

// MARK: - CloudKitHabit Extensions

extension CloudKitHabit {
  static func dateKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
