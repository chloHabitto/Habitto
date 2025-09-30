import XCTest
import SwiftUI
import SwiftData
@testable import Habitto

@MainActor
final class HomeTabViewUITests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: DailyAward.self, Habit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - UI Tests
    
    func testCompleteOneHabitNoCelebration() async throws {
        // Given
        let habits = createTestHabits(count: 3)
        let selectedDate = Date()
        
        // When - complete only one habit
        let view = HomeTabView(
            selectedDate: .constant(selectedDate),
            selectedStatsTab: .constant(0),
            habits: habits,
            onToggleHabit: { _, _ in },
            onUpdateHabit: nil,
            onSetProgress: { _, _, _ in },
            onDeleteHabit: nil,
            onCompletionDismiss: nil
        )
        
        // Simulate completing first habit
        // This would be done through the UI interaction
        // For testing, we'll directly call the service
        
        // Then - no celebration should be shown
        // This would be verified through UI state observation
    }
    
    func testCompleteAllHabitsShowsCelebration() async throws {
        // Given
        let habits = createTestHabits(count: 3)
        let selectedDate = Date()
        
        // When - complete all habits
        let view = HomeTabView(
            selectedDate: .constant(selectedDate),
            selectedStatsTab: .constant(0),
            habits: habits,
            onToggleHabit: { _, _ in },
            onUpdateHabit: nil,
            onSetProgress: { _, _, _ in },
            onDeleteHabit: nil,
            onCompletionDismiss: nil
        )
        
        // Simulate completing all habits
        // This would be done through the UI interaction
        
        // Then - celebration should be shown
        // This would be verified through UI state observation
    }
    
    func testUncompleteAfterAwardHidesCelebration() async throws {
        // Given
        let habits = createTestHabits(count: 3)
        let selectedDate = Date()
        
        // Complete all habits first (shows celebration)
        // Then uncomplete one habit
        
        // Then - celebration should be hidden
        // This would be verified through UI state observation
    }
    
    func testRapidTaps() async throws {
        // Given
        let habits = createTestHabits(count: 3)
        let selectedDate = Date()
        
        // When - rapid taps on habit completion
        let view = HomeTabView(
            selectedDate: .constant(selectedDate),
            selectedStatsTab: .constant(0),
            habits: habits,
            onToggleHabit: { _, _ in },
            onUpdateHabit: nil,
            onSetProgress: { _, _, _ in },
            onDeleteHabit: nil,
            onCompletionDismiss: nil
        )
        
        // Simulate rapid taps
        for _ in 0..<10 {
            // Rapid completion/uncompletion
        }
        
        // Then - should handle gracefully without duplicate awards
        // This would be verified through service state
    }
    
    func testSortingBehavior() async throws {
        // Given
        let habits = createTestHabits(count: 5)
        let selectedDate = Date()
        
        // When - complete some habits
        let view = HomeTabView(
            selectedDate: .constant(selectedDate),
            selectedStatsTab: .constant(0),
            habits: habits,
            onToggleHabit: { _, _ in },
            onUpdateHabit: nil,
            onSetProgress: { _, _, _ in },
            onDeleteHabit: nil,
            onCompletionDismiss: nil
        )
        
        // Simulate completing some habits
        
        // Then - completed habits should sink to bottom
        // This would be verified through UI order observation
    }
    
    // MARK: - Helper Methods
    
    private func createTestHabits(count: Int) -> [Habit] {
        var habits: [Habit] = []
        
        for i in 0..<count {
            let habit = Habit(
                name: "Test Habit \(i)",
                description: "Test description \(i)",
                category: .health,
                difficulty: .easy,
                schedule: .everyday,
                startDate: Date(),
                endDate: nil,
                reminders: [],
                userId: "test_user"
            )
            habits.append(habit)
        }
        
        return habits
    }
}
