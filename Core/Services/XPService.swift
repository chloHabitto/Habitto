import Foundation
import OSLog
import SwiftData

// MARK: - XP_RULES

enum XP_RULES {
  static let dailyCompletionXP = 50
  static let levelBaseXP = 200
  static let maxLevel = 100
}

// MARK: - XPServiceProtocol

/// Centralized service for all XP and level mutations
/// This is the ONLY service allowed to mutate XP/level data
protocol XPServiceProtocol {
  /// Awards daily completion XP if user is eligible
  /// - Parameters:
  ///   - userId: The user ID to award XP to
  ///   - dateKey: The date key for the completion
  /// - Returns: The amount of XP awarded (0 if not eligible)
  func awardDailyCompletionIfEligible(userId: String, dateKey: String) async throws -> Int

  /// Revokes daily completion XP if user becomes ineligible
  /// - Parameters:
  ///   - userId: The user ID to revoke XP from
  ///   - dateKey: The date key for the completion
  /// - Returns: The amount of XP revoked (0 if not eligible)
  func revokeDailyCompletionIfIneligible(userId: String, dateKey: String) async throws -> Int

  /// Gets current user progress
  /// - Parameter userId: The user ID
  /// - Returns: Current user progress
  func getUserProgress(userId: String) async throws -> UserProgress

  /// Gets daily award for specific date
  /// - Parameters:
  ///   - userId: The user ID
  ///   - dateKey: The date key
  /// - Returns: Daily award if exists
  nonisolated func getDailyAward(userId: String, dateKey: String) async throws -> DailyAward?
}

// MARK: - XPService

@MainActor
final class XPService: XPServiceProtocol {
  // MARK: Lifecycle

  private init() {
    // TODO: In Phase 3, this will be user-scoped
    self.modelContext = ModelContext(SwiftDataContainer.shared.modelContainer)
  }

  // MARK: Internal

  static let shared = XPService()

  // MARK: - XP Award Methods

  func awardDailyCompletionIfEligible(userId: String, dateKey: String) async throws -> Int {
    logger.info("XPService: Checking daily completion eligibility for user \(userId) on \(dateKey)")

    // Step 1: Check if already awarded (idempotency)
    if let existingAward = try await getDailyAward(userId: userId, dateKey: dateKey) {
      logger
        .info(
          "XPService: Daily award already exists for user \(userId) on \(dateKey) - XP: \(existingAward.xpGranted)")
      return 0 // Already awarded, no additional XP
    }

    // Step 2: Check if all habits are completed for this date
    let allHabitsCompleted = try await checkAllHabitsCompleted(userId: userId, dateKey: dateKey)

    if allHabitsCompleted {
      let xpAmount = XP_RULES.dailyCompletionXP

      // Step 3: Create DailyAward record
      try await createDailyAward(
        userId: userId,
        dateKey: dateKey,
        xpGranted: xpAmount,
        allHabitsCompleted: true)

      // Step 4: Update UserProgress (xpTotal/level via pure function)
      try await updateUserProgress(userId: userId, xpToAdd: xpAmount)

      logger
        .info(
          "XPService: Awarded \(xpAmount) XP to user \(userId) for daily completion on \(dateKey)")

      // Log XP award event
      ObservabilityLogger.shared.logXPAward(
        userId: userId,
        dateKey: dateKey,
        xpGranted: xpAmount,
        reason: "daily_completion")

      return xpAmount
    } else {
      logger
        .info("XPService: Not all habits completed for user \(userId) on \(dateKey), no XP awarded")
      return 0
    }
  }

  func revokeDailyCompletionIfIneligible(userId: String, dateKey: String) async throws -> Int {
    logger
      .info("XPService: Checking daily completion ineligibility for user \(userId) on \(dateKey)")

    // Check if award exists
    guard let existingAward = try await getDailyAward(userId: userId, dateKey: dateKey) else {
      logger.info("XPService: No daily award exists for user \(userId) on \(dateKey)")
      return 0
    }

    // Check if all habits are still completed for this date
    let allHabitsCompleted = try await checkAllHabitsCompleted(userId: userId, dateKey: dateKey)

    if !allHabitsCompleted {
      let xpAmount = existingAward.xpGranted
      try await deleteDailyAward(userId: userId, dateKey: dateKey)
      try await updateUserProgress(userId: userId, xpToAdd: -xpAmount)

      logger
        .info(
          "XPService: Revoked \(xpAmount) XP from user \(userId) for daily completion on \(dateKey)")

      // Log XP revocation event
      ObservabilityLogger.shared.logXPRevocation(
        userId: userId,
        dateKey: dateKey,
        xpRevoked: xpAmount,
        reason: "daily_incompletion")

      return xpAmount
    } else {
      logger
        .info(
          "XPService: All habits still completed for user \(userId) on \(dateKey), no XP revoked")
      return 0
    }
  }

  // MARK: - Query Methods

  func getUserProgress(userId: String) async throws -> UserProgress {
    let request = FetchDescriptor<UserProgressData>(
      predicate: #Predicate<UserProgressData> { progress in
        progress.userId == userId
      })

    let results = try modelContext.fetch(request)
    if let existing = results.first {
      return existing.toUserProgress()
    } else {
      // Create new user progress if doesn't exist
      let newProgress = UserProgressData(userId: userId)
      modelContext.insert(newProgress)
      try modelContext.save()
      return newProgress.toUserProgress()
    }
  }

  nonisolated func getDailyAward(userId: String, dateKey: String) async throws -> DailyAward? {
    let request = FetchDescriptor<DailyAward>(
      predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey })

    // Create a new ModelContext for this nonisolated operation
    // We need to access the model container in a nonisolated way
    let container = await MainActor.run { SwiftDataContainer.shared.modelContainer }
    let context = ModelContext(container)
    let results = try context.fetch(request)
    return results.first
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "XPService")
  private var modelContext: ModelContext

  // MARK: - Private Helper Methods

  private func checkAllHabitsCompleted(userId: String, dateKey: String) async throws -> Bool {
    // Get all habits for the user
    let habitRequest = FetchDescriptor<HabitData>(
      predicate: #Predicate { $0.userId == userId })
    let habits = try modelContext.fetch(habitRequest)

    if habits.isEmpty {
      return false
    }

    // Check if all habits are completed for the date
    for habit in habits {
      let isCompleted = try await isHabitCompleted(habit: habit, dateKey: dateKey)
      if !isCompleted {
        return false
      }
    }

    return true
  }

  private func isHabitCompleted(habit: HabitData, dateKey: String) async throws -> Bool {
    // Check completion history for the specific date
    let habitId = habit.id
    let request = FetchDescriptor<CompletionRecord>(
      predicate: #Predicate<CompletionRecord> { completion in
        completion.habitId == habitId && completion.dateKey == dateKey && completion
          .isCompleted == true
      })

    let results = try modelContext.fetch(request)
    return !results.isEmpty
  }

  private func createDailyAward(
    userId: String,
    dateKey: String,
    xpGranted: Int,
    allHabitsCompleted: Bool) async throws
  {
    let award = DailyAward(
      userId: userId,
      dateKey: dateKey,
      xpGranted: xpGranted,
      allHabitsCompleted: allHabitsCompleted)
    modelContext.insert(award)
    try modelContext.save()
  }

  private func deleteDailyAward(userId: String, dateKey: String) async throws {
    let request = FetchDescriptor<DailyAward>(
      predicate: #Predicate { $0.userId == userId && $0.dateKey == dateKey })

    let results = try modelContext.fetch(request)
    for award in results {
      modelContext.delete(award)
    }
    try modelContext.save()
  }

  private func updateUserProgress(userId: String, xpToAdd: Int) async throws {
    var progress = try await getUserProgress(userId: userId)
    let oldLevel = progress.currentLevel
    progress.totalXP += xpToAdd
    progress.currentLevel = calculateLevel(xpTotal: progress.totalXP)
    // progress.levelProgress = calculateLevelProgress(xpTotal: progress.totalXP, level:
    // progress.currentLevel)  // Read-only property
    progress.updatedAt = Date()

    // Log level up if it occurred
    if progress.currentLevel > oldLevel {
      ObservabilityLogger.shared.logLevelUp(
        userId: userId,
        oldLevel: oldLevel,
        newLevel: progress.currentLevel,
        totalXP: progress.totalXP)
    }

    try modelContext.save()
  }

  private func calculateLevel(xpTotal: Int) -> Int {
    // Level n needs XP_RULES.levelBaseXP * n XP (arithmetic progression)
    max(1, Int(sqrt(Double(xpTotal) / Double(XP_RULES.levelBaseXP))) + 1)
  }

  private func calculateLevelProgress(xpTotal: Int, level: Int) -> Double {
    let currentLevelXP = XP_RULES.levelBaseXP * (level - 1)
    let nextLevelXP = XP_RULES.levelBaseXP * level
    let xpInCurrentLevel = xpTotal - currentLevelXP
    let xpNeededForNextLevel = nextLevelXP - currentLevelXP
    return Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
  }
}

// MARK: - XPServiceGuard

/// This class ensures only XPService can mutate XP/level data
@MainActor
final class XPServiceGuard {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = XPServiceGuard()

  /// Validates that XP mutations are only happening through XPService
  func validateXPMutation(caller: String, function: String) {
    let featureFlags = FeatureFlagManager.shared.provider

    // Skip validation if strict validation is disabled
    guard featureFlags.isStrictValidationEnabled else {
      logger.debug("XP mutation validation disabled by feature flag")
      return
    }

    let allowedCallers = [
      "XPService",
      "DailyAwardService", // Legacy service being phased out
      "XPServiceGuard",
      "LegacyXPService" // Legacy service for backward compatibility
    ]

    let callerName = String(caller.split(separator: ".").last ?? "")

    if !allowedCallers.contains(callerName) {
      logger.error("🚨 XP MUTATION VIOLATION: \(function) called from \(caller)")
      logger.error("🚨 Only XPService and DailyAwardService are allowed to mutate XP/level data")

      // In debug builds with strict validation, this will crash to catch violations early
      #if DEBUG
      if featureFlags.strictXPMutationValidation {
        fatalError("XP mutation violation: \(function) called from \(caller)")
      }
      #endif
    }
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "XPServiceGuard")
}
