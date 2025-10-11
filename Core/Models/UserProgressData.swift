import Foundation
import SwiftData

// MARK: - UserProgressData

/// SwiftData model for persisting user progress and XP data
@Model
final class UserProgressData {
  // MARK: Lifecycle

  init(
    userId: String,
    xpTotal: Int = 0,
    level: Int = 1,
    xpForCurrentLevel: Int = 0,
    xpForNextLevel: Int = 300,
    dailyXP: Int = 0,
    lastCompletedDate: Date? = nil,
    streakDays: Int = 0)
  {
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

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  @Attribute(.unique) var userId: String // One UserProgress per user
  var xpTotal: Int
  var level: Int
  var xpForCurrentLevel: Int
  var xpForNextLevel: Int
  var dailyXP: Int
  var lastCompletedDate: Date?
  var streakDays: Int
  var createdAt: Date
  var updatedAt: Date

  /// Relationships
  @Relationship(deleteRule: .cascade) var achievements: [AchievementData]

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
    levelProgress >= 0.8
  }

  // MARK: - Update Methods

  func updateXP(_ newXP: Int) {
    xpTotal = newXP
    updatedAt = Date()

    // Recalculate level based on new XP
    level = calculateLevel(from: newXP)

    // Update level progress fields
    let currentLevelStartXP = Int(pow(Double(level - 1), 2) * 300)
    let nextLevelStartXP = Int(pow(Double(level), 2) * 300)
    xpForCurrentLevel = newXP - currentLevelStartXP
    xpForNextLevel = nextLevelStartXP - currentLevelStartXP
  }

  func updateStreak(_ newStreak: Int) {
    streakDays = newStreak
    updatedAt = Date()
  }

  func markCompletedToday() {
    lastCompletedDate = Date()
    updatedAt = Date()
  }

  // MARK: Private

  private func calculateLevel(from xp: Int) -> Int {
    // Level formula: level = floor(sqrt(xp / 300)) + 1
    // This creates a challenging progression where level 2 starts at 300 XP
    let levelFloat = sqrt(Double(xp) / 300.0)
    return max(1, Int(floor(levelFloat)) + 1)
  }
}

// MARK: - AchievementData

@Model
final class AchievementData {
  // MARK: Lifecycle

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
    progress: Int = 0)
  {
    self.id = UUID()
    self.userId = userId
    self.title = title
    self.achievementDescription = description
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

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var userId: String // Reference to user (not indexed, use relationship)
  var title: String
  var achievementDescription: String
  var xpReward: Int
  var isUnlocked: Bool
  var unlockedDate: Date?
  var iconName: String
  var category: String // Store enum as string
  var requirementType: String // Store enum as string
  var requirementTarget: Int
  var progress: Int
  var createdAt: Date
  var updatedAt: Date

  var progressPercentage: Double {
    guard requirementTarget > 0 else { return 0 }
    return min(Double(progress) / Double(requirementTarget), 1.0)
  }

  var isCompleted: Bool {
    progress >= requirementTarget
  }

  func updateProgress(_ newProgress: Int) {
    progress = newProgress
    updatedAt = Date()

    // Auto-unlock if target reached and not already unlocked
    if isCompleted, !isUnlocked {
      isUnlocked = true
      unlockedDate = Date()
    }
  }
}

// MARK: - Conversion Extensions

extension UserProgressData {
  /// Convert to legacy UserProgress struct for backward compatibility
  func toUserProgress() -> UserProgress {
    var userProgress = UserProgress(userId: userId)
    userProgress.totalXP = xpTotal
    userProgress.currentLevel = level
    userProgress.xpForCurrentLevel = xpForCurrentLevel
    userProgress.xpForNextLevel = xpForNextLevel
    userProgress.dailyXP = dailyXP
    userProgress.lastCompletedDate = lastCompletedDate
    userProgress.streakDays = streakDays
    userProgress.achievements = achievements.map { $0.toAchievement() }
    userProgress.createdAt = createdAt
    userProgress.updatedAt = updatedAt
    return userProgress
  }
}

extension AchievementData {
  /// Convert to legacy Achievement struct for backward compatibility
  func toAchievement() -> Achievement {
    let category = Achievement.AchievementCategory(rawValue: category) ?? .general
    let requirement: Achievement.AchievementRequirement = switch requirementType {
    case "completeHabits":
      .completeHabits(count: requirementTarget)
    case "maintainStreak":
      .maintainStreak(days: requirementTarget)
    case "earnXP":
      .earnXP(amount: requirementTarget)
    case "completeDailyHabits":
      .completeDailyHabits(days: requirementTarget)
    case "createHabits":
      .createHabits(count: requirementTarget)
    case "perfectWeek":
      .perfectWeek(weeks: requirementTarget)
    default:
      .specialEvent("Unknown")
    }

    return Achievement(
      title: title,
      description: achievementDescription,
      xpReward: xpReward,
      isUnlocked: isUnlocked,
      unlockedDate: unlockedDate,
      iconName: iconName,
      category: category,
      requirement: requirement)
  }
}

// MARK: - Legacy UserProgress Extensions

extension UserProgress {
  /// Convert legacy UserProgress to SwiftData UserProgressData
  func toUserProgressData() -> UserProgressData {
    let userProgressData = UserProgressData(
      userId: userId ?? "",
      xpTotal: totalXP,
      level: currentLevel,
      xpForCurrentLevel: xpForCurrentLevel,
      xpForNextLevel: xpForNextLevel,
      dailyXP: dailyXP,
      lastCompletedDate: lastCompletedDate,
      streakDays: streakDays)

    // Convert achievements
    for achievement in achievements {
      let achievementData = AchievementData(
        userId: userId ?? "",
        title: achievement.title,
        description: achievement.description,
        xpReward: achievement.xpReward,
        isUnlocked: achievement.isUnlocked,
        unlockedDate: achievement.unlockedDate,
        iconName: achievement.iconName,
        category: achievement.category.rawValue,
        requirementType: achievement.requirementType,
        requirementTarget: achievement.requirement.target,
        progress: achievement.progress)
      userProgressData.achievements.append(achievementData)
    }

    return userProgressData
  }
}

// MARK: - Legacy Achievement Extensions

extension Achievement {
  var requirementType: String {
    switch requirement {
    case .completeHabits:
      "completeHabits"
    case .maintainStreak:
      "maintainStreak"
    case .earnXP:
      "earnXP"
    case .completeDailyHabits:
      "completeDailyHabits"
    case .createHabits:
      "createHabits"
    case .perfectWeek:
      "perfectWeek"
    case .specialEvent:
      "specialEvent"
    }
  }
}
