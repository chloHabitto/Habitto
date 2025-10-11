import Foundation
import OSLog

// MARK: - DataRetentionPolicy

/// Defines how long different types of data should be retained
struct DataRetentionPolicy: Codable, Equatable {
  // MARK: Lifecycle

  init(
    completionHistoryDays: Int = 365, // 1 year
    difficultyHistoryDays: Int = 180, // 6 months
    usageHistoryDays: Int = 90, // 3 months
    notesDays: Int = 30, // 1 month
    maxHabits: Int = 100,
    autoCleanupEnabled: Bool = true,
    cleanupFrequencyDays: Int = 7, // Weekly cleanup
    lastCleanupDate: Date? = nil)
  {
    self.completionHistoryDays = completionHistoryDays
    self.difficultyHistoryDays = difficultyHistoryDays
    self.usageHistoryDays = usageHistoryDays
    self.notesDays = notesDays
    self.maxHabits = maxHabits
    self.autoCleanupEnabled = autoCleanupEnabled
    self.cleanupFrequencyDays = cleanupFrequencyDays
    self.lastCleanupDate = lastCleanupDate
  }

  // MARK: Internal

  /// Creates a default retention policy
  static let `default` = DataRetentionPolicy()

  /// Creates a conservative retention policy (longer retention)
  static let conservative = DataRetentionPolicy(
    completionHistoryDays: 730, // 2 years
    difficultyHistoryDays: 365, // 1 year
    usageHistoryDays: 180, // 6 months
    notesDays: 90, // 3 months
    maxHabits: 200,
    autoCleanupEnabled: true,
    cleanupFrequencyDays: 14 // Bi-weekly cleanup
  )

  /// Creates an aggressive retention policy (shorter retention)
  static let aggressive = DataRetentionPolicy(
    completionHistoryDays: 90, // 3 months
    difficultyHistoryDays: 60, // 2 months
    usageHistoryDays: 30, // 1 month
    notesDays: 14, // 2 weeks
    maxHabits: 50,
    autoCleanupEnabled: true,
    cleanupFrequencyDays: 3 // Every 3 days
  )

  /// Retention period for completion history (in days)
  let completionHistoryDays: Int

  /// Retention period for difficulty history (in days)
  let difficultyHistoryDays: Int

  /// Retention period for usage history (in days)
  let usageHistoryDays: Int

  /// Retention period for notes (in days)
  let notesDays: Int

  /// Maximum number of habits to retain
  let maxHabits: Int

  /// Whether to enable automatic cleanup
  let autoCleanupEnabled: Bool

  /// Cleanup frequency (in days)
  let cleanupFrequencyDays: Int

  /// Last cleanup date
  let lastCleanupDate: Date?
}

// MARK: - DataRetentionManager

/// Manages data retention and cleanup operations
final class DataRetentionManager {
  // MARK: Lifecycle

  private init() {
    // Load existing policy or use default
    if let savedPolicy = try? userDefaults.getCodable(DataRetentionPolicy.self, forKey: policyKey) {
      self.currentPolicy = savedPolicy
    } else {
      self.currentPolicy = .default
      // Save default policy
      try? userDefaults.setCodable(currentPolicy, forKey: policyKey)
    }

    logger
      .info(
        "DataRetentionManager initialized with policy: \(self.currentPolicy.completionHistoryDays) days retention")
  }

  // MARK: Internal

  static let shared = DataRetentionManager()

  /// Current retention policy
  private(set) var currentPolicy: DataRetentionPolicy

  // MARK: - Policy Management

  /// Updates the retention policy
  func updatePolicy(_ newPolicy: DataRetentionPolicy) async throws {
    currentPolicy = newPolicy
    try await savePolicy()
    logger.info("Retention policy updated")
  }

  // MARK: - Cleanup Operations

  /// Performs data cleanup based on the current policy
  func performCleanup() async throws -> CleanupResult {
    // Skip cleanup operations during vacation mode
    if VacationManager.shared.isActive {
      logger.info("Skipping data cleanup during vacation mode")
      return CleanupResult()
    }

    logger.info("Starting data cleanup")

    let startTime = Date()
    var result = CleanupResult()

    // Check if cleanup is needed
    guard shouldPerformCleanup() else {
      logger.debug("Cleanup not needed at this time")
      return result
    }

    // Cleanup completion history
    result.completionHistoryCleaned = try await cleanupCompletionHistory()

    // Cleanup difficulty history
    result.difficultyHistoryCleaned = try await cleanupDifficultyHistory()

    // Cleanup usage history
    result.usageHistoryCleaned = try await cleanupUsageHistory()

    // Cleanup notes
    result.notesCleaned = try await cleanupNotes()

    // Cleanup excess habits
    result.habitsCleaned = try await cleanupExcessHabits()

    // Update last cleanup date
    var updatedPolicy = currentPolicy
    updatedPolicy = DataRetentionPolicy(
      completionHistoryDays: currentPolicy.completionHistoryDays,
      difficultyHistoryDays: currentPolicy.difficultyHistoryDays,
      usageHistoryDays: currentPolicy.usageHistoryDays,
      notesDays: currentPolicy.notesDays,
      maxHabits: currentPolicy.maxHabits,
      autoCleanupEnabled: currentPolicy.autoCleanupEnabled,
      cleanupFrequencyDays: currentPolicy.cleanupFrequencyDays,
      lastCleanupDate: Date())
    try await updatePolicy(updatedPolicy)

    let duration = Date().timeIntervalSince(startTime)
    result.duration = duration
    result.success = true

    logger
      .info(
        "Data cleanup completed in \(String(format: "%.2f", duration))s - Cleaned: \(result.totalItemsCleaned) items")

    return result
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "DataRetentionManager")
  private let atomicWriter = AtomicFileWriter()
  private let userDefaults = UserDefaultsWrapper.shared

  /// Policy storage key
  private let policyKey = "DataRetentionPolicy"

  /// Saves the current policy
  private func savePolicy() async throws {
    try userDefaults.setCodable(currentPolicy, forKey: policyKey)
  }

  /// Checks if cleanup should be performed
  private func shouldPerformCleanup() -> Bool {
    guard currentPolicy.autoCleanupEnabled else { return false }

    guard let lastCleanup = currentPolicy.lastCleanupDate else { return true }

    let daysSinceLastCleanup = Calendar.current
      .dateComponents([.day], from: lastCleanup, to: Date()).day ?? 0
    return daysSinceLastCleanup >= currentPolicy.cleanupFrequencyDays
  }

  // MARK: - History Cleanup

  /// Cleans up completion history based on retention policy
  private func cleanupCompletionHistory() async throws -> Int {
    logger.debug("Cleaning up completion history")

    let cutoffDate = Calendar.current.date(
      byAdding: .day,
      value: -currentPolicy.completionHistoryDays,
      to: Date()) ?? Date()
    var cleanedCount = 0

    // Load all habits
    let habits = try await loadAllHabits()

    for habit in habits {
      var updatedHabit = habit
      let originalCount = updatedHabit.completionHistory.count

      // Remove old completion history entries
      updatedHabit.completionHistory = updatedHabit.completionHistory.filter { dateString, _ in
        guard let date = ISO8601DateHelper.shared.date(from: dateString) else { return true }
        return date >= cutoffDate
      }

      let removedCount = originalCount - updatedHabit.completionHistory.count
      if removedCount > 0 {
        cleanedCount += removedCount
        try await saveHabit(updatedHabit)
      }
    }

    logger.debug("Cleaned up \(cleanedCount) completion history entries")
    return cleanedCount
  }

  /// Cleans up difficulty history based on retention policy
  private func cleanupDifficultyHistory() async throws -> Int {
    logger.debug("Cleaning up difficulty history")

    let cutoffDate = Calendar.current.date(
      byAdding: .day,
      value: -currentPolicy.difficultyHistoryDays,
      to: Date()) ?? Date()
    var cleanedCount = 0

    let habits = try await loadAllHabits()

    for habit in habits {
      var updatedHabit = habit
      let originalCount = updatedHabit.difficultyHistory.count

      // Remove old difficulty history entries
      updatedHabit.difficultyHistory = updatedHabit.difficultyHistory.filter { dateString, _ in
        guard let date = ISO8601DateHelper.shared.date(from: dateString) else { return true }
        return date >= cutoffDate
      }

      let removedCount = originalCount - updatedHabit.difficultyHistory.count
      if removedCount > 0 {
        cleanedCount += removedCount
        try await saveHabit(updatedHabit)
      }
    }

    logger.debug("Cleaned up \(cleanedCount) difficulty history entries")
    return cleanedCount
  }

  /// Cleans up usage history based on retention policy
  private func cleanupUsageHistory() async throws -> Int {
    logger.debug("Cleaning up usage history")

    let cutoffDate = Calendar.current.date(
      byAdding: .day,
      value: -currentPolicy.usageHistoryDays,
      to: Date()) ?? Date()
    var cleanedCount = 0

    let habits = try await loadAllHabits()

    for habit in habits {
      var updatedHabit = habit
      let originalCount = updatedHabit.actualUsage.count

      // Remove old usage history entries
      updatedHabit.actualUsage = updatedHabit.actualUsage.filter { dateString, _ in
        guard let date = ISO8601DateHelper.shared.date(from: dateString) else { return true }
        return date >= cutoffDate
      }

      let removedCount = originalCount - updatedHabit.actualUsage.count
      if removedCount > 0 {
        cleanedCount += removedCount
        try await saveHabit(updatedHabit)
      }
    }

    logger.debug("Cleaned up \(cleanedCount) usage history entries")
    return cleanedCount
  }

  /// Cleans up notes based on retention policy
  private func cleanupNotes() async throws -> Int {
    logger.debug("Cleaning up notes - placeholder implementation")

    // TODO: Implement notes cleanup when Habit model supports notes
    // For now, return 0 as no notes are supported in the current Habit model
    return 0
  }

  /// Cleans up excess habits based on retention policy
  private func cleanupExcessHabits() async throws -> Int {
    logger.debug("Cleaning up excess habits")

    let habits = try await loadAllHabits()

    guard habits.count > currentPolicy.maxHabits else {
      logger.debug("No excess habits to clean up")
      return 0
    }

    // Sort habits by creation date (oldest first)
    let sortedHabits = habits.sorted { $0.createdAt < $1.createdAt }

    // Keep only the most recent habits
    let _ = Array(sortedHabits.suffix(currentPolicy.maxHabits)) // Keep for future use
    let habitsToRemove = Array(sortedHabits.prefix(habits.count - currentPolicy.maxHabits))

    // Remove excess habits
    for habit in habitsToRemove {
      try await deleteHabit(habit)
    }

    logger.debug("Cleaned up \(habitsToRemove.count) excess habits")
    return habitsToRemove.count
  }

  // MARK: - Data Access Helpers

  /// Loads all habits from storage
  private func loadAllHabits() async throws -> [Habit] {
    // Try SwiftData first, fallback to UserDefaults
    do {
      let swiftDataStorage = SwiftDataStorage()
      return try await swiftDataStorage.loadHabits()
    } catch {
      let userDefaultsStorage = UserDefaultsStorage()
      return try await userDefaultsStorage.loadHabits()
    }
  }

  /// Saves a habit to storage
  private func saveHabit(_ habit: Habit) async throws {
    // Try SwiftData first, fallback to UserDefaults
    do {
      let swiftDataStorage = SwiftDataStorage()
      try await swiftDataStorage.saveHabit(habit)
    } catch {
      let userDefaultsStorage = UserDefaultsStorage()
      try await userDefaultsStorage.saveHabit(habit)
    }
  }

  /// Deletes a habit from storage
  private func deleteHabit(_ habit: Habit) async throws {
    // Try SwiftData first, fallback to UserDefaults
    do {
      let swiftDataStorage = SwiftDataStorage()
      try await swiftDataStorage.deleteHabit(id: habit.id)
    } catch {
      let userDefaultsStorage = UserDefaultsStorage()
      try await userDefaultsStorage.deleteHabit(id: habit.id)
    }
  }
}

// MARK: - CleanupResult

/// Result of a data cleanup operation
struct CleanupResult: Codable {
  var success = false
  var duration: TimeInterval = 0
  var completionHistoryCleaned = 0
  var difficultyHistoryCleaned = 0
  var usageHistoryCleaned = 0
  var notesCleaned = 0
  var habitsCleaned = 0

  var totalItemsCleaned: Int {
    completionHistoryCleaned + difficultyHistoryCleaned + usageHistoryCleaned + notesCleaned +
      habitsCleaned
  }
}

// MARK: - Retention Policy Extensions

extension DataRetentionPolicy {
  /// Gets a human-readable description of the policy
  var description: String {
    """
    Data Retention Policy:
    - Completion History: \(completionHistoryDays) days
    - Difficulty History: \(difficultyHistoryDays) days
    - Usage History: \(usageHistoryDays) days
    - Notes: \(notesDays) days
    - Max Habits: \(maxHabits)
    - Auto Cleanup: \(autoCleanupEnabled ? "Enabled" : "Disabled")
    - Cleanup Frequency: \(cleanupFrequencyDays) days
    """
  }

  /// Checks if the policy is conservative (long retention)
  var isConservative: Bool {
    completionHistoryDays >= 365 && difficultyHistoryDays >= 180 && usageHistoryDays >= 90
  }

  /// Checks if the policy is aggressive (short retention)
  var isAggressive: Bool {
    completionHistoryDays <= 90 && difficultyHistoryDays <= 60 && usageHistoryDays <= 30
  }
}
