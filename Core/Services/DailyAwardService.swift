import Combine
import FirebaseCore
import Foundation

/// Service for managing XP awards with ledger-based integrity
///
/// This is the **single source of truth** for all XP changes in the app.
/// All XP awards must go through this service to maintain integrity.
///
/// Responsibilities:
/// - Award XP with delta and reason (positive or negative)
/// - Maintain append-only ledger for audit trail
/// - Update XP state transactionally
/// - Calculate level progression
/// - Verify XP integrity (sum(ledger) == state.totalXP)
/// - Auto-repair on integrity mismatch
///
/// Integrity Guarantee:
/// - Ledger is append-only (immutable)
/// - State is derived from ledger
/// - Integrity check on app start
/// - Auto-repair if mismatch detected
@MainActor
class DailyAwardService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = DailyAwardService()
    
    // MARK: - Published Properties
    
    /// Current XP state
    @Published private(set) var xpState: XPState?
    
    /// Error state
    @Published private(set) var error: XPError?
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let dateFormatter: LocalDateFormatter
    
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
        repository: FirestoreRepository? = nil,
        dateFormatter: LocalDateFormatter? = nil
    ) {
        self.repository = repository ?? FirestoreRepository.shared
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
        
        // Start streaming XP state
        startXPStateStream()
    }
    
    // MARK: - XP Award Methods
    
    /// Award XP to the user
    ///
    /// This is the **only** method that should be used to change XP.
    /// It maintains an append-only ledger and updates state transactionally.
    ///
    /// - Parameters:
    ///   - delta: The XP change (can be positive or negative)
    ///   - reason: Human-readable reason for the award (1-500 characters)
    ///
    /// - Note: Uses Firestore transaction to ensure ledger and state stay in sync
    func awardXP(delta: Int, reason: String) async throws {
        guard !reason.isEmpty && reason.count <= 500 else {
            throw XPError.invalidReason("Reason must be 1-500 characters")
        }
        
        print("🎖️ DailyAwardService: Awarding \(delta) XP for '\(reason)'")
        
        do {
            // Award via repository (appends to ledger + updates state)
            try await repository.awardXP(delta: delta, reason: reason)
            
            // Refresh state
            await refreshXPState()
            
            if let state = xpState {
                print("✅ DailyAwardService: XP awarded - Total: \(state.totalXP), Level: \(state.level)")
            }
            
        } catch {
            print("❌ DailyAwardService: Failed to award XP: \(error)")
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
        var level = 1
        var remainingXP = totalXP
        
        while remainingXP >= xpRequiredForLevel(level) {
            remainingXP -= xpRequiredForLevel(level)
            level += 1
        }
        
        return (level: level, currentLevelXP: remainingXP)
    }
    
    // MARK: - Integrity Methods
    
    /// Verify XP integrity
    ///
    /// Checks that `sum(ledger) == state.totalXP`.
    ///
    /// - Returns: True if integrity check passes
    func verifyIntegrity() async throws -> Bool {
        print("🔍 DailyAwardService: Verifying XP integrity...")
        
        do {
            let isValid = try await repository.verifyXPIntegrity()
            
            if isValid {
                print("✅ DailyAwardService: XP integrity verified")
            } else {
                print("⚠️ DailyAwardService: XP integrity mismatch detected")
            }
            
            return isValid
        } catch {
            print("❌ DailyAwardService: Integrity check failed: \(error)")
            throw XPError.integrityCheckFailed(error.localizedDescription)
        }
    }
    
    /// Repair XP integrity by recalculating from ledger
    ///
    /// Recalculates totalXP and level from the ledger (source of truth).
    /// Safe to call if integrity check fails.
    func repairIntegrity() async throws {
        print("🔧 DailyAwardService: Repairing XP integrity...")
        
        do {
            try await repository.repairXPIntegrity()
            
            // Refresh state after repair
            await refreshXPState()
            
            print("✅ DailyAwardService: XP integrity repaired")
            
            if let state = xpState {
                print("   New state - Total: \(state.totalXP), Level: \(state.level)")
            }
            
        } catch {
            print("❌ DailyAwardService: Integrity repair failed: \(error)")
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
            print("⚠️ DailyAwardService: Integrity mismatch, auto-repairing...")
            try await repairIntegrity()
            return true
        }
        
        return true
    }
    
    // MARK: - Real-time Streams
    
    /// Start streaming XP state for real-time UI updates
    private func startXPStateStream() {
        print("👂 DailyAwardService: Starting XP state stream")
        
        Task {
            guard await waitForFirebaseConfigurationIfNeeded() else {
                print("⚠️ DailyAwardService: Firebase not configured, XP stream not started")
                return
            }
            repository.streamXPState()
        }
    }
    
    /// Refresh XP state from repository
    func refreshXPState() async {
        print("🔄 DailyAwardService: Refreshing XP state")
        
        guard await waitForFirebaseConfigurationIfNeeded() else {
            print("⚠️ DailyAwardService: Firebase not configured, skipping XP refresh")
            return
        }
        
        xpState = repository.xpState
    }
    
    /// Stop all listeners
    func stopListening() {
        repository.stopListening()
        print("🛑 DailyAwardService: Stopped all XP listeners")
    }
    
    private func waitForFirebaseConfigurationIfNeeded(timeout: TimeInterval = 3) async -> Bool {
        if FirebaseBootstrapper.isConfigured {
            return true
        }
        
        let pollInterval: UInt64 = 50_000_000 // 50ms
        let maxIterations = Int((timeout * 1_000_000_000) / Double(pollInterval))
        
        for _ in 0..<maxIterations {
            try? await Task.sleep(nanoseconds: pollInterval)
            if FirebaseBootstrapper.isConfigured {
                return true
            }
        }
        
        return FirebaseBootstrapper.isConfigured
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
