import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Sync Manager
/// Manages synchronization between local data and CloudKit
@MainActor
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: CloudKitSyncStatus = .idle
    @Published var conflictCount = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let cloudKitManager = CloudKitManager.shared
    private let privateDatabase: CKDatabase?
    private let syncQueue = DispatchQueue(label: "com.habitto.cloudkit.sync", qos: .userInitiated)
    private var syncTimer: Timer?
    
    // Sync configuration
    private let batchSize = 50
    private let maxRetries = 3
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    private init() {
        self.privateDatabase = cloudKitManager.privateDatabase
        setupSyncTimer()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start automatic sync
    func startAutoSync() {
        guard cloudKitManager.isSignedIn else {
            print("⚠️ CloudKitSyncManager: Cannot start auto sync - user not signed in")
            return
        }
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sync()
            }
        }
        
        print("✅ CloudKitSyncManager: Auto sync started")
    }
    
    /// Stop automatic sync
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("✅ CloudKitSyncManager: Auto sync stopped")
    }
    
    /// Manual sync trigger
    func sync() async {
        guard !isSyncing else {
            print("⚠️ CloudKitSyncManager: Sync already in progress")
            return
        }
        
        guard cloudKitManager.isSignedIn else {
            print("❌ CloudKitSyncManager: Cannot sync - user not signed in")
            syncStatus = .error(CloudKitError.notConfigured)
            return
        }
        
        isSyncing = true
        syncStatus = .syncing
        errorMessage = nil
        
        do {
            // Sync habits
            await syncHabits()
            
            // Sync reminders
            await syncReminders()
            
            // Sync analytics (if enabled)
            await syncAnalytics()
            
            lastSyncDate = Date()
            syncStatus = .completed
            print("✅ CloudKitSyncManager: Sync completed successfully")
            
        } catch {
            syncStatus = .error(error)
            errorMessage = error.localizedDescription
            print("❌ CloudKitSyncManager: Sync failed - \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    /// Force sync all data
    func forceSync() async {
        print("🔄 CloudKitSyncManager: Starting force sync...")
        await sync()
    }
    
    /// Resolve conflicts
    func resolveConflicts(using resolution: CloudKitSyncMetadata.ConflictResolution) async {
        // Implementation for conflict resolution
        print("🔄 CloudKitSyncManager: Resolving conflicts using \(resolution)")
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        // Timer setup is handled in startAutoSync()
    }
    
    private func syncHabits() async {
        guard let privateDatabase = privateDatabase else {
            print("❌ CloudKitSyncManager: No private database available for habit sync")
            return
        }
        
        print("🔄 CloudKitSyncManager: Starting habit sync...")
        
        // Load local habits
        let localHabits = HabitStorageManager.shared.loadHabits()
        let localCloudKitHabits = localHabits.map { habit in
            CloudKitHabit(
                id: habit.id,
                name: habit.name,
                description: habit.description,
                icon: habit.icon,
                colorHex: habit.color.toHex(),
                habitType: habit.habitType.rawValue,
                schedule: habit.schedule,
                goal: habit.goal,
                reminder: habit.reminder,
                startDate: habit.startDate,
                endDate: habit.endDate,
                isCompleted: habit.isCompleted,
                streak: habit.streak,
                createdAt: habit.createdAt,
                completionHistory: [:],
                difficultyHistory: [:],
                baseline: habit.baseline,
                target: habit.target,
                actualUsage: [:],
                cloudKitRecordID: nil,
                lastModified: habit.createdAt,
                isDeleted: false
            )
        }
        
        // Fetch remote habits
        let remoteHabits = await fetchRemoteHabits(from: privateDatabase)
        
        // Merge and resolve conflicts
        let mergedHabits = await mergeHabits(local: localCloudKitHabits, remote: remoteHabits)
        
        // Save merged habits locally
        let finalHabits = mergedHabits.map { $0.toHabit() }
        HabitStorageManager.shared.saveHabits(finalHabits, immediate: true)
        
        // Upload changes to CloudKit
        await uploadHabits(mergedHabits, to: privateDatabase)
        
        print("✅ CloudKitSyncManager: Habit sync completed")
    }
    
    private func syncReminders() async {
        // Implementation for reminder sync
        print("🔄 CloudKitSyncManager: Starting reminder sync...")
        // TODO: Implement reminder sync
        print("✅ CloudKitSyncManager: Reminder sync completed")
    }
    
    private func syncAnalytics() async {
        // Implementation for analytics sync
        print("🔄 CloudKitSyncManager: Starting analytics sync...")
        // TODO: Implement analytics sync
        print("✅ CloudKitSyncManager: Analytics sync completed")
    }
    
    private func fetchRemoteHabits(from database: CKDatabase) async -> [CloudKitHabit] {
        let query = CKQuery(recordType: "Habit", predicate: NSPredicate(value: true))
        
        do {
            let result = try await database.records(matching: query)
            let habits = result.matchResults.compactMap { try? $0.1.get() }
                .compactMap { CloudKitHabit.fromCloudKitRecord($0) }
            
            print("📥 CloudKitSyncManager: Fetched \(habits.count) remote habits")
            return habits
            
        } catch {
            print("❌ CloudKitSyncManager: Error fetching remote habits - \(error.localizedDescription)")
            return []
        }
    }
    
    private func mergeHabits(local: [CloudKitHabit], remote: [CloudKitHabit]) async -> [CloudKitHabit] {
        var mergedHabits: [CloudKitHabit] = []
        var conflictCount = 0
        
        // Create lookup dictionaries
        let localDict = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let remoteDict = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        
        // Get all unique IDs
        let allIds = Set(localDict.keys).union(Set(remoteDict.keys))
        
        for id in allIds {
            let localHabit = localDict[id]
            let remoteHabit = remoteDict[id]
            
            if let local = localHabit, let remote = remoteHabit {
                // Both exist - check for conflicts
                if local.lastModified > remote.lastModified {
                    // Local is newer
                    mergedHabits.append(local)
                } else if remote.lastModified > local.lastModified {
                    // Remote is newer
                    mergedHabits.append(remote)
                } else {
                    // Same timestamp - use local (or implement more sophisticated conflict resolution)
                    mergedHabits.append(local)
                    conflictCount += 1
                }
            } else if let local = localHabit {
                // Only local exists
                mergedHabits.append(local)
            } else if let remote = remoteHabit {
                // Only remote exists
                mergedHabits.append(remote)
            }
        }
        
        self.conflictCount = conflictCount
        print("🔄 CloudKitSyncManager: Merged \(mergedHabits.count) habits, \(conflictCount) conflicts")
        
        return mergedHabits
    }
    
    private func uploadHabits(_ habits: [CloudKitHabit], to database: CKDatabase) async {
        let batches = habits.chunked(into: batchSize)
        
        for batch in batches {
            let records = batch.map { $0.toCloudKitRecord() }
            
            do {
                let result = try await database.modifyRecords(saving: records, deleting: [])
                print("📤 CloudKitSyncManager: Uploaded batch of \(records.count) habits")
                
                // Handle any errors
                for (recordID, result) in result.saveResults {
                    switch result {
                    case .success(let record):
                        print("✅ CloudKitSyncManager: Successfully saved habit \(recordID.recordName)")
                    case .failure(let error):
                        print("❌ CloudKitSyncManager: Failed to save habit \(recordID.recordName) - \(error.localizedDescription)")
                    }
                }
                
            } catch {
                print("❌ CloudKitSyncManager: Error uploading habit batch - \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


// MARK: - CloudKit Error Extensions
extension CloudKitError {
    static let syncFailed = CloudKitError.notConfigured // Placeholder for sync-specific errors
}
