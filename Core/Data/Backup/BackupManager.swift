import Foundation
import SwiftData
import Compression
import OSLog
import UIKit

// MARK: - Backup Error
enum BackupError: Error, LocalizedError {
    case vacationModeActive
    case backupFailed(Error)
    case restoreFailed(Error)
    case invalidBackup
    case fileNotFound
    case dataExportFailed(String)
    case fileCreationFailed(String)
    case compressionFailed(String)
    case serializationFailed(String)
    case networkError(String)
    case storageError(String)
    case validationFailed(String)
    case permissionDenied(String)
    case insufficientStorage(String)
    case userNotAuthenticated
    case unknown(String)
    
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
        case .dataExportFailed(let message):
            return "Data export failed: \(message)"
        case .fileCreationFailed(let message):
            return "File creation failed: \(message)"
        case .compressionFailed(let message):
            return "Compression failed: \(message)"
        case .serializationFailed(let message):
            return "Serialization failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .insufficientStorage(let message):
            return "Insufficient storage: \(message)"
        case .userNotAuthenticated:
            return "User must be authenticated to create backups"
        case .unknown(let message):
            return "Unknown error: \(message)"
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
    
    // MARK: - Public Wrapper Methods
    
    /// Public method to create backup data for storage coordinators
    func createBackupData() async throws -> Data {
        // Create comprehensive backup data directly
        let backupData = try await createComprehensiveBackupData(metadata: BackupMetadata(
            version: "1.0",
            createdDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            userId: authManager.currentUser?.uid ?? "guest",
            backupId: UUID().uuidString
        ), habits: try await HabitStore.shared.loadHabits())
        
        return try JSONEncoder().encode(backupData)
    }
    
    /// Public method to restore from backup data
    func restoreFromData(_ data: Data) async throws -> Int {
        let backupData = try JSONDecoder().decode(BackupData.self, from: data)
        
        // Restore habits to storage - handle both legacy and new format
        let habitStore = HabitStore.shared
        if let legacyHabits = backupData.habitsLegacy, !legacyHabits.isEmpty {
            // Restore legacy format
            try await habitStore.saveHabits(legacyHabits)
            return legacyHabits.count
        } else {
            // For new format, we would need to convert BackupHabitData back to Habit
            // For now, we'll just log that new format restoration is not yet implemented
            logger.info("New backup format restoration not yet implemented")
            throw BackupError.restoreFailed(NSError(domain: "BackupManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "New backup format restoration not yet implemented"]))
        }
    }
    
    // MARK: - Private Methods
    
    private func performBackup() async throws -> BackupSnapshot {
        let snapshotId = UUID()
        let createdAt = Date()
        
        // Check if user is authenticated
        guard let currentUser = authManager.currentUser else {
            throw BackupError.userNotAuthenticated
        }
        
        // Load current habits data
        let habitStore = HabitStore.shared
        let habits = try await habitStore.loadHabits()
        
        // Create comprehensive backup data
        let metadata = BackupMetadata(userId: currentUser.uid)
        let backupData = try await createComprehensiveBackupData(metadata: metadata, habits: habits)
        
        // Save backup to file with compression
        let backupURL = backupDirectory.appendingPathComponent(snapshotId.uuidString)
        let fileInfo = try await saveBackupDataWithCompression(backupData, to: backupURL)
        
        // Create snapshot metadata
        let snapshot = BackupSnapshot(
            id: snapshotId,
            createdAt: createdAt,
            habitCount: habits.count,
            fileSize: Int(fileInfo.fileSize),
            appVersion: backupData.appVersion
        )
        
        return snapshot
    }
    
    /// Create comprehensive backup data from SwiftData
    private func createComprehensiveBackupData(metadata: BackupMetadata, habits: [Habit]) async throws -> BackupData {
        let context = SwiftDataContainer.shared.modelContext
        let userId = metadata.userId
        
        // Fetch all data for the current user
        let habitData = try context.fetch(FetchDescriptor<HabitData>(
            predicate: #Predicate { $0.userId == userId }
        ))
        
        // Note: CompletionRecord, DifficultyRecord, UsageRecord, and HabitNote 
        // are accessed through relationships, not directly queried
        // We'll collect them from the habit relationships
        var allCompletions: [CompletionRecord] = []
        var allDifficulties: [DifficultyRecord] = []
        var allUsageRecords: [UsageRecord] = []
        var allHabitNotes: [HabitNote] = []
        
        for habit in habitData {
            allCompletions.append(contentsOf: habit.completionHistory)
            allDifficulties.append(contentsOf: habit.difficultyHistory)
            allUsageRecords.append(contentsOf: habit.usageHistory)
            allHabitNotes.append(contentsOf: habit.notes)
        }
        
        // Convert to backup models
        let backupHabits = habitData.map { BackupHabitData(from: $0) }
        
        // Create mappings for related records
        var habitIdMapping: [ObjectIdentifier: String] = [:]
        for habit in habitData {
            habitIdMapping[ObjectIdentifier(habit)] = habit.id.uuidString
        }
        
        let backupCompletions: [BackupCompletionRecord] = allCompletions.compactMap { completion in
            // Find the habit this completion belongs to
            guard let habitId = habitData.first(where: { $0.completionHistory.contains(completion) })?.id.uuidString else {
                return nil
            }
            return BackupCompletionRecord(from: completion, habitId: habitId)
        }
        
        let backupDifficulties: [BackupDifficultyRecord] = allDifficulties.compactMap { difficulty in
            // Find the habit this difficulty belongs to
            guard let habitId = habitData.first(where: { $0.difficultyHistory.contains(difficulty) })?.id.uuidString else {
                return nil
            }
            return BackupDifficultyRecord(from: difficulty, habitId: habitId)
        }
        
        let backupUsageRecords: [BackupUsageRecord] = allUsageRecords.compactMap { usage in
            // Find the habit this usage belongs to
            guard let habitId = habitData.first(where: { $0.usageHistory.contains(usage) })?.id.uuidString else {
                return nil
            }
            return BackupUsageRecord(from: usage, habitId: habitId)
        }
        
        let backupHabitNotes: [BackupHabitNote] = allHabitNotes.compactMap { note in
            // Find the habit this note belongs to
            guard let habitId = habitData.first(where: { $0.notes.contains(note) })?.id.uuidString else {
                return nil
            }
            return BackupHabitNote(from: note, habitId: habitId)
        }
        
        // Get user settings
        let userSettings = getUserSettings()
        
        return BackupData(
            metadata: metadata,
            habits: backupHabits,
            completions: backupCompletions,
            difficulties: backupDifficulties,
            usageRecords: backupUsageRecords,
            habitNotes: backupHabitNotes,
            userSettings: userSettings,
            habitsLegacy: habits
        )
    }
    
    /// Save backup data with optional compression
    private func saveBackupDataWithCompression(_ backupData: BackupData, to filePath: URL, compressionEnabled: Bool = true) async throws -> BackupFileInfo {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(backupData)
        
        let finalData: Data
        let isCompressed: Bool
        
        if compressionEnabled {
            finalData = try compressData(jsonData)
            isCompressed = true
        } else {
            finalData = jsonData
            isCompressed = false
        }
        
        // Write to file
        try finalData.write(to: filePath)
        
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        return BackupFileInfo(
            fileName: filePath.lastPathComponent,
            filePath: filePath.path,
            fileSize: fileSize,
            backupId: backupData.metadata.backupId,
            isCompressed: isCompressed
        )
    }
    
    /// Compress data using compression framework
    private func compressData(_ data: Data) throws -> Data {
        return try data.compressed(algorithm: COMPRESSION_LZFSE)
    }
    
    /// Decompress data using compression framework
    private func decompressData(_ compressedData: Data) throws -> Data {
        return try compressedData.decompressed(algorithm: COMPRESSION_LZFSE)
    }
    
    /// Get user settings from UserDefaults
    private func getUserSettings() -> BackupUserSettings {
        let defaults = UserDefaults.standard
        
        let notificationSettings: [String: Bool] = [
            "dailyReminders": defaults.bool(forKey: "dailyReminders"),
            "weeklyReports": defaults.bool(forKey: "weeklyReports"),
            "streakReminders": defaults.bool(forKey: "streakReminders")
        ]
        
        let themeSettings: [String: String] = [
            "selectedTheme": defaults.string(forKey: "selectedTheme") ?? "default"
        ]
        
        let privacySettings: [String: Bool] = [
            "analyticsEnabled": defaults.bool(forKey: "analyticsEnabled"),
            "crashReportingEnabled": defaults.bool(forKey: "crashReportingEnabled")
        ]
        
        let backupSettings: [String: String] = [
            "automaticBackup": defaults.bool(forKey: "automaticBackup") ? "true" : "false",
            "backupFrequency": defaults.string(forKey: "backupFrequency") ?? "daily"
        ]
        
        return BackupUserSettings(
            notificationSettings: notificationSettings,
            themeSettings: themeSettings,
            privacySettings: privacySettings,
            backupSettings: backupSettings
        )
    }
    
    private func performRestore(_ snapshot: BackupSnapshot) async throws {
        let backupURL = backupDirectory.appendingPathComponent(snapshot.id.uuidString)
        let data = try Data(contentsOf: backupURL)
        let backupData = try JSONDecoder().decode(BackupData.self, from: data)
        
        // Restore habits to storage - handle both legacy and new format
        let habitStore = HabitStore.shared
        if let legacyHabits = backupData.habitsLegacy, !legacyHabits.isEmpty {
            // Restore legacy format
            try await habitStore.saveHabits(legacyHabits)
        } else {
            // For new format, we would need to convert BackupHabitData back to Habit
            // For now, we'll just log that new format restoration is not yet implemented
            logger.info("New backup format restoration not yet implemented")
            throw BackupError.restoreFailed(NSError(domain: "BackupManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "New backup format restoration not yet implemented"]))
        }
        
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

/// Main backup data structure containing all app data
struct BackupData: Codable {
    let metadata: BackupMetadata
    let habits: [BackupHabitData]
    let completions: [BackupCompletionRecord]
    let difficulties: [BackupDifficultyRecord]
    let usageRecords: [BackupUsageRecord]
    let habitNotes: [BackupHabitNote]
    let userSettings: BackupUserSettings
    
    // Legacy support for existing backups
    let id: UUID
    let createdAt: Date
    let habitsLegacy: [Habit]?
    let appVersion: String
    let dataVersion: String
    
    init(
        metadata: BackupMetadata,
        habits: [BackupHabitData] = [],
        completions: [BackupCompletionRecord] = [],
        difficulties: [BackupDifficultyRecord] = [],
        usageRecords: [BackupUsageRecord] = [],
        habitNotes: [BackupHabitNote] = [],
        userSettings: BackupUserSettings = BackupUserSettings(),
        id: UUID = UUID(),
        createdAt: Date = Date(),
        habitsLegacy: [Habit]? = nil,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        dataVersion: String = "1.0"
    ) {
        self.metadata = metadata
        self.habits = habits
        self.completions = completions
        self.difficulties = difficulties
        self.usageRecords = usageRecords
        self.habitNotes = habitNotes
        self.userSettings = userSettings
        self.id = id
        self.createdAt = createdAt
        self.habitsLegacy = habitsLegacy
        self.appVersion = appVersion
        self.dataVersion = dataVersion
    }
    
    var isValid: Bool {
        return !habits.isEmpty || (habitsLegacy?.isEmpty == false) || (habits.isEmpty && (habitsLegacy?.isEmpty ?? true))
    }
}

/// Backup metadata containing version and timestamp information
struct BackupMetadata: Codable {
    let version: String
    let createdDate: Date
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    let userId: String
    let backupId: String
    
    init(
        version: String = "1.0",
        createdDate: Date = Date(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        deviceModel: String = UIDevice.current.model,
        osVersion: String = UIDevice.current.systemVersion,
        userId: String,
        backupId: String = UUID().uuidString
    ) {
        self.version = version
        self.createdDate = createdDate
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.userId = userId
        self.backupId = backupId
    }
}

/// Backup representation of habit data
struct BackupHabitData: Codable {
    let id: String
    let name: String
    let habitDescription: String?
    let colorData: Data?
    let icon: String?
    let goal: String
    let schedule: String
    let habitType: String
    let reminder: String?
    let startDate: Date
    let endDate: Date?
    let isCompleted: Bool
    let streak: Int
    let createdAt: Date
    let updatedAt: Date
    let userId: String
    
    init(from habitData: HabitData) {
        self.id = habitData.id.uuidString
        self.name = habitData.name
        self.habitDescription = habitData.habitDescription
        self.colorData = habitData.colorData
        self.icon = habitData.icon
        self.goal = habitData.goal
        self.schedule = habitData.schedule
        self.habitType = habitData.habitType
        self.reminder = habitData.reminder
        self.startDate = habitData.startDate
        self.endDate = habitData.endDate
        self.isCompleted = habitData.isCompleted
        self.streak = habitData.streak
        self.createdAt = habitData.createdAt
        self.updatedAt = habitData.updatedAt
        self.userId = habitData.userId
    }
}

/// Backup representation of completion records
struct BackupCompletionRecord: Codable {
    let id: String
    let habitId: String?
    let date: Date
    let isCompleted: Bool
    let createdAt: Date
    
    init(from completion: CompletionRecord, habitId: String? = nil) {
        self.id = UUID().uuidString // Generate new ID since CompletionRecord doesn't have one
        self.habitId = habitId
        self.date = completion.date
        self.isCompleted = completion.isCompleted
        self.createdAt = completion.createdAt
    }
}

/// Backup representation of difficulty records
struct BackupDifficultyRecord: Codable {
    let id: String
    let habitId: String?
    let date: Date
    let difficulty: Int
    let createdAt: Date
    
    init(from difficulty: DifficultyRecord, habitId: String? = nil) {
        self.id = UUID().uuidString // Generate new ID since DifficultyRecord doesn't have one
        self.habitId = habitId
        self.date = difficulty.date
        self.difficulty = difficulty.difficulty
        self.createdAt = difficulty.createdAt
    }
}

/// Backup representation of usage records
struct BackupUsageRecord: Codable {
    let id: String
    let habitId: String?
    let key: String
    let value: Int
    let createdAt: Date
    
    init(from usage: UsageRecord, habitId: String? = nil) {
        self.id = UUID().uuidString // Generate new ID since UsageRecord doesn't have one
        self.habitId = habitId
        self.key = usage.key
        self.value = usage.value
        self.createdAt = usage.createdAt
    }
}

/// Backup representation of habit notes
struct BackupHabitNote: Codable {
    let id: String
    let habitId: String?
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    init(from note: HabitNote, habitId: String? = nil) {
        self.id = UUID().uuidString // Generate new ID since HabitNote doesn't have one
        self.habitId = habitId
        self.content = note.content
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
    }
}

/// Backup representation of user settings
struct BackupUserSettings: Codable {
    let notificationSettings: [String: Bool]
    let themeSettings: [String: String]
    let privacySettings: [String: Bool]
    let backupSettings: [String: String] // Changed from [String: Any] to [String: String] for Codable conformance
    
    init(
        notificationSettings: [String: Bool] = [:],
        themeSettings: [String: String] = [:],
        privacySettings: [String: Bool] = [:],
        backupSettings: [String: String] = [:]
    ) {
        self.notificationSettings = notificationSettings
        self.themeSettings = themeSettings
        self.privacySettings = privacySettings
        self.backupSettings = backupSettings
    }
}

/// Backup file information for tracking and management
struct BackupFileInfo: Codable {
    let fileName: String
    let filePath: String
    let fileSize: Int64
    let createdDate: Date
    let backupId: String
    let isCompressed: Bool
    let checksum: String?
    
    init(
        fileName: String,
        filePath: String,
        fileSize: Int64,
        createdDate: Date = Date(),
        backupId: String,
        isCompressed: Bool = false,
        checksum: String? = nil
    ) {
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.createdDate = createdDate
        self.backupId = backupId
        self.isCompressed = isCompressed
        self.checksum = checksum
    }
}

/// Backup operation result
struct BackupResult {
    let success: Bool
    let fileInfo: BackupFileInfo?
    let error: BackupError?
    let duration: TimeInterval
    
    init(success: Bool, fileInfo: BackupFileInfo? = nil, error: BackupError? = nil, duration: TimeInterval = 0) {
        self.success = success
        self.fileInfo = fileInfo
        self.error = error
        self.duration = duration
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

// MARK: - Data Compression Extensions

extension Data {
    func compressed(algorithm: compression_algorithm) throws -> Data {
        return try self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, self.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
                nil, algorithm
            )
            
            guard compressedSize > 0 else {
                throw BackupError.compressionFailed("Compression failed")
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    func decompressed(algorithm: compression_algorithm) throws -> Data {
        return try self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count * 4) // Estimate
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, self.count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
                nil, algorithm
            )
            
            guard decompressedSize > 0 else {
                throw BackupError.compressionFailed("Decompression failed")
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
}
