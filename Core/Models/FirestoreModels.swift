//
//  FirestoreModels.swift
//  Habitto
//
//  Firestore data models matching the schema specification
//

import Foundation
import FirebaseFirestore
import SwiftUI
import SwiftData

// MARK: - FirestoreHabit

/// Habit document stored in /users/{uid}/habits/{habitId}
struct FirestoreHabit: Codable, Identifiable {
  @DocumentID var id: String?
  var name: String
  var description: String
  var icon: String
  var color: String // Store as hex string
  var habitType: String
  var schedule: String
  var goal: String
  var reminder: String
  var startDate: Date
  var endDate: Date?
  var createdAt: Date
  var reminders: [String] // Store as array of strings
  var baseline: Int
  var target: Int
  var completionHistory: [String: Int]
  var completionStatus: [String: Bool]
  var completionTimestamps: [String: [Date]]
  var difficultyHistory: [String: Int]
  var actualUsage: [String: Int]
  var skippedDaysJSON: String  // JSON-encoded skipped days dictionary
  var isActive: Bool
  
  // MARK: - Sync Metadata (Phase 1: Dual-Write)
  var lastSyncedAt: Date?
  var syncStatus: String? // Store as string: "pending", "syncing", "synced", "failed" (optional for backward compatibility)
  
  // MARK: - Skip Data Encoding/Decoding
  
  /// Encode skipped days dictionary to JSON string for Firestore storage
  private static func encodeSkippedDays(_ skippedDays: [String: HabitSkip]) -> String {
    guard !skippedDays.isEmpty else { return "{}" }
    
    var jsonDict: [String: [String: Any]] = [:]
    let formatter = ISO8601DateFormatter()
    
    for (dateKey, skip) in skippedDays {
      var entry: [String: Any] = [
        "habitId": skip.habitId.uuidString,
        "dateKey": skip.dateKey,
        "reason": skip.reason.rawValue,
        "createdAt": formatter.string(from: skip.createdAt)
      ]
      if let note = skip.customNote, !note.isEmpty {
        entry["customNote"] = note
      }
      jsonDict[dateKey] = entry
    }
    
    guard let data = try? JSONSerialization.data(withJSONObject: jsonDict),
          let string = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return string
  }
  
  /// Decode skipped days from JSON string to dictionary
  private static func decodeSkippedDays(_ json: String, habitId: UUID) -> [String: HabitSkip] {
    guard json != "{}", !json.isEmpty,
          let data = json.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
      return [:]
    }
    
    var result: [String: HabitSkip] = [:]
    let formatter = ISO8601DateFormatter()
    
    for (dateKey, skipDict) in dict {
      guard let reasonRaw = skipDict["reason"] as? String,
            let reason = SkipReason.allCases.first(where: { $0.rawValue == reasonRaw }),
            let createdAtString = skipDict["createdAt"] as? String,
            let createdAt = formatter.date(from: createdAtString) else {
        continue
      }
      
      let customNote = skipDict["customNote"] as? String
      let skipHabitId: UUID
      if let idString = skipDict["habitId"] as? String, let parsed = UUID(uuidString: idString) {
        skipHabitId = parsed
      } else {
        skipHabitId = habitId
      }
      
      result[dateKey] = HabitSkip(
        habitId: skipHabitId,
        dateKey: dateKey,
        reason: reason,
        customNote: customNote,
        createdAt: createdAt
      )
    }
    return result
  }
  
  // MARK: Firestore conversion
  
  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "name": name,
      "description": description,
      "icon": icon,
      "color": color,
      "habitType": habitType,
      "schedule": schedule,
      "goal": goal,
      "reminder": reminder,
      "startDate": startDate,
      "createdAt": createdAt,
      "reminders": reminders,
      "baseline": baseline,
      "target": target,
      "completionHistory": completionHistory,
      "completionStatus": completionStatus,
      "completionTimestamps": completionTimestamps,
      "difficultyHistory": difficultyHistory,
      "actualUsage": actualUsage,
      "skippedDaysJSON": skippedDaysJSON,
      "isActive": isActive,
      "syncStatus": syncStatus ?? "pending"  // Default for backward compatibility
    ]
    
    if let endDate = endDate {
      data["endDate"] = endDate
    }
    
    if let lastSyncedAt = lastSyncedAt {
      data["lastSyncedAt"] = lastSyncedAt
    }
    
    return data
  }
  
  init(from habit: Habit) {
    // ✅ FIX: Don't set @DocumentID when creating documents
    // The document ID is set explicitly via .document(id) in FirestoreService
    // @DocumentID is only populated when READING from Firestore
    self.id = nil
    self.name = habit.name
    self.description = habit.description
    self.icon = habit.icon
    self.color = habit.color.hexString
    self.habitType = habit.habitType.rawValue
    self.schedule = habit.schedule
    self.goal = habit.goal
    self.reminder = habit.reminder
    self.startDate = habit.startDate
    self.endDate = habit.endDate
    self.createdAt = habit.createdAt
    self.reminders = habit.reminders.map { $0.id.uuidString }
    self.baseline = habit.baseline
    self.target = habit.target
    self.completionHistory = habit.completionHistory
    self.completionStatus = habit.completionStatus
    self.completionTimestamps = habit.completionTimestamps
    self.difficultyHistory = habit.difficultyHistory
    self.actualUsage = habit.actualUsage
    // Encode skipped days to JSON for Firestore storage
    self.skippedDaysJSON = Self.encodeSkippedDays(habit.skippedDays)
    self.isActive = true
    // Sync metadata
    self.lastSyncedAt = habit.lastSyncedAt
    self.syncStatus = habit.syncStatus.rawValue
  }
  
  init(
    id: String?,
    name: String,
    description: String,
    icon: String,
    color: String,
    habitType: String,
    schedule: String,
    goal: String,
    reminder: String,
    startDate: Date,
    endDate: Date?,
    createdAt: Date,
    reminders: [String],
    baseline: Int,
    target: Int,
    completionHistory: [String: Int],
    completionStatus: [String: Bool],
    completionTimestamps: [String: [Date]],
    difficultyHistory: [String: Int],
    actualUsage: [String: Int],
    skippedDaysJSON: String = "{}",
    isActive: Bool,
    lastSyncedAt: Date? = nil,
    syncStatus: String? = "pending"
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.icon = icon
    self.color = color
    self.habitType = habitType
    self.schedule = schedule
    self.goal = goal
    self.reminder = reminder
    self.startDate = startDate
    self.endDate = endDate
    self.createdAt = createdAt
    self.reminders = reminders
    self.baseline = baseline
    self.target = target
    self.completionHistory = completionHistory
    self.completionStatus = completionStatus
    self.completionTimestamps = completionTimestamps
    self.difficultyHistory = difficultyHistory
    self.actualUsage = actualUsage
    self.skippedDaysJSON = skippedDaysJSON
    self.isActive = isActive
    self.lastSyncedAt = lastSyncedAt
    self.syncStatus = syncStatus
  }
  
  @MainActor
  func toHabit() -> Habit? {
    guard let id = id,
          let uuid = UUID(uuidString: id),
          let habitType = HabitType(rawValue: self.habitType) else {
      return nil
    }
    
    let color = Color(hex: self.color)
    
    let reminderItems = reminders.compactMap { reminderId in
      ReminderItem(id: UUID(uuidString: reminderId) ?? UUID(), time: Date(), isActive: true)
    }
    
    // Convert syncStatus string back to enum (with default for backward compatibility)
    let status = FirestoreSyncStatus(rawValue: syncStatus ?? "pending") ?? .pending
    
    // ✅ CRITICAL FIX: Query CompletionRecords from SwiftData as source of truth
    // Even when loading from Firestore, CompletionRecords may have newer/correct data
    let (finalCompletionHistory, finalCompletionStatus) = queryCompletionRecords(
      habitId: uuid,
      userId: FirebaseConfiguration.currentUserId ?? "unknown",
      firestoreHistory: completionHistory,
      firestoreStatus: completionStatus
    )
    
    var habit = Habit(
      id: uuid,
      name: name,
      description: description,
      icon: icon,
      color: CodableColor(color),
      habitType: habitType,
      schedule: schedule,
      goal: goal,
      reminder: reminder,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      reminders: reminderItems,
      baseline: baseline,
      target: target,
      completionHistory: finalCompletionHistory,  // ✅ From CompletionRecords
      completionStatus: finalCompletionStatus,    // ✅ From CompletionRecords
      completionTimestamps: completionTimestamps, // Keep Firestore version (not critical)
      difficultyHistory: difficultyHistory,
      actualUsage: actualUsage,
      lastSyncedAt: lastSyncedAt,
      syncStatus: status
    )
    
    // ✅ SKIP FEATURE: Restore skipped days from Firestore
    habit.skippedDays = Self.decodeSkippedDays(skippedDaysJSON, habitId: uuid)
    
    return habit
  }
  
  /// Query CompletionRecords from SwiftData to get source of truth
  @MainActor
  private func queryCompletionRecords(
    habitId: UUID,
    userId: String,
    firestoreHistory: [String: Int],
    firestoreStatus: [String: Bool]
  ) -> ([String: Int], [String: Bool]) {
    do {
      let context = SwiftDataContainer.shared.modelContext
      let predicate = #Predicate<CompletionRecord> { record in
        record.habitId == habitId && record.userId == userId
      }
      let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
      let records = try context.fetch(descriptor)
      
      if records.isEmpty {
        print("⚠️ FirestoreHabit.toHabit(): No CompletionRecords found for habit \(self.name), using Firestore data")
        return (firestoreHistory, firestoreStatus)
      }
      
      // Build dictionaries from CompletionRecords (SOURCE OF TRUTH)
      let historyDict = Dictionary(uniqueKeysWithValues: records.map {
        (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted ? 1 : 0)
      })
      let statusDict = Dictionary(uniqueKeysWithValues: records.map {
        (ISO8601DateHelper.shared.string(from: $0.date), $0.isCompleted)
      })
      
      print("✅ FirestoreHabit.toHabit(): Found \(records.count) CompletionRecords for habit '\(self.name)', using those as source of truth")
      return (historyDict, statusDict)
      
    } catch {
      print("❌ FirestoreHabit.toHabit(): Failed to query CompletionRecords: \(error), using Firestore data")
      return (firestoreHistory, firestoreStatus)
    }
  }
  
  static func from(id: String?, data: [String: Any]) -> FirestoreHabit? {
    guard let name = data["name"] as? String,
          let description = data["description"] as? String,
          let icon = data["icon"] as? String,
          let color = data["color"] as? String,
          let habitType = data["habitType"] as? String,
          let schedule = data["schedule"] as? String,
          let goal = data["goal"] as? String,
          let reminder = data["reminder"] as? String,
          let startDate = data["startDate"] as? Date,
          let createdAt = data["createdAt"] as? Date,
          let reminders = data["reminders"] as? [String],
          let baseline = data["baseline"] as? Int,
          let target = data["target"] as? Int,
          let completionHistory = data["completionHistory"] as? [String: Int],
          let completionStatus = data["completionStatus"] as? [String: Bool],
          let completionTimestamps = data["completionTimestamps"] as? [String: [Date]],
          let difficultyHistory = data["difficultyHistory"] as? [String: Int],
          let actualUsage = data["actualUsage"] as? [String: Int],
          let isActive = data["isActive"] as? Bool else {
      return nil
    }
    
    let endDate = data["endDate"] as? Date
    
    // Parse sync metadata with defaults for backward compatibility
    let lastSyncedAt = data["lastSyncedAt"] as? Date
    let syncStatus = data["syncStatus"] as? String ?? "pending"
    
    // Parse skip data with default for backward compatibility
    let skippedDaysJSON = data["skippedDaysJSON"] as? String ?? "{}"
    
    return FirestoreHabit(
      id: id,
      name: name,
      description: description,
      icon: icon,
      color: color,
      habitType: habitType,
      schedule: schedule,
      goal: goal,
      reminder: reminder,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      reminders: reminders,
      baseline: baseline,
      target: target,
      completionHistory: completionHistory,
      completionStatus: completionStatus,
      completionTimestamps: completionTimestamps,
      difficultyHistory: difficultyHistory,
      actualUsage: actualUsage,
      skippedDaysJSON: skippedDaysJSON,
      isActive: isActive,
      lastSyncedAt: lastSyncedAt,
      syncStatus: syncStatus
    )
  }
}

// MARK: - GoalVersion

/// Goal version document stored in /users/{uid}/goalVersions/{habitId}/{versionId}
struct GoalVersion: Codable {
  var habitId: String
  var versionId: String
  var effectiveLocalDate: String // "YYYY-MM-DD" in Europe/Amsterdam
  var goal: Int
  var createdAt: Date
  
  func toFirestoreData() -> [String: Any] {
    [
      "habitId": habitId,
      "effectiveLocalDate": effectiveLocalDate,
      "goal": goal,
      "createdAt": createdAt
    ]
  }
  
  static func from(id: String, data: [String: Any]) -> GoalVersion? {
    guard let habitId = data["habitId"] as? String,
          let effectiveLocalDate = data["effectiveLocalDate"] as? String,
          let goal = data["goal"] as? Int else {
      return nil
    }
    
    let createdAt: Date
    if let timestamp = data["createdAt"] as? Date {
      createdAt = timestamp
    } else {
      createdAt = Date()
    }
    
    return GoalVersion(
      habitId: habitId,
      versionId: id,
      effectiveLocalDate: effectiveLocalDate,
      goal: goal,
      createdAt: createdAt)
  }
}

// MARK: - Completion

/// Completion document stored in /users/{uid}/completions/{YYYY-MM-DD}/{habitId}
struct Completion: Codable {
  var habitId: String
  var localDate: String // "YYYY-MM-DD"
  var count: Int
  var updatedAt: Date
  
  func toFirestoreData() -> [String: Any] {
    [
      "count": count,
      "updatedAt": updatedAt
    ]
  }
  
  static func from(habitId: String, localDate: String, data: [String: Any]) -> Completion? {
    guard let count = data["count"] as? Int else {
      return nil
    }
    
    let updatedAt: Date
    if let timestamp = data["updatedAt"] as? Date {
      updatedAt = timestamp
    } else {
      updatedAt = Date()
    }
    
    return Completion(
      habitId: habitId,
      localDate: localDate,
      count: count,
      updatedAt: updatedAt)
  }
}

// MARK: - XPState

/// XP state document stored in /users/{uid}/xp/state
struct XPState: Codable {
  var totalXP: Int
  var level: Int
  var currentLevelXP: Int
  var lastUpdated: Date
  
  func toFirestoreData() -> [String: Any] {
    [
      "totalXP": totalXP,
      "level": level,
      "currentLevelXP": currentLevelXP,
      "lastUpdated": lastUpdated
    ]
  }
  
  static func from(data: [String: Any]) -> XPState? {
    guard let totalXP = data["totalXP"] as? Int,
          let level = data["level"] as? Int,
          let currentLevelXP = data["currentLevelXP"] as? Int else {
      return nil
    }
    
    let lastUpdated: Date
    if let timestamp = data["lastUpdated"] as? Date {
      lastUpdated = timestamp
    } else {
      lastUpdated = Date()
    }
    
    return XPState(
      totalXP: totalXP,
      level: level,
      currentLevelXP: currentLevelXP,
      lastUpdated: lastUpdated)
  }
}

// MARK: - XPLedgerEntry

/// XP ledger entry stored in /users/{uid}/xp/ledger/{eventId}
struct XPLedgerEntry: Codable {
  var eventId: String
  var delta: Int
  var reason: String
  var timestamp: Date
  
  func toFirestoreData() -> [String: Any] {
    [
      "delta": delta,
      "reason": reason,
      "ts": timestamp
    ]
  }
  
  static func from(id: String, data: [String: Any]) -> XPLedgerEntry? {
    guard let delta = data["delta"] as? Int,
          let reason = data["reason"] as? String else {
      return nil
    }
    
    let timestamp: Date
    if let ts = data["ts"] as? Date {
      timestamp = ts
    } else {
      timestamp = Date()
    }
    
    return XPLedgerEntry(
      eventId: id,
      delta: delta,
      reason: reason,
      timestamp: timestamp)
  }
}

// MARK: - Streak

/// Streak document stored in /users/{uid}/streaks/{habitId}
struct Streak: Codable {
  var habitId: String
  var current: Int
  var longest: Int
  var lastCompletionDate: String? // "YYYY-MM-DD" or nil
  var updatedAt: Date
  
  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "current": current,
      "longest": longest,
      "updatedAt": updatedAt
    ]
    
    if let lastCompletionDate = lastCompletionDate {
      data["lastCompletionDate"] = lastCompletionDate
    }
    
    return data
  }
  
  static func from(habitId: String, data: [String: Any]) -> Streak? {
    guard let current = data["current"] as? Int,
          let longest = data["longest"] as? Int else {
      return nil
    }
    
    let lastCompletionDate = data["lastCompletionDate"] as? String
    
    let updatedAt: Date
    if let timestamp = data["updatedAt"] as? Date {
      updatedAt = timestamp
    } else {
      updatedAt = Date()
    }
    
    return Streak(
      habitId: habitId,
      current: current,
      longest: longest,
      lastCompletionDate: lastCompletionDate,
      updatedAt: updatedAt)
  }
}

// MARK: - FirestoreDailyAward

/// Daily award document stored in /users/{uid}/daily_awards/{userIdDateKey}
struct FirestoreDailyAward: Codable {
  var date: String // "YYYY-MM-DD"
  var xpGranted: Int
  var allHabitsCompleted: Bool
  var grantedAt: Date
  var habitCount: Int? // Number of habits completed
  var bonusXP: Int? // Bonus XP for perfect day
  
  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "date": date,
      "xpGranted": xpGranted,
      "allHabitsCompleted": allHabitsCompleted,
      "grantedAt": grantedAt
    ]
    
    if let habitCount = habitCount {
      data["habitCount"] = habitCount
    }
    
    if let bonusXP = bonusXP {
      data["bonusXP"] = bonusXP
    }
    
    return data
  }
  
  static func from(data: [String: Any]) -> FirestoreDailyAward? {
    guard let date = data["date"] as? String,
          let xpGranted = data["xpGranted"] as? Int,
          let allHabitsCompleted = data["allHabitsCompleted"] as? Bool else {
      return nil
    }
    
    let grantedAt: Date
    if let timestamp = data["grantedAt"] as? Date {
      grantedAt = timestamp
    } else {
      grantedAt = Date()
    }
    
    let habitCount = data["habitCount"] as? Int
    let bonusXP = data["bonusXP"] as? Int
    
    return FirestoreDailyAward(
      date: date,
      xpGranted: xpGranted,
      allHabitsCompleted: allHabitsCompleted,
      grantedAt: grantedAt,
      habitCount: habitCount,
      bonusXP: bonusXP
    )
  }
  
  /// Initialize from SwiftData DailyAward entity
  init(from dailyAward: DailyAward) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    
    self.date = dateFormatter.string(from: dailyAward.date)
    self.xpGranted = dailyAward.xp
    self.allHabitsCompleted = dailyAward.allHabitsCompleted
    self.grantedAt = dailyAward.date
    self.habitCount = nil // Not stored in current DailyAward
    self.bonusXP = dailyAward.allHabitsCompleted ? 50 : nil // Bonus XP for perfect day
  }
  
  init(
    date: String,
    xpGranted: Int,
    allHabitsCompleted: Bool,
    grantedAt: Date,
    habitCount: Int? = nil,
    bonusXP: Int? = nil
  ) {
    self.date = date
    self.xpGranted = xpGranted
    self.allHabitsCompleted = allHabitsCompleted
    self.grantedAt = grantedAt
    self.habitCount = habitCount
    self.bonusXP = bonusXP
  }
}

// MARK: - FirestoreUserProgress

/// User progress document stored in /users/{uid}/xp/state
struct FirestoreUserProgress: Codable {
  var totalXP: Int
  var level: Int
  var dailyXP: Int // XP earned today
  var lastUpdated: Date
  var currentLevelXP: Int? // XP in current level
  var nextLevelXP: Int? // XP needed for next level
  
  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "totalXP": totalXP,
      "level": level,
      "dailyXP": dailyXP,
      "lastUpdated": lastUpdated
    ]
    
    if let currentLevelXP = currentLevelXP {
      data["currentLevelXP"] = currentLevelXP
    }
    
    if let nextLevelXP = nextLevelXP {
      data["nextLevelXP"] = nextLevelXP
    }
    
    return data
  }
  
  static func from(data: [String: Any]) -> FirestoreUserProgress? {
    guard let totalXP = data["totalXP"] as? Int,
          let level = data["level"] as? Int else {
      return nil
    }
    
    let dailyXP = data["dailyXP"] as? Int ?? 0
    
    let lastUpdated: Date
    if let timestamp = data["lastUpdated"] as? Date {
      lastUpdated = timestamp
    } else {
      lastUpdated = Date()
    }
    
    let currentLevelXP = data["currentLevelXP"] as? Int
    let nextLevelXP = data["nextLevelXP"] as? Int
    
    return FirestoreUserProgress(
      totalXP: totalXP,
      level: level,
      dailyXP: dailyXP,
      lastUpdated: lastUpdated,
      currentLevelXP: currentLevelXP,
      nextLevelXP: nextLevelXP
    )
  }
  
  init(
    totalXP: Int,
    level: Int,
    dailyXP: Int,
    lastUpdated: Date,
    currentLevelXP: Int? = nil,
    nextLevelXP: Int? = nil
  ) {
    self.totalXP = totalXP
    self.level = level
    self.dailyXP = dailyXP
    self.lastUpdated = lastUpdated
    self.currentLevelXP = currentLevelXP
    self.nextLevelXP = nextLevelXP
  }
}

