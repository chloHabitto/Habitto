import Foundation
import SwiftData

/// AchievementModel tracks unlocked achievements for gamification
///
/// **Uniqueness:** Uses composite ID (userId_achievementId) to ensure
/// each user can only unlock each achievement once
///
/// **Achievement Types:**
/// - First habit created
/// - 7-day streak
/// - 30-day streak
/// - 100 total completions
/// - Perfect week (all habits completed every day)
/// - Level milestones
@Model
final class AchievementModel {
    // MARK: - Identity
    
    /// Composite unique identifier: "userId_achievementId"
    /// **Example:** "user123_first_habit"
    /// **Purpose:** Ensures each user can only unlock each achievement once
    @Attribute(.unique) var id: String
    
    /// User ID
    var userId: String
    
    /// Unique achievement identifier (e.g., "first_habit", "streak_7")
    var achievementId: String
    
    // MARK: - Achievement Data
    
    /// Display title (e.g., "First Steps")
    var title: String
    
    /// Description (e.g., "Created your first habit")
    var achievementDescription: String
    
    /// When achievement was unlocked
    var unlockedAt: Date
    
    /// XP awarded for this achievement
    var xpAwarded: Int
    
    // MARK: - Initialization
    
    /// Initialize achievement with automatic composite ID generation
    init(
        userId: String,
        achievementId: String,
        title: String,
        description: String,
        unlockedAt: Date = Date(),
        xpAwarded: Int = 0
    ) {
        // Create composite unique ID
        self.id = "\(userId)_\(achievementId)"
        
        self.userId = userId
        self.achievementId = achievementId
        self.title = title
        self.achievementDescription = description
        self.unlockedAt = unlockedAt
        self.xpAwarded = xpAwarded
    }
}

// MARK: - Achievement Definitions

extension AchievementModel {
    /// Predefined achievement definitions
    enum Achievement {
        case firstHabit
        case streak7
        case streak30
        case streak100
        case completions100
        case completions500
        case completions1000
        case perfectWeek
        case perfectMonth
        case level5
        case level10
        case level25
        case level50
        
        var achievementId: String {
            switch self {
            case .firstHabit: return "first_habit"
            case .streak7: return "streak_7"
            case .streak30: return "streak_30"
            case .streak100: return "streak_100"
            case .completions100: return "completions_100"
            case .completions500: return "completions_500"
            case .completions1000: return "completions_1000"
            case .perfectWeek: return "perfect_week"
            case .perfectMonth: return "perfect_month"
            case .level5: return "level_5"
            case .level10: return "level_10"
            case .level25: return "level_25"
            case .level50: return "level_50"
            }
        }
        
        var title: String {
            switch self {
            case .firstHabit: return "First Steps"
            case .streak7: return "Week Warrior"
            case .streak30: return "Monthly Master"
            case .streak100: return "Century Streak"
            case .completions100: return "Consistent Achiever"
            case .completions500: return "Habit Hero"
            case .completions1000: return "Legendary Consistency"
            case .perfectWeek: return "Perfect Week"
            case .perfectMonth: return "Perfect Month"
            case .level5: return "Rising Star"
            case .level10: return "Habit Expert"
            case .level25: return "Master of Habits"
            case .level50: return "Legendary"
            }
        }
        
        var description: String {
            switch self {
            case .firstHabit: return "Created your first habit"
            case .streak7: return "Completed all habits for 7 days straight"
            case .streak30: return "Completed all habits for 30 days straight"
            case .streak100: return "Completed all habits for 100 days straight"
            case .completions100: return "Completed 100 total habit instances"
            case .completions500: return "Completed 500 total habit instances"
            case .completions1000: return "Completed 1000 total habit instances"
            case .perfectWeek: return "Completed all habits every day this week"
            case .perfectMonth: return "Completed all habits every day this month"
            case .level5: return "Reached level 5"
            case .level10: return "Reached level 10"
            case .level25: return "Reached level 25"
            case .level50: return "Reached level 50"
            }
        }
        
        var xpReward: Int {
            switch self {
            case .firstHabit: return 50
            case .streak7: return 100
            case .streak30: return 500
            case .streak100: return 2000
            case .completions100: return 200
            case .completions500: return 1000
            case .completions1000: return 5000
            case .perfectWeek: return 150
            case .perfectMonth: return 1000
            case .level5: return 100
            case .level10: return 300
            case .level25: return 1000
            case .level50: return 5000
            }
        }
    }
}

