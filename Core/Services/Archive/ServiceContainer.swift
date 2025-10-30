import SwiftData
import Foundation

/// Central container for managing service instances
///
/// **Usage:**
/// ```swift
/// let container = try ServiceContainer(userId: currentUserId)
/// let result = try container.completeHabit(habit, on: today)
/// ```
///
/// **Architecture:**
/// - Creates and manages all service instances
/// - Handles service dependencies
/// - Provides high-level orchestration methods
/// - Manages SwiftData ModelContext lifecycle
@MainActor
final class ServiceContainer {
    // MARK: - Services
    
    /// Service for managing daily progress
    let progress: ProgressService
    
    /// Service for managing global streak
    let streak: StreakService
    
    /// Service for managing XP and leveling
    let xp: XPService
    
    /// Service for habit CRUD operations
    let habit: HabitService
    
    // MARK: - Properties
    
    /// Current user ID
    let userId: String
    
    /// SwiftData model context
    private let modelContext: ModelContext
    
    /// SwiftData model container
    private let modelContainer: ModelContainer
    
    // MARK: - Initialization
    
    /// Initialize service container for a user
    /// - Parameter userId: The user ID to initialize services for
    /// - Throws: If ModelContainer creation fails
    init(userId: String) throws {
        self.userId = userId
        
        print("🔧 ServiceContainer: Initializing for user '\(userId)'...")
        
        // Create SwiftData schema
        let schema = Schema([
            HabitModel.self,
            DailyProgressModel.self,
            GlobalStreakModel.self,
            UserProgressModel.self,
            XPTransactionModel.self,
            AchievementModel.self,
            ReminderModel.self
        ])
        
        // Create ModelContainer
        // TODO: Use user-specific container for multi-user support
        // For now, use shared container with user ID filtering
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        self.modelContainer = try ModelContainer(for: schema, configurations: configuration)
        self.modelContext = ModelContext(modelContainer)
        
        // Disable autosave - we'll control saves explicitly
        self.modelContext.autosaveEnabled = false
        
        print("  ✅ ModelContainer created")
        
        // Initialize services with proper dependencies
        // Order matters - dependencies must be created first
        
        self.progress = ProgressService(modelContext: modelContext)
        print("  ✅ ProgressService initialized")
        
        self.xp = XPService(modelContext: modelContext)
        print("  ✅ XPService initialized")
        
        self.streak = StreakService(
            modelContext: modelContext,
            progressService: progress
        )
        print("  ✅ StreakService initialized (depends on ProgressService)")
        
        self.habit = HabitService(modelContext: modelContext)
        print("  ✅ HabitService initialized")
        
        print("✅ ServiceContainer: Fully initialized for user '\(userId)'")
    }
    
    // MARK: - High-Level Operations
    
    /// Complete a habit with full workflow
    ///
    /// **What it does:**
    /// 1. Increments progress for the habit
    /// 2. If habit becomes complete, checks if ALL habits are complete
    /// 3. If all complete, awards XP and updates streak
    ///
    /// **Example:**
    /// ```swift
    /// let result = try container.completeHabit(habit, on: Date())
    /// if result.xpAwarded > 0 {
    ///     print("🎉 Earned \(result.xpAwarded) XP!")
    /// }
    /// ```
    func completeHabit(_ habit: HabitModel, on date: Date) throws -> CompletionResult {
        let dateKey = DateUtils.dateKey(for: date)
        print("📝 ServiceContainer: Completing '\(habit.name)' on \(dateKey)")
        
        // 1. Increment progress
        let progressResult = try progress.incrementProgress(for: habit, on: date)
        print("  ✅ Progress: \(progressResult.newProgress) (was \(progressResult.oldProgress))")
        
        var xpAwarded = 0
        var streakUpdated = false
        var allHabitsComplete = false
        
        // 2. If completion status changed, check for rewards
        if progressResult.completionChanged && progressResult.isNowComplete {
            print("  🎯 Habit became complete!")
            
            // Get all habits for this user
            let allHabits = try self.habit.getActiveHabits(for: userId, on: date)
            print("  📋 Checking \(allHabits.count) active habits...")
            
            // Check if ALL habits complete for this day
            allHabitsComplete = try streak.areAllHabitsComplete(
                on: date,
                habits: allHabits
            )
            
            if allHabitsComplete {
                print("  🎉 ALL HABITS COMPLETE!")
                
                // Award XP
                xpAwarded = try xp.awardDailyCompletion(
                    for: userId,
                    on: date,
                    habits: allHabits
                )
                print("  ⭐ Awarded \(xpAwarded) XP")
                
                // Update streak
                try streak.updateStreakIfNeeded(
                    on: date,
                    habits: allHabits,
                    userId: userId
                )
                streakUpdated = true
                print("  🔥 Streak updated")
            } else {
                print("  ⏸️ Not all habits complete yet - no XP/streak update")
            }
        } else {
            print("  ℹ️ Completion status unchanged")
        }
        
        // Save context
        try save()
        
        return CompletionResult(
            progressResult: progressResult,
            xpAwarded: xpAwarded,
            streakUpdated: streakUpdated,
            allHabitsComplete: allHabitsComplete
        )
    }
    
    /// Uncomplete a habit with full workflow
    ///
    /// **What it does:**
    /// 1. Decrements progress for the habit
    /// 2. If day becomes incomplete, removes XP and recalculates streak
    ///
    /// **Example:**
    /// ```swift
    /// let result = try container.uncompleteHabit(habit, on: Date())
    /// if result.xpRemoved > 0 {
    ///     print("⬇️ Lost \(result.xpRemoved) XP")
    /// }
    /// ```
    func uncompleteHabit(_ habit: HabitModel, on date: Date) throws -> UncompletionResult {
        let dateKey = DateUtils.dateKey(for: date)
        print("📝 ServiceContainer: Uncompleting '\(habit.name)' on \(dateKey)")
        
        // 1. Check if day was complete BEFORE decrement
        let allHabits = try self.habit.getActiveHabits(for: userId, on: date)
        let wasComplete = try streak.areAllHabitsComplete(on: date, habits: allHabits)
        
        // 2. Decrement progress
        let progressResult = try progress.decrementProgress(for: habit, on: date)
        print("  ✅ Progress: \(progressResult.newProgress) (was \(progressResult.oldProgress))")
        
        var xpRemoved = 0
        var streakBroken = false
        
        // 3. If day was complete and is now incomplete, handle XP reversal
        if wasComplete && progressResult.completionChanged && !progressResult.isNowComplete {
            print("  💔 Day became incomplete!")
            
            // Remove XP
            xpRemoved = try xp.removeDailyCompletion(for: userId, on: date)
            print("  ❌ Removed \(xpRemoved) XP")
            
            // Recalculate streak from scratch
            print("  🔄 Recalculating streak...")
            try streak.recalculateStreak(for: userId, habits: allHabits)
            streakBroken = true
            print("  🔥 Streak recalculated")
        } else {
            print("  ℹ️ Day still complete or was already incomplete - no XP/streak change")
        }
        
        // Save context
        try save()
        
        return UncompletionResult(
            progressResult: progressResult,
            xpRemoved: xpRemoved,
            streakBroken: streakBroken
        )
    }
    
    /// Get dashboard stats for the user
    ///
    /// **Returns:**
    /// - Current streak
    /// - Total XP
    /// - Current level
    /// - Active habits count
    func getDashboardStats(on date: Date = Date()) throws -> DashboardStats {
        let allHabits = try habit.getActiveHabits(for: userId, on: date)
        let streakStats = try streak.getStreakStats(for: userId)
        let xpStats = try xp.getUserStats(for: userId)
        
        // Count completed habits today
        var completedToday = 0
        for h in allHabits {
            if try progress.isComplete(habit: h, on: date) {
                completedToday += 1
            }
        }
        
        return DashboardStats(
            currentStreak: streakStats.currentStreak,
            longestStreak: streakStats.longestStreak,
            totalXP: xpStats.totalXP,
            currentLevel: xpStats.currentLevel,
            activeHabitsCount: allHabits.count,
            completedTodayCount: completedToday
        )
    }
    
    // MARK: - Context Management
    
    /// Save the model context
    /// - Throws: If save fails
    func save() throws {
        try modelContext.save()
        print("💾 ServiceContainer: Context saved")
    }
    
    /// Reset all data for testing
    /// **WARNING:** This deletes ALL data!
    func resetAllData() throws {
        print("⚠️ ServiceContainer: RESETTING ALL DATA")
        
        // Delete all models
        try modelContext.delete(model: HabitModel.self)
        try modelContext.delete(model: DailyProgressModel.self)
        try modelContext.delete(model: GlobalStreakModel.self)
        try modelContext.delete(model: UserProgressModel.self)
        try modelContext.delete(model: XPTransactionModel.self)
        try modelContext.delete(model: AchievementModel.self)
        try modelContext.delete(model: ReminderModel.self)
        
        try save()
        
        print("✅ ServiceContainer: All data reset")
    }
}

// MARK: - Result Types

/// Result of completing a habit
struct CompletionResult {
    /// Progress increment result
    let progressResult: IncrementResult
    
    /// XP awarded (0 if not all habits complete)
    let xpAwarded: Int
    
    /// Whether streak was updated
    let streakUpdated: Bool
    
    /// Whether all habits are now complete
    let allHabitsComplete: Bool
    
    /// User-friendly description
    var description: String {
        if allHabitsComplete {
            return "✅ Habit complete! +\(xpAwarded) XP" + (streakUpdated ? " 🔥" : "")
        } else {
            return "✅ Progress: \(progressResult.newProgress)"
        }
    }
}

/// Result of uncompleting a habit
struct UncompletionResult {
    /// Progress decrement result
    let progressResult: DecrementResult
    
    /// XP removed (0 if day was already incomplete)
    let xpRemoved: Int
    
    /// Whether streak was broken/recalculated
    let streakBroken: Bool
    
    /// User-friendly description
    var description: String {
        if xpRemoved > 0 {
            return "⬇️ Day incomplete - Lost \(xpRemoved) XP" + (streakBroken ? " 💔" : "")
        } else {
            return "⬇️ Progress: \(progressResult.newProgress)"
        }
    }
}

/// Dashboard statistics
struct DashboardStats {
    let currentStreak: Int
    let longestStreak: Int
    let totalXP: Int
    let currentLevel: Int
    let activeHabitsCount: Int
    let completedTodayCount: Int
    
    var completionPercentage: Double {
        guard activeHabitsCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(activeHabitsCount)
    }
    
    var description: String {
        return """
        🔥 Streak: \(currentStreak) (Best: \(longestStreak))
        ⭐ XP: \(totalXP) (Level \(currentLevel))
        ✅ Habits: \(completedTodayCount)/\(activeHabitsCount) (\(Int(completionPercentage * 100))%)
        """
    }
}

// MARK: - Errors

enum ServiceContainerError: LocalizedError {
    case modelContainerCreationFailed(Error)
    case userNotFound
    case invalidState
    
    var errorDescription: String? {
        switch self {
        case .modelContainerCreationFailed(let error):
            return "Failed to create ModelContainer: \(error.localizedDescription)"
        case .userNotFound:
            return "User not found"
        case .invalidState:
            return "Service container in invalid state"
        }
    }
}

