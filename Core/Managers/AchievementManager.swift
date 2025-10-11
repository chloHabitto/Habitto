import Combine
import Foundation

// MARK: - AchievementManager

@MainActor
class AchievementManager: ObservableObject {
  // MARK: Lifecycle

  init() {
    loadAchievements()
  }

  // MARK: Internal

  @Published var achievements: [Achievement] = []
  @Published var unlockedAchievements: [Achievement] = []
  @Published var recentUnlocks: [Achievement] = []

  // MARK: - Achievement Management

  func loadAchievements() {
    if achievements.isEmpty {
      achievements = createDefaultAchievements()
    }
    updateUnlockedAchievements()
  }

  func updateAchievementProgress(_ achievementId: UUID, progress: Int) {
    guard let index = achievements.firstIndex(where: { $0.id == achievementId }) else { return }

    _ = achievements[index].progress
    achievements[index].progress = max(achievements[index].progress, progress)

    // Check if achievement was just unlocked
    if !achievements[index].isUnlocked, achievements[index].isCompleted {
      unlockAchievement(at: index)
    }
  }

  func updateAchievementProgress(
    by requirement: Achievement.AchievementRequirement,
    amount: Int = 1)
  {
    for (index, achievement) in achievements.enumerated() {
      if achievement.requirement.matches(requirement), !achievement.isUnlocked {
        achievements[index].progress += amount

        if achievements[index].isCompleted {
          unlockAchievement(at: index)
        }
      }
    }
  }

  // MARK: - Achievement Tracking

  func trackHabitCompletion() {
    updateAchievementProgress(by: .completeHabits(count: 1), amount: 1)
  }

  func trackDailyCompletion() {
    updateAchievementProgress(by: .completeDailyHabits(days: 1), amount: 1)
  }

  func trackStreakUpdate(_ streakDays: Int) {
    for (index, achievement) in achievements.enumerated() {
      if case .maintainStreak = achievement.requirement,
         !achievement.isUnlocked
      {
        achievements[index].progress = max(achievement.progress, streakDays)

        if achievements[index].isCompleted {
          unlockAchievement(at: index)
        }
      }
    }
  }

  func trackXPUpdate(_ totalXP: Int) {
    for (index, achievement) in achievements.enumerated() {
      if case .earnXP = achievement.requirement,
         !achievement.isUnlocked
      {
        achievements[index].progress = max(achievement.progress, totalXP)

        if achievements[index].isCompleted {
          unlockAchievement(at: index)
        }
      }
    }
  }

  func trackHabitCreation() {
    updateAchievementProgress(by: .createHabits(count: 1), amount: 1)
  }

  func trackPerfectWeek() {
    updateAchievementProgress(by: .perfectWeek(weeks: 1), amount: 1)
  }

  // MARK: - Special Events

  func trackSpecialEvent(_ eventName: String) {
    for (index, achievement) in achievements.enumerated() {
      if case .specialEvent(let name) = achievement.requirement,
         name == eventName,
         !achievement.isUnlocked
      {
        achievements[index].progress = 1
        unlockAchievement(at: index)
      }
    }
  }

  // MARK: - Helper Methods

  func getAchievementsByCategory(_ category: Achievement.AchievementCategory) -> [Achievement] {
    achievements.filter { $0.category == category }
  }

  func getUnlockedAchievementsByCategory(_ category: Achievement
    .AchievementCategory) -> [Achievement]
  {
    unlockedAchievements.filter { $0.category == category }
  }

  func getProgressAchievements() -> [Achievement] {
    achievements.filter { !$0.isUnlocked && $0.progress > 0 }
  }

  func clearRecentUnlocks() {
    recentUnlocks.removeAll()
  }

  // MARK: Private

  private let maxRecentUnlocks = 5

  // MARK: - Achievement Definitions

  private func createDefaultAchievements() -> [Achievement] {
    [
      // Daily Achievements
      Achievement(
        title: "First Steps",
        description: "Complete your first habit",
        xpReward: 25,
        iconName: "star.fill",
        category: .daily,
        requirement: .completeHabits(count: 1)),
      Achievement(
        title: "Daily Warrior",
        description: "Complete all habits for 7 days straight",
        xpReward: 100,
        iconName: "flame.fill",
        category: .daily,
        requirement: .completeDailyHabits(days: 7)),
      Achievement(
        title: "Perfect Week",
        description: "Complete all habits every day for a week",
        xpReward: 200,
        iconName: "crown.fill",
        category: .daily,
        requirement: .perfectWeek(weeks: 1)),

      // Streak Achievements
      Achievement(
        title: "Streak Starter",
        description: "Maintain a 3-day streak",
        xpReward: 50,
        iconName: "fire.fill",
        category: .streak,
        requirement: .maintainStreak(days: 3)),
      Achievement(
        title: "Week Warrior",
        description: "Maintain a 7-day streak",
        xpReward: 150,
        iconName: "flame.fill",
        category: .streak,
        requirement: .maintainStreak(days: 7)),
      Achievement(
        title: "Month Master",
        description: "Maintain a 30-day streak",
        xpReward: 500,
        iconName: "crown.fill",
        category: .streak,
        requirement: .maintainStreak(days: 30)),

      // Milestone Achievements
      Achievement(
        title: "XP Collector",
        description: "Earn 1000 XP total",
        xpReward: 100,
        iconName: "star.circle.fill",
        category: .milestone,
        requirement: .earnXP(amount: 1000)),
      Achievement(
        title: "XP Master",
        description: "Earn 5000 XP total",
        xpReward: 300,
        iconName: "star.circle.fill",
        category: .milestone,
        requirement: .earnXP(amount: 5000)),
      Achievement(
        title: "XP Legend",
        description: "Earn 10000 XP total",
        xpReward: 750,
        iconName: "star.circle.fill",
        category: .milestone,
        requirement: .earnXP(amount: 10000)),

      // Habit Achievements
      Achievement(
        title: "Habit Creator",
        description: "Create 5 habits",
        xpReward: 50,
        iconName: "plus.circle.fill",
        category: .habit,
        requirement: .createHabits(count: 5)),
      Achievement(
        title: "Habit Master",
        description: "Create 10 habits",
        xpReward: 100,
        iconName: "plus.circle.fill",
        category: .habit,
        requirement: .createHabits(count: 10)),

      // Special Achievements
      Achievement(
        title: "Early Bird",
        description: "Complete all habits before 8 AM",
        xpReward: 75,
        iconName: "sunrise.fill",
        category: .special,
        requirement: .specialEvent("early_bird")),
      Achievement(
        title: "Night Owl",
        description: "Complete all habits after 10 PM",
        xpReward: 75,
        iconName: "moon.fill",
        category: .special,
        requirement: .specialEvent("night_owl"))
    ]
  }

  private func updateUnlockedAchievements() {
    unlockedAchievements = achievements.filter { $0.isUnlocked }
  }

  private func unlockAchievement(at index: Int) {
    achievements[index].isUnlocked = true
    achievements[index].unlockedDate = Date()

    let unlockedAchievement = achievements[index]
    unlockedAchievements.append(unlockedAchievement)

    // Add to recent unlocks
    recentUnlocks.insert(unlockedAchievement, at: 0)
    if recentUnlocks.count > maxRecentUnlocks {
      recentUnlocks = Array(recentUnlocks.prefix(maxRecentUnlocks))
    }

    print("🏆 Achievement Unlocked: \(unlockedAchievement.title)")
  }
}

// MARK: - Achievement Requirement Matching

extension Achievement.AchievementRequirement {
  func matches(_ other: Achievement.AchievementRequirement) -> Bool {
    switch (self, other) {
    case (.completeDailyHabits, .completeDailyHabits),
         (.completeHabits, .completeHabits),
         (.createHabits, .createHabits),
         (.earnXP, .earnXP),
         (.maintainStreak, .maintainStreak),
         (.perfectWeek, .perfectWeek):
      true
    case (.specialEvent(let name1), .specialEvent(let name2)):
      name1 == name2
    default:
      false
    }
  }
}
