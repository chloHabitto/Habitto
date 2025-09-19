import Foundation
import CloudKit
import OSLog
import SwiftUI

// MARK: - CloudKit Sync Manager
final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "CloudKitSyncManager")
    private let conflictResolver = ConflictResolutionManager.shared
    private var _container: CKContainer?
    
    @Published var syncStatus: CloudKitSyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private init() {
        logger.info("CloudKitSyncManager initialized (CloudKit disabled for now)")
    }
    
    /// Lazy initialization of CloudKit container
    private var container: CKContainer? {
        // CloudKit is disabled for now to prevent crashes
        return nil
    }
    
    func performFullSync() async throws -> SyncResult {
        logger.info("Starting full CloudKit sync")
        
        // Check if CloudKit is available
        guard let container = container else {
            let error = CloudKitError.notConfigured
            syncStatus = .error(error)
            syncError = error
            logger.error("CloudKit not available for sync")
            throw error
        }
        
        syncStatus = .syncing
        syncError = nil
        
        let startTime = Date()
        var result = SyncResult()
        
        do {
            try await checkCloudKitAvailability()
            
            let remoteChanges = try await fetchRemoteChanges()
            result.remoteChangesCount = remoteChanges.count
            
            let localChanges = try await fetchLocalChanges()
            result.localChangesCount = localChanges.count
            
            let conflicts = try await resolveConflicts(remoteChanges: remoteChanges, localChanges: localChanges)
            result.conflictsResolved = conflicts.count
            
            syncStatus = .completed
            lastSyncDate = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            result.duration = duration
            result.success = true
            
            logger.info("Full sync completed in \(String(format: "%.2f", duration))s")
            
        } catch {
            syncStatus = .error(error)
            syncError = error
            result.success = false
            result.error = error
            
            logger.error("Full sync failed: \(error.localizedDescription)")
            throw error
        }
        
        return result
    }
    
    /// Performs a sync (alias for performFullSync)
    func sync() async throws -> SyncResult {
        return try await performFullSync()
    }
    
    /// Starts automatic syncing
    func startAutoSync() {
        logger.info("Starting automatic CloudKit sync")
        // TODO: Implement automatic sync scheduling
    }
    
    /// Stops automatic syncing
    func stopAutoSync() {
        logger.info("Stopping automatic CloudKit sync")
        // TODO: Implement automatic sync cancellation
    }
    
    /// Checks if CloudKit is available
    func isCloudKitAvailable() -> Bool {
        // CloudKit is disabled for now to prevent crashes
        return false
    }
    
    private func checkCloudKitAvailability() async throws {
        guard let container = container else {
            throw CloudKitError.notConfigured
        }
        
        let status = try await container.accountStatus()
        
        switch status {
        case .available:
            logger.debug("CloudKit is available")
        case .noAccount:
            throw CloudKitError.authenticationFailed
        case .restricted:
            throw CloudKitError.authenticationFailed
        case .couldNotDetermine:
            throw CloudKitError.authenticationFailed
        case .temporarilyUnavailable:
            throw CloudKitError.networkError(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "CloudKit temporarily unavailable"]))
        @unknown default:
            throw CloudKitError.authenticationFailed
        }
    }
    
    private func fetchRemoteChanges(since date: Date = Date.distantPast) async throws -> [CloudKitChange] {
        logger.debug("Fetching remote changes since \(date)")
        
        guard let container = container else {
            throw CloudKitError.notConfigured
        }
        
        let database = container.privateCloudDatabase
        let query = CKQuery(recordType: "Habit", predicate: NSPredicate(format: "modificationDate > %@", date as NSDate))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: true)]
        
        let (records, _) = try await database.records(matching: query)
        
        let changes = records.compactMap { (_, result) -> CloudKitChange? in
            switch result {
            case .success(let record):
                return CloudKitChange(record: record, changeType: .modified)
            case .failure(let error):
                logger.error("Failed to fetch record: \(error.localizedDescription)")
                return nil
            }
        }
        
        logger.debug("Fetched \(changes.count) remote changes")
        return changes
    }
    
    private func fetchLocalChanges(since date: Date = Date.distantPast) async throws -> [LocalChange] {
        logger.debug("Fetching local changes since \(date)")
        let changes: [LocalChange] = []
        logger.debug("Fetched \(changes.count) local changes")
        return changes
    }
    
    private func resolveConflicts(remoteChanges: [CloudKitChange], localChanges: [LocalChange]) async throws -> [ConflictResolutionResult] {
        logger.debug("Resolving conflicts between \(remoteChanges.count) remote and \(localChanges.count) local changes")
        
        var resolutions: [ConflictResolutionResult] = []
        
        for remoteChange in remoteChanges {
            if let localChange = localChanges.first(where: { $0.recordID == remoteChange.record.recordID }) {
                let resolution = try await resolveConflict(remoteChange: remoteChange, localChange: localChange)
                resolutions.append(resolution)
            }
        }
        
        logger.debug("Resolved \(resolutions.count) conflicts")
        return resolutions
    }
    
    private func resolveConflict(remoteChange: CloudKitChange, localChange: LocalChange) async throws -> ConflictResolutionResult {
        logger.debug("Resolving conflict for record: \(remoteChange.record.recordID)")
        
        let remoteHabit = try habitFromCloudKitRecord(remoteChange.record)
        let localHabit = localChange.habit
        let resolvedHabit = conflictResolver.resolveHabitConflict(localHabit, remoteHabit)
        
        let resolution = ConflictResolutionResult(
            recordID: remoteChange.record.recordID,
            localHabit: localHabit,
            remoteHabit: remoteHabit,
            resolvedHabit: resolvedHabit,
            resolutionMethod: "field_level_last_writer_wins"
        )
        
        logger.debug("Conflict resolved for record: \(remoteChange.record.recordID)")
        return resolution
    }
    
    private func habitFromCloudKitRecord(_ record: CKRecord) throws -> Habit {
        guard let name = record["name"] as? String,
              let description = record["description"] as? String,
              let icon = record["icon"] as? String,
              let colorString = record["color"] as? String,
              let habitTypeString = record["habitType"] as? String,
              let habitType = HabitType(rawValue: habitTypeString),
              let schedule = record["schedule"] as? String,
              let goal = record["goal"] as? String,
              let reminder = record["reminder"] as? String,
              let startDate = record["startDate"] as? Date,
              let isCompleted = record["isCompleted"] as? Bool,
              let streak = record["streak"] as? Int,
              let createdAt = record["createdAt"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        let endDate = record["endDate"] as? Date
        let color = Color.fromHex(colorString) ?? Color.blue
        
        return Habit(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
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
            isCompleted: isCompleted,
            streak: streak,
            createdAt: createdAt,
            reminders: [],
            baseline: 0,
            target: 1,
            completionHistory: [:],
            difficultyHistory: [:],
            actualUsage: [:]
        )
    }
}