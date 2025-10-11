import Foundation
import OSLog

// MARK: - BackupStorageCoordinator

/// Coordinates backup storage across multiple providers (iCloud, Google Drive, Local)
/// Provides unified interface for backup operations with automatic fallback
@MainActor
final class BackupStorageCoordinator: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  private init() {
    loadConfiguration()
    updateStorageProviderStatus()
  }

  // MARK: Internal

  static let shared = BackupStorageCoordinator()

  // Configuration
  @Published var preferredStorageProvider: StorageProvider = .automatic
  @Published var enableiCloudBackup = true
  @Published var enableGoogleDriveBackup = false
  @Published var enableLocalBackup = true

  // Status
  @Published var lastBackupStatus: BackupStatus = .unknown
  @Published var availableStorageProviders: [StorageProviderStatus] = []

  /// Update storage provider status
  func updateStorageProviderStatus() {
    var providers: [StorageProviderStatus] = []

    // Check iCloud status
    let iCloudStatus = cloudStorageManager.getStorageStatus()
    providers.append(StorageProviderStatus(
      provider: .iCloud,
      isAvailable: iCloudStatus.isiCloudAvailable,
      isEnabled: enableiCloudBackup && iCloudStatus.isiCloudEnabled,
      lastSyncStatus: iCloudStatus.lastSyncStatus,
      strategy: iCloudStatus.strategy))

    // Check Google Drive status
    let googleDriveStatus = googleDriveManager.getIntegrationStatus()
    providers.append(StorageProviderStatus(
      provider: .googleDrive,
      isAvailable: googleDriveStatus.isAvailable,
      isEnabled: enableGoogleDriveBackup && googleDriveStatus.isSignedIn,
      lastSyncStatus: googleDriveStatus.lastSyncStatus,
      strategy: nil))

    // Local storage is always available
    providers.append(StorageProviderStatus(
      provider: .local,
      isAvailable: true,
      isEnabled: enableLocalBackup,
      lastSyncStatus: .synced,
      strategy: nil))

    availableStorageProviders = providers
    logger.debug("Updated storage provider status: \(providers.count) providers")
  }

  // MARK: - Backup Operations

  /// Perform backup with automatic provider selection and fallback
  func performBackup() async throws -> BackupStorageResult {
    logger.info("Starting backup with preferred provider: \(self.preferredStorageProvider.rawValue)")

    // Determine backup providers in order of preference
    let providers = determineBackupProviders()

    var results: [BackupProviderResult] = []
    var primaryResult: BackupProviderResult?

    // Try each provider in order
    for provider in providers {
      do {
        let result = try await performBackupWithProvider(provider)
        results.append(result)

        // First successful backup is primary
        if primaryResult == nil {
          primaryResult = result
        }

        logger.info("Backup successful with \(provider.rawValue)")

      } catch {
        logger.warning("Backup failed with \(provider.rawValue): \(error.localizedDescription)")
        results.append(BackupProviderResult(
          provider: provider,
          success: false,
          error: error,
          fileInfo: nil))
      }
    }

    // Update status
    lastBackupStatus = primaryResult != nil ? .success : .failed

    return BackupStorageResult(
      primaryProvider: primaryResult?.provider,
      results: results,
      timestamp: Date(),
      overallSuccess: primaryResult != nil)
  }

  // MARK: - Restore Operations

  /// List available backups from all providers
  func listAvailableBackups() async throws -> [BackupStorageFileInfo] {
    var allBackups: [BackupStorageFileInfo] = []

    // Get iCloud backups
    if enableiCloudBackup, cloudStorageManager.isiCloudEnabled {
      do {
        let iCloudBackups = try await cloudStorageManager.listiCloudBackups()
        allBackups.append(contentsOf: iCloudBackups.map { BackupStorageFileInfo(
          filename: $0.filename,
          fileSize: $0.fileSize,
          createdDate: $0.createdDate,
          storagePath: $0.cloudPath,
          provider: .iCloud) })
      } catch {
        logger.warning("Failed to list iCloud backups: \(error.localizedDescription)")
      }
    }

    // Get Google Drive backups
    if enableGoogleDriveBackup, googleDriveManager.isSignedIn {
      do {
        let googleBackups = try await googleDriveManager.listGoogleDriveBackups()
        allBackups.append(contentsOf: googleBackups.map { BackupStorageFileInfo(
          filename: $0.fileName,
          fileSize: $0.fileSize,
          createdDate: $0.createdDate,
          storagePath: $0.fileId,
          provider: .googleDrive) })
      } catch {
        logger.warning("Failed to list Google Drive backups: \(error.localizedDescription)")
      }
    }

    // Get local backups
    if enableLocalBackup {
      do {
        let localBackups = try cloudStorageManager.listLocalBackups()
        allBackups.append(contentsOf: localBackups.map { BackupStorageFileInfo(
          filename: $0.filename,
          fileSize: $0.fileSize,
          createdDate: $0.createdDate,
          storagePath: $0.localPath,
          provider: .local) })
      } catch {
        logger.warning("Failed to list local backups: \(error.localizedDescription)")
      }
    }

    // Sort by creation date (newest first)
    return allBackups.sorted { $0.createdDate > $1.createdDate }
  }

  /// Restore backup from specific provider
  func restoreBackup(_ backupFile: BackupStorageFileInfo) async throws -> RestoreResult {
    logger.info("Restoring backup: \(backupFile.filename) from \(backupFile.provider.rawValue)")

    let backupData: Data

    switch backupFile.provider {
    case .iCloud:
      backupData = try await cloudStorageManager.downloadFromiCloud(filename: backupFile.filename)

    case .googleDrive:
      backupData = try await googleDriveManager
        .downloadFromGoogleDrive(fileId: backupFile.storagePath)

    case .local:
      backupData = try Data(contentsOf: URL(fileURLWithPath: backupFile.storagePath))

    case .automatic:
      throw BackupStorageError.invalidProvider
    }

    // Perform restore using BackupManager
    let result = try await backupManager.restoreFromData(backupData)

    return result
  }

  // MARK: - Configuration Management

  /// Update preferred storage provider
  func setPreferredProvider(_ provider: StorageProvider) {
    preferredStorageProvider = provider
    saveConfiguration()
    updateStorageProviderStatus()
    logger.info("Updated preferred storage provider to: \(provider.rawValue)")
  }

  /// Enable/disable specific storage provider
  func setProviderEnabled(_ provider: StorageProvider, enabled: Bool) {
    switch provider {
    case .iCloud:
      enableiCloudBackup = enabled
    case .googleDrive:
      enableGoogleDriveBackup = enabled
    case .local:
      enableLocalBackup = enabled
    case .automatic:
      break // Cannot enable/disable automatic
    }

    saveConfiguration()
    updateStorageProviderStatus()
    logger.info("Set \(provider.rawValue) enabled: \(enabled)")
  }

  /// Get current configuration
  func getConfiguration() -> BackupStorageConfiguration {
    BackupStorageConfiguration(
      preferredProvider: preferredStorageProvider,
      enableiCloud: enableiCloudBackup,
      enableGoogleDrive: enableGoogleDriveBackup,
      enableLocal: enableLocalBackup,
      availableProviders: availableStorageProviders)
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "BackupStorageCoordinator")

  // Storage managers
  private let cloudStorageManager = CloudStorageManager.shared
  private let googleDriveManager = GoogleDriveManager.shared
  private let backupManager = BackupManager.shared

  // MARK: - Configuration

  /// Load backup storage configuration from UserDefaults
  private func loadConfiguration() {
    preferredStorageProvider = StorageProvider(
      rawValue: UserDefaults.standard.string(forKey: "backup_preferred_provider") ?? "automatic") ??
      .automatic

    enableiCloudBackup = UserDefaults.standard.bool(forKey: "backup_enable_icloud")
    enableGoogleDriveBackup = UserDefaults.standard.bool(forKey: "backup_enable_google_drive")
    enableLocalBackup = UserDefaults.standard.bool(forKey: "backup_enable_local")
  }

  /// Save backup storage configuration to UserDefaults
  private func saveConfiguration() {
    UserDefaults.standard.set(
      preferredStorageProvider.rawValue,
      forKey: "backup_preferred_provider")
    UserDefaults.standard.set(enableiCloudBackup, forKey: "backup_enable_icloud")
    UserDefaults.standard.set(enableGoogleDriveBackup, forKey: "backup_enable_google_drive")
    UserDefaults.standard.set(enableLocalBackup, forKey: "backup_enable_local")
  }

  /// Perform backup with specific provider
  private func performBackupWithProvider(_ provider: StorageProvider) async throws
    -> BackupProviderResult
  {
    let backupData = try await backupManager.createBackupData()
    let filename = generateBackupFilename()

    switch provider {
    case .iCloud:
      let uploadResult = try await cloudStorageManager.uploadToiCloud(
        backupData,
        filename: filename)
      return BackupProviderResult(
        provider: .iCloud,
        success: true,
        error: nil,
        fileInfo: BackupStorageFileInfo(
          filename: filename,
          fileSize: uploadResult.fileSize,
          createdDate: uploadResult.uploadDate,
          storagePath: uploadResult.cloudPath,
          provider: .iCloud))

    case .googleDrive:
      let uploadResult = try await googleDriveManager.uploadToGoogleDrive(
        backupData,
        filename: filename)
      return BackupProviderResult(
        provider: .googleDrive,
        success: true,
        error: nil,
        fileInfo: BackupStorageFileInfo(
          filename: filename,
          fileSize: uploadResult.fileSize,
          createdDate: uploadResult.uploadDate,
          storagePath: uploadResult.fileId,
          provider: .googleDrive))

    case .local:
      let localFile = try cloudStorageManager.storeLocally(backupData, filename: filename)
      return BackupProviderResult(
        provider: .local,
        success: true,
        error: nil,
        fileInfo: BackupStorageFileInfo(
          filename: filename,
          fileSize: localFile.fileSize,
          createdDate: localFile.createdDate,
          storagePath: localFile.localPath,
          provider: .local))

    case .automatic:
      // This shouldn't happen as automatic is resolved to specific providers
      throw BackupStorageError.invalidProvider
    }
  }

  /// Determine backup providers in order of preference
  private func determineBackupProviders() -> [StorageProvider] {
    var providers: [StorageProvider] = []

    switch preferredStorageProvider {
    case .automatic:
      // Auto-select based on availability
      if enableiCloudBackup, cloudStorageManager.isiCloudEnabled {
        providers.append(.iCloud)
      }
      if enableGoogleDriveBackup, googleDriveManager.isSignedIn {
        providers.append(.googleDrive)
      }
      if enableLocalBackup {
        providers.append(.local)
      }

    case .iCloud:
      if enableiCloudBackup {
        providers.append(.iCloud)
      }
      // Fallback providers
      if enableGoogleDriveBackup, googleDriveManager.isSignedIn {
        providers.append(.googleDrive)
      }
      if enableLocalBackup {
        providers.append(.local)
      }

    case .googleDrive:
      if enableGoogleDriveBackup {
        providers.append(.googleDrive)
      }
      // Fallback providers
      if enableiCloudBackup, cloudStorageManager.isiCloudEnabled {
        providers.append(.iCloud)
      }
      if enableLocalBackup {
        providers.append(.local)
      }

    case .local:
      if enableLocalBackup {
        providers.append(.local)
      }
      // No fallback for local-only
    }

    // Ensure at least one provider is available
    if providers.isEmpty, enableLocalBackup {
      providers.append(.local)
    }

    return providers
  }

  // MARK: - Utility

  /// Generate unique backup filename
  private func generateBackupFilename() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())
    return "habitto_backup_\(timestamp).habitto"
  }
}

// MARK: - StorageProvider

enum StorageProvider: String, CaseIterable {
  case automatic
  case iCloud = "icloud"
  case googleDrive = "google_drive"
  case local

  // MARK: Internal

  var displayName: String {
    switch self {
    case .automatic: "Automatic"
    case .iCloud: "iCloud Drive"
    case .googleDrive: "Google Drive"
    case .local: "Local Storage"
    }
  }
}

// MARK: - BackupStatus

enum BackupStatus {
  case unknown
  case inProgress
  case success
  case failed
}

// MARK: - BackupStorageError

enum BackupStorageError: LocalizedError {
  case invalidProvider
  case noProvidersAvailable
  case restoreFailed

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .invalidProvider:
      "Invalid storage provider specified"
    case .noProvidersAvailable:
      "No backup storage providers are available"
    case .restoreFailed:
      "Failed to restore backup data"
    }
  }
}

// MARK: - StorageProviderStatus

struct StorageProviderStatus {
  let provider: StorageProvider
  let isAvailable: Bool
  let isEnabled: Bool
  let lastSyncStatus: SyncStatus
  let strategy: StorageStrategy?
}

// MARK: - BackupStorageResult

struct BackupStorageResult {
  let primaryProvider: StorageProvider?
  let results: [BackupProviderResult]
  let timestamp: Date
  let overallSuccess: Bool
}

// MARK: - BackupProviderResult

struct BackupProviderResult {
  let provider: StorageProvider
  let success: Bool
  let error: Error?
  let fileInfo: BackupStorageFileInfo?
}

// MARK: - BackupStorageFileInfo

struct BackupStorageFileInfo {
  let filename: String
  let fileSize: Int
  let createdDate: Date
  let storagePath: String
  let provider: StorageProvider
}

// MARK: - BackupStorageConfiguration

struct BackupStorageConfiguration {
  let preferredProvider: StorageProvider
  let enableiCloud: Bool
  let enableGoogleDrive: Bool
  let enableLocal: Bool
  let availableProviders: [StorageProviderStatus]
}
