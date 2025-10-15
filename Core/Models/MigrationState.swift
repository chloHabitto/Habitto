import Foundation
import SwiftData
import SwiftUI

// MARK: - MigrationState

/// Tracks migration status for each user to ensure idempotent migrations
@Model
final class MigrationState {
  // MARK: Lifecycle

  init(
    userId: String,
    migrationVersion: Int,
    status: MigrationStatus = .pending)
  {
    self.id = UUID()
    self.userId = userId
    self.migrationVersion = migrationVersion
    self.status = status
    self.startedAt = Date()
    self.completedAt = nil
    self.errorMessage = nil
    self.migratedRecordsCount = 0
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  // MARK: Internal

  @Attribute(.unique) var id: UUID
  var userId: String
  var migrationVersion: Int
  var status: MigrationStatus
  var startedAt: Date
  var completedAt: Date?
  var errorMessage: String?
  var migratedRecordsCount: Int
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - MigrationStatus

enum MigrationStatus: String, Codable, CaseIterable {
  case pending
  case inProgress = "in_progress"
  case completed
  case failed
  case rolledBack = "rolled_back"

  // MARK: Internal

  var color: Color {
    switch self {
    case .pending:
      .orange
    case .inProgress:
      .blue
    case .completed:
      .green
    case .failed:
      .red
    case .rolledBack:
      .gray
    }
  }

  var displayName: String {
    switch self {
    case .pending:
      "Pending"
    case .inProgress:
      "In Progress"
    case .completed:
      "Completed"
    case .failed:
      "Failed"
    case .rolledBack:
      "Rolled Back"
    }
  }
}

// MARK: - MigrationVersions

enum MigrationVersions {
  /// Initial migration from legacy storage to normalized SwiftData
  static let initialNormalization = 1
  
  /// Firebase migration from local storage to Firestore
  static let firebaseMigration = 2

  /// Current migration version
  static let current = firebaseMigration

  /// Check if migration is needed
  static func isMigrationNeeded(currentVersion: Int?) -> Bool {
    currentVersion == nil || currentVersion! < current
  }
}

// MARK: - FirebaseMigrationState

/// Represents the state of a Firebase data migration job, stored in Firestore.
struct FirebaseMigrationState: Codable, Equatable {
  // MARK: Lifecycle

  init(
    status: Status = .notStarted,
    lastKey: String? = nil,
    startedAt: Date? = nil,
    finishedAt: Date? = nil,
    error: String? = nil)
  {
    self.status = status
    self.lastKey = lastKey
    self.startedAt = startedAt
    self.finishedAt = finishedAt
    self.error = error
  }

  // MARK: Internal

  enum Status: String, Codable, Equatable {
    case notStarted = "not_started"
    case running
    case complete
    case failed
  }

  var status: Status
  var lastKey: String?
  var startedAt: Date?
  var finishedAt: Date?
  var error: String?
}

// MARK: - Migration State Extensions

extension MigrationState {
  /// Check if migration is completed
  var isCompleted: Bool {
    status == .completed
  }

  /// Check if migration is in progress
  var isInProgress: Bool {
    status == .inProgress
  }

  /// Check if migration failed
  var hasFailed: Bool {
    status == .failed
  }

  /// Check if migration can be rolled back
  var canRollback: Bool {
    status == .completed || status == .failed
  }

  /// Mark migration as completed
  func markCompleted(recordsCount: Int) {
    status = .completed
    completedAt = Date()
    migratedRecordsCount = recordsCount
    updatedAt = Date()
  }

  /// Mark migration as failed
  func markFailed(error: Error) {
    status = .failed
    errorMessage = error.localizedDescription
    updatedAt = Date()
  }

  /// Mark migration as in progress
  func markInProgress() {
    status = .inProgress
    updatedAt = Date()
  }

  /// Mark migration as rolled back
  func markRolledBack() {
    status = .rolledBack
    updatedAt = Date()
  }
}

// MARK: - Migration State Queries

extension MigrationState {
  /// Find migration state for a specific user
  static func findForUser(userId: String, in context: ModelContext) throws -> MigrationState? {
    let request = FetchDescriptor<MigrationState>(
      predicate: #Predicate { $0.userId == userId })

    let results = try context.fetch(request)
    return results.first
  }

  /// Find or create migration state for a specific user
  static func findOrCreateForUser(
    userId: String,
    in context: ModelContext) throws -> MigrationState
  {
    if let existing = try findForUser(userId: userId, in: context) {
      return existing
    }

    let newState = MigrationState(
      userId: userId,
      migrationVersion: MigrationVersions.current)
    context.insert(newState)
    try context.save()
    return newState
  }

  /// Check if user has completed migration
  static func hasCompletedMigration(userId: String, in context: ModelContext) throws -> Bool {
    guard let state = try findForUser(userId: userId, in: context) else {
      return false
    }
    return state.isCompleted
  }

  /// Get all migration states (for debugging)
  static func getAll(in context: ModelContext) throws -> [MigrationState] {
    let request = FetchDescriptor<MigrationState>()
    return try context.fetch(request)
  }
}
