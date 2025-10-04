import Foundation
import SwiftData
import SwiftUI
import UIKit

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
        return try! NSKeyedArchiver.archivedData(withRootObject: colorComponents, requiringSecureCoding: true)
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
        self.updatedAt = Date()
        // Note: isCompleted and streak are now computed properties
    }
    
    // MARK: - Computed Properties
    
    /// Computed property for current completion status
    var isCompleted: Bool {
        isCompletedForDate(Date())
    }
    
    /// Computed property for current streak
    var streak: Int {
        calculateTrueStreak()
    }
    
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
    
    // ✅ CRITICAL FIX: Fallback for database corruption
    static func createCompletionRecordIfNeeded(
        userId: String,
        habitId: UUID,
        date: Date,
        isCompleted: Bool,
        modelContext: ModelContext
    ) -> Bool {
        let dateKey = ISO8601DateHelper.shared.string(from: date)
        let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
        
        do {
            // Check if record already exists
            let predicate = #Predicate<CompletionRecord> { record in
                record.userIdHabitIdDateKey == uniqueKey
            }
            let request = FetchDescriptor<CompletionRecord>(predicate: predicate)
            let existingRecords = try modelContext.fetch(request)
            
            if existingRecords.isEmpty {
                // Create new record
                let record = CompletionRecord(
                    userId: userId,
                    habitId: habitId,
                    date: date,
                    dateKey: dateKey,
                    isCompleted: isCompleted
                )
                modelContext.insert(record)
                try modelContext.save()
                return true
            } else {
                // Update existing record
                if let existingRecord = existingRecords.first {
                    existingRecord.isCompleted = isCompleted
                    try modelContext.save()
                    return true
                }
            }
        } catch {
            print("❌ CompletionRecord creation failed: \(error)")
            // ✅ FALLBACK: If database is corrupted, return false but don't crash
            return false
        }
        
        return false
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:habitId:date:dateKey:isCompleted:) instead")
    init(date: Date, isCompleted: Bool) {
        self.userId = "legacy"
        let habitId = UUID()
        self.habitId = habitId
        self.date = date
        self.dateKey = ""
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.userIdHabitIdDateKey = "legacy#\(habitId.uuidString)#"
    }
}

// MARK: - Difficulty Record
@Model
final class DifficultyRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var date: Date
    var difficulty: Int
    var createdAt: Date
    
    init(userId: String, habitId: UUID, date: Date, difficulty: Int) {
        // self.userId = userId  // ❌ Property not available in current SwiftData version
        // self.habitId = habitId  // ❌ Property not available in current SwiftData version
        self.date = date
        self.difficulty = difficulty
        self.createdAt = Date()
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:habitId:date:difficulty:) instead")
    init(date: Date, difficulty: Int) {
        // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
        // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
        self.date = date
        self.difficulty = difficulty
        self.createdAt = Date()
    }
}

// MARK: - Usage Record
@Model
final class UsageRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var key: String
    var value: Int
    var createdAt: Date
    
    init(userId: String, habitId: UUID, key: String, value: Int) {
        // self.userId = userId  // ❌ Property not available in current SwiftData version
        // self.habitId = habitId  // ❌ Property not available in current SwiftData version
        self.key = key
        self.value = value
        self.createdAt = Date()
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:habitId:key:value:) instead")
    init(key: String, value: Int) {
        // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
        // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
        self.key = key
        self.value = value
        self.createdAt = Date()
    }
}

// MARK: - Habit Note
@Model
final class HabitNote {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, habitId: UUID, content: String) {
        // self.userId = userId  // ❌ Property not available in current SwiftData version
        // self.habitId = habitId  // ❌ Property not available in current SwiftData version
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:habitId:content:) instead")
    init(content: String) {
        // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
        // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Storage Header for Schema Versioning
@Model
final class StorageHeader {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    var schemaVersion: Int
    var lastMigration: Date
    var createdAt: Date
    
    init(userId: String, schemaVersion: Int) {
        // self.userId = userId  // ❌ Property not available in current SwiftData version
        self.schemaVersion = schemaVersion
        self.lastMigration = Date()
        self.createdAt = Date()
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:schemaVersion:) instead")
    init(schemaVersion: Int) {
        // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
        self.schemaVersion = schemaVersion
        self.lastMigration = Date()
        self.createdAt = Date()
    }
}

// MARK: - Migration Record
@Model
final class MigrationRecord {
    // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
    var fromVersion: Int
    var toVersion: Int
    var executedAt: Date
    var success: Bool
    var errorMessage: String?
    
    init(userId: String, fromVersion: Int, toVersion: Int, success: Bool, errorMessage: String? = nil) {
        // self.userId = userId  // ❌ Property not available in current SwiftData version
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.executedAt = Date()
        self.success = success
        self.errorMessage = errorMessage
    }
    
    // Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use init(userId:fromVersion:toVersion:success:errorMessage:) instead")
    init(fromVersion: Int, toVersion: Int, success: Bool, errorMessage: String? = nil) {
        // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.executedAt = Date()
        self.success = success
        self.errorMessage = errorMessage
    }
}
