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
@MainActor
class CrashSafeHabitStore: ObservableObject {
    static let shared = CrashSafeHabitStore()
    
    private let fileManager = FileManager.default
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
        do {
            let data = try Data(contentsOf: mainURL)
            let container = try JSONDecoder().decode(HabitDataContainer.self, from: data)
            print("✅ CrashSafeHabitStore: Loaded \(container.habits.count) habits, version \(container.version.stringValue)")
            return container
        } catch {
            print("⚠️ CrashSafeHabitStore: Failed to load main file, trying backup: \(error)")
            
            // Fallback to backup
            do {
                let backupData = try Data(contentsOf: backupURL)
                let container = try JSONDecoder().decode(HabitDataContainer.self, from: backupData)
                print("✅ CrashSafeHabitStore: Loaded from backup: \(container.habits.count) habits, version \(container.version.stringValue)")
                
                // Try to restore main file from backup
                try? fileManager.copyItem(at: backupURL, to: mainURL)
                return container
            } catch {
                print("❌ CrashSafeHabitStore: Both main and backup failed, returning empty container: \(error)")
                return HabitDataContainer(habits: [])
            }
        }
    }
    
    private func saveContainer(_ container: HabitDataContainer) throws {
        let data = try JSONEncoder().encode(container)
        
        // 1) Write atomically to main file
        try data.write(to: mainURL, options: [.atomic])
        
        // 2) Verify by reading back
        let verificationData = try Data(contentsOf: mainURL)
        _ = try JSONDecoder().decode(HabitDataContainer.self, from: verificationData)
        
        // 3) Refresh backup
        try? fileManager.removeItem(at: backupURL)
        try fileManager.copyItem(at: mainURL, to: backupURL)
        
        print("✅ CrashSafeHabitStore: Saved \(container.habits.count) habits, version \(container.version.stringValue)")
    }
    
    func clearCache() {
        cachedContainer = nil
    }
}

// MARK: - Habit Store Error
enum HabitStoreError: LocalizedError {
    case noDataLoaded
    case fileSystemError(Error)
    case encodingError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noDataLoaded:
            return "No data loaded in HabitStore"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
