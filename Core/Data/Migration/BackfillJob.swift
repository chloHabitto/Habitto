import Foundation
import FirebaseFirestore
import OSLog

// MARK: - Migration State Store Protocol

/// Protocol for storing and retrieving migration state
protocol MigrationStateStore {
    func load(for userId: String) async throws -> MigrationStateData
    func save(_ state: MigrationStateData, for userId: String) async throws
    func updateProgress(for userId: String, itemsProcessed: Int, lastItemKey: String?, status: MigrationStatusData?, errorMessage: String?) async throws
}

/// Firestore implementation of migration state storage
final class FirestoreMigrationStateStore: MigrationStateStore {
    private let firestore = Firestore.firestore()
    private let logger = Logger(subsystem: "com.habitto.app", category: "FirestoreMigrationStateStore")
    
    func load(for userId: String) async throws -> MigrationStateData {
        let docRef = firestore.collection("users").document(userId).collection("meta").document("migration")
        let document = try await docRef.getDocument()
        
        if document.exists, let data = document.data() {
            return try MigrationStateData(from: data)
        } else {
            return MigrationStateData()
        }
    }
    
    func save(_ state: MigrationStateData, for userId: String) async throws {
        let docRef = firestore.collection("users").document(userId).collection("meta").document("migration")
        try await docRef.setData(state.toDictionary(), merge: true)
    }
    
    func updateProgress(for userId: String, itemsProcessed: Int, lastItemKey: String?, status: MigrationStatusData?, errorMessage: String?) async throws {
        let docRef = firestore.collection("users").document(userId).collection("meta").document("migration")
        
        var updateData: [String: Any] = [
            "migratedRecordsCount": itemsProcessed
        ]
        
        if let key = lastItemKey {
            updateData["lastItemKey"] = key
        }
        
        if let status = status {
            updateData["status"] = status.rawValue
        }
        
        if let error = errorMessage {
            updateData["error"] = error
        }
        
        try await docRef.updateData(updateData)
    }
}

// MARK: - Migration State Data Extensions

extension MigrationStateData {
    init(from data: [String: Any]) throws {
        self.status = MigrationStatusData(rawValue: data["status"] as? String ?? "") ?? .notStarted
        self.lastItemKey = data["lastItemKey"] as? String
        self.startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        self.finishedAt = (data["finishedAt"] as? Timestamp)?.dateValue()
        self.error = data["error"] as? String
        self.itemsProcessed = data["migratedRecordsCount"] as? Int ?? 0
        self.totalItems = data["totalItems"] as? Int
        self.version = data["version"] as? String ?? "1.0.0"
        self.metadata = data["metadata"] as? [String: String] ?? [:]
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "status": status.rawValue,
            "migratedRecordsCount": itemsProcessed,
            "version": version,
            "metadata": metadata
        ]
        
        if let lastKey = lastItemKey {
            dict["lastItemKey"] = lastKey
        }
        
        if let started = startedAt {
            dict["startedAt"] = Timestamp(date: started)
        }
        
        if let finished = finishedAt {
            dict["finishedAt"] = Timestamp(date: finished)
        }
        
        if let errorMsg = error {
            dict["error"] = errorMsg
        }
        
        if let total = totalItems {
            dict["totalItems"] = total
        }
        
        return dict
    }
}

// MARK: - Migration State Manager

/// Manages migration state for users
final class MigrationStateManager {
    private let stateStore: MigrationStateStore
    
    init(stateStore: MigrationStateStore = FirestoreMigrationStateStore()) {
        self.stateStore = stateStore
    }
    
    func load(for userId: String) async throws -> MigrationStateData {
        return try await stateStore.load(for: userId)
    }
    
    func save(_ state: MigrationStateData, for userId: String) async throws {
        try await stateStore.save(state, for: userId)
    }
    
    func updateProgress(for userId: String, itemsProcessed: Int, lastItemKey: String?, status: MigrationStatusData?, errorMessage: String?) async throws {
        if let firestoreStore = stateStore as? FirestoreMigrationStateStore {
            try await firestoreStore.updateProgress(for: userId, itemsProcessed: itemsProcessed, lastItemKey: lastItemKey, status: status, errorMessage: errorMessage)
        } else {
            // Fallback for other implementations
            var state = try await load(for: userId)
            state.itemsProcessed = itemsProcessed
            if let key = lastItemKey { state.lastItemKey = key }
            if let s = status { state.status = s }
            if let error = errorMessage { state.error = error }
            try await save(state, for: userId)
        }
    }
    
    func needsMigration(for userId: String) async throws -> Bool {
        let state = try await load(for: userId)
        return !state.isComplete && state.status != .running
    }
    
    func startMigration(for userId: String) async throws -> MigrationStateData {
        var state = try await load(for: userId)
        state.status = .running
        state.startedAt = Date()
        state.itemsProcessed = 0
        try await save(state, for: userId)
        return state
    }
    
    func completeMigration(for userId: String) async throws {
        var state = try await load(for: userId)
        state.status = .completed
        state.finishedAt = Date()
        try await save(state, for: userId)
    }
    
    func failMigration(for userId: String, error: Error) async throws {
        var state = try await load(for: userId)
        state.status = .failed
        state.error = error.localizedDescription
        state.finishedAt = Date()
        try await save(state, for: userId)
    }
}

// MARK: - Backfill Job

/// Orchestrates the migration of legacy data to Firestore
/// Supports idempotent, resumable migration with progress tracking
final class BackfillJob {
    
    // MARK: - Properties
    
    private let stateManager: MigrationStateManager
    private let legacyLoader: LegacyAggregateLoaderProtocol
    private let mapper: LegacyToFirestoreMapperProtocol
    private let firestoreWriter: FirestoreBatchWriter
    private let logger = Logger(subsystem: "com.habitto.app", category: "BackfillJob")
    
    // MARK: - Initialization
    
    init(
        stateManager: MigrationStateManager = MigrationStateManager(),
        legacyLoader: LegacyAggregateLoaderProtocol,
        mapper: LegacyToFirestoreMapperProtocol = LegacyToFirestoreMapper(),
        firestoreWriter: FirestoreBatchWriter = DefaultFirestoreBatchWriter()
    ) {
        self.stateManager = stateManager
        self.legacyLoader = legacyLoader
        self.mapper = mapper
        self.firestoreWriter = firestoreWriter
        
        logger.info("🔧 BackfillJob: Initialized with components")
    }
    
    /// Convenience initializer that creates a SwiftDataLoader on the main actor
    @MainActor
    static func createWithSwiftDataLoader(
        stateManager: MigrationStateManager = MigrationStateManager(),
        mapper: LegacyToFirestoreMapperProtocol = LegacyToFirestoreMapper(),
        firestoreWriter: FirestoreBatchWriter = DefaultFirestoreBatchWriter()
    ) -> BackfillJob {
        let swiftDataLoader = SwiftDataLoader()
        return BackfillJob(
            stateManager: stateManager,
            legacyLoader: swiftDataLoader,
            mapper: mapper,
            firestoreWriter: firestoreWriter
        )
    }
    
    // MARK: - Public Methods
    
    /// Run backfill migration if needed and enabled
    func runIfNeeded(for userId: String) async {
        // Check if backfill is enabled via feature flags
        guard MigrationFeatureFlags.backfillEnabled else {
            logger.info("🚫 BackfillJob: Backfill disabled via feature flags")
            return
        }
        
        // Check if user should be included in rollout
        guard MigrationFeatureFlags.shouldEnableBackfill(for: userId) else {
            logger.info("🚫 BackfillJob: User \(userId) not included in backfill rollout")
            return
        }
        
        // Check if migration is needed
        do {
            let needsMigration = try await stateManager.needsMigration(for: userId)
            guard needsMigration else {
                logger.info("✅ BackfillJob: User \(userId) already migrated or in progress")
                return
            }
        } catch {
            logger.error("❌ BackfillJob: Failed to check migration status for user \(userId): \(error.localizedDescription)")
            return
        }
        
        // Start migration
        await runMigration(for: userId)
    }
    
    /// Force run migration (ignores feature flags and rollout percentage)
    func forceRunMigration(for userId: String) async {
        logger.info("🚀 BackfillJob: Force running migration for user \(userId)")
        await runMigration(for: userId, force: true)
    }
    
    // MARK: - Private Methods
    
    private func runMigration(for userId: String, force: Bool = false) async {
        let startTime = Date()
        
        do {
            // Start migration state
            var state = try await stateManager.startMigration(for: userId)
            
            if MigrationFeatureFlags.debugMigration {
                logger.info("🚀 BackfillJob: Starting migration for user \(userId) - status: \(state.status.rawValue)")
            }
            
            // Load legacy data
            let legacyItems = try await loadLegacyData(for: userId, from: state.lastItemKey)
            
            if legacyItems.isEmpty {
                logger.info("📭 BackfillJob: No legacy data found for user \(userId)")
                try await stateManager.completeMigration(for: userId)
                return
            }
            
            // Update total items estimate
            state.totalItems = legacyItems.count
            try await stateManager.updateProgress(for: userId, itemsProcessed: state.itemsProcessed, lastItemKey: state.lastItemKey, status: nil, errorMessage: nil)
            
            logger.info("📊 BackfillJob: Found \(legacyItems.count) legacy items for user \(userId)")
            
            // Process items in batches
            try await processItemsInBatches(legacyItems, for: userId)
            
            // Complete migration
            try await stateManager.completeMigration(for: userId)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ BackfillJob: Successfully completed migration for user \(userId)")
            
            // Record success telemetry
            MigrationTelemetryService.shared.trackMigrationCompletion(userId: userId, itemsProcessed: state.itemsProcessed, duration: duration)
            
        } catch {
            logger.error("❌ BackfillJob: Migration failed for user \(userId): \(error.localizedDescription)")
            
            // Record failure
            try? await stateManager.failMigration(for: userId, error: error)
            
            // Record failure telemetry
            MigrationTelemetryService.shared.trackMigrationFailure(userId: userId, error: error, itemsProcessed: 0, lastItemKey: nil)
        }
    }
    
    private func loadLegacyData(for userId: String, from lastItemKey: String?) async throws -> [LegacyDataItem] {
        logger.debug("📥 BackfillJob: Loading legacy data for user \(userId) from key: \(lastItemKey ?? "start")")
        
        let items = try await legacyLoader.enumerate(from: lastItemKey)
        
        logger.debug("📥 BackfillJob: Loaded \(items.count) legacy items")
        return items
    }
    
    private func processItemsInBatches(_ items: [LegacyDataItem], for userId: String) async throws {
        let batchSize = MigrationFeatureFlags.migrationBatchSize
        let totalBatches = (items.count + batchSize - 1) / batchSize
        
        logger.info("📦 BackfillJob: Processing \(items.count) items in \(totalBatches) batches of \(batchSize)")
        
        for (batchIndex, batch) in items.chunked(into: batchSize).enumerated() {
            try await processBatch(batch, batchIndex: batchIndex + 1, totalBatches: totalBatches, for: userId)
        }
    }
    
    private func processBatch(_ batch: [LegacyDataItem], batchIndex: Int, totalBatches: Int, for userId: String) async throws {
        logger.debug("📦 BackfillJob: Processing batch \(batchIndex)/\(totalBatches) with \(batch.count) items")
        
        let batchStartTime = Date()
        
        do {
            // Map legacy items to Firestore writes
            let writes = try await mapper.mapItems(batch, for: userId)
            
            if writes.isEmpty {
                logger.debug("📦 BackfillJob: No writes needed for batch \(batchIndex)")
                return
            }
            
            // Execute batch write
            try await firestoreWriter.batchWrite(writes)
            
            // Update progress
            let lastItemKey = batch.last?.stableKey
            let currentProgress = batchIndex * MigrationFeatureFlags.migrationBatchSize
            try await stateManager.updateProgress(for: userId, itemsProcessed: currentProgress, lastItemKey: lastItemKey, status: nil, errorMessage: nil)
            
            let batchDuration = Date().timeIntervalSince(batchStartTime)
            MigrationTelemetryService.shared.trackMigrationBatch(batchNumber: batchIndex, batchSize: batch.count, success: true, duration: batchDuration)
            
            if MigrationFeatureFlags.debugMigration {
                logger.debug("✅ BackfillJob: Completed batch \(batchIndex)/\(totalBatches) - \(writes.count) writes")
            }
            
        } catch {
            let batchDuration = Date().timeIntervalSince(batchStartTime)
            MigrationTelemetryService.shared.trackMigrationBatch(batchNumber: batchIndex, batchSize: batch.count, success: false, duration: batchDuration, error: error)
            
            logger.error("❌ BackfillJob: Batch \(batchIndex) failed: \(error.localizedDescription)")
            
            // Retry logic if enabled
            if MigrationFeatureFlags.migrationRetryEnabled {
                logger.info("🔄 BackfillJob: Retrying batch \(batchIndex)")
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                try await processBatch(batch, batchIndex: batchIndex, totalBatches: totalBatches, for: userId)
            } else {
                throw error
            }
        }
    }
}


// MARK: - Legacy Data Item

/// Represents a single item of legacy data to be migrated
struct LegacyDataItem {
    let type: LegacyDataType
    let stableKey: String
    let data: [String: Any]
    let userId: String
    let createdAt: Date?
    let updatedAt: Date?
    
    init(
        type: LegacyDataType,
        stableKey: String,
        data: [String: Any],
        userId: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.type = type
        self.stableKey = stableKey
        self.data = data
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Legacy Data Type

enum LegacyDataType: String, CaseIterable {
    case habit = "habit"
    case completion = "completion"
    case xpState = "xp_state"
    case xpLedger = "xp_ledger"
    case streak = "streak"
    case goalVersion = "goal_version"
    case userSettings = "user_settings"
    
    var firestoreCollection: String {
        switch self {
        case .habit: return "habits"
        case .completion: return "completions"
        case .xpState: return "xp"
        case .xpLedger: return "xp/ledger"
        case .streak: return "streaks"
        case .goalVersion: return "goalVersions"
        case .userSettings: return "settings"
        }
    }
}


// MARK: - Legacy To Firestore Mapper Protocol

/// Protocol for mapping legacy data to Firestore document structures
protocol LegacyToFirestoreMapperProtocol {
    /// Map legacy data items to Firestore write operations
    func mapItems(_ items: [LegacyDataItem], for userId: String) async throws -> [FirestoreWriteOperation]
}

// MARK: - Firestore Write Operation

/// Represents a single Firestore write operation
struct FirestoreWriteOperation {
    let type: FirestoreWriteType
    let path: String
    let data: [String: Any]
    let merge: Bool
    
    init(type: FirestoreWriteType, path: String, data: [String: Any], merge: Bool = false) {
        self.type = type
        self.path = path
        self.data = data
        self.merge = merge
    }
}

enum FirestoreWriteType {
    case set
    case update
    case delete
}

// MARK: - Firestore Batch Writer Protocol

/// Protocol for executing batch writes to Firestore
protocol FirestoreBatchWriter {
    /// Execute a batch of write operations
    func batchWrite(_ operations: [FirestoreWriteOperation]) async throws
}

// MARK: - Default Implementations (Placeholders)


/// Default implementation of FirestoreBatchWriter
final class DefaultFirestoreBatchWriter: FirestoreBatchWriter {
    func batchWrite(_ operations: [FirestoreWriteOperation]) async throws {
        // TODO: Implement actual batch writing
        logger.info("💾 FirestoreBatchWriter: Executing \(operations.count) write operations")
    }
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "FirestoreBatchWriter")
}
