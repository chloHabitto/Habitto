import Foundation
import FirebaseFirestore
import OSLog

// MARK: - Migration State

/// Represents the current state of user data migration
struct MigrationStateData: Codable, Equatable {
    /// Migration status
    var status: MigrationStatusData
    
    /// Last processed item key (for resumable migration)
    var lastItemKey: String?
    
    /// When migration started
    var startedAt: Date?
    
    /// When migration completed
    var finishedAt: Date?
    
    /// Error message if migration failed
    var error: String?
    
    /// Number of items processed
    var itemsProcessed: Int
    
    /// Total number of items to process (estimated)
    var totalItems: Int?
    
    /// Migration version (for schema changes)
    var version: String
    
    /// Custom metadata for migration tracking
    var metadata: [String: String]
    
    init(
        status: MigrationStatusData = .notStarted,
        lastItemKey: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        error: String? = nil,
        itemsProcessed: Int = 0,
        totalItems: Int? = nil,
        version: String = "1.0.0",
        metadata: [String: String] = [:]
    ) {
        self.status = status
        self.lastItemKey = lastItemKey
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.error = error
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.version = version
        self.metadata = metadata
    }
    
    /// Check if migration is in progress
    var isInProgress: Bool {
        return status == .running || status == .paused
    }
    
    /// Check if migration is complete
    var isComplete: Bool {
        return status == .completed
    }
    
    /// Check if migration failed
    var isFailed: Bool {
        return status == .failed
    }
    
    /// Get progress percentage (0.0 to 1.0)
    var progress: Double {
        guard let total = totalItems, total > 0 else {
            return 0.0
        }
        return Double(itemsProcessed) / Double(total)
    }
}

// MARK: - Migration Status

enum MigrationStatusData: String, Codable, CaseIterable {
    case notStarted = "not_started"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        return self == .running || self == .paused
    }
    
    var isFinal: Bool {
        return self == .completed || self == .failed || self == .cancelled
    }
}

// MARK: - Migration State Store Protocol

/// Protocol for persisting migration state
protocol MigrationStateDataStore {
    /// Load migration state for a user
    func load(for userId: String) async throws -> MigrationStateData
    
    /// Save migration state for a user
    func save(_ state: MigrationStateData, for userId: String) async throws
    
    /// Clear migration state for a user
    func clear(for userId: String) async throws
    
    /// Check if migration state exists for a user
    func exists(for userId: String) async throws -> Bool
}

// MARK: - Firestore Migration State Store

/// Firestore-based implementation of migration state storage
final class FirestoreMigrationStateDataStore: MigrationStateDataStore {
    
    private let firestore = Firestore.firestore()
    private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationStateDataStore")
    
    /// Get the Firestore document reference for migration state
    private func migrationDocRef(for userId: String) -> DocumentReference {
        return firestore
            .collection("users")
            .document(userId)
            .collection("meta")
            .document("migration")
    }
    
    func load(for userId: String) async throws -> MigrationStateData {
        logger.debug("📥 MigrationStateDataStore: Loading migration state for user \(userId)")
        
        let docRef = migrationDocRef(for: userId)
        let document = try await docRef.getDocument()
        
        if document.exists {
            let state = try document.data(as: MigrationStateData.self)
            logger.debug("📥 MigrationStateDataStore: Loaded state - \(state.status.rawValue), items: \(state.itemsProcessed)")
            return state
        } else {
            logger.debug("📥 MigrationStateDataStore: No existing state found, returning default")
            return MigrationStateData()
        }
    }
    
    func save(_ state: MigrationStateData, for userId: String) async throws {
        logger.debug("💾 MigrationStateDataStore: Saving migration state for user \(userId) - \(state.status.rawValue), items: \(state.itemsProcessed)")
        
        let docRef = migrationDocRef(for: userId)
        try docRef.setData(from: state, merge: true)
        
        logger.debug("💾 MigrationStateDataStore: Successfully saved migration state")
    }
    
    func clear(for userId: String) async throws {
        logger.info("🗑️ MigrationStateDataStore: Clearing migration state for user \(userId)")
        
        let docRef = migrationDocRef(for: userId)
        try await docRef.delete()
        
        logger.info("🗑️ MigrationStateDataStore: Successfully cleared migration state")
    }
    
    func exists(for userId: String) async throws -> Bool {
        let docRef = migrationDocRef(for: userId)
        let document = try await docRef.getDocument()
        return document.exists
    }
}

// MARK: - Local Migration State Store

/// Local UserDefaults-based implementation for testing/fallback
final class LocalMigrationStateDataStore: MigrationStateDataStore {
    
    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.habitto.app", category: "LocalMigrationStateDataStore")
    
    private func key(for userId: String) -> String {
        return "migration_state_\(userId)"
    }
    
    func load(for userId: String) async throws -> MigrationStateData {
        logger.debug("📥 LocalMigrationStateDataStore: Loading migration state for user \(userId)")
        
        let key = self.key(for: userId)
        guard let data = userDefaults.data(forKey: key) else {
            logger.debug("📥 LocalMigrationStateDataStore: No existing state found, returning default")
            return MigrationStateData()
        }
        
        let state = try JSONDecoder().decode(MigrationStateData.self, from: data)
        logger.debug("📥 LocalMigrationStateDataStore: Loaded state - \(state.status.rawValue), items: \(state.itemsProcessed)")
        return state
    }
    
    func save(_ state: MigrationStateData, for userId: String) async throws {
        logger.debug("💾 LocalMigrationStateDataStore: Saving migration state for user \(userId) - \(state.status.rawValue), items: \(state.itemsProcessed)")
        
        let key = self.key(for: userId)
        let data = try JSONEncoder().encode(state)
        userDefaults.set(data, forKey: key)
        
        logger.debug("💾 LocalMigrationStateDataStore: Successfully saved migration state")
    }
    
    func clear(for userId: String) async throws {
        logger.info("🗑️ LocalMigrationStateDataStore: Clearing migration state for user \(userId)")
        
        let key = self.key(for: userId)
        userDefaults.removeObject(forKey: key)
        
        logger.info("🗑️ LocalMigrationStateDataStore: Successfully cleared migration state")
    }
    
    func exists(for userId: String) async throws -> Bool {
        let key = self.key(for: userId)
        return userDefaults.data(forKey: key) != nil
    }
}

// MARK: - Migration State Manager

/// High-level manager for migration state operations
final class MigrationStateDataManager {
    
    private let stateStore: MigrationStateDataStore
    private let logger = Logger(subsystem: "com.habitto.app", category: "MigrationStateDataManager")
    
    init(stateStore: MigrationStateDataStore = FirestoreMigrationStateDataStore()) {
        self.stateStore = stateStore
    }
    
    /// Get current migration state for a user
    func getCurrentState(for userId: String) async throws -> MigrationStateData {
        return try await stateStore.load(for: userId)
    }
    
    /// Start migration for a user
    func startMigration(for userId: String) async throws -> MigrationStateData {
        var state = try await stateStore.load(for: userId)
        
        // Don't restart if already in progress
        if state.isInProgress {
            logger.info("🔄 MigrationStateDataManager: Migration already in progress for user \(userId)")
            return state
        }
        
        // Reset state for new migration
        state.status = .running
        state.startedAt = Date()
        state.finishedAt = nil
        state.error = nil
        state.itemsProcessed = 0
        state.lastItemKey = nil
        state.metadata["started_by"] = "system"
        state.metadata["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        
        try await stateStore.save(state, for: userId)
        logger.info("🚀 MigrationStateDataManager: Started migration for user \(userId)")
        
        return state
    }
    
    /// Update migration progress
    func updateProgress(for userId: String, itemsProcessed: Int, lastItemKey: String?, totalItems: Int? = nil) async throws {
        var state = try await stateStore.load(for: userId)
        
        state.itemsProcessed = itemsProcessed
        state.lastItemKey = lastItemKey
        
        if let total = totalItems {
            state.totalItems = total
        }
        
        state.metadata["last_updated"] = ISO8601DateFormatter().string(from: Date())
        
        try await stateStore.save(state, for: userId)
        
        if itemsProcessed % 10 == 0 { // Log every 10 items
            logger.debug("📊 MigrationStateDataManager: Progress update for user \(userId) - \(itemsProcessed) items processed")
        }
    }
    
    /// Complete migration for a user
    func completeMigration(for userId: String) async throws -> MigrationStateData {
        var state = try await stateStore.load(for: userId)
        
        state.status = .completed
        state.finishedAt = Date()
        state.error = nil
        state.metadata["completed_by"] = "system"
        state.metadata["completion_duration"] = String(describing: state.startedAt?.timeIntervalSinceNow ?? 0)
        
        try await stateStore.save(state, for: userId)
        logger.info("✅ MigrationStateDataManager: Completed migration for user \(userId) - \(state.itemsProcessed) items processed")
        
        return state
    }
    
    /// Fail migration for a user
    func failMigration(for userId: String, error: Error) async throws -> MigrationStateData {
        var state = try await stateStore.load(for: userId)
        
        state.status = .failed
        state.finishedAt = Date()
        state.error = error.localizedDescription
        state.metadata["failed_by"] = "system"
        state.metadata["error_type"] = String(describing: type(of: error))
        
        try await stateStore.save(state, for: userId)
        logger.error("❌ MigrationStateDataManager: Failed migration for user \(userId) - \(error.localizedDescription)")
        
        return state
    }
    
    /// Cancel migration for a user
    func cancelMigration(for userId: String, reason: String = "user_request") async throws -> MigrationStateData {
        var state = try await stateStore.load(for: userId)
        
        state.status = .cancelled
        state.finishedAt = Date()
        state.metadata["cancelled_by"] = reason
        
        try await stateStore.save(state, for: userId)
        logger.info("🛑 MigrationStateDataManager: Cancelled migration for user \(userId) - reason: \(reason)")
        
        return state
    }
    
    /// Reset migration state for a user (for retry)
    func resetMigration(for userId: String) async throws -> MigrationStateData {
        let defaultState = MigrationStateData()
        try await stateStore.save(defaultState, for: userId)
        logger.info("🔄 MigrationStateDataManager: Reset migration state for user \(userId)")
        return defaultState
    }
    
    /// Check if user needs migration
    func needsMigration(for userId: String) async throws -> Bool {
        let state = try await stateStore.load(for: userId)
        return state.status == .notStarted || state.status == .failed || state.status == .cancelled
    }
    
    /// Get migration statistics
    func getMigrationStats(for userId: String) async throws -> MigrationStats {
        let state = try await stateStore.load(for: userId)
        
        return MigrationStats(
            status: state.status,
            itemsProcessed: state.itemsProcessed,
            totalItems: state.totalItems,
            progress: state.progress,
            startedAt: state.startedAt,
            finishedAt: state.finishedAt,
            duration: state.startedAt?.timeIntervalSince(state.finishedAt ?? Date()) ?? 0,
            error: state.error
        )
    }
}

// MARK: - Migration Stats

struct MigrationStats {
    let status: MigrationStatusData
    let itemsProcessed: Int
    let totalItems: Int?
    let progress: Double
    let startedAt: Date?
    let finishedAt: Date?
    let duration: TimeInterval
    let error: String?
    
    var isComplete: Bool {
        return status == .completed
    }
    
    var isInProgress: Bool {
        return status == .running || status == .paused
    }
    
    var hasError: Bool {
        return status == .failed
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
}
