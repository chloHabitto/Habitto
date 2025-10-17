//
//  FirestoreModels.swift
//  Habitto
//
//  Firestore data models matching the schema specification
//

import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - FirestoreHabit

/// Habit document stored in /users/{uid}/habits/{habitId}
struct FirestoreHabit: Codable, Identifiable {
  var id: String
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
  var isActive: Bool
  
  // MARK: Initializers
  
  init(
    id: String,
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
    isActive: Bool
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
    self.isActive = isActive
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
      "isActive": isActive
    ]
    
    if let endDate = endDate {
      data["endDate"] = endDate
    }
    
    return data
  }
  
  init(from habit: Habit) {
    self.id = habit.id.uuidString
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
    self.isActive = true
  }
  
  func toHabit() -> Habit? {
    guard let uuid = UUID(uuidString: id),
          let habitType = HabitType(rawValue: self.habitType) else {
      return nil
    }
    
    let color = Color(hex: self.color)
    
    let reminderItems = reminders.compactMap { reminderId in
      ReminderItem(id: UUID(uuidString: reminderId) ?? UUID(), time: Date(), isActive: true)
    }
    
    return Habit(
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
      completionHistory: completionHistory,
      completionStatus: completionStatus,
      completionTimestamps: completionTimestamps,
      difficultyHistory: difficultyHistory,
      actualUsage: actualUsage
    )
  }
  
  static func from(id: String, data: [String: Any]) -> FirestoreHabit? {
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
      isActive: isActive
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

