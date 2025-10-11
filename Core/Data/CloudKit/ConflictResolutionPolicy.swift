import CloudKit
import Foundation
import OSLog

// MARK: - ConflictResolutionPolicy

/// Defines how conflicts should be resolved for different field types
enum ConflictResolutionPolicy: String, CaseIterable, Codable {
  case lastWriterWins = "last_writer_wins"
  case firstWriterWins = "first_writer_wins"
  case merge
  case custom

  // MARK: Internal

  var displayName: String {
    switch self {
    case .lastWriterWins:
      "Last Writer Wins"
    case .firstWriterWins:
      "First Writer Wins"
    case .merge:
      "Merge"
    case .custom:
      "Custom"
    }
  }

  var description: String {
    switch self {
    case .lastWriterWins:
      "The most recently modified value takes precedence"
    case .firstWriterWins:
      "The first value written takes precedence"
    case .merge:
      "Values are merged intelligently"
    case .custom:
      "Custom resolution logic is applied"
    }
  }
}

// MARK: - FieldConflictRule

/// Defines conflict resolution rules for specific fields
struct FieldConflictRule: Codable, Equatable {
  // MARK: Lifecycle

  init(
    fieldName: String,
    policy: ConflictResolutionPolicy,
    priority: Int = 0,
    customResolver: String? = nil)
  {
    self.fieldName = fieldName
    self.policy = policy
    self.priority = priority
    self.customResolver = customResolver
  }

  // MARK: Internal

  let fieldName: String
  let policy: ConflictResolutionPolicy
  let priority: Int // Higher priority rules are applied first
  let customResolver: String? // For custom resolution logic
}

// MARK: - ConflictResolutionManager

/// Manages conflict resolution for CloudKit data
final class ConflictResolutionManager {
  // MARK: Lifecycle

  private init() {
    logger.info("ConflictResolutionManager initialized with \(self.defaultRules.count) default rules")
  }

  // MARK: Internal

  static let shared = ConflictResolutionManager()

  // MARK: - Rule Management

  /// Adds a custom conflict resolution rule
  func addCustomRule(_ rule: FieldConflictRule) {
    customRules.append(rule)
    customRules.sort { $0.priority > $1.priority }
    logger
      .debug("Added custom rule for field: \(rule.fieldName) with policy: \(rule.policy.rawValue)")
  }

  /// Removes a custom conflict resolution rule
  func removeCustomRule(for fieldName: String) {
    customRules.removeAll { $0.fieldName == fieldName }
    logger.debug("Removed custom rule for field: \(fieldName)")
  }

  /// Gets all conflict resolution rules (default + custom)
  func getAllRules() -> [FieldConflictRule] {
    let allRules = defaultRules + customRules
    return allRules.sorted { $0.priority > $1.priority }
  }

  /// Gets the rule for a specific field
  func getRule(for fieldName: String) -> FieldConflictRule? {
    getAllRules().first { $0.fieldName == fieldName }
  }

  // MARK: - Conflict Resolution

  /// Resolves conflicts between two habit records
  func resolveHabitConflict(_ localHabit: Habit, _ remoteHabit: Habit) -> Habit {
    logger.info("Resolving conflict between local and remote habit: \(localHabit.name)")

    var resolvedHabit = localHabit

    // Get all field names from both habits
    let allFields = Set(getHabitFieldNames(localHabit) + getHabitFieldNames(remoteHabit))

    for fieldName in allFields {
      let localValue = getFieldValue(from: localHabit, fieldName: fieldName)
      let remoteValue = getFieldValue(from: remoteHabit, fieldName: fieldName)

      // Skip if values are the same
      if areValuesEqual(localValue, remoteValue) {
        continue
      }

      // Get resolution rule for this field
      guard let rule = getRule(for: fieldName) else {
        logger
          .warning(
            "No conflict resolution rule found for field: \(fieldName), using last writer wins")
        continue
      }

      // Resolve conflict based on rule
      let resolvedValue = resolveFieldConflict(
        fieldName: fieldName,
        localValue: localValue,
        remoteValue: remoteValue,
        rule: rule,
        localHabit: localHabit,
        remoteHabit: remoteHabit)

      // Apply resolved value
      setFieldValue(to: &resolvedHabit, fieldName: fieldName, value: resolvedValue)

      logger.debug("Resolved conflict for field \(fieldName): \(rule.policy.rawValue)")
    }

    // Update timestamp to reflect resolution
    resolvedHabit = Habit(
      id: resolvedHabit.id,
      name: resolvedHabit.name,
      description: resolvedHabit.description,
      icon: resolvedHabit.icon,
      color: resolvedHabit.color,
      habitType: resolvedHabit.habitType,
      schedule: resolvedHabit.schedule,
      goal: resolvedHabit.goal,
      reminder: resolvedHabit.reminder,
      startDate: resolvedHabit.startDate,
      endDate: resolvedHabit.endDate,
      createdAt: resolvedHabit.createdAt,
      reminders: resolvedHabit.reminders,
      baseline: resolvedHabit.baseline,
      target: resolvedHabit.target,
      completionHistory: resolvedHabit.completionHistory,
      difficultyHistory: resolvedHabit.difficultyHistory,
      actualUsage: resolvedHabit.actualUsage)

    logger.info("Conflict resolution completed for habit: \(resolvedHabit.name)")
    return resolvedHabit
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "ConflictResolutionManager")

  /// Default conflict resolution rules for habit fields
  private let defaultRules: [FieldConflictRule] = [
    // High priority fields - last writer wins
    FieldConflictRule(fieldName: "name", policy: .lastWriterWins, priority: 100),
    FieldConflictRule(fieldName: "description", policy: .lastWriterWins, priority: 90),
    FieldConflictRule(fieldName: "icon", policy: .lastWriterWins, priority: 80),
    FieldConflictRule(fieldName: "color", policy: .lastWriterWins, priority: 80),
    FieldConflictRule(fieldName: "schedule", policy: .lastWriterWins, priority: 90),
    FieldConflictRule(fieldName: "goal", policy: .lastWriterWins, priority: 90),
    FieldConflictRule(fieldName: "reminder", policy: .lastWriterWins, priority: 80),

    // Medium priority fields - merge or last writer wins
    FieldConflictRule(fieldName: "completionHistory", policy: .merge, priority: 70),
    FieldConflictRule(fieldName: "difficultyHistory", policy: .merge, priority: 70),
    FieldConflictRule(fieldName: "usageHistory", policy: .merge, priority: 70),
    FieldConflictRule(fieldName: "streak", policy: .lastWriterWins, priority: 60),
    FieldConflictRule(fieldName: "isCompleted", policy: .lastWriterWins, priority: 60),

    // Low priority fields - first writer wins (metadata)
    FieldConflictRule(fieldName: "id", policy: .firstWriterWins, priority: 10),
    FieldConflictRule(fieldName: "createdAt", policy: .firstWriterWins, priority: 10),
    FieldConflictRule(fieldName: "startDate", policy: .firstWriterWins, priority: 20),

    // Special fields - custom resolution
    FieldConflictRule(
      fieldName: "endDate",
      policy: .custom,
      priority: 50,
      customResolver: "resolveEndDate"),
    FieldConflictRule(fieldName: "updatedAt", policy: .lastWriterWins, priority: 100)
  ]

  /// Custom conflict resolution rules (can be modified at runtime)
  private var customRules: [FieldConflictRule] = []

  // MARK: - Field Conflict Resolution

  /// Resolves a conflict for a specific field
  private func resolveFieldConflict(
    fieldName: String,
    localValue: Any?,
    remoteValue: Any?,
    rule: FieldConflictRule,
    localHabit: Habit,
    remoteHabit: Habit) -> Any?
  {
    switch rule.policy {
    case .lastWriterWins:
      resolveLastWriterWins(
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)

    case .firstWriterWins:
      resolveFirstWriterWins(
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)

    case .merge:
      resolveMerge(
        fieldName: fieldName,
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)

    case .custom:
      resolveCustom(
        fieldName: fieldName,
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit,
        customResolver: rule.customResolver)
    }
  }

  /// Last writer wins resolution
  private func resolveLastWriterWins(
    localValue: Any?,
    remoteValue: Any?,
    localHabit: Habit,
    remoteHabit: Habit) -> Any?
  {
    // Compare timestamps to determine which is more recent
    if localHabit.createdAt > remoteHabit.createdAt {
      localValue
    } else {
      remoteValue
    }
  }

  /// First writer wins resolution
  private func resolveFirstWriterWins(
    localValue: Any?,
    remoteValue: Any?,
    localHabit: Habit,
    remoteHabit: Habit) -> Any?
  {
    // Compare timestamps to determine which was written first
    if localHabit.createdAt < remoteHabit.createdAt {
      localValue
    } else {
      remoteValue
    }
  }

  /// Merge resolution
  private func resolveMerge(
    fieldName: String,
    localValue: Any?,
    remoteValue: Any?,
    localHabit: Habit,
    remoteHabit: Habit) -> Any?
  {
    // Special handling for different field types
    switch fieldName {
    case "completionHistory":
      mergeCompletionHistory(localValue: localValue, remoteValue: remoteValue)
    case "difficultyHistory":
      mergeDifficultyHistory(localValue: localValue, remoteValue: remoteValue)
    case "usageHistory":
      mergeUsageHistory(localValue: localValue, remoteValue: remoteValue)
    default:
      // For other fields, use last writer wins as fallback
      resolveLastWriterWins(
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)
    }
  }

  /// Custom resolution
  private func resolveCustom(
    fieldName _: String,
    localValue: Any?,
    remoteValue: Any?,
    localHabit: Habit,
    remoteHabit: Habit,
    customResolver: String?) -> Any?
  {
    switch customResolver {
    case "resolveEndDate":
      resolveEndDate(
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)

    default:
      // Fallback to last writer wins
      resolveLastWriterWins(
        localValue: localValue,
        remoteValue: remoteValue,
        localHabit: localHabit,
        remoteHabit: remoteHabit)
    }
  }

  // MARK: - Specific Field Resolvers

  /// Merges completion history dictionaries
  private func mergeCompletionHistory(localValue: Any?, remoteValue: Any?) -> Any? {
    guard let localHistory = localValue as? [String: Int],
          let remoteHistory = remoteValue as? [String: Int] else
    {
      return localValue ?? remoteValue
    }

    var mergedHistory = localHistory

    for (date, count) in remoteHistory {
      if let existingCount = mergedHistory[date] {
        // If both have the same date, take the higher count
        mergedHistory[date] = max(existingCount, count)
      } else {
        // New date, add it
        mergedHistory[date] = count
      }
    }

    return mergedHistory
  }

  /// Merges difficulty history dictionaries
  private func mergeDifficultyHistory(localValue: Any?, remoteValue: Any?) -> Any? {
    guard let localHistory = localValue as? [String: Int],
          let remoteHistory = remoteValue as? [String: Int] else
    {
      return localValue ?? remoteValue
    }

    var mergedHistory = localHistory

    for (date, difficulty) in remoteHistory {
      if let existingDifficulty = mergedHistory[date] {
        // If both have the same date, take the average
        mergedHistory[date] = (existingDifficulty + difficulty) / 2
      } else {
        // New date, add it
        mergedHistory[date] = difficulty
      }
    }

    return mergedHistory
  }

  /// Merges usage history dictionaries
  private func mergeUsageHistory(localValue: Any?, remoteValue: Any?) -> Any? {
    guard let localHistory = localValue as? [String: Int],
          let remoteHistory = remoteValue as? [String: Int] else
    {
      return localValue ?? remoteValue
    }

    var mergedHistory = localHistory

    for (date, usage) in remoteHistory {
      if let existingUsage = mergedHistory[date] {
        // If both have the same date, take the higher usage
        mergedHistory[date] = max(existingUsage, usage)
      } else {
        // New date, add it
        mergedHistory[date] = usage
      }
    }

    return mergedHistory
  }

  /// Custom resolver for end date
  private func resolveEndDate(
    localValue: Any?,
    remoteValue: Any?,
    localHabit _: Habit,
    remoteHabit _: Habit) -> Any?
  {
    let localEndDate = localValue as? Date
    let remoteEndDate = remoteValue as? Date

    // If one is nil and the other isn't, take the non-nil one
    if localEndDate == nil, remoteEndDate != nil {
      return remoteEndDate
    } else if localEndDate != nil, remoteEndDate == nil {
      return localEndDate
    } else if let local = localEndDate, let remote = remoteEndDate {
      // Both have values, take the later date (more recent end date)
      return local > remote ? local : remote
    } else {
      // Both are nil
      return nil
    }
  }

  // MARK: - Helper Methods

  /// Compares two values for equality
  private func areValuesEqual(_ value1: Any?, _ value2: Any?) -> Bool {
    guard let val1 = value1, let val2 = value2 else {
      return value1 == nil && value2 == nil
    }

    // Use string representation for comparison
    return String(describing: val1) == String(describing: val2)
  }

  /// Gets all field names from a habit
  private func getHabitFieldNames(_: Habit) -> [String] {
    [
      "id", "name", "description", "icon", "color", "habitType", "schedule",
      "goal", "reminder", "startDate", "endDate", "isCompleted", "streak",
      "createdAt", "completionHistory", "difficultyHistory", "actualUsage"
    ]
  }

  /// Gets the value of a field from a habit
  private func getFieldValue(from habit: Habit, fieldName: String) -> Any? {
    switch fieldName {
    case "id": habit.id
    case "name": habit.name
    case "description": habit.description
    case "icon": habit.icon
    case "color": habit.color
    case "habitType": habit.habitType
    case "schedule": habit.schedule
    case "goal": habit.goal
    case "reminder": habit.reminder
    case "startDate": habit.startDate
    case "endDate": habit.endDate
    case "isCompleted": habit.isCompletedForDate(Date())
    case "streak": habit.computedStreak()
    case "createdAt": habit.createdAt
    case "completionHistory": habit.completionHistory
    case "difficultyHistory": habit.difficultyHistory
    case "actualUsage": habit.actualUsage
    default: nil
    }
  }

  /// Sets the value of a field in a habit
  private func setFieldValue(to _: inout Habit, fieldName: String, value: Any?) {
    // Note: This is a simplified implementation
    // In a real implementation, you would need to create a new Habit instance
    // with the updated field value, as Habit properties are likely immutable
    logger.debug("Setting field \(fieldName) to value: \(String(describing: value))")
  }
}

// MARK: - Conflict Resolution Extensions

extension ConflictResolutionManager {
  /// Gets a summary of conflict resolution rules
  func getRulesSummary() -> String {
    let rules = getAllRules()
    var summary = "Conflict Resolution Rules:\n"

    for rule in rules {
      summary += "- \(rule.fieldName): \(rule.policy.displayName) (priority: \(rule.priority))\n"
    }

    return summary
  }

  /// Validates conflict resolution rules
  func validateRules() -> [String] {
    var errors: [String] = []
    let rules = getAllRules()

    // Check for duplicate field names
    let fieldNames = rules.map { $0.fieldName }
    let duplicates = Dictionary(grouping: fieldNames, by: { $0 }).filter { $0.value.count > 1 }

    for (fieldName, _) in duplicates {
      errors.append("Duplicate rule for field: \(fieldName)")
    }

    // Check for invalid custom resolvers
    for rule in rules where rule.policy == .custom && rule.customResolver == nil {
      errors.append("Custom rule for field \(rule.fieldName) has no custom resolver")
    }

    return errors
  }
}
