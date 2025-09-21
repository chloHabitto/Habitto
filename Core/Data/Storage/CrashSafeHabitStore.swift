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
    let version: DataVersion
    let habits: [Habit]
    let completedMigrationSteps: Set<String>
    let lastUpdated: Date
    
    init(habits: [Habit], version: DataVersion = DataVersion(1, 0, 0), completedSteps: Set<String> = []) {
        self.habits = habits
        self.version = version
        self.completedMigrationSteps = completedSteps
        self.lastUpdated = Date()
    }
}

// MARK: - Crash-Safe Habit Store (File-Based Storage)
actor CrashSafeHabitStore: ObservableObject {
    static let shared = CrashSafeHabitStore()
    
    private let fileManager = FileManager.default
    private let fileCoordinator = NSFileCoordinator()
    private let mainURL: URL
    private let backupURL: URL
    private let userDefaults = UserDefaults.standard
    
    // Cache for performance
    private var cachedContainer: HabitDataContainer?
    
    private init() {
        // Create documents directory URLs
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        self.mainURL = documentsURL.appendingPathComponent("habits.json")
        self.backupURL = documentsURL.appendingPathComponent("habits_backup.json")
        
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
        userDefaults.set(newContainer.version.stringValue, forKey: "HabitStoreDataVersion")
    }
    
    func getCurrentVersion() -> DataVersion {
        return cachedContainer?.version ?? DataVersion(1, 0, 0)
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
    
    func updateVersion(_ version: DataVersion) throws {
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
                print("✅ CrashSafeHabitStore: Loaded \(container.habits.count) habits, version \(container.version.stringValue)")
                result = container
            } catch {
                print("⚠️ CrashSafeHabitStore: Failed to load main file, trying backup: \(error)")
                
                // Fallback to backup
                do {
                    let backupData = try Data(contentsOf: backupURL)
                    let container = try JSONDecoder().decode(HabitDataContainer.self, from: backupData)
                    print("✅ CrashSafeHabitStore: Loaded from backup: \(container.habits.count) habits, version \(container.version.stringValue)")
                    
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
                // 1) Write to temporary file first
                let tempURL = coordinatedURL.appendingPathExtension("tmp")
                try data.write(to: tempURL, options: [.atomic])
                
                // 2) Set file protection on temp file
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: tempURL.path
                )
                
                // 3) Atomically replace main file
                _ = try fileManager.replaceItem(at: coordinatedURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
                
                // 4) Verify by reading back
                let verificationData = try Data(contentsOf: coordinatedURL)
                _ = try JSONDecoder().decode(HabitDataContainer.self, from: verificationData)
                
                success = true
            } catch {
                success = false
            }
        }
        
        if !success {
            throw HabitStoreError.fileSystemError(coordinatorError ?? NSError(domain: "HabitStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown file coordination error"]))
        }
        
        // 5) Only now rotate backup (keep two generations)
        try rotateBackup()
        
        print("✅ CrashSafeHabitStore: Saved \(container.habits.count) habits, version \(container.version.stringValue)")
    }
    
    private func rotateBackup() throws {
        let backup2URL = backupURL.appendingPathExtension("2")
        
        // Move current backup to backup-2
        if fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.removeItem(at: backup2URL)
            try? fileManager.moveItem(at: backupURL, to: backup2URL)
        }
        
        // Copy main to backup
        try fileManager.copyItem(at: mainURL, to: backupURL)
        
        // Set file protection on backup
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: backupURL.path
        )
    }
    
    private func checkDiskSpace(for container: HabitDataContainer) throws {
        let data = try JSONEncoder().encode(container)
        let estimatedSize = data.count * 3 // Write amplification: temp + main + backup
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: mainURL.deletingLastPathComponent().path)
            let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
            
            if freeSpace < Int64(estimatedSize) {
                throw HabitStoreError.insufficientDiskSpace(required: estimatedSize, available: Int(freeSpace))
            }
            
            // Ensure minimum 100MB buffer
            let minimumBuffer = 100 * 1024 * 1024 // 100MB
            if freeSpace < minimumBuffer {
                throw HabitStoreError.lowDiskSpace(available: Int(freeSpace), minimum: minimumBuffer)
            }
            
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
}

// MARK: - Habit Store Error
enum HabitStoreError: LocalizedError {
    case noDataLoaded
    case fileSystemError(Error)
    case insufficientDiskSpace(required: Int, available: Int)
    case lowDiskSpace(available: Int, minimum: Int)
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
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
