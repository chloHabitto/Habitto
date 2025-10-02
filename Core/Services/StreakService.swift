import Foundation
import SwiftData
import OSLog

// MARK: - Streak Service
/// Pure functions that compute streak from DailyAward sequence
@MainActor
final class StreakService {
    static let shared = StreakService()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "StreakService")
    
    private init() {}
    
    // MARK: - User-Level Streak Computation
    
    /// Computes user's overall streak from consecutive DailyAward records
    /// This is the authoritative streak calculation for the user
    func computeUserStreak(userId: String, context: ModelContext) async throws -> Int {
        logger.debug("StreakService: Computing user streak for \(userId)")
        
        // Get all daily awards for the user, sorted by date
        let request = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId && $0.allHabitsCompleted == true }
        )
        
        let dailyAwards = try context.fetch(request)
            .sorted { $0.dateKey < $1.dateKey }
        
        // Calculate consecutive streak from most recent backwards
        let streak = computeConsecutiveStreak(from: dailyAwards)
        
        logger.debug("StreakService: User streak computed: \(streak)")
        return streak
    }
    
    /// Computes streak for a specific habit from completion records
    func computeHabitStreak(userId: String, habitId: UUID, context: ModelContext) async throws -> Int {
        logger.debug("StreakService: Computing habit streak for habit \(habitId)")
        
        // Get all completion records for the habit, sorted by date
        let request = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.userId == userId && $0.habitId == habitId && $0.isCompleted == true }
        )
        
        let completions = try context.fetch(request)
            .sorted { $0.date < $1.date }
        
        // Calculate consecutive streak from most recent backwards
        let streak = computeConsecutiveStreakFromCompletions(from: completions)
        
        logger.debug("StreakService: Habit streak computed: \(streak)")
        return streak
    }
    
    /// Computes the longest streak for a user
    func computeLongestStreak(userId: String, context: ModelContext) async throws -> Int {
        logger.debug("StreakService: Computing longest streak for \(userId)")
        
        // Get all daily awards for the user, sorted by date
        let request = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId && $0.allHabitsCompleted == true }
        )
        
        let dailyAwards = try context.fetch(request)
            .sorted { $0.dateKey < $1.dateKey }
        
        // Find the longest consecutive sequence
        let longestStreak = findLongestConsecutiveSequence(from: dailyAwards)
        
        logger.debug("StreakService: Longest streak computed: \(longestStreak)")
        return longestStreak
    }
    
    // MARK: - Private Helper Methods
    
    private func computeConsecutiveStreak(from dailyAwards: [DailyAward]) -> Int {
        guard !dailyAwards.isEmpty else { return 0 }
        
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        // Create a set of date keys for O(1) lookup
        let dateKeySet = Set(dailyAwards.map { $0.dateKey })
        
        // Go backwards day by day
        while true {
            let dateKey = DateKey.key(for: currentDate)
            
            if dateKeySet.contains(dateKey) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func computeConsecutiveStreakFromCompletions(from completions: [CompletionRecord]) -> Int {
        guard !completions.isEmpty else { return 0 }
        
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        // Create a set of date keys for O(1) lookup
        let dateKeySet = Set(completions.map { $0.dateKey })
        
        // Go backwards day by day
        while true {
            let dateKey = DateKey.key(for: currentDate)
            
            if dateKeySet.contains(dateKey) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func findLongestConsecutiveSequence(from dailyAwards: [DailyAward]) -> Int {
        guard !dailyAwards.isEmpty else { return 0 }
        
        var longestStreak = 0
        var currentStreak = 0
        let calendar = Calendar.current
        
        // Sort by date key to process chronologically
        let sortedAwards = dailyAwards.sorted { $0.dateKey < $1.dateKey }
        
        for (index, award) in sortedAwards.enumerated() {
            if index == 0 {
                currentStreak = 1
            } else {
                let previousDateKey = sortedAwards[index - 1].dateKey
                let currentDateKey = award.dateKey
                
                // Check if this award is consecutive to the previous one
                if isConsecutiveDay(previousDateKey: previousDateKey, currentDateKey: currentDateKey) {
                    currentStreak += 1
                } else {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            }
        }
        
        longestStreak = max(longestStreak, currentStreak)
        return longestStreak
    }
    
    private func isConsecutiveDay(previousDateKey: String, currentDateKey: String) -> Bool {
        // Parse date keys (assuming format "yyyy-MM-dd")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let previousDate = dateFormatter.date(from: previousDateKey),
              let currentDate = dateFormatter.date(from: currentDateKey) else {
            return false
        }
        
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDate) ?? previousDate
        
        return calendar.isDate(nextDay, inSameDayAs: currentDate)
    }
}

// MARK: - Streak Statistics
extension StreakService {
    
    /// Computes comprehensive streak statistics for a user
    func computeStreakStatistics(userId: String, context: ModelContext) async throws -> StreakStatistics {
        logger.debug("StreakService: Computing streak statistics for \(userId)")
        
        let currentStreak = try await computeUserStreak(userId: userId, context: context)
        let longestStreak = try await computeLongestStreak(userId: userId, context: context)
        
        // Get total completion days
        let request = FetchDescriptor<DailyAward>(
            predicate: #Predicate { $0.userId == userId && $0.allHabitsCompleted == true }
        )
        let totalCompletionDays = try context.fetch(request).count
        
        return StreakStatistics(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCompletionDays: totalCompletionDays
        )
    }
}

// MARK: - Streak Statistics Model
struct StreakStatistics {
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletionDays: Int
    
    var streakPercentage: Double {
        guard totalCompletionDays > 0 else { return 0.0 }
        return Double(currentStreak) / Double(totalCompletionDays)
    }
}
