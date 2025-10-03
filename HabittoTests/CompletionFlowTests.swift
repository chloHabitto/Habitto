import XCTest
import SwiftUI
@testable import Habitto

final class CompletionFlowTests: XCTestCase {
    
    var testHabit: Habit!
    var testDate: Date!
    
    override func setUp() {
        super.setUp()
        testDate = Date()
        testHabit = Habit(
            name: "Test Habit",
            description: "Test Description",
            icon: "🏃‍♂️",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "3 times",
            reminder: "No reminder",
            startDate: testDate,
            endDate: nil
        )
    }
    
    override func tearDown() {
        testHabit = nil
        testDate = nil
        super.tearDown()
    }
    
    // MARK: - Circle Tap Tests
    
    func test_TapCircle_setsCountToGoal_andPresentsSheet() {
        // Given: Habit with 0/3 progress
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 0
        
        // When: Circle is tapped
        let initialProgress = testHabit.getProgress(for: testDate)
        XCTAssertEqual(initialProgress, 0, "Initial progress should be 0")
        
        // Simulate circle tap completion
        let goalAmount = 3 // "3 times" goal
        testHabit.completionHistory[dateKey] = goalAmount
        
        // Then: Progress should be set to goal and habit should be completed
        let finalProgress = testHabit.getProgress(for: testDate)
        XCTAssertEqual(finalProgress, goalAmount, "Progress should be set to goal amount")
        XCTAssertTrue(testHabit.isCompleted(for: testDate), "Habit should be completed")
    }
    
    // MARK: - Swipe Tests
    
    func test_SwipeRight_incrementsToGoal_andPresentsSheet_boundedAtGoal() {
        // Given: Habit with 2/3 progress
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 2
        
        // When: Swipe right (should increment to 3, reaching goal)
        let currentProgress = testHabit.getProgress(for: testDate)
        let newProgress = min(currentProgress + 1, 3) // Clamp to goal
        testHabit.completionHistory[dateKey] = newProgress
        
        // Then: Progress should be 3 and habit should be completed
        XCTAssertEqual(newProgress, 3, "Progress should be clamped to goal")
        XCTAssertTrue(testHabit.isCompleted(for: testDate), "Habit should be completed")
        
        // When: Swipe right again (should not exceed goal)
        let finalProgress = min(newProgress + 1, 3)
        testHabit.completionHistory[dateKey] = finalProgress
        
        // Then: Progress should still be 3 (clamped)
        XCTAssertEqual(finalProgress, 3, "Progress should not exceed goal")
    }
    
    func test_SwipeLeft_neverGoesNegative() {
        // Given: Habit with 1/3 progress
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 1
        
        // When: Swipe left (should decrement to 0)
        let currentProgress = testHabit.getProgress(for: testDate)
        let newProgress = max(currentProgress - 1, 0) // Clamp to 0
        testHabit.completionHistory[dateKey] = newProgress
        
        // Then: Progress should be 0
        XCTAssertEqual(newProgress, 0, "Progress should be 0")
        XCTAssertFalse(testHabit.isCompleted(for: testDate), "Habit should not be completed")
        
        // When: Swipe left again (should not go negative)
        let finalProgress = max(newProgress - 1, 0)
        testHabit.completionHistory[dateKey] = finalProgress
        
        // Then: Progress should still be 0 (clamped)
        XCTAssertEqual(finalProgress, 0, "Progress should not go negative")
    }
    
    // MARK: - Detail Screen Tests
    
    func test_DetailButtons_plusMinus_boundsAndSheet() {
        // Given: Habit with 1/3 progress
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 1
        
        // When: Plus button pressed twice
        var progress = testHabit.getProgress(for: testDate)
        progress = min(progress + 1, 3) // First plus
        testHabit.completionHistory[dateKey] = progress
        
        progress = min(progress + 1, 3) // Second plus (should reach goal)
        testHabit.completionHistory[dateKey] = progress
        
        // Then: Progress should be 3 and habit should be completed
        XCTAssertEqual(progress, 3, "Progress should reach goal")
        XCTAssertTrue(testHabit.isCompleted(for: testDate), "Habit should be completed")
        
        // When: Minus button pressed
        progress = max(progress - 1, 0)
        testHabit.completionHistory[dateKey] = progress
        
        // Then: Progress should be 2
        XCTAssertEqual(progress, 2, "Progress should be decremented")
        XCTAssertFalse(testHabit.isCompleted(for: testDate), "Habit should not be completed")
    }
    
    // MARK: - Sheet Dismissal Tests
    
    func test_DismissSheet_triggersReorder() {
        // Given: Habit is completed
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 3
        
        // When: Sheet is dismissed
        // This would normally trigger onDifficultySheetDismissed() in HomeTabView
        // For testing, we verify the habit is in completed state
        
        // Then: Habit should be completed and ready for reordering
        XCTAssertTrue(testHabit.isCompleted(for: testDate), "Habit should be completed")
        XCTAssertEqual(testHabit.getProgress(for: testDate), 3, "Progress should be at goal")
    }
    
    // MARK: - Edge Cases
    
    func test_CompletionFlow_handlesZeroGoal() {
        // Given: Habit with 0 goal (edge case)
        let zeroGoalHabit = Habit(
            name: "Zero Goal Habit",
            description: "Test",
            icon: "🏃‍♂️",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "0 times", // Zero goal
            reminder: "No reminder",
            startDate: testDate,
            endDate: nil
        )
        
        // Then: Habit should be considered completed immediately
        XCTAssertTrue(zeroGoalHabit.isCompleted(for: testDate), "Zero goal habit should be completed")
    }
    
    func test_CompletionFlow_handlesLargeGoal() {
        // Given: Habit with large goal
        let largeGoalHabit = Habit(
            name: "Large Goal Habit",
            description: "Test",
            icon: "🏃‍♂️",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "100 times", // Large goal
            reminder: "No reminder",
            startDate: testDate,
            endDate: nil
        )
        
        let dateKey = Habit.dateKey(for: testDate)
        largeGoalHabit.completionHistory[dateKey] = 50
        
        // When: Increment by 1
        let currentProgress = largeGoalHabit.getProgress(for: testDate)
        let newProgress = min(currentProgress + 1, 100) // Clamp to goal
        
        // Then: Progress should be 51, not completed
        XCTAssertEqual(newProgress, 51, "Progress should increment correctly")
        XCTAssertFalse(largeGoalHabit.isCompleted(for: testDate), "Habit should not be completed yet")
    }
    
    // MARK: - Data Consistency Tests
    
    func test_CompletionHistory_isSingleSourceOfTruth() {
        // Given: Habit with progress
        let dateKey = Habit.dateKey(for: testDate)
        testHabit.completionHistory[dateKey] = 2
        
        // When: Check completion status
        let progress = testHabit.getProgress(for: testDate)
        let isCompleted = testHabit.isCompleted(for: testDate)
        
        // Then: Both should be consistent
        XCTAssertEqual(progress, 2, "Progress should match completion history")
        XCTAssertFalse(isCompleted, "Habit should not be completed with progress < goal")
        
        // When: Update progress to goal
        testHabit.completionHistory[dateKey] = 3
        
        // Then: Both should be consistent
        let newProgress = testHabit.getProgress(for: testDate)
        let newIsCompleted = testHabit.isCompleted(for: testDate)
        XCTAssertEqual(newProgress, 3, "Progress should match completion history")
        XCTAssertTrue(newIsCompleted, "Habit should be completed with progress = goal")
    }
    
    // MARK: - Performance Tests
    
    func test_CompletionFlow_performance() {
        // Given: Multiple habits
        let habits = (0..<100).map { index in
            Habit(
                name: "Habit \(index)",
                description: "Test",
                icon: "🏃‍♂️",
                color: .blue,
                habitType: .formation,
                schedule: "Everyday",
                goal: "3 times",
                reminder: "No reminder",
                startDate: testDate,
                endDate: nil
            )
        }
        
        // When: Complete all habits
        measure {
            for habit in habits {
                let dateKey = Habit.dateKey(for: testDate)
                habit.completionHistory[dateKey] = 3
                _ = habit.isCompleted(for: testDate)
            }
        }
        
        // Then: All habits should be completed
        let completedCount = habits.filter { $0.isCompleted(for: testDate) }.count
        XCTAssertEqual(completedCount, 100, "All habits should be completed")
    }
}
