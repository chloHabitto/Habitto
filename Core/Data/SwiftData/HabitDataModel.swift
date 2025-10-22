import Foundation
import SwiftData
import SwiftUI
import UIKit

// MARK: - HabitData

@Model
final class HabitData {
  // MARK: Lifecycle

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
    endDate: Date? = nil,
    baseline: Int = 0,
    target: Int = 1)
  {
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
    self.baseline = baseline
    self.target = target
    self.createdAt = Date()
    self.updatedAt = Date()

    // Initialize relationships
    self.completionHistory = []
    self.difficultyHistory = []
    self.usageHistory = []
    self.notes = []
  }

  // MARK: Internal

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
  
  // Breaking habit fields (CRITICAL: Must be stored!)
  var baseline: Int = 0  // Current usage level (for breaking habits)
  var target: Int = 1    // Goal usage level (for breaking habits)

  // Relationships
  @Relationship(deleteRule: .cascade) var completionHistory: [CompletionRecord]
  @Relationship(deleteRule: .cascade) var difficultyHistory: [DifficultyRecord]
  @Relationship(deleteRule: .cascade) var usageHistory: [UsageRecord]
  @Relationship(deleteRule: .cascade) var notes: [HabitNote]

  var color: Color {
    get { Self.decodeColor(colorData) }
    set { colorData = Self.encodeColor(newValue) }
  }

  var habitTypeEnum: HabitType {
    get { HabitType(rawValue: habitType) ?? .formation }
    set { habitType = newValue.rawValue }
  }

  /// Computed property for current completion status
  var isCompleted: Bool {
    isCompletedForDate(Date())
  }

  /// Computed property for current streak
  var streak: Int {
    calculateTrueStreak()
  }

  static func decodeColor(_ data: Data) -> Color {
    guard let components = try? NSKeyedUnarchiver.unarchivedObject(
      ofClass: NSArray.self,
      from: data) as? [CGFloat],
      components.count == 4 else
    {
      return .blue // Default color
    }

    return Color(
      red: Double(components[0]),
      green: Double(components[1]),
      blue: Double(components[2]),
      opacity: Double(components[3]))
  }

  // MARK: - Update Methods

  func updateFromHabit(_ habit: Habit) {
    name = habit.name
    habitDescription = habit.description
    icon = habit.icon
    color = habit.color.color
    habitTypeEnum = habit.habitType
    schedule = habit.schedule
    goal = habit.goal
    reminder = habit.reminder
    startDate = habit.startDate
    endDate = habit.endDate
    baseline = habit.baseline
    target = habit.target
    updatedAt = Date()
    // Note: isCompleted and streak are now computed properties
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
    // ✅ FIX: Query CompletionRecords by habitId if relationship is empty (orphaned records)
    let completionRecords: [CompletionRecord]
    if completionHistory.isEmpty {
      // Relationship is empty, query manually by habitId
      let habitId = self.id  // Capture for use in predicate
      let userId = self.userId  // Capture for use in predicate
      let predicate = #Predicate<CompletionRecord> { record in
        record.habitId == habitId && record.userId == userId
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      do {
        let context = SwiftDataContainer.shared.modelContext
        completionRecords = try context.fetch(descriptor)
        print("🔍 toHabit(): Found \(completionRecords.count) orphaned CompletionRecords for habit '\(self.name)' by querying habitId")
      } catch {
        print("❌ toHabit(): Failed to query CompletionRecords: \(error)")
        completionRecords = []
      }
    } else {
      // Use relationship if it's working
      completionRecords = completionHistory
      print("🔍 toHabit(): Using \(completionRecords.count) CompletionRecords from relationship for habit '\(self.name)'")
    }
    
    // Convert Date keys to String keys for compatibility with Habit model
    let completionHistoryDict: [String: Int] = Dictionary(uniqueKeysWithValues: completionRecords
      .map {
        (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted ? 1 : 0)
      })
    
    // ✅ FIX: Rebuild completionStatus from CompletionRecords
    let completionStatusDict: [String: Bool] = Dictionary(uniqueKeysWithValues: completionRecords
      .map {
        (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted)
      })

    let difficultyHistoryDict: [String: Int] = Dictionary(uniqueKeysWithValues: difficultyHistory
      .map {
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
      color: CodableColor(color),
      habitType: habitTypeEnum,
      schedule: schedule,
      goal: goal,
      reminder: reminder,
      startDate: startDate,
      endDate: endDate,
      baseline: baseline,
      target: target,
      completionHistory: completionHistoryDict,
      completionStatus: completionStatusDict,  // ✅ NOW REBUILT!
      difficultyHistory: difficultyHistoryDict,
      actualUsage: actualUsageDict)
  }

  // MARK: Private

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
    return try! NSKeyedArchiver.archivedData(
      withRootObject: colorComponents,
      requiringSecureCoding: true)
  }
}

// MARK: - CompletionRecord

@Model
final class CompletionRecord {
  // MARK: Lifecycle

  init(userId: String, habitId: UUID, date: Date, dateKey: String, isCompleted: Bool) {
    self.userId = userId
    self.habitId = habitId
    self.date = date
    self.dateKey = dateKey
    self.isCompleted = isCompleted
    self.createdAt = Date()
    self.userIdHabitIdDateKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
  }

  /// Legacy initializer for backward compatibility
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

  // MARK: Internal

  var userId: String
  var habitId: UUID
  var date: Date
  var dateKey: String // ✅ PHASE 5: Added field for date-based queries (indexing not supported in
  // current SwiftData)
  var isCompleted: Bool
  var createdAt: Date

  /// ✅ PHASE 5: Composite unique constraint to prevent duplicate completions
  @Attribute(.unique) var userIdHabitIdDateKey: String
  
  /// ✅ FIX: Inverse relationship to HabitData for proper linking
  @Relationship(inverse: \HabitData.completionHistory) var habit: HabitData?

  /// ✅ CRITICAL FIX: Fallback for database corruption
  static func createCompletionRecordIfNeeded(
    userId: String,
    habitId: UUID,
    date: Date,
    isCompleted: Bool,
    modelContext: ModelContext) -> Bool
  {
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
          isCompleted: isCompleted)
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
}

// MARK: - DifficultyRecord

@Model
final class DifficultyRecord {
  // MARK: Lifecycle

  init(userId _: String, habitId _: UUID, date: Date, difficulty: Int) {
    // self.userId = userId  // ❌ Property not available in current SwiftData version
    // self.habitId = habitId  // ❌ Property not available in current SwiftData version
    self.date = date
    self.difficulty = difficulty
    self.createdAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:date:difficulty:) instead")
  init(date: Date, difficulty: Int) {
    // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
    // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
    self.date = date
    self.difficulty = difficulty
    self.createdAt = Date()
  }

  // MARK: Internal

  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
  var date: Date
  var difficulty: Int
  var createdAt: Date
}

// MARK: - UsageRecord

@Model
final class UsageRecord {
  // MARK: Lifecycle

  init(userId _: String, habitId _: UUID, key: String, value: Int) {
    // self.userId = userId  // ❌ Property not available in current SwiftData version
    // self.habitId = habitId  // ❌ Property not available in current SwiftData version
    self.key = key
    self.value = value
    self.createdAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:key:value:) instead")
  init(key: String, value: Int) {
    // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
    // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
    self.key = key
    self.value = value
    self.createdAt = Date()
  }

  // MARK: Internal

  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
  var key: String
  var value: Int
  var createdAt: Date
}

// MARK: - HabitNote

@Model
final class HabitNote {
  // MARK: Lifecycle

  init(userId _: String, habitId _: UUID, content: String) {
    // self.userId = userId  // ❌ Property not available in current SwiftData version
    // self.habitId = habitId  // ❌ Property not available in current SwiftData version
    self.content = content
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:content:) instead")
  init(content: String) {
    // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
    // self.habitId = UUID()  // ❌ Property not available in current SwiftData version
    self.content = content
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  // MARK: Internal

  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
  var content: String
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - StorageHeader

@Model
final class StorageHeader {
  // MARK: Lifecycle

  init(userId _: String, schemaVersion: Int) {
    // self.userId = userId  // ❌ Property not available in current SwiftData version
    self.schemaVersion = schemaVersion
    self.lastMigration = Date()
    self.createdAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:schemaVersion:) instead")
  init(schemaVersion: Int) {
    // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
    self.schemaVersion = schemaVersion
    self.lastMigration = Date()
    self.createdAt = Date()
  }

  // MARK: Internal

  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  var schemaVersion: Int
  var lastMigration: Date
  var createdAt: Date
}

// MARK: - MigrationRecord

@Model
final class MigrationRecord {
  // MARK: Lifecycle

  init(
    userId _: String,
    fromVersion: Int,
    toVersion: Int,
    success: Bool,
    errorMessage: String? = nil)
  {
    // self.userId = userId  // ❌ Property not available in current SwiftData version
    self.fromVersion = fromVersion
    self.toVersion = toVersion
    self.executedAt = Date()
    self.success = success
    self.errorMessage = errorMessage
  }

  /// Legacy initializer for backward compatibility
  @available(
    *,
    deprecated,
    message: "Use init(userId:fromVersion:toVersion:success:errorMessage:) instead")
  init(fromVersion: Int, toVersion: Int, success: Bool, errorMessage: String? = nil) {
    // self.userId = "legacy"  // ❌ Property not available in current SwiftData version
    self.fromVersion = fromVersion
    self.toVersion = toVersion
    self.executedAt = Date()
    self.success = success
    self.errorMessage = errorMessage
  }

  // MARK: Internal

  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  var fromVersion: Int
  var toVersion: Int
  var executedAt: Date
  var success: Bool
  var errorMessage: String?
}
