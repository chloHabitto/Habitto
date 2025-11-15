import Foundation

// MARK: - UserProgress

struct UserProgress: Codable, Identifiable {
  // MARK: Lifecycle

  init(userId: String? = nil) {
    self.id = UUID()
    self.userId = userId
  }

  // MARK: Internal

  let id: UUID
  var userId: String? // For future cloud sync
  var totalXP = 0
  var currentLevel = 1
  var xpForCurrentLevel = 0
  var xpForNextLevel = 300 // Level 2 starts at 300 XP (challenging progression)
  var dailyXP = 0
  var lastCompletedDate: Date?
  var streakDays = 0
  var achievements: [Achievement] = []
  var createdAt = Date()
  var updatedAt = Date()

  /// Computed properties
  var levelProgress: Double {
    // Calculate progress based on XP needed for current level vs XP needed for next level
    let currentLevelStartXP =
      Int(pow(Double(currentLevel - 1), 2) * 300) // Updated to 300 for challenging progression
    let nextLevelStartXP =
      Int(pow(Double(currentLevel), 2) * 300) // Updated to 300 for challenging progression
    let xpNeededForNextLevel = nextLevelStartXP - currentLevelStartXP
    let xpInCurrentLevel = totalXP - currentLevelStartXP

    guard xpNeededForNextLevel > 0 else { return 0 }
    let progress = Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
    // Clamp to a safe 0...1 range to avoid negative/NaN layout values in SwiftUI
    return max(0, min(progress, 1.0))
  }

  var isCloseToLevelUp: Bool {
    levelProgress >= 0.8
  }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable {
  // MARK: Lifecycle

  init(
    title: String,
    description: String,
    xpReward: Int,
    isUnlocked: Bool = false,
    unlockedDate: Date? = nil,
    iconName: String,
    category: AchievementCategory,
    requirement: AchievementRequirement)
  {
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

  // MARK: Internal

  enum AchievementCategory: String, Codable, CaseIterable {
    case daily
    case streak
    case milestone
    case habit
    case general
    case social
    case special
  }

  enum AchievementRequirement: Codable {
    case completeHabits(count: Int)
    case maintainStreak(days: Int)
    case earnXP(amount: Int)
    case completeDailyHabits(days: Int)
    case createHabits(count: Int)
    case perfectWeek(weeks: Int)
    case specialEvent(String)

    // MARK: Internal

    var target: Int {
      switch self {
      case .completeHabits(let count):
        count
      case .maintainStreak(let days):
        days
      case .earnXP(let amount):
        amount
      case .completeDailyHabits(let days):
        days
      case .createHabits(let count):
        count
      case .perfectWeek(let weeks):
        weeks
      case .specialEvent:
        1
      }
    }
  }

  let id: UUID
  let title: String
  let description: String
  let xpReward: Int
  var isUnlocked = false
  var unlockedDate: Date?
  let iconName: String
  let category: AchievementCategory
  let requirement: AchievementRequirement
  var progress = 0

  var progressPercentage: Double {
    guard requirement.target > 0 else { return 0 }
    return min(Double(progress) / Double(requirement.target), 1.0)
  }

  var isCompleted: Bool {
    progress >= requirement.target
  }
}

// MARK: - XPRewardReason

enum XPRewardReason: String, Codable {
  case completeAllHabits = "complete_all_habits"
  case completeHabit = "complete_habit"
  case streakBonus = "streak_bonus"
  case perfectWeek = "perfect_week"
  case levelUp = "level_up"
  case achievement
  case firstHabit = "first_habit"
  case comeback
}

// MARK: - XPTransaction

struct XPTransaction: Codable, Identifiable {
  // MARK: Lifecycle

  init(amount: Int, reason: XPRewardReason, habitName: String? = nil, description: String? = nil) {
    self.id = UUID()
    self.amount = amount
    self.reason = reason
    self.timestamp = Date()
    self.habitName = habitName
    self.description = description ?? reason.rawValue.replacingOccurrences(of: "_", with: " ")
      .capitalized
  }

  // MARK: Internal

  let id: UUID
  let amount: Int
  let reason: XPRewardReason
  let timestamp: Date
  let habitName: String?
  let description: String
}
