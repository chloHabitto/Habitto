import Foundation
import SwiftData

/// DailyProgressModel is the SINGLE SOURCE OF TRUTH for all progress tracking
///
/// **Design Philosophy:**
/// - One record per (habit, date) combination
/// - Works for BOTH formation and breaking habits using same fields
/// - Stores goalCount for historical accuracy (goal can change over time)
/// - All completion logic is computed (not stored)
///
/// **Why store goalCount?**
/// If user changes habit goal from 30min → 60min, past records at 30min
/// should still show as complete (30/30), not incomplete (30/60)
@Model
final class DailyProgressModel {
    // MARK: - Identity
    
    @Attribute(.unique) var id: UUID
    
    // MARK: - Keys (Indexed for fast queries)
    
    /// Date string "yyyy-MM-dd" for fast lookups
    @Attribute(.index) var dateString: String
    
    /// Normalized date (start of day in local timezone)
    @Attribute(.index) var date: Date
    
    // MARK: - Progress Data
    
    /// Current progress count
    /// - Formation habits: Number of completions (e.g., 3 workouts)
    /// - Breaking habits: Number of times behavior occurred (e.g., 5 cigarettes)
    var progressCount: Int
    
    /// Goal count ON THIS DATE
    /// **Critical:** Stored per-record for historical accuracy
    /// If goal changes from 30min → 60min, old records remain accurate
    var goalCount: Int
    
    // MARK: - Metadata
    
    /// Timestamps of each progress increment (for time-of-day analytics)
    /// **Example:** User completed habit at [8:30 AM, 12:00 PM, 6:00 PM]
    var timestamps: [Date]
    
    /// User-reported difficulty (1-5 scale)
    /// 1 = Very Easy, 5 = Very Hard
    var difficulty: Int?
    
    // MARK: - Relationships
    
    /// Parent habit relationship
    /// **Note:** SwiftData requires this to be optional syntactically,
    /// but logically every progress record MUST have a parent habit
    var habit: HabitModel?
    
    /// Safe non-optional access to habit
    /// **Use this in code instead of force-unwrapping**
    /// **Crashes if habit is nil (which should never happen if properly initialized)**
    var habitRequired: HabitModel {
        guard let habit = habit else {
            fatalError("❌ CRITICAL: DailyProgressModel must have a parent habit. Record ID: \(id)")
        }
        return habit
    }
    
    /// Safe optional access with helpful logging
    var habitSafe: HabitModel? {
        if habit == nil {
            print("⚠️ WARNING: DailyProgressModel missing habit. Record ID: \(id), Date: \(dateString)")
        }
        return habit
    }
    
    // MARK: - Computed Properties
    
    /// Is this habit complete for the day?
    /// **Formation:** Complete when progressCount >= goalCount (e.g., 5/5 workouts)
    /// **Breaking:** Complete when progressCount <= goalCount (e.g., 3/5 cigarettes - under limit!)
    var isComplete: Bool {
        progressCount >= goalCount
    }
    
    /// Is progress over the goal?
    /// **Formation:** Over is good! (extra effort)
    /// **Breaking:** Over is bad (exceeded limit)
    var isOverGoal: Bool {
        progressCount > goalCount
    }
    
    /// Completion percentage (clamped to 0-100%)
    var completionPercentage: Double {
        guard goalCount > 0 else { return 0.0 }
        let percentage = (Double(progressCount) / Double(goalCount)) * 100.0
        return min(percentage, 100.0)
    }
    
    /// Remaining count to reach goal
    var remainingCount: Int {
        max(0, goalCount - progressCount)
    }
    
    /// Display string for UI (e.g., "3/5 times")
    func displayString(unit: String) -> String {
        "\(progressCount)/\(goalCount) \(unit)"
    }
    
    // MARK: - Initialization
    
    /// Initialize a new daily progress record
    /// **Note:** The habit relationship must be set for SwiftData to work correctly
    init(
        id: UUID = UUID(),
        date: Date,
        habit: HabitModel,
        progressCount: Int = 0,
        goalCount: Int,
        timestamps: [Date] = [],
        difficulty: Int? = nil
    ) {
        self.id = id
        
        // Normalize date to start of day
        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: date)
        self.dateString = DateUtils.dateKey(for: self.date)
        
        self.progressCount = progressCount
        self.goalCount = goalCount
        self.timestamps = timestamps
        self.difficulty = difficulty
        
        // Set the relationship
        self.habit = habit
    }
    
    // MARK: - Progress Mutations
    
    /// Increment progress by 1
    /// **Thread-safe:** Designed to be called from @MainActor context
    func increment(at timestamp: Date = Date()) {
        progressCount += 1
        timestamps.append(timestamp)
    }
    
    /// Decrement progress by 1
    /// **Safety:** Won't go below 0
    func decrement() {
        guard progressCount > 0 else { return }
        progressCount -= 1
        
        // Remove most recent timestamp
        if !timestamps.isEmpty {
            timestamps.removeLast()
        }
    }
    
    /// Set progress to specific value
    /// **Use case:** Direct entry (e.g., "I ran 30 minutes" instead of tapping 30 times)
    func setProgress(_ count: Int, timestamps: [Date] = []) {
        progressCount = max(0, count)
        self.timestamps = timestamps
    }
    
    /// Set difficulty rating
    func setDifficulty(_ rating: Int) {
        difficulty = max(1, min(5, rating))  // Clamp to 1-5
    }
    
    /// Reset progress to 0
    func reset() {
        progressCount = 0
        timestamps.removeAll()
        difficulty = nil
    }
}

// MARK: - Query Helpers

extension DailyProgressModel {
    /// Check if progress was made (any count > 0)
    var hasProgress: Bool {
        progressCount > 0
    }
    
    /// Check if no progress made
    var isEmpty: Bool {
        progressCount == 0
    }
    
    /// Get average time of day for completions
    var averageCompletionTime: Date? {
        guard !timestamps.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let totalMinutes = timestamps.reduce(0) { sum, timestamp in
            let hour = calendar.component(.hour, from: timestamp)
            let minute = calendar.component(.minute, from: timestamp)
            return sum + (hour * 60 + minute)
        }
        
        let avgMinutes = totalMinutes / timestamps.count
        let avgHour = avgMinutes / 60
        let avgMinute = avgMinutes % 60
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = avgHour
        components.minute = avgMinute
        
        return calendar.date(from: components)
    }
}

// MARK: - Validation

extension DailyProgressModel {
    /// Validate progress record
    func validate() -> [String] {
        var errors: [String] = []
        
        // Validate habit relationship
        if habit == nil {
            errors.append("Progress record must have a parent habit")
        }
        
        if progressCount < 0 {
            errors.append("Progress count cannot be negative")
        }
        
        if goalCount <= 0 {
            errors.append("Goal count must be greater than 0")
        }
        
        if let diff = difficulty, (diff < 1 || diff > 5) {
            errors.append("Difficulty must be between 1-5")
        }
        
        // Validate dateString matches date
        let expectedDateKey = DateUtils.dateKey(for: date)
        if dateString != expectedDateKey {
            errors.append("Date string mismatch: '\(dateString)' vs '\(expectedDateKey)'")
        }
        
        return errors
    }
    
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Migration Helpers

extension DailyProgressModel {
    /// Create from legacy completionHistory entry
    /// **Note:** Requires habit to be fetched separately
    static func fromLegacyCompletion(
        habit: HabitModel,
        dateKey: String,
        completionCount: Int,
        goalCount: Int,
        timestamps: [Date] = [],
        difficulty: Int? = nil
    ) -> DailyProgressModel? {
        // Parse dateKey "yyyy-MM-dd" back to Date
        guard let date = DateUtils.date(from: dateKey) else {
            print("⚠️ Failed to parse date from key: \(dateKey)")
            return nil
        }
        
        return DailyProgressModel(
            date: date,
            habit: habit,
            progressCount: completionCount,
            goalCount: goalCount,
            timestamps: timestamps,
            difficulty: difficulty
        )
    }
}

