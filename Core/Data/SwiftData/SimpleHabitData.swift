import Foundation
import SwiftData
import SwiftUI

// MARK: - Color Extensions
extension Color {
    func toHexString() -> String {
        // Convert Color to hex string
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
}

// MARK: - Simple Habit Entity for SwiftData
@Model
final class SimpleHabitData {
    @Attribute(.unique) var id: UUID
    var name: String
    var habitDescription: String
    var icon: String
    var colorString: String // Store color as string
    var habitType: String // Store enum as String
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var streak: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Store completion history as JSON string for simplicity
    var completionHistoryJSON: String
    var difficultyHistoryJSON: String
    var usageHistoryJSON: String
    
    init(
        id: UUID = UUID(),
        name: String,
        habitDescription: String,
        icon: String,
        colorString: String,
        habitType: String,
        schedule: String,
        goal: String,
        reminder: String,
        startDate: Date,
        endDate: Date? = nil,
        isCompleted: Bool = false,
        streak: Int = 0,
        completionHistoryJSON: String = "{}",
        difficultyHistoryJSON: String = "{}",
        usageHistoryJSON: String = "{}"
    ) {
        self.id = id
        self.name = name
        self.habitDescription = habitDescription
        self.icon = icon
        self.colorString = colorString
        self.habitType = habitType
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.streak = streak
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completionHistoryJSON = completionHistoryJSON
        self.difficultyHistoryJSON = difficultyHistoryJSON
        self.usageHistoryJSON = usageHistoryJSON
    }
    
    // MARK: - Helper Methods
    
    func updateFromHabit(_ habit: Habit) {
        self.name = habit.name
        self.habitDescription = habit.description
        self.icon = habit.icon
        self.colorString = habit.color.toHexString()
        self.habitType = habit.habitType.rawValue
        self.schedule = habit.schedule
        self.goal = habit.goal
        self.reminder = habit.reminder
        self.startDate = habit.startDate
        self.endDate = habit.endDate
        self.isCompleted = habit.isCompleted
        self.streak = habit.streak
        self.updatedAt = Date()
        
        // Update JSON histories
        self.completionHistoryJSON = encodeCompletionHistory(habit.completionHistory)
        self.difficultyHistoryJSON = encodeDifficultyHistory(habit.difficultyHistory)
        self.usageHistoryJSON = encodeUsageHistory(habit.actualUsage)
    }
    
    func toHabit() -> Habit {
        return Habit(
            id: id,
            name: name,
            description: habitDescription,
            icon: icon,
            color: Color.fromHex(colorString),
            habitType: HabitType(rawValue: habitType) ?? .formation,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            isCompleted: isCompleted,
            streak: streak,
            createdAt: createdAt,
            reminders: [], // TODO: Implement reminders
            baseline: 0, // TODO: Implement baseline
            target: parseGoalAmount(from: goal) ?? 1,
            completionHistory: decodeCompletionHistory(completionHistoryJSON),
            difficultyHistory: decodeDifficultyHistory(difficultyHistoryJSON),
            actualUsage: decodeUsageHistory(usageHistoryJSON)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func parseGoalAmount(from goalString: String) -> Int? {
        // Extract the number from goal strings like "6 times per day", "3 times", etc.
        let components = goalString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let number = Int(component), number > 0 {
                return number
            }
        }
        return nil
    }
    
    private func encodeCompletionHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    private func encodeDifficultyHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    private func encodeUsageHistory(_ history: [String: Int]) -> String {
        do {
            let data = try JSONEncoder().encode(history)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    private func decodeCompletionHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }
    
    private func decodeDifficultyHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }
    
    private func decodeUsageHistory(_ jsonString: String) -> [String: Int] {
        guard let data = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }
}
