//
//  FirestoreModels.swift
//  Habitto
//
//  Firestore data models matching the schema specification
//

import Foundation
import FirebaseFirestore

// MARK: - FirestoreHabit

/// Habit document stored in /users/{uid}/habits/{habitId}
struct FirestoreHabit: Codable, Identifiable {
  var id: String
  var name: String
  var color: String
  var type: String // "formation", "breaking", etc.
  var createdAt: Date
  var active: Bool
  
  // MARK: Firestore conversion
  
  func toFirestoreData() -> [String: Any] {
    [
      "name": name,
      "color": color,
      "type": type,
      "createdAt": createdAt, // Will be converted to Timestamp by Firestore
      "active": active
    ]
  }
  
  static func from(id: String, data: [String: Any]) -> FirestoreHabit? {
    guard let name = data["name"] as? String,
          let color = data["color"] as? String,
          let type = data["type"] as? String,
          let active = data["active"] as? Bool else {
      return nil
    }
    
    // Handle Timestamp or Date
    let createdAt: Date
    if let timestamp = data["createdAt"] as? Date {
      createdAt = timestamp
    } else {
      createdAt = Date()
    }
    
    return FirestoreHabit(
      id: id,
      name: name,
      color: color,
      type: type,
      createdAt: createdAt,
      active: active)
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

