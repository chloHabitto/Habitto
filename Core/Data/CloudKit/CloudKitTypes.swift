import Foundation
import CloudKit

// MARK: - CloudKit Sync Status
// Using existing CloudKitSyncStatus from CloudKitModels.swift

// MARK: - CloudKit Change
struct CloudKitChange {
    let record: CKRecord
    let changeType: ChangeType
}

// MARK: - Local Change
struct LocalChange {
    let recordID: CKRecord.ID
    let habit: Habit
    let changeType: ChangeType
}

// MARK: - Change Type
enum ChangeType {
    case created
    case modified
    case deleted
}

// MARK: - Conflict Resolution Result
struct ConflictResolutionResult {
    let recordID: CKRecord.ID
    let localHabit: Habit
    let remoteHabit: Habit
    let resolvedHabit: Habit
    let resolutionMethod: String
}

// MARK: - Sync Result
struct SyncResult {
    var success: Bool = false
    var duration: TimeInterval = 0
    var remoteChangesCount: Int = 0
    var localChangesCount: Int = 0
    var conflictsResolved: Int = 0
    var uploadedCount: Int = 0
    var downloadedCount: Int = 0
    var uploadErrors: [Error] = []
    var downloadErrors: [Error] = []
    var error: Error?
}

// MARK: - CloudKit Error
// Using existing CloudKitError from CloudKitManager.swift
