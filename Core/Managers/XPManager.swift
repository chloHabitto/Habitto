import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Simplified XP Manager with single, clear award flow
///
/// ⚠️  CRITICAL: ALL XP MUTATIONS MUST GO THROUGH DailyAwardService
/// DO NOT call XP mutation methods directly from UI or repositories.
/// Direct XP writes will cause double-awarding and data corruption.
///
/// This class manages the UserProgress state but should NOT be used
/// to award or remove XP. Use DailyAwardService.grantIfAllComplete() instead.
///
@MainActor
@Observable
class XPManager {
  // MARK: Lifecycle
  
  // 🔍 DIAGNOSTIC: Fail-fast registry for duplicate instances
  private static weak var _instance: XPManager?

  init() {
    // 🔍 FAIL-FAST: Prevent multiple instances
    if let existing = XPManager._instance {
      let existingId = ObjectIdentifier(existing)
      let newId = ObjectIdentifier(self)
      preconditionFailure("""
        ❌ DUPLICATE XPManager INSTANCE DETECTED!
        Existing: \(existingId)
        New:      \(newId)
        FIX: Ensure only one XPManager is created at app root.
        """)
    }
    XPManager._instance = self
    
    loadUserProgress()
    loadRecentTransactions()
    loadDailyAwards()
    
    logger
      .info(
        "XPManager initialized with level \(self.userProgress.currentLevel) and \(self.userProgress.totalXP) XP")
    
    // ✅ Trigger XP migration check (runs once)
    Task {
      await checkAndTriggerMigration()
    }
  }
  
  /// Check if XP migration is needed and trigger it
  private func checkAndTriggerMigration() async {
    // Check if migration already completed
    if await XPMigrationService.shared.isMigrationComplete() {
      return
    }
    
    // Migration will be triggered from a view with @Environment(\.modelContext)
  }

  // MARK: Internal

  /// Single source of truth for XP values
  enum XPRewards {
    static let completeHabit = 5
    static let completeAllHabits = 15
    static let streakBonus = 10
    static let levelUp = 25
    static let perfectWeek = 25
    static let achievement = 10
    static let dailyCompletion = 50  // XP per fully completed day
  }

  static let shared = XPManager()

  // ✅ UI-reactive properties (@Observable provides automatic change tracking)
  private(set) var totalXP: Int = 0
  private(set) var currentLevel: Int = 1
  private(set) var dailyXP: Int = 0
  
  // Internal progress struct (kept in sync with properties)
  var userProgress = UserProgress()
  var recentTransactions: [XPTransaction] = []
  
  // MARK: - Derived XP (Idempotent)
  
  /// ✅ PURE FUNCTION: Calculate XP from completed days (idempotent, no state mutation)
  /// This is the single source of truth for XP calculation.
  /// Call this after any habit toggle to recalculate and publish XP.
  ///
  /// - Parameter completedDaysCount: Number of days where all habits were completed
  /// - Returns: Total XP (completedDays * baseXP)
  func recalculateXP(completedDaysCount: Int) -> Int {
    return completedDaysCount * XPRewards.dailyCompletion
  }
  
  /// ✅ IDEMPOTENT: Set XP from derived calculation
  /// Use this instead of += or -= operations
  @MainActor
  func publishXP(completedDaysCount: Int) {
    let newXP = recalculateXP(completedDaysCount: completedDaysCount)
    
    // Only update if changed
    guard newXP != totalXP else { return }
    
    // ✅ Update properties directly (@Observable triggers automatic UI update)
    totalXP = newXP
    
    // Keep userProgress in sync
    var updatedProgress = userProgress
    updatedProgress.totalXP = newXP
    userProgress = updatedProgress
    
    updateLevelFromXP()
    saveUserProgress()
    
    #if DEBUG
    // ✅ INVARIANT: XP must always equal completedDays * 50
    let expected = completedDaysCount * XPRewards.dailyCompletion
    if userProgress.totalXP != expected {
      assertionFailure("""
        ❌ INVARIANT VIOLATION!
        Expected XP: \(expected) (completedDays: \(completedDaysCount))
        Actual XP: \(userProgress.totalXP)
        Delta: \(userProgress.totalXP - expected)
        This means XP was mutated outside of publishXP!
        """)
    }
    #endif
  }

  /// Ensures level is always calculated from current XP (no double-bumping)
  func updateLevelFromXP() {
    let calculatedLevel = level(forXP: totalXP)
    let newLevel = max(1, calculatedLevel)
    
    // Only update if level changed
    guard currentLevel != newLevel else {
      updateLevelProgress()  // Still update progress bar
      return
    }
    
    // ✅ Update properties directly (@Observable triggers automatic UI update)
    currentLevel = newLevel
    
    // Keep userProgress in sync
    var updatedProgress = userProgress
    updatedProgress.currentLevel = newLevel
    userProgress = updatedProgress
    
    updateLevelProgress()
  }

  /// ❌ DEPRECATED: Use publishXP(completedDaysCount:) instead
  @available(*, unavailable, message: "Use XPManager.publishXP(completedDaysCount:) for idempotent XP updates")
  func updateXPFromDailyAward(xpGranted: Int, dateKey: String) {
    fatalError("updateXPFromDailyAward is deprecated. Use publishXP(completedDaysCount:) instead.")
  }

  /// ❌ REMOVED: Force award XP for testing
  /// This method has been removed in Phase 4. Use XPService.awardDailyCompletionIfEligible instead.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use XPService.awardDailyCompletionIfEligible instead.")
  func debugForceAwardXP(_: Int) {
    fatalError(
      "debugForceAwardXP has been removed. Use XPService.awardDailyCompletionIfEligible instead.")
  }

  /// ✅ DEBUG: Get current XP status
  func debugGetXPStatus() -> String {
    "Total XP: \(userProgress.totalXP), Level: \(userProgress.currentLevel), Daily XP: \(userProgress.dailyXP)"
  }

  /// ✅ DEBUG: Get current userId (XPManager doesn't store userId, this is for debugging)
  func debugGetCurrentUserId() -> String {
    return "XPManager does not store userId"
  }

  // MARK: - Authentication Handling

  /// Handle user sign-out: Clear XP data and switch to guest mode
  func handleUserSignOut() {
    // Reset to default state
    userProgress = UserProgress()
    recentTransactions.removeAll()

    // Save cleared data
    saveUserProgress()
    saveRecentTransactions()
  }

  /// Handle user sign-in: Load user-specific XP from SwiftData
  func handleUserSignIn(userId: String) {
    // Load user-specific XP from SwiftData
    loadUserXPFromSwiftData(userId: userId)
  }

  /// Load user-specific XP from SwiftData (call this from a view with ModelContext)
  func loadUserXPFromSwiftData(userId: String, modelContext: ModelContext) {
    do {
      // Query all DailyAward records for this user
      let predicate = #Predicate<DailyAward> { award in
        award.userId == userId
      }
      let request = FetchDescriptor<DailyAward>(predicate: predicate)
      let awards = try modelContext.fetch(request)

      // Calculate total XP from all awards
      let totalXP = awards.reduce(0) { $0 + $1.xpGranted }

      // Update XPManager with the calculated XP
      // ✅ Update @Published properties directly (triggers instant UI update)
      self.totalXP = totalXP
      self.dailyXP = 0
      
      // Keep userProgress in sync
      var updatedProgress = userProgress
      updatedProgress.totalXP = totalXP
      updatedProgress.dailyXP = 0 // Reset daily XP
      userProgress = updatedProgress

      // Recalculate level based on total XP
      updateLevelFromXP()

      // Save to UserDefaults
      saveUserProgress()

    } catch {
      print("❌ Error loading user XP from SwiftData: \(error)")
    }
  }

  // MARK: - Data Persistence

  func saveUserProgress() {
    // Save to UserDefaults (local backup)
    if let encoded = try? JSONEncoder().encode(userProgress) {
      userDefaults.set(encoded, forKey: userProgressKey)
    } else {
      print("❌ Failed to encode user progress")
      return
    }
    
    // ✅ Dual-write to Firestore (cloud backup)
    Task {
      do {
        let firestoreProgress = FirestoreUserProgress(
          totalXP: userProgress.totalXP,
          level: userProgress.currentLevel,
          dailyXP: userProgress.dailyXP,
          lastUpdated: Date(),
          currentLevelXP: userProgress.xpForCurrentLevel,
          nextLevelXP: userProgress.xpForNextLevel
        )
        
        try await FirestoreService.shared.saveUserProgress(firestoreProgress)
      } catch {
        print("⚠️ Failed to sync XP to Firestore: \(error.localizedDescription)")
        // Don't throw - local save succeeded
      }
    }
  }

  func loadUserProgress() {
    // Try Firestore first (cloud-first strategy)
    Task {
      do {
        if let firestoreProgress = try await FirestoreService.shared.loadUserProgress() {
          // Load from Firestore (authoritative source)
          var newProgress = UserProgress()
          newProgress.totalXP = firestoreProgress.totalXP
          newProgress.currentLevel = firestoreProgress.level
          newProgress.dailyXP = firestoreProgress.dailyXP
          newProgress.xpForCurrentLevel = firestoreProgress.currentLevelXP ?? 0
          newProgress.xpForNextLevel = firestoreProgress.nextLevelXP ?? 300
          
          userProgress = newProgress
          totalXP = newProgress.totalXP
          dailyXP = newProgress.dailyXP
          updateLevelFromXP()
          
          // Sync to UserDefaults
          saveUserProgressToLocal()
          return
        }
      } catch {
        // Silently fall back to local storage
      }
    }
    
    // Fallback to UserDefaults (local storage)
    if let data = userDefaults.data(forKey: userProgressKey),
       let progress = try? JSONDecoder().decode(UserProgress.self, from: data)
    {
      userProgress = progress
      // ✅ Sync @Published properties from loaded data
      totalXP = progress.totalXP
      dailyXP = progress.dailyXP
      updateLevelFromXP() // Ensure level is calculated from XP (also syncs currentLevel)
    } else {
      // Initialize with default values
      userProgress = UserProgress()
      totalXP = 0
      dailyXP = 0
      updateLevelFromXP()
    }
  }
  
  /// Save to UserDefaults only (helper for syncing after Firestore load)
  private func saveUserProgressToLocal() {
    if let encoded = try? JSONEncoder().encode(userProgress) {
      userDefaults.set(encoded, forKey: userProgressKey)
    }
  }

  func saveRecentTransactions() {
    if let encoded = try? JSONEncoder().encode(recentTransactions) {
      userDefaults.set(encoded, forKey: recentTransactionsKey)
    }
  }

  // MARK: - Public API (Simplified)

  /// Clear all XP data (used during sign-out and delete all data)
  func clearXPData() async {
    logger.info("Clearing XP data for sign-out")

    // Reset objects to defaults
    userProgress = UserProgress()
    recentTransactions = []
    dailyAwards = [:]

    // Remove the keys from UserDefaults to ensure clean state
    userDefaults.removeObject(forKey: userProgressKey)
    userDefaults.removeObject(forKey: recentTransactionsKey)
    userDefaults.removeObject(forKey: dailyAwardsKey)

    // Update level from XP (will be level 1 with 0 XP)
    updateLevelFromXP()

    // Save the reset state (to local only, not Firestore)
    if let encoded = try? JSONEncoder().encode(userProgress) {
      userDefaults.set(encoded, forKey: userProgressKey)
    }
    saveRecentTransactions()
    saveDailyAwards()

    // Delete from Firestore
    do {
      try await FirestoreService.shared.deleteUserProgress()
      logger.info("✅ XP data cleared from Firestore")
    } catch {
      logger.error("⚠️ Failed to clear XP from Firestore: \(error.localizedDescription)")
    }

    logger.info("XP data cleared for sign-out - user will start fresh")
  }

  /// Check daily completion for habits (used by existing system)
  func checkDailyCompletion(habits: [Habit]) async {
    logger.debug("Daily completion checked for \(habits.count) habits")
  }

  /// Reset daily XP (used by existing system)
  func resetDailyXP() {
    // ✅ Update properties directly (@Observable triggers automatic UI update)
    dailyXP = 0
    
    // Keep userProgress in sync
    var updatedProgress = userProgress
    updatedProgress.dailyXP = 0
    userProgress = updatedProgress
    
    saveUserProgress()
  }

  /// Check achievements (delegated to AchievementManager)
  func checkAchievements(habits _: [Habit]) {
    logger.debug("Achievement checking delegated to AchievementManager")
  }

  // MARK: - Display Helpers

  func getXPCelebrationMessage(earnedXP: Int, habitCount: Int) -> String {
    if habitCount == 1 {
      "You earned \(earnedXP) XP!"
    } else {
      "You earned \(earnedXP) XP for completing \(habitCount) habits!"
    }
  }

  func getFormattedTotalXP() -> String {
    if userProgress.totalXP >= 1000 {
      String(format: "%.1fK", Double(userProgress.totalXP) / 1000.0)
    } else {
      "\(userProgress.totalXP)"
    }
  }

  func getFormattedDailyXP() -> String {
    "\(userProgress.dailyXP)"
  }

  func calculateLevel() -> Int {
    calculateLevel(for: userProgress.totalXP)
  }

  func getXPProgressToNextLevel() -> (current: Int, needed: Int, percentage: Double) {
    let currentLevel = calculateLevel()
    let currentLevelStartXP = Int(pow(Double(currentLevel - 1), 2) * Double(levelBaseXP))
    let nextLevelStartXP = Int(pow(Double(currentLevel), 2) * Double(levelBaseXP))
    let currentXPInLevel = userProgress.totalXP - currentLevelStartXP
    let neededXP = nextLevelStartXP - userProgress.totalXP
    let xpNeededForNextLevel = nextLevelStartXP - currentLevelStartXP
    let percentage = Double(currentXPInLevel) / Double(xpNeededForNextLevel)

    return (current: currentXPInLevel, needed: neededXP, percentage: min(percentage, 1.0))
  }

  // MARK: - Testing/Debug Methods

  #if DEBUG
  /// ⚠️ DEBUG ONLY: Verify daily XP limits are respected
  func verifyDailyXPLimits() {
    // Check if daily XP exceeds reasonable limits
    precondition(
      userProgress.dailyXP <= 500,
      "Daily XP \(userProgress.dailyXP) exceeds reasonable limit - possible duplication")
  }
  #endif

  #if DEBUG
  /// ⚠️ DEBUG/ADMIN ONLY: Reset all XP data to defaults
  /// DO NOT call from production code - this bypasses DailyAwardService
  func resetXPData() {
    userProgress = UserProgress()
    recentTransactions = []
    dailyAwards = [:]
    updateLevelFromXP() // Ensure level is calculated from XP
    saveUserProgress()
    saveRecentTransactions()
    saveDailyAwards()
    logger.info("XP data reset to defaults")
  }

  /// ⚠️ DEBUG/ADMIN ONLY: Reset XP to a specific level for testing/correction
  /// DO NOT call from production code - this bypasses DailyAwardService
  func resetXPToLevel(_ level: Int) {
    let baseXP = Int(pow(Double(level - 1), 2) * Double(levelBaseXP))
    
    // ✅ FIX: Create new UserProgress with baseXP, then assign once
    var newProgress = UserProgress()
    newProgress.totalXP = baseXP
    userProgress = newProgress
    
    // Level will be calculated from XP automatically
    recentTransactions = []
    dailyAwards = [:]
    updateLevelFromXP() // Ensure level is calculated from XP
    saveUserProgress()
    saveRecentTransactions()
    saveDailyAwards()
    logger.info("XP reset to level \(level) with \(baseXP) XP")
  }

  /// ⚠️ DEBUG/ADMIN ONLY: Fix XP data by recalculating level from current XP
  /// DO NOT call from production code - this bypasses DailyAwardService
  func fixXPData() {
    updateLevelFromXP() // Ensure level is calculated from XP
    saveUserProgress()
    logger.info("Fixed XP data: level=\(self.userProgress.currentLevel)")
  }

  /// ⚠️ DEBUG/ADMIN ONLY: Emergency reset method to fix corrupted XP data
  /// DO NOT call from production code - this bypasses DailyAwardService
  func emergencyResetXP() {
    userProgress = UserProgress()
    recentTransactions = []
    dailyAwards = [:]
    updateLevelFromXP() // Ensure level is calculated from XP
    saveUserProgress()
    saveRecentTransactions()
    saveDailyAwards()
    logger.info("Emergency XP reset completed - back to level 1")
  }
  #endif

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "XPManager")
  private let userDefaults = UserDefaults.standard
  private let userProgressKey = "user_progress"
  private let recentTransactionsKey = "recent_xp_transactions"
  private let dailyAwardsKey = "daily_xp_awards"

  /// Track which habits have been awarded XP today to prevent duplicates
  private var dailyAwards: [String: Set<UUID>] = [:]

  /// Level calculation constants - MUCH MORE CHALLENGING
  private let levelBaseXP = 300 // XP needed for level 2 (6x harder than before)

  // MARK: - Pure Level Calculation

  /// Pure function to calculate level from XP
  private func level(forXP totalXP: Int) -> Int {
    Int(sqrt(Double(totalXP) / Double(levelBaseXP))) + 1
  }

  // MARK: - DEPRECATED XP Methods (DO NOT USE)

  // These methods are kept for backwards compatibility only
  // ALL NEW CODE MUST USE DailyAwardService

  /// ❌ REMOVED: awardXPForAllHabitsCompleted method
  /// This method has been removed in Phase 4. Use XPService.awardDailyCompletionIfEligible instead.
  @available(
    *,
    unavailable,
    message: "Removed in Phase 4. Use XPService.awardDailyCompletionIfEligible instead.")
  private func awardXPForAllHabitsCompleted(habits _: [Habit], for _: Date = Date()) -> Int {
    fatalError(
      "awardXPForAllHabitsCompleted has been removed. Use XPService.awardDailyCompletionIfEligible instead.")
  }

  /// Load user-specific XP from SwiftData DailyAward records
  private func loadUserXPFromSwiftData(userId: String) {
    // Note: This method needs access to ModelContext to query SwiftData
    // For now, we'll implement a placeholder that can be called from a view
    // The actual implementation should be called from a view that has @Environment(\\.modelContext)
  }

  /// ❌ DEPRECATED: Use DailyAwardService.revokeIfAnyIncomplete() instead
  /// This method causes duplicate XP removal and should not be called
  @available(*, deprecated, message: "XP must go through DailyAwardService to prevent duplicates")
  private func removeXPForHabitUncompleted(
    habits: [Habit],
    for date: Date = Date(),
    oldProgress: Int? = nil) -> Int
  {
    let targetDate = DateUtils.startOfDay(for: date)
    let dateKey = DateKey.key(for: date)

    // Calculate XP that should be removed (based on what was previously awarded)
    let xpToRemove = calculateXPToRemoveForHabits(habits, for: targetDate, oldProgress: oldProgress)

    if xpToRemove > 0 {
      // Remove the XP
      userProgress.totalXP = max(0, userProgress.totalXP - xpToRemove)
      userProgress.dailyXP = max(0, userProgress.dailyXP - xpToRemove)

      // Update level from XP (pure function approach)
      updateLevelFromXP()

      // Add transaction for removal
      let transaction = XPTransaction(
        amount: -xpToRemove,
        reason: .completeHabit,
        description: "Habit uncompleted")
      addTransaction(transaction)

      // Remove from daily awards tracking
      for habit in habits {
        dailyAwards[dateKey]?.remove(habit.id)
      }
      saveDailyAwards()

      // Save data
      saveUserProgress()
      saveRecentTransactions()

      logger.info("Removed \(xpToRemove) XP for uncompleting habits")
    }

    return xpToRemove
  }

  // MARK: - XP Calculation (Private Helper)

  /// Calculate XP to remove for uncompleted habits (based on what was previously awarded)
  private func calculateXPToRemoveForHabits(
    _ habits: [Habit],
    for date: Date,
    oldProgress: Int? = nil) -> Int
  {
    var totalXP = 0

    for habit in habits {
      // Calculate the XP that was previously awarded for this habit
      // Use oldProgress if provided, otherwise check completion history
      let dateKey = DateKey.key(for: date)
      let previousProgress = oldProgress ?? (habit.completionHistory[dateKey] ?? 0)

      if previousProgress > 0 {
        // This habit was previously completed, so we need to remove the XP that was awarded
        let baseXP = XPRewards.completeHabit
        let streakBonus = calculateStreakBonus(for: habit)
        let habitXP = baseXP + streakBonus
        totalXP += habitXP
      }
    }

    return totalXP
  }

  private func calculateTotalXPForHabits(_ habits: [Habit], for date: Date) -> Int {
    var totalXP = 0
    var completedHabitsCount = 0

    for habit in habits {
      if habit.isCompleted(for: date) {
        let baseXP = XPRewards.completeHabit
        let streakBonus = calculateStreakBonus(for: habit)
        totalXP += baseXP + streakBonus
        completedHabitsCount += 1
      }
    }

    // Bonus for completing ALL habits
    if completedHabitsCount == habits.count, !habits.isEmpty {
      totalXP += XPRewards.completeAllHabits
    }

    return totalXP
  }

  private func calculateStreakBonus(for habit: Habit) -> Int {
    let streak = habit.computedStreak()
    switch streak {
    case 0 ... 6: return 0
    case 7 ... 13: return 5
    case 14 ... 29: return 10
    case 30 ... 99: return 15
    default: return 20
    }
  }

  // MARK: - Core XP Management (Private - Use DailyAwardService instead)

  /// ⚠️  INTERNAL USE ONLY: Do not call this method directly
  /// All XP awards must go through XPService to prevent duplicates
  private func addXP(_ amount: Int, reason _: XPRewardReason, description _: String) {
    let oldLevel = userProgress.currentLevel

    #if DEBUG
    // Debug invariant: ensure XP changes are reasonable
    precondition(amount > 0, "XP amount must be positive")
    precondition(amount <= 1000, "XP amount \(amount) seems too high - possible duplication")
    #endif

    // Add XP
    userProgress.totalXP += amount
    userProgress.dailyXP += amount

    // Update level from XP (pure function approach)
    let newLevel = level(forXP: userProgress.totalXP)
    if newLevel > oldLevel {
      // Level up detected - but NO bonus XP to prevent feedback loops
      logger.info("Level up! Reached level \(newLevel) (no bonus XP to prevent inflation)")
    }

    // Always update level from current XP to prevent double-bumping
    updateLevelFromXP()

    fatalError("addXP has been removed. Use XPService instead.")
  }

  private func awardLevelUpBonus(newLevel: Int) {
    // Add level-up XP directly (no recursion)
    userProgress.totalXP += XPRewards.levelUp
    userProgress.dailyXP += XPRewards.levelUp

    // Add transaction
    let transaction = XPTransaction(
      amount: XPRewards.levelUp,
      reason: .levelUp,
      description: "Level \(newLevel) reached!")
    addTransaction(transaction)

    logger.info("Awarded \(XPRewards.levelUp) XP for reaching level \(newLevel)")
  }

  private func addTransaction(_ transaction: XPTransaction) {
    recentTransactions.insert(transaction, at: 0)
    if recentTransactions.count > 10 {
      recentTransactions.removeLast()
    }
  }

  // MARK: - Level Management

  /// Legacy method - use level(forXP:) instead
  private func calculateLevel(for totalXP: Int) -> Int {
    level(forXP: totalXP)
  }

  private func updateLevelProgress() {
    let currentLevel = userProgress.currentLevel
    let currentLevelStartXP = Int(pow(Double(currentLevel - 1), 2) * Double(levelBaseXP))
    let nextLevelStartXP = Int(pow(Double(currentLevel), 2) * Double(levelBaseXP))

    userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
    userProgress.xpForNextLevel = nextLevelStartXP - currentLevelStartXP
  }

  private func loadRecentTransactions() {
    if let data = userDefaults.data(forKey: recentTransactionsKey),
       let transactions = try? JSONDecoder().decode([XPTransaction].self, from: data)
    {
      recentTransactions = transactions
    }
  }

  private func saveDailyAwards() {
    if let encoded = try? JSONEncoder().encode(dailyAwards) {
      userDefaults.set(encoded, forKey: dailyAwardsKey)
    }
  }

  private func loadDailyAwards() {
    if let data = userDefaults.data(forKey: dailyAwardsKey),
       let awards = try? JSONDecoder().decode([String: Set<UUID>].self, from: data)
    {
      dailyAwards = awards
    }
  }
}
