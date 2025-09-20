import Foundation
import OSLog

// MARK: - Backup Error
enum BackupError: Error, LocalizedError {
    case vacationModeActive
    case backupFailed(Error)
    case restoreFailed(Error)
    case invalidBackup
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .vacationModeActive:
            return "Backup operations are paused during vacation mode"
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        case .invalidBackup:
            return "Invalid backup file"
        case .fileNotFound:
            return "Backup file not found"
        }
    }
}

// MARK: - Backup Manager
/// Manages automatic and manual backups with rotating snapshots
@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    // MARK: - Properties
    @Published var isBackingUp = false
    @Published var lastBackupDate: Date?
    @Published var backupCount = 0
    @Published var availableBackups: [BackupSnapshot] = []
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "BackupManager")
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let authManager = AuthenticationManager.shared
    
    // MARK: - Configuration
    private let maxBackups = 10 // Keep last 10 backups
    private let backupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let backupDirectory: URL
    
    // MARK: - Keys
    private let lastBackupKey = "LastBackupDate"
    private let backupCountKey = "BackupCount"
    
    // MARK: - User-Specific Keys
    private func getUserSpecificKey(_ baseKey: String) -> String {
        let userId = getCurrentUserId()
        return "\(userId)_\(baseKey)"
    }
    
    private func getCurrentUserId() -> String {
        if let user = authManager.currentUser {
            return user.uid
        }
        return "guest_user"
    }
    
    private init() {
        // Create user-specific backup directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let userId = authManager.currentUser?.uid ?? "guest_user"
        backupDirectory = documentsPath.appendingPathComponent("Backups").appendingPathComponent(userId)
        
        // Ensure backup directory exists
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        loadBackupInfo()
        loadAvailableBackups()
    }
    
    // MARK: - Public Methods
    
    /// Create a backup snapshot of current data
    func createBackup() async throws -> BackupSnapshot {
        // Skip backup operations during vacation mode
        if VacationManager.shared.isActive {
            logger.info("Skipping backup creation during vacation mode")
            throw BackupError.vacationModeActive
        }
        
        logger.info("Starting backup creation")
        isBackingUp = true
        defer { isBackingUp = false }
        
        let snapshot = try await performBackup()
        
        // Update metadata
        lastBackupDate = snapshot.createdAt
        backupCount += 1
        
        let userLastBackupKey = getUserSpecificKey(lastBackupKey)
        let userBackupCountKey = getUserSpecificKey(backupCountKey)
        
        userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
        userDefaults.set(backupCount, forKey: userBackupCountKey)
        
        // Clean up old backups
        try await cleanupOldBackups()
        
        // Reload available backups
        loadAvailableBackups()
        
        logger.info("Backup created successfully: \(snapshot.id)")
        return snapshot
    }
    
    /// Restore from a specific backup
    func restore(from snapshot: BackupSnapshot) async throws {
        logger.info("Starting restore from backup: \(snapshot.id)")
        
        try await performRestore(snapshot)
        
        logger.info("Restore completed successfully")
    }
    
    /// Delete a specific backup
    func deleteBackup(_ snapshot: BackupSnapshot) async throws {
        logger.info("Deleting backup: \(snapshot.id)")
        
        let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
        try fileManager.removeItem(at: backupURL)
        
        loadAvailableBackups()
        logger.info("Backup deleted successfully")
    }
    
    /// Check if backup is needed based on interval
    func shouldCreateBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        return Date().timeIntervalSince(lastBackup) >= backupInterval
    }
    
    /// Create backup if needed
    func createBackupIfNeeded() async {
        // Skip automatic backups during vacation mode
        if VacationManager.shared.isActive {
            logger.info("Skipping automatic backup during vacation mode")
            return
        }
        
        guard shouldCreateBackup() else { return }
        
        do {
            _ = try await createBackup()
            logger.info("Automatic backup created")
        } catch {
            logger.error("Automatic backup failed: \(error.localizedDescription)")
        }
    }
    
    /// Verify backup integrity
    func verifyBackup(_ snapshot: BackupSnapshot) async throws -> Bool {
        let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
        
        // Check if backup file exists
        guard fileManager.fileExists(atPath: backupURL.path) else {
            return false
        }
        
        // Verify backup can be loaded
        do {
            let data = try Data(contentsOf: backupURL)
            let backupData = try JSONDecoder().decode(BackupData.self, from: data)
            return backupData.isValid
        } catch {
            logger.error("Backup verification failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func performBackup() async throws -> BackupSnapshot {
        let snapshotId = UUID()
        let createdAt = Date()
        
        // Load current habits data
        let habitStore = HabitStore.shared
        let habits = try await habitStore.loadHabits()
        
        // Create backup data
        let backupData = BackupData(
            id: snapshotId,
            createdAt: createdAt,
            habits: habits,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            dataVersion: "1.0"
        )
        
        // Save backup to file
        let backupURL = backupDirectory.appendingPathComponent(snapshotId.uuidString)
        let data = try JSONEncoder().encode(backupData)
        try data.write(to: backupURL)
        
        // Create snapshot metadata
        let snapshot = BackupSnapshot(
            id: snapshotId,
            createdAt: createdAt,
            habitCount: habits.count,
            fileSize: data.count,
            appVersion: backupData.appVersion
        )
        
        return snapshot
    }
    
    private func performRestore(_ snapshot: BackupSnapshot) async throws {
        let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
        let data = try Data(contentsOf: backupURL)
        let backupData = try JSONDecoder().decode(BackupData.self, from: data)
        
        // Restore habits to storage
        let habitStore = HabitStore.shared
        try await habitStore.saveHabits(backupData.habits)
        
        // Update backup info
        lastBackupDate = snapshot.createdAt
        let userLastBackupKey = getUserSpecificKey(lastBackupKey)
        userDefaults.set(lastBackupDate, forKey: userLastBackupKey)
    }
    
    private func cleanupOldBackups() async throws {
        let sortedBackups = availableBackups.sorted { $0.createdAt > $1.createdAt }
        
        if sortedBackups.count > maxBackups {
            let backupsToDelete = Array(sortedBackups.dropFirst(maxBackups))
            
            for backup in backupsToDelete {
                try await deleteBackup(backup)
            }
        }
    }
    
    private func loadBackupInfo() {
        let userLastBackupKey = getUserSpecificKey(lastBackupKey)
        let userBackupCountKey = getUserSpecificKey(backupCountKey)
        
        lastBackupDate = userDefaults.object(forKey: userLastBackupKey) as? Date
        backupCount = userDefaults.integer(forKey: userBackupCountKey)
    }
    
    private func loadAvailableBackups() {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            var backups: [BackupSnapshot] = []
            
            for fileURL in backupFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let backupData = try JSONDecoder().decode(BackupData.self, from: data)
                    
                    let snapshot = BackupSnapshot(
                        id: backupData.id,
                        createdAt: backupData.createdAt,
                        habitCount: backupData.habits.count,
                        fileSize: data.count,
                        appVersion: backupData.appVersion
                    )
                    
                    backups.append(snapshot)
                } catch {
                    logger.error("Failed to load backup file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            availableBackups = backups.sorted { $0.createdAt > $1.createdAt }
        } catch {
            logger.error("Failed to load available backups: \(error.localizedDescription)")
            availableBackups = []
        }
    }
}

// MARK: - Backup Data Models
struct BackupData: Codable {
    let id: UUID
    let createdAt: Date
    let habits: [Habit]
    let appVersion: String
    let dataVersion: String
    
    var isValid: Bool {
        return !habits.isEmpty || habits.isEmpty // Empty habits is still valid
    }
}

struct BackupSnapshot: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let habitCount: Int
    let fileSize: Int
    let appVersion: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
