import SwiftUI

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

    // Handle migration for new completionTimestamps field
    self.completionTimestamps = try container.decodeIfPresent(
      [String: [Date]].self,
      forKey: .completionTimestamps) ?? [:]
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
    actualUsage: [String: Int] = [:])
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

  // Habit Breaking specific properties
  var baseline = 0 // Current average usage
  var target = 0 // Target reduced amount
  var actualUsage: [String: Int] = [:] // Track actual usage: "yyyy-MM-dd" -> Int

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
    try container.encode(completionTimestamps, forKey: .completionTimestamps)
  }

  // MARK: - Completion History Methods

  mutating func markCompleted(for date: Date, at timestamp: Date = Date()) {
    let dateKey = Self.dateKey(for: date)

    // Keep the old system for backward compatibility and migration
    let currentProgress = completionHistory[dateKey] ?? 0
    completionHistory[dateKey] = currentProgress + 1

    // ✅ FIX: Only mark as completed in boolean system when GOAL is actually met
    if habitType == .breaking {
      // For breaking habits, completed when actual usage is at or below target
      let newProgress = completionHistory[dateKey] ?? 0
      completionStatus[dateKey] = newProgress <= target
      print("🔍 COMPLETION FIX - Breaking Habit '\(name)' marked | Progress: \(newProgress) | Target: \(target) | Completed: \(newProgress <= target)")
    } else {
      // For formation habits, completed when progress meets or exceeds goal
      let newProgress = completionHistory[dateKey] ?? 0
      if let goalAmount = parseGoalAmount(from: goal) {
        let isComplete = newProgress >= goalAmount
        completionStatus[dateKey] = isComplete
        print("🔍 COMPLETION FIX - Formation Habit '\(name)' marked | Progress: \(newProgress) | Goal: \(goalAmount) | Completed: \(isComplete)")
      } else {
        // Fallback: if can't parse goal, use progress > 0
        completionStatus[dateKey] = newProgress > 0
        print("🔍 COMPLETION FIX - Formation Habit '\(name)' marked (fallback) | Progress: \(newProgress) | Completed: \(newProgress > 0)")
      }
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

    // ✅ FIX: Update completion status based on whether GOAL is still met after decrement
    if habitType == .breaking {
      // For breaking habits, completed when actual usage is at or below target
      let newProgress = completionHistory[dateKey] ?? 0
      completionStatus[dateKey] = newProgress <= target
      print("🔍 COMPLETION FIX - Breaking Habit '\(name)' unmarked | Progress: \(newProgress) | Target: \(target) | Completed: \(newProgress <= target)")
    } else {
      // For formation habits, completed when progress meets or exceeds goal
      let newProgress = completionHistory[dateKey] ?? 0
      if let goalAmount = parseGoalAmount(from: goal) {
        let isComplete = newProgress >= goalAmount
        completionStatus[dateKey] = isComplete
        print("🔍 COMPLETION FIX - Formation Habit '\(name)' unmarked | Progress: \(newProgress) | Goal: \(goalAmount) | Completed: \(isComplete)")
      } else {
        // Fallback: if can't parse goal, use progress > 0
        completionStatus[dateKey] = newProgress > 0
        print("🔍 COMPLETION FIX - Formation Habit '\(name)' unmarked (fallback) | Progress: \(newProgress) | Completed: \(newProgress > 0)")
      }
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
    // If it's a vacation day AND vacation is currently active, treat it as neutral
    let vacationManager = VacationManager.shared
    if vacationManager.isActive, vacationManager.isVacationDay(date) {
      // For vacation days during active vacation, we need to determine if the habit would have been
      // completed
      // based on the previous non-vacation day's completion status
      let calendar = Calendar.current
      var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date

      // Look back to find the last non-vacation day
      while vacationManager.isActive, vacationManager.isVacationDay(checkDate) {
        guard let prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
          break
        }
        checkDate = prevDate
      }

      // Return the completion status of the last non-vacation day
      return isCompletedInternal(for: checkDate)
    }

    // For non-vacation days or historical vacation days, use the normal completion logic
    return isCompletedInternal(for: date)
  }

  func getProgress(for date: Date) -> Int {
    let dateKey = Self.dateKey(for: date)

    // For breaking habits, return actual usage instead of completion history
    if habitType == .breaking {
      let usage = actualUsage[dateKey] ?? 0
      print(
        "🔍 PROGRESS DEBUG - Breaking Habit '\(name)' | Date: \(dateKey) | Actual Usage: \(usage) | ActualUsage keys: \(actualUsage.keys.sorted())")
      return usage
    } else {
      // For formation habits, use completion history as before
      let progress = completionHistory[dateKey] ?? 0
      print(
        "🔍 PROGRESS DEBUG - Formation Habit '\(name)' | Date: \(dateKey) | Progress: \(progress) | CompletionHistory keys: \(completionHistory.keys.sorted())")
      return progress
    }
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
  /// Skips vacation days to preserve streaks during vacation periods
  func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let vacationManager = VacationManager.shared
    var calculatedStreak = 0
    var currentDate = today
    var debugInfo: [String] = []

    // ✅ FIX #20: Prevent infinite loop for new habits by checking against start date
    let habitStartDate = calendar.startOfDay(for: startDate)

    // Count consecutive completed days backwards from today
    // Skip vacation days only during active vacation periods
    while (isCompleted(for: currentDate) ||
      (vacationManager.isActive && vacationManager.isVacationDay(currentDate))) &&
      currentDate >= habitStartDate  // ✅ FIX #20: Stop at habit start date
    {
      let dateKey = Self.dateKey(for: currentDate)
      let isCompleted = isCompleted(for: currentDate)
      let isVacation = vacationManager.isActive && vacationManager.isVacationDay(currentDate)

      // Only increment streak for actually completed days (not vacation days)
      if isCompleted {
        calculatedStreak += 1
        debugInfo.append("\(dateKey): completed=true, vacation=\(isVacation)")
      } else {
        debugInfo.append("\(dateKey): completed=false, vacation=\(isVacation)")
      }

      // Move to previous day regardless of vacation status
      currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
    }

    print(
      "🔍 STREAK CALCULATION DEBUG - Habit '\(name)': calculated streak=\(calculatedStreak), details: \(debugInfo.joined(separator: ", "))")

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
    let actualStreak = calculateTrueStreak()
    // ❌ REMOVED: Denormalized field comparison in Phase 4
    // Streak validation now always returns true since we only use computed values
    let isValid = true

    print(
      "🔍 STREAK VALIDATION DEBUG - Habit '\(name)': calculated streak=\(actualStreak), valid=\(isValid) (computed-only)")

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

  // MARK: Private

  /// Internal completion check that doesn't consider vacation days
  private func isCompletedInternal(for date: Date) -> Bool {
    let dateKey = Self.dateKey(for: date)

    // First check the new boolean completion status
    if let completionStatus = completionStatus[dateKey] {
      // ✅ FIX #13: Removed flooding debug log
      return completionStatus
    }

    // Fallback to old system for migration purposes
    if habitType == .breaking {
      // For breaking habits, completion is based on actual usage vs target
      let usage = actualUsage[dateKey] ?? 0
      let target = target

      // ✅ FIX #13: Removed flooding debug log that was showing year 742
      // The date formatter issue will be fixed separately
      
      // ✅ CRITICAL FIX: Breaking habit is complete when usage is tracked (> 0) AND within target
      // If usage is 0, habit is not complete (user hasn't logged any usage yet)
      return usage > 0 && usage <= target
    } else {
      // For formation habits, use completion history as before
      let progress = completionHistory[dateKey] ?? 0

      // Parse the goal to get the target amount
      if let targetAmount = parseGoalAmount(from: goal) {
        // A habit is complete when progress reaches or exceeds the goal amount
        let isCompleted = progress >= targetAmount
        // ✅ FIX #13: Removed flooding debug log
        return isCompleted
      }

      // Fallback: if we can't parse the goal, consider it complete with any progress
      let isCompleted = progress > 0
      print(
        "🔍 COMPLETION DEBUG - Formation Habit '\(name)' | Date: \(dateKey) | Progress: \(progress) | Completed: \(isCompleted) (fallback)")
      return isCompleted
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
}
