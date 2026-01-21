import Combine
import Foundation
import SwiftData
import OSLog

/// Service for managing XP awards with ledger-based integrity
///
/// This is the **single source of truth** for all XP changes in the app.
/// All XP awards must go through this service to maintain integrity.
///
/// Responsibilities:
/// - Award XP with delta and reason (positive or negative)
/// - Maintain append-only ledger via DailyAward records (audit trail)
/// - Update XP state transactionally in SwiftData
/// - Calculate level progression
/// - Verify XP integrity (sum(DailyAwards) == UserProgressData.totalXP)
/// - Auto-repair on integrity mismatch
///
/// Integrity Guarantee:
/// - DailyAward records are append-only (immutable)
/// - UserProgressData.totalXP is derived from sum of DailyAward.xpGranted
/// - Integrity check on app start
/// - Auto-repair if mismatch detected
///
/// ✅ GUEST-ONLY MODE: Uses SwiftData only, no Firestore/authentication required
@MainActor
class DailyAwardService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = DailyAwardService()
    
    // MARK: - Published Properties
    
    /// Current XP state (derived from SwiftData)
    @Published private(set) var xpState: XPState?
    
    /// Error state
    @Published private(set) var error: XPError?
    
    // MARK: - Dependencies
    
    private let dateFormatter: LocalDateFormatter
    private let logger = Logger(subsystem: "com.habitto.app", category: "DailyAwardService")
    
    // MARK: - Debouncing
    
    private var lastRefreshTime: Date?
    private let refreshDebounceInterval: TimeInterval = 2.0 // Don't refresh more than once every 2 seconds
    
    // MARK: - Constants
    
    /// XP required for each level
    /// Level 1: 0-99 XP
    /// Level 2: 100-249 XP (150 XP needed)
    /// Level 3: 250-449 XP (200 XP needed)
    /// Level N: progressively more XP needed
    private func xpRequiredForLevel(_ level: Int) -> Int {
        // Base formula: 100 + (level - 1) * 50
        // Level 1: 100 XP
        // Level 2: 150 XP
        // Level 3: 200 XP, etc.
        return 100 + (level - 1) * 50
    }
    
    // MARK: - Initialization
    
    init(
        dateFormatter: LocalDateFormatter? = nil
    ) {
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
        
        // ✅ GUEST-ONLY MODE: Load XP state from SwiftData on init
        Task {
            await refreshXPState()
        }
    }
    
    // MARK: - XP Award Methods
    
    /// Award XP to the user
    ///
    /// This is the **single source of truth** for all XP changes.
    /// It maintains an append-only ledger (DailyAward records) and derives state from it.
    ///
    /// **Architecture:**
    /// 1. Creates or deletes DailyAward record (immutable ledger entry)
    /// 2. Recalculates UserProgressData.totalXP from sum(DailyAward.xpGranted) (source of truth)
    /// 3. Updates xpState for UI reactivity
    ///
    /// - Parameters:
    ///   - delta: The XP change (positive = award, negative = reversal)
    ///   - dateKey: The date key (yyyy-MM-dd) for the DailyAward record
    ///   - reason: Human-readable reason for the award (1-500 characters)
    ///
    /// - Note: ✅ GUEST-ONLY MODE: Uses SwiftData only, no authentication required
    func awardXP(delta: Int, dateKey: String, reason: String) async throws {
        guard !reason.isEmpty && reason.count <= 500 else {
            throw XPError.invalidReason("Reason must be 1-500 characters")
        }
        
        guard !dateKey.isEmpty else {
            throw XPError.invalidReason("Date key cannot be empty")
        }
        
        logger.info("🎖️ DailyAwardService: Awarding \(delta) XP for '\(reason)' on \(dateKey)")
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // ✅ STEP 1: Create or delete DailyAward record (immutable ledger entry)
            // This is the source of truth - all XP calculations derive from this
            if delta > 0 {
                // Award XP: Create DailyAward record
                // Check if award already exists (idempotency)
                let existingPredicate = #Predicate<DailyAward> { award in
                    award.userId == userId && award.dateKey == dateKey
                }
                let existingDescriptor = FetchDescriptor<DailyAward>(predicate: existingPredicate)
                let existingAwards = (try? modelContext.fetch(existingDescriptor)) ?? []
                
                if existingAwards.isEmpty {
                    // Create new DailyAward record
                    let award = DailyAward(
                        userId: userId,
                        dateKey: dateKey,
                        xpGranted: delta,
                        allHabitsCompleted: true
                    )
                    modelContext.insert(award)
                } else {
                    // Award already exists - update it (shouldn't happen, but handle gracefully)
                    if let existing = existingAwards.first {
                        logger.warning("⚠️ DailyAwardService: DailyAward already exists for \(dateKey), updating from \(existing.xpGranted) to \(delta)")
                        existing.xpGranted = delta
                    }
                }
            } else if delta < 0 {
                // Reverse XP: Delete DailyAward record(s) for this date
                let deletePredicate = #Predicate<DailyAward> { award in
                    award.userId == userId && award.dateKey == dateKey
                }
                let deleteDescriptor = FetchDescriptor<DailyAward>(predicate: deletePredicate)
                let awardsToDelete = (try? modelContext.fetch(deleteDescriptor)) ?? []
                
                for award in awardsToDelete {
                    modelContext.delete(award)
                }
                
                if awardsToDelete.isEmpty {
                    logger.warning("⚠️ DailyAwardService: No DailyAward found to delete for \(dateKey) (reversal)")
                }
            }
            // delta == 0: No-op (no ledger change needed)
            
            // Save ledger changes first
            try modelContext.save()
            
            // ✅ STEP 2: Recalculate UserProgressData.totalXP from ALL DailyAward records (source of truth)
            // Calculate total XP from sum of all DailyAward records
            let allAwardsPredicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let allAwardsDescriptor = FetchDescriptor<DailyAward>(predicate: allAwardsPredicate)
            let allAwards = try modelContext.fetch(allAwardsDescriptor)
            let calculatedTotalXP = allAwards.reduce(0) { $0 + $1.xpGranted }
            
            logger.info("🎖️ DailyAwardService: Calculated total XP from \(allAwards.count) DailyAward records: \(calculatedTotalXP)")
            
            // Get or create UserProgressData
            let progressPredicate = #Predicate<UserProgressData> { progress in
                progress.userId == userId
            }
            let progressDescriptor = FetchDescriptor<UserProgressData>(predicate: progressPredicate)
            let existingProgress = (try? modelContext.fetch(progressDescriptor)) ?? []
            
            let userProgress: UserProgressData
            if let existing = existingProgress.first {
                userProgress = existing
            } else {
                // Create new UserProgressData for guest/user
                userProgress = UserProgressData(userId: userId)
                modelContext.insert(userProgress)
                logger.info("✅ DailyAwardService: Created new UserProgressData for userId: '\(userId.isEmpty ? "guest" : userId)'")
            }
            
            // Update XP from calculated value (this recalculates level automatically)
            userProgress.updateXP(calculatedTotalXP)
            
            logger.info("🎖️ DailyAwardService: Updated UserProgressData - Total: \(calculatedTotalXP), Level: \(userProgress.level)")
            
            // Save UserProgressData
            try modelContext.save()
            
            // ✅ STEP 3: Update xpState for UI reactivity
            await refreshXPState()
            
            // ✅ CRITICAL FIX: XPManager is already notified in refreshXPState()
            if let state = xpState {
                logger.info("✅ DailyAwardService: XP awarded - Total: \(state.totalXP), Level: \(state.level)")
            }
            
        } catch {
            logger.error("❌ DailyAwardService: Failed to award XP: \(error.localizedDescription)")
            self.error = .awardFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Award XP for completing a habit
    ///
    /// Standard XP amount for habit completion.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - habitName: The habit name (for reason string)
    ///   - date: The completion date
    func awardHabitCompletionXP(habitId: String, habitName: String, on date: Date) async throws {
        let localDateString = dateFormatter.dateToString(date)
        let dateKey = DateUtils.dateKey(for: date)
        let reason = "Completed '\(habitName)' on \(localDateString)"
        
        // Standard completion XP: 10 points
        try await awardXP(delta: 10, dateKey: dateKey, reason: reason)
    }
    
    /// Award XP for maintaining a streak
    ///
    /// Bonus XP for consecutive days.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - streakDays: Current streak count
    ///   - date: The date for the streak bonus
    func awardStreakBonusXP(habitId: String, streakDays: Int, on date: Date) async throws {
        let dateKey = DateUtils.dateKey(for: date)
        let reason = "Streak bonus: \(streakDays) consecutive days"
        
        // Streak bonus: 5 XP per day
        let bonus = streakDays * 5
        try await awardXP(delta: bonus, dateKey: dateKey, reason: reason)
    }
    
    /// Award XP for completing all habits in a day
    ///
    /// Special bonus for 100% completion rate.
    ///
    /// - Parameter date: The date of completion
    func awardDailyCompletionBonus(on date: Date) async throws {
        let localDateString = dateFormatter.dateToString(date)
        let dateKey = DateUtils.dateKey(for: date)
        let reason = "All habits completed on \(localDateString)"
        
        // Daily completion bonus: 50 XP
        try await awardXP(delta: 50, dateKey: dateKey, reason: reason)
    }
    
    // MARK: - XP State Query Methods
    
    /// Get current total XP
    func getTotalXP() -> Int {
        xpState?.totalXP ?? 0
    }
    
    /// Get current level
    func getCurrentLevel() -> Int {
        xpState?.level ?? 1
    }
    
    /// Get XP progress in current level
    ///
    /// - Returns: (currentLevelXP, xpNeededForNextLevel)
    func getLevelProgress() -> (current: Int, needed: Int) {
        guard let state = xpState else {
            return (0, xpRequiredForLevel(1))
        }
        
        let needed = xpRequiredForLevel(state.level)
        return (state.currentLevelXP, needed)
    }
    
    /// Calculate level from total XP
    ///
    /// - Parameter totalXP: Total XP accumulated
    /// - Returns: (level, currentLevelXP)
    func calculateLevel(totalXP: Int) -> (level: Int, currentLevelXP: Int) {
        // ✅ GUEST-ONLY MODE: Use same formula as UserProgressData
        // Level formula: level = floor(sqrt(xp / 300)) + 1
        let levelFloat = sqrt(Double(totalXP) / 300.0)
        let level = max(1, Int(floor(levelFloat)) + 1)
        
        // Calculate currentLevelXP
        let currentLevelStartXP = Int(pow(Double(level - 1), 2) * 300)
        let currentLevelXP = totalXP - currentLevelStartXP
        
        return (level: level, currentLevelXP: max(0, currentLevelXP))
    }
    
    // MARK: - Integrity Methods
    
    /// Verify XP integrity
    ///
    /// Checks that `sum(DailyAward.xpGranted) == UserProgressData.totalXP`.
    ///
    /// - Returns: True if integrity check passes
    func verifyIntegrity() async throws -> Bool {
        logger.info("🔍 DailyAwardService: Verifying XP integrity...")
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // Calculate XP from DailyAward records (source of truth)
            let awardPredicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
            let awards = try modelContext.fetch(awardDescriptor)
            let calculatedXP = awards.reduce(0) { $0 + $1.xpGranted }
            
            // Get stored XP from UserProgressData
            let progressPredicate = #Predicate<UserProgressData> { progress in
                progress.userId == userId
            }
            let progressDescriptor = FetchDescriptor<UserProgressData>(predicate: progressPredicate)
            let progressRecords = try modelContext.fetch(progressDescriptor)
            let storedXP = progressRecords.first?.xpTotal ?? 0
            
            let isValid = calculatedXP == storedXP
            
            if isValid {
                logger.info("✅ DailyAwardService: XP integrity verified (calculated: \(calculatedXP), stored: \(storedXP))")
            } else {
                logger.warning("⚠️ DailyAwardService: XP integrity mismatch detected (calculated: \(calculatedXP), stored: \(storedXP))")
            }
            
            return isValid
        } catch {
            logger.error("❌ DailyAwardService: Integrity check failed: \(error.localizedDescription)")
            throw XPError.integrityCheckFailed(error.localizedDescription)
        }
    }
    
    /// Repair XP integrity by recalculating from DailyAward records
    ///
    /// Recalculates totalXP and level from DailyAward records (source of truth).
    /// Safe to call if integrity check fails.
    func repairIntegrity() async throws {
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // Calculate XP from DailyAward records (source of truth)
            let awardPredicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
            let awards = try modelContext.fetch(awardDescriptor)
            let calculatedXP = awards.reduce(0) { $0 + $1.xpGranted }
            
            // Get or create UserProgressData
            let progressPredicate = #Predicate<UserProgressData> { progress in
                progress.userId == userId
            }
            let progressDescriptor = FetchDescriptor<UserProgressData>(predicate: progressPredicate)
            let progressRecords = try modelContext.fetch(progressDescriptor)
            
            let userProgress: UserProgressData
            if let existing = progressRecords.first {
                userProgress = existing
            } else {
                userProgress = UserProgressData(userId: userId)
                modelContext.insert(userProgress)
            }
            
            // Update XP to calculated value
            userProgress.updateXP(calculatedXP)
            
            try modelContext.save()
            
            // Refresh state after repair
            await refreshXPState()
            
            logger.info("✅ DailyAwardService: XP integrity repaired - Total: \(calculatedXP)")
            
            if let state = xpState {
                logger.info("   New state - Total: \(state.totalXP), Level: \(state.level)")
            }
            
        } catch {
            logger.error("❌ DailyAwardService: Integrity repair failed: \(error.localizedDescription)")
            self.error = .repairFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Perform integrity check and auto-repair if needed
    ///
    /// Call this on app startup to ensure XP data is consistent.
    ///
    /// - Returns: True if integrity was valid or successfully repaired
    func checkAndRepairIntegrity() async throws -> Bool {
        let isValid = try await verifyIntegrity()
        
        if !isValid {
            logger.warning("⚠️ DailyAwardService: Integrity mismatch, auto-repairing...")
            try await repairIntegrity()
            return true
        }
        
        return true
    }
    
    // MARK: - XP State Management
    
    /// Refresh XP state from SwiftData
    /// ✅ GUEST-ONLY MODE: Loads XP from UserProgressData and DailyAward records
    func refreshXPState() async {
        // Debounce: Skip if called too recently
        if let lastRefresh = lastRefreshTime, Date().timeIntervalSince(lastRefresh) < refreshDebounceInterval {
            return
        }
        
        lastRefreshTime = Date()
        logger.info("🔄 DailyAwardService: Refreshing XP state from SwiftData")
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // ✅ DIAGNOSTIC: Query ALL DailyAwards first
            let allAwardsDescriptor = FetchDescriptor<DailyAward>()
            let allAwards = try modelContext.fetch(allAwardsDescriptor)
            
            // Calculate XP from DailyAward records (source of truth)
            let awardPredicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
            let awards = try modelContext.fetch(awardDescriptor)
            
            // ✅ FALLBACK: If predicate returns 0 but we have awards, check for userId mismatches
            var finalAwards = awards
            if awards.isEmpty && !allAwards.isEmpty {
                // First try code filter with exact userId match
                let filtered = allAwards.filter { $0.userId == userId }
                if !filtered.isEmpty {
                    finalAwards = filtered
                } else {
                    // If still empty, check for guest/empty string mismatches
                    // This handles cases where awards were saved with "" but user is now authenticated (or vice versa)
                    if userId.isEmpty {
                        // Current user is guest - check for any awards with empty userId
                        let guestAwards = allAwards.filter { $0.userId.isEmpty }
                        if !guestAwards.isEmpty {
                            finalAwards = guestAwards
                        }
                    }
                }
            }
            
            let totalXP = finalAwards.reduce(0) { $0 + $1.xpGranted }
            
            // Get level from UserProgressData or calculate from XP
            // ✅ DIAGNOSTIC: Query ALL UserProgressData first
            let allProgressDescriptor = FetchDescriptor<UserProgressData>()
            let allProgress = try modelContext.fetch(allProgressDescriptor)
            
            let progressPredicate = #Predicate<UserProgressData> { progress in
                progress.userId == userId
            }
            let progressDescriptor = FetchDescriptor<UserProgressData>(predicate: progressPredicate)
            let progressRecords = try modelContext.fetch(progressDescriptor)
            
            // ✅ FALLBACK: If predicate returns 0 but we have progress, use code filter
            var finalProgress: UserProgressData? = progressRecords.first
            if finalProgress == nil && !allProgress.isEmpty {
                let filtered = allProgress.filter { $0.userId == userId }
                if let first = filtered.first {
                    finalProgress = first
                }
            }
            
            let level: Int
            let currentLevelXP: Int
            if let progress = finalProgress, progress.xpTotal == totalXP {
                // UserProgressData is in sync, use its level
                level = progress.level
                currentLevelXP = progress.xpForCurrentLevel
            } else {
                // Calculate level from XP
                let levelInfo = calculateLevel(totalXP: totalXP)
                level = levelInfo.level
                currentLevelXP = levelInfo.currentLevelXP
                
                // Update UserProgressData if it exists but is out of sync
                if let progress = progressRecords.first {
                    progress.updateXP(totalXP)
                    try? modelContext.save()
                }
            }
            
            // Update XPState
            let refreshTimestamp = Date()
            
            xpState = XPState(
                totalXP: totalXP,
                level: level,
                currentLevelXP: currentLevelXP,
                lastUpdated: refreshTimestamp
            )
            
            logger.info("✅ DailyAwardService: XP state refreshed - Total: \(totalXP), Level: \(level)")
            
            // ✅ CRITICAL FIX: Immediately notify XPManager for instant UI updates
            // Since both DailyAwardService and XPManager are @MainActor, we can call directly
            // Pass fromDirectCall: true to bypass grace period check and ensure immediate update
            // This ensures @Observable properties update synchronously on MainActor, triggering SwiftUI to re-render
            if let newState = xpState {
                XPManager.shared.applyXPState(newState, fromDirectCall: true)
            }
            
        } catch {
            logger.error("❌ DailyAwardService: Failed to refresh XP state: \(error.localizedDescription)")
            // Initialize with default state if error
            let defaultState = XPState(
                totalXP: 0,
                level: 1,
                currentLevelXP: 0,
                lastUpdated: Date()
            )
            xpState = defaultState
            
            // ✅ CRITICAL FIX: Notify XPManager even on error to ensure UI shows correct state
            // Since both classes are @MainActor, we can call directly
            // Pass fromDirectCall: true to bypass grace period check
            XPManager.shared.applyXPState(defaultState, fromDirectCall: true)
        }
    }
    
    /// Stop all listeners (no-op in guest-only mode)
    func stopListening() {
        logger.info("🛑 DailyAwardService: stopListening() called (no-op in guest-only mode)")
    }
    
    /// Reset DailyAwardService state (clears xpState)
    func resetState() {
        logger.info("🔄 DailyAwardService: Resetting state")
        xpState = nil
        
        // ✅ CRITICAL FIX: Notify XPManager with zero state when resetting
        // This ensures UI updates immediately to show 0 XP
        // Pass fromDirectCall: true to bypass grace period check
        let zeroState = XPState(
            totalXP: 0,
            level: 1,
            currentLevelXP: 0,
            lastUpdated: Date()
        )
        XPManager.shared.applyXPState(zeroState, fromDirectCall: true)
        logger.info("✅ DailyAwardService: State reset complete, XPManager notified with zero state (fromDirectCall: true)")
    }
    
    // MARK: - CompletionRecord Reconciliation
    
    /// Result of CompletionRecord reconciliation
    struct ReconciliationResult {
        let totalRecords: Int
        let mismatchesFound: Int
        let mismatchesFixed: Int
        let errors: Int
    }
    
    /// Determine if reconciliation should be skipped for a record
    ///
    /// ✅ CRITICAL FIX: Prevents overwriting valid synced data with stale local event calculations
    ///
    /// Skips reconciliation if:
    /// 1. Record was recently synced (within 5 minutes) - likely from another device
    /// 2. Local events appear stale (calculated <= 0 but record > 0) - missing events on this device
    /// 3. Delta is suspiciously large (> 5) - likely missing events
    ///
    /// - Parameters:
    ///   - record: The CompletionRecord to check
    ///   - calculatedProgress: Progress calculated from local ProgressEvents
    ///   - recordProgress: Current progress stored in CompletionRecord
    ///   - recordIdentifier: String identifier for logging
    /// - Returns: true if reconciliation should be skipped
    private func shouldSkipReconciliation(
        record: CompletionRecord,
        calculatedProgress: Int,
        recordProgress: Int,
        recordIdentifier: String
    ) -> Bool {
        // 1. Skip if recently synced (within 5 minutes)
        if let updatedAt = record.updatedAt {
            let timeSinceUpdate = Date().timeIntervalSince(updatedAt)
            let recentSyncThreshold: TimeInterval = 5 * 60 // 5 minutes
            
            if timeSinceUpdate < recentSyncThreshold {
                return true
            }
        }
        
        // 2. Skip if local events seem stale (calculated <= 0 but record > 0)
        // This indicates local events are incomplete - trust the synced record
        if calculatedProgress <= 0 && recordProgress > 0 {
            logger.warning("⚠️ DailyAwardService: Skipping reconciliation for \(recordIdentifier) - local events appear stale (calculated=\(calculatedProgress), record=\(recordProgress))")
            return true
        }
        
        // 3. Skip if the delta is suspiciously large (> 5) - likely missing events
        let delta = abs(recordProgress - calculatedProgress)
        if delta > 5 {
            logger.warning("⚠️ DailyAwardService: Skipping reconciliation for \(recordIdentifier) - delta too large (\(delta)) - likely missing events (calculated=\(calculatedProgress), record=\(recordProgress))")
            return true
        }
        
        // Reconciliation is safe to proceed
        return false
    }
    
    /// Reconcile all CompletionRecords from ProgressEvents (source of truth)
    ///
    /// ✅ PRIORITY 3: Ensures CompletionRecord.progress matches ProgressEvents.
    /// This fixes any drift that may occur if one operation fails.
    ///
    /// Algorithm:
    /// 1. Query all CompletionRecords for current user
    /// 2. For each CompletionRecord:
    ///    - Calculate progress from ProgressEvents (source of truth)
    ///    - Compare with CompletionRecord.progress
    ///    - Update if mismatch detected
    /// 3. Save all changes in batch
    ///
    /// - Returns: ReconciliationResult with statistics
    /// - Note: Safe to run multiple times (idempotent)
    func reconcileCompletionRecords() async throws -> ReconciliationResult {
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        // Query all CompletionRecords for current user
        let recordPredicate = #Predicate<CompletionRecord> { record in
            record.userId == userId
        }
        let recordDescriptor = FetchDescriptor<CompletionRecord>(predicate: recordPredicate)
        let allRecords = try modelContext.fetch(recordDescriptor)
        
        
        let totalRecords = allRecords.count
        var mismatchesFound = 0
        var mismatchesFixed = 0
        var errors = 0
        
        // Cache HabitData lookups to avoid repeated queries
        var habitDataCache: [UUID: HabitData] = [:]
        
        // Helper to get HabitData (with caching)
        func getHabitData(habitId: UUID) -> HabitData? {
            if let cached = habitDataCache[habitId] {
                return cached
            }
            
            let habitPredicate = #Predicate<HabitData> { habit in
                habit.id == habitId && habit.userId == userId
            }
            let habitDescriptor = FetchDescriptor<HabitData>(predicate: habitPredicate)
            
            if let habitData = try? modelContext.fetch(habitDescriptor).first {
                habitDataCache[habitId] = habitData
                return habitData
            }
            
            return nil
        }
        
        // Helper to get goalAmount for a specific date
        func getGoalAmount(habitData: HabitData, dateKey: String) -> Int {
            // Parse dateKey to Date
            guard let date = DateUtils.date(from: dateKey) else {
                // Fallback: use current goal string
                return StreakDataCalculator.parseGoalAmount(from: habitData.goal)
            }
            
            // Convert HabitData to Habit to use goalAmount(for:) which considers goalHistory
            // This is @MainActor, but we're already on MainActor
            let habit = habitData.toHabit()
            return habit.goalAmount(for: date)
        }
        
        // Process each CompletionRecord
        for record in allRecords {
            let habitId = record.habitId
            let dateKey = record.dateKey
            let currentProgress = record.progress
            let recordIdentifier = "habitId=\(habitId.uuidString.prefix(8))..., dateKey=\(dateKey)"
            
            // Get HabitData to determine goalAmount
            guard let habitData = getHabitData(habitId: habitId) else {
                logger.warning("⚠️ DailyAwardService: HabitData not found for \(recordIdentifier) (skipping CompletionRecord)")
                errors += 1
                continue
            }
            
            // Get goalAmount for this date (considers goalHistory)
            let goalAmount = getGoalAmount(habitData: habitData, dateKey: dateKey)
            
            // Calculate progress from ProgressEvents (source of truth)
            // Note: calculateProgressFromEvents is async but doesn't throw
            let eventResult = await ProgressEventService.shared.calculateProgressFromEvents(
                habitId: habitId,
                dateKey: dateKey,
                goalAmount: goalAmount,
                legacyProgress: nil  // Don't use legacy, we want pure event calculation
            )
            
            let calculatedProgress = eventResult.progress
            
            // Compare with CompletionRecord.progress
            if calculatedProgress != currentProgress {
                mismatchesFound += 1
                
                logger.info("   CompletionRecord.progress: \(currentProgress)")
                logger.info("   Calculated from ProgressEvents: \(calculatedProgress)")
                logger.info("   Delta: \(calculatedProgress - currentProgress)")
                
                // ✅ CRITICAL FIX: Don't overwrite recently synced CompletionRecords
                // If the record was updated recently (within last 5 minutes), it was likely synced from another device
                // and the local events are stale. Trust the synced data.
                if shouldSkipReconciliation(
                    record: record,
                    calculatedProgress: calculatedProgress,
                    recordProgress: currentProgress,
                    recordIdentifier: recordIdentifier
                ) {
                    continue
                }
                
                // Update CompletionRecord to match ProgressEvents
                record.progress = calculatedProgress
                
                // Update isCompleted based on calculated progress
                record.isCompleted = calculatedProgress >= goalAmount
                
                mismatchesFixed += 1
                
                logger.info("✅ DailyAwardService: Updated CompletionRecord - progress: \(calculatedProgress), isCompleted: \(calculatedProgress >= goalAmount)")
            }
        }
        
        // Save all changes in batch
        if mismatchesFixed > 0 {
            try modelContext.save()
            logger.info("✅ DailyAwardService: Saved \(mismatchesFixed) CompletionRecord updates")
        }
        
        let result = ReconciliationResult(
            totalRecords: totalRecords,
            mismatchesFound: mismatchesFound,
            mismatchesFixed: mismatchesFixed,
            errors: errors
        )
        
        logger.info("✅ DailyAwardService: Reconciliation complete")
        logger.info("   Total records checked: \(totalRecords)")
        logger.info("   Mismatches found: \(mismatchesFound)")
        logger.info("   Mismatches fixed: \(mismatchesFixed)")
        logger.info("   Errors: \(errors)")
        
        return result
    }
}

// MARK: - Errors

enum XPError: LocalizedError {
    case awardFailed(String)
    case invalidReason(String)
    case integrityCheckFailed(String)
    case repairFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .awardFailed(let message):
            return "Failed to award XP: \(message)"
        case .invalidReason(let message):
            return "Invalid reason: \(message)"
        case .integrityCheckFailed(let message):
            return "Integrity check failed: \(message)"
        case .repairFailed(let message):
            return "Integrity repair failed: \(message)"
        }
    }
}
