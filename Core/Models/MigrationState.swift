import Foundation
import SwiftData

// MARK: - Migration State Model
/// Tracks migration status for each user to ensure idempotent migrations
@Model
final class MigrationState {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var userId: String
    var migrationVersion: Int
    var status: MigrationStatus
    var startedAt: Date
    var completedAt: Date?
    var errorMessage: String?
    var migratedRecordsCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        userId: String,
        migrationVersion: Int,
        status: MigrationStatus = .pending
    ) {
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
}

// MARK: - Migration Status Enum
enum MigrationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case rolledBack = "rolled_back"
}

// MARK: - Migration Version Constants
struct MigrationVersions {
    /// Initial migration from legacy storage to normalized SwiftData
    static let initialNormalization = 1
    
    /// Current migration version
    static let current = initialNormalization
    
    /// Check if migration is needed
    static func isMigrationNeeded(currentVersion: Int?) -> Bool {
        return currentVersion == nil || currentVersion! < current
    }
}

// MARK: - Migration State Extensions
extension MigrationState {
    /// Check if migration is completed
    var isCompleted: Bool {
        return status == .completed
    }
    
    /// Check if migration is in progress
    var isInProgress: Bool {
        return status == .inProgress
    }
    
    /// Check if migration failed
    var hasFailed: Bool {
        return status == .failed
    }
    
    /// Check if migration can be rolled back
    var canRollback: Bool {
        return status == .completed || status == .failed
    }
    
    /// Mark migration as completed
    mutating func markCompleted(recordsCount: Int) {
        self.status = .completed
        self.completedAt = Date()
        self.migratedRecordsCount = recordsCount
        self.updatedAt = Date()
    }
    
    /// Mark migration as failed
    mutating func markFailed(error: Error) {
        self.status = .failed
        self.errorMessage = error.localizedDescription
        self.updatedAt = Date()
    }
    
    /// Mark migration as in progress
    mutating func markInProgress() {
        self.status = .inProgress
        self.updatedAt = Date()
    }
    
    /// Mark migration as rolled back
    mutating func markRolledBack() {
        self.status = .rolledBack
        self.updatedAt = Date()
    }
}

// MARK: - Migration State Queries
extension MigrationState {
    /// Find migration state for a specific user
    static func findForUser(userId: String, in context: ModelContext) throws -> MigrationState? {
        let request = FetchDescriptor<MigrationState>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        let results = try context.fetch(request)
        return results.first
    }
    
    /// Find or create migration state for a specific user
    static func findOrCreateForUser(userId: String, in context: ModelContext) throws -> MigrationState {
        if let existing = try findForUser(userId: userId, in: context) {
            return existing
        }
        
        let newState = MigrationState(
            userId: userId,
            migrationVersion: MigrationVersions.current
        )
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
