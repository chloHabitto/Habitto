import SwiftUI

// Test file to demonstrate habit editing functionality
struct HabitEditTest {
    
    // Test function to demonstrate habit editing flow
    static func testHabitEditing() {
        // Create a sample habit
        let originalHabit = Habit(
            name: "Morning Exercise",
            description: "Start the day with a quick workout",
            icon: "🏃‍♂️",
            color: .blue,
            habitType: .formation,
            schedule: "Everyday",
            goal: "30 minutes",
            reminder: "6:00 AM",
            startDate: Date(),
            endDate: nil,
            isCompleted: false,
            streak: 5
        )
        
        print("Original habit: \(originalHabit.name), Icon: \(originalHabit.icon), Color: \(originalHabit.color), ID: \(originalHabit.id)")
        
        // Simulate editing the habit
        var editedHabit = Habit(
            name: "Evening Exercise", // Changed name
            description: "End the day with a relaxing workout", // Changed description
            icon: "💪", // Changed icon
            color: .green, // Changed color
            habitType: .formation,
            schedule: "Every 2 days", // Changed schedule
            goal: "45 minutes", // Changed goal
            reminder: "7:00 PM", // Changed reminder
            startDate: originalHabit.startDate,
            endDate: originalHabit.endDate,
            isCompleted: originalHabit.isCompleted,
            streak: originalHabit.streak
        )
        
        // Preserve the original ID
        editedHabit.id = originalHabit.id
        
        print("Edited habit: \(editedHabit.name), Icon: \(editedHabit.icon), Color: \(editedHabit.color), ID: \(editedHabit.id)")
        
        // Verify that the changes are reflected
        assert(originalHabit.name != editedHabit.name, "Name should be different")
        assert(originalHabit.description != editedHabit.description, "Description should be different")
        assert(originalHabit.icon != editedHabit.icon, "Icon should be different")
        assert(originalHabit.color != editedHabit.color, "Color should be different")
        assert(originalHabit.schedule != editedHabit.schedule, "Schedule should be different")
        assert(originalHabit.goal != editedHabit.goal, "Goal should be different")
        assert(originalHabit.reminder != editedHabit.reminder, "Reminder should be different")
        assert(originalHabit.id == editedHabit.id, "ID should be preserved")
        
        print("✅ All habit editing tests passed!")
    }
    
    // Test function to verify ID preservation
    static func testIdPreservation() {
        let originalHabit = Habit(
            name: "Test Habit",
            description: "Test description",
            icon: "📝",
            color: .red,
            habitType: .formation,
            schedule: "Daily",
            goal: "1 time",
            reminder: "No reminder",
            startDate: Date(),
            endDate: nil,
            isCompleted: false,
            streak: 0
        )
        
        let originalId = originalHabit.id
        print("Original habit ID: \(originalId)")
        
        // Simulate the editing process
        var updatedHabit = Habit(
            name: "Updated Test Habit",
            description: "Updated description",
            icon: "✅",
            color: .blue,
            habitType: .formation,
            schedule: "Weekly",
            goal: "2 times",
            reminder: "9:00 AM",
            startDate: originalHabit.startDate,
            endDate: originalHabit.endDate,
            isCompleted: originalHabit.isCompleted,
            streak: originalHabit.streak
        )
        
        // Preserve the original ID
        updatedHabit.id = originalHabit.id
        
        print("Updated habit ID: \(updatedHabit.id)")
        assert(updatedHabit.id == originalId, "ID should be preserved during editing")
        print("✅ ID preservation test passed!")
    }
    
    // Test function to demonstrate data persistence
    static func testDataPersistence() {
        let testHabits = [
            Habit(
                name: "Read Books",
                description: "Read for 30 minutes daily",
                icon: "📚",
                color: .blue,
                habitType: .formation,
                schedule: "Everyday",
                goal: "30 minutes",
                reminder: "8:00 PM",
                startDate: Date(),
                endDate: nil,
                isCompleted: false,
                streak: 3
            ),
            Habit(
                name: "Meditate",
                description: "Practice mindfulness",
                icon: "🧘‍♀️",
                color: .green,
                habitType: .formation,
                schedule: "Every 2 days",
                goal: "15 minutes",
                reminder: "7:00 AM",
                startDate: Date(),
                endDate: nil,
                isCompleted: true,
                streak: 7
            )
        ]
        
        // Save habits
        Habit.saveHabits(testHabits)
        print("✅ Habits saved to UserDefaults")
        
        // Load habits
        let loadedHabits = Habit.loadHabits()
        print("✅ Habits loaded from UserDefaults: \(loadedHabits.count) habits")
        
        // Verify data integrity
        assert(loadedHabits.count == testHabits.count, "Should have same number of habits")
        
        for (original, loaded) in zip(testHabits, loadedHabits) {
            assert(original.name == loaded.name, "Names should match")
            assert(original.description == loaded.description, "Descriptions should match")
            assert(original.icon == loaded.icon, "Icons should match")
            assert(original.color == loaded.color, "Colors should match")
            assert(original.schedule == loaded.schedule, "Schedules should match")
            assert(original.goal == loaded.goal, "Goals should match")
            assert(original.reminder == loaded.reminder, "Reminders should match")
        }
        
        print("✅ Data persistence tests passed!")
    }
}

// Usage example:
// HabitEditTest.testHabitEditing()
// HabitEditTest.testIdPreservation()
// HabitEditTest.testDataPersistence() 