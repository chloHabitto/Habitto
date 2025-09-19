import Foundation
import OSLog

// MARK: - History Capper
/// Utility for capping history data to prevent unlimited growth
final class HistoryCapper {
    static let shared = HistoryCapper()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "HistoryCapper")
    
    private init() {}
    
    // MARK: - History Capping Methods
    
    /// Caps completion history to a maximum number of entries
    /// - Parameters:
    ///   - history: The completion history dictionary
    ///   - maxEntries: Maximum number of entries to keep
    /// - Returns: Capped completion history
    func capCompletionHistory(_ history: [String: Int], maxEntries: Int = 1000) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        logger.debug("Capping completion history from \(history.count) to \(maxEntries) entries")
        
        // Sort by date (newest first) and keep only the most recent entries
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        let cappedEntries = Array(sortedEntries.prefix(maxEntries))
        let result = Dictionary(uniqueKeysWithValues: cappedEntries)
        
        logger.debug("Capped completion history: removed \(history.count - result.count) entries")
        return result
    }
    
    /// Caps difficulty history to a maximum number of entries
    /// - Parameters:
    ///   - history: The difficulty history dictionary
    ///   - maxEntries: Maximum number of entries to keep
    /// - Returns: Capped difficulty history
    func capDifficultyHistory(_ history: [String: Int], maxEntries: Int = 500) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        logger.debug("Capping difficulty history from \(history.count) to \(maxEntries) entries")
        
        // Sort by date (newest first) and keep only the most recent entries
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        let cappedEntries = Array(sortedEntries.prefix(maxEntries))
        let result = Dictionary(uniqueKeysWithValues: cappedEntries)
        
        logger.debug("Capped difficulty history: removed \(history.count - result.count) entries")
        return result
    }
    
    /// Caps usage history to a maximum number of entries
    /// - Parameters:
    ///   - history: The usage history dictionary
    ///   - maxEntries: Maximum number of entries to keep
    /// - Returns: Capped usage history
    func capUsageHistory(_ history: [String: Int], maxEntries: Int = 500) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        logger.debug("Capping usage history from \(history.count) to \(maxEntries) entries")
        
        // Sort by date (newest first) and keep only the most recent entries
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        let cappedEntries = Array(sortedEntries.prefix(maxEntries))
        let result = Dictionary(uniqueKeysWithValues: cappedEntries)
        
        logger.debug("Capped usage history: removed \(history.count - result.count) entries")
        return result
    }
    
    /// Caps notes to a maximum number of entries
    /// - Parameters:
    ///   - notes: The notes array
    ///   - maxEntries: Maximum number of entries to keep
    /// - Returns: Capped notes array
    func capNotes(_ notes: [String], maxEntries: Int = 100) -> [String] {
        guard notes.count > maxEntries else { return notes }
        
        logger.debug("Capping notes from \(notes.count) to \(maxEntries) entries")
        
        // Keep only the most recent notes (assuming they're in chronological order)
        let result = Array(notes.suffix(maxEntries))
        
        logger.debug("Capped notes: removed \(notes.count - result.count) entries")
        return result
    }
    
    // MARK: - Comprehensive Capping
    
    /// Caps all history data for a habit
    /// - Parameters:
    ///   - habit: The habit to cap history for
    ///   - policy: The retention policy to use
    /// - Returns: Updated habit with capped history
    func capHabitHistory(_ habit: Habit, using policy: DataRetentionPolicy) -> Habit {
        var updatedHabit = habit
        
        // Cap completion history
        updatedHabit.completionHistory = capCompletionHistory(
            updatedHabit.completionHistory,
            maxEntries: policy.completionHistoryDays
        )
        
        // Cap difficulty history
        updatedHabit.difficultyHistory = capDifficultyHistory(
            updatedHabit.difficultyHistory,
            maxEntries: policy.difficultyHistoryDays
        )
        
        // Cap usage history
        updatedHabit.actualUsage = capUsageHistory(
            updatedHabit.actualUsage,
            maxEntries: policy.usageHistoryDays
        )
        
        // Cap notes if they exist (placeholder for future implementation)
        // TODO: Implement notes capping when Habit model supports notes
        
        logger.debug("Capped history for habit: \(habit.name)")
        return updatedHabit
    }
    
    /// Caps all habits in a collection
    /// - Parameters:
    ///   - habits: Array of habits to cap
    ///   - policy: The retention policy to use
    /// - Returns: Array of habits with capped history
    func capAllHabits(_ habits: [Habit], using policy: DataRetentionPolicy) -> [Habit] {
        logger.info("Capping history for \(habits.count) habits")
        
        let cappedHabits = habits.map { habit in
            capHabitHistory(habit, using: policy)
        }
        
        logger.info("History capping completed for \(habits.count) habits")
        return cappedHabits
    }
    
    // MARK: - Smart Capping
    
    /// Intelligently caps history based on data patterns
    /// - Parameters:
    ///   - habit: The habit to cap
    ///   - policy: The retention policy to use
    /// - Returns: Updated habit with intelligently capped history
    func smartCapHabitHistory(_ habit: Habit, using policy: DataRetentionPolicy) -> Habit {
        var updatedHabit = habit
        
        // Smart cap completion history - keep more recent data, less older data
        updatedHabit.completionHistory = smartCapCompletionHistory(
            updatedHabit.completionHistory,
            maxEntries: policy.completionHistoryDays
        )
        
        // Smart cap difficulty history
        updatedHabit.difficultyHistory = smartCapDifficultyHistory(
            updatedHabit.difficultyHistory,
            maxEntries: policy.difficultyHistoryDays
        )
        
        // Smart cap usage history
        updatedHabit.actualUsage = smartCapUsageHistory(
            updatedHabit.actualUsage,
            maxEntries: policy.usageHistoryDays
        )
        
        logger.debug("Smart capped history for habit: \(habit.name)")
        return updatedHabit
    }
    
    /// Smart caps completion history with weighted retention
    private func smartCapCompletionHistory(_ history: [String: Int], maxEntries: Int) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        // Keep more recent entries (first 70% of maxEntries)
        let recentCount = Int(Double(maxEntries) * 0.7)
        let olderCount = maxEntries - recentCount
        
        let recentEntries = Array(sortedEntries.prefix(recentCount))
        let olderEntries = Array(sortedEntries.dropFirst(recentCount).prefix(olderCount))
        
        let result = Dictionary(uniqueKeysWithValues: recentEntries + olderEntries)
        
        logger.debug("Smart capped completion history: kept \(result.count) entries")
        return result
    }
    
    /// Smart caps difficulty history with weighted retention
    private func smartCapDifficultyHistory(_ history: [String: Int], maxEntries: Int) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        // Keep more recent entries (first 80% of maxEntries)
        let recentCount = Int(Double(maxEntries) * 0.8)
        let olderCount = maxEntries - recentCount
        
        let recentEntries = Array(sortedEntries.prefix(recentCount))
        let olderEntries = Array(sortedEntries.dropFirst(recentCount).prefix(olderCount))
        
        let result = Dictionary(uniqueKeysWithValues: recentEntries + olderEntries)
        
        logger.debug("Smart capped difficulty history: kept \(result.count) entries")
        return result
    }
    
    /// Smart caps usage history with weighted retention
    private func smartCapUsageHistory(_ history: [String: Int], maxEntries: Int) -> [String: Int] {
        guard history.count > maxEntries else { return history }
        
        let sortedEntries = history.sorted { (entry1, entry2) in
            guard let date1 = ISO8601DateHelper.shared.date(from: entry1.key),
                  let date2 = ISO8601DateHelper.shared.date(from: entry2.key) else {
                return false
            }
            return date1 > date2
        }
        
        // Keep more recent entries (first 90% of maxEntries)
        let recentCount = Int(Double(maxEntries) * 0.9)
        let olderCount = maxEntries - recentCount
        
        let recentEntries = Array(sortedEntries.prefix(recentCount))
        let olderEntries = Array(sortedEntries.dropFirst(recentCount).prefix(olderCount))
        
        let result = Dictionary(uniqueKeysWithValues: recentEntries + olderEntries)
        
        logger.debug("Smart capped usage history: kept \(result.count) entries")
        return result
    }
}

// MARK: - History Capper Extensions
extension HistoryCapper {
    /// Gets the current data size for a habit
    func getHabitDataSize(_ habit: Habit) -> DataSizeInfo {
        let completionSize = estimateDictionarySize(habit.completionHistory)
        let difficultySize = estimateDictionarySize(habit.difficultyHistory)
        let usageSize = estimateDictionarySize(habit.actualUsage)
        let notesSize = 0 // TODO: Calculate notes size when Habit model supports notes
        
        return DataSizeInfo(
            completionHistoryBytes: completionSize,
            difficultyHistoryBytes: difficultySize,
            usageHistoryBytes: usageSize,
            notesBytes: notesSize,
            totalBytes: completionSize + difficultySize + usageSize + notesSize
        )
    }
    
    /// Estimates the size of a dictionary in bytes
    private func estimateDictionarySize(_ dictionary: [String: Int]) -> Int {
        var totalSize = 0
        for (key, _) in dictionary {
            totalSize += key.utf8.count + MemoryLayout<Int>.size
        }
        return totalSize
    }
}

// MARK: - Data Size Info
/// Information about data size for a habit
struct DataSizeInfo {
    let completionHistoryBytes: Int
    let difficultyHistoryBytes: Int
    let usageHistoryBytes: Int
    let notesBytes: Int
    let totalBytes: Int
    
    var totalKB: Double {
        return Double(totalBytes) / 1024.0
    }
    
    var totalMB: Double {
        return totalKB / 1024.0
    }
    
    var description: String {
        if totalMB >= 1.0 {
            return String(format: "%.2f MB", totalMB)
        } else {
            return String(format: "%.2f KB", totalKB)
        }
    }
}
