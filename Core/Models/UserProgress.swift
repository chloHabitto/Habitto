import Foundation

// MARK: - User Progress Model
struct UserProgress: Codable, Identifiable {
    let id: UUID
    var userId: String? // For future cloud sync
    var totalXP: Int = 0
    var currentLevel: Int = 1
    var xpForCurrentLevel: Int = 0
    var xpForNextLevel: Int = 50  // Level 2 starts at 50 XP
    var dailyXP: Int = 0
    var lastCompletedDate: Date?
    var streakDays: Int = 0
    var achievements: [Achievement] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String? = nil) {
        self.id = UUID()
        self.userId = userId
    }
    
    // Computed properties
    var levelProgress: Double {
        // Calculate progress based on XP needed for current level vs XP needed for next level
        let currentLevelStartXP = Int(pow(Double(currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(currentLevel), 2) * 25)
        let xpNeededForNextLevel = nextLevelStartXP - currentLevelStartXP
        let xpInCurrentLevel = totalXP - currentLevelStartXP
        
        guard xpNeededForNextLevel > 0 else { return 0 }
        let progress = Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
        return min(progress, 1.0) // Clamp to maximum of 1.0
    }
    
    var isCloseToLevelUp: Bool {
        return levelProgress >= 0.8
    }
}

// MARK: - Achievement Model
struct Achievement: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let xpReward: Int
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    let iconName: String
    let category: AchievementCategory
    let requirement: AchievementRequirement
    var progress: Int = 0
    
    init(title: String, description: String, xpReward: Int, isUnlocked: Bool = false, unlockedDate: Date? = nil, iconName: String, category: AchievementCategory, requirement: AchievementRequirement) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.xpReward = xpReward
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
        self.iconName = iconName
        self.category = category
        self.requirement = requirement
    }
    
    var progressPercentage: Double {
        guard requirement.target > 0 else { return 0 }
        return min(Double(progress) / Double(requirement.target), 1.0)
    }
    
    var isCompleted: Bool {
        return progress >= requirement.target
    }
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case daily = "daily"
        case streak = "streak"
        case milestone = "milestone"
        case habit = "habit"
        case general = "general"
        case social = "social"
        case special = "special"
    }
    
    enum AchievementRequirement: Codable {
        case completeHabits(count: Int)
        case maintainStreak(days: Int)
        case earnXP(amount: Int)
        case completeDailyHabits(days: Int)
        case createHabits(count: Int)
        case perfectWeek(weeks: Int)
        case specialEvent(String)
        
        var target: Int {
            switch self {
            case .completeHabits(let count):
                return count
            case .maintainStreak(let days):
                return days
            case .earnXP(let amount):
                return amount
            case .completeDailyHabits(let days):
                return days
            case .createHabits(let count):
                return count
            case .perfectWeek(let weeks):
                return weeks
            case .specialEvent:
                return 1
            }
        }
    }
}

// MARK: - XP Reward Reasons
enum XPRewardReason: String, Codable {
    case completeAllHabits = "complete_all_habits"
    case completeHabit = "complete_habit"
    case streakBonus = "streak_bonus"
    case perfectWeek = "perfect_week"
    case levelUp = "level_up"
    case achievement = "achievement"
    case firstHabit = "first_habit"
    case comeback = "comeback"
}

// MARK: - XP Transaction Log
struct XPTransaction: Codable, Identifiable {
    let id: UUID
    let amount: Int
    let reason: XPRewardReason
    let timestamp: Date
    let habitName: String?
    let description: String
    
    init(amount: Int, reason: XPRewardReason, habitName: String? = nil, description: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.reason = reason
        self.timestamp = Date()
        self.habitName = habitName
        self.description = description ?? reason.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
