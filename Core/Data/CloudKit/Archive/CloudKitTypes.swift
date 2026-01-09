import CloudKit
import Foundation

// MARK: - CloudKitChange

// Using existing CloudKitSyncStatus from CloudKitModels.swift

struct CloudKitChange {
  let record: CKRecord
  let changeType: ChangeType
}

// MARK: - LocalChange

struct LocalChange {
  let recordID: CKRecord.ID
  let habit: Habit
  let changeType: ChangeType
}

// MARK: - ChangeType

enum ChangeType {
  case created
  case modified
  case deleted
}

// MARK: - ConflictResolutionResult

struct ConflictResolutionResult {
  let recordID: CKRecord.ID
  let localHabit: Habit
  let remoteHabit: Habit
  let resolvedHabit: Habit
  let resolutionMethod: String
}

// MARK: - SyncResult

struct SyncResult {
  var success = false
  var duration: TimeInterval = 0
  var remoteChangesCount = 0
  var localChangesCount = 0
  var conflictsResolved = 0
  var uploadedCount = 0
  var downloadedCount = 0
  var uploadErrors: [Error] = []
  var downloadErrors: [Error] = []
  var error: Error?
}

// MARK: - CloudKit Error

// Using existing CloudKitError from CloudKitManager.swift
