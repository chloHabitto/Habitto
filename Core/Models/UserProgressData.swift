import Foundation
import SwiftData

// MARK: - SwiftData UserProgress Model
/// SwiftData model for persisting user progress and XP data
@Model
final class UserProgressData {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var userId: String  // One UserProgress per user
    var xpTotal: Int
    var level: Int
    var xpForCurrentLevel: Int
    var xpForNextLevel: Int
    var dailyXP: Int
    var lastCompletedDate: Date?
    var streakDays: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var achievements: [AchievementData]
    
    init(
        userId: String,
        xpTotal: Int = 0,
        level: Int = 1,
        xpForCurrentLevel: Int = 0,
        xpForNextLevel: Int = 300,
        dailyXP: Int = 0,
        lastCompletedDate: Date? = nil,
        streakDays: Int = 0
    ) {
        self.id = UUID()
        self.userId = userId
        self.xpTotal = xpTotal
        self.level = level
        self.xpForCurrentLevel = xpForCurrentLevel
        self.xpForNextLevel = xpForNextLevel
        self.dailyXP = dailyXP
        self.lastCompletedDate = lastCompletedDate
        self.streakDays = streakDays
        self.createdAt = Date()
        self.updatedAt = Date()
        self.achievements = []
    }
    
    // MARK: - Computed Properties
    
    var levelProgress: Double {
        // Calculate progress based on XP needed for current level vs XP needed for next level
        let currentLevelStartXP = Int(pow(Double(level - 1), 2) * 300)
        let nextLevelStartXP = Int(pow(Double(level), 2) * 300)
        let xpNeededForNextLevel = nextLevelStartXP - currentLevelStartXP
        let xpInCurrentLevel = xpTotal - currentLevelStartXP
        
        guard xpNeededForNextLevel > 0 else { return 0 }
        let progress = Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
        return min(progress, 1.0) // Clamp to maximum of 1.0
    }
    
    var isCloseToLevelUp: Bool {
        return levelProgress >= 0.8
    }
    
    // MARK: - Update Methods
    
    func updateXP(_ newXP: Int) {
        self.xpTotal = newXP
        self.updatedAt = Date()
        
        // Recalculate level based on new XP
        self.level = calculateLevel(from: newXP)
        
        // Update level progress fields
        let currentLevelStartXP = Int(pow(Double(level - 1), 2) * 300)
        let nextLevelStartXP = Int(pow(Double(level), 2) * 300)
        self.xpForCurrentLevel = newXP - currentLevelStartXP
        self.xpForNextLevel = nextLevelStartXP - currentLevelStartXP
    }
    
    func updateStreak(_ newStreak: Int) {
        self.streakDays = newStreak
        self.updatedAt = Date()
    }
    
    func markCompletedToday() {
        self.lastCompletedDate = Date()
        self.updatedAt = Date()
    }
    
    private func calculateLevel(from xp: Int) -> Int {
        // Level formula: level = floor(sqrt(xp / 300)) + 1
        // This creates a challenging progression where level 2 starts at 300 XP
        let levelFloat = sqrt(Double(xp) / 300.0)
        return max(1, Int(floor(levelFloat)) + 1)
    }
}

// MARK: - SwiftData Achievement Model
@Model
final class AchievementData {
    @Attribute(.unique) var id: UUID
    var userId: String  // Reference to user (not indexed, use relationship)
    var title: String
    var description: String
    var xpReward: Int
    var isUnlocked: Bool
    var unlockedDate: Date?
    var iconName: String
    var category: String  // Store enum as string
    var requirementType: String  // Store enum as string
    var requirementTarget: Int
    var progress: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        userId: String,
        title: String,
        description: String,
        xpReward: Int,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil,
        iconName: String,
        category: String,
        requirementType: String,
        requirementTarget: Int,
        progress: Int = 0
    ) {
        self.id = UUID()
        self.userId = userId
        self.title = title
        self.description = description
        self.xpReward = xpReward
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
        self.iconName = iconName
        self.category = category
        self.requirementType = requirementType
        self.requirementTarget = requirementTarget
        self.progress = progress
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var progressPercentage: Double {
        guard requirementTarget > 0 else { return 0 }
        return min(Double(progress) / Double(requirementTarget), 1.0)
    }
    
    var isCompleted: Bool {
        return progress >= requirementTarget
    }
    
    func updateProgress(_ newProgress: Int) {
        self.progress = newProgress
        self.updatedAt = Date()
        
        // Auto-unlock if target reached and not already unlocked
        if isCompleted && !isUnlocked {
            self.isUnlocked = true
            self.unlockedDate = Date()
        }
    }
}

// MARK: - Conversion Extensions
extension UserProgressData {
    /// Convert to legacy UserProgress struct for backward compatibility
    func toUserProgress() -> UserProgress {
        return UserProgress(
            id: self.id,
            userId: self.userId,
            xpTotal: self.xpTotal,
            level: self.level,
            xpForCurrentLevel: self.xpForCurrentLevel,
            xpForNextLevel: self.xpForNextLevel,
            dailyXP: self.dailyXP,
            lastCompletedDate: self.lastCompletedDate,
            streakDays: self.streakDays,
            achievements: self.achievements.map { $0.toAchievement() },
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}

extension AchievementData {
    /// Convert to legacy Achievement struct for backward compatibility
    func toAchievement() -> Achievement {
        let category = Achievement.AchievementCategory(rawValue: self.category) ?? .general
        let requirement: Achievement.AchievementRequirement
        
        switch self.requirementType {
        case "completeHabits":
            requirement = .completeHabits(count: self.requirementTarget)
        case "maintainStreak":
            requirement = .maintainStreak(days: self.requirementTarget)
        case "earnXP":
            requirement = .earnXP(amount: self.requirementTarget)
        case "completeDailyHabits":
            requirement = .completeDailyHabits(days: self.requirementTarget)
        case "createHabits":
            requirement = .createHabits(count: self.requirementTarget)
        case "perfectWeek":
            requirement = .perfectWeek(weeks: self.requirementTarget)
        default:
            requirement = .specialEvent("Unknown")
        }
        
        return Achievement(
            id: self.id,
            title: self.title,
            description: self.description,
            xpReward: self.xpReward,
            isUnlocked: self.isUnlocked,
            unlockedDate: self.unlockedDate,
            iconName: self.iconName,
            category: category,
            requirement: requirement,
            progress: self.progress
        )
    }
}

// MARK: - Legacy UserProgress Extensions
extension UserProgress {
    /// Convert legacy UserProgress to SwiftData UserProgressData
    func toUserProgressData() -> UserProgressData {
        let userProgressData = UserProgressData(
            userId: self.userId ?? "",
            xpTotal: self.totalXP,
            level: self.currentLevel,
            xpForCurrentLevel: self.xpForCurrentLevel,
            xpForNextLevel: self.xpForNextLevel,
            dailyXP: self.dailyXP,
            lastCompletedDate: self.lastCompletedDate,
            streakDays: self.streakDays
        )
        
        // Convert achievements
        for achievement in self.achievements {
            let achievementData = AchievementData(
                userId: self.userId ?? "",
                title: achievement.title,
                description: achievement.description,
                xpReward: achievement.xpReward,
                isUnlocked: achievement.isUnlocked,
                unlockedDate: achievement.unlockedDate,
                iconName: achievement.iconName,
                category: achievement.category.rawValue,
                requirementType: achievement.requirementType,
                requirementTarget: achievement.requirement.target,
                progress: achievement.progress
            )
            userProgressData.achievements.append(achievementData)
        }
        
        return userProgressData
    }
}

// MARK: - Legacy Achievement Extensions
extension Achievement {
    var requirementType: String {
        switch self.requirement {
        case .completeHabits:
            return "completeHabits"
        case .maintainStreak:
            return "maintainStreak"
        case .earnXP:
            return "earnXP"
        case .completeDailyHabits:
            return "completeDailyHabits"
        case .createHabits:
            return "createHabits"
        case .perfectWeek:
            return "perfectWeek"
        case .specialEvent:
            return "specialEvent"
        }
    }
}
