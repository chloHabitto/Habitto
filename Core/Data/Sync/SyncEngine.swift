import Foundation
import FirebaseFirestore
import SwiftData
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
    // MARK: - Singleton
    
    static let shared = SyncEngine()
    
    // MARK: - Properties
    
    private let firestore: Firestore
    private let habitStore: HabitStore
    private var isSyncing: Bool = false
    private let logger = Logger(subsystem: "com.habitto.app", category: "SyncEngine")
    
    // Background sync scheduler
    private var syncTask: Task<Void, Never>?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    private init() {
        self.firestore = Firestore.firestore()
        self.habitStore = HabitStore.shared
        logger.info("SyncEngine initialized")
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
        
        // Skip sync for guest users (no cloud sync)
        guard !CurrentUser.isGuestId(userId) else {
            logger.info("⏭️ Skipping sync for guest user")
            return
        }
        
        logger.info("🔄 Starting event sync for user: \(userId)")
        
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
        
        var syncedCount = 0
        var failedCount = 0
        
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
                try await self.syncEvents()
            } catch {
                self.logger.error("❌ Background sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start periodic background sync (every 5 minutes)
    func startPeriodicSync() {
        logger.info("🔄 Starting periodic sync (every \(self.syncInterval)s)")
        
        syncTask?.cancel()
        
        syncTask = Task {
            while !Task.isCancelled {
                do {
                    try await self.syncEvents()
                } catch {
                    self.logger.error("❌ Periodic sync failed: \(error.localizedDescription)")
                }
                
                // Wait for sync interval
                try? await Task.sleep(nanoseconds: UInt64(self.syncInterval * 1_000_000_000))
            }
        }
    }
    
    /// Stop periodic sync
    func stopPeriodicSync() {
        logger.info("⏹️ Stopping periodic sync")
        syncTask?.cancel()
        syncTask = nil
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

