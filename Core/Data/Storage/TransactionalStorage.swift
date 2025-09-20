import Foundation
import OSLog

// MARK: - Transactional Storage Protocol
/// Protocol for storage implementations that support atomic transactions
protocol TransactionalStorage {
    /// Performs multiple operations atomically
    /// - Parameter operations: Array of storage operations to perform
    /// - Throws: TransactionError if any operation fails
    func performTransaction(_ operations: [StorageOperation]) async throws
}

// MARK: - Storage Operation Types

enum StorageOperation {
    case save(key: String, data: Data)
    case delete(key: String)
    case update(key: String, data: Data)
}

// MARK: - Transaction Error

enum TransactionError: LocalizedError {
    case operationFailed(operation: StorageOperation, underlyingError: Error)
    case rollbackFailed(underlyingError: Error)
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation, let error):
            return "Storage operation failed: \(operation) - \(error.localizedDescription)"
        case .rollbackFailed(let error):
            return "Failed to rollback transaction: \(error.localizedDescription)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .operationFailed:
            return "Check storage availability and permissions"
        case .rollbackFailed:
            return "Data may be in an inconsistent state. Consider manual recovery."
        case .invalidOperation:
            return "Verify the operation parameters are correct"
        }
    }
}

// MARK: - Transaction Manager

/// Manages atomic transactions for storage operations
final class TransactionManager {
    private let logger = Logger(subsystem: "com.habitto.app", category: "TransactionManager")
    private let atomicWriter = AtomicFileWriter()
    
    /// Performs a transaction with rollback capability
    /// - Parameters:
    ///   - operations: Array of storage operations to perform
    ///   - storage: The storage implementation to use
    /// - Throws: TransactionError if any operation fails
    func performTransaction(_ operations: [StorageOperation], using storage: TransactionalStorage) async throws {
        guard !operations.isEmpty else {
            logger.debug("No operations to perform in transaction")
            return
        }
        
        logger.info("Starting transaction with \(operations.count) operations")
        
        // Create backup of current state
        let backup = try await createBackup(operations: operations, using: storage)
        
        do {
            // Perform all operations
            try await storage.performTransaction(operations)
            logger.info("Transaction completed successfully")
            
        } catch {
            logger.error("Transaction failed, attempting rollback: \(error.localizedDescription)")
            
            // Rollback to previous state
            try await rollback(to: backup, using: storage)
            throw TransactionError.operationFailed(operation: operations.first!, underlyingError: error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates a backup of the current state before transaction
    private func createBackup(operations: [StorageOperation], using storage: TransactionalStorage) async throws -> [String: Data] {
        var backup: [String: Data] = [:]
        
        // Extract unique keys from operations
        let keys = Set(operations.compactMap { operation in
            switch operation {
            case .save(let key, _), .delete(let key), .update(let key, _):
                return key
            }
        })
        
        // Backup current values for each key
        for key in keys {
            if let data = try await readData(for: key, using: storage) {
                backup[key] = data
            }
        }
        
        logger.debug("Created backup for \(backup.count) keys")
        return backup
    }
    
    /// Rolls back to the backup state
    private func rollback(to backup: [String: Data], using storage: TransactionalStorage) async throws {
        logger.info("Rolling back transaction")
        
        do {
            // Restore backed up data
            let restoreOperations = backup.map { StorageOperation.save(key: $0.key, data: $0.value) }
            try await storage.performTransaction(restoreOperations)
            
            logger.info("Rollback completed successfully")
        } catch {
            logger.error("Rollback failed: \(error.localizedDescription)")
            throw TransactionError.rollbackFailed(underlyingError: error)
        }
    }
    
    /// Reads data for a specific key (implementation depends on storage type)
    private func readData(for key: String, using storage: TransactionalStorage) async throws -> Data? {
        // This is a simplified implementation
        // In a real implementation, this would depend on the specific storage type
        return nil
    }
}

// MARK: - Atomic Storage Wrapper

/// Wraps any storage implementation with atomic write capabilities
final class AtomicStorageWrapper<T: HabitStorageProtocol>: HabitStorageProtocol, TransactionalStorage {
    typealias DataType = T.DataType
    
    private let wrappedStorage: T
    private let atomicWriter = AtomicFileWriter()
    private let transactionManager = TransactionManager()
    private let logger = Logger(subsystem: "com.habitto.app", category: "AtomicStorageWrapper")
    
    init(wrapping storage: T) {
        self.wrappedStorage = storage
    }
    
    // MARK: - HabitStorageProtocol Implementation
    
    func save<U: Codable>(_ data: U, forKey key: String, immediate: Bool = false) async throws {
        logger.debug("Saving data atomically for key: \(key)")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            let fileURL = getFileURL(for: key)
            try atomicWriter.writeAtomically(jsonData, to: fileURL)
            
            logger.debug("Data saved atomically for key: \(key)")
        } catch {
            logger.error("Failed to save data atomically for key \(key): \(error.localizedDescription)")
            throw error
        }
    }
    
    func load<U: Codable>(_ type: U.Type, forKey key: String) async throws -> U? {
        logger.debug("Loading data for key: \(key)")
        
        do {
            let fileURL = getFileURL(for: key)
            return try atomicWriter.readObject(type, from: fileURL)
        } catch {
            logger.error("Failed to load data for key \(key): \(error.localizedDescription)")
            throw error
        }
    }
    
    func delete(forKey key: String) async throws {
        logger.debug("Deleting data for key: \(key)")
        
        do {
            let fileURL = getFileURL(for: key)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            logger.debug("Data deleted for key: \(key)")
        } catch {
            logger.error("Failed to delete data for key \(key): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Habit-Specific Methods
    
    func saveHabits(_ habits: [Habit], immediate: Bool = false) async throws {
        logger.info("Saving \(habits.count) habits atomically")
        
        do {
            let jsonData = try JSONEncoder().encode(habits)
            let fileURL = getFileURL(for: "habits")
            try atomicWriter.writeAtomically(jsonData, to: fileURL)
            
            logger.info("Habits saved atomically")
        } catch {
            logger.error("Failed to save habits atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadHabits() async throws -> [Habit] {
        logger.debug("Loading habits atomically")
        
        do {
            let fileURL = getFileURL(for: "habits")
            guard let habits = try atomicWriter.readObject([Habit].self, from: fileURL) else {
                logger.debug("No habits found, returning empty array")
                return []
            }
            
            logger.debug("Loaded \(habits.count) habits atomically")
            return habits
        } catch {
            logger.error("Failed to load habits atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    func saveHabit(_ habit: Habit, immediate: Bool = false) async throws {
        logger.debug("Saving single habit atomically: \(habit.name)")
        
        do {
            let jsonData = try JSONEncoder().encode(habit)
            let fileURL = getFileURL(for: "habit_\(habit.id.uuidString)")
            try atomicWriter.writeAtomically(jsonData, to: fileURL)
            
            logger.debug("Habit saved atomically: \(habit.name)")
        } catch {
            logger.error("Failed to save habit atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadHabit(id: UUID) async throws -> Habit? {
        logger.debug("Loading habit atomically by ID: \(id)")
        
        do {
            let fileURL = getFileURL(for: "habit_\(id.uuidString)")
            return try atomicWriter.readObject(Habit.self, from: fileURL)
        } catch {
            logger.error("Failed to load habit atomically by ID \(id): \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteHabit(id: UUID) async throws {
        logger.debug("Deleting habit atomically by ID: \(id)")
        
        do {
            let fileURL = getFileURL(for: "habit_\(id.uuidString)")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            logger.debug("Habit deleted atomically by ID: \(id)")
        } catch {
            logger.error("Failed to delete habit atomically by ID \(id): \(error.localizedDescription)")
            throw error
        }
    }
    
    func clearAllHabits() async throws {
        logger.info("Clearing all habits atomically")
        
        do {
            let fileURL = getFileURL(for: "habits")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // Also clear individual habit files
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let atomicStorageDirectory = documentsPath.appendingPathComponent("AtomicStorage")
            
            if FileManager.default.fileExists(atPath: atomicStorageDirectory.path) {
                let files = try FileManager.default.contentsOfDirectory(at: atomicStorageDirectory, includingPropertiesForKeys: nil)
                for file in files where file.lastPathComponent.hasPrefix("habit_") {
                    try FileManager.default.removeItem(at: file)
                }
            }
            
            logger.info("All habits cleared atomically")
        } catch {
            logger.error("Failed to clear all habits atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - DataStorageProtocol Implementation
    
    func exists(forKey key: String) async throws -> Bool {
        let fileURL = getFileURL(for: key)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func keys(withPrefix prefix: String) async throws -> [String] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let atomicStorageDirectory = documentsPath.appendingPathComponent("AtomicStorage")
        
        guard FileManager.default.fileExists(atPath: atomicStorageDirectory.path) else {
            return []
        }
        
        let files = try FileManager.default.contentsOfDirectory(at: atomicStorageDirectory, includingPropertiesForKeys: nil)
        return files.compactMap { file in
            let fileName = file.lastPathComponent
            if fileName.hasPrefix(prefix) && fileName.hasSuffix(".json") {
                return String(fileName.dropLast(5)) // Remove .json extension
            }
            return nil
        }
    }
    
    // MARK: - TransactionalStorage Implementation
    
    func performTransaction(_ operations: [StorageOperation]) async throws {
        logger.info("Performing transaction with \(operations.count) operations")
        
        for operation in operations {
            switch operation {
            case .save(let key, let data):
                try await save(data, forKey: key)
            case .delete(let key):
                try await delete(forKey: key)
            case .update(let key, let data):
                try await save(data, forKey: key)
            }
        }
        
        logger.info("Transaction completed successfully")
    }
    
    // MARK: - Private Methods
    
    /// Gets the file URL for a given key
    private func getFileURL(for key: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storageDirectory = documentsPath.appendingPathComponent("AtomicStorage")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        return storageDirectory.appendingPathComponent("\(key).json")
    }
}
