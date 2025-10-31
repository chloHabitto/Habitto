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
        
        // Get model context
        let modelContext = await MainActor.run { SwiftDataContainer.shared.modelContext }
        
        // Fetch unsynced events
        let descriptor = ProgressEvent.unsyncedEvents()
        let unsyncedEvents: [ProgressEvent]
        do {
            unsyncedEvents = try modelContext.fetch(descriptor)
        } catch {
            logger.error("❌ Failed to fetch unsynced events: \(error.localizedDescription)")
            throw SyncError.fetchFailed(error)
        }
        
        guard !unsyncedEvents.isEmpty else {
            logger.info("✅ No unsynced events to sync")
            return
        }
        
        logger.info("📤 Found \(unsyncedEvents.count) unsynced events to sync")
        
        var syncedCount = 0
        var failedCount = 0
        
        // Sync events in batches to avoid overwhelming Firestore
        let batchSize = 50
        for batchStart in stride(from: 0, to: unsyncedEvents.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, unsyncedEvents.count)
            let batch = Array(unsyncedEvents[batchStart..<batchEnd])
            
            do {
                try await syncBatch(batch, userId: userId, modelContext: modelContext)
                syncedCount += batch.count
                logger.info("✅ Synced batch: \(batch.count) events (\(syncedCount)/\(unsyncedEvents.count))")
            } catch {
                failedCount += batch.count
                logger.error("❌ Failed to sync batch: \(error.localizedDescription)")
                // Continue with next batch even if this one failed
            }
        }
        
        logger.info("✅ Event sync completed: \(syncedCount) synced, \(failedCount) failed")
    }
    
    /// Sync a batch of events to Firestore
    private func syncBatch(
        _ events: [ProgressEvent],
        userId: String,
        modelContext: ModelContext
    ) async throws {
        // Use Firestore batch write for atomicity
        let batch = firestore.batch()
        var eventsToSync: [ProgressEvent] = []
        
        for event in events {
            // Generate yearMonth from dateKey (format: "yyyy-MM-dd" -> "yyyy-MM")
            let yearMonth = String(event.dateKey.prefix(7)) // "2025-10-31" -> "2025-10"
            
            // Firestore path: /users/{userId}/events/{yearMonth}/{eventId}
            let eventRef = firestore.collection("users")
                .document(userId)
                .collection("events")
                .document(yearMonth)
                .collection("events")
                .document(event.id)
            
            // Check if event already exists (idempotency check using operationId)
            let existingDoc = try? await eventRef.getDocument()
            if let existingData = existingDoc?.data(),
               let existingOperationId = existingData["operationId"] as? String,
               existingOperationId == event.operationId {
                // Event already synced, mark as synced locally
                logger.info("⏭️ Event \(event.id.prefix(20))... already synced (operationId match), marking as synced")
                event.markAsSynced()
                continue
            }
            
            // Convert event to Firestore dictionary
            var eventData = event.toFirestore()
            
            // Add operationId for idempotency
            eventData["operationId"] = event.operationId
            
            // Write to Firestore (setData with merge for idempotency)
            batch.setData(eventData, forDocument: eventRef, merge: true)
            eventsToSync.append(event)
        }
        
        // Only commit if there are events to sync
        guard !eventsToSync.isEmpty else {
            // All events were already synced, just save the context
            try modelContext.save()
            return
        }
        
        // Commit batch
        try await batch.commit()
        
        // Mark only synced events as synced locally
        for event in eventsToSync {
            event.markAsSynced()
        }
        
        // Save model context
        try modelContext.save()
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

