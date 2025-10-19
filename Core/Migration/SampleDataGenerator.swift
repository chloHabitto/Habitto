import Foundation
import SwiftUI

/// SampleDataGenerator creates realistic test data for migration testing
///
/// **Test Cases:**
/// 1. Simple formation habit (daily)
/// 2. Breaking habit (daily)
/// 3. Frequency-based schedule (N days a week)
/// 4. Specific weekdays schedule
/// 5. Edge cases (no completions, weird schedules, etc.)
class SampleDataGenerator {
    
    /// Generate all test cases and save to UserDefaults
    static func generateTestData(userId: String) {
        print("🧪 Generating sample test data...")
        
        var testHabits: [Habit] = []
        
        // Test Case 1: Simple Formation Habit
        testHabits.append(createSimpleFormationHabit())
        
        // Test Case 2: Breaking Habit
        testHabits.append(createBreakingHabit())
        
        // Test Case 3: Frequency-Based Schedule (Weekly)
        testHabits.append(createFrequencyWeeklyHabit())
        
        // Test Case 4: Specific Weekdays
        testHabits.append(createSpecificWeekdaysHabit())
        
        // Test Case 5: Every N Days
        testHabits.append(createEveryNDaysHabit())
        
        // Test Case 6: Frequency Monthly
        testHabits.append(createFrequencyMonthlyHabit())
        
        // Test Case 7: Edge Case - No Completions
        testHabits.append(createHabitWithNoCompletions())
        
        // Test Case 8: Edge Case - Very Old Data
        testHabits.append(createVeryOldHabit())
        
        // Test Case 9: Edge Case - Different Goal Units
        testHabits.append(createHabitWithMinutes())
        testHabits.append(createHabitWithSteps())
        
        // Save to UserDefaults (old system storage)
        Habit.saveHabits(testHabits)
        
        // Generate XP data
        generateXPData(userId: userId, habits: testHabits)
        
        print("✅ Generated \(testHabits.count) test habits")
        print("📊 Total completion records: \(testHabits.reduce(0) { $0 + $1.completionHistory.count + $1.actualUsage.count })")
    }
    
    // MARK: - Test Case 1: Simple Formation Habit
    
    private static func createSimpleFormationHabit() -> Habit {
        var habit = Habit(
            name: "Morning Run",
            description: "Run every morning to stay healthy",
            icon: "figure.run",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "5 times",
            reminder: "",
            startDate: Date()
        )
        
        // Add 7 days of completions (5, 3, 5, 5, 2, 5, 5)
        let today = Date()
        for daysAgo in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            let dateString = formatDate(date)
            let completionCount = [5, 3, 5, 5, 2, 5, 5][daysAgo]
            habit.completionHistory[dateString] = completionCount
        }
        
        return habit
    }
    
    // MARK: - Test Case 2: Breaking Habit
    
    private static func createBreakingHabit() -> Habit {
        var habit = Habit(
            name: "Reduce Coffee",
            description: "Reduce coffee intake for better sleep",
            icon: "cup.and.saucer.fill",
            color: .brown,
            habitType: .breaking,
            schedule: "Everyday",
            goal: "3 cups",
            reminder: "",
            startDate: Date(),
            baseline: 10,
            target: 3
        )
        
        // Add actualUsage (breaking habits track usage, not completions)
        let today = Date()
        for daysAgo in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            let dateString = formatDate(date)
            let usageCount = [2, 3, 4, 3, 2, 1, 3][daysAgo] // Some days under goal, some over
            habit.actualUsage[dateString] = usageCount
        }
        
        return habit
    }
    
    // MARK: - Test Case 3: Frequency-Based Schedule (Weekly)
    
    private static func createFrequencyWeeklyHabit() -> Habit {
        var habit = Habit(
            name: "Gym Session",
            description: "Hit the gym 3 times a week",
            icon: "dumbbell.fill",
            color: .red,
            habitType: .formation,
            schedule: "3 days a week",
            goal: "1 time",
            reminder: "",
            startDate: Date()
        )
        
        // Add completions for this week (3 completions)
        let today = Date()
        habit.completionHistory[formatDate(today)] = 1
        habit.completionHistory[formatDate(Calendar.current.date(byAdding: .day, value: -2, to: today)!)] = 1
        habit.completionHistory[formatDate(Calendar.current.date(byAdding: .day, value: -4, to: today)!)] = 1
        
        return habit
    }
    
    // MARK: - Test Case 4: Specific Weekdays
    
    private static func createSpecificWeekdaysHabit() -> Habit {
        var habit = Habit(
            name: "Team Meeting",
            description: "Weekly team sync meetings",
            icon: "person.3.fill",
            color: .purple,
            habitType: .formation,
            schedule: "Every Monday, Wednesday, Friday",
            goal: "1 time",
            reminder: "",
            startDate: Date()
        )
        
        // Add completions for last 2 weeks
        let today = Date()
        for daysAgo in 0..<14 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            let weekday = Calendar.current.component(.weekday, from: date)
            
            // Monday=2, Wednesday=4, Friday=6 in Calendar.Weekday
            if [2, 4, 6].contains(weekday) {
                habit.completionHistory[formatDate(date)] = 1
            }
        }
        
        return habit
    }
    
    // MARK: - Test Case 5: Every N Days
    
    private static func createEveryNDaysHabit() -> Habit {
        var habit = Habit(
            name: "Deep Clean",
            description: "Deep clean the house",
            icon: "sparkles",
            color: .green,
            habitType: .formation,
            schedule: "Every 3 days",
            goal: "1 time",
            reminder: "",
            startDate: Date()
        )
        
        // Add completions every 3 days
        let today = Date()
        for daysAgo in stride(from: 0, to: 15, by: 3) {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            habit.completionHistory[formatDate(date)] = 1
        }
        
        return habit
    }
    
    // MARK: - Test Case 6: Frequency Monthly
    
    private static func createFrequencyMonthlyHabit() -> Habit {
        var habit = Habit(
            name: "Call Family",
            description: "Stay in touch with family",
            icon: "phone.fill",
            color: .orange,
            habitType: .formation,
            schedule: "5 days a month",
            goal: "1 time",
            reminder: "",
            startDate: Date()
        )
        
        // Add 5 completions this month
        let today = Date()
        for day in [1, 5, 10, 15, 20] {
            let date = Calendar.current.date(byAdding: .day, value: -day, to: today)!
            habit.completionHistory[formatDate(date)] = 1
        }
        
        return habit
    }
    
    // MARK: - Test Case 7: Edge Case - No Completions
    
    private static func createHabitWithNoCompletions() -> Habit {
        let habit = Habit(
            name: "Learn Spanish",
            description: "Practice Spanish daily",
            icon: "book.fill",
            color: .yellow,
            habitType: .formation,
            schedule: "Everyday",
            goal: "30 minutes",
            reminder: "",
            startDate: Date()
        )
        
        // No completions - just created
        return habit
    }
    
    // MARK: - Test Case 8: Edge Case - Very Old Data
    
    private static func createVeryOldHabit() -> Habit {
        var habit = Habit(
            name: "Meditation",
            description: "Daily meditation practice",
            icon: "leaf.fill",
            color: .mint,
            habitType: .formation,
            schedule: "Everyday",
            goal: "10 minutes",
            reminder: "",
            startDate: Date()
        )
        
        // Add old completions from 1 year ago
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        for daysAgo in 0..<30 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: oneYearAgo)!
            habit.completionHistory[formatDate(date)] = 1
        }
        
        return habit
    }
    
    // MARK: - Test Case 9: Different Goal Units
    
    private static func createHabitWithMinutes() -> Habit {
        var habit = Habit(
            name: "Read Books",
            description: "Reading time",
            icon: "book.pages.fill",
            color: .indigo,
            habitType: .formation,
            schedule: "Everyday",
            goal: "30 minutes",
            reminder: "",
            startDate: Date()
        )
        
        // Add completions with minute tracking
        let today = Date()
        for daysAgo in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            habit.completionHistory[formatDate(date)] = [30, 25, 30, 15, 30][daysAgo]
        }
        
        return habit
    }
    
    private static func createHabitWithSteps() -> Habit {
        var habit = Habit(
            name: "Daily Steps",
            description: "Walk 10k steps daily",
            icon: "figure.walk",
            color: .cyan,
            habitType: .formation,
            schedule: "Everyday",
            goal: "10000 steps",
            reminder: "",
            startDate: Date()
        )
        
        // Add completions with step tracking
        let today = Date()
        for daysAgo in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            habit.completionHistory[formatDate(date)] = [10500, 9800, 10200, 8500, 10000][daysAgo]
        }
        
        return habit
    }
    
    // MARK: - XP Data Generation
    
    private static func generateXPData(userId: String, habits: [Habit]) {
        // Calculate realistic XP based on habit completions
        var totalXP = 0
        
        // Award XP for each completed day
        // Assume each complete day = 100 XP
        for habit in habits {
            let completedDays = habit.habitType == .breaking
                ? habit.actualUsage.count
                : habit.completionHistory.count
            totalXP += completedDays * 50 // 50 XP per habit completion
        }
        
        // Add some bonus XP
        totalXP += 500 // Welcome bonus
        
        // Save to UserDefaults (old XPManager storage)
        UserDefaults.standard.set(totalXP, forKey: "total_xp_\(userId)")
        
        let level = totalXP / 1000 // Simplified level calculation
        UserDefaults.standard.set(level, forKey: "current_level_\(userId)")
        
        print("💎 Generated XP: \(totalXP) (Level \(level))")
    }
    
    // MARK: - Helpers
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // MARK: - Cleanup
    
    /// Clear all test data
    static func clearTestData(userId: String) {
        // Clear habits
        Habit.saveHabits([])
        
        // Clear XP
        UserDefaults.standard.removeObject(forKey: "total_xp_\(userId)")
        UserDefaults.standard.removeObject(forKey: "current_level_\(userId)")
        UserDefaults.standard.removeObject(forKey: "xp_history_\(userId)")
        
        print("🗑️ Test data cleared")
    }
}

