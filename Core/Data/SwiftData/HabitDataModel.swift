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
    // ✅ FIX: NSKeyedUnarchiver warnings - must explicitly allow NSNumber for secure coding
    // When using requiringSecureCoding: true, all classes (including NSNumber) must be declared
    guard let components = try? NSKeyedUnarchiver.unarchivedObject(
      ofClasses: [NSArray.self, NSNumber.self],  // ✅ Include NSNumber
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
    
    // ✅ CRITICAL FIX: Sync CompletionRecords from habit.completionHistory
    // This ensures CompletionRecords exist for all dates in completionHistory
    // to prevent data loss when habits are reloaded
    Task { @MainActor in
      await syncCompletionRecordsFromHabit(habit)
    }
  }
  
  /// Sync CompletionRecords from habit's completionHistory to ensure all dates have records
  @MainActor
  private func syncCompletionRecordsFromHabit(_ habit: Habit) async {
    let context = SwiftDataContainer.shared.modelContext
    let goalAmount = StreakDataCalculator.parseGoalAmount(from: habit.goal)
    
    // ✅ CRITICAL FIX: Parse dateString as "yyyy-MM-dd" format (dateKey format)
    // completionHistory uses DateUtils.dateKey format, not ISO8601
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    
    for (dateString, progress) in habit.completionHistory {
      // Try parsing as dateKey format first (yyyy-MM-dd)
      guard let date = dateFormatter.date(from: dateString) ?? ISO8601DateHelper.shared.dateWithFallback(from: dateString) else {
        print("⚠️ syncCompletionRecordsFromHabit: Failed to parse dateString '\(dateString)' for habit '\(habit.name)'")
        continue
      }
      
      let dateKey = DateUtils.dateKey(for: date)
      let isCompleted = progress >= goalAmount
      
      // Check if CompletionRecord already exists
      let uniqueKey = "\(self.userId)#\(self.id.uuidString)#\(dateKey)"
      let predicate = #Predicate<CompletionRecord> { record in
        record.userIdHabitIdDateKey == uniqueKey
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      
      if let existingRecord = try? context.fetch(descriptor).first {
        // Update existing record
        existingRecord.isCompleted = isCompleted
        existingRecord.progress = progress
        existingRecord.date = date
        existingRecord.dateKey = dateKey
      } else {
        // Create new record
        let record = CompletionRecord(
          userId: self.userId,
          habitId: self.id,
          date: date,
          dateKey: dateKey,
          isCompleted: isCompleted,
          progress: progress
        )
        context.insert(record)
        
        // Link to HabitData if not already linked
        if !self.completionHistory.contains(where: { $0.id == record.id }) {
          self.completionHistory.append(record)
        }
      }
    }
    
    // Save changes
    do {
      try context.save()
      print("✅ syncCompletionRecordsFromHabit: Synced \(habit.completionHistory.count) CompletionRecords for habit '\(habit.name)'")
    } catch {
      print("❌ syncCompletionRecordsFromHabit: Failed to save CompletionRecords: \(error)")
    }
  }

  /// Check if habit is completed for a specific date (source of truth)
  func isCompletedForDate(_ date: Date) -> Bool {
    let dateKey = DateUtils.dateKey(for: date)
    let completionRecord = completionHistory.first { record in
      DateUtils.dateKey(for: record.date) == dateKey
    }
    return completionRecord?.isCompleted ?? false
  }

  /// Calculate true streak from completionHistory (source of truth)
  /// ✅ CRITICAL FIX: Includes today if completed, then counts backwards
  func calculateTrueStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var streak = 0
    var currentDate = today

    // ✅ CRITICAL FIX: Count consecutive completed days backwards from today
    // This includes today if it's completed
    while isCompletedForDate(currentDate) {
      streak += 1
      currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
      
      // Prevent infinite loop if we go too far back
      let habitStartDate = calendar.startOfDay(for: startDate)
      if currentDate < habitStartDate {
        break
      }
    }

    return streak
  }

  @MainActor
  func toHabit() -> Habit {
    // ✅ CRITICAL FIX: Always query CompletionRecords manually by habitId to ensure we get ALL records
    // The relationship might be incomplete if records were created with different userIds or not properly linked
    let habitId = self.id  // Capture for use in predicate
    let userId = self.userId  // Capture for use in predicate
    
    // ✅ CRITICAL FIX: Always query ALL CompletionRecords for this habitId first
    // Then filter by userId to handle mismatches
    let allRecordsPredicate = #Predicate<CompletionRecord> { record in
      record.habitId == habitId
    }
    let allRecordsDescriptor = FetchDescriptor<CompletionRecord>(predicate: allRecordsPredicate)
    
    let completionRecords: [CompletionRecord]
    do {
      let context = SwiftDataContainer.shared.modelContext
      
      // Query ALL CompletionRecords for this habitId
      let allRecords = try context.fetch(allRecordsDescriptor)
      
      if !allRecords.isEmpty {
        let allUserIds = Array(Set(allRecords.map { $0.userId }))
        print("🔍 toHabit() DEBUG: Found \(allRecords.count) total CompletionRecords for habit '\(self.name)' with userIds: \(allUserIds)")
      }
      
      // Now filter by userId with fallback logic
      var fetchedRecords: [CompletionRecord]
      
      // ✅ CRITICAL FIX: Handle empty string userId properly in predicate
      // SwiftData predicates need explicit handling for empty strings
      let predicate: Predicate<CompletionRecord>
      if userId.isEmpty {
        // For guest users (empty userId), match records with empty userId
        predicate = #Predicate<CompletionRecord> { record in
          record.habitId == habitId && (record.userId == "" || record.userId == "guest")
        }
      } else {
        // For authenticated users, exact match
        predicate = #Predicate<CompletionRecord> { record in
          record.habitId == habitId && record.userId == userId
        }
      }
      
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      fetchedRecords = try context.fetch(descriptor)
      
      print("🔍 toHabit(): Found \(fetchedRecords.count) CompletionRecords for habit '\(self.name)' (habitId: \(habitId), userId: '\(userId.isEmpty ? "guest" : userId)')")
      
      // ✅ CRITICAL FIX: If no records found with HabitData.userId, but records exist, use them with fallback logic
      // This handles cases where CompletionRecord was saved with different userId due to timing issues
      if fetchedRecords.isEmpty && !allRecords.isEmpty {
        // Check if there's a userId mismatch - use records anyway but log warning
        print("⚠️ toHabit() FALLBACK: No CompletionRecords found with userId '\(userId.isEmpty ? "guest" : userId)', but \(allRecords.count) exist with different userIds!")
        print("   Using all records for habit '\(self.name)' (userId mismatch may need fixing)")
        
        // ✅ FIX: For authenticated users, still use records if they exist (likely userId mismatch)
        // This prevents data loss when userId doesn't match exactly
        fetchedRecords = allRecords
      }
      
      if fetchedRecords.count > 0 {
        let userIds = Array(Set(fetchedRecords.map { $0.userId }))
        if userIds.count > 1 || (userIds.first != userId && !userId.isEmpty) {
          print("⚠️ toHabit() WARNING: CompletionRecords have userId mismatch for habit '\(self.name)'")
          print("   HabitData.userId: '\(userId.isEmpty ? "guest" : userId)'")
          print("   CompletionRecord userIds: \(userIds)")
        }
      }
      
      completionRecords = fetchedRecords
    } catch {
      print("❌ toHabit(): Failed to query CompletionRecords: \(error)")
      // Fallback to relationship if query fails
      completionRecords = completionHistory
      print("🔍 toHabit(): Falling back to relationship with \(completionRecords.count) CompletionRecords for habit '\(self.name)'")
    }

    // ✅ FILTER: Only include records for the current userId to avoid cross-user duplicates
    // ✅ CRITICAL FIX: Handle guest userId inconsistencies ("", "guest" both mean guest)
    let filteredRecords = completionRecords.filter { record in
      if self.userId.isEmpty || self.userId == "guest" {
        // For guest habits, accept both "" and "guest" userIds (legacy compatibility)
        return record.userId.isEmpty || record.userId == "guest" || record.userId == self.userId
      } else {
        // For authenticated users, exact match required
        return record.userId == self.userId
      }
    }
    
    // ✅ DEBUG: Log filtering results
    if completionRecords.count != filteredRecords.count {
      let uniqueUserIds = Array(Set(completionRecords.map { $0.userId }))
      print("⚠️ toHabit(): Filtered out \(completionRecords.count - filteredRecords.count) CompletionRecords due to userId mismatch")
      print("   HabitData.userId: '\(self.userId)'")
      print("   CompletionRecord userIds: \(uniqueUserIds)")
    }
    
    // ✅ HOTFIX: Rebuild ALL dictionaries from CompletionRecords to prevent data loss
    // ✅ CRITICAL FIX: Use DateUtils.dateKey format ("yyyy-MM-dd") to match UI queries
    
    // ✅ CRITICAL FIX: Use actual progress count from CompletionRecord instead of just 1/0
    // ✅ DEDUP: If multiple records exist for same dateKey, keep the latest by createdAt
    let reducedProgressByDate: [String: CompletionRecord] = filteredRecords
      .reduce(into: [String: CompletionRecord]()) { acc, record in
        let key = DateUtils.dateKey(for: record.date)
        if let existing = acc[key] {
          if record.createdAt > existing.createdAt { acc[key] = record }
        } else {
          acc[key] = record
        }
      }
    let completionHistoryDict: [String: Int] = reducedProgressByDate
      .mapValues { $0.progress }
    
    // ✅ FIX: Rebuild completionStatus from CompletionRecords
    let completionStatusDict: [String: Bool] = reducedProgressByDate
      .mapValues { $0.isCompleted }
    
    // ✅ FIX: Rebuild completionTimestamps from CompletionRecords
    // Note: CompletionRecord doesn't store individual timestamps, so we use createdAt as proxy
    let completionTimestampsDict: [String: [Date]] = reducedProgressByDate
      .filter { $0.value.isCompleted }
      .mapValues { [$0.createdAt] }

    let difficultyHistoryDict: [String: Int] = Dictionary(uniqueKeysWithValues: difficultyHistory
      .map {
        (DateUtils.dateKey(for: $0.date), $0.difficulty)
      })

    let actualUsageDict: [String: Int] = Dictionary(uniqueKeysWithValues: usageHistory.map {
      ($0.key, $0.value)
    })
    
    // ✅ DIAGNOSTIC LOGGING: Verify data was rebuilt correctly
    #if DEBUG
    print("🔧 HOTFIX: toHabit() for '\(name)':")
    print("  → CompletionRecords: \(filteredRecords.count)")
    print("  → completionHistory entries: \(completionHistoryDict.count)")
    print("  → completionStatus entries: \(completionStatusDict.count)")
    print("  → completionTimestamps entries: \(completionTimestampsDict.count)")
    if filteredRecords.count > 0 {
      let completedCount = filteredRecords.filter { $0.isCompleted }.count
      print("  → Completed days: \(completedCount)/\(filteredRecords.count)")
    }
    #endif

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
      completionTimestamps: completionTimestampsDict,  // ✅ NOW REBUILT!
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

  init(userId: String, habitId: UUID, date: Date, dateKey: String, isCompleted: Bool, progress: Int = 0) {
    self.userId = userId
    self.habitId = habitId
    self.date = date
    self.dateKey = dateKey
    self.isCompleted = isCompleted
    self.progress = progress  // ✅ NEW: Store actual progress count
    self.createdAt = Date()
    self.userIdHabitIdDateKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:date:dateKey:isCompleted:progress:) instead")
  init(date: Date, isCompleted: Bool) {
    self.userId = "legacy"
    let habitId = UUID()
    self.habitId = habitId
    self.date = date
    self.dateKey = ""
    self.isCompleted = isCompleted
    self.progress = isCompleted ? 1 : 0  // ✅ Legacy default
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
  var progress: Int = 0  // ✅ CRITICAL FIX: Store actual progress count (e.g., 10 for "10 times")
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
    progress: Int = 0,  // ✅ NEW: Accept progress parameter
    modelContext: ModelContext) -> Bool
  {
    let dateKey = DateUtils.dateKey(for: date)
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
          isCompleted: isCompleted,
          progress: progress)  // ✅ NEW: Store progress
        modelContext.insert(record)
        try modelContext.save()
        return true
      } else {
        // Update existing record
        if let existingRecord = existingRecords.first {
          existingRecord.isCompleted = isCompleted
          existingRecord.progress = progress  // ✅ NEW: Update progress
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
