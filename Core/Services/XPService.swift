import Foundation
import SwiftUI
import OSLog

// MARK: - XP Service
/// Manages XP rewards, level calculations, and achievement tracking
@MainActor
class XPService: ObservableObject {
    static let shared = XPService()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "XPService")
    private let userDefaults = UserDefaults.standard
    private let userProgressKey = "user_progress"
    
    @Published var userProgress: UserProgress = UserProgress()
    @Published var recentTransactions: [XPTransaction] = []
    
    private init() {
        loadUserProgress()
        loadRecentTransactions()
        logger.info("XPService initialized with level \(userProgress.currentLevel) and \(userProgress.totalXP) XP")
    }
    
    // MARK: - XP Rewards
    
    /// Awards XP for habit completion
    func awardXPForHabitCompletion(_ habit: Habit, date: Date = Date()) {
        let baseXP = calculateBaseXP(for: habit)
        let streakBonus = calculateStreakBonus(for: habit)
        let totalXP = baseXP + streakBonus
        
        let transaction = XPTransaction(
            amount: totalXP,
            reason: .completeHabit,
            habitName: habit.name,
            description: "Completed \(habit.name)"
        )
        
        addXP(totalXP, transaction: transaction)
        
        logger.info("Awarded \(totalXP) XP for completing habit '\(habit.name)' (base: \(baseXP), streak bonus: \(streakBonus))")
    }
    
    /// Awards XP for completing all habits in a day
    func awardXPForPerfectDay(habits: [Habit], date: Date = Date()) {
        let perfectDayXP = 50 // Bonus XP for completing all habits
        let transaction = XPTransaction(
            amount: perfectDayXP,
            reason: .completeAllHabits,
            description: "Perfect Day - All habits completed!"
        )
        
        addXP(perfectDayXP, transaction: transaction)
        
        logger.info("Awarded \(perfectDayXP) XP for perfect day")
    }
    
    /// Awards XP for streak milestones
    func awardXPForStreakMilestone(_ habit: Habit, streakDays: Int) {
        let milestoneXP = calculateStreakMilestoneXP(streakDays: streakDays)
        guard milestoneXP > 0 else { return }
        
        let transaction = XPTransaction(
            amount: milestoneXP,
            reason: .streakBonus,
            habitName: habit.name,
            description: "\(streakDays) day streak!"
        )
        
        addXP(milestoneXP, transaction: transaction)
        
        logger.info("Awarded \(milestoneXP) XP for \(streakDays) day streak in habit '\(habit.name)'")
    }
    
    /// Awards XP for leveling up
    func awardXPForLevelUp(newLevel: Int) {
        let levelUpXP = 25 // Bonus XP for reaching a new level
        let transaction = XPTransaction(
            amount: levelUpXP,
            reason: .levelUp,
            description: "Level \(newLevel) reached!"
        )
        
        addXP(levelUpXP, transaction: transaction)
        
        logger.info("Awarded \(levelUpXP) XP for reaching level \(newLevel)")
    }
    
    // MARK: - XP Calculation Helpers
    
    private func calculateBaseXP(for habit: Habit) -> Int {
        // Base XP varies by habit type and difficulty
        switch habit.habitType {
        case .formation:
            return 10 // Standard XP for habit formation
        case .breaking:
            return 15 // Higher XP for habit breaking (more challenging)
        }
    }
    
    private func calculateStreakBonus(for habit: Habit) -> Int {
        let streak = habit.streak
        switch streak {
        case 0...6:
            return 0 // No bonus for first week
        case 7...13:
            return 5 // Small bonus for 1-2 weeks
        case 14...29:
            return 10 // Medium bonus for 2-4 weeks
        case 30...99:
            return 15 // Good bonus for 1-3 months
        default:
            return 20 // Maximum bonus for 100+ days
        }
    }
    
    private func calculateStreakMilestoneXP(streakDays: Int) -> Int {
        switch streakDays {
        case 7, 14, 30, 60, 100, 200, 365:
            return streakDays // XP equal to streak days for major milestones
        default:
            return 0 // No bonus for non-milestone streaks
        }
    }
    
    // MARK: - Level Management
    
    private func addXP(_ amount: Int, transaction: XPTransaction) {
        let oldLevel = userProgress.currentLevel
        userProgress.totalXP += amount
        userProgress.dailyXP += amount
        
        // Check for level up
        let newLevel = calculateLevel(for: userProgress.totalXP)
        if newLevel > oldLevel {
            userProgress.currentLevel = newLevel
            updateLevelProgress()
            
            // Award bonus XP for leveling up
            awardXPForLevelUp(newLevel: newLevel)
            
            logger.info("Level up! Reached level \(newLevel)")
        } else {
            updateLevelProgress()
        }
        
        // Add transaction to recent list
        recentTransactions.insert(transaction, at: 0)
        if recentTransactions.count > 10 {
            recentTransactions.removeLast()
        }
        
        saveUserProgress()
        saveRecentTransactions()
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    private func calculateLevel(for totalXP: Int) -> Int {
        // Level formula: Level = floor(sqrt(XP / 25)) + 1
        // This creates exponential XP requirements: Level 2 = 25 XP, Level 3 = 100 XP, Level 4 = 225 XP, etc.
        return Int(sqrt(Double(totalXP) / 25.0)) + 1
    }
    
    private func updateLevelProgress() {
        let currentLevelStartXP = Int(pow(Double(userProgress.currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(userProgress.currentLevel), 2) * 25)
        
        userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
        userProgress.xpForNextLevel = nextLevelStartXP - currentLevelStartXP
    }
    
    // MARK: - Achievement Management
    
    /// Checks and unlocks achievements based on current progress
    func checkAchievements(habits: [Habit]) {
        let achievements = AchievementManager.shared.getAllAchievements()
        
        for achievement in achievements {
            if !achievement.isUnlocked {
                let progress = calculateAchievementProgress(achievement, habits: habits)
                if progress >= achievement.requirement.target {
                    unlockAchievement(achievement)
                }
            }
        }
    }
    
    private func calculateAchievementProgress(_ achievement: Achievement, habits: [Habit]) -> Int {
        switch achievement.requirement {
        case .completeHabits(let count):
            return habits.reduce(0) { total, habit in
                total + habit.completionHistory.values.reduce(0, +)
            }
        case .maintainStreak(let days):
            return habits.map { $0.streak }.max() ?? 0
        case .earnXP(let amount):
            return userProgress.totalXP
        case .completeDailyHabits(let days):
            // Count days where all habits were completed
            return countPerfectDays(habits: habits)
        case .createHabits(let count):
            return habits.count
        case .perfectWeek(let weeks):
            return countPerfectWeeks(habits: habits)
        case .specialEvent:
            return 0 // Special events handled separately
        }
    }
    
    private func countPerfectDays(habits: [Habit]) -> Int {
        // This is a simplified implementation
        // In a real app, you'd track this more precisely
        return habits.isEmpty ? 0 : min(habits.count, 30) // Placeholder
    }
    
    private func countPerfectWeeks(habits: [Habit]) -> Int {
        // This is a simplified implementation
        // In a real app, you'd track this more precisely
        return habits.isEmpty ? 0 : min(habits.count / 7, 4) // Placeholder
    }
    
    private func unlockAchievement(_ achievement: Achievement) {
        var unlockedAchievement = achievement
        unlockedAchievement.isUnlocked = true
        unlockedAchievement.unlockedDate = Date()
        
        // Add to user progress
        if let index = userProgress.achievements.firstIndex(where: { $0.id == achievement.id }) {
            userProgress.achievements[index] = unlockedAchievement
        } else {
            userProgress.achievements.append(unlockedAchievement)
        }
        
        // Award XP for achievement
        let transaction = XPTransaction(
            amount: achievement.xpReward,
            reason: .achievement,
            description: "Achievement unlocked: \(achievement.title)"
        )
        
        addXP(achievement.xpReward, transaction: transaction)
        
        logger.info("Unlocked achievement: \(achievement.title)")
    }
    
    // MARK: - Data Persistence
    
    private func saveUserProgress() {
        if let encoded = try? JSONEncoder().encode(userProgress) {
            userDefaults.set(encoded, forKey: userProgressKey)
        }
    }
    
    private func loadUserProgress() {
        if let data = userDefaults.data(forKey: userProgressKey),
           let progress = try? JSONDecoder().decode(UserProgress.self, from: data) {
            userProgress = progress
            updateLevelProgress() // Ensure level progress is up to date
        }
    }
    
    private func saveRecentTransactions() {
        let transactionsKey = "recent_xp_transactions"
        if let encoded = try? JSONEncoder().encode(recentTransactions) {
            userDefaults.set(encoded, forKey: transactionsKey)
        }
    }
    
    private func loadRecentTransactions() {
        let transactionsKey = "recent_xp_transactions"
        if let data = userDefaults.data(forKey: transactionsKey),
           let transactions = try? JSONDecoder().decode([XPTransaction].self, from: data) {
            recentTransactions = transactions
        }
    }
    
    // MARK: - Reset Functions
    
    /// Resets daily XP counter (call this daily)
    func resetDailyXP() {
        userProgress.dailyXP = 0
        saveUserProgress()
        logger.info("Daily XP reset")
    }
    
    /// Resets all progress (for testing or account reset)
    func resetAllProgress() {
        userProgress = UserProgress()
        recentTransactions = []
        saveUserProgress()
        saveRecentTransactions()
        logger.info("All XP progress reset")
    }
}

// MARK: - Achievement Manager
class AchievementManager {
    static let shared = AchievementManager()
    
    private init() {}
    
    func getAllAchievements() -> [Achievement] {
        return [
            // Daily achievements
            Achievement(
                title: "First Steps",
                description: "Complete your first habit",
                xpReward: 25,
                iconName: "star.fill",
                category: .daily,
                requirement: .completeHabits(count: 1)
            ),
            Achievement(
                title: "Daily Warrior",
                description: "Complete all habits for 7 days",
                xpReward: 100,
                iconName: "calendar.badge.checkmark",
                category: .daily,
                requirement: .completeDailyHabits(days: 7)
            ),
            
            // Streak achievements
            Achievement(
                title: "Week Warrior",
                description: "Maintain a 7-day streak",
                xpReward: 50,
                iconName: "flame.fill",
                category: .streak,
                requirement: .maintainStreak(days: 7)
            ),
            Achievement(
                title: "Month Master",
                description: "Maintain a 30-day streak",
                xpReward: 200,
                iconName: "crown.fill",
                category: .streak,
                requirement: .maintainStreak(days: 30)
            ),
            
            // XP achievements
            Achievement(
                title: "XP Collector",
                description: "Earn 500 XP",
                xpReward: 50,
                iconName: "gift.fill",
                category: .milestone,
                requirement: .earnXP(amount: 500)
            ),
            Achievement(
                title: "XP Master",
                description: "Earn 2000 XP",
                xpReward: 100,
                iconName: "trophy.fill",
                category: .milestone,
                requirement: .earnXP(amount: 2000)
            ),
            
            // Habit achievements
            Achievement(
                title: "Habit Creator",
                description: "Create 5 habits",
                xpReward: 75,
                iconName: "plus.circle.fill",
                category: .habit,
                requirement: .createHabits(count: 5)
            ),
            Achievement(
                title: "Habit Master",
                description: "Create 10 habits",
                xpReward: 150,
                iconName: "star.circle.fill",
                category: .habit,
                requirement: .createHabits(count: 10)
            )
        ]
    }
}
