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
    /// This is the **only** method that should be used to change XP.
    /// It updates UserProgressData by adding delta (or recalculating from DailyAward records).
    ///
    /// - Parameters:
    ///   - delta: The XP change (can be positive or negative)
    ///   - reason: Human-readable reason for the award (1-500 characters)
    ///
    /// - Note: ✅ GUEST-ONLY MODE: Updates UserProgressData in SwiftData (no authentication required)
    ///   After DailyAward record is created by HabitStore, refreshXPState() will recalculate from ledger.
    func awardXP(delta: Int, reason: String) async throws {
        guard !reason.isEmpty && reason.count <= 500 else {
            throw XPError.invalidReason("Reason must be 1-500 characters")
        }
        
        logger.info("🎖️ DailyAwardService: Awarding \(delta) XP for '\(reason)'")
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // ✅ GUEST-ONLY MODE: Get or create UserProgressData for this user
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
            
            // Update XP by adding delta (this recalculates level automatically)
            // Note: After DailyAward record is created, refreshXPState() will recalculate from ledger
            let newTotalXP = max(0, userProgress.xpTotal + delta)
            userProgress.updateXP(newTotalXP)
            
            logger.info("🎖️ DailyAwardService: Updated XP - Old: \(userProgress.xpTotal - delta), New: \(newTotalXP), Level: \(userProgress.level)")
            
            // Save changes
            try modelContext.save()
            
            // Refresh state to update xpState (recalculates from DailyAward records if they exist)
            await refreshXPState()
            
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
        let reason = "Completed '\(habitName)' on \(localDateString)"
        
        // Standard completion XP: 10 points
        try await awardXP(delta: 10, reason: reason)
    }
    
    /// Award XP for maintaining a streak
    ///
    /// Bonus XP for consecutive days.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - streakDays: Current streak count
    func awardStreakBonusXP(habitId: String, streakDays: Int) async throws {
        let reason = "Streak bonus: \(streakDays) consecutive days"
        
        // Streak bonus: 5 XP per day
        let bonus = streakDays * 5
        try await awardXP(delta: bonus, reason: reason)
    }
    
    /// Award XP for completing all habits in a day
    ///
    /// Special bonus for 100% completion rate.
    ///
    /// - Parameter date: The date of completion
    func awardDailyCompletionBonus(on date: Date) async throws {
        let localDateString = dateFormatter.dateToString(date)
        let reason = "All habits completed on \(localDateString)"
        
        // Daily completion bonus: 50 XP
        try await awardXP(delta: 50, reason: reason)
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
        logger.info("🔧 DailyAwardService: Repairing XP integrity...")
        
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
        logger.info("🔄 DailyAwardService: Refreshing XP state from SwiftData")
        
        let modelContext = SwiftDataContainer.shared.modelContext
        let userId = await CurrentUser().idOrGuest
        
        do {
            // Calculate XP from DailyAward records (source of truth)
            let awardPredicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let awardDescriptor = FetchDescriptor<DailyAward>(predicate: awardPredicate)
            let awards = try modelContext.fetch(awardDescriptor)
            let totalXP = awards.reduce(0) { $0 + $1.xpGranted }
            
            // Get level from UserProgressData or calculate from XP
            let progressPredicate = #Predicate<UserProgressData> { progress in
                progress.userId == userId
            }
            let progressDescriptor = FetchDescriptor<UserProgressData>(predicate: progressPredicate)
            let progressRecords = try modelContext.fetch(progressDescriptor)
            
            let level: Int
            let currentLevelXP: Int
            if let progress = progressRecords.first, progress.xpTotal == totalXP {
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
            xpState = XPState(
                totalXP: totalXP,
                level: level,
                currentLevelXP: currentLevelXP,
                lastUpdated: Date()
            )
            
            logger.info("✅ DailyAwardService: XP state refreshed - Total: \(totalXP), Level: \(level)")
            
        } catch {
            logger.error("❌ DailyAwardService: Failed to refresh XP state: \(error.localizedDescription)")
            // Initialize with default state if error
            xpState = XPState(
                totalXP: 0,
                level: 1,
                currentLevelXP: 0,
                lastUpdated: Date()
            )
        }
    }
    
    /// Stop all listeners (no-op in guest-only mode)
    func stopListening() {
        logger.info("🛑 DailyAwardService: stopListening() called (no-op in guest-only mode)")
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
