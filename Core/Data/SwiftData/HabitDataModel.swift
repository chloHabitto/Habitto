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
    target: Int = 1,
    goalHistory: [String: String] = [:])
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
    self.goalHistoryJSON = Self.encodeGoalHistory(goalHistory)
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
  var remindersData: Data?  // JSON-encoded [ReminderItem] array
  var goalHistoryJSON: String = "{}"
  var skippedDaysJSON: String = "{}"  // JSON-encoded skipped days dictionary
  var startDate: Date
  var endDate: Date?
  var createdAt: Date
  var updatedAt: Date
  
  // Breaking habit fields (CRITICAL: Must be stored!)
  var baseline: Int = 0  // Current usage level (for breaking habits)
  var target: Int = 1    // Goal usage level (for breaking habits)
  
  // Streak tracking
  /// Best streak ever achieved for this habit
  /// ✅ PERSISTENT: Only increases, never decreases, survives data loss
  /// Updated when current calculated streak exceeds it
  var bestStreakEver: Int = 0
  
  // MARK: - Soft Delete Fields
  /// When the habit was soft-deleted (nil = active, Date = soft-deleted)
  /// Soft-deleted habits are filtered from queries but retained for audit/recovery
  var deletedAt: Date?
  
  /// Source of the deletion action for audit trail
  /// Values: "user", "sync", "migration", "cleanup"
  var deletionSource: String?

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
  
  /// Get best streak ever achieved
  /// Returns the persistent bestStreakEver value, which never decreases
  var bestStreak: Int {
    bestStreakEver
  }
  
  // MARK: - Soft Delete Methods
  
  /// Soft delete this habit (marks as deleted without removing from database)
  /// - Parameters:
  ///   - source: The source of the deletion ("user", "sync", "migration", "cleanup")
  ///   - context: ModelContext for creating the deletion log
  func softDelete(source: String, context: ModelContext) {
    // Mark as deleted
    self.deletedAt = Date()
    self.deletionSource = source
    self.updatedAt = Date()
    
    // Create audit log entry
    let log = HabitDeletionLog(
      habitId: self.id,
      habitName: self.name,
      userId: self.userId,
      source: source,
      metadata: nil
    )
    context.insert(log)
    
    // Diagnostic logging
    print("🗑️ [SOFT_DELETE] Habit soft-deleted:")
    print("   ID: \(self.id.uuidString.prefix(8))...")
    print("   Name: '\(self.name)'")
    print("   UserId: '\(self.userId.isEmpty ? "EMPTY" : self.userId.prefix(8) + "...")'")
    print("   Source: \(source)")
    print("   DeletedAt: \(self.deletedAt?.description ?? "nil")")
    
    // Log stack trace for debugging
    #if DEBUG
    print("   Call stack:")
    Thread.callStackSymbols.prefix(5).forEach { print("      \($0)") }
    #endif
  }
  
  /// Check if this habit is soft-deleted
  var isSoftDeleted: Bool {
    deletedAt != nil
  }
  
  /// Restore a soft-deleted habit (undelete)
  func restore() {
    self.deletedAt = nil
    self.deletionSource = nil
    self.updatedAt = Date()
    
    print("♻️ [RESTORE] Habit restored:")
    print("   ID: \(self.id.uuidString.prefix(8))...")
    print("   Name: '\(self.name)'")
  }

  static func decodeColor(_ data: Data) -> Color {
    guard let components = try? NSKeyedUnarchiver.unarchivedObject(
        ofClasses: [NSArray.self, NSNumber.self],
        from: data) as? [CGFloat],
        components.count == 4 else {
        return Color("appPrimary") // Default to Navy
    }
    
    // Check for sentinel
    if components[0] < 0 {
        return Color("appPrimary")  // Explicitly use asset catalog color
    }
    
    let tolerance: CGFloat = 0.02
    
    // NEW Navy (appPrimary): #2A3563 = RGB(42, 53, 99)
    let newNavyRed: CGFloat = 42.0 / 255.0
    let newNavyGreen: CGFloat = 53.0 / 255.0
    let newNavyBlue: CGFloat = 99.0 / 255.0
    
    // OLD Navy (navy500): #1C264C = RGB(28, 39, 76) - ACTUAL STORED VALUES
    let oldNavyRed: CGFloat = 28.0 / 255.0
    let oldNavyGreen: CGFloat = 39.0 / 255.0
    let oldNavyBlue: CGFloat = 76.0 / 255.0
    
    // Check for NEW Navy (appPrimary #2A3563)
    if abs(components[0] - newNavyRed) < tolerance &&
       abs(components[1] - newNavyGreen) < tolerance &&
       abs(components[2] - newNavyBlue) < tolerance {
        return Color("appPrimary")  // Return semantic color for dark mode adaptation
    }
    
    // Check for OLD Navy (navy500 #1C264C) - THIS IS WHAT'S ACTUALLY STORED
    if abs(components[0] - oldNavyRed) < tolerance &&
       abs(components[1] - oldNavyGreen) < tolerance &&
       abs(components[2] - oldNavyBlue) < tolerance {
        return Color("appPrimary")  // Return semantic color for dark mode adaptation
    }
    
    return Color(
        red: Double(components[0]),
        green: Double(components[1]),
        blue: Double(components[2]),
        opacity: Double(components[3])
    )
  }

  private static func encodeGoalHistory(_ history: [String: String]) -> String {
    guard !history.isEmpty else {
      return "{}"
    }

    if let data = try? JSONEncoder().encode(history),
       let string = String(data: data, encoding: .utf8) {
      return string
    }

    return "{}"
  }

  private static func decodeGoalHistory(_ json: String) -> [String: String] {
    guard let data = json.data(using: .utf8) else {
      return [:]
    }

    return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
  }
  
  // MARK: - SkippedDays Encoding/Decoding
  
  private static func encodeSkippedDays(_ skippedDays: [String: HabitSkip]) -> String {
    guard !skippedDays.isEmpty else {
      print("⏭️ [ENCODE_SKIP] No skipped days to encode")
      return "{}"
    }
    
    print("⏭️ [ENCODE_SKIP] Encoding \(skippedDays.count) skipped day(s)")
    
    // Convert HabitSkip to a simpler dictionary for JSON encoding
    var jsonDict: [String: [String: Any]] = [:]
    let formatter = ISO8601DateFormatter()
    
    for (dateKey, skip) in skippedDays {
      print("   ⏭️ Encoding skip: \(dateKey) -> \(skip.reason.rawValue)")
      
      var entry: [String: Any] = [
        "habitId": skip.habitId.uuidString,
        "dateKey": skip.dateKey,
        "reason": skip.reason.rawValue,
        "createdAt": formatter.string(from: skip.createdAt)
      ]
      
      // Only add customNote if it has a value (avoid null in JSON)
      if let note = skip.customNote, !note.isEmpty {
        entry["customNote"] = note
        print("   ⏭️ Including customNote: \(note.prefix(20))...")
      } else {
        print("   ⏭️ Omitting customNote (nil or empty)")
      }
      
      jsonDict[dateKey] = entry
    }
    
    guard let data = try? JSONSerialization.data(withJSONObject: jsonDict),
          let string = String(data: data, encoding: .utf8) else {
      print("❌ [ENCODE_SKIP] Failed to serialize JSON")
      return "{}"
    }
    
    print("⏭️ [ENCODE_SKIP] SUCCESS: \(string.prefix(100))...")
    return string
  }
  
  private static func decodeSkippedDays(_ json: String, habitId: UUID) -> [String: HabitSkip] {
    print("⏭️ [DECODE_SKIP] Input JSON: \(json.prefix(150))...")
    
    guard json != "{}", !json.isEmpty else {
      print("⏭️ [DECODE_SKIP] Empty JSON, returning empty dictionary")
      return [:]
    }
    
    guard let data = json.data(using: .utf8) else {
      print("❌ [DECODE_SKIP] Failed to convert JSON string to Data")
      return [:]
    }
    
    // Use [String: [String: Any]] to handle null values and different types
    guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
      print("❌ [DECODE_SKIP] Failed to parse JSON as dictionary")
      print("❌ [DECODE_SKIP] Raw data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
      return [:]
    }
    
    print("⏭️ [DECODE_SKIP] Found \(dict.count) entries in JSON")
    
    var result: [String: HabitSkip] = [:]
    let formatter = ISO8601DateFormatter()
    
    for (dateKey, skipDict) in dict {
      print("⏭️ [DECODE_SKIP] Processing entry for \(dateKey)...")
      print("⏭️ [DECODE_SKIP]   Keys in entry: \(skipDict.keys.joined(separator: ", "))")
      
      // Extract reason (required)
      guard let reasonRaw = skipDict["reason"] as? String else {
        print("⚠️ [DECODE_SKIP] Missing or invalid 'reason' for \(dateKey) (value: \(skipDict["reason"] ?? "nil"))")
        continue
      }
      guard let reason = SkipReason.allCases.first(where: { $0.rawValue == reasonRaw }) else {
        print("⚠️ [DECODE_SKIP] Unknown reason '\(reasonRaw)' for \(dateKey)")
        continue
      }
      
      // Extract createdAt (required)
      guard let createdAtString = skipDict["createdAt"] as? String else {
        print("⚠️ [DECODE_SKIP] Missing or invalid 'createdAt' for \(dateKey) (value: \(skipDict["createdAt"] ?? "nil"))")
        continue
      }
      guard let createdAt = formatter.date(from: createdAtString) else {
        print("⚠️ [DECODE_SKIP] Failed to parse createdAt '\(createdAtString)' for \(dateKey)")
        continue
      }
      
      // Extract customNote (optional - can be null, missing, or empty string)
      let customNote: String?
      if let noteValue = skipDict["customNote"] {
        if let noteString = noteValue as? String, !noteString.isEmpty {
          customNote = noteString
          print("⏭️ [DECODE_SKIP]   customNote: '\(noteString.prefix(20))...'")
        } else {
          customNote = nil
          print("⏭️ [DECODE_SKIP]   customNote: null or empty (value type: \(type(of: noteValue)))")
        }
      } else {
        customNote = nil
        print("⏭️ [DECODE_SKIP]   customNote: missing key")
      }
      
      // Extract habitId from JSON or use the provided one
      let skipHabitId: UUID
      if let habitIdString = skipDict["habitId"] as? String,
         let parsedId = UUID(uuidString: habitIdString) {
        skipHabitId = parsedId
      } else {
        skipHabitId = habitId
      }
      
      let skip = HabitSkip(
        habitId: skipHabitId,
        dateKey: dateKey,
        reason: reason,
        customNote: customNote,
        createdAt: createdAt
      )
      
      result[dateKey] = skip
      print("   ⏭️ Decoded skip: \(dateKey) -> \(reason.shortLabel)")
    }
    
    print("⏭️ [DECODE_SKIP] SUCCESS: Decoded \(result.count) skipped day(s) for habit \(habitId.uuidString.prefix(8))...")
    return result
  }

  // MARK: - Reminders Encoding/Decoding

  private static func encodeReminders(_ reminders: [ReminderItem]) -> Data? {
    guard !reminders.isEmpty else { return nil }
    return try? JSONEncoder().encode(reminders)
  }

  private static func decodeReminders(_ data: Data?) -> [ReminderItem] {
    guard let data = data else { return [] }
    return (try? JSONDecoder().decode([ReminderItem].self, from: data)) ?? []
  }

  // MARK: - Update Methods

  @MainActor
  func updateFromHabit(_ habit: Habit) async {
    print("⏭️ [UPDATE_FROM_HABIT] Updating HabitData for '\(habit.name)'")
    print("⏭️ [UPDATE_FROM_HABIT] Habit has \(habit.skippedDays.count) skipped day(s)")
    
    name = habit.name
    habitDescription = habit.description
    icon = habit.icon
    color = habit.color.color
    habitTypeEnum = habit.habitType
    schedule = habit.schedule
    goal = habit.goal
    reminder = habit.reminder
    remindersData = Self.encodeReminders(habit.reminders)
    startDate = habit.startDate
    endDate = habit.endDate
    baseline = habit.baseline
    target = habit.target
    goalHistoryJSON = Self.encodeGoalHistory(habit.goalHistory)
    
    // ⏭️ SKIP FEATURE: Encode and save skipped days
    skippedDaysJSON = Self.encodeSkippedDays(habit.skippedDays)
    print("⏭️ [UPDATE_FROM_HABIT] Saved skippedDaysJSON: \(skippedDaysJSON.prefix(100))...")
    
    updatedAt = Date()
    // Note: isCompleted and streak are now computed properties
    
    // ✅ CRITICAL FIX: Sync CompletionRecords from habit.completionHistory
    // This ensures CompletionRecords exist for all dates in completionHistory
    // to prevent data loss when habits are reloaded
    // ✅ CRITICAL FIX: Await sync to prevent race conditions where habit is saved before CompletionRecords are synced
    await syncCompletionRecordsFromHabit(habit)
    
    // ✅ PERSISTENT BEST STREAK: Update bestStreakEver when habit is saved
    // This ensures best streak is preserved even if completion records are lost
    // Only update if current calculated streak exceeds bestStreakEver
    let currentStreak = calculateTrueStreak()
    if currentStreak > bestStreakEver {
      bestStreakEver = currentStreak
    }
  }
  
  /// Sync CompletionRecords from habit's completionHistory to ensure all dates have records
  /// ✅ CRITICAL FIX: This method ADDITIVELY syncs records from completionHistory.
  /// It does NOT delete existing CompletionRecords that aren't in completionHistory.
  /// This preserves data integrity when habits are loaded from Firestore with empty completionHistory.
  @MainActor
  private func syncCompletionRecordsFromHabit(_ habit: Habit) async {
    let context = SwiftDataContainer.shared.modelContext
    // ✅ CRITICAL FIX: Parse dateString as "yyyy-MM-dd" format (dateKey format)
    // completionHistory uses DateUtils.dateKey format, not ISO8601
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    
    var syncedCount = 0
    var createdCount = 0
    var updatedCount = 0
    
    let habitId = self.id
    let habitUserId = self.userId
    let habitRecordsPredicate = #Predicate<CompletionRecord> { record in
      record.habitId == habitId && record.userId == habitUserId
    }
    let habitRecordsDescriptor = FetchDescriptor<CompletionRecord>(predicate: habitRecordsPredicate)
    let existingRecords = (try? context.fetch(habitRecordsDescriptor)) ?? []
    
    // ✅ FIX: Handle duplicate dateKeys by keeping the most recent record
    // Dictionary(uniqueKeysWithValues:) crashes if there are duplicate keys
    var duplicateCount = 0
    let existingRecordsByDate: [String: CompletionRecord] = existingRecords
      .reduce(into: [String: CompletionRecord]()) { acc, record in
        let key = record.dateKey
        if let existing = acc[key] {
          // Keep the most recent record if duplicates exist
          duplicateCount += 1
          if record.createdAt > existing.createdAt {
            acc[key] = record
          }
        } else {
          acc[key] = record
        }
      }
    
    // Log warning if duplicates were found
    if duplicateCount > 0 {
      print("⚠️ syncCompletionRecordsFromHabit: Found \(duplicateCount) duplicate dateKey(s) for habit '\(habit.name)' - kept most recent records")
    }
    
    var parsedEntries: [(date: Date, dateKey: String, progress: Int, isCompleted: Bool)] = []
    for (dateString, progress) in habit.completionHistory {
      guard let date = dateFormatter.date(from: dateString) ?? ISO8601DateHelper.shared.dateWithFallback(from: dateString) else {
        debugLog("⚠️ syncCompletionRecordsFromHabit: Failed to parse dateString '\(dateString)' for habit '\(habit.name)'")
        continue
      }
      let dateKey = DateUtils.dateKey(for: date)
      let recordedStatus = habit.completionStatus[dateKey]
      let goalAmount = habit.goalAmount(for: date)
      let isCompleted = recordedStatus ?? (progress >= goalAmount)
      parsedEntries.append((date, dateKey, progress, isCompleted))
    }
    
    let requiresSync = parsedEntries.contains { entry in
      guard let existingRecord = existingRecordsByDate[entry.dateKey] else { return true }
      return existingRecord.isCompleted != entry.isCompleted || existingRecord.progress != entry.progress
    }
    
    if !requiresSync && parsedEntries.count == existingRecordsByDate.count {
      debugLog("ℹ️ syncCompletionRecordsFromHabit: Habit '\(habit.name)' already synced - skipping")
      return
    }
    
    // ✅ CRITICAL FIX: Only sync records FROM completionHistory (additive approach)
    // This ensures we don't lose CompletionRecords that exist in SwiftData but not in habit.completionHistory
    // (e.g., when habit is loaded from Firestore with empty completionHistory)
    for entry in parsedEntries {
      let date = entry.date
      let dateKey = entry.dateKey
      let progress = entry.progress
      let isCompleted = entry.isCompleted
      
      // Check if CompletionRecord already exists
      let uniqueKey = "\(self.userId)#\(self.id.uuidString)#\(dateKey)"
      let predicate = #Predicate<CompletionRecord> { record in
        record.userIdHabitIdDateKey == uniqueKey
      }
      var descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      descriptor.includePendingChanges = true  // ✅ FIX: See just-saved records
      
      do {
        let existingRecords = try context.fetch(descriptor)
        
        // ✅ FIX: Handle duplicates by deleting all and creating fresh one
        // This ensures exactly ONE CompletionRecord per habit/date/user
        if !existingRecords.isEmpty {
          if existingRecords.count > 1 {
            print("⚠️ syncCompletionRecordsFromHabit: Found \(existingRecords.count) duplicate CompletionRecords for habit '\(habit.name)' on \(dateKey) - deleting duplicates")
          }
          
          // Delete ALL existing records (handles duplicates)
          for existingRecord in existingRecords {
            context.delete(existingRecord)
          }
          
          // Create fresh record with current state
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
          
          updatedCount += existingRecords.count
          syncedCount += 1
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
          createdCount += 1
          syncedCount += 1
        }
      } catch {
        print("❌ syncCompletionRecordsFromHabit: Failed to fetch/update CompletionRecord for \(dateKey): \(error)")
      }
    }
    
    // ✅ CRITICAL FIX: Log warning if completionHistory is empty but CompletionRecords exist
    // This helps diagnose data loss issues
    if habit.completionHistory.isEmpty {
      // Check if CompletionRecords exist for this habit
      if !existingRecords.isEmpty {
        debugLog(
          "⚠️ syncCompletionRecordsFromHabit: Habit '\(habit.name)' has empty completionHistory but \(existingRecords.count) CompletionRecords exist - preserving existing records")
      }
    }
    
    // Save changes
    do {
      try context.save()
      if syncedCount > 0 {
        print("✅ syncCompletionRecordsFromHabit: Synced \(syncedCount) CompletionRecords for habit '\(habit.name)' (created: \(createdCount), updated: \(updatedCount))")
      } else if !habit.completionHistory.isEmpty {
        print("⚠️ syncCompletionRecordsFromHabit: No CompletionRecords synced for habit '\(habit.name)' despite \(habit.completionHistory.count) entries in completionHistory")
      }
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
  /// ✅ PERSISTENT BEST STREAK: Updates bestStreakEver if current streak exceeds it
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
    
    // ✅ PERSISTENT BEST STREAK: Update bestStreakEver if current streak exceeds it
    // This ensures best streak survives even if completion records are lost
    if streak > bestStreakEver {
      bestStreakEver = streak
      // Note: We don't save here to avoid performance issues
      // The save will happen when the habit is saved elsewhere
    }

    return streak
  }
  
  /// Calculate best streak from all history and update bestStreakEver
  /// This method iterates through all dates to find the longest consecutive streak
  /// ✅ PERSISTENT BEST STREAK: Updates bestStreakEver if found streak exceeds it
  func calculateAndUpdateBestStreak() -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let startDate = calendar.startOfDay(for: self.startDate)
    let vacationManager = VacationManager.shared
    
    var maxStreak = 0
    var currentStreak = 0
    var currentDate = startDate
    
    // Iterate through all dates from habit start to today
    while currentDate <= today {
      // Skip vacation days during active vacation - they don't count toward or break streaks
      if vacationManager.isActive, vacationManager.isVacationDay(currentDate) {
        // Move to next day without affecting streak
        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        continue
      }
      
      if isCompletedForDate(currentDate) {
        currentStreak += 1
        maxStreak = max(maxStreak, currentStreak)
      } else {
        currentStreak = 0
      }
      
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
    // ✅ PERSISTENT BEST STREAK: Update bestStreakEver if calculated streak exceeds it
    // This ensures best streak survives even if completion records are lost
    if maxStreak > bestStreakEver {
      bestStreakEver = maxStreak
    }
    
    // Always return bestStreakEver (the persistent value) to ensure it never decreases
    return bestStreakEver
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
    var allRecords: [CompletionRecord] = []
    
    do {
      let context = SwiftDataContainer.shared.modelContext
      
      // Query ALL CompletionRecords for this habitId
      allRecords = try context.fetch(allRecordsDescriptor)
      
      #if DEBUG
      // ✅ DIAGNOSTIC: Log what records were found
      if !allRecords.isEmpty {
        let recordsByUserId = Dictionary(grouping: allRecords) { $0.userId }
        print("🔍 [HABIT_TO_HABIT] Habit '\(self.name)' (id: \(habitId.uuidString.prefix(8))...)")
        print("   Habit userId: '\(userId.isEmpty ? "EMPTY" : userId.prefix(8))...'")
        print("   Total CompletionRecords found: \(allRecords.count)")
        for (recordUserId, records) in recordsByUserId {
          let userIdDisplay = recordUserId.isEmpty ? "EMPTY STRING" : "\(recordUserId.prefix(8))..."
          print("     Records with userId '\(userIdDisplay)': \(records.count)")
        }
      }
      #endif
      
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
      
      // ✅ CRITICAL FIX: If no records found with HabitData.userId, but records exist, use them with fallback logic
      // This handles cases where CompletionRecord was saved with different userId due to timing issues
      if fetchedRecords.isEmpty && !allRecords.isEmpty {
        #if DEBUG
        print("⚠️ [HABIT_TO_HABIT] No records found with userId '\(userId.isEmpty ? "EMPTY" : userId.prefix(8))...', but \(allRecords.count) records exist - using all records as fallback")
        #endif
        // ✅ FIX: For authenticated users, still use records if they exist (likely userId mismatch)
        // This prevents data loss when userId doesn't match exactly
        fetchedRecords = allRecords
      }
      
      completionRecords = fetchedRecords
      
      #if DEBUG
      // ✅ DIAGNOSTIC: Log final filtered records
      if !completionRecords.isEmpty {
        print("✅ [HABIT_TO_HABIT] Habit '\(self.name)' - Using \(completionRecords.count) completion records after filtering")
      } else if !allRecords.isEmpty {
        print("⚠️ [HABIT_TO_HABIT] Habit '\(self.name)' - Filtered out all \(allRecords.count) records (userId mismatch?)")
      }
      #endif
    } catch {
      // Fallback to relationship if query fails
      completionRecords = completionHistory
    }

    // ✅ CRITICAL FIX: Use ALL records found for this habitId, regardless of userId mismatch
    // This prevents data loss when records were saved with different userId (e.g., guest -> authenticated)
    // We'll fix the userId later via repair function, but for now we need to show the data
    let filteredRecords: [CompletionRecord]
    if completionRecords.isEmpty && !allRecords.isEmpty {
      // If no records matched userId but records exist, use all records (userId mismatch)
      #if DEBUG
      print("⚠️ [HABIT_TO_HABIT] Using ALL \(allRecords.count) records due to userId mismatch - will repair userId later")
      #endif
      filteredRecords = allRecords
    } else if !completionRecords.isEmpty {
      // Use records that matched userId
      filteredRecords = completionRecords
    } else {
      // No records found at all - use empty array
      filteredRecords = []
    }
    
    
    // ✅ HOTFIX: Rebuild ALL dictionaries from CompletionRecords to prevent data loss
    // ✅ CRITICAL FIX: Use DateUtils.dateKey format ("yyyy-MM-dd") to match UI queries
    
    // ✅ CRITICAL FIX: Use actual progress count from CompletionRecord instead of just 1/0
    // ✅ DEDUP: If multiple records exist for same dateKey, keep the latest by updatedAt
    let reducedProgressByDate: [String: CompletionRecord] = filteredRecords
      .reduce(into: [String: CompletionRecord]()) { acc, record in
        let key = DateUtils.dateKey(for: record.date)
        if let existing = acc[key] {
          // ✅ FIX: Use updatedAt for comparison (this is what sync updates)
          let existingTimestamp = existing.updatedAt ?? existing.createdAt
          let recordTimestamp = record.updatedAt ?? record.createdAt
          
          if recordTimestamp > existingTimestamp {
            acc[key] = record
          }
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

    // ✅ CRITICAL FIX: Load difficulty history from SwiftData relationship
    // DifficultyRecord doesn't have habitId/userId properties (SwiftData limitation),
    // so we must use the relationship which is automatically filtered by SwiftData
    // The relationship should be loaded when HabitData is fetched
    let difficultyRecords = difficultyHistory
    
    // ✅ FIX: Handle duplicate dateKeys by keeping the most recent record
    // Similar to completionHistoryDict, use reduce to deduplicate
    let reducedDifficultyByDate: [String: DifficultyRecord] = difficultyRecords
      .reduce(into: [String: DifficultyRecord]()) { acc, record in
        let key = record.dateKey.isEmpty ? DateUtils.dateKey(for: record.date) : record.dateKey
        if let existing = acc[key] {
          // Keep the most recent record if duplicates exist
          if record.createdAt > existing.createdAt {
            acc[key] = record
          }
        } else {
          acc[key] = record
        }
      }
    
    let difficultyHistoryDict: [String: Int] = reducedDifficultyByDate
      .mapValues { $0.difficulty }

    let actualUsageDict: [String: Int] = Dictionary(uniqueKeysWithValues: usageHistory.map {
      ($0.key, $0.value)
    })
    

    var habit = Habit(
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
      createdAt: createdAt,
      reminders: Self.decodeReminders(remindersData),
      baseline: baseline,
      target: target,
      completionHistory: completionHistoryDict,
      completionStatus: completionStatusDict,  // ✅ NOW REBUILT!
      completionTimestamps: completionTimestampsDict,  // ✅ NOW REBUILT!
      difficultyHistory: difficultyHistoryDict,
      actualUsage: actualUsageDict,
      goalHistory: Self.decodeGoalHistory(goalHistoryJSON))
    
    // ✅ SKIP FEATURE: Load skipped days from storage
    habit.skippedDays = Self.decodeSkippedDays(skippedDaysJSON, habitId: self.id)
    
    #if DEBUG
    if !habit.skippedDays.isEmpty {
      print("⏭️ [HABIT_LOAD] Loaded \(habit.skippedDays.count) skipped day(s) for habit '\(habit.name)'")
      for (dateKey, skip) in habit.skippedDays {
        print("   ⏭️ \(dateKey): \(skip.reason.shortLabel)")
      }
    }
    #endif
    
    return habit
  }

  // MARK: Private

  // MARK: - Color Encoding/Decoding

  private static func encodeColor(_ color: Color) -> Data {
    // ✅ FIX: Explicitly use Color("appPrimary") instead of .primary
    // This avoids Swift's name resolution picking SwiftUI's built-in .primary
    let appPrimaryColor = Color("appPrimary")
    
    // Resolve both colors in light AND dark mode for comparison
    let primaryUIColorLight = UIColor(appPrimaryColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let primaryUIColorDark = UIColor(appPrimaryColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    let colorUIColorLight = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let colorUIColorDark = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    
    var primaryRedLight: CGFloat = 0, primaryGreenLight: CGFloat = 0, primaryBlueLight: CGFloat = 0, primaryAlphaLight: CGFloat = 0
    primaryUIColorLight.getRed(&primaryRedLight, green: &primaryGreenLight, blue: &primaryBlueLight, alpha: &primaryAlphaLight)
    
    var primaryRedDark: CGFloat = 0, primaryGreenDark: CGFloat = 0, primaryBlueDark: CGFloat = 0, primaryAlphaDark: CGFloat = 0
    primaryUIColorDark.getRed(&primaryRedDark, green: &primaryGreenDark, blue: &primaryBlueDark, alpha: &primaryAlphaDark)
    
    var colorRedLight: CGFloat = 0, colorGreenLight: CGFloat = 0, colorBlueLight: CGFloat = 0, colorAlphaLight: CGFloat = 0
    colorUIColorLight.getRed(&colorRedLight, green: &colorGreenLight, blue: &colorBlueLight, alpha: &colorAlphaLight)
    
    var colorRedDark: CGFloat = 0, colorGreenDark: CGFloat = 0, colorBlueDark: CGFloat = 0, colorAlphaDark: CGFloat = 0
    colorUIColorDark.getRed(&colorRedDark, green: &colorGreenDark, blue: &colorBlueDark, alpha: &colorAlphaDark)
    
    // Use a more generous tolerance for floating point comparison
    let tolerance: CGFloat = 0.02
    
    // Check if this color matches appPrimary in BOTH light and dark modes
    let matchesLight = abs(colorRedLight - primaryRedLight) < tolerance &&
                       abs(colorGreenLight - primaryGreenLight) < tolerance &&
                       abs(colorBlueLight - primaryBlueLight) < tolerance
    
    let matchesDark = abs(colorRedDark - primaryRedDark) < tolerance &&
                      abs(colorGreenDark - primaryGreenDark) < tolerance &&
                      abs(colorBlueDark - primaryBlueDark) < tolerance
    
    // If it matches BOTH appearances, it's the semantic Navy/primary color
    if matchesLight && matchesDark {
      // Store sentinel value to preserve semantic color
      let components: [CGFloat] = [-1.0, 0.0, 0.0, 1.0]
      return (try? NSKeyedArchiver.archivedData(withRootObject: components, requiringSecureCoding: true)) ?? Data()
    }
    
    // Also check if it matches JUST the light mode value (for existing habits)
    // This catches habits saved with fixed RGB that should be Navy
    
    // NEW Navy (appPrimary): #2A3563 = RGB(42, 53, 99)
    let newNavyLightRed: CGFloat = 42.0 / 255.0  // 0x2A = 42
    let newNavyLightGreen: CGFloat = 53.0 / 255.0  // 0x35 = 53
    let newNavyLightBlue: CGFloat = 99.0 / 255.0  // 0x63 = 99
    
    if abs(colorRedLight - newNavyLightRed) < tolerance &&
       abs(colorGreenLight - newNavyLightGreen) < tolerance &&
       abs(colorBlueLight - newNavyLightBlue) < tolerance {
      // This is NEW Navy stored as fixed RGB, store as semantic
      let components: [CGFloat] = [-1.0, 0.0, 0.0, 1.0]
      return (try? NSKeyedArchiver.archivedData(withRootObject: components, requiringSecureCoding: true)) ?? Data()
    }
    
    // OLD Navy (navy500): #1C264C = RGB(28, 39, 76)
    let oldNavyLightRed: CGFloat = 28.0 / 255.0
    let oldNavyLightGreen: CGFloat = 39.0 / 255.0
    let oldNavyLightBlue: CGFloat = 76.0 / 255.0
    
    if abs(colorRedLight - oldNavyLightRed) < tolerance &&
       abs(colorGreenLight - oldNavyLightGreen) < tolerance &&
       abs(colorBlueLight - oldNavyLightBlue) < tolerance {
      // This is OLD Navy stored as fixed RGB, store as semantic
      let components: [CGFloat] = [-1.0, 0.0, 0.0, 1.0]
      return (try? NSKeyedArchiver.archivedData(withRootObject: components, requiringSecureCoding: true)) ?? Data()
    }
    
    // For non-Navy colors, store the actual RGB values
    let uiColor = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let components: [CGFloat] = [red, green, blue, alpha]
    return (try? NSKeyedArchiver.archivedData(withRootObject: components, requiringSecureCoding: true)) ?? Data()
  }
}

// MARK: - HabitDeletionLog

/// Audit log for all habit deletion events
/// This model provides a complete audit trail to investigate data loss
@Model
final class HabitDeletionLog {
  // MARK: Lifecycle
  
  init(
    habitId: UUID,
    habitName: String,
    userId: String,
    source: String,
    metadata: String? = nil
  ) {
    self.id = UUID()
    self.habitId = habitId
    self.habitName = habitName
    self.userId = userId
    self.deletedAt = Date()
    self.source = source
    self.metadata = metadata
  }
  
  // MARK: Internal
  
  /// Unique identifier for this deletion log entry
  @Attribute(.unique) var id: UUID
  
  /// ID of the habit that was deleted
  var habitId: UUID
  
  /// Name of the habit (preserved for debugging)
  var habitName: String
  
  /// User who owned the habit
  var userId: String
  
  /// When the deletion occurred
  var deletedAt: Date
  
  /// Source of deletion: "user", "sync", "migration", "cleanup"
  var source: String
  
  /// Optional JSON metadata for additional context
  /// Examples:
  /// - {"screen": "HabitsTabView", "method": "swipeToDelete"}
  /// - {"syncConflict": "remoteDeleted", "hasLocalRecords": true}
  /// - {"migration": "v1_to_v2", "reason": "invalidData"}
  var metadata: String?
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
    self.updatedAt = Date()
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
    self.updatedAt = Date()
  }

  // MARK: Internal

  var userId: String
  var habitId: UUID
  var date: Date
  var dateKey: String // ✅ PHASE 5: Added field for date-based queries (indexing not supported in
  // current SwiftData)
  var isCompleted: Bool {
    didSet { updatedAt = Date() }
  }
  var progress: Int = 0 {  // ✅ CRITICAL FIX: Store actual progress count (e.g., 10 for "10 times")
    didSet { updatedAt = Date() }
  }
  var createdAt: Date
  var updatedAt: Date?

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

  init(userId _: String, habitId _: UUID, dateKey: String, difficulty: Int) {
    self.dateKey = dateKey
    self.date = DateUtils.date(from: dateKey) ?? Date()
    self.difficulty = difficulty
    self.createdAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:dateKey:difficulty:) instead")
  init(userId _: String, habitId _: UUID, date: Date, difficulty: Int) {
    self.dateKey = DateUtils.dateKey(for: date)
    self.date = date
    self.difficulty = difficulty
    self.createdAt = Date()
  }

  /// Legacy initializer for backward compatibility
  @available(*, deprecated, message: "Use init(userId:habitId:dateKey:difficulty:) instead")
  init(date: Date, difficulty: Int) {
    self.dateKey = DateUtils.dateKey(for: date)
    self.date = date
    self.difficulty = difficulty
    self.createdAt = Date()
  }

  // MARK: Internal

  var dateKey: String = ""
  // @Attribute(.indexed) // Not supported in current SwiftData version var userId: String
  // @Attribute(.indexed) // Not supported in current SwiftData version var habitId: UUID
  var date: Date
  var difficulty: Int
  var createdAt: Date
  
  /// ✅ FIX: Inverse relationship to HabitData for proper linking
  @Relationship(inverse: \HabitData.difficultyHistory) var habit: HabitData?
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
