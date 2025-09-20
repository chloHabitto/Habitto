import Foundation
import OSLog
import UIKit

/// Manages cloud storage operations for backup files
/// Supports iCloud Drive integration with local fallback
@MainActor
final class CloudStorageManager: ObservableObject {
    
    // MARK: - Properties
    
    static let shared = CloudStorageManager()
    
    private let logger = Logger(subsystem: "com.habitto.app", category: "CloudStorageManager")
    
    @Published var isiCloudAvailable: Bool = false
    @Published var isiCloudEnabled: Bool = false
    @Published var lastSyncStatus: SyncStatus = .unknown
    
    private var iCloudDocumentsURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    // MARK: - Initialization
    
    private init() {
        checkiCloudAvailability()
        setupiCloudObserver()
    }
    
    // MARK: - iCloud Availability
    
    /// Check if iCloud Drive is available and enabled
    func checkiCloudAvailability() {
        guard iCloudDocumentsURL != nil else {
            logger.warning("iCloud container not available")
            isiCloudAvailable = false
            isiCloudEnabled = false
            return
        }
        
        // Check if iCloud Drive is enabled
        if FileManager.default.ubiquityIdentityToken != nil {
            isiCloudAvailable = true
            isiCloudEnabled = true
            logger.info("iCloud Drive is available and enabled")
        } else {
            isiCloudAvailable = true
            isiCloudEnabled = false
            logger.info("iCloud Drive is available but not enabled")
        }
    }
    
    /// Setup observer for iCloud availability changes
    private func setupiCloudObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkiCloudAvailability()
            }
        }
    }
    
    // MARK: - Cloud Storage Operations
    
    /// Upload backup file to iCloud Drive
    func uploadToiCloud(_ backupData: Data, filename: String) async throws -> CloudUploadResult {
        guard isiCloudEnabled else {
            throw CloudStorageError.iCloudNotEnabled
        }
        
        guard let iCloudURL = iCloudDocumentsURL else {
            throw CloudStorageError.iCloudUnavailable
        }
        
        let backupDirectory = iCloudURL.appendingPathComponent("HabittoBackups")
        let fileURL = backupDirectory.appendingPathComponent(filename)
        
        // Ensure backup directory exists
        try await ensureDirectoryExists(backupDirectory)
        
        // Write file to iCloud Drive
        try backupData.write(to: fileURL)
        
        // Start iCloud sync
        try await startiCloudSync(for: fileURL)
        
        logger.info("Successfully uploaded backup to iCloud: \(filename)")
        
        return CloudUploadResult(
            fileURL: fileURL,
            cloudPath: fileURL.path,
            uploadDate: Date(),
            fileSize: backupData.count
        )
    }
    
    /// Download backup file from iCloud Drive
    func downloadFromiCloud(filename: String) async throws -> Data {
        guard let iCloudURL = iCloudDocumentsURL else {
            throw CloudStorageError.iCloudUnavailable
        }
        
        let fileURL = iCloudURL
            .appendingPathComponent("HabittoBackups")
            .appendingPathComponent(filename)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CloudStorageError.fileNotFound
        }
        
        // Ensure file is downloaded from iCloud
        try await ensureFileDownloaded(fileURL)
        
        // Read file data
        let data = try Data(contentsOf: fileURL)
        
        logger.info("Successfully downloaded backup from iCloud: \(filename)")
        
        return data
    }
    
    /// List available backup files in iCloud Drive
    func listiCloudBackups() async throws -> [CloudBackupFile] {
        guard let iCloudURL = iCloudDocumentsURL else {
            throw CloudStorageError.iCloudUnavailable
        }
        
        let backupDirectory = iCloudURL.appendingPathComponent("HabittoBackups")
        
        // Ensure directory exists
        try await ensureDirectoryExists(backupDirectory)
        
        // List files in backup directory
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: []
        )
        
        let backupFiles = try fileURLs.compactMap { url -> CloudBackupFile? in
            guard url.pathExtension == "habitto" else { return nil }
            
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .creationDateKey,
                .contentModificationDateKey
            ])
            
            return CloudBackupFile(
                filename: url.lastPathComponent,
                cloudPath: url.path,
                fileSize: resourceValues.fileSize ?? 0,
                createdDate: resourceValues.creationDate ?? Date(),
                modifiedDate: resourceValues.contentModificationDate ?? Date()
            )
        }
        
        logger.info("Found \(backupFiles.count) backup files in iCloud")
        
        return backupFiles.sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Delete backup file from iCloud Drive
    func deleteFromiCloud(filename: String) async throws {
        guard let iCloudURL = iCloudDocumentsURL else {
            throw CloudStorageError.iCloudUnavailable
        }
        
        let fileURL = iCloudURL
            .appendingPathComponent("HabittoBackups")
            .appendingPathComponent(filename)
        
        try FileManager.default.removeItem(at: fileURL)
        
        logger.info("Successfully deleted backup from iCloud: \(filename)")
    }
    
    // MARK: - Local Storage Fallback
    
    /// Store backup locally when cloud services are unavailable
    func storeLocally(_ backupData: Data, filename: String) throws -> LocalBackupFile {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDirectory = documentsURL.appendingPathComponent("LocalBackups")
        
        // Ensure backup directory exists
        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let fileURL = backupDirectory.appendingPathComponent(filename)
        
        // Write file locally
        try backupData.write(to: fileURL)
        
        logger.info("Successfully stored backup locally: \(filename)")
        
        return LocalBackupFile(
            filename: filename,
            localPath: fileURL.path,
            fileSize: backupData.count,
            createdDate: Date()
        )
    }
    
    /// List local backup files
    func listLocalBackups() throws -> [LocalBackupFile] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDirectory = documentsURL.appendingPathComponent("LocalBackups")
        
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            return []
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: []
        )
        
        let backupFiles = try fileURLs.compactMap { url -> LocalBackupFile? in
            guard url.pathExtension == "habitto" else { return nil }
            
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .creationDateKey
            ])
            
            return LocalBackupFile(
                filename: url.lastPathComponent,
                localPath: url.path,
                fileSize: resourceValues.fileSize ?? 0,
                createdDate: resourceValues.creationDate ?? Date()
            )
        }
        
        logger.info("Found \(backupFiles.count) local backup files")
        
        return backupFiles.sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Delete local backup file
    func deleteLocalBackup(filename: String) throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL
            .appendingPathComponent("LocalBackups")
            .appendingPathComponent(filename)
        
        try FileManager.default.removeItem(at: fileURL)
        
        logger.info("Successfully deleted local backup: \(filename)")
    }
    
    // MARK: - Sync Management
    
    /// Start iCloud sync for a specific file
    private func startiCloudSync(for fileURL: URL) async throws {
        // Set file attributes to trigger iCloud sync
        try FileManager.default.setAttributes([
            .modificationDate: Date()
        ], ofItemAtPath: fileURL.path)
        
        // Trigger iCloud sync by accessing the file
        _ = try Data(contentsOf: fileURL)
        
        lastSyncStatus = .syncing
        logger.debug("Started iCloud sync for: \(fileURL.lastPathComponent)")
    }
    
    /// Ensure directory exists in iCloud Drive
    private func ensureDirectoryExists(_ directoryURL: URL) async throws {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    /// Ensure file is downloaded from iCloud
    private func ensureFileDownloaded(_ fileURL: URL) async throws {
        // Start download if needed
        try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        
        // Wait for download to complete (with timeout)
        let timeout = Date().addingTimeInterval(30) // 30 second timeout
        while Date() < timeout {
            // Check if file exists and is readable
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Try to read file to verify it's downloaded
                do {
                    _ = try Data(contentsOf: fileURL)
                    return // File is downloaded and readable
                } catch {
                    // File exists but not readable yet, continue waiting
                }
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        throw CloudStorageError.downloadTimeout
    }
    
    // MARK: - Storage Strategy
    
    /// Determine the best storage strategy based on availability
    func determineStorageStrategy() -> StorageStrategy {
        if isiCloudEnabled {
            return .iCloudPreferred
        } else if isiCloudAvailable {
            return .localWithiCloudOption
        } else {
            return .localOnly
        }
    }
    
    /// Get storage status summary
    func getStorageStatus() -> StorageStatus {
        return StorageStatus(
            isiCloudAvailable: isiCloudAvailable,
            isiCloudEnabled: isiCloudEnabled,
            strategy: determineStorageStrategy(),
            lastSyncStatus: lastSyncStatus
        )
    }
}

// MARK: - Supporting Types

enum CloudStorageError: LocalizedError {
    case iCloudUnavailable
    case iCloudNotEnabled
    case fileNotFound
    case downloadTimeout
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive is not available on this device"
        case .iCloudNotEnabled:
            return "iCloud Drive is not enabled. Please enable it in Settings."
        case .fileNotFound:
            return "Backup file not found in iCloud Drive"
        case .downloadTimeout:
            return "Timeout while downloading file from iCloud"
        case .syncFailed:
            return "Failed to sync file with iCloud Drive"
        }
    }
}

enum StorageStrategy {
    case iCloudPreferred    // Use iCloud with local fallback
    case localWithiCloudOption  // Use local with iCloud as option
    case localOnly          // Use local storage only
}

enum SyncStatus {
    case unknown
    case syncing
    case synced
    case failed
}

struct CloudUploadResult {
    let fileURL: URL
    let cloudPath: String
    let uploadDate: Date
    let fileSize: Int
}

struct CloudBackupFile {
    let filename: String
    let cloudPath: String
    let fileSize: Int
    let createdDate: Date
    let modifiedDate: Date
}

struct LocalBackupFile {
    let filename: String
    let localPath: String
    let fileSize: Int
    let createdDate: Date
}

struct StorageStatus {
    let isiCloudAvailable: Bool
    let isiCloudEnabled: Bool
    let strategy: StorageStrategy
    let lastSyncStatus: SyncStatus
}
