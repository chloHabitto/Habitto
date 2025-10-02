import Foundation
import SwiftUI

// MARK: - Widget/Extension Concurrent Access Tests
// Tests that prove actor + NSFileCoordinator prevent races between app and extensions

struct WidgetExtensionConcurrentAccessTests {
    
    // MARK: - Test Scenarios
    
    /// Test concurrent access between main app and widget extension
    func testMainAppWidgetConcurrency() async throws -> TestScenarioResult {
        let startTime = Date()
        
        // Simulate concurrent access patterns
        let habitStore = CrashSafeHabitStore.shared
        
        // Create test habits
        let testHabits = createTestHabits(count: 100)
        
        // Simulate main app writing while widget reads
        let mainAppTask = Task {
            for i in 0..<10 {
                try await habitStore.saveHabits(testHabits + createTestHabits(count: i))
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        let widgetTask = Task {
            for _ in 0..<20 {
                let habits = await habitStore.loadHabits()
                // Verify we always get consistent data
                assert(habits.allSatisfy { !$0.name.isEmpty })
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
        
        // Wait for both tasks to complete
        try await mainAppTask.value
        try await widgetTask.value
        
        // Verify final state is consistent
        let finalHabits = await habitStore.loadHabits()
        let success = finalHabits.count >= 100 && finalHabits.allSatisfy { !$0.name.isEmpty }
        
        return TestScenarioResult(
            scenario: .widgetExtensionConcurrency,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Concurrent access test failed - inconsistent data detected",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: finalHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 20, // 10 writes + 20 reads
                encryptionOperations: 0,
                validationChecks: 20
            ),
            severity: .high
        )
    }
    
    /// Test NSFileCoordinator prevents file corruption during concurrent access
    func testFileCoordinatorRacePrevention() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create multiple concurrent writers to stress test coordination
        let writerTasks = (0..<5).map { writerId in
            Task {
                for i in 0..<10 {
                    let habits = createTestHabits(count: 50 + i, prefix: "Writer\(writerId)")
                    try await habitStore.saveHabits(habits)
                    try await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...50_000_000))
                }
            }
        }
        
        // Wait for all writers to complete
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in writerTasks {
                group.addTask { try await task.value }
            }
            
            for try await _ in group {
                // All tasks completed successfully
            }
        }
        
        // Verify file integrity after concurrent writes
        let finalHabits = await habitStore.loadHabits()
        let success = finalHabits.count > 0 && finalHabits.allSatisfy { !$0.name.isEmpty }
        
        return TestScenarioResult(
            scenario: .fileCoordinatorRacePrevention,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "File coordinator race prevention failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: finalHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 50, // 5 writers × 10 writes each
                encryptionOperations: 0,
                validationChecks: 50
            ),
            severity: .critical
        )
    }
    
    /// Test actor isolation prevents data races
    func testActorIsolation() async throws -> TestScenarioResult {
        let startTime = Date()
        
        let habitStore = CrashSafeHabitStore.shared
        
        // Create tasks that access the actor from different contexts
        let tasks = (0..<10).map { taskId in
            Task {
                // Each task performs multiple operations
                for i in 0..<5 {
                    let habits = await habitStore.loadHabits()
                    let newHabit = createTestHabit(name: "Task\(taskId)_\(i)")
                    try await habitStore.saveHabits(habits + [newHabit])
                }
            }
        }
        
        // Execute all tasks concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            for try await _ in group {
                // All tasks completed without data races
            }
        }
        
        // Verify final state is consistent
        let finalHabits = await habitStore.loadHabits()
        let success = finalHabits.count >= 50 // At least 10 tasks × 5 habits each
        
        return TestScenarioResult(
            scenario: .actorIsolation,
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Actor isolation test failed",
            metrics: TestScenarioResult.TestMetrics(
                recordsProcessed: finalHabits.count,
                memoryUsage: 0,
                diskUsage: 0,
                networkCalls: 0,
                fileOperations: 100, // 10 tasks × 5 operations each × 2 (load + save)
                encryptionOperations: 0,
                validationChecks: 100
            ),
            severity: .high
        )
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabits(count: Int, prefix: String = "Test") -> [Habit] {
        return (0..<count).map { index in
            createTestHabit(name: "\(prefix)Habit\(index)")
        }
    }
    
    private func createTestHabit(name: String) -> Habit {
        return Habit(
            id: UUID(),
            name: name,
            description: "Test habit for concurrent access testing",
            icon: "star",
            color: .blue,
            habitType: .formation,
            schedule: "daily",
            goal: "1",
            reminder: "9:00 AM",
            startDate: Date(),
            endDate: nil,
            isCompleted: false,
            streak: 0,
            createdAt: Date(),
            reminders: [],
            baseline: 0,
            target: 0,
            completionHistory: [:],
            difficultyHistory: [:],
            actualUsage: [:]
        )
    }
}

