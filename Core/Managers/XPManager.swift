import Foundation
import SwiftUI

/// Manages XP (Experience Points) system for habit completion rewards
@MainActor
class XPManager: ObservableObject {
    static let shared = XPManager()
    
    @Published var userProgress = UserProgress()
    @Published var recentTransactions: [XPTransaction] = []
    
    private let userDefaults = UserDefaults.standard
    private let totalXPKey = "totalXP"
    private let dailyXPKey = "dailyXP"
    private let lastXPDateKey = "lastXPDate"
    private let currentLevelKey = "currentLevel"
    private let streakDaysKey = "streakDays"
    
    // XP calculation constants
    private let baseXPPerHabit = 5  // Reduced from 10
    private let streakBonusMultiplier = 1.5
    private let allHabitsCompletedBonus = 15  // Reduced from 50
    
    init() {
        loadXPData()
        // Fix any corrupted XP data on first load
        if userProgress.xpForNextLevel < 0 || userProgress.xpForCurrentLevel < 0 {
            print("🔧 XP DEBUG - Fixing corrupted XP data")
            resetXPData()
        }
    }
    
    // MARK: - XP Calculation
    
    /// Calculates XP earned for completing all habits for today
    func calculateXPForAllHabitsCompleted(habits: [Habit], for date: Date = Date()) -> Int {
        var totalXP = 0
        var completedHabitsCount = 0
        let targetDate = DateUtils.startOfDay(for: date)
        
        // Base XP for each completed habit
        for habit in habits {
            // Only give XP if the habit is actually completed for the target date
            if habit.isCompleted(for: targetDate) {
                let baseXP = baseXPPerHabit
                
                // Streak bonus: +50% XP for habits with 3+ day streaks
                let streakBonus = habit.streak >= 3 ? Int(Double(baseXP) * (streakBonusMultiplier - 1.0)) : 0
                
                totalXP += baseXP + streakBonus
                completedHabitsCount += 1
                
                print("🎯 XP CALC - Habit '\(habit.name)' completed for \(targetDate): +\(baseXP + streakBonus) XP")
            } else {
                print("🎯 XP CALC - Habit '\(habit.name)' not completed for \(targetDate): +0 XP")
            }
        }
        
        // Bonus XP for completing ALL habits (only if all habits are completed)
        if completedHabitsCount == habits.count && !habits.isEmpty {
            totalXP += allHabitsCompletedBonus
            print("🎯 XP CALC - All habits bonus: +\(allHabitsCompletedBonus) XP")
        }
        
        print("🎯 XP CALC - Total calculated XP: \(totalXP) (completed: \(completedHabitsCount)/\(habits.count)) for date: \(targetDate)")
        return totalXP
    }
    
    /// Awards XP for completing all habits and updates daily/total XP
    func awardXPForAllHabitsCompleted(habits: [Habit]) -> Int {
        let earnedXP = calculateXPForAllHabitsCompleted(habits: habits)
        
        // Check if we already awarded XP today
        let today = Calendar.current.startOfDay(for: Date())
        let lastAwardDate = userProgress.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) }
        
        if lastAwardDate == nil || today > lastAwardDate! {
            // New day - reset daily XP and award new XP
            userProgress.dailyXP = earnedXP
            userProgress.totalXP += earnedXP
            userProgress.lastCompletedDate = Date()
            
            // Update level and progress
            updateUserLevel()
            
            saveXPData()
            
            print("🎯 XP AWARDED: \(earnedXP) XP for completing \(habits.count) habits")
            return earnedXP
        } else {
            // Already awarded XP today - don't award again, but return the calculated amount for display
            print("🎯 XP ALREADY AWARDED: Daily XP already earned for today")
            return earnedXP
        }
    }
    
    /// Updates XP based on current habit completion state (can remove XP if habits are uncompleted)
    func updateXPForCurrentHabits(habits: [Habit], for date: Date = Date()) -> Int {
        print("🎯 XP UPDATE: Starting update for \(habits.count) habits on \(date)")
        
        let calculatedXP = calculateXPForAllHabitsCompleted(habits: habits, for: date)
        let today = Calendar.current.startOfDay(for: date)
        let lastAwardDate = userProgress.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) }
        
        print("🎯 XP UPDATE: Calculated XP: \(calculatedXP), Today: \(today), LastAward: \(lastAwardDate?.description ?? "nil")")
        
        // Only allow XP updates if it's the same day (for dynamic updates when uncompleting habits)
        guard lastAwardDate != nil && today == lastAwardDate! else {
            print("🎯 XP UPDATE: Not same day, skipping dynamic XP update (today: \(today), lastAward: \(lastAwardDate?.description ?? "nil"))")
            return calculatedXP
        }
        
        let previousDailyXP = userProgress.dailyXP
        let xpDifference = calculatedXP - previousDailyXP
        
        print("🎯 XP UPDATE: Previous daily XP: \(previousDailyXP), Calculated XP: \(calculatedXP), Difference: \(xpDifference)")
        
        if xpDifference != 0 {
            // Update daily XP and total XP
            userProgress.dailyXP = calculatedXP
            userProgress.totalXP += xpDifference
            
            // Ensure total XP doesn't go below 0
            if userProgress.totalXP < 0 {
                userProgress.totalXP = 0
                userProgress.dailyXP = 0
            }
            
            // Update level and progress
            updateUserLevel()
            
            // Ensure lastCompletedDate is set for today (important for dynamic updates)
            userProgress.lastCompletedDate = Date()
            
            saveXPData()
            
            if xpDifference > 0 {
                print("🎯 XP GAINED: +\(xpDifference) XP (total: \(userProgress.totalXP))")
            } else {
                print("🎯 XP LOST: \(xpDifference) XP (total: \(userProgress.totalXP))")
            }
        } else {
            print("🎯 XP UPDATE: No XP change needed")
        }
        
        return calculatedXP
    }
    
    /// Handles individual habit completion/uncompletion for immediate XP updates
    func handleHabitCompletionChange(habits: [Habit]) {
        // Update XP immediately when any habit completion state changes
        let _ = updateXPForCurrentHabits(habits: habits)
    }
    
    /// Updates user level based on total XP
    private func updateUserLevel() {
        // More balanced level system: Level 1: 0-49 XP, Level 2: 50-149 XP, Level 3: 150-299 XP, etc.
        // Formula: Level = sqrt(totalXP / 25) + 1, rounded down
        let newLevel = Int(sqrt(Double(userProgress.totalXP) / 25.0)) + 1
        if newLevel > userProgress.currentLevel {
            userProgress.currentLevel = newLevel
        }
        // Update level progress fields
        let currentLevelStartXP = Int(pow(Double(userProgress.currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(userProgress.currentLevel), 2) * 25)
        userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
        userProgress.xpForNextLevel = nextLevelStartXP - userProgress.totalXP
    }
    
    // MARK: - Data Persistence
    
    private func saveXPData() {
        userDefaults.set(userProgress.totalXP, forKey: totalXPKey)
        userDefaults.set(userProgress.dailyXP, forKey: dailyXPKey)
        userDefaults.set(userProgress.currentLevel, forKey: currentLevelKey)
        userDefaults.set(userProgress.streakDays, forKey: streakDaysKey)
        userDefaults.set(userProgress.lastCompletedDate, forKey: lastXPDateKey)
    }
    
    private func loadXPData() {
        userProgress.totalXP = userDefaults.integer(forKey: totalXPKey)
        userProgress.dailyXP = userDefaults.integer(forKey: dailyXPKey)
        userProgress.currentLevel = userDefaults.integer(forKey: currentLevelKey)
        userProgress.streakDays = userDefaults.integer(forKey: streakDaysKey)
        userProgress.lastCompletedDate = userDefaults.object(forKey: lastXPDateKey) as? Date
        
        // Ensure minimum level is 1
        if userProgress.currentLevel <= 0 {
            userProgress.currentLevel = 1
        }
        
        // Reset daily XP if it's a new day
        let today = Calendar.current.startOfDay(for: Date())
        let lastAwardDate = userProgress.lastCompletedDate.map { Calendar.current.startOfDay(for: $0) }
        
        if lastAwardDate == nil || today > lastAwardDate! {
            userProgress.dailyXP = 0
            saveXPData()
        }
        
        // Update level progress fields
        let currentLevelStartXP = Int(pow(Double(userProgress.currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(userProgress.currentLevel), 2) * 25)
        userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
        userProgress.xpForNextLevel = nextLevelStartXP - userProgress.totalXP
        
        print("🔍 XP DEBUG - loadXPData: totalXP=\(userProgress.totalXP), level=\(userProgress.currentLevel)")
        print("🔍 XP DEBUG - currentLevelStartXP=\(currentLevelStartXP), nextLevelStartXP=\(nextLevelStartXP)")
        print("🔍 XP DEBUG - xpForCurrentLevel=\(userProgress.xpForCurrentLevel), xpForNextLevel=\(userProgress.xpForNextLevel)")
    }
    
    // MARK: - XP Display Helpers
    
    /// Gets a friendly XP message for the celebration
    func getXPCelebrationMessage(earnedXP: Int, habitCount: Int) -> String {
        if habitCount == 1 {
            return "You earned \(earnedXP) XP!"
        } else {
            return "You earned \(earnedXP) XP for completing \(habitCount) habits!"
        }
    }
    
    /// Gets total XP with formatting
    func getFormattedTotalXP() -> String {
        if userProgress.totalXP >= 1000 {
            return String(format: "%.1fK", Double(userProgress.totalXP) / 1000.0)
        } else {
            return "\(userProgress.totalXP)"
        }
    }
    
    /// Gets daily XP with formatting
    func getFormattedDailyXP() -> String {
        return "\(userProgress.dailyXP)"
    }
    
    /// Resets all XP data (for testing purposes)
    func resetXPData() {
        userProgress.totalXP = 0
        userProgress.dailyXP = 0
        userProgress.currentLevel = 1
        userProgress.streakDays = 0
        userProgress.lastCompletedDate = nil
        // Update level progress fields with correct values
        let currentLevelStartXP = Int(pow(Double(userProgress.currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(userProgress.currentLevel), 2) * 25)
        userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
        userProgress.xpForNextLevel = nextLevelStartXP - userProgress.totalXP
        saveXPData()
        print("🔧 XP DEBUG - XP data reset to defaults")
    }
    
    /// Fix corrupted XP data by recalculating level and progress
    func fixXPData() {
        // Recalculate level based on total XP
        let newLevel = Int(sqrt(Double(userProgress.totalXP) / 25.0)) + 1
        userProgress.currentLevel = max(1, newLevel)
        
        // Recalculate progress fields
        let currentLevelStartXP = Int(pow(Double(userProgress.currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(userProgress.currentLevel), 2) * 25)
        userProgress.xpForCurrentLevel = userProgress.totalXP - currentLevelStartXP
        userProgress.xpForNextLevel = nextLevelStartXP - userProgress.totalXP
        
        saveXPData()
        print("🔧 XP DEBUG - Fixed XP data: level=\(userProgress.currentLevel), xpForCurrent=\(userProgress.xpForCurrentLevel), xpForNext=\(userProgress.xpForNextLevel)")
    }
    
    /// Check daily completion for habits (used by existing system)
    func checkDailyCompletion(habits: [Habit]) async {
        // This method is called by the existing system
        // We can implement additional logic here if needed
        print("🎯 Daily completion checked for \(habits.count) habits")
    }
    
    /// Reset daily XP (used by existing system)
    func resetDailyXP() {
        userProgress.dailyXP = 0
        saveXPData()
    }
    
    /// XP Rewards constants (used by existing system)
    struct XPRewards {
        static let completeAllHabits = 15  // Reduced from 50
        static let completeHabit = 5       // Reduced from 10
        static let streakBonus = 10        // Reduced from 25
        static let perfectWeek = 25        // Reduced from 100
        static let levelUp = 15            // Reduced from 50
        static let achievement = 10        // Reduced from 25
    }
}

// MARK: - XP Level System (Future Enhancement)
extension XPManager {
    /// Calculates user level based on total XP
    func calculateLevel() -> Int {
        // Balanced level calculation: Level = sqrt(totalXP / 25) + 1
        return Int(sqrt(Double(userProgress.totalXP) / 25.0)) + 1
    }
    
    /// Gets XP progress to next level
    func getXPProgressToNextLevel() -> (current: Int, needed: Int, percentage: Double) {
        let currentLevel = calculateLevel()
        let currentLevelStartXP = Int(pow(Double(currentLevel - 1), 2) * 25)
        let nextLevelStartXP = Int(pow(Double(currentLevel), 2) * 25)
        let currentXPInLevel = userProgress.totalXP - currentLevelStartXP
        let neededXP = nextLevelStartXP - userProgress.totalXP
        let xpNeededForNextLevel = nextLevelStartXP - currentLevelStartXP
        let percentage = Double(currentXPInLevel) / Double(xpNeededForNextLevel)
        
        return (current: currentXPInLevel, needed: neededXP, percentage: min(percentage, 1.0))
    }
}