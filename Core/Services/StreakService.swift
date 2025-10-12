import Foundation
import Combine

/// Service for managing habit streaks with consecutive day detection
///
/// Responsibilities:
/// - Track consecutive days of habit completion
/// - Maintain current streak and longest streak
/// - Detect streak breaks (non-consecutive days)
/// - Support "all habits complete" gating for daily streaks
/// - Handle streak resets
///
/// Streak Logic:
/// - Streak increments when a habit is completed on consecutive days
/// - Streak breaks if a day is skipped
/// - Longest streak is preserved even when current streak breaks
@MainActor
class StreakService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = StreakService()
    
    // MARK: - Published Properties
    
    /// Current streaks by habit ID
    @Published private(set) var streaks: [String: Streak] = [:]
    
    /// Error state
    @Published private(set) var error: StreakError?
    
    // MARK: - Dependencies
    
    private let repository: FirestoreRepository
    private let completionService: CompletionService
    private let dateFormatter: LocalDateFormatter
    
    // MARK: - Initialization
    
    init(
        repository: FirestoreRepository? = nil,
        completionService: CompletionService? = nil,
        dateFormatter: LocalDateFormatter? = nil
    ) {
        self.repository = repository ?? FirestoreRepository.shared
        self.completionService = completionService ?? CompletionService.shared
        self.dateFormatter = dateFormatter ?? LocalDateFormatter()
    }
    
    // MARK: - Streak Methods
    
    /// Update streak after a habit is marked complete
    ///
    /// Logic:
    /// - If last completion was yesterday → increment streak
    /// - If last completion was today → no change (already counted)
    /// - If last completion was >1 day ago → reset to 1
    /// - If no last completion → start at 1
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date of completion
    ///   - completed: Whether the habit was completed (true) or uncompleted (false)
    func updateStreak(habitId: String, on date: Date, completed: Bool) async throws {
        let localDateString = dateFormatter.dateToString(date)
        
        print("📈 StreakService: Updating streak for habit \(habitId) on \(localDateString)")
        
        do {
            // Delegate to repository
            try await repository.updateStreak(habitId: habitId, localDate: localDateString, completed: completed)
            
            // Refresh streak from repository
            // In production, this would come from real-time listener
            print("✅ StreakService: Streak updated for habit \(habitId)")
            
        } catch {
            print("❌ StreakService: Failed to update streak: \(error)")
            self.error = .updateFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Calculate and update streak based on completion status
    ///
    /// This is the main logic that determines streak continuation vs reset.
    ///
    /// - Parameters:
    ///   - habitId: The habit identifier
    ///   - date: The date of the completion
    ///   - isComplete: Whether the goal was reached on this date
    func calculateStreak(habitId: String, date: Date, isComplete: Bool) async throws {
        let localDateString = dateFormatter.dateToString(date)
        
        // Get current streak data
        let currentStreak = streaks[habitId] ?? Streak(
            habitId: habitId,
            current: 0,
            longest: 0,
            lastCompletionDate: nil,
            updatedAt: Date()
        )
        
        guard isComplete else {
            // If not complete, don't update streak
            print("ℹ️ StreakService: Habit \(habitId) not complete on \(localDateString), no streak update")
            return
        }
        
        let newCurrent: Int
        let yesterday = dateFormatter.addDays(-1, to: localDateString)
        
        if let lastCompletionDate = currentStreak.lastCompletionDate {
            if lastCompletionDate == yesterday {
                // Consecutive day → increment
                newCurrent = currentStreak.current + 1
                print("📈 StreakService: Consecutive day detected, streak: \(currentStreak.current) → \(newCurrent)")
            } else if lastCompletionDate == localDateString {
                // Same day → no change
                newCurrent = currentStreak.current
                print("ℹ️ StreakService: Same day completion, streak unchanged: \(newCurrent)")
            } else {
                // Gap detected → reset to 1
                newCurrent = 1
                print("⚠️ StreakService: Streak broken for \(habitId), resetting to 1")
            }
        } else {
            // First completion ever
            newCurrent = 1
            print("🎉 StreakService: First completion for \(habitId), streak: 1")
        }
        
        let newLongest = max(currentStreak.longest, newCurrent)
        
        // Update streak in repository
        try await updateStreak(habitId: habitId, on: date, completed: true)
        
        // Update local cache
        streaks[habitId] = Streak(
            habitId: habitId,
            current: newCurrent,
            longest: newLongest,
            lastCompletionDate: localDateString,
            updatedAt: Date()
        )
        
        print("✅ StreakService: Updated streak - Current: \(newCurrent), Longest: \(newLongest)")
    }
    
    /// Get current streak for a habit
    ///
    /// - Parameter habitId: The habit identifier
    /// - Returns: Current streak count
    func getCurrentStreak(habitId: String) async throws -> Int {
        // Check cache first
        if let cached = streaks[habitId] {
            return cached.current
        }
        
        // Fetch from repository
        // In production, this would query Firestore
        return 0
    }
    
    /// Get longest streak for a habit
    ///
    /// - Parameter habitId: The habit identifier
    /// - Returns: Longest streak count
    func getLongestStreak(habitId: String) async throws -> Int {
        // Check cache first
        if let cached = streaks[habitId] {
            return cached.longest
        }
        
        // Fetch from repository
        return 0
    }
    
    /// Reset streak for a habit (e.g., after deletion or user request)
    ///
    /// - Parameter habitId: The habit identifier
    func resetStreak(habitId: String) async throws {
        print("🔄 StreakService: Resetting streak for habit \(habitId)")
        
        // Update in repository with 0 values
        let today = dateFormatter.today()
        try await repository.updateStreak(habitId: habitId, localDate: today, completed: false)
        
        // Update cache
        streaks[habitId] = Streak(
            habitId: habitId,
            current: 0,
            longest: 0,
            lastCompletionDate: nil,
            updatedAt: Date()
        )
        
        print("✅ StreakService: Streak reset for habit \(habitId)")
    }
    
    // MARK: - All Habits Complete Logic
    
    /// Check if all active habits are complete for a given date
    ///
    /// This is used for "daily streak" logic where XP is only awarded
    /// when ALL habits for the day are completed.
    ///
    /// - Parameters:
    ///   - habits: Array of active habits for the date
    ///   - date: The date to check
    ///
    /// - Returns: True if all habits are complete
    func areAllHabitsComplete(habits: [String], on date: Date, goals: [String: Int]) async throws -> Bool {
        guard !habits.isEmpty else {
            print("ℹ️ StreakService: No habits to check")
            return false
        }
        
        print("🔍 StreakService: Checking if all \(habits.count) habits complete on \(dateFormatter.dateToString(date))")
        
        for habitId in habits {
            let goal = goals[habitId] ?? 1
            let count = try await completionService.getCompletion(habitId: habitId, on: date)
            
            if count < goal {
                print("ℹ️ StreakService: Habit \(habitId) not complete (\(count)/\(goal))")
                return false
            }
        }
        
        print("✅ StreakService: All \(habits.count) habits complete!")
        return true
    }
    
    /// Update overall daily streak (when all habits are complete)
    ///
    /// This maintains a special "all" streak that tracks consecutive days
    /// where ALL active habits were completed.
    ///
    /// - Parameter date: The date to update
    func updateDailyStreak(on date: Date) async throws {
        let localDateString = dateFormatter.dateToString(date)
        
        print("📈 StreakService: Updating daily streak for \(localDateString)")
        
        // Update special "all" streak
        try await updateStreak(habitId: "all", on: date, completed: true)
        
        print("✅ StreakService: Daily streak updated")
    }
    
    // MARK: - Real-time Updates
    
    /// Start streaming today's completions for UI updates
    private func startTodayCompletionsStream() {
        let today = dateFormatter.today()
        print("👂 StreakService: Starting completions stream for \(today)")
        
        // In production, subscribe to repository.completions publisher
        // For now, set up the structure
    }
    
    /// Refresh all streaks from repository
    func refreshStreaks() async {
        print("🔄 StreakService: Refreshing all streaks")
        
        // In production with real Firestore, this would come from real-time listeners
        // For mock mode, update from repository state
        streaks = repository.streaks
    }
}

// MARK: - Errors

enum StreakError: LocalizedError {
    case updateFailed(String)
    case calculationFailed(String)
    case invalidDate(String)
    
    var errorDescription: String? {
        switch self {
        case .updateFailed(let message):
            return "Failed to update streak: \(message)"
        case .calculationFailed(let message):
            return "Failed to calculate streak: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        }
    }
}
