import Foundation
import SwiftUI
import SwiftData

// MARK: - Fake Data Generator for Alex's Scenario
/// Creates realistic fake data for testing the app with a 3-month user story
@MainActor
class FakeDataGenerator: ObservableObject {
    static let shared = FakeDataGenerator()
    
    private let modelContext: ModelContext
    private let habitRepository: HabitRepository
    
    // Alex's user ID (guest mode)
    private let alexUserId = "" // Guest mode uses empty string
    
    // MARK: - Alex's Habit Definitions
    
    private let alexHabits = [
        HabitDefinition(
            name: "Morning Meditation",
            description: "Start each day with 10 minutes of mindfulness",
            icon: "🧘‍♀️",
            color: Color.purple,
            habitType: .formation,
            schedule: "Everyday",
            goal: "10 minutes",
            successRate: 0.85,
            difficulty: 4.2,
            baseline: 0,
            target: 1
        ),
        HabitDefinition(
            name: "Gym Workout",
            description: "Strength training and cardio at the gym",
            icon: "💪",
            color: Color.red,
            habitType: .formation,
            schedule: "Weekdays",
            goal: "45 minutes",
            successRate: 0.70,
            difficulty: 6.8,
            baseline: 0,
            target: 1
        ),
        HabitDefinition(
            name: "Daily Reading",
            description: "Read at least one chapter from a book",
            icon: "📚",
            color: Color.blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "1 chapter",
            successRate: 0.90,
            difficulty: 3.1,
            baseline: 0,
            target: 1
        ),
        HabitDefinition(
            name: "Reduce Social Media",
            description: "Limit social media usage to 30 minutes per day",
            icon: "📱",
            color: Color.orange,
            habitType: .breaking,
            schedule: "Everyday",
            goal: "30 minutes max",
            successRate: 0.60,
            difficulty: 7.5,
            baseline: 120, // 2 hours baseline
            target: 30
        ),
        HabitDefinition(
            name: "Quit Smoking",
            description: "Stay smoke-free for the day",
            icon: "🚭",
            color: Color.gray,
            habitType: .breaking,
            schedule: "Everyday",
            goal: "0 cigarettes",
            successRate: 0.45,
            difficulty: 8.9,
            baseline: 10, // 10 cigarettes baseline
            target: 0
        ),
        HabitDefinition(
            name: "Drink 8 Glasses Water",
            description: "Stay hydrated throughout the day",
            icon: "💧",
            color: Color.cyan,
            habitType: .formation,
            schedule: "Everyday",
            goal: "8 glasses",
            successRate: 0.75,
            difficulty: 5.2,
            baseline: 0,
            target: 8
        ),
        HabitDefinition(
            name: "Sleep Schedule",
            description: "Go to bed by 10:30 PM every night",
            icon: "😴",
            color: Color.indigo,
            habitType: .formation,
            schedule: "Everyday",
            goal: "10:30 PM",
            successRate: 0.65,
            difficulty: 6.0,
            baseline: 0,
            target: 1
        ),
        HabitDefinition(
            name: "Reduce Sugar",
            description: "Limit added sugar to 25g per day",
            icon: "🍰",
            color: Color.pink,
            habitType: .breaking,
            schedule: "Everyday",
            goal: "25g max",
            successRate: 0.55,
            difficulty: 7.0,
            baseline: 50, // 50g baseline
            target: 25
        )
    ]
    
    init() {
        // Get the shared SwiftData container
        let container = SwiftDataContainer.shared
        self.modelContext = container.modelContext
        self.habitRepository = HabitRepository.shared
    }
    
    // MARK: - Main Injection Method
    
    /// Inject Alex's complete fake data scenario
    func injectAlexData() async throws {
        print("🧪 FakeDataGenerator: Starting Alex's data injection...")
        
        // Debug authentication state
        let currentUser = AuthenticationManager.shared.currentUser
        let authState = AuthenticationManager.shared.authState
        print("🧪 FakeDataGenerator: Current auth state: \(authState)")
        print("🧪 FakeDataGenerator: Current user: \(currentUser?.uid ?? "nil")")
        
        // Clear existing data first
        try await clearAllData()
        
        // Generate habits with completion history
        let habits = try await generateAlexHabits()
        
        // Save habits to repository
        for habit in habits {
            print("🧪 FakeDataGenerator: Creating habit: \(habit.name)")
            await habitRepository.createHabit(habit)
        }
        
        // Generate and save XP data
        try await generateAlexXPData(habits: habits)
        
        // Generate vacation history
        try await generateAlexVacationHistory()
        
        print("🧪 FakeDataGenerator: ✅ Alex's data injection complete!")
        print("🧪 FakeDataGenerator: Created \(habits.count) habits with 3 months of history")
        
        // Force refresh the repository to show the new data
        await habitRepository.loadHabits(force: true)
        print("🧪 FakeDataGenerator: Repository refreshed, now has \(habitRepository.habits.count) habits")
    }
    
    // MARK: - Data Generation Methods
    
    private func generateAlexHabits() async throws -> [Habit] {
        var habits: [Habit] = []
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        for (index, habitDef) in alexHabits.enumerated() {
            // Generate 3 months of completion history first
            let tempHabit = Habit(
                id: UUID(),
                name: habitDef.name,
                description: habitDef.description,
                icon: habitDef.icon,
                color: habitDef.color,
                habitType: habitDef.habitType,
                schedule: habitDef.schedule,
                goal: habitDef.goal,
                reminder: "No reminder",
                startDate: startDate,
                endDate: nil,
                createdAt: startDate,
                reminders: [],
                baseline: habitDef.baseline,
                target: habitDef.target,
                completionHistory: [:],
                completionTimestamps: [:],
                difficultyHistory: [:],
                actualUsage: [:]
            )
            
            let completionData = generateCompletionHistory(
                for: tempHabit,
                startDate: startDate,
                successRate: habitDef.successRate,
                difficulty: habitDef.difficulty,
                schedule: habitDef.schedule
            )
            
            // Create final habit with completion history
            var habit = Habit(
                id: UUID(),
                name: habitDef.name,
                description: habitDef.description,
                icon: habitDef.icon,
                color: habitDef.color,
                habitType: habitDef.habitType,
                schedule: habitDef.schedule,
                goal: habitDef.goal,
                reminder: "No reminder",
                startDate: startDate,
                endDate: nil,
                createdAt: startDate,
                reminders: [],
                baseline: habitDef.baseline,
                target: habitDef.target,
                completionHistory: completionData.completionHistory,
                completionTimestamps: completionData.completionTimestamps,
                difficultyHistory: completionData.difficultyHistory,
                actualUsage: completionData.actualUsage
            )
            
            // Mark some habits as inactive
            if index >= 6 {
                // Sleep Schedule - paused 2 weeks ago
                if index == 6 {
                    habit = Habit(
                        id: habit.id,
                        name: habit.name,
                        description: habit.description,
                        icon: habit.icon,
                        color: habit.color,
                        habitType: habit.habitType,
                        schedule: habit.schedule,
                        goal: habit.goal,
                        reminder: habit.reminder,
                        startDate: habit.startDate,
                        endDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()),
                        createdAt: habit.createdAt,
                        reminders: habit.reminders,
                        baseline: habit.baseline,
                        target: habit.target,
                        completionHistory: habit.completionHistory,
                        completionTimestamps: habit.completionTimestamps,
                        difficultyHistory: habit.difficultyHistory,
                        actualUsage: habit.actualUsage
                    )
                }
                // Reduce Sugar - abandoned 1 month ago
                if index == 7 {
                    habit = Habit(
                        id: habit.id,
                        name: habit.name,
                        description: habit.description,
                        icon: habit.icon,
                        color: habit.color,
                        habitType: habit.habitType,
                        schedule: habit.schedule,
                        goal: habit.goal,
                        reminder: habit.reminder,
                        startDate: habit.startDate,
                        endDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                        createdAt: habit.createdAt,
                        reminders: habit.reminders,
                        baseline: habit.baseline,
                        target: habit.target,
                        completionHistory: habit.completionHistory,
                        completionTimestamps: habit.completionTimestamps,
                        difficultyHistory: habit.difficultyHistory,
                        actualUsage: habit.actualUsage
                    )
                }
            }
            
            habits.append(habit)
        }
        
        return habits
    }
    
    private func generateCompletionHistory(
        for habit: Habit,
        startDate: Date,
        successRate: Double,
        difficulty: Double,
        schedule: String
    ) -> (completionHistory: [String: Int], completionTimestamps: [String: [Date]], difficultyHistory: [String: Int], actualUsage: [String: Int]) {
        
        var completionHistory: [String: Int] = [:]
        var completionTimestamps: [String: [Date]] = [:]
        var difficultyHistory: [String: Int] = [:]
        var actualUsage: [String: Int] = [:]
        
        let calendar = Calendar.current
        let today = Date()
        var currentDate = startDate
        
        while currentDate <= today {
            let dateKey = DateUtils.dateKey(for: currentDate)
            
            // Check if habit should be active on this date
            if shouldShowHabitOnDate(habit: habit, date: currentDate, schedule: schedule) {
                // Determine if habit was completed based on success rate
                let shouldComplete = Double.random(in: 0...1) < successRate
                
                if shouldComplete {
                    // Mark as completed
                    completionHistory[dateKey] = 1
                    
                    // Add completion timestamp (random time during the day)
                    let completionTime = generateCompletionTime(for: currentDate)
                    completionTimestamps[dateKey] = [completionTime]
                    
                    // Add difficulty rating (variation around average)
                    let difficultyVariation = Double.random(in: -2...2)
                    let dailyDifficulty = max(1, min(10, Int(difficulty + difficultyVariation)))
                    difficultyHistory[dateKey] = dailyDifficulty
                    
                    // Add actual usage for habit breaking types
                    if habit.habitType == .breaking {
                        let baselineVariation = Double.random(in: 0.8...1.2)
                        actualUsage[dateKey] = Int(Double(habit.target) * baselineVariation)
                    }
                } else {
                    // Not completed
                    completionHistory[dateKey] = 0
                    difficultyHistory[dateKey] = Int(difficulty)
                    
                    // For habit breaking, actual usage might be higher
                    if habit.habitType == .breaking {
                        let overuseFactor = Double.random(in: 1.2...2.0)
                        actualUsage[dateKey] = Int(Double(habit.baseline) * overuseFactor)
                    }
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return (completionHistory, completionTimestamps, difficultyHistory, actualUsage)
    }
    
    private func shouldShowHabitOnDate(habit: Habit, date: Date, schedule: String) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch schedule {
        case "Everyday":
            return true
        case "Weekdays":
            return weekday >= 2 && weekday <= 6 // Monday to Friday
        case "Weekends":
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        default:
            return true
        }
    }
    
    private func generateCompletionTime(for date: Date) -> Date {
        let calendar = Calendar.current
        let hour = Int.random(in: 6...22) // Between 6 AM and 10 PM
        let minute = Int.random(in: 0...59)
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components) ?? date
    }
    
    private func generateAlexXPData(habits: [Habit]) async throws {
        print("🧪 FakeDataGenerator: Generating Alex's XP data...")
        
        // Calculate total XP based on completion history
        var totalXP = 0
        let calendar = Calendar.current
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let today = Date()
        var currentDate = startDate
        
        while currentDate <= today {
            let dateKey = DateUtils.dateKey(for: currentDate)
            
            // Count completed habits for this day
            var completedHabits = 0
            var dailyXP = 0
            
            for habit in habits {
                if habit.completionHistory[dateKey] == 1 {
                    completedHabits += 1
                    
                    // Base XP for habit completion
                    dailyXP += 5
                    
                    // Streak bonus (simplified calculation)
                    let streak = calculateStreakForHabit(habit, upTo: currentDate)
                    if streak >= 7 {
                        dailyXP += 5 // Streak bonus
                    }
                }
            }
            
            // All habits bonus
            if completedHabits == habits.count && completedHabits > 0 {
                dailyXP += 15
            }
            
            totalXP += dailyXP
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add some level-up bonuses (Alex reached level 3)
        totalXP += 50 // Level 2 bonus
        totalXP += 25 // Level 3 bonus
        
        print("🧪 FakeDataGenerator: Total XP calculated: \(totalXP)")
        
        // Update XPManager with calculated XP
        let xpManager = XPManager.shared
        // Set to target XP that gives us Level 3
        let targetXP = 2310 // This should give us Level 3: √(2310/300) + 1 = √7.7 + 1 = 2.77 + 1 = 3
        xpManager.userProgress.totalXP = targetXP
        xpManager.updateLevelFromXP()
        xpManager.saveUserProgress()
        
        print("🧪 FakeDataGenerator: ✅ XP data generated - Level \(xpManager.userProgress.currentLevel), \(xpManager.userProgress.totalXP) XP")
    }
    
    private func calculateStreakForHabit(_ habit: Habit, upTo date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = date
        
        while true {
            let dateKey = DateUtils.dateKey(for: currentDate)
            if habit.completionHistory[dateKey] == 1 {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func generateAlexVacationHistory() async throws {
        print("🧪 FakeDataGenerator: Generating Alex's vacation history...")
        
        // Alex had two vacation periods:
        // 1. Feb 15-19: 5 days (skiing trip)
        // 2. Mar 8-9: 2 days (weekend getaway)
        
        // Note: Vacation history would be stored in VacationManager
        // For now, we'll just log the vacation periods
        print("🧪 FakeDataGenerator: Alex's vacation history:")
        print("  - Feb 15-19: 5 days (skiing trip)")
        print("  - Mar 8-9: 2 days (weekend getaway)")
        print("  - Total: 7 vacation days")
    }
    
    private func clearAllData() async throws {
        print("🧪 FakeDataGenerator: Clearing existing data...")
        
        // Clear habits from repository
        let existingHabits = habitRepository.habits
        for habit in existingHabits {
            habitRepository.deleteHabit(habit)
        }
        
        // Clear XP data
        XPManager.shared.clearXPData()
        
        print("🧪 FakeDataGenerator: ✅ Existing data cleared")
    }
    
    // MARK: - Debug Methods
    
    func printAlexDataSummary() {
        print("🧪 FakeDataGenerator: === ALEX'S DATA SUMMARY ===")
        print("🧪 FakeDataGenerator: Habits: \(habitRepository.habits.count)")
        print("🧪 FakeDataGenerator: XP Level: \(XPManager.shared.userProgress.currentLevel)")
        print("🧪 FakeDataGenerator: Total XP: \(XPManager.shared.userProgress.totalXP)")
        
        for habit in habitRepository.habits {
            let completionCount = habit.completionHistory.values.reduce(0, +)
            print("🧪 FakeDataGenerator: \(habit.name): \(completionCount) completions")
        }
        
        print("🧪 FakeDataGenerator: === END SUMMARY ===")
    }
}

// MARK: - Supporting Structures

private struct HabitDefinition {
    let name: String
    let description: String
    let icon: String
    let color: Color
    let habitType: HabitType
    let schedule: String
    let goal: String
    let successRate: Double
    let difficulty: Double
    let baseline: Int
    let target: Int
}

