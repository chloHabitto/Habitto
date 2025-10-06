import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Sync Status
enum CloudKitSyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case error(Error)
    case conflict
    
    static func == (lhs: CloudKitSyncStatus, rhs: CloudKitSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed), (.conflict, .conflict):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - CloudKit Sync Protocol
/// Protocol for objects that can be synced with CloudKit
protocol CloudKitSyncable {
    var cloudKitRecordID: CKRecord.ID? { get }
    var cloudKitRecordType: String { get }
    var lastModified: Date { get }
    var isDeleted: Bool { get }
    
    func toCloudKitRecord() -> CKRecord
    static func fromCloudKitRecord(_ record: CKRecord) -> Self?
    func updateFromCloudKitRecord(_ record: CKRecord)
}


// MARK: - CloudKit Sync Metadata
struct CloudKitSyncMetadata {
    let recordID: CKRecord.ID
    let lastModified: Date
    let syncStatus: String // Using String instead of CloudKitSyncStatus to avoid conflicts
    let version: Int
    let conflictResolution: ConflictResolution?
    
    enum ConflictResolution {
        case useLocal
        case useRemote
        case merge
    }
}

// MARK: - CloudKit Habit Record
/// CloudKit-compatible Habit model for sync
struct CloudKitHabit: CloudKitSyncable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let colorHex: String // Store color as hex string for CloudKit compatibility
    let habitType: String
    let schedule: String
    let goal: String
    let reminder: String
    let startDate: Date
    let endDate: Date?
    var isCompleted: Bool
    var streak: Int
    let createdAt: Date
    var completionHistory: [String: Int] // Date key -> progress count
    var difficultyHistory: [String: Int] // Date key -> difficulty (1-10)
    var baseline: Int
    var target: Int
    var actualUsage: [String: Int] // Date key -> actual usage amount
    
    // CloudKit sync properties
    var cloudKitRecordID: CKRecord.ID?
    var lastModified: Date
    var isDeleted: Bool
    
    // MARK: - CloudKitSyncable Implementation
    var cloudKitRecordType: String { "Habit" }
    
    func toCloudKitRecord() -> CKRecord {
        let record = cloudKitRecordID.map { CKRecord(recordType: cloudKitRecordType, recordID: $0) } 
                                   ?? CKRecord(recordType: cloudKitRecordType)
        
        record["id"] = id.uuidString
        record["name"] = name
        record["description"] = description
        record["icon"] = icon
        record["colorHex"] = colorHex
        record["habitType"] = habitType
        record["schedule"] = schedule
        record["goal"] = goal
        record["reminder"] = reminder
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["isCompleted"] = isCompleted
        record["streak"] = streak
        record["createdAt"] = createdAt
        record["baseline"] = baseline
        record["target"] = target
        record["lastModified"] = lastModified
        record["isDeleted"] = isDeleted
        
        // Store dictionaries as JSON strings for CloudKit compatibility
        if let completionData = try? JSONEncoder().encode(completionHistory),
           let completionString = String(data: completionData, encoding: .utf8) {
            record["completionHistory"] = completionString
        }
        
        if let difficultyData = try? JSONEncoder().encode(difficultyHistory),
           let difficultyString = String(data: difficultyData, encoding: .utf8) {
            record["difficultyHistory"] = difficultyString
        }
        
        if let usageData = try? JSONEncoder().encode(actualUsage),
           let usageString = String(data: usageData, encoding: .utf8) {
            record["actualUsage"] = usageString
        }
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> CloudKitHabit? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let description = record["description"] as? String,
              let icon = record["icon"] as? String,
              let colorHex = record["colorHex"] as? String,
              let habitType = record["habitType"] as? String,
              let schedule = record["schedule"] as? String,
              let goal = record["goal"] as? String,
              let reminder = record["reminder"] as? String,
              let startDate = record["startDate"] as? Date,
              let isCompleted = record["isCompleted"] as? Bool,
              let streak = record["streak"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let baseline = record["baseline"] as? Int,
              let target = record["target"] as? Int,
              let lastModified = record["lastModified"] as? Date,
              let isDeleted = record["isDeleted"] as? Bool else {
            return nil
        }
        
        let endDate = record["endDate"] as? Date
        
        // Parse JSON strings back to dictionaries
        var completionHistory: [String: Int] = [:]
        if let completionString = record["completionHistory"] as? String,
           let completionData = completionString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: completionData) {
            completionHistory = decoded
        }
        
        var difficultyHistory: [String: Int] = [:]
        if let difficultyString = record["difficultyHistory"] as? String,
           let difficultyData = difficultyString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: difficultyData) {
            difficultyHistory = decoded
        }
        
        var actualUsage: [String: Int] = [:]
        if let usageString = record["actualUsage"] as? String,
           let usageData = usageString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: usageData) {
            actualUsage = decoded
        }
        
        return CloudKitHabit(
            id: id,
            name: name,
            description: description,
            icon: icon,
            colorHex: colorHex,
            habitType: habitType,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            isCompleted: isCompleted,
            streak: streak,
            createdAt: createdAt,
            completionHistory: completionHistory,
            difficultyHistory: difficultyHistory,
            baseline: baseline,
            target: target,
            actualUsage: actualUsage,
            cloudKitRecordID: record.recordID,
            lastModified: lastModified,
            isDeleted: isDeleted
        )
    }
    
    func updateFromCloudKitRecord(_ record: CKRecord) {
        // This would be used for updating existing records
        // Implementation would update the current instance with data from CloudKit record
    }
}

// MARK: - CloudKit Reminder Record
/// CloudKit-compatible Reminder model for sync
struct CloudKitReminder: CloudKitSyncable, Identifiable {
    let id: UUID
    let habitId: UUID
    let title: String
    let time: Date
    let isEnabled: Bool
    let repeatDays: [Int] // Days of week (1-7, where 1 is Sunday)
    
    // CloudKit sync properties
    var cloudKitRecordID: CKRecord.ID?
    var lastModified: Date
    var isDeleted: Bool
    
    // MARK: - CloudKitSyncable Implementation
    var cloudKitRecordType: String { "Reminder" }
    
    func toCloudKitRecord() -> CKRecord {
        let record = cloudKitRecordID.map { CKRecord(recordType: cloudKitRecordType, recordID: $0) } 
                                   ?? CKRecord(recordType: cloudKitRecordType)
        
        record["id"] = id.uuidString
        record["habitId"] = habitId.uuidString
        record["title"] = title
        record["time"] = time
        record["isEnabled"] = isEnabled
        record["lastModified"] = lastModified
        record["isDeleted"] = isDeleted
        
        // Store array as JSON string for CloudKit compatibility
        if let repeatData = try? JSONEncoder().encode(repeatDays),
           let repeatString = String(data: repeatData, encoding: .utf8) {
            record["repeatDays"] = repeatString
        }
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> CloudKitReminder? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let habitIdString = record["habitId"] as? String,
              let habitId = UUID(uuidString: habitIdString),
              let title = record["title"] as? String,
              let time = record["time"] as? Date,
              let isEnabled = record["isEnabled"] as? Bool,
              let lastModified = record["lastModified"] as? Date,
              let isDeleted = record["isDeleted"] as? Bool else {
            return nil
        }
        
        var repeatDays: [Int] = []
        if let repeatString = record["repeatDays"] as? String,
           let repeatData = repeatString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Int].self, from: repeatData) {
            repeatDays = decoded
        }
        
        return CloudKitReminder(
            id: id,
            habitId: habitId,
            title: title,
            time: time,
            isEnabled: isEnabled,
            repeatDays: repeatDays,
            cloudKitRecordID: record.recordID,
            lastModified: lastModified,
            isDeleted: isDeleted
        )
    }
    
    func updateFromCloudKitRecord(_ record: CKRecord) {
        // Implementation for updating existing records
    }
}

// MARK: - CloudKit Analytics Record
/// CloudKit-compatible Analytics model for sync
struct CloudKitAnalytics: CloudKitSyncable, Identifiable {
    let id: UUID
    let userId: String
    let eventType: String
    let eventData: [String: String]
    let timestamp: Date
    let sessionId: String?
    
    // CloudKit sync properties
    var cloudKitRecordID: CKRecord.ID?
    var lastModified: Date
    var isDeleted: Bool
    
    // MARK: - CloudKitSyncable Implementation
    var cloudKitRecordType: String { "Analytics" }
    
    func toCloudKitRecord() -> CKRecord {
        let record = cloudKitRecordID.map { CKRecord(recordType: cloudKitRecordType, recordID: $0) } 
                                   ?? CKRecord(recordType: cloudKitRecordType)
        
        record["id"] = id.uuidString
        record["userId"] = userId
        record["eventType"] = eventType
        record["timestamp"] = timestamp
        record["sessionId"] = sessionId
        record["lastModified"] = lastModified
        record["isDeleted"] = isDeleted
        
        // Store dictionary as JSON string for CloudKit compatibility
        if let eventData = try? JSONEncoder().encode(eventData),
           let eventString = String(data: eventData, encoding: .utf8) {
            record["eventData"] = eventString
        }
        
        return record
    }
    
    static func fromCloudKitRecord(_ record: CKRecord) -> CloudKitAnalytics? {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = record["userId"] as? String,
              let eventType = record["eventType"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let lastModified = record["lastModified"] as? Date,
              let isDeleted = record["isDeleted"] as? Bool else {
            return nil
        }
        
        var eventData: [String: String] = [:]
        if let eventString = record["eventData"] as? String,
           let eventDataBytes = eventString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: eventDataBytes) {
            eventData = decoded
        }
        
        let sessionId = record["sessionId"] as? String
        
        return CloudKitAnalytics(
            id: id,
            userId: userId,
            eventType: eventType,
            eventData: eventData,
            timestamp: timestamp,
            sessionId: sessionId,
            cloudKitRecordID: record.recordID,
            lastModified: lastModified,
            isDeleted: isDeleted
        )
    }
    
    func updateFromCloudKitRecord(_ record: CKRecord) {
        // Implementation for updating existing records
    }
}

// MARK: - Conversion Extensions
extension Habit {
    /// Convert Habit to CloudKitHabit for sync
    func toCloudKitHabit() -> CloudKitHabit {
        return CloudKitHabit(
            id: id,
            name: name,
            description: description,
            icon: icon,
            colorHex: color.color.toHex(),
            habitType: habitType.rawValue,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            isCompleted: isCompletedForDate(Date()),
            streak: computedStreak(),
            createdAt: createdAt,
            completionHistory: completionHistory,
            difficultyHistory: difficultyHistory,
            baseline: baseline,
            target: target,
            actualUsage: actualUsage,
            cloudKitRecordID: nil, // Will be set during sync
            lastModified: Date(),
            isDeleted: false
        )
    }
}

extension CloudKitHabit {
    /// Convert CloudKitHabit back to Habit for local use
    func toHabit() -> Habit {
        return Habit(
            id: id,
            name: name,
            description: description,
            icon: icon,
            color: CodableColor(Color.fromHex(colorHex)),
            habitType: HabitType(rawValue: habitType) ?? .formation,
            schedule: schedule,
            goal: goal,
            reminder: reminder,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            reminders: [], // Would need separate sync for reminders
            baseline: baseline,
            target: target,
            completionHistory: completionHistory,
            difficultyHistory: difficultyHistory,
            actualUsage: actualUsage
        )
    }
}

// MARK: - Color Extensions for CloudKit
// Note: Using Color extensions from Utils/Design/ColorSystem.swift to avoid conflicts
