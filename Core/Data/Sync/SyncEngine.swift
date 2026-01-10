import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import SwiftUI
import OSLog

// MARK: - SyncEngine

/// Actor that handles syncing ProgressEvent records to Firestore
///
/// Responsibilities:
/// - Fetch unsynced events from SwiftData
/// - Write events to Firestore with idempotency checks
/// - Mark events as synced after successful upload
/// - Schedule background syncs
actor SyncEngine {
    // MARK: - Sendable Data Structures
    
    /// Sendable award data for syncing across actor boundaries
    struct AwardData: Sendable {
        let userIdDateKey: String
        let dateKey: String
        let xpGranted: Int
        let allHabitsCompleted: Bool
        let createdAt: Date
    }
    
    /// Sendable completion data for syncing across actor boundaries
    struct CompletionData: Sendable {
        let completionId: String // Deterministic: "comp_{habitId}_{dateKey}"
        let habitId: String
        let dateKey: String
        let isCompleted: Bool
        let progress: Int
        let createdAt: Date
        let updatedAt: Date
    }
    // MARK: - Singleton
    
    static let shared = SyncEngine()
    
    // MARK: - Properties
    
    private let firestore: Firestore
    private let habitStore: HabitStore
    private var isSyncing: Bool = false
    private let logger = Logger(subsystem: "com.habitto.app", category: "SyncEngine")
    
    // ✅ CRITICAL BUG FIX: Track recently deleted habits to prevent resurrection
    private static var recentlyDeletedHabitIds: Set<UUID> = []
    private static let deletedHabitsLock = NSLock()
    
    // MARK: - Deleted Habit Tracking
    
    /// Mark a habit as deleted to prevent resurrection
    static func markHabitAsDeleted(_ habitId: UUID) {
        deletedHabitsLock.lock()
        recentlyDeletedHabitIds.insert(habitId)
        deletedHabitsLock.unlock()
        Logger(subsystem: "com.habitto.app", category: "SyncEngine").info("🗑️ SyncEngine: Marked habit \(habitId.uuidString.prefix(8))... as deleted")
    }
    
    /// Check if a habit was recently deleted
    static func isHabitDeleted(_ habitId: UUID) -> Bool {
        deletedHabitsLock.lock()
        defer { deletedHabitsLock.unlock() }
        return recentlyDeletedHabitIds.contains(habitId)
    }
    
    /// Clear the deleted marker for a habit (after cleanup is complete)
    static func clearDeletedHabit(_ habitId: UUID) {
        deletedHabitsLock.lock()
        recentlyDeletedHabitIds.remove(habitId)
        deletedHabitsLock.unlock()
        Logger(subsystem: "com.habitto.app", category: "SyncEngine").info("✅ SyncEngine: Cleared deleted marker for habit \(habitId.uuidString.prefix(8))...")
    }
    
    // Background sync scheduler
    private var syncTask: Task<Void, Never>?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var periodicSyncUserId: String?
    
    // MARK: - Initialization
    
    private init() {
        self.firestore = Firestore.firestore()
        self.habitStore = HabitStore.shared
        logger.info("SyncEngine initialized")
        debugLog("🔄 SyncEngine: Initialized")
        NSLog("🔄 SyncEngine: Initialized (NSLog)")
        fflush(stdout)
    }
    
    // MARK: - Helper Methods
    
    /// Helper function to safely create Timestamp from Date
    /// Prevents crash from invalid dates (e.g., Date.distantPast) that are out of Firestore's valid range
    private func safeTimestamp(from date: Date?) -> Timestamp {
        guard let date = date else {
            return Timestamp(date: Date())
        }
        // Check if date is valid for Firestore (year 1-9999)
        let year = Calendar.current.component(.year, from: date)
        if year < 1 || year > 9999 {
            logger.warning("⚠️ SyncEngine: Invalid date year \(year) - using current date as fallback")
            return Timestamp(date: Date()) // Use current date as fallback
        }
        return Timestamp(date: date)
    }
    
    // MARK: - Event Sync
    
    /// Sync all unsynced events to Firestore
    ///
    /// Events are written to: `/users/{userId}/events/{yearMonth}/{eventId}`
    /// Uses `operationId` for idempotency to prevent duplicate writes
    func syncEvents() async throws {
        // Prevent concurrent syncs
        guard !isSyncing else {
            logger.info("⏭️ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let userId = await CurrentUser().idOrGuest
        
        // ✅ Skip sync only for users with userId = "" (no Firebase auth)
        // Anonymous users (with Firebase UID) ARE synced to Firestore
        guard !CurrentUser.isGuestId(userId) else {
            logger.info("⏭️ Skipping event sync for guest user (userId = \"\")")
            return
        }
        
        logger.info("🔄 Starting event sync for user: \(userId)")
        
        let startTime = Date()
        var syncedCount = 0
        var failedCount = 0
        var syncError: Error?
        
        // Record queue size before sync
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let descriptor = ProgressEvent.unsyncedEvents()
            let queueSize = (try? modelContext.fetch(descriptor))?.count ?? 0
            SyncHealthMonitor.shared.recordQueueSize(queueSize, operation: .events)
        }
        
        defer {
            // Record sync metrics
            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                SyncHealthMonitor.shared.recordSync(
                    operation: .events,
                    duration: duration,
                    success: syncError == nil && failedCount == 0,
                    itemsSynced: syncedCount,
                    itemsFailed: failedCount,
                    conflictsResolved: 0,
                    error: syncError
                )
            }
        }
        
        // Fetch unsynced event IDs and data (ModelContext access must be on MainActor)
        // Extract Sendable data to avoid passing ProgressEvent across concurrency boundaries
        struct EventData: Sendable {
            let id: String
            let dateKey: String
            let operationId: String
        }
        
        let eventDataArray: [EventData] = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let descriptor = ProgressEvent.unsyncedEvents()
            let events = (try? modelContext.fetch(descriptor)) ?? []
            return events.map { event in
                EventData(
                    id: event.id,
                    dateKey: event.dateKey,
                    operationId: event.operationId
                )
            }
        }
        
        guard !eventDataArray.isEmpty else {
            logger.info("✅ No unsynced events to sync")
            return
        }
        
        logger.info("📤 Found \(eventDataArray.count) unsynced events to sync")
        
        // Sync events in batches to avoid overwhelming Firestore
        let batchSize = 50
        for batchStart in stride(from: 0, to: eventDataArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, eventDataArray.count)
            let batch = Array(eventDataArray[batchStart..<batchEnd])
            
            do {
                // syncBatch handles ModelContext access internally using event IDs
                let successfullySynced = try await syncBatch(eventIds: batch.map { $0.id }, userId: userId)
                syncedCount += successfullySynced
                logger.info("✅ Synced batch: \(successfullySynced) events (\(syncedCount)/\(eventDataArray.count))")
            } catch {
                failedCount += batch.count
                if syncError == nil {
                    syncError = error
                }
                logger.error("❌ Failed to sync batch: \(error.localizedDescription)")
                // Continue with next batch even if this one failed
            }
        }
        
        logger.info("✅ Event sync completed: \(syncedCount) synced, \(failedCount) failed")
    }
    
    /// Sync a batch of events to Firestore using event IDs
    private func syncBatch(
        eventIds: [String],
        userId: String
    ) async throws -> Int {
        // Fetch events and sync them one by one (avoiding Sendable issues with [String: Any])
        var eventIdsToMarkSynced: [String] = []
        var alreadySyncedCount = 0
        
        // Use Firestore batch write for atomicity
        let batch = firestore.batch()
        
        for eventId in eventIds {
            // Fetch event data on MainActor
            let eventData: (id: String, dateKey: String, operationId: String, firestoreData: [String: Any])? = await MainActor.run {
                let modelContext = SwiftDataContainer.shared.modelContext
                let descriptor = FetchDescriptor<ProgressEvent>(
                    predicate: #Predicate { $0.id == eventId }
                )
                guard let event = try? modelContext.fetch(descriptor).first else {
                    return nil
                }
                
                var firestoreData = event.toFirestore()
                firestoreData["operationId"] = event.operationId
                
                return (
                    id: event.id,
                    dateKey: event.dateKey,
                    operationId: event.operationId,
                    firestoreData: firestoreData
                )
            }
            
            guard let eventData = eventData else { continue }
            
            // Generate yearMonth from dateKey (format: "yyyy-MM-dd" -> "yyyy-MM")
            let yearMonth = String(eventData.dateKey.prefix(7)) // "2025-10-31" -> "2025-10"
            
            // Firestore path: /users/{userId}/events/{yearMonth}/{eventId}
            let eventRef = firestore.collection("users")
                .document(userId)
                .collection("events")
                .document(yearMonth)
                .collection("events")
                .document(eventData.id)
            
            // Check if event already exists (idempotency check using operationId)
            let existingDoc = try? await eventRef.getDocument()
            if let existingData = existingDoc?.data(),
               let existingOperationId = existingData["operationId"] as? String,
               existingOperationId == eventData.operationId {
                // Event already synced, mark as synced locally
                logger.info("⏭️ Event \(eventData.id.prefix(20))... already synced (operationId match), marking as synced")
                eventIdsToMarkSynced.append(eventData.id)
                alreadySyncedCount += 1
                continue
            }
            
            // Write to Firestore (setData with merge for idempotency)
            batch.setData(eventData.firestoreData, forDocument: eventRef, merge: true)
            eventIdsToMarkSynced.append(eventData.id)
        }
        
        // Only commit if there are events to sync
        guard alreadySyncedCount < eventIdsToMarkSynced.count else {
            // All events were already synced, just mark them
            await markEventsAsSynced(eventIds: eventIdsToMarkSynced)
            return alreadySyncedCount
        }
        
        // Commit batch
        try await batch.commit()
        
        // Mark events as synced (must be on MainActor for ModelContext)
        await markEventsAsSynced(eventIds: eventIdsToMarkSynced)
        
        return eventIdsToMarkSynced.count
    }
    
    /// Mark events as synced using their IDs (runs on MainActor)
    private func markEventsAsSynced(eventIds: [String]) async {
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            for eventId in eventIds {
                let descriptor = FetchDescriptor<ProgressEvent>(
                    predicate: #Predicate { $0.id == eventId }
                )
                if let event = try? modelContext.fetch(descriptor).first {
                    event.markAsSynced()
                }
            }
            do {
                try modelContext.save()
            } catch {
                logger.error("❌ Failed to save synced status: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Background Sync Scheduler
    
    /// Schedule a sync if one is not already scheduled
    /// Uses full sync cycle to ensure all data types are synced
    func scheduleSyncIfNeeded() {
        // Cancel existing task if any
        syncTask?.cancel()
        
        // Schedule new sync task
        syncTask = Task {
            // Wait a short delay to batch multiple sync requests
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            do {
                // Perform full sync cycle (includes all sync operations)
                let userId = await CurrentUser().idOrGuest
                // ✅ Skip sync only for users with userId = "" (no Firebase auth)
                // Anonymous users (with Firebase UID) ARE synced to Firestore
                guard !CurrentUser.isGuestId(userId) else {
                    logger.info("⏭️ Skipping background sync for guest user (userId = \"\")")
                    return
                }
                try await self.performFullSyncCycle(userId: userId)
            } catch {
                self.logger.error("❌ Background sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start periodic background sync (every 5 minutes)
    /// Orchestrates all sync operations: pull remote changes, then sync local changes
    /// Performs an immediate sync on start, then continues periodically
    /// - Parameter userId: The authenticated user ID (must not be guest). If nil, will fetch from CurrentUser.
    func startPeriodicSync(userId: String? = nil, forceRestart: Bool = false) {
        if let providedUserId = userId {
            if !forceRestart, periodicSyncUserId == providedUserId, syncTask != nil {
                logger.info("⏭️ Periodic sync already running for user \(providedUserId), skipping restart")
                return
            }
            periodicSyncUserId = providedUserId
        }
        logger.info("🔄 Starting periodic sync (every \(self.syncInterval)s)")
        
        syncTask?.cancel()
        
        syncTask = Task {
            // Use provided userId or fetch it (for backward compatibility)
            let initialUserId: String
            if let providedUserId = userId {
                initialUserId = providedUserId
            } else {
                initialUserId = await CurrentUser().idOrGuest
            }
            
            // ✅ Skip sync only for users with userId = "" (no Firebase auth)
            // Anonymous users (with Firebase UID) ARE synced to Firestore
            guard !CurrentUser.isGuestId(initialUserId) else {
                logger.info("⏭️ Skipping periodic sync for guest user (userId = \"\")")
                self.stopPeriodicSync(reason: "guest user")
                return
            }
            
            self.periodicSyncUserId = initialUserId
            
            // Perform immediate sync on start (don't wait for first interval)
            do {
                try await self.performFullSyncCycle(userId: initialUserId)
            } catch {
                self.logger.error("❌ Initial sync failed: \(error.localizedDescription)")
            }
            
            // Then continue with periodic syncs
            while !Task.isCancelled {
                // Wait for sync interval before next sync
                try? await Task.sleep(nanoseconds: UInt64(self.syncInterval * 1_000_000_000))
                
                // Check if cancelled before performing sync
                guard !Task.isCancelled else { break }
                
                // Re-check userId in case user signed out
                let currentUserId = await CurrentUser().idOrGuest
                // ✅ Skip sync only for users with userId = "" (no Firebase auth)
                // Anonymous users (with Firebase UID) continue syncing
                guard !CurrentUser.isGuestId(currentUserId) else {
                    logger.info("⏭️ User is now guest (userId = \"\"), stopping periodic sync")
                    debugLog("⏭️ SyncEngine: User is now guest (userId = \"\"), stopping periodic sync")
                    break
                }
                
                do {
                    // Perform full sync cycle
                    try await self.performFullSyncCycle(userId: currentUserId)
                } catch {
                    self.logger.error("❌ Periodic sync failed: \(error.localizedDescription)")
                    debugLog("❌ SyncEngine: Periodic sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stop the periodic sync task (e.g., when user signs out)
    func stopPeriodicSync(reason: String? = nil) {
        if let reason {
            logger.info("🛑 Stopping periodic sync (\(reason))")
            debugLog("🛑 SyncEngine: Stopping periodic sync (\(reason))")
        } else {
            logger.info("🛑 Stopping periodic sync")
            debugLog("🛑 SyncEngine: Stopping periodic sync")
        }
        syncTask?.cancel()
        syncTask = nil
        periodicSyncUserId = nil
    }
    
    /// Check if periodic sync is currently active
    func hasActiveSync() -> Bool {
        return periodicSyncUserId != nil && syncTask != nil && !Task.isCancelled
    }
    
    /// Perform a full sync cycle: pull remote changes, then sync local changes
    /// This orchestrates all sync operations in the correct order
    /// - Parameter userId: The authenticated user ID (must not be guest)
    func performFullSyncCycle(userId: String) async throws {
        // ✅ Skip sync only for users with userId = "" (no Firebase auth)
        // Anonymous users (with Firebase UID) ARE synced to Firestore
        guard !CurrentUser.isGuestId(userId) else {
            logger.info("⏭️ Skipping full sync cycle for guest user (userId = \"\")")
            return
        }
        
        logger.info("🔄 Starting full sync cycle for user: \(userId)")
        
        // Notify HabitRepository that sync started
        Task { @MainActor in
            HabitRepository.shared.syncStarted()
        }
        
        let startTime = Date()
        var pullError: Error?
        var eventsError: Error?
        var completionsError: Error?
        var awardsError: Error?
        
        defer {
            // Record full sync cycle metrics
            let duration = Date().timeIntervalSince(startTime)
            let success = pullError == nil && eventsError == nil && completionsError == nil && awardsError == nil
            let finalError = pullError ?? eventsError ?? completionsError ?? awardsError
            
            Task { @MainActor in
                SyncHealthMonitor.shared.recordSync(
                    operation: .full,
                    duration: duration,
                    success: success,
                    itemsSynced: 0, // Individual operations track their own counts
                    itemsFailed: 0,
                    conflictsResolved: 0,
                    error: finalError
                )
                
                // Notify HabitRepository of sync completion/failure
                if success {
                    HabitRepository.shared.syncCompleted()
                } else if let error = finalError {
                    HabitRepository.shared.syncFailed(error: error)
                }
            }
        }
        
        // Step 1: Pull remote changes first (to get latest data from server)
        do {
            let pullStartTime = Date()
            let summary = try await pullRemoteChanges(userId: userId)
            let pullDuration = Date().timeIntervalSince(pullStartTime)
            logger.info("✅ Pull remote changes completed: \(summary)")
            
            // Record pull metrics
            Task { @MainActor in
                SyncHealthMonitor.shared.recordSync(
                    operation: .full,
                    duration: pullDuration,
                    success: true,
                    itemsSynced: summary.eventsPulled + summary.completionsPulled + summary.awardsPulled,
                    itemsFailed: 0,
                    conflictsResolved: 0,
                    error: nil
                )
            }
        } catch {
            pullError = error
            logger.error("❌ Failed to pull remote changes: \(error.localizedDescription)")
            // Continue with local sync even if pull fails
        }
        
        // ✅ BUG FIX: Retry pending Firestore deletions that failed previously
        // This cleans up orphaned habits that couldn't be deleted due to network errors
        await MainActor.run {
            _ = Task {
                await FirebaseBackupService.shared.retryPendingDeletions()
            }
        }
        
        // Step 2: Sync local changes to server (in order of dependency)
        // Events first (they affect completions), then completions, then awards
        do {
            try await syncEvents()
        } catch {
            eventsError = error
            logger.error("❌ Failed to sync events: \(error.localizedDescription)")
        }
        
        do {
            try await syncCompletions()
        } catch {
            completionsError = error
            logger.error("❌ Failed to sync completions: \(error.localizedDescription)")
        }
        
        do {
            try await syncAwards()
        } catch {
            awardsError = error
            logger.error("❌ Failed to sync awards: \(error.localizedDescription)")
        }
        
        logger.info("✅ Full sync cycle completed")
    }
    
    /// Stop periodic sync
    func stopPeriodicSync() {
        logger.info("⏹️ Stopping periodic sync")
        syncTask?.cancel()
        syncTask = nil
    }
    
    // MARK: - Award Sync
    
    /// Sync all DailyAward records to Firestore atomically
    ///
    /// Awards are written to: `/users/{userId}/daily_awards/{userIdDateKey}`
    /// Uses `userIdDateKey` (deterministic: "{userId}#{dateKey}") for idempotency
    /// Also updates `/users/{userId}/progress/current` with total XP in the same transaction
    func syncAwards() async throws {
        // Prevent concurrent syncs
        guard !isSyncing else {
            logger.info("⏭️ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let userId = await CurrentUser().idOrGuest
        
        // ✅ Skip sync only for users with userId = "" (no Firebase auth)
        // Anonymous users (with Firebase UID) ARE synced to Firestore
        guard !CurrentUser.isGuestId(userId) else {
            logger.info("⏭️ Skipping award sync for guest user (userId = \"\")")
            return
        }
        
        logger.info("🔄 Starting award sync for user: \(userId)")
        
        let startTime = Date()
        var syncedCount = 0
        var failedCount = 0
        var alreadySyncedCount = 0
        var syncError: Error?
        
        // Record queue size before sync
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let descriptor = FetchDescriptor<DailyAward>(predicate: predicate)
            let queueSize = (try? modelContext.fetch(descriptor))?.count ?? 0
            SyncHealthMonitor.shared.recordQueueSize(queueSize, operation: .awards)
        }
        
        defer {
            // Record sync metrics
            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                SyncHealthMonitor.shared.recordSync(
                    operation: .awards,
                    duration: duration,
                    success: syncError == nil && failedCount == 0,
                    itemsSynced: syncedCount + alreadySyncedCount,
                    itemsFailed: failedCount,
                    conflictsResolved: 0,
                    error: syncError
                )
            }
        }
        
        // Fetch all awards for this user (ModelContext access must be on MainActor)
        // Extract Sendable data to avoid passing DailyAward across concurrency boundaries
        let awardDataArray: [AwardData] = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<DailyAward> { award in
                award.userId == userId
            }
            let descriptor = FetchDescriptor<DailyAward>(predicate: predicate)
            let awards = (try? modelContext.fetch(descriptor)) ?? []
            return awards.map { award in
                AwardData(
                    userIdDateKey: award.userIdDateKey,
                    dateKey: award.dateKey,
                    xpGranted: award.xpGranted,
                    allHabitsCompleted: award.allHabitsCompleted,
                    createdAt: award.createdAt
                )
            }
        }
        
        guard !awardDataArray.isEmpty else {
            logger.info("✅ No awards to sync")
            return
        }
        
        logger.info("📤 Found \(awardDataArray.count) awards to sync")
        
        // Snapshot the latest XP state from DailyAwardService (source of truth)
        let xpSnapshot: XPState? = await MainActor.run {
            DailyAwardService.shared.xpState
        }
        
        if xpSnapshot == nil {
            logger.warning("⚠️ SyncEngine: XP snapshot unavailable; xp/state document update will be skipped to avoid zeroing remote data")
        }
        
        // Sync awards in batches using transactions
        let batchSize = 10 // Smaller batches for transactions
        for batchStart in stride(from: 0, to: awardDataArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, awardDataArray.count)
            let batch = Array(awardDataArray[batchStart..<batchEnd])
            
            do {
                let result = try await syncAwardsBatch(
                    awards: batch,
                    userId: userId,
                    xpSnapshot: xpSnapshot
                )
                syncedCount += result.synced
                alreadySyncedCount += result.alreadySynced
                logger.info("✅ Synced batch: \(result.synced) awards (\(syncedCount + alreadySyncedCount)/\(awardDataArray.count))")
            } catch {
                failedCount += batch.count
                if syncError == nil {
                    syncError = error
                }
                logger.error("❌ Failed to sync batch: \(error.localizedDescription)")
                // Continue with next batch even if this one failed
            }
        }
        
        logger.info("✅ Award sync completed: \(syncedCount) synced, \(alreadySyncedCount) already synced, \(failedCount) failed")
    }
    
    /// Sync a batch of awards to Firestore using transactions
    private func syncAwardsBatch(
        awards: [AwardData],
        userId: String,
        xpSnapshot: XPState?
    ) async throws -> (synced: Int, alreadySynced: Int) {
        // Track counts locally to avoid double-counting on transaction retries
        var syncedCount = 0
        var alreadySyncedCount = 0
        
        // Use Firestore transaction for atomicity
        // Note: runTransaction expects (Transaction, NSErrorPointer) -> Any? signature
        let result = try await firestore.runTransaction { (transaction, errorPointer) -> Any? in
            var batchSynced = 0
            var batchAlreadySynced = 0
            
            for award in awards {
                // Firestore path: /users/{userId}/daily_awards/{userIdDateKey}
                let awardRef = self.firestore.collection("users")
                    .document(userId)
                    .collection("daily_awards")
                    .document(award.userIdDateKey)
                
                // Check if award already exists (idempotency)
                // Note: getDocument in transaction throws if document doesn't exist
                do {
                    let existingDoc = try transaction.getDocument(awardRef)
                    if existingDoc.exists {
                        // Award already synced, skip
                        batchAlreadySynced += 1
                        continue
                    }
                } catch {
                    // Document doesn't exist - proceed to create
                    // This is expected for new awards
                }
                
                // Create award document
                // ✅ BUG 1 FIX: Use safeTimestamp to prevent crash from invalid dates
                let awardData: [String: Any] = [
                    "userId": userId,
                    "dateKey": award.dateKey,
                    "xpGranted": award.xpGranted,
                    "allHabitsCompleted": award.allHabitsCompleted,
                    "createdAt": self.safeTimestamp(from: award.createdAt),
                    "userIdDateKey": award.userIdDateKey
                ]
                
                transaction.setData(awardData, forDocument: awardRef)
                batchSynced += 1
            }
            
            if let xpSnapshot {
                let xpStateRef = self.firestore.collection("users")
                    .document(userId)
                    .collection("xp")
                    .document("state")
                
                let progressData: [String: Any] = [
                    "totalXP": xpSnapshot.totalXP,
                    "level": xpSnapshot.level,
                    "currentLevelXP": xpSnapshot.currentLevelXP,
                    "lastUpdated": Timestamp(date: xpSnapshot.lastUpdated)
                ]
                
                transaction.setData(progressData, forDocument: xpStateRef, merge: true)
            } else {
                self.logger.warning("⚠️ SyncEngine: Transaction skipped xp/state update – missing XP snapshot")
            }
            
            // Return counts as tuple (wrapped in array for easier casting)
            return [batchSynced, batchAlreadySynced]
        }
        
        // Extract counts from transaction result
        if let resultArray = result as? [Int], resultArray.count == 2 {
            syncedCount = resultArray[0]
            alreadySyncedCount = resultArray[1]
        }
        
        return (syncedCount, alreadySyncedCount)
    }
    
    // MARK: - Completion Sync
    
    /// Sync all CompletionRecord records to Firestore
    ///
    /// Completions are written to: `/users/{userId}/completions/{yearMonth}/{completionId}`
    /// Uses deterministic ID format: "comp_{habitId}_{dateKey}" for idempotency
    /// Checks for existing completions before creating (idempotency)
    func syncCompletions() async throws {
        // Prevent concurrent syncs
        guard !isSyncing else {
            logger.info("⏭️ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let userId = await CurrentUser().idOrGuest
        
        // ✅ Skip sync only for users with userId = "" (no Firebase auth)
        // Anonymous users (with Firebase UID) ARE synced to Firestore
        guard !CurrentUser.isGuestId(userId) else {
            logger.info("⏭️ Skipping completion sync for guest user (userId = \"\")")
            return
        }
        
        logger.info("🔄 Starting completion sync for user: \(userId)")
        
        let startTime = Date()
        var syncedCount = 0
        var failedCount = 0
        var alreadySyncedCount = 0
        var syncError: Error?
        
        // Record queue size before sync
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<CompletionRecord> { record in
                record.userId == userId
            }
            let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
            let queueSize = (try? modelContext.fetch(descriptor))?.count ?? 0
            SyncHealthMonitor.shared.recordQueueSize(queueSize, operation: .completions)
        }
        
        defer {
            // Record sync metrics
            let duration = Date().timeIntervalSince(startTime)
            Task { @MainActor in
                SyncHealthMonitor.shared.recordSync(
                    operation: .completions,
                    duration: duration,
                    success: syncError == nil && failedCount == 0,
                    itemsSynced: syncedCount + alreadySyncedCount,
                    itemsFailed: failedCount,
                    conflictsResolved: 0,
                    error: syncError
                )
            }
        }
        
        // Fetch all completion records for this user (ModelContext access must be on MainActor)
        // Extract Sendable data to avoid passing CompletionRecord across concurrency boundaries
        let completionDataArray: [CompletionData] = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<CompletionRecord> { record in
                record.userId == userId
            }
            let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
            let completions = (try? modelContext.fetch(descriptor)) ?? []
            return completions.map { completion in
                // Generate deterministic ID: "comp_{habitId}_{dateKey}"
                let habitIdString = completion.habitId.uuidString
                let completionId = "comp_\(habitIdString)_\(completion.dateKey)"
                return CompletionData(
                    completionId: completionId,
                    habitId: habitIdString,
                    dateKey: completion.dateKey,
                    isCompleted: completion.isCompleted,
                    progress: completion.progress,
                    createdAt: completion.createdAt,
                    updatedAt: completion.updatedAt ?? completion.createdAt
                )
            }
        }
        
        guard !completionDataArray.isEmpty else {
            logger.info("✅ No completions to sync")
            return
        }
        
        logger.info("📤 Found \(completionDataArray.count) completions to sync")
        
        // Sync completions in batches
        let batchSize = 50
        for batchStart in stride(from: 0, to: completionDataArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, completionDataArray.count)
            let batch = Array(completionDataArray[batchStart..<batchEnd])
            
            do {
                let result = try await syncCompletionsBatch(completions: batch, userId: userId)
                syncedCount += result.synced
                alreadySyncedCount += result.alreadySynced
            } catch {
                failedCount += batch.count
                if syncError == nil {
                    syncError = error
                }
                logger.error("❌ Failed to sync batch: \(error.localizedDescription)")
                // Continue with next batch even if this one failed
            }
        }
        
        logger.info("✅ Completion sync completed: \(syncedCount) synced, \(alreadySyncedCount) already synced, \(failedCount) failed")
    }
    
    /// Sync a batch of completions to Firestore
    private func syncCompletionsBatch(
        completions: [CompletionData],
        userId: String
    ) async throws -> (synced: Int, alreadySynced: Int) {
        var syncedCount = 0
        var alreadySyncedCount = 0
        
        // Use Firestore batch write for efficiency
        let batch = firestore.batch()
        
        for completion in completions {
            // Generate yearMonth from dateKey (format: "yyyy-MM-dd" -> "yyyy-MM")
            let yearMonth = String(completion.dateKey.prefix(7)) // "2025-10-31" -> "2025-10"
            
            // Firestore path: /users/{userId}/completions/{yearMonth}/{completionId}
            let completionRef = firestore.collection("users")
                .document(userId)
                .collection("completions")
                .document(yearMonth)
                .collection("completions")
                .document(completion.completionId)
            
            var shouldWriteRemote = true
            
            if let existingDoc = try? await completionRef.getDocument(), existingDoc.exists {
                let remoteData = existingDoc.data() ?? [:]
                let remoteProgress = remoteData["progress"] as? Int
                let remoteCompleted = remoteData["isCompleted"] as? Bool
                
                if remoteProgress == completion.progress && remoteCompleted == completion.isCompleted {
                    // Remote already matches local state, skip write
                    alreadySyncedCount += 1
                    shouldWriteRemote = false
                }
            }
            
            guard shouldWriteRemote else {
                continue
            }
            
            // Create/overwrite completion document
            // ✅ BUG 1 FIX: Use safeTimestamp to prevent crash from invalid dates
            let completionData: [String: Any] = [
                "userId": userId,
                "habitId": completion.habitId,
                "dateKey": completion.dateKey,
                "isCompleted": completion.isCompleted,
                "progress": completion.progress,
                "createdAt": safeTimestamp(from: completion.createdAt),
                "updatedAt": safeTimestamp(from: completion.updatedAt),
                "completionId": completion.completionId
            ]
            
            batch.setData(completionData, forDocument: completionRef, merge: true)
            syncedCount += 1
        }
        
        // Only commit if there are completions to sync
        guard syncedCount > 0 else {
            return (synced: 0, alreadySynced: alreadySyncedCount)
        }
        
        // Commit batch
        try await batch.commit()
        
        return (synced: syncedCount, alreadySynced: alreadySyncedCount)
    }
    
    // MARK: - Pull Remote Changes
    
    /// Pull remote changes from Firestore and merge into local SwiftData
    ///
    /// Fetches:
    /// - Habits updated since last sync
    /// - CompletionRecords from recent months (last 3 months)
    /// - DailyAwards updated since last sync
    /// - ProgressEvents from recent months (last 3 months)
    ///
    /// - Parameter userId: The authenticated user ID (must not be guest). If nil, will fetch from CurrentUser.
    /// Returns: Summary of what was synced
    func pullRemoteChanges(userId: String? = nil) async throws -> PullSyncSummary {
        // Use provided userId or fetch it (for backward compatibility)
        let actualUserId: String
        if let providedUserId = userId {
            actualUserId = providedUserId
        } else {
            actualUserId = await CurrentUser().idOrGuest
        }
        
        // ✅ Skip sync only for users with userId = "" (no Firebase auth)
        // Anonymous users (with Firebase UID) ARE synced to Firestore
        guard !CurrentUser.isGuestId(actualUserId) else {
            logger.info("⏭️ Skipping pull for guest user (userId = \"\")")
            debugLog("⏭️ SyncEngine: Skipping pull for guest user (userId: '\(actualUserId)')")
            NSLog("⏭️ SyncEngine: Skipping pull for guest user (userId: '%@')", actualUserId)
            fflush(stdout)
            return PullSyncSummary()
        }
        
        // ✅ ISSUE 1 FIX: Check if this is a fresh install (empty local SwiftData)
        // If so, reset lastSync to pull ALL data from Firestore
        let isFirstSync = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<HabitData> { habit in
                habit.userId == actualUserId
            }
            let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
            let localHabits = (try? modelContext.fetch(descriptor)) ?? []
            return localHabits.isEmpty
        }
        
        let lastSync: Date
        if isFirstSync {
            // Fresh install or empty database - pull ALL data from Firestore
            lastSync = Date.distantPast
            logger.info("🆕 Fresh install detected - pulling all remote data (ignoring stored lastSync)")
            debugLog("🆕 SYNC: Fresh install - will pull ALL habits from Firestore")
        } else {
            lastSync = getLastSyncTimestamp(userId: actualUserId) ?? Date.distantPast
        }
        
        logger.info("🔄 Starting pull remote changes for user: \(actualUserId)")
        debugLog("🔵 SYNC_PULL_START: userId=\(actualUserId), lastSync=\(lastSync.ISO8601Format())")
        NSLog("🔄 SyncEngine: Starting pull remote changes for user: %@", actualUserId)
        fflush(stdout)
        
        var summary = PullSyncSummary()
        
        // 1. Pull habits updated since last sync
        do {
            let habitsPulled = try await pullHabits(userId: actualUserId, since: lastSync)
            summary.habitsPulled = habitsPulled
            logger.info("✅ Pulled \(habitsPulled) habits")
        } catch {
            logger.error("❌ Failed to pull habits: \(error.localizedDescription)")
            summary.errors.append("Failed to pull habits: \(error.localizedDescription)")
        }
        
        // 2. Pull completions from recent months (last 3 months)
        // ✅ FIX: Also try to pull all completions if recent months returns 0
        do {
            var completionsPulled = try await pullCompletions(userId: actualUserId, recentMonths: 3)
            logger.info("✅ Pulled \(completionsPulled) completions from recent 3 months")
            
            // If no completions found in recent months, try pulling all completions
            if completionsPulled == 0 {
                logger.info("🔄 No completions in recent months, attempting to pull all completions...")
                let allCompletionsPulled = try await pullAllCompletions(userId: actualUserId)
                completionsPulled = allCompletionsPulled
                logger.info("✅ Pulled \(allCompletionsPulled) completions from all months")
            }
            
            summary.completionsPulled = completionsPulled
            
            // ✅ CRITICAL FIX: Reload habits after completion sync to reflect new completion states
            if completionsPulled > 0 {
                await HabitRepository.shared.loadHabits(force: true)
                logger.info("✅ SyncEngine: Reloaded habits after completion sync")
                
                // ✅ BUG 4 FIX: Capture value before MainActor.run to avoid Swift 6 concurrency warning
                let pulledCount = completionsPulled
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SyncCompletionsPulled"),
                        object: nil,
                        userInfo: ["completionsPulled": pulledCount]
                    )
                }
            }
        } catch {
            logger.error("❌ Failed to pull completions: \(error.localizedDescription)")
            summary.errors.append("Failed to pull completions: \(error.localizedDescription)")
        }
        
        // 3. Pull awards updated since last sync
        // ✅ FIX: If no awards found, try pulling all awards
        do {
            var awardsPulled = try await pullAwards(userId: actualUserId, since: lastSync)
            logger.info("✅ Pulled \(awardsPulled) awards since last sync")
            
            // If no awards found since last sync, try pulling all awards
            if awardsPulled == 0 {
                logger.info("🔄 No awards since last sync, attempting to pull all awards...")
                let allAwardsPulled = try await pullAllAwards(userId: actualUserId)
                awardsPulled = allAwardsPulled
                logger.info("✅ Pulled \(allAwardsPulled) awards from all time")
            }
            
            summary.awardsPulled = awardsPulled
        } catch {
            logger.error("❌ Failed to pull awards: \(error.localizedDescription)")
            summary.errors.append("Failed to pull awards: \(error.localizedDescription)")
        }
        
        // 4. Pull events from recent months (last 3 months)
        do {
            let eventsPulled = try await pullEvents(userId: actualUserId, recentMonths: 3)
            summary.eventsPulled = eventsPulled
            logger.info("✅ Pulled \(eventsPulled) events")
        } catch {
            logger.error("❌ Failed to pull events: \(error.localizedDescription)")
            summary.errors.append("Failed to pull events: \(error.localizedDescription)")
        }
        
        // 5. Update last sync timestamp after successful pull
        setLastSyncTimestamp(userId: actualUserId, timestamp: Date())
        
        // ✅ ISSUE 2 FIX: Clear cache and notify UI if we pulled habits OR if reconciliation happened
        // ✅ FIX: Capture value before async closure to avoid Swift 6 concurrency warning
        let habitsPulledCount = summary.habitsPulled
        
        // Note: Reconciliation already handles cache clearing and notifications when it deletes locally
        // We only need to handle cache clearing here if habits were pulled (but not deleted)
        if habitsPulledCount > 0 {
            // Clear the storage cache so next load fetches fresh data from SwiftData
            await habitStore.clearStorageCache()
            logger.info("🔄 Cleared storage cache after pulling \(habitsPulledCount) habits")
            
            // Notify HabitRepository to reload
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SyncPullCompleted"),
                    object: nil,
                    userInfo: ["habitsPulled": habitsPulledCount]
                )
            }
        }
        
        logger.info("✅ Pull remote changes completed: habits=\(summary.habitsPulled), completions=\(summary.completionsPulled), awards=\(summary.awardsPulled), events=\(summary.eventsPulled)")
        return summary
    }
    
    /// Pull habits updated since the given timestamp
    /// ✅ CRITICAL BUG FIX: Get ALL remote habit IDs separately for reconciliation, not just filtered ones
    private func pullHabits(userId: String, since: Date) async throws -> Int {
        logger.info("📥 Pulling habits updated since: \(since.ISO8601Format())")
        
        let habitsRef = firestore.collection("users")
            .document(userId)
            .collection("habits")
        
        // STEP 1: Get ALL habit IDs from Firestore (for reconciliation)
        let allHabitsSnapshot = try await habitsRef.getDocuments()
        var remoteHabitIds: Set<UUID> = []
        
        for document in allHabitsSnapshot.documents {
            if let uuid = UUID(uuidString: document.documentID) {
                remoteHabitIds.insert(uuid)
            }
        }
        
        logger.info("📊 SyncEngine: Found \(remoteHabitIds.count) total habits in Firestore")
        
        // STEP 2: Pull habits updated since lastSync (filter by timestamp)
        var pulledCount = 0
        
        for document in allHabitsSnapshot.documents {
            guard let uuid = UUID(uuidString: document.documentID) else {
                continue
            }
            
            let data = document.data()
            
            // Check if habit was updated since last sync
            // Use lastSyncedAt or createdAt as fallback
            let lastSyncedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue()
            let updatedAt = lastSyncedAt ?? (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            // Only merge if updated since last sync
            guard updatedAt > since else {
                continue
            }
            
            // Merge habit into SwiftData
            // ✅ BUG FIX: Errors are now logged inside mergeHabitFromFirestore, sync continues
            await mergeHabitFromFirestore(data: data, habitId: uuid, userId: userId)
            pulledCount += 1
        }
        
        logger.info("📥 SyncEngine: Pulled \(pulledCount) habits updated since \(since.ISO8601Format())")
        
        // STEP 3: Reconcile deletions using ALL remote habit IDs (not just pulled ones)
        logger.info("🔄 SyncEngine: Starting reconciliation with \(remoteHabitIds.count) remote habits")
        await reconcileDeletedHabits(userId: userId, remoteHabitIds: remoteHabitIds)
        
        return pulledCount
    }
    
    /// Pull completions from recent months
    private func pullCompletions(userId: String, recentMonths: Int) async throws -> Int {
        let yearMonths = getRecentYearMonths(count: recentMonths)
        var pulledCount = 0
        
        for yearMonth in yearMonths {
            let completionsRef = firestore.collection("users")
                .document(userId)
                .collection("completions")
                .document(yearMonth)
                .collection("completions")
            
            let snapshot = try? await completionsRef.getDocuments()
            guard let snapshot = snapshot else {
                continue
            }
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Merge completion into SwiftData
                do {
                    try await mergeCompletionFromFirestore(data: data, userId: userId)
                    pulledCount += 1
                } catch {
                    logger.error("❌ Failed to merge completion: \(error.localizedDescription)")
                    // Continue with next completion even if this one fails
                }
            }
        }
        
        if pulledCount > 0 {
            logger.info("✅ Pulled \(pulledCount) completions")
        }
        
        return pulledCount
    }
    
    /// Pull ALL completions from all year-months (not just recent)
    /// This is used when recent months return 0 results
    private func pullAllCompletions(userId: String) async throws -> Int {
        // Get all year-month subcollections by listing documents in completions collection
        let completionsRef = firestore.collection("users")
            .document(userId)
            .collection("completions")
        
        // List all year-month documents
        let yearMonthDocs = try await completionsRef.getDocuments()
        var totalPulled = 0
        
        for yearMonthDoc in yearMonthDocs.documents {
            let yearMonth = yearMonthDoc.documentID
            
            let completionsSubRef = completionsRef
                .document(yearMonth)
                .collection("completions")
            
            let snapshot = try? await completionsSubRef.getDocuments()
            guard let snapshot = snapshot else { continue }
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Merge completion into SwiftData
                do {
                    try await mergeCompletionFromFirestore(data: data, userId: userId)
                    totalPulled += 1
                } catch {
                    logger.error("❌ Failed to merge completion: \(error.localizedDescription)")
                    // Continue with next completion even if this one fails
                }
            }
        }
        
        if totalPulled > 0 {
            logger.info("✅ Pulled \(totalPulled) completions from all months")
        }
        
        return totalPulled
    }
    
    /// Pull awards updated since the given timestamp
    private func pullAwards(userId: String, since: Date) async throws -> Int {
        let awardsRef = firestore.collection("users")
            .document(userId)
            .collection("daily_awards")
        
        let snapshot = try await awardsRef.getDocuments()
        var pulledCount = 0
        
        for document in snapshot.documents {
            let data = document.data()
            
            // Check if award was created since last sync
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            if createdAt > since {
                // Merge award into SwiftData (idempotent - won't create duplicates)
                do {
                    try await mergeAwardFromFirestore(data: data, userId: userId)
                    pulledCount += 1
                } catch {
                    logger.error("❌ Failed to merge award: \(error.localizedDescription)")
                }
            }
        }
        
        if pulledCount > 0 {
            logger.info("✅ Pulled \(pulledCount) awards")
        }
        
        return pulledCount
    }
    
    /// Pull ALL awards (ignore timestamp filter)
    /// This is used when timestamp-filtered pull returns 0 results
    private func pullAllAwards(userId: String) async throws -> Int {
        let awardsRef = firestore.collection("users")
            .document(userId)
            .collection("daily_awards")
        
        let snapshot = try await awardsRef.getDocuments()
        var pulledCount = 0
        
        for document in snapshot.documents {
            let data = document.data()
            
            // Merge award into SwiftData (idempotent - won't create duplicates)
            do {
                try await mergeAwardFromFirestore(data: data, userId: userId)
                pulledCount += 1
            } catch {
                logger.error("❌ Failed to merge award: \(error.localizedDescription)")
            }
        }
        
        if pulledCount > 0 {
            logger.info("✅ Pulled \(pulledCount) awards from all time")
        }
        
        return pulledCount
    }
    
    /// Pull events from recent months
    private func pullEvents(userId: String, recentMonths: Int) async throws -> Int {
        let yearMonths = getRecentYearMonths(count: recentMonths)
        var pulledCount = 0
        
        for yearMonth in yearMonths {
            let eventsRef = firestore.collection("users")
                .document(userId)
                .collection("events")
                .document(yearMonth)
                .collection("events")
            
            let snapshot = try? await eventsRef.getDocuments()
            guard let snapshot = snapshot else { continue }
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Merge event into SwiftData (idempotent via operationId)
                try await mergeEventFromFirestore(data: data)
                pulledCount += 1
            }
        }
        
        return pulledCount
    }
    
    // MARK: - Merge Helpers
    
    /// Merge habit from Firestore into SwiftData
    /// ✅ BUG FIX: Changed from silent `try?` to proper error handling with logging
    private func mergeHabitFromFirestore(data: [String: Any], habitId: UUID, userId: String) async {
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            // Check if habit exists
            let predicate = #Predicate<HabitData> { habit in
                habit.id == habitId && habit.userId == userId
            }
            let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
            
            if let existingHabit = try? modelContext.fetch(descriptor).first {
                // Update existing habit (last-write-wins based on updatedAt)
                let remoteUpdatedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue() ?? Date()
                let localUpdatedAt = existingHabit.updatedAt
                
                if remoteUpdatedAt > localUpdatedAt {
                    // Remote is newer, update local
                    Self.updateHabitData(from: data, to: existingHabit)
                    existingHabit.updatedAt = remoteUpdatedAt
                    do {
                        try modelContext.save()
                        logger.info("✅ SyncEngine: Updated habit \(habitId.uuidString.prefix(8))... from Firestore")
                    } catch {
                        logger.error("❌ SyncEngine: Failed to save updated habit \(habitId.uuidString.prefix(8))...: \(error.localizedDescription)")
                        logger.error("   Error details: \(error)")
                        // Don't throw - continue with other habits even if one fails
                    }
                }
            } else {
                // ✅ CRITICAL BUG FIX: Check if habit was recently deleted before recreating
                // If a habit was deleted but still exists in Firestore (deletion didn't complete),
                // we should NOT recreate it on sync - this causes deleted habits to reappear
                if Self.isHabitDeleted(habitId) {
                    logger.info("⏭️ SyncEngine: Skipping creation of deleted habit \(habitId.uuidString.prefix(8))... from Firestore")
                    return
                }
                
                // Check if there are any completion records for this habit that would indicate
                // it was recently active. If no completion records exist, the habit might be orphaned
                // and we should skip it to prevent resurrection.
                let completionPredicate = #Predicate<CompletionRecord> { record in
                    record.habitId == habitId && record.userId == userId
                }
                let completionDescriptor = FetchDescriptor<CompletionRecord>(predicate: completionPredicate)
                let existingCompletions = (try? modelContext.fetch(completionDescriptor)) ?? []
                
                // ✅ FIX: Only create habit if it has completion records OR if it's explicitly in Firestore
                // If habit exists in Firestore habits collection, it's legitimate (not orphaned)
                // But if it was deleted and Firestore deletion failed, we don't want to recreate it
                // 
                // For now, we'll create it if it exists in Firestore (trust Firestore as source of truth)
                // But log a warning if there are no completion records (might be orphaned)
                if existingCompletions.isEmpty {
                    logger.warning("⚠️ SyncEngine: Creating habit \(habitId.uuidString.prefix(8))... from Firestore but no local completion records found - might be orphaned")
                }
                
                // Create new habit
                guard let habitData = Self.createHabitData(from: data, habitId: habitId, userId: userId) else {
                    logger.warning("⚠️ SyncEngine: Failed to create HabitData from Firestore data for habit \(habitId.uuidString.prefix(8))...")
                    return
                }
                modelContext.insert(habitData)
                do {
                    try modelContext.save()
                    logger.info("✅ SyncEngine: Created habit \(habitId.uuidString.prefix(8))... from Firestore")
                } catch {
                    logger.error("❌ SyncEngine: Failed to save new habit \(habitId.uuidString.prefix(8))...: \(error.localizedDescription)")
                    logger.error("   Error details: \(error)")
                    // Don't throw - continue with other habits even if one fails
                    // This allows the sync to continue and pull remaining habits
                }
            }
        }
    }
    
    /// Merge completion from Firestore into SwiftData
    private func mergeCompletionFromFirestore(data: [String: Any], userId: String) async throws {
        // Parse required fields
        guard let habitIdString = data["habitId"] as? String,
              let habitId = UUID(uuidString: habitIdString),
              let dateKey = data["dateKey"] as? String else {
            logger.error("❌ SyncEngine: Failed to parse completion data from Firestore")
            return
        }
        
        // ✅ CRITICAL BUG FIX: Skip if this habit was deleted - prevents resurrection
        if Self.isHabitDeleted(habitId) {
            logger.info("⏭️ SyncEngine: Skipping completion for deleted habit \(habitId.uuidString.prefix(8))...")
            return
        }
        
        // ✅ CRITICAL BUG FIX: Check if habit exists locally - if not, skip (don't create orphaned completions)
        let habitExists = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<HabitData> { habit in
                habit.id == habitId && habit.userId == userId
            }
            let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
            return (try? modelContext.fetch(descriptor).first) != nil
        }
        
        guard habitExists else {
            logger.info("⏭️ SyncEngine: Skipping completion for non-existent habit \(habitId.uuidString.prefix(8))...")
            return
        }
        
        // If there are pending local events for this habit/date, skip remote overwrite
        if await hasPendingLocalEvents(habitId: habitId, dateKey: dateKey) {
            logger.info("⏭️ SyncEngine: Skipping completion for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) - pending local events")
            return
        }
        
        let remoteIsCompleted = data["isCompleted"] as? Bool ?? false
        let remoteProgress = data["progress"] as? Int ?? 0
        let remoteCreatedAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let remoteUpdatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        
        // ✅ BUG 3 FIX: Guard against invalid timestamps (e.g., Date.distantPast)
        let remoteTimestamp: Date
        if let updated = remoteUpdatedAt, Calendar.current.component(.year, from: updated) > 1900 {
            remoteTimestamp = updated
        } else if let created = remoteCreatedAt, Calendar.current.component(.year, from: created) > 1900 {
            remoteTimestamp = created
        } else {
            // Invalid remote timestamp - treat as very old so local wins, unless local is also invalid
            remoteTimestamp = Date(timeIntervalSince1970: 0) // Jan 1, 1970
            logger.warning("⚠️ SyncEngine: Invalid remote timestamp for habit \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) - using fallback date")
        }
        
        // Merge into SwiftData on MainActor
        try await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            // Check if completion exists (using deterministic ID)
            let uniqueKey = "\(userId)#\(habitId.uuidString)#\(dateKey)"
            
            let predicate = #Predicate<CompletionRecord> { record in
                record.userIdHabitIdDateKey == uniqueKey
            }
            let descriptor = FetchDescriptor<CompletionRecord>(predicate: predicate)
            
            do {
                if let existingRecord = try modelContext.fetch(descriptor).first {
                    let localTimestamp = existingRecord.updatedAt ?? existingRecord.createdAt
                    
                    // ✅ BUG 2 FIX: Compare timestamps correctly - handle equal timestamps
                    if remoteTimestamp > localTimestamp {
                        // Remote is newer, update local
                        existingRecord.isCompleted = remoteIsCompleted
                        existingRecord.progress = remoteProgress
                        if let createdAt = remoteCreatedAt, Calendar.current.component(.year, from: createdAt) > 1900 {
                            existingRecord.createdAt = createdAt
                        }
                        existingRecord.updatedAt = remoteTimestamp
                        
                        try modelContext.save()
                        logger.info("✅ SyncEngine: Updated completion for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) isCompleted=\(remoteIsCompleted) progress=\(remoteProgress)")
                    } else if remoteTimestamp == localTimestamp {
                        // Timestamps equal - check if values differ
                        if existingRecord.isCompleted != remoteIsCompleted || existingRecord.progress != remoteProgress {
                            // Values differ, update to remote (resolve conflict by preferring remote)
                            existingRecord.isCompleted = remoteIsCompleted
                            existingRecord.progress = remoteProgress
                            try modelContext.save()
                            logger.info("✅ SyncEngine: Updated completion (same timestamp, different values) for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) isCompleted=\(remoteIsCompleted) progress=\(remoteProgress)")
                        } else {
                            logger.info("⏭️ SyncEngine: Skipping completion for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) - already in sync")
                        }
                    } else {
                        logger.info("⏭️ SyncEngine: Skipping completion for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) - local is newer (local: \(localTimestamp), remote: \(remoteTimestamp))")
                    }
                } else {
                    // Create new completion record
                    guard let date = DateUtils.date(from: dateKey) else {
                        logger.error("❌ SyncEngine: Failed to parse dateKey: '\(dateKey)'")
                        throw NSError(domain: "SyncEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid dateKey format"])
                    }
                    
                    let newRecord = CompletionRecord(
                        userId: userId,
                        habitId: habitId,
                        date: date,
                        dateKey: dateKey,
                        isCompleted: remoteIsCompleted,
                        progress: remoteProgress
                    )
                    
                    // ✅ BUG 3 FIX: Only set createdAt if it's valid
                    if let createdAt = remoteCreatedAt, Calendar.current.component(.year, from: createdAt) > 1900 {
                        newRecord.createdAt = createdAt
                    }
                    newRecord.updatedAt = remoteTimestamp
                    
                    modelContext.insert(newRecord)
                    try modelContext.save()
                    logger.info("✅ SyncEngine: Created completion for \(habitId.uuidString.prefix(8))... dateKey=\(dateKey) isCompleted=\(remoteIsCompleted) progress=\(remoteProgress)")
                }
            } catch {
                logger.error("❌ SyncEngine: Failed to merge completion: \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func hasPendingLocalEvents(habitId: UUID, dateKey: String) async -> Bool {
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<ProgressEvent> { event in
                event.habitId == habitId &&
                event.dateKey == dateKey &&
                event.synced == false &&
                event.deletedAt == nil
            }
            let descriptor = FetchDescriptor<ProgressEvent>(predicate: predicate)
            let events = try? modelContext.fetch(descriptor)
            return (events?.isEmpty == false)
        }
    }
    
    /// Merge award from Firestore into SwiftData (idempotent)
    /// CRITICAL: When importing a remote award, we must also sync XP to prevent desync across devices
    private func mergeAwardFromFirestore(data: [String: Any], userId: String) async throws {
        let dateKey = data["dateKey"] as? String
        guard let dateKey = dateKey else {
            return
        }
        
        let userIdDateKey = data["userIdDateKey"] as? String ?? "\(userId)#\(dateKey)"
        let xpGranted = data["xpGranted"] as? Int ?? 50
        
        // Check if award already exists locally (idempotent check)
        let awardExists = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<DailyAward> { award in
                award.userIdDateKey == userIdDateKey
            }
            let descriptor = FetchDescriptor<DailyAward>(predicate: predicate)
            return (try? modelContext.fetch(descriptor).first) != nil
        }
        
        // If award already exists locally, skip (idempotent)
        guard !awardExists else {
            logger.info("⏭️ Award already exists locally for \(dateKey), skipping import")
            return
        }
        
        // ✅ FIX: Validate BEFORE importing to prevent invalid awards from being imported
        // Parse dateKey to Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        guard let date = dateFormatter.date(from: dateKey) else {
            logger.warning("⚠️ Invalid dateKey format in award from Firestore: \(dateKey) - skipping import")
            // Delete invalid award from Firestore
            await deleteInvalidAwardFromFirestore(dateKey: dateKey, userId: userId)
            return
        }
        
        // Get scheduled habits for this date
        guard let scheduledHabits = try? await HabitStore.shared.scheduledHabits(for: date) else {
            logger.warning("⚠️ Failed to load scheduled habits for validation - skipping award import for \(dateKey)")
            return
        }
        
        // If no habits were scheduled, award should not exist
        if scheduledHabits.isEmpty {
            logger.warning("⚠️ INVALID AWARD: No habits scheduled for \(dateKey) - skipping import and deleting from Firestore")
            await deleteInvalidAwardFromFirestore(dateKey: dateKey, userId: userId)
            return
        }
        
        // Check completion records for this date
        let scheduledHabitIds: Set<UUID> = Set(scheduledHabits.map { $0.id })
        let (allCompleted, missingHabits): (Bool, [String]) = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            let completionPredicate = #Predicate<CompletionRecord> { record in
                record.userId == userId && record.dateKey == dateKey && record.isCompleted == true
            }
            let completionDescriptor = FetchDescriptor<CompletionRecord>(predicate: completionPredicate)
            let completionRecords = (try? modelContext.fetch(completionDescriptor)) ?? []
            let completedIds = Set(completionRecords.map(\.habitId))
            
            // Check if all scheduled habits were completed
            let missingHabitIds = scheduledHabitIds.subtracting(completedIds)
            let missingHabits = scheduledHabits
                .filter { missingHabitIds.contains($0.id) }
                .map(\.name)
            
            return (missingHabitIds.isEmpty, missingHabits)
        }
        
        // If not all habits completed, skip import and delete from Firestore
        if !allCompleted {
            logger.warning("⚠️ INVALID AWARD: Not all habits completed for \(dateKey) - skipping import and deleting from Firestore")
            logger.warning("   Scheduled: \(scheduledHabits.count), Completed: \(scheduledHabitIds.count - missingHabits.count)")
            logger.warning("   Missing habits: \(missingHabits.joined(separator: ", "))")
            logger.info("🔄 SYNC: Deleting invalid award from Firestore to prevent re-import...")
            await deleteInvalidAwardFromFirestore(dateKey: dateKey, userId: userId)
            logger.info("✅ SYNC: Invalid award prevented from being imported - XP integrity maintained")
            return
        }
        
        // ✅ VALIDATION PASSED: Import the award record
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            let award = DailyAward(
                userId: userId,
                dateKey: dateKey,
                xpGranted: xpGranted,
                allHabitsCompleted: data["allHabitsCompleted"] as? Bool ?? true
            )
            
            if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
                award.createdAt = createdAt
            }
            
            modelContext.insert(award)
            try? modelContext.save()
            logger.info("✅ Imported DailyAward for \(dateKey) (\(xpGranted) XP) - validated: all \(scheduledHabits.count) habits completed")
        }
        
        // CRITICAL: Sync XP from Firestore to ensure consistency across devices
        // The XP state stream should handle this, but we explicitly sync here to ensure
        // immediate consistency when importing remote awards
        await syncXPStateFromFirestore(userId: userId)
    }
    
    /// Delete an invalid DailyAward from Firestore
    /// This prevents invalid awards from being re-imported on future syncs
    private func deleteInvalidAwardFromFirestore(dateKey: String, userId: String) async {
        let userIdDateKey = "\(userId)#\(dateKey)"
        let awardRef = firestore.collection("users")
            .document(userId)
            .collection("daily_awards")
            .document(userIdDateKey)
        
        do {
            try await awardRef.delete()
            logger.info("✅ Deleted invalid DailyAward from Firestore: \(dateKey)")
        } catch {
            logger.warning("⚠️ Failed to delete invalid DailyAward from Firestore: \(error.localizedDescription)")
            // Don't throw - this is cleanup, not critical
        }
    }
    
    /// Validate an imported award to check if it's valid (non-blocking)
    /// This logs warnings if invalid awards are detected but doesn't block sync
    /// The DailyAwardIntegrityService can be used to clean up invalid awards later
    private func validateImportedAward(dateKey: String, userId: String) async {
        // Parse dateKey to Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        guard let date = dateFormatter.date(from: dateKey) else {
            logger.warning("⚠️ Invalid dateKey format in imported award: \(dateKey)")
            return
        }
        
        // Get scheduled habits for this date
        guard let scheduledHabits = try? await HabitStore.shared.scheduledHabits(for: date) else {
            logger.warning("⚠️ Failed to load scheduled habits for validation of imported award: \(dateKey)")
            return
        }
        
        // If no habits were scheduled, award should not exist
        if scheduledHabits.isEmpty {
            logger.warning("⚠️ INVALID AWARD IMPORTED: No habits scheduled for \(dateKey) - award should not exist")
            return
        }
        
        // Check completion records for this date
        let scheduledHabitIds: Set<UUID> = Set(scheduledHabits.map { $0.id })
        
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            let completionPredicate = #Predicate<CompletionRecord> { record in
                record.userId == userId && record.dateKey == dateKey && record.isCompleted == true
            }
            let completionDescriptor = FetchDescriptor<CompletionRecord>(predicate: completionPredicate)
            let completionRecords = (try? modelContext.fetch(completionDescriptor)) ?? []
            let completedIds = Set(completionRecords.map(\.habitId))
            
            // Check if all scheduled habits were completed
            let missingHabitIds = scheduledHabitIds.subtracting(completedIds)
            
            if !missingHabitIds.isEmpty {
                let missingHabits = scheduledHabits
                    .filter { missingHabitIds.contains($0.id) }
                    .map(\.name)
                
                logger.warning("⚠️ INVALID AWARD IMPORTED: Not all habits completed for \(dateKey)")
                logger.warning("   Scheduled: \(scheduledHabits.count), Completed: \(completedIds.count)")
                logger.warning("   Missing habits: \(missingHabits.joined(separator: ", "))")
                logger.warning("   Use DailyAwardIntegrityService to clean up invalid awards")
            } else {
                logger.info("✅ Imported award for \(dateKey) is valid (all \(scheduledHabits.count) habits completed)")
            }
        }
    }
    
    /// Sync XP state from Firestore's xp/state document
    /// This ensures XP stays in sync when importing remote awards
    private func syncXPStateFromFirestore(userId: String) async {
        // Fetch current XP state directly from xp/state (single source of truth)
        let xpStateRef = firestore.collection("users")
            .document(userId)
            .collection("xp")
            .document("state")
        
        let xpStateSnapshot = try? await xpStateRef.getDocument()
        let xpStateData = xpStateSnapshot?.data()
        let xpStateTotalXP = xpStateData?["totalXP"] as? Int
        
        guard let remoteTotalXP = xpStateTotalXP else {
            logger.info("ℹ️ No remote XP state found, skipping sync")
            return
        }
        
        // Refresh XP state from repository (which reads from xp/state stream)
        await DailyAwardService.shared.refreshXPState()
        
        // Log sync status
        await MainActor.run {
            let localTotalXP = DailyAwardService.shared.getTotalXP()
            
            if remoteTotalXP != localTotalXP {
                logger.info("🔄 XP sync: Local=\(localTotalXP), Remote=\(remoteTotalXP) (xp/state)")
                logger.info("ℹ️ XP state stream should update DailyAwardService automatically")
            } else {
                logger.info("✅ XP already in sync: \(localTotalXP)")
            }
        }
    }
    
    /// Merge event from Firestore into SwiftData (idempotent via operationId)
    private func mergeEventFromFirestore(data: [String: Any]) async throws {
        await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            
            guard let operationId = data["operationId"] as? String else {
                return
            }
            
            // Check if event exists (idempotent check via operationId)
            let predicate = #Predicate<ProgressEvent> { event in
                event.operationId == operationId
            }
            let descriptor = FetchDescriptor<ProgressEvent>(predicate: predicate)
            
            if (try? modelContext.fetch(descriptor).first) == nil {
                // Create new event from Firestore data
                guard let event = ProgressEvent.fromFirestore(data) else {
                    return
                }
                
                modelContext.insert(event)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get recent year-month keys (e.g., ["2025-11", "2025-10", "2025-09"])
    private func getRecentYearMonths(count: Int) -> [String] {
        var yearMonths: [String] = []
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.timeZone = TimeZone.current
        
        for i in 0..<count {
            guard let date = calendar.date(byAdding: .month, value: -i, to: Date()) else {
                continue
            }
            yearMonths.append(dateFormatter.string(from: date))
        }
        
        return yearMonths
    }
    
    /// Get last sync timestamp for user (stored in UserDefaults)
    
    private func getLastSyncTimestamp(userId: String) -> Date? {
        let key = "lastSyncTimestamp_\(userId)"
        return UserDefaults.standard.object(forKey: key) as? Date
    }
    
    /// Set last sync timestamp for user (stored in UserDefaults)
    private func setLastSyncTimestamp(userId: String, timestamp: Date) {
        let key = "lastSyncTimestamp_\(userId)"
        UserDefaults.standard.set(timestamp, forKey: key)
    }
    
    /// Update HabitData from Firestore data
    @MainActor
    private static func updateHabitData(from data: [String: Any], to habitData: HabitData) {
        if let name = data["name"] as? String {
            habitData.name = name
        }
        if let description = data["description"] as? String {
            habitData.habitDescription = description
        }
        if let icon = data["icon"] as? String {
            habitData.icon = icon
        }
        if let colorHex = data["color"] as? String {
            habitData.color = Color(hex: colorHex)
        }
        if let habitType = data["habitType"] as? String {
            habitData.habitType = habitType
        }
        if let schedule = data["schedule"] as? String {
            habitData.schedule = schedule
        }
        if let goal = data["goal"] as? String {
            habitData.goal = goal
        }
        if let baseline = data["baseline"] as? Int {
            habitData.baseline = baseline
        }
        if let target = data["target"] as? Int {
            habitData.target = target
        }
    }
    
    /// Create HabitData from Firestore data
    @MainActor
    private static func createHabitData(from data: [String: Any], habitId: UUID, userId: String) -> HabitData? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let icon = data["icon"] as? String,
              let colorHex = data["color"] as? String,
              let habitType = data["habitType"] as? String,
              let schedule = data["schedule"] as? String,
              let goal = data["goal"] as? String,
              let startDate = (data["startDate"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        let baseline = data["baseline"] as? Int ?? 0
        let target = data["target"] as? Int ?? 1
        
        let habitData = HabitData(
            id: habitId,
            userId: userId,
            name: name,
            habitDescription: description,
            icon: icon,
            color: Color(hex: colorHex),
            habitType: HabitType(rawValue: habitType) ?? .formation,
            schedule: schedule,
            goal: goal,
            reminder: data["reminder"] as? String ?? "",
            startDate: startDate,
            endDate: endDate,
            baseline: baseline,
            target: target
        )
        
        if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
            habitData.createdAt = createdAt
        }
        if let updatedAt = (data["lastSyncedAt"] as? Timestamp)?.dateValue() {
            habitData.updatedAt = updatedAt
        }
        
        return habitData
    }
    
    /// ✅ BUG FIX: Reconcile deletions bidirectionally:
    /// 1. Delete from Firestore: habits that exist remotely but not locally (deleted on this device)
    /// 2. Delete from Local: habits that exist locally but not remotely (deleted on another device)
    /// Call this after pullHabits() completes to clean up orphaned habits
    private func reconcileDeletedHabits(userId: String, remoteHabitIds: Set<UUID>) async {
        logger.info("🔄 RECONCILE: Starting with \(remoteHabitIds.count) remote habit IDs")
        
        // Get local habit IDs
        let localHabitIds: Set<UUID> = await MainActor.run {
            let modelContext = SwiftDataContainer.shared.modelContext
            let predicate = #Predicate<HabitData> { habit in
                habit.userId == userId
            }
            let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
            let localHabits = (try? modelContext.fetch(descriptor)) ?? []
            return Set(localHabits.map { $0.id })
        }
        
        logger.info("🔄 RECONCILE: Found \(localHabitIds.count) local habit IDs")
        logger.info("🔄 RECONCILE: Remote IDs: \(remoteHabitIds.map { String($0.uuidString.prefix(8)) }.sorted())")
        logger.info("🔄 RECONCILE: Local IDs: \(localHabitIds.map { String($0.uuidString.prefix(8)) }.sorted())")
        
        // DIRECTION 1: Delete from Firestore habits that were deleted locally
        // (exist in Firestore but not locally)
        let deletedLocallyButInFirestore = remoteHabitIds.subtracting(localHabitIds)
        
        if !deletedLocallyButInFirestore.isEmpty {
            logger.info("🗑️ SyncEngine: Found \(deletedLocallyButInFirestore.count) habits deleted locally but still in Firestore - cleaning up Firestore")
            
            for habitId in deletedLocallyButInFirestore {
                // ✅ CRITICAL BUG FIX: Mark as deleted to prevent resurrection
                Self.markHabitAsDeleted(habitId)
                
                do {
                    let docRef = firestore.collection("users")
                        .document(userId)
                        .collection("habits")
                        .document(habitId.uuidString)
                    
                    try await docRef.delete()
                    logger.info("✅ SyncEngine: Deleted orphaned habit \(habitId.uuidString.prefix(8))... from Firestore")
                    
                    // Also delete orphaned completion records
                    await FirebaseBackupService.shared.deleteCompletionRecordsForHabitAwait(habitId: habitId)
                    
                    // Clear the deleted marker after cleanup is complete
                    Self.clearDeletedHabit(habitId)
                } catch {
                    logger.error("❌ SyncEngine: Failed to delete orphaned habit \(habitId.uuidString.prefix(8))... from Firestore: \(error.localizedDescription)")
                    // Keep marker if deletion failed so it can be retried
                }
            }
        }
        
        // DIRECTION 2: Delete locally habits that were deleted remotely
        // (exist locally but not in Firestore)
        let deletedRemotelyButLocal = localHabitIds.subtracting(remoteHabitIds)
        
        if !deletedRemotelyButLocal.isEmpty {
            logger.info("🗑️ SyncEngine: Found \(deletedRemotelyButLocal.count) habits deleted remotely but still local - cleaning up local SwiftData")
            
            // ✅ CRITICAL BUG FIX: Mark as deleted to prevent resurrection before deleting
            for habitId in deletedRemotelyButLocal {
                Self.markHabitAsDeleted(habitId)
            }
            
            await MainActor.run {
                let modelContext = SwiftDataContainer.shared.modelContext
                
                for habitId in deletedRemotelyButLocal {
                    // Find and delete the local habit
                    let predicate = #Predicate<HabitData> { habit in
                        habit.id == habitId && habit.userId == userId
                    }
                    let descriptor = FetchDescriptor<HabitData>(predicate: predicate)
                    
                    if let habitToDelete = try? modelContext.fetch(descriptor).first {
                        logger.info("🗑️ SyncEngine: Deleting locally orphaned habit '\(habitToDelete.name)' (\(habitId.uuidString.prefix(8))...)")
                        modelContext.delete(habitToDelete)
                    }
                }
                
                do {
                    try modelContext.save()
                    logger.info("✅ SyncEngine: Deleted \(deletedRemotelyButLocal.count) locally orphaned habits from SwiftData")
                } catch {
                    logger.error("❌ SyncEngine: Failed to save after deleting local orphaned habits: \(error.localizedDescription)")
                }
            }
            
            // After deleting locally orphaned habits, also delete their completion records from Firestore
            for habitId in deletedRemotelyButLocal {
                await FirebaseBackupService.shared.deleteCompletionRecordsForHabitAwait(habitId: habitId)
                // Clear the deleted marker after cleanup is complete
                Self.clearDeletedHabit(habitId)
            }
            
            // ✅ CRITICAL FIX: Reload HabitRepository's in-memory list BEFORE any save operations
            // This prevents stale data from re-creating deleted habits
            await HabitRepository.shared.loadHabits(force: true)
            logger.info("✅ SyncEngine: Reloaded HabitRepository after deleting \(deletedRemotelyButLocal.count) local habits")
            
            // Clear cache and notify UI to reload
            await habitStore.clearStorageCache()
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SyncPullCompleted"),
                    object: nil,
                    userInfo: ["habitsDeleted": deletedRemotelyButLocal.count]
                )
            }
        }
    }
}

// MARK: - Pull Sync Summary

/// Summary of what was pulled from remote
struct PullSyncSummary: Sendable, CustomStringConvertible {
    var habitsPulled: Int = 0
    var completionsPulled: Int = 0
    var awardsPulled: Int = 0
    var eventsPulled: Int = 0
    var errors: [String] = []
    
    var totalPulled: Int {
        habitsPulled + completionsPulled + awardsPulled + eventsPulled
    }
    
    var description: String {
        "habits=\(habitsPulled), completions=\(completionsPulled), awards=\(awardsPulled), events=\(eventsPulled), errors=\(errors.count)"
    }
}

// MARK: - Sync Errors

enum SyncError: Error, LocalizedError {
    case fetchFailed(Error)
    case firestoreWriteFailed(Error)
    case invalidUserId
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch unsynced events: \(error.localizedDescription)"
        case .firestoreWriteFailed(let error):
            return "Failed to write to Firestore: \(error.localizedDescription)"
        case .invalidUserId:
            return "Invalid user ID for sync"
        }
    }
}

