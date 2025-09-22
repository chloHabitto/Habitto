import Foundation
import SwiftUI

// MARK: - Data Version
struct DataVersion: Codable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    
    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    var stringValue: String {
        return "\(major).\(minor).\(patch)"
    }
    
    static func < (lhs: DataVersion, rhs: DataVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
    static func == (lhs: DataVersion, rhs: DataVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

// MARK: - Habit Data Container
struct HabitDataContainer: Codable {
    let version: String // Data version stored in payload (authoritative)
    let habits: [Habit]
    let completedMigrationSteps: Set<String>
    let lastUpdated: Date
    
    init(habits: [Habit], version: String = "1.0.0", completedSteps: Set<String> = []) {
        self.habits = habits
        self.version = version
        self.completedMigrationSteps = completedSteps
        self.lastUpdated = Date()
    }
}

// MARK: - Crash-Safe Habit Store (File-Based Storage)
// Actor ensures all file operations are serialized and thread-safe
// NSFileCoordinator provides additional safety for extensions/widgets
actor CrashSafeHabitStore: ObservableObject {
    static let shared = CrashSafeHabitStore()
    
    private let fileManager = FileManager.default
    private let fileCoordinator = NSFileCoordinator() // For extensions/widgets coordination
    private let mainURL: URL
    private let backupURL: URL
    private let backup2URL: URL
    private let userDefaults = UserDefaults.standard // For migration version cache only (not authoritative)
    private let userId: String // For multi-account support
    
    // Cache for performance
    private var cachedContainer: HabitDataContainer?
    
    private init() {
        // Create documents directory URLs
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // For now, use a default userId - in production, this would come from user authentication
        self.userId = "default_user"
        
        self.mainURL = documentsURL.appendingPathComponent("habits.json")
        self.backupURL = documentsURL.appendingPathComponent("habits_backup.json")
        self.backup2URL = documentsURL.appendingPathComponent("habits_backup2.json")
        
        // Ensure documents directory exists
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        // Apply iOS Data Protection
        try? (mainURL as NSURL).setResourceValue(
            FileProtectionType.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
        )
        try? (backupURL as NSURL).setResourceValue(
            FileProtectionType.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
        )
        try? (backup2URL as NSURL).setResourceValue(
            FileProtectionType.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
        )
        
        print("🔧 CrashSafeHabitStore: Initialized with atomic file-based storage")
        print("🔧 CrashSafeHabitStore: Main file: \(mainURL.path)")
        print("🔧 CrashSafeHabitStore: Backup file: \(backupURL.path)")
    }
    
    // MARK: - Public Interface
    
    func loadHabits() -> [Habit] {
        if let cached = cachedContainer {
            return cached.habits
        }
        
        let container = loadContainer()
        cachedContainer = container
        return container.habits
    }
    
    func saveHabits(_ habits: [Habit]) throws {
        let currentContainer = cachedContainer ?? loadContainer()
        let newContainer = HabitDataContainer(
            habits: habits,
            version: currentContainer.version,
            completedSteps: currentContainer.completedMigrationSteps
        )
        
        try saveContainer(newContainer)
        cachedContainer = newContainer
        
        // Update UserDefaults with just the file path and version
        userDefaults.set(mainURL.path, forKey: "HabitStoreFilePath")
        userDefaults.set(newContainer.version, forKey: "HabitStoreDataVersion")
    }
    
    func getCurrentVersion() -> String {
        return cachedContainer?.version ?? "1.0.0"
    }
    
    func getCompletedMigrationSteps() -> Set<String> {
        return cachedContainer?.completedMigrationSteps ?? []
    }
    
    func markMigrationStepCompleted(_ stepName: String) throws {
        guard let container = cachedContainer else {
            throw HabitStoreError.noDataLoaded
        }
        
        var completedSteps = container.completedMigrationSteps
        completedSteps.insert(stepName)
        
        let updatedContainer = HabitDataContainer(
            habits: container.habits,
            version: container.version,
            completedSteps: completedSteps
        )
        
        try saveContainer(updatedContainer)
        cachedContainer = updatedContainer
    }
    
    func updateVersion(_ version: String) throws {
        guard let container = cachedContainer else {
            throw HabitStoreError.noDataLoaded
        }
        
        let updatedContainer = HabitDataContainer(
            habits: container.habits,
            version: version,
            completedSteps: container.completedMigrationSteps
        )
        
        try saveContainer(updatedContainer)
        cachedContainer = updatedContainer
    }
    
    func createSnapshot() throws -> URL {
        let snapshotURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("habits_snapshot_\(Date().timeIntervalSince1970).json")
        
        try fileManager.copyItem(at: mainURL, to: snapshotURL)
        
        // Exclude snapshot from backup
        try? (snapshotURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        
        print("📸 CrashSafeHabitStore: Created snapshot at \(snapshotURL.path)")
        return snapshotURL
    }
    
    func restoreFromSnapshot(_ snapshotURL: URL) throws {
        try fileManager.copyItem(at: snapshotURL, to: mainURL)
        cachedContainer = nil // Force reload
        print("🔄 CrashSafeHabitStore: Restored from snapshot at \(snapshotURL.path)")
    }
    
    // MARK: - Private Methods
    
    private func loadContainer() -> HabitDataContainer {
        var coordinatorError: NSError?
        var result: HabitDataContainer?
        
        fileCoordinator.coordinate(readingItemAt: mainURL, options: .withoutChanges, error: &coordinatorError) { (coordinatedURL) in
            do {
                let data = try Data(contentsOf: coordinatedURL)
                let container = try JSONDecoder().decode(HabitDataContainer.self, from: data)
                print("✅ CrashSafeHabitStore: Loaded \(container.habits.count) habits, version \(container.version)")
                
                // Mirror version to UserDefaults cache (not authoritative) with per-account key
                let versionKey = "MigrationVersion:\(userId)"
                userDefaults.set(container.version, forKey: versionKey)
                
                result = container
            } catch {
                print("⚠️ CrashSafeHabitStore: Failed to load main file, trying backup: \(error)")
                
                // Fallback to backup
                do {
                    let backupData = try Data(contentsOf: backupURL)
                    let container = try JSONDecoder().decode(HabitDataContainer.self, from: backupData)
                    print("✅ CrashSafeHabitStore: Loaded from backup: \(container.habits.count) habits, version \(container.version)")
                    
                    // Mirror version to UserDefaults cache (not authoritative) with per-account key
                    let versionKey = "MigrationVersion:\(userId)"
                    userDefaults.set(container.version, forKey: versionKey)
                    
                    // Try to restore main file from backup
                    try? fileManager.copyItem(at: backupURL, to: coordinatedURL)
                    result = container
                } catch {
                    print("❌ CrashSafeHabitStore: Both main and backup failed, returning empty container: \(error)")
                    result = HabitDataContainer(habits: [])
                }
            }
        }
        
        return result ?? HabitDataContainer(habits: [])
    }
    
    private func saveContainer(_ container: HabitDataContainer) throws {
        // Check disk space before writing
        try checkDiskSpace(for: container)
        
        let data = try JSONEncoder().encode(container)
        
        var coordinatorError: NSError?
        var success = false
        
        fileCoordinator.coordinate(writingItemAt: mainURL, options: .forReplacing, error: &coordinatorError) { (coordinatedURL) in
            do {
                // 1) Write to temporary file with fsync for durability
                let tempURL = coordinatedURL.deletingPathExtension()
                    .appendingPathExtension("tmp.\(UUID().uuidString)")
                
                // Ensure cleanup on any exit path
                defer { try? FileManager.default.removeItem(at: tempURL) }
                
                // Create empty temp file first
                FileManager.default.createFile(atPath: tempURL.path, contents: nil)
                
                // Write data via FileHandle for proper durability
                let fileHandle = try FileHandle(forWritingTo: tempURL)
                try fileHandle.write(contentsOf: data)
                try fileHandle.synchronize()
                try fileHandle.close()
                
                // 2) Set file protection on temp file BEFORE atomic replace
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: tempURL.path
                )
                
                // 3) Exclude temp file from backup
                try? (tempURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
                
                // 4) Atomically replace main file
                _ = try fileManager.replaceItem(at: coordinatedURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
                
                // 5) Re-assert file protection on replaced target
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: coordinatedURL.path
                )
                
                // 6) Verify by reading back
                let verificationData = try Data(contentsOf: coordinatedURL)
                let _ = try JSONDecoder().decode(HabitDataContainer.self, from: verificationData)
                
                success = true
            } catch {
                print("❌ CrashSafeHabitStore: Write operation failed: \(error)")
                // Attempt rollback from backup
                do {
                    try rollbackFromBackup(coordinatedURL)
                    print("✅ CrashSafeHabitStore: Successfully rolled back from backup")
                } catch {
                    print("❌ CrashSafeHabitStore: Rollback failed: \(error)")
                }
                success = false
            }
        }
        
        if !success {
            let error = coordinatorError ?? NSError(domain: "HabitStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown file coordination error"])
            throw HabitStoreError.fileSystemError(error)
        }
        
        // 6) Read-back verify + invariants before backup rotation
        let verifyData = try Data(contentsOf: mainURL)
        let verifyContainer = try JSONDecoder().decode(HabitDataContainer.self, from: verifyData)
        
        // Run invariants validation (simplified version for storage layer)
        try validateStorageInvariants(verifyContainer)
        
        // 7) Only now rotate backup (keep two generations) - after verify + invariants pass
        try rotateBackup()
        
        // 8) Mirror version to UserDefaults cache (not authoritative) with per-account key
        let versionKey = "MigrationVersion:\(userId)"
        userDefaults.set(container.version, forKey: versionKey)
        
        print("✅ CrashSafeHabitStore: Saved \(container.habits.count) habits, version \(container.version)")
    }
    
    private func rotateBackup() throws {
        // Atomic two-generation backup rotation: bak2 <- bak1 <- main
        // Use copy/rename pattern to avoid leaving zero backups if app dies mid-rotation
        
        // 1) Create new backup1 from main (atomic copy)
        let newBackupURL = backupURL.appendingPathExtension("new")
        try fileManager.copyItem(at: mainURL, to: newBackupURL)
        
        // 2) Set file protection on new backup1
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: newBackupURL.path
        )
        
        // 3) Move current backup1 to backup2 (atomic rename)
        if fileManager.fileExists(atPath: backupURL.path) {
            // Remove old backup2 if it exists
            try? fileManager.removeItem(at: backup2URL)
            try fileManager.moveItem(at: backupURL, to: backup2URL)
            
            // Set file protection on backup2
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: backup2URL.path
            )
        }
        
        // 4) Rename new backup to backup1 (atomic rename)
        try fileManager.moveItem(at: newBackupURL, to: backupURL)
        
        print("🔄 CrashSafeHabitStore: Atomically rotated backup files (main -> bak1 -> bak2)")
    }
    
    private func checkDiskSpace(for container: HabitDataContainer) throws {
        let data = try JSONEncoder().encode(container)
        let estimatedSize = data.count * 3 // Write amplification: temp + main + backup
        
        do {
            // Query available capacity for important usage (more accurate than systemFreeSize)
            let volumeURL = mainURL.deletingLastPathComponent()
            let resourceValues = try volumeURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            
            // Prefer important usage capacity if available, fallback to general capacity
            let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage ?? 
                                  Int64(resourceValues.volumeAvailableCapacity ?? 0)
            
            // Check if we have enough space for the write operation
            if availableCapacity < Int64(estimatedSize) {
                throw HabitStoreError.insufficientDiskSpace(required: estimatedSize, available: Int(availableCapacity))
            }
            
            // Additional safety buffer - require 2x the estimated size for safety
            let safetyBuffer = max(Int64(estimatedSize) * 2, 100 * 1024 * 1024) // 2x or 100MB, whichever is larger
            if availableCapacity < safetyBuffer {
                throw HabitStoreError.lowDiskSpace(available: Int(availableCapacity), minimum: Int(safetyBuffer))
            }
            
            print("💾 CrashSafeHabitStore: Disk space check passed - \(Int(availableCapacity / 1024 / 1024))MB available, \(estimatedSize) bytes needed")
            
        } catch let error as HabitStoreError {
            throw error
        } catch {
            // If we can't check disk space, log but don't fail
            print("⚠️ CrashSafeHabitStore: Could not check disk space: \(error)")
        }
    }
    
    func clearCache() {
        cachedContainer = nil
    }
    
    // MARK: - Rollback Methods
    
    private func rollbackFromBackup(_ targetURL: URL) throws {
        // Try to restore from backup1 first, then backup2 if backup1 fails
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: backupURL, to: targetURL)
            print("✅ CrashSafeHabitStore: Restored from backup1")
        } else if fileManager.fileExists(atPath: backup2URL.path) {
            try fileManager.copyItem(at: backup2URL, to: targetURL)
            print("✅ CrashSafeHabitStore: Restored from backup2")
        } else {
            // No backup available, create empty container
            let emptyContainer = HabitDataContainer(habits: [])
            let emptyData = try JSONEncoder().encode(emptyContainer)
            try emptyData.write(to: targetURL)
            print("⚠️ CrashSafeHabitStore: No backup available, created empty container")
        }
        
        // Re-apply file protection after rollback
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: targetURL.path
        )
    }
    
    // MARK: - Storage-Level Invariants Validation
    
    private func validateStorageInvariants(_ container: HabitDataContainer) throws {
        // Basic storage-level invariants (lightweight version of full migration invariants)
        
        // 1. Check for duplicate IDs
        let habitIds = container.habits.map { $0.id }
        let uniqueIds = Set(habitIds)
        if habitIds.count != uniqueIds.count {
            throw HabitStoreError.dataIntegrityError("Duplicate habit IDs detected")
        }
        
        // 2. Check for valid version format
        if container.version.isEmpty {
            throw HabitStoreError.dataIntegrityError("Invalid version format")
        }
        
        // 3. Check for reasonable data size
        let dataSize = try JSONEncoder().encode(container).count
        if dataSize > 100 * 1024 * 1024 { // 100MB limit
            throw HabitStoreError.dataIntegrityError("Data size exceeds reasonable limits")
        }
        
        // 4. Check for valid UTF-8 encoding in habit names and descriptions
        for habit in container.habits {
            if !habit.name.canBeConverted(to: .utf8) {
                throw HabitStoreError.dataIntegrityError("Habit name contains invalid UTF-8 encoding")
            }
            if !habit.description.canBeConverted(to: .utf8) {
                throw HabitStoreError.dataIntegrityError("Habit description contains invalid UTF-8 encoding")
            }
        }
        
        // 5. Check for valid dates
        for habit in container.habits {
            if habit.startDate > Date() {
                throw HabitStoreError.dataIntegrityError("Habit start date in the future")
            }
            if let endDate = habit.endDate, endDate < habit.startDate {
                throw HabitStoreError.dataIntegrityError("Habit end date before start date")
            }
        }
        
        print("✅ CrashSafeHabitStore: Storage invariants validation passed")
    }
}

// MARK: - Habit Store Error
enum HabitStoreError: LocalizedError {
    case noDataLoaded
    case fileSystemError(Error)
    case insufficientDiskSpace(required: Int, available: Int)
    case lowDiskSpace(available: Int, minimum: Int)
    case dataIntegrityError(String)
    case encodingError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noDataLoaded:
            return "No data loaded in HabitStore"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space: need \(required) bytes, have \(available) bytes"
        case .lowDiskSpace(let available, let minimum):
            return "Low disk space: \(available) bytes available, minimum \(minimum) bytes required"
        case .dataIntegrityError(let message):
            return "Data integrity error: \(message)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
