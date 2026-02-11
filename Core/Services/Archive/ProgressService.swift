import Foundation
import SwiftData

/// Service for managing daily habit progress
/// **Responsibilities:**
/// - Track progress for habits on specific dates
/// - Increment/decrement progress with timestamps
/// - Determine completion status
/// - Coordinate with XP and Streak services
@MainActor
class ProgressService {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("✅ ProgressService: Initialized")
    }
    
    // MARK: - Progress Management
    
    /// Get or create progress record for a habit on a specific date
    /// **Returns:** DailyProgressModel for the given habit and date
    /// **Creates new record if none exists**
    func getOrCreateProgress(
        for habit: HabitModel,
        on date: Date
    ) throws -> DailyProgressModel {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        // Try to find existing progress
        if let existing = try findProgress(for: habit, on: normalizedDate) {
            print("📊 ProgressService: Found existing progress for '\(habit.name)' on \(dateKey)")
            return existing
        }
        
        // Create new progress record
        let progress = DailyProgressModel(
            date: normalizedDate,
            habit: habit,
            progressCount: 0,
            goalCount: habit.goalCount
        )
        
        modelContext.insert(progress)
        
        print("✨ ProgressService: Created new progress for '\(habit.name)' on \(dateKey)")
        return progress
    }
    
    /// Find existing progress record for a habit on a date
    /// **Returns:** DailyProgressModel if found, nil otherwise
    private func findProgress(
        for habit: HabitModel,
        on date: Date
    ) throws -> DailyProgressModel? {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        // Fetch all progress records for this date
        let descriptor = FetchDescriptor<DailyProgressModel>(
            predicate: #Predicate { progress in
                progress.dateString == dateKey
            }
        )
        
        let allProgressForDate = try modelContext.fetch(descriptor)
        
        // Filter by habit ID (to avoid optional relationship predicate issues)
        return allProgressForDate.first { progress in
            progress.habit?.id == habit.id
        }
    }
    
    // MARK: - Increment/Decrement
    
    /// Increment progress for a habit on a date
    /// **Side effects:**
    /// - Adds timestamp
    /// - Updates completion status
    /// - May trigger XP award (via delegate)
    /// - May trigger streak update (via delegate)
    @discardableResult
    func incrementProgress(
        for habit: HabitModel,
        on date: Date,
        at timestamp: Date = Date()
    ) throws -> IncrementResult {
        let progress = try getOrCreateProgress(for: habit, on: date)
        
        let wasComplete = progress.isComplete
        let oldProgress = progress.progressCount
        
        // Increment progress
        progress.increment(at: timestamp)
        
        let newProgress = progress.progressCount
        let isNowComplete = progress.isComplete
        
        // Save changes
        try modelContext.save()
        
        let dateKey = DateUtils.dateKey(for: date)
        print("➕ ProgressService: '\(habit.name)' \(oldProgress) → \(newProgress) on \(dateKey)")
        
        // Determine result type
        let completionChanged = !wasComplete && isNowComplete
        
        return IncrementResult(
            habit: habit,
            date: date,
            oldProgress: oldProgress,
            newProgress: newProgress,
            wasComplete: wasComplete,
            isNowComplete: isNowComplete,
            completionChanged: completionChanged
        )
    }
    
    /// Decrement progress for a habit on a date
    /// **Side effects:**
    /// - Removes last timestamp
    /// - Updates completion status
    /// - May trigger XP removal (via delegate)
    /// - May trigger streak break (via delegate)
    @discardableResult
    func decrementProgress(
        for habit: HabitModel,
        on date: Date
    ) throws -> DecrementResult {
        let progress = try getOrCreateProgress(for: habit, on: date)
        
        let wasComplete = progress.isComplete
        let oldProgress = progress.progressCount
        
        guard oldProgress > 0 else {
            print("⚠️ ProgressService: Cannot decrement - already at 0")
            throw ProgressError.alreadyAtZero
        }
        
        // Decrement progress
        progress.decrement()
        
        let newProgress = progress.progressCount
        let isNowComplete = progress.isComplete
        
        // Save changes
        try modelContext.save()
        
        let dateKey = DateUtils.dateKey(for: date)
        print("➖ ProgressService: '\(habit.name)' \(oldProgress) → \(newProgress) on \(dateKey)")
        
        // Determine result type
        let completionChanged = wasComplete && !isNowComplete
        
        return DecrementResult(
            habit: habit,
            date: date,
            oldProgress: oldProgress,
            newProgress: newProgress,
            wasComplete: wasComplete,
            isNowComplete: isNowComplete,
            completionChanged: completionChanged
        )
    }
    
    // MARK: - Queries
    
    /// Get progress for a specific habit on a date
    /// **Returns:** DailyProgressModel if exists, nil otherwise
    func getProgress(
        for habit: HabitModel,
        on date: Date
    ) throws -> DailyProgressModel? {
        let normalizedDate = DateUtils.startOfDay(for: date)
        return try findProgress(for: habit, on: normalizedDate)
    }
    
    /// Check if habit is complete on a date
    /// **Returns:** true if complete, false otherwise
    func isComplete(
        habit: HabitModel,
        on date: Date
    ) throws -> Bool {
        guard let progress = try getProgress(for: habit, on: date) else {
            return false
        }
        return progress.isComplete
    }
    
    /// Get all progress records for a date
    /// **Returns:** Array of DailyProgressModel for the given date
    func getAllProgress(
        on date: Date
    ) throws -> [DailyProgressModel] {
        let normalizedDate = DateUtils.startOfDay(for: date)
        let dateKey = DateUtils.dateKey(for: normalizedDate)
        
        let descriptor = FetchDescriptor<DailyProgressModel>(
            predicate: #Predicate { progress in
                progress.dateString == dateKey
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Get all progress records for a habit within a date range
    /// **Returns:** Array of DailyProgressModel sorted by date
    func getProgressHistory(
        for habit: HabitModel,
        from startDate: Date,
        to endDate: Date
    ) throws -> [DailyProgressModel] {
        let normalizedStart = DateUtils.startOfDay(for: startDate)
        let normalizedEnd = DateUtils.startOfDay(for: endDate)
        
        // Fetch all progress in date range
        let descriptor = FetchDescriptor<DailyProgressModel>(
            predicate: #Predicate { progress in
                progress.date >= normalizedStart && progress.date <= normalizedEnd
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        let allProgress = try modelContext.fetch(descriptor)
        
        // Filter by habit ID
        return allProgress.filter { progress in
            progress.habit?.id == habit.id
        }
    }
    
    // MARK: - Batch Operations
    
    /// Reset progress for a habit on a date to zero
    /// **Warning:** This removes all timestamps and resets count to 0
    func resetProgress(
        for habit: HabitModel,
        on date: Date
    ) throws {
        guard let progress = try getProgress(for: habit, on: date) else {
            print("ℹ️ ProgressService: No progress to reset")
            return
        }
        
        progress.reset()
        try modelContext.save()
        
        let dateKey = DateUtils.dateKey(for: date)
        print("🔄 ProgressService: Reset progress for '\(habit.name)' on \(dateKey)")
    }
    
    /// Set difficulty rating for a habit on a date
    func setDifficulty(
        _ difficulty: Int,
        for habit: HabitModel,
        on date: Date
    ) throws {
        let progress = try getOrCreateProgress(for: habit, on: date)
        
        guard (1...5).contains(difficulty) else {
            throw ProgressError.invalidDifficulty(difficulty)
        }
        
        progress.setDifficulty(difficulty)
        try modelContext.save()
        
        let dateKey = DateUtils.dateKey(for: date)
        print("📊 ProgressService: Set difficulty \(difficulty) for '\(habit.name)' on \(dateKey)")
    }
    
    // MARK: - Analytics Helpers
    
    /// Get completion percentage for a habit on a date
    func getCompletionPercentage(
        for habit: HabitModel,
        on date: Date
    ) throws -> Double {
        guard let progress = try getProgress(for: habit, on: date) else {
            return 0.0
        }
        return progress.completionPercentage
    }
    
    /// Count how many days a habit was completed in a date range
    func countCompletedDays(
        for habit: HabitModel,
        from startDate: Date,
        to endDate: Date
    ) throws -> Int {
        let history = try getProgressHistory(for: habit, from: startDate, to: endDate)
        return history.filter { $0.isComplete }.count
    }
}

// MARK: - Result Types

/// Result of incrementing progress
struct IncrementResult {
    let habit: HabitModel
    let date: Date
    let oldProgress: Int
    let newProgress: Int
    let wasComplete: Bool
    let isNowComplete: Bool
    
    /// Did this increment change the completion status from incomplete → complete?
    let completionChanged: Bool
    
    /// User-friendly description
    var description: String {
        let dateKey = DateUtils.dateKey(for: date)
        if completionChanged {
            return "✅ '\(habit.name)' completed on \(dateKey) (\(oldProgress)→\(newProgress))"
        } else {
            return "➕ '\(habit.name)' progress on \(dateKey) (\(oldProgress)→\(newProgress))"
        }
    }
}

/// Result of decrementing progress
struct DecrementResult {
    let habit: HabitModel
    let date: Date
    let oldProgress: Int
    let newProgress: Int
    let wasComplete: Bool
    let isNowComplete: Bool
    
    /// Did this decrement change the completion status from complete → incomplete?
    let completionChanged: Bool
    
    /// User-friendly description
    var description: String {
        let dateKey = DateUtils.dateKey(for: date)
        if completionChanged {
            return "❌ '\(habit.name)' unmarked on \(dateKey) (\(oldProgress)→\(newProgress))"
        } else {
            return "➖ '\(habit.name)' progress on \(dateKey) (\(oldProgress)→\(newProgress))"
        }
    }
}

// MARK: - Errors

enum ProgressError: LocalizedError {
    case habitNotFound
    case alreadyAtZero
    case invalidDifficulty(Int)
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .habitNotFound:
            return "Habit not found"
        case .alreadyAtZero:
            return "Progress is already at zero"
        case .invalidDifficulty(let value):
            return "Invalid difficulty rating: \(value). Must be 1-5."
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

