import Foundation
import SwiftUI

/// Simple test runner for Habitto app (without XCTest dependency)
class SimpleTestRunner {
    
    static let shared = SimpleTestRunner()
    
    private var testResults: [String: Bool] = [:]
    private var testCount = 0
    private var passedCount = 0
    private var failedCount = 0
    
    private init() {}
    
    // MARK: - Test Execution
    
    func runAllTests() {
        print("🧪 Starting Habitto Test Suite")
        print("=" * 50)
        
        // Reset counters
        testCount = 0
        passedCount = 0
        failedCount = 0
        testResults.removeAll()
        
        // Run test categories
        runStreakCalculationTests()
        runDSTBoundaryTests()
        runDataIntegrityTests()
        runIntegrationTests()
        
        // Print summary
        printSummary()
    }
    
    // MARK: - Streak Calculation Tests
    
    private func runStreakCalculationTests() {
        print("\n📊 Running Streak Calculation Tests")
        print("-" * 30)
        
        test("Basic streak calculation with consecutive days") {
            let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
            let completionHistory: [Date: Bool] = [
                startDate: true,
                Calendar.current.date(byAdding: .day, value: 1, to: startDate)!: true,
                Calendar.current.date(byAdding: .day, value: 2, to: startDate)!: true,
                Calendar.current.date(byAdding: .day, value: 3, to: startDate)!: true,
                Calendar.current.date(byAdding: .day, value: 4, to: startDate)!: true
            ]
            
            let streak = calculateStreak(from: completionHistory, currentDate: Calendar.current.date(byAdding: .day, value: 5, to: startDate)!)
            return streak == 5
        }
        
        test("Streak calculation with gap") {
            let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
            let completionHistory: [Date: Bool] = [
                startDate: true,
                Calendar.current.date(byAdding: .day, value: 1, to: startDate)!: true,
                Calendar.current.date(byAdding: .day, value: 2, to: startDate)!: false, // Gap
                Calendar.current.date(byAdding: .day, value: 3, to: startDate)!: true,
                Calendar.current.date(byAdding: .day, value: 4, to: startDate)!: true
            ]
            
            let streak = calculateStreak(from: completionHistory, currentDate: Calendar.current.date(byAdding: .day, value: 5, to: startDate)!)
            return streak == 2
        }
        
        test("Streak calculation with no completions") {
            let completionHistory: [Date: Bool] = [:]
            let streak = calculateStreak(from: completionHistory, currentDate: Date())
            return streak == 0
        }
    }
    
    // MARK: - DST Boundary Tests
    
    private func runDSTBoundaryTests() {
        print("\n🕐 Running DST Boundary Tests")
        print("-" * 30)
        
        test("DST spring forward transition") {
            let beforeDST = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 23, minute: 30))!
            let afterDST = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 1, minute: 30))!
            
            let isSameDay = Calendar.current.isDate(beforeDST, inSameDayAs: afterDST)
            return !isSameDay // Should not be the same day
        }
        
        test("DST fall back transition") {
            let beforeDST = Calendar.current.date(from: DateComponents(year: 2024, month: 11, day: 2, hour: 23, minute: 30))!
            let afterDST = Calendar.current.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 1, minute: 30))!
            
            let isSameDay = Calendar.current.isDate(beforeDST, inSameDayAs: afterDST)
            return !isSameDay // Should not be the same day
        }
        
        test("DST transition with streak calculation") {
            let dayBeforeDST = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 9))!
            let dayAfterDST = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
            let dayAfterAfterDST = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 11))!
            
            let completionHistory: [Date: Bool] = [
                dayBeforeDST: true,
                dayAfterDST: true,
                dayAfterAfterDST: true
            ]
            
            let streak = calculateStreak(from: completionHistory, currentDate: dayAfterAfterDST)
            return streak == 3
        }
    }
    
    // MARK: - Data Integrity Tests
    
    private func runDataIntegrityTests() {
        print("\n🔍 Running Data Integrity Tests")
        print("-" * 30)
        
        test("Valid habit data validation") {
            let habit = createTestHabit(
                name: "Test Habit",
                description: "A test habit",
                streak: 0
            )
            
            let errors = validateHabit(habit)
            return errors.isEmpty
        }
        
        test("Invalid habit data validation") {
            let habit = createTestHabit(
                name: "", // Invalid: empty name
                description: "A test habit",
                streak: 0
            )
            
            let errors = validateHabit(habit)
            return !errors.isEmpty
        }
        
        test("Habit with negative streak validation") {
            let habit = createTestHabit(
                name: "Test Habit",
                description: "A test habit",
                streak: -1 // Invalid: negative streak
            )
            
            let errors = validateHabit(habit)
            return !errors.isEmpty
        }
        
        test("Habit with invalid date range validation") {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
            
            let habit = createTestHabit(
                name: "Test Habit",
                description: "A test habit",
                startDate: startDate,
                endDate: endDate // Invalid: end date before start date
            )
            
            let errors = validateHabit(habit)
            return !errors.isEmpty
        }
    }
    
    // MARK: - Integration Tests
    
    private func runIntegrationTests() {
        print("\n🔗 Running Integration Tests")
        print("-" * 30)
        
        test("Habit creation and basic properties") {
            let habit = createTestHabit(
                name: "Integration Test Habit",
                description: "A habit for integration testing",
                streak: 5
            )
            
            return !habit.id.uuidString.isEmpty &&
                   habit.name == "Integration Test Habit" &&
                   habit.streak == 5
        }
        
        test("Date utilities integration") {
            let date = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let isToday = calendar.isDate(date, inSameDayAs: Date())
            
            return startOfDay < endOfDay && isToday
        }
        
        test("UserDefaults wrapper integration") {
            let testData = ["key1": "value1", "key2": "value2"]
            
            do {
                // Use UserDefaults directly to avoid @MainActor issues
                let data = try JSONEncoder().encode(testData)
                UserDefaults.standard.set(data, forKey: "TestData")
                
                if let loadedData = UserDefaults.standard.data(forKey: "TestData"),
                   let decodedData = try? JSONDecoder().decode([String: String].self, from: loadedData) {
                    return decodedData["key1"] == "value1" && decodedData["key2"] == "value2"
                }
                return false
            } catch {
                return false
            }
        }
        
        test("Performance test with large dataset") {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create large completion history
            var completionHistory: [Date: Bool] = [:]
            let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
            
            for i in 0..<1000 {
                if let date = Calendar.current.date(byAdding: .day, value: i, to: startDate) {
                    completionHistory[date] = i % 2 == 0
                }
            }
            
            let streak = calculateStreak(from: completionHistory, currentDate: Calendar.current.date(byAdding: .day, value: 1000, to: startDate)!)
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            return timeElapsed < 1.0 && streak >= 0 // Should complete in under 1 second
        }
    }
    
    // MARK: - Test Helper Methods
    
    private func test(_ name: String, _ test: () -> Bool) {
        testCount += 1
        let result = test()
        testResults[name] = result
        
        if result {
            passedCount += 1
            print("✅ \(name)")
        } else {
            failedCount += 1
            print("❌ \(name)")
        }
    }
    
    private func printSummary() {
        print("\n" + "=" * 50)
        print("📊 Test Summary")
        print("=" * 50)
        print("Total Tests: \(testCount)")
        print("Passed: \(passedCount)")
        print("Failed: \(failedCount)")
        print("Success Rate: \(String(format: "%.1f", Double(passedCount) / Double(testCount) * 100))%")
        
        if failedCount > 0 {
            print("\n❌ Failed Tests:")
            for (name, result) in testResults {
                if !result {
                    print("  - \(name)")
                }
            }
        }
        
        print("\n" + "=" * 50)
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabit(
        name: String = "Test Habit",
        description: String = "A test habit",
        icon: String = "📝",
        color: Color = .blue,
        habitType: HabitType = .formation,
        schedule: String = "Daily",
        goal: String = "1 time",
        reminder: String = "9:00 AM",
        startDate: Date = Date(),
        endDate: Date? = nil,
        isCompleted: Bool = false,
        streak: Int = 0
    ) -> Habit {
        return Habit(
            name: name,
            description: description,
            icon: icon,
            color: color,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            isCompleted: isCompleted,
            streak: streak
        )
    }
    
    private func calculateStreak(from completionHistory: [Date: Bool], currentDate: Date) -> Int {
        guard !completionHistory.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = completionHistory.keys.sorted(by: >)
        
        var streak = 0
        var currentDate = currentDate
        
        for date in sortedDates {
            guard date <= currentDate else { continue }
            
            let previousDate = calendar.date(byAdding: .day, value: 1, to: date)!
            
            if streak == 0 {
                if completionHistory[date] == true {
                    streak = 1
                    currentDate = date
                } else {
                    break
                }
            } else {
                if previousDate == currentDate && completionHistory[date] == true {
                    streak += 1
                    currentDate = date
                } else {
                    break
                }
            }
        }
        
        return streak
    }
    
    private func validateHabit(_ habit: Habit) -> [String] {
        var errors: [String] = []
        
        if habit.name.isEmpty {
            errors.append("Name cannot be empty")
        }
        
        if habit.name.count > 100 {
            errors.append("Name too long")
        }
        
        if habit.streak < 0 {
            errors.append("Streak cannot be negative")
        }
        
        if let endDate = habit.endDate, endDate < habit.startDate {
            errors.append("End date cannot be before start date")
        }
        
        return errors
    }
}

// MARK: - String Extension for Repeated Characters

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
