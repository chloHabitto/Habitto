import Foundation
import SwiftData
import SwiftUI

// MARK: - Main Habit Entity
@Model
final class HabitData {
    @Attribute(.unique) var id: UUID
    var userId: String // User ID for data isolation
    var name: String
    var habitDescription: String
    var icon: String
    var colorData: Data // Store Color as Data for SwiftData
    var habitType: String // Store enum as String
    var schedule: String
    var goal: String
    var reminder: String
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
    @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
    @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
    @Relationship(deleteRule: .cascade) var notes: [HabitNote]
    
    init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        habitDescription: String,
        icon: String,
        color: Color,
        habitType: HabitType,
        schedule: String,
        goal: String,
        reminder: String,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.habitDescription = habitDescription
        self.icon = icon
        self.colorData = Self.encodeColor(color)
        self.habitType = habitType.rawValue
        self.schedule = schedule
        self.goal = goal
        self.reminder = reminder
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Initialize relationships
        self.completionHistory = []
        self.difficultyHistory = []
        self.usageHistory = []
        self.notes = []
    }
    
    // MARK: - Computed Properties
    
    var color: Color {
        get { Self.decodeColor(colorData) }
        set { colorData = Self.encodeColor(newValue) }
    }
    
    var habitTypeEnum: HabitType {
        get { HabitType(rawValue: habitType) ?? .formation }
        set { habitType = newValue.rawValue }
    }
    
    // Computed property: Check if completed today
    var isCompleted: Bool {
        isCompletedForDate(Date())
    }
    
    // Computed property: Calculate current streak
    var streak: Int {
        calculateTrueStreak()
    }
    
    // MARK: - Color Encoding/Decoding
    
    private static func encodeColor(_ color: Color) -> Data {
        // Convert Color to Data for storage
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorComponents = [red, green, blue, alpha]
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: colorComponents, requiringSecureCoding: true)
        } catch {
            // Fallback to a default blue color if encoding fails
            print("Warning: Failed to encode color, using default blue")
            return try! NSKeyedArchiver.archivedData(withRootObject: [0.0, 0.0, 1.0, 1.0], requiringSecureCoding: true)
        }
    }
    
    static func decodeColor(_ data: Data) -> Color {
        guard let components = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data) as? [CGFloat],
              components.count == 4 else {
            return .blue // Default color
        }
        
        return Color(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            opacity: Double(components[3])
        )
    }
    
    // MARK: - Update Methods
    
    func updateFromHabit(_ habit: Habit) {
        self.name = habit.name
        self.habitDescription = habit.description
        self.icon = habit.icon
        self.color = habit.color
        self.habitTypeEnum = habit.habitType
        self.schedule = habit.schedule
        self.goal = habit.goal
        self.reminder = habit.reminder
        self.startDate = habit.startDate
        self.endDate = habit.endDate
        // Note: isCompleted and streak are now computed properties
        self.updatedAt = Date()
    }
    
    // MARK: - Completion and Streak Methods
    
    /// Check if habit is completed for a specific date (source of truth)
    func isCompletedForDate(_ date: Date) -> Bool {
        let dateKey = ISO8601DateHelper.shared.string(from: date)
        let completionRecord = completionHistory.first { record in
            ISO8601DateHelper.shared.string(from: record.date) == dateKey
        }
        return completionRecord?.isCompleted ?? false
    }
    
    /// Calculate true streak from completionHistory (source of truth)
    func calculateTrueStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        // Count consecutive completed days backwards from today
        while isCompletedForDate(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    @MainActor
    func toHabit() -> Habit {
        // Convert Date keys to String keys for compatibility with Habit model
        let completionHistoryDict: [String: Int] = Dictionary(uniqueKeysWithValues: completionHistory.map { 
            (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted ? 1 : 0) 
        })
        
        let difficultyHistoryDict: [String: Int] = Dictionary(uniqueKeysWithValues: difficultyHistory.map { 
            (ISO8601DateHelper.shared.string(from: $0.date), $0.difficulty) 
        })
        
        let actualUsageDict: [String: Int] = Dictionary(uniqueKeysWithValues: usageHistory.map { 
            ($0.key, $0.value) 
        })
        
        return Habit(
            id: id,
            name: name,
            description: habitDescription,
            icon: icon,
            color: color,
            habitType: habitTypeEnum,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            completionHistory: completionHistoryDict,
            difficultyHistory: difficultyHistoryDict,
            actualUsage: actualUsageDict
        )
    }
    
}

// MARK: - Completion Record
@Model
final class CompletionRecord {
    var userId: String
    var habitId: UUID
    var date: Date
    var dateKey: String  // ✅ PHASE 5: Added field for date-based queries (indexing not supported in current SwiftData)
    var isCompleted: Bool
    var createdAt: Date
    
    // ✅ PHASE 5: Composite unique constraint to prevent duplicate completions
    @Attribute(.unique) var userIdHabitIdDateKey: String
    
    init(userId: String, habitId: UUID, date: Date, dateKey: String, isCompleted: Bool) {
        self.userId = userId
        self.habitId = habitId
        self.date = date
        self.dateKey = dateKey
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.userIdHabitIdDateKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
    }
}

// MARK: - Difficulty Record
@Model
final class DifficultyRecord {
    var date: Date
    var difficulty: Int
    var createdAt: Date
    
    init(date: Date, difficulty: Int) {
        self.date = date
        self.difficulty = difficulty
        self.createdAt = Date()
    }
}

// MARK: - Usage Record
@Model
final class UsageRecord {
    var key: String
    var value: Int
    var createdAt: Date
    
    init(key: String, value: Int) {
        self.key = key
        self.value = value
        self.createdAt = Date()
    }
}

// MARK: - Habit Note
@Model
final class HabitNote {
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    init(content: String) {
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Storage Header for Schema Versioning
@Model
final class StorageHeader {
    var schemaVersion: Int
    var lastMigration: Date
    var createdAt: Date
    
    init(schemaVersion: Int) {
        self.schemaVersion = schemaVersion
        self.lastMigration = Date()
        self.createdAt = Date()
    }
}

// MARK: - Migration Record
@Model
final class MigrationRecord {
    var fromVersion: Int
    var toVersion: Int
    var executedAt: Date
    var success: Bool
    var errorMessage: String?
    
    init(fromVersion: Int, toVersion: Int, success: Bool, errorMessage: String? = nil) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.executedAt = Date()
        self.success = success
        self.errorMessage = errorMessage
    }
}
