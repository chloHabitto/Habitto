import SwiftUI
import SwiftData

// MARK: - HabitStorageManager

class HabitStorageManager {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = HabitStorageManager()

  func saveHabits(_ habits: [Habit], immediate: Bool = false) {
    // Performance optimization: Debounce saves to avoid excessive writes
    // But allow immediate saves when needed (e.g., new habit creation)
    if immediate {
      performSave(habits)
      return
    }

    let now = Date()
    if now.timeIntervalSince(lastSaveTime) < saveDebounceInterval {
      // Schedule a delayed save
      DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
        self.performSave(habits)
      }
      return
    }

    performSave(habits)
  }

  func loadHabits() -> [Habit] {
    // Performance optimization: Return cached result if available
    if let cached = cachedHabits {
      return cached
    }

    if let data = userDefaults.data(forKey: habitsKey),
       let habits = try? JSONDecoder().decode([Habit].self, from: data)
    {
      cachedHabits = habits
      return habits
    }
    return []
  }

  func clearCache() {
    cachedHabits = nil
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let habitsKey = "SavedHabits"

  // Performance optimization: Cache loaded habits
  private var cachedHabits: [Habit]?
  private var lastSaveTime = Date()
  private let saveDebounceInterval: TimeInterval = 0.5

  private func performSave(_ habits: [Habit]) {
    // Performance optimization: Only save if habits actually changed
    if let cached = cachedHabits, cached == habits {
      return // No change, skip save
    }

    if let encoded = try? JSONEncoder().encode(habits) {
      userDefaults.set(encoded, forKey: habitsKey)
      cachedHabits = habits
      lastSaveTime = Date()
    }
  }
}

// MARK: - FirestoreSyncStatus

/// Tracks the synchronization status of a habit with Firestore
enum FirestoreSyncStatus: String, Codable, Equatable {
  case pending   // Not yet synced to Firestore
  case syncing   // Currently syncing to Firestore
  case synced    // Successfully synced to Firestore
  case failed    // Sync failed, needs retry
  
  var displayName: String {
    switch self {
    case .pending: return "Pending"
    case .syncing: return "Syncing..."
    case .synced: return "Synced"
    case .failed: return "Failed"
    }
  }
  
  var icon: String {
    switch self {
    case .pending: return "clock"
    case .syncing: return "arrow.triangle.2.circlepath"
    case .synced: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.triangle.fill"
    }
  }
}

// MARK: - Habit

struct Habit: Identifiable, Codable, Equatable {
  // MARK: Lifecycle

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(UUID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.description = try container.decode(String.self, forKey: .description)
    self.icon = try container.decode(String.self, forKey: .icon)
    self.color = try container.decode(CodableColor.self, forKey: .color)
    self.habitType = try container.decode(HabitType.self, forKey: .habitType)
    self.schedule = try container.decode(String.self, forKey: .schedule)
    self.goal = try container.decode(String.self, forKey: .goal)
    self.reminder = try container.decode(String.self, forKey: .reminder)
    self.startDate = try container.decode(Date.self, forKey: .startDate)
    self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
    // ❌ REMOVED: Denormalized field decoding in Phase 4
    // isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    // streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
    self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    self.reminders = try container.decodeIfPresent([ReminderItem].self, forKey: .reminders) ?? []
    self.baseline = try container.decodeIfPresent(Int.self, forKey: .baseline) ?? 0
    self.target = try container.decodeIfPresent(Int.self, forKey: .target) ?? 0
    self.completionHistory = try container.decodeIfPresent(
      [String: Int].self,
      forKey: .completionHistory) ?? [:]
    self.completionStatus = try container.decodeIfPresent(
      [String: Bool].self,
      forKey: .completionStatus) ?? [:]
    self.difficultyHistory = try container.decodeIfPresent(
      [String: Int].self,
      forKey: .difficultyHistory) ?? [:]
    self.actualUsage = try container
      .decodeIfPresent([String: Int].self, forKey: .actualUsage) ?? [:]
    self.goalHistory = try container
      .decodeIfPresent([String: String].self, forKey: .goalHistory) ?? [:]

    // Handle migration for new completionTimestamps field
    self.completionTimestamps = try container.decodeIfPresent(
      [String: [Date]].self,
      forKey: .completionTimestamps) ?? [:]
    
    // MARK: - Sync Metadata (Phase 1: Dual-Write)
    // Decode with defaults for backward compatibility
    self.lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    self.syncStatus = try container.decodeIfPresent(FirestoreSyncStatus.self, forKey: .syncStatus) ?? .pending
    
    // MARK: - Skip Feature (Phase 1)
    self.skippedDays = try container.decodeIfPresent([String: HabitSkip].self, forKey: .skippedDays) ?? [:]
    
    ensureGoalHistoryInitialized()
  }

  // MARK: - Designated Initializer

  init(
    id: UUID = UUID(),
    name: String,
    description: String,
    icon: String,
    color: CodableColor,
    habitType: HabitType,
    schedule: String,
    goal: String,
    reminder: String,
    startDate: Date,
    endDate: Date? = nil,
    createdAt: Date = Date(),
    reminders: [ReminderItem] = [],
    baseline: Int = 0,
    target: Int = 0,
    completionHistory: [String: Int] = [:],
    completionStatus: [String: Bool] = [:],
    completionTimestamps: [String: [Date]] = [:],
    difficultyHistory: [String: Int] = [:],
    actualUsage: [String: Int] = [:],
    goalHistory: [String: String] = [:],
    lastSyncedAt: Date? = nil,
    syncStatus: FirestoreSyncStatus = .pending,
    skippedDays: [String: HabitSkip] = [:])
  {
    self.id = id
    self.name = name
    self.description = description
    self.icon = icon
    self.color = color
    self.habitType = habitType
    self.schedule = schedule
    self.goal = goal
    self.reminder = reminder
    self.reminders = reminders
    self.startDate = startDate
    self.endDate = endDate
    // ❌ REMOVED: Denormalized field assignments in Phase 4
    // self.isCompleted = isCompleted  // Use isCompleted(for:) instead
    // self.streak = streak           // Use computedStreak() instead
    self.createdAt = createdAt
    self.baseline = baseline
    self.target = target
    self.completionHistory = completionHistory
    self.completionStatus = completionStatus
    self.completionTimestamps = completionTimestamps
    self.difficultyHistory = difficultyHistory
    self.actualUsage = actualUsage
    self.goalHistory = goalHistory
    // Sync metadata
    self.lastSyncedAt = lastSyncedAt
    self.syncStatus = syncStatus
    // Skip feature
    self.skippedDays = skippedDays
    ensureGoalHistoryInitialized()
  }

  // MARK: - Convenience Initializers

  init(
    name: String,
    description: String,
    icon: String,
    color: Color,
    habitType: HabitType,
    schedule: String,
    goal: String,
    reminder: String,
    startDate: Date,
    endDate: Date? = nil,
    reminders: [ReminderItem] = [],
    baseline: Int = 0,
    target: Int = 0)
  {
    self.init(
      id: UUID(),
      name: name,
      description: description,
      icon: icon,
      color: CodableColor(color),
      habitType: habitType,
      schedule: schedule,
      goal: goal,
      reminder: reminder,
      startDate: startDate,
      endDate: endDate,
      // ❌ REMOVED: Denormalized field parameters in Phase 4
      // isCompleted: isCompleted,  // Use isCompleted(for:) instead
      // streak: streak,           // Use computedStreak() instead
      createdAt: Date(),
      reminders: reminders,
      baseline: baseline,
      target: target)
  }

  init(
    from step1Data: (String, String, String, Color, HabitType),
    schedule: String,
    goal: String,
    reminder: String,
    startDate: Date,
    endDate: Date? = nil,
    reminders: [ReminderItem] = [],
    baseline: Int = 0,
    target: Int = 0)
  {
    self.init(
      id: UUID(),
      name: step1Data.0,
      description: step1Data.1,
      icon: step1Data.2,
      color: CodableColor(step1Data.3),
      habitType: step1Data.4,
      schedule: schedule,
      goal: goal,
      reminder: reminder,
      startDate: startDate,
      endDate: endDate,
      reminders: reminders,
      baseline: baseline,
      target: target)
  }

  // MARK: Internal

  // MARK: - Codable Support for Migration

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case description
    case icon
    case color
    case habitType
    case schedule
    case goal
    case reminder
    case startDate
    case endDate
    case isCompleted
    case streak
    case createdAt
    case reminders
    case baseline
    case target
    case completionHistory
    case completionStatus
    case difficultyHistory
    case actualUsage
    case completionTimestamps
    case goalHistory
    // Sync metadata (Phase 1: Dual-Write)
    case lastSyncedAt
    case syncStatus
    // Skip feature (Phase 1)
    case skippedDays
  }

  let id: UUID
  let name: String
  let description: String
  let icon: String // System icon name
  let color: CodableColor
  let habitType: HabitType
  let schedule: String
  let goal: String
  let reminder: String // Keep for backward compatibility
  let reminders: [ReminderItem] // New field for storing reminder items
  let startDate: Date
  let endDate: Date?
  // ❌ REMOVED: Denormalized fields in Phase 4
  // var isCompleted: Bool = false  // Use isCompleted(for:) instead
  // var streak: Int = 0           // Use computedStreak() instead
  let createdAt: Date
  var completionHistory: [String: Int] =
    [:] // Track daily progress: "yyyy-MM-dd" -> Int (count of completions) - DEPRECATED
  var completionStatus: [String: Bool] =
    [:] // Track daily completion status: "yyyy-MM-dd" -> Bool (completed/incomplete)
  var completionTimestamps: [String: [Date]] =
    [:] // Track completion timestamps: "yyyy-MM-dd" -> [completion_times]
  var difficultyHistory: [String: Int] =
    [:] // Track daily difficulty: "yyyy-MM-dd" -> Int (1-10 scale)
  var goalHistory: [String: String] =
    [:] // Track goal changes per effective date: "yyyy-MM-dd" -> goal string

  // Habit Breaking specific properties
  var baseline = 0 // Current average usage
  var target = 0 // Target reduced amount
  var actualUsage: [String: Int] = [:] // Track actual usage: "yyyy-MM-dd" -> Int
  
  // MARK: - Skip Feature (Phase 1)
  
  /// Track skipped days with reasons: "yyyy-MM-dd" -> HabitSkip
  var skippedDays: [String: HabitSkip] = [:]
  
  // MARK: - Sync Metadata (Phase 1: Dual-Write)
  
  /// Timestamp of last successful sync to Firestore
  /// nil = never synced, Date = last sync time
  var lastSyncedAt: Date?
  
  /// Current synchronization status with Firestore
  /// Default: .pending (needs sync)
  var syncStatus: FirestoreSyncStatus = .pending

  /// Access the actual Color value for UI usage
  var colorValue: Color {
    color.color
  }

  static func dateKey(for date: Date) -> String {
    DateUtils.dateKey(for: date)
  }

  // MARK: - Persistence Methods (Optimized)

  static func saveHabits(_ habits: [Habit], immediate: Bool = false) {
    OptimizedHabitStorageManager.shared.saveHabits(habits, immediate: immediate)
  }

  static func loadHabits() -> [Habit] {
    OptimizedHabitStorageManager.shared.loadHabits()
  }

  static func clearCache() {
    OptimizedHabitStorageManager.shared.clearCache()
  }

  private mutating func ensureGoalHistoryInitialized() {
    // Only seed goalHistory for *new* habits (no completion history yet).
    // For existing habits with historical data, we must not assume the current goal
    // has always been active since startDate.
    if goalHistory.isEmpty, completionHistory.isEmpty {
      goalHistory[Self.dateKey(for: startDate)] = goal
      return
    }

    if !goalHistory.values.contains(goal) {
      goalHistory[Self.dateKey(for: Date())] = goal
    }
  }

  func goalString(for date: Date) -> String {
    // 🔍 DEBUG: Uncomment for debugging goal inference
    // let targetDate = DateUtils.startOfDay(for: date)
    // let dateKey = Self.dateKey(for: targetDate)
    // print("🔍 GOAL_DEBUG: goalString(for: \(dateKey))")
    // print("  - goalHistory.isEmpty: \(goalHistory.isEmpty)")
    // print("  - goalHistory keys: \(goalHistory.keys.sorted())")
    // print("  - goalHistory values: \(goalHistory.values)")
    // print("  - current goal: '\(goal)'")
    // print("  - completionHistory[\(dateKey)]: \(completionHistory[dateKey] ?? -1)")

    let result = goalStringCore(for: date)
    // print("  → RETURNING: '\(result)'")
    return result
  }

  /// Core implementation for goalString(for:), separated so we can wrap it with debug logging
  private func goalStringCore(for date: Date) -> String {
    let targetDate = DateUtils.startOfDay(for: date)
    let currentGoalString = goal
    let currentGoalAmount = StreakDataCalculator.parseGoalAmount(from: currentGoalString)

    // Determine if goalHistory has rich history (multiple entries or different goals),
    // or if it's effectively "simple" (empty or a single entry equal to the current goal).
    let simpleHistory: Bool = {
      if goalHistory.isEmpty { return true }
      if goalHistory.count == 1, let onlyValue = goalHistory.values.first {
        return onlyValue == currentGoalString
      }
      return false
    }()

    // 1) For rich goalHistory, use it as the primary source of truth.
    if !simpleHistory, !goalHistory.isEmpty {
      var latestMatch: (date: Date, goal: String)?

      for (key, value) in goalHistory {
        guard let entryDate = DateUtils.date(from: key) else { continue }
        let normalizedEntryDate = DateUtils.startOfDay(for: entryDate)

        guard normalizedEntryDate <= targetDate else { continue }

        if let existingMatch = latestMatch {
          if normalizedEntryDate > existingMatch.date {
            latestMatch = (normalizedEntryDate, value)
          }
        } else {
          latestMatch = (normalizedEntryDate, value)
        }
      }

      if let match = latestMatch {
        return match.goal
      }
    }

    // 2) If goalHistory is missing or too simple, infer a historical goal from completionHistory.
    //    This handles the case where the goal was increased later (e.g., 1 → 2 on the 15th),
    //    but older days (12–14) only ever reached 1.
    if currentGoalAmount > 1 {
      var earliestHighGoalDate: Date?
      var smallestPositiveProgressBeforeHighGoal: Int?

      for (key, progress) in completionHistory {
        guard let rawDate = DateUtils.date(from: key) else { continue }
        let day = DateUtils.startOfDay(for: rawDate)

        if progress >= currentGoalAmount {
          // This day reached the *new* goal (e.g., 2 times) – candidate for goal-change date
          if earliestHighGoalDate == nil || day < earliestHighGoalDate! {
            earliestHighGoalDate = day
          }
        } else if progress > 0 {
          // Completed but below current goal – candidate for the *old* goal amount
          if smallestPositiveProgressBeforeHighGoal == nil ||
            progress < smallestPositiveProgressBeforeHighGoal!
          {
            smallestPositiveProgressBeforeHighGoal = progress
          }
        }
      }

      if
        let changeDate = earliestHighGoalDate,
        let oldGoalAmount = smallestPositiveProgressBeforeHighGoal
      {
        if targetDate < changeDate {
          // For dates before the inferred change date, use the inferred old goal amount.
          return adjustedGoalString(baseGoal: currentGoalString, amount: oldGoalAmount)
        } else {
          // For dates on/after the inferred change date, use the current goal string.
          return currentGoalString
        }
      }
    }

    // 3) Fallback – use the current goal string.
    return currentGoalString
  }

  /// Returns a copy of `baseGoal` with its leading numeric amount replaced by `amount`.
  /// Example: baseGoal = "2 times on everyday", amount = 1 → "1 time on everyday".
  private func adjustedGoalString(baseGoal: String, amount: Int) -> String {
    guard amount > 0 else { return baseGoal }

    // Replace the first number in the string with the new amount.
    let pattern = #"(\d+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(
            in: baseGoal,
            options: [],
            range: NSRange(location: 0, length: baseGoal.utf16.count))
    else {
      // If there is no number, fall back to the original goal.
      return baseGoal
    }

    let amountString = "\(amount)"
    let nsBase = baseGoal as NSString
    let newString = nsBase.replacingCharacters(in: match.range, with: amountString)

    // Simple singular/plural fix for "time"/"times" when amount is 1
    if amount == 1 {
      return newString.replacingOccurrences(of: "times", with: "time")
    }

    return newString
  }

  func goalAmount(for date: Date) -> Int {
    StreakDataCalculator.parseGoalAmount(from: goalString(for: date))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(icon, forKey: .icon)
    try container.encode(color, forKey: .color)
    try container.encode(habitType, forKey: .habitType)
    try container.encode(schedule, forKey: .schedule)
    try container.encode(goal, forKey: .goal)
    try container.encode(reminder, forKey: .reminder)
    try container.encode(startDate, forKey: .startDate)
    try container.encodeIfPresent(endDate, forKey: .endDate)
    // Note: isCompleted and streak are computed-only fields, not encoded
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(reminders, forKey: .reminders)
    try container.encode(baseline, forKey: .baseline)
    try container.encode(target, forKey: .target)
    try container.encode(completionHistory, forKey: .completionHistory)
    try container.encode(completionStatus, forKey: .completionStatus)
    try container.encode(difficultyHistory, forKey: .difficultyHistory)
    try container.encode(actualUsage, forKey: .actualUsage)
    try container.encode(goalHistory, forKey: .goalHistory)
    try container.encode(completionTimestamps, forKey: .completionTimestamps)
    
    // MARK: - Sync Metadata (Phase 1: Dual-Write)
    try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
    try container.encode(syncStatus, forKey: .syncStatus)
    
    // MARK: - Skip Feature (Phase 1)
    try container.encode(skippedDays, forKey: .skippedDays)
  }

  // MARK: - Completion History Methods

  mutating func markCompleted(for date: Date, at timestamp: Date = Date()) {
    let dateKey = Self.dateKey(for: date)

    // Keep the old system for backward compatibility and migration
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = currentProgress + 1

    // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
    // Set completionStatus[dateKey] = true when progress >= goal
    let newProgress = completionHistory[dateKey] ?? 0
    if let goalAmount = parseGoalAmount(from: goalString(for: date)) {
      let isComplete = newProgress >= goalAmount
      completionStatus[dateKey] = isComplete
      print("🔍 COMPLETION FIX - \(habitType == .breaking ? "Breaking" : "Formation") Habit '\(name)' marked | Progress: \(newProgress) | Goal: \(goalAmount) | Completed: \(isComplete)")
    } else {
      // Fallback: if can't parse goal, use progress > 0
      completionStatus[dateKey] = newProgress > 0
      print("🔍 COMPLETION FIX - Habit '\(name)' marked (fallback) | Progress: \(newProgress) | Completed: \(newProgress > 0)")
    }

    // Store the actual completion timestamp
    if completionTimestamps[dateKey] == nil {
      completionTimestamps[dateKey] = []
    }
    completionTimestamps[dateKey]?.append(timestamp)

    // ❌ REMOVED: Denormalized field updates in Phase 4
    // updateCurrentCompletionStatus() and updateStreakWithReset() have been removed
    // Use isCompleted(for:) and calculateTrueStreak() for read-only access

    // Debug: Print completion tracking
    print(
      "🔍 COMPLETION DEBUG - Habit '\(name)' marked completed for \(dateKey) at \(timestamp) | Old: \(currentProgress) | New: \(completionHistory[dateKey] ?? 0)")
  }

  // MARK: - Difficulty History Methods

  mutating func recordDifficulty(_ difficulty: Int, for date: Date) {
    let dateKey = Self.dateKey(for: date)
    difficultyHistory[dateKey] = difficulty

    // Debug: Print difficulty tracking
    print("🔍 DIFFICULTY DEBUG - Habit '\(name)' difficulty \(difficulty) recorded for \(dateKey)")
  }

  func getDifficulty(for date: Date) -> Int? {
    let dateKey = Self.dateKey(for: date)
    return difficultyHistory[dateKey]
  }

  mutating func markIncomplete(for date: Date) {
    let dateKey = Self.dateKey(for: date)

    // Keep the old system for backward compatibility and migration
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = max(0, currentProgress - 1)

    // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use IDENTICAL completion logic
    // Update completionStatus[dateKey] based on whether progress >= goal after decrement
    let newProgress = completionHistory[dateKey] ?? 0
    if let goalAmount = parseGoalAmount(from: goalString(for: date)) {
      let isComplete = newProgress >= goalAmount
      completionStatus[dateKey] = isComplete
      print("🔍 COMPLETION FIX - \(habitType == .breaking ? "Breaking" : "Formation") Habit '\(name)' unmarked | Progress: \(newProgress) | Goal: \(goalAmount) | Completed: \(isComplete)")
    } else {
      // Fallback: if can't parse goal, use progress > 0
      completionStatus[dateKey] = newProgress > 0
      print("🔍 COMPLETION FIX - Habit '\(name)' unmarked (fallback) | Progress: \(newProgress) | Completed: \(newProgress > 0)")
    }

    // Remove the most recent timestamp if there are any
    if completionTimestamps[dateKey]?.isEmpty == false {
      completionTimestamps[dateKey]?.removeLast()
    }

    // ❌ REMOVED: Denormalized field updates in Phase 4
    // updateCurrentCompletionStatus() and updateStreakWithReset() have been removed
    // Use isCompleted(for:) and calculateTrueStreak() for read-only access
  }

  func isCompleted(for date: Date) -> Bool {
    isCompletedInternal(for: effectiveCompletionCheckDate(for: date))
  }

  /// Async completion check that hops to the main actor for historical SwiftData lookups.
  /// Prefer this (or the prefetched-map overload) from background/`Task.detached` work.
  func isCompletedAsync(for date: Date) async -> Bool {
    await isCompletedInternalAsync(for: effectiveCompletionCheckDate(for: date))
  }

  /// Sync completion check using a prefetched `[dateKey: progress]` map (no SwiftData hop).
  /// Applies the same vacation-day remapping as `isCompleted(for:)`.
  func isCompleted(for date: Date, progressByDateKey: [String: Int]) -> Bool {
    isCompletedInternal(for: effectiveCompletionCheckDate(for: date), progressByDateKey: progressByDateKey)
  }

  /// Single source of truth for "does this progress meet the goal?"
  static func isProgressComplete(progress: Int, goalAmount: Int) -> Bool {
    goalAmount > 0 ? (progress >= goalAmount) : (progress > 0)
  }

  /// Prefetch CompletionRecord progress for many habits/dates in one MainActor hop.
  /// Returns `[habitId: [dateKey: progress]]`.
  @MainActor
  static func prefetchCompletionProgress(
    habitIds: [UUID],
    from: Date,
    to: Date) throws -> [UUID: [String: Int]]
  {
    guard !habitIds.isEmpty else { return [:] }

    let fromKey = dateKey(for: from)
    let toKey = dateKey(for: to)
    let ids = habitIds
    let context = SwiftDataContainer.shared.modelContext

    let predicate = #Predicate<CompletionRecord> { record in
      ids.contains(record.habitId) && record.dateKey >= fromKey && record.dateKey <= toKey
    }
    let records = try context.fetch(FetchDescriptor<CompletionRecord>(predicate: predicate))

    var result: [UUID: [String: Int]] = [:]
    for record in records {
      var byDate = result[record.habitId] ?? [:]
      let existing = byDate[record.dateKey] ?? 0
      byDate[record.dateKey] = max(existing, record.progress)
      result[record.habitId] = byDate
    }
    return result
  }

  // MARK: - Streak Mode Completion Check

  /// Checks if this habit meets the completion criteria for STREAK and XP purposes.
  /// This respects the user's Streak Mode setting.
  ///
  /// - Important: This is DIFFERENT from `isCompleted(for:)` which is for UI display.
  ///   - `isCompleted(for:)` → UI checkmarks, calendars, progress charts (always uses full completion)
  ///   - `meetsStreakCriteria(for:)` → Streak calculation, XP awards (respects Streak Mode)
  ///
  /// - Parameter date: The date to check
  /// - Returns: true if the habit meets streak criteria based on current CompletionMode
  func meetsStreakCriteria(for date: Date) -> Bool {
    let mode = CompletionMode.current
    return meetsStreakCriteria(for: date, mode: mode)
  }

  /// Checks if this habit meets the completion criteria for the given mode.
  /// - Parameters:
  ///   - date: The date to check
  ///   - mode: The completion mode to evaluate against
  /// - Returns: true if the habit meets the criteria for the given mode
  func meetsStreakCriteria(for date: Date, mode: CompletionMode) -> Bool {
    let progress = getProgress(for: date)
    
    switch mode {
    case .full:
      // Strict mode: progress must meet or exceed goal (current behavior)
      let goalAmount = goalAmount(for: date)
      if goalAmount > 0 {
        return progress >= goalAmount
      } else {
        return progress > 0
      }
      
    case .partial:
      // Lenient mode: any progress counts
      return progress > 0
    }
  }

  func getProgress(for date: Date) -> Int {
    let dateKey = Self.dateKey(for: date)

    // ✅ UNIVERSAL RULE: Both Formation and Breaking habits use completionHistory
    // actualUsage, baseline, current, and target are DISPLAY-ONLY fields
    let progress = completionHistory[dateKey] ?? 0
    return progress
  }

  // MARK: - Habit Breaking Methods

  mutating func logActualUsage(_ amount: Int, for date: Date) {
    let dateKey = Self.dateKey(for: date)
    actualUsage[dateKey] = amount
  }

  func getActualUsage(for date: Date) -> Int {
    let dateKey = Self.dateKey(for: date)
    return actualUsage[dateKey] ?? 0
  }

  func calculateSuccessRate(for date: Date) -> Double {
    let actual = getActualUsage(for: date)

    if target == 0 {
      // Complete elimination
      return baseline > 0 ? Double(baseline - actual) / Double(baseline) * 100.0 : 0.0
    } else {
      // Partial reduction
      let reductionRange = baseline - target
      return reductionRange > 0 ? Double(baseline - actual) / Double(reductionRange) * 100.0 : 0.0
    }
  }

  func getProgressForHabitBreaking(for date: Date) -> Int {
    let successRate = calculateSuccessRate(for: date)
    return Int(successRate)
  }

  // MARK: - Improved Streak Tracking Methods

  /// Calculates the true consecutive day streak by checking actual completion history
  /// Skips vacation days and skipped days to preserve streaks during vacation periods or legitimate skip reasons
  /// ✅ FIX: Includes TODAY if completed, then counts backwards
  func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let vacationManager = VacationManager.shared
    var calculatedStreak = 0
    
    // ✅ CRITICAL FIX: Start from TODAY if completed, otherwise start from YESTERDAY
    // If today is completed, include it in the streak
    var currentDate = today
    var debugInfo: [String] = []

    // ✅ FIX #20: Prevent infinite loop for new habits by checking against start date
    let habitStartDate = calendar.startOfDay(for: startDate)
    
    // ✅ CRITICAL FIX: Check if today is completed first
    let todayCompleted = isCompleted(for: today)
    let todaySkipped = isSkipped(for: today)
    if todayCompleted {
      calculatedStreak += 1
      debugInfo.append("\(Self.dateKey(for: today)): completed=true (TODAY)")
      // Start counting backwards from yesterday
      currentDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    } else if todaySkipped {
      // Today is skipped - don't increment streak but continue counting backwards
      debugInfo.append("\(Self.dateKey(for: today)): skipped=true (TODAY, streak protected)")
      currentDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    } else {
      // Today not completed and not skipped, start from yesterday
      currentDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    // Count consecutive completed days backwards from currentDate
    // Skip vacation days and skipped days to preserve streaks
    while (isCompleted(for: currentDate) ||
      (vacationManager.isActive && vacationManager.isVacationDay(currentDate)) ||
      isSkipped(for: currentDate)) &&
      currentDate >= habitStartDate  // ✅ FIX #20: Stop at habit start date
    {
      let dateKey = Self.dateKey(for: currentDate)
      let isCompleted = isCompleted(for: currentDate)
      let isVacation = vacationManager.isActive && vacationManager.isVacationDay(currentDate)
      let isSkipped = isSkipped(for: currentDate)

      // Only increment streak for actually completed days (not vacation or skipped days)
      if isCompleted {
        calculatedStreak += 1
        debugInfo.append("\(dateKey): completed=true, vacation=\(isVacation), skipped=\(isSkipped)")
      } else if isSkipped {
        // Skipped day - preserve streak but don't increment
        debugInfo.append("\(dateKey): completed=false, skipped=true (streak protected)")
      } else {
        // Vacation day - preserve streak but don't increment
        debugInfo.append("\(dateKey): completed=false, vacation=\(isVacation)")
      }

      // Move to previous day regardless of vacation or skip status
      currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
    }

    return calculatedStreak
  }

  /// ❌ REMOVED: updateStreakWithReset method
  /// This method has been removed in Phase 4. Use calculateTrueStreak() for read-only access.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use calculateTrueStreak() for read-only access.")
  mutating func updateStreakWithReset() {
    fatalError(
      "updateStreakWithReset has been removed. Use calculateTrueStreak() for read-only access.")
  }

  /// Validates if the current streak matches actual consecutive completions
  func validateStreak() -> Bool {
    _ = calculateTrueStreak()
    // ❌ REMOVED: Denormalized field comparison in Phase 4
    // Streak validation now always returns true since we only use computed values
    let isValid = true

    return isValid
  }

  /// ❌ REMOVED: correctStreak method
  /// This method has been removed in Phase 4. Use calculateTrueStreak() for read-only access.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use calculateTrueStreak() for read-only access.")
  mutating func correctStreak() {
    fatalError("correctStreak has been removed. Use calculateTrueStreak() for read-only access.")
  }

  /// ❌ REMOVED: recalculateCompletionStatus method
  /// This method has been removed in Phase 4. Use isCompleted(for:) for read-only access.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use isCompleted(for:) for read-only access.")
  mutating func recalculateCompletionStatus() {
    fatalError(
      "recalculateCompletionStatus has been removed. Use isCompleted(for:) for read-only access.")
  }

  /// Debug function to print streak information
  func debugStreakInfo() {
    let trueStreak = calculateTrueStreak()
    let isValid = validateStreak()
    print("🔍 Habit '\(name)': computed streak=\(trueStreak), valid=\(isValid) (computed-only)")
  }

  // MARK: - Migration Methods

  /// Migrates completion history from count-based to boolean-based system
  mutating func migrateCompletionHistory() {
    print("🔄 MIGRATION: Migrating completion history for habit '\(name)'")

    // Convert completion counts to boolean status
    for (dateKey, count) in completionHistory {
      if count > 0 {
        completionStatus[dateKey] = true
        print("🔄 MIGRATION: \(dateKey) -> completed (was \(count))")
      } else {
        completionStatus[dateKey] = false
        print("🔄 MIGRATION: \(dateKey) -> incomplete (was \(count))")
      }
    }

    print(
      "🔄 MIGRATION: Completed migration for habit '\(name)' - \(completionStatus.count) days migrated")
  }
  
  // MARK: - Skip Feature Methods (Phase 1: Data Models Only)
  
  /// Check if a habit was skipped on a specific date
  /// - Parameter date: The date to check
  /// - Returns: true if the habit was skipped on this date
  func isSkipped(for date: Date) -> Bool {
    let dateKey = Self.dateKey(for: date)
    return skippedDays[dateKey] != nil
  }
  
  /// Get the skip reason for a specific date
  /// - Parameter date: The date to check
  /// - Returns: The skip reason if the habit was skipped, nil otherwise
  func skipReason(for date: Date) -> SkipReason? {
    let dateKey = Self.dateKey(for: date)
    return skippedDays[dateKey]?.reason
  }
  
  /// Get the skip reason for a specific date
  /// - Parameter date: The date to check
  /// - Returns: The SkipReason if the habit is skipped on that date, nil otherwise
  func getSkipReason(for date: Date) -> SkipReason? {
    let dateKey = Self.dateKey(for: date)
    return skippedDays[dateKey]?.reason
  }
  
  /// Mark a habit as skipped for a specific date
  /// - Parameters:
  ///   - date: The date to skip
  ///   - reason: The reason for skipping
  ///   - note: Optional custom note for additional context
  mutating func skip(for date: Date, reason: SkipReason, note: String? = nil) {
    let dateKey = Self.dateKey(for: date)
    print("⏭️ [HABIT.SKIP] Adding skip for '\(name)' on \(dateKey)")
    print("⏭️ [HABIT.SKIP] Reason: \(reason.rawValue)")
    
    let habitSkip = HabitSkip(
      habitId: id,
      dateKey: dateKey,
      reason: reason,
      customNote: note,
      createdAt: Date()
    )
    
    skippedDays[dateKey] = habitSkip
    print("⏭️ [HABIT.SKIP] Skip added. Total skipped days: \(skippedDays.count)")
    print("⏭️ [HABIT.SKIP] All skipped days: \(Array(skippedDays.keys).sorted())")
    
    print("✅ SKIP: Habit '\(name)' skipped on \(dateKey) - Reason: \(reason.rawValue)")
  }
  
  /// Remove a skip entry for a specific date
  /// - Parameter date: The date to unskip
  mutating func unskip(for date: Date) {
    let dateKey = Self.dateKey(for: date)
    if skippedDays.removeValue(forKey: dateKey) != nil {
      print("✅ UNSKIP: Habit '\(name)' unskipped on \(dateKey)")
    }
  }

  // MARK: Private

  /// Remap an active vacation day to the last non-vacation day (same rules as public isCompleted).
  private func effectiveCompletionCheckDate(for date: Date) -> Date {
    let vacationManager = VacationManager.shared
    guard vacationManager.isActive, vacationManager.isVacationDay(date) else {
      return date
    }

    let calendar = Calendar.current
    var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date

    while vacationManager.isActive, vacationManager.isVacationDay(checkDate) {
      guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
        break
      }
      checkDate = prevDate
    }
    return checkDate
  }

  /// Evaluate completion for a date using progress + historical goal (shared comparison).
  private func evaluateCompletion(progress: Int, for date: Date, storedStatus: Bool? = nil) -> Bool {
    let goalAmount = parseGoalAmount(from: goalString(for: date)) ?? 0
    let calculatedCompleted = Self.isProgressComplete(progress: progress, goalAmount: goalAmount)

    if let storedStatus {
      // If stored status matches the calculated one, trust it; otherwise trust calculated.
      return storedStatus == calculatedCompleted ? storedStatus : calculatedCompleted
    }
    return calculatedCompleted
  }

  /// Internal completion check that doesn't consider vacation days (sync; SwiftData only on main).
  private func isCompletedInternal(for date: Date) -> Bool {
    let dateKey = Self.dateKey(for: date)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let normalizedDate = calendar.startOfDay(for: date)
    let isHistoricalDate = normalizedDate < today

    if isHistoricalDate {
      if let progress = queryCompletionRecordFromSwiftData(for: date) {
        return evaluateCompletion(progress: progress, for: date)
      }
      let progress = completionHistory[dateKey] ?? 0
      return evaluateCompletion(progress: progress, for: date)
    }

    let progress = completionHistory[dateKey] ?? 0
    return evaluateCompletion(
      progress: progress,
      for: date,
      storedStatus: completionStatus[dateKey])
  }

  /// Async internal completion check — hops to MainActor for historical SwiftData queries.
  private func isCompletedInternalAsync(for date: Date) async -> Bool {
    let dateKey = Self.dateKey(for: date)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let normalizedDate = calendar.startOfDay(for: date)
    let isHistoricalDate = normalizedDate < today

    if isHistoricalDate {
      let progress = await MainActor.run { () -> Int? in
        queryCompletionRecordFromSwiftDataOnMainActor(for: date)
      }
      if let progress {
        return evaluateCompletion(progress: progress, for: date)
      }
      let fallback = completionHistory[dateKey] ?? 0
      return evaluateCompletion(progress: fallback, for: date)
    }

    let progress = completionHistory[dateKey] ?? 0
    return evaluateCompletion(
      progress: progress,
      for: date,
      storedStatus: completionStatus[dateKey])
  }

  /// Internal completion check using a prefetched progress map (no SwiftData access).
  private func isCompletedInternal(for date: Date, progressByDateKey: [String: Int]) -> Bool {
    let dateKey = Self.dateKey(for: date)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let normalizedDate = calendar.startOfDay(for: date)
    let isHistoricalDate = normalizedDate < today

    if isHistoricalDate {
      let progress = progressByDateKey[dateKey] ?? completionHistory[dateKey] ?? 0
      return evaluateCompletion(progress: progress, for: date)
    }

    // Today: in-memory dict is authoritative when present
    let progress = completionHistory[dateKey] ?? progressByDateKey[dateKey] ?? 0
    return evaluateCompletion(
      progress: progress,
      for: date,
      storedStatus: completionStatus[dateKey])
  }

  /// Query CompletionRecord progress from SwiftData for a specific date.
  /// Sync path: returns nil when off the main thread (callers should use async or prefetch).
  private func queryCompletionRecordFromSwiftData(for date: Date) -> Int? {
    guard Thread.isMainThread else {
      return nil
    }
    return MainActor.assumeIsolated {
      queryCompletionRecordFromSwiftDataOnMainActor(for: date)
    }
  }

  /// SwiftData fetch — must run on the main actor.
  @MainActor
  private func queryCompletionRecordFromSwiftDataOnMainActor(for date: Date) -> Int? {
    let dateKey = Self.dateKey(for: date)
    let habitId = self.id

    do {
      let context = SwiftDataContainer.shared.modelContext
      let predicate = #Predicate<CompletionRecord> { record in
        record.habitId == habitId && record.dateKey == dateKey
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      let records = try context.fetch(descriptor)
      // Prefer highest progress if duplicates exist
      return records.map(\.progress).max()
    } catch {
      print(
        "⚠️ queryCompletionRecordFromSwiftData: Failed to query for \(dateKey): \(error.localizedDescription)"
      )
      return nil
    }
  }

  /// Helper method to parse goal amount from goal string
  private func parseGoalAmount(from goalString: String) -> Int? {
    // Extract the number from goal strings like "6 times per day", "3 times", etc.
    let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
    for component in components {
      if let amount = Int(component), amount > 0 {
        return amount
      }
    }
    return nil
  }

  /// ❌ REMOVED: updateCurrentCompletionStatus method
  /// This method has been removed in Phase 4. Use isCompleted(for:) for read-only access.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use isCompleted(for:) for read-only access.")
  private mutating func updateCurrentCompletionStatus() {
    fatalError(
      "updateCurrentCompletionStatus has been removed. Use isCompleted(for:) for read-only access.")
  }
}

// MARK: - HabitType

enum HabitType: String, CaseIterable, Codable {
  case formation = "Habit Building"
  case breaking = "Habit Breaking"
  
  // MARK: Internal
  
  @MainActor
  var localizedName: String {
    switch self {
    case .formation:
      return "habits.type.formation".localized
    case .breaking:
      return "habits.type.breaking".localized
    }
  }
}
