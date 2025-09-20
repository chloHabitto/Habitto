import Foundation
import OSLog

/// Centralized manager for backup settings persistence and synchronization
@MainActor
final class BackupSettingsManager: ObservableObject {
    static let shared = BackupSettingsManager()
    
    private let logger = Logger(subsystem: "com.habitto.backup", category: "settings")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Published Properties
    
    @Published var automaticBackupEnabled: Bool = false
    @Published var backupFrequency: BackupFrequency = .weekly
    @Published var wifiOnlyBackup: Bool = false
    @Published var preferredStorageProvider: StorageProvider = .automatic
    @Published var enableiCloudBackup: Bool = true
    @Published var enableGoogleDriveBackup: Bool = false
    @Published var enableLocalBackup: Bool = true
    @Published var backupRetentionDays: Int = 30
    @Published var enableBackupNotifications: Bool = true
    @Published var enableBackupCompression: Bool = true
    @Published var enableBackupEncryption: Bool = false
    @Published var lastBackupDate: Date?
    @Published var nextScheduledBackup: Date?
    
    // MARK: - Private Properties
    
    private let backupScheduler = BackupScheduler.shared
    private let storageCoordinator = BackupStorageCoordinator.shared
    
    private init() {
        loadAllSettings()
        setupObservers()
    }
    
    // MARK: - Settings Management
    
    /// Load all backup settings from UserDefaults
    private func loadAllSettings() {
        let userId = getCurrentUserId()
        
        // Scheduler settings
        let schedulerConfig = BackupScheduler.loadScheduleConfig()
        automaticBackupEnabled = schedulerConfig.isEnabled
        backupFrequency = schedulerConfig.frequency
        wifiOnlyBackup = schedulerConfig.networkCondition == .wifiOnly
        
        // Storage provider settings
        enableiCloudBackup = userDefaults.bool(forKey: "\(userId)_backup_enable_icloud")
        enableGoogleDriveBackup = userDefaults.bool(forKey: "\(userId)_backup_enable_google_drive")
        enableLocalBackup = userDefaults.bool(forKey: "\(userId)_backup_enable_local")
        
        // Advanced settings
        backupRetentionDays = userDefaults.object(forKey: "\(userId)_backup_retention_days") as? Int ?? 30
        enableBackupNotifications = userDefaults.object(forKey: "\(userId)_backup_notifications") as? Bool ?? true
        enableBackupCompression = userDefaults.object(forKey: "\(userId)_backup_compression") as? Bool ?? true
        enableBackupEncryption = userDefaults.object(forKey: "\(userId)_backup_encryption") as? Bool ?? false
        
        // Last backup info
        if let lastBackupTimestamp = userDefaults.object(forKey: "\(userId)_last_backup_date") as? TimeInterval {
            lastBackupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
        }
        
        // Next scheduled backup
        if let nextBackupTimestamp = userDefaults.object(forKey: "\(userId)_next_backup_date") as? TimeInterval {
            nextScheduledBackup = Date(timeIntervalSince1970: nextBackupTimestamp)
        }
        
        logger.debug("Loaded backup settings for user: \(userId)")
    }
    
    /// Save all backup settings to UserDefaults
    func saveAllSettings() {
        let userId = getCurrentUserId()
        
        // Scheduler settings
        backupScheduler.updateSchedule(
            isEnabled: automaticBackupEnabled,
            frequency: backupFrequency,
            networkCondition: wifiOnlyBackup ? .wifiOnly : .any
        )
        
        // Storage provider settings
        userDefaults.set(enableiCloudBackup, forKey: "\(userId)_backup_enable_icloud")
        userDefaults.set(enableGoogleDriveBackup, forKey: "\(userId)_backup_enable_google_drive")
        userDefaults.set(enableLocalBackup, forKey: "\(userId)_backup_enable_local")
        
        // Advanced settings
        userDefaults.set(backupRetentionDays, forKey: "\(userId)_backup_retention_days")
        userDefaults.set(enableBackupNotifications, forKey: "\(userId)_backup_notifications")
        userDefaults.set(enableBackupCompression, forKey: "\(userId)_backup_compression")
        userDefaults.set(enableBackupEncryption, forKey: "\(userId)_backup_encryption")
        
        // Last backup info
        if let lastBackup = lastBackupDate {
            userDefaults.set(lastBackup.timeIntervalSince1970, forKey: "\(userId)_last_backup_date")
        }
        
        // Next scheduled backup
        if let nextBackup = nextScheduledBackup {
            userDefaults.set(nextBackup.timeIntervalSince1970, forKey: "\(userId)_next_backup_date")
        }
        
        // Update storage coordinator
        storageCoordinator.enableiCloudBackup = enableiCloudBackup
        storageCoordinator.enableGoogleDriveBackup = enableGoogleDriveBackup
        storageCoordinator.enableLocalBackup = enableLocalBackup
        
        logger.debug("Saved backup settings for user: \(userId)")
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        automaticBackupEnabled = false
        backupFrequency = .weekly
        wifiOnlyBackup = false
        preferredStorageProvider = .automatic
        enableiCloudBackup = true
        enableGoogleDriveBackup = false
        enableLocalBackup = true
        backupRetentionDays = 30
        enableBackupNotifications = true
        enableBackupCompression = true
        enableBackupEncryption = false
        lastBackupDate = nil
        nextScheduledBackup = nil
        
        saveAllSettings()
        logger.info("Reset all backup settings to defaults")
    }
    
    /// Export settings to JSON
    func exportSettings() -> Data? {
        let settings = BackupSettingsExport(
            automaticBackupEnabled: automaticBackupEnabled,
            backupFrequency: backupFrequency.rawValue,
            wifiOnlyBackup: wifiOnlyBackup,
            preferredStorageProvider: preferredStorageProvider.rawValue,
            enableiCloudBackup: enableiCloudBackup,
            enableGoogleDriveBackup: enableGoogleDriveBackup,
            enableLocalBackup: enableLocalBackup,
            backupRetentionDays: backupRetentionDays,
            enableBackupNotifications: enableBackupNotifications,
            enableBackupCompression: enableBackupCompression,
            enableBackupEncryption: enableBackupEncryption,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
        
        return try? JSONEncoder().encode(settings)
    }
    
    /// Import settings from JSON
    func importSettings(from data: Data) throws {
        let settings = try JSONDecoder().decode(BackupSettingsExport.self, from: data)
        
        automaticBackupEnabled = settings.automaticBackupEnabled
        backupFrequency = BackupFrequency(rawValue: settings.backupFrequency) ?? .weekly
        wifiOnlyBackup = settings.wifiOnlyBackup
        preferredStorageProvider = StorageProvider(rawValue: settings.preferredStorageProvider) ?? .automatic
        enableiCloudBackup = settings.enableiCloudBackup
        enableGoogleDriveBackup = settings.enableGoogleDriveBackup
        enableLocalBackup = settings.enableLocalBackup
        backupRetentionDays = settings.backupRetentionDays
        enableBackupNotifications = settings.enableBackupNotifications
        enableBackupCompression = settings.enableBackupCompression
        enableBackupEncryption = settings.enableBackupEncryption
        
        saveAllSettings()
        logger.info("Imported backup settings from data")
    }
    
    // MARK: - Settings Validation
    
    /// Validate current settings configuration
    func validateSettings() -> [String] {
        var issues: [String] = []
        
        // Check if at least one storage provider is enabled
        if !enableiCloudBackup && !enableGoogleDriveBackup && !enableLocalBackup {
            issues.append("At least one storage provider must be enabled")
        }
        
        // Check backup frequency for automatic backups
        if automaticBackupEnabled && backupFrequency == .manual {
            issues.append("Automatic backup cannot use manual frequency")
        }
        
        // Check retention days
        if backupRetentionDays < 1 || backupRetentionDays > 365 {
            issues.append("Backup retention must be between 1 and 365 days")
        }
        
        // Check if encryption is enabled but no secure storage
        if enableBackupEncryption && !enableiCloudBackup && !enableGoogleDriveBackup {
            issues.append("Encryption requires a secure cloud storage provider")
        }
        
        return issues
    }
    
    // MARK: - Settings Synchronization
    
    /// Update last backup date
    func updateLastBackupDate(_ date: Date) {
        lastBackupDate = date
        let userId = getCurrentUserId()
        userDefaults.set(date.timeIntervalSince1970, forKey: "\(userId)_last_backup_date")
    }
    
    /// Update next scheduled backup date
    func updateNextScheduledBackup(_ date: Date?) {
        nextScheduledBackup = date
        let userId = getCurrentUserId()
        if let date = date {
            userDefaults.set(date.timeIntervalSince1970, forKey: "\(userId)_next_backup_date")
        } else {
            userDefaults.removeObject(forKey: "\(userId)_next_backup_date")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String {
        return AuthenticationManager.shared.currentUser?.uid ?? "guest_user"
    }
    
    private func setupObservers() {
        // Observe authentication changes to reload settings for different users
        NotificationCenter.default.addObserver(
            forName: .authenticationStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadAllSettings()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Settings Export Model

struct BackupSettingsExport: Codable {
    let automaticBackupEnabled: Bool
    let backupFrequency: String
    let wifiOnlyBackup: Bool
    let preferredStorageProvider: String
    let enableiCloudBackup: Bool
    let enableGoogleDriveBackup: Bool
    let enableLocalBackup: Bool
    let backupRetentionDays: Int
    let enableBackupNotifications: Bool
    let enableBackupCompression: Bool
    let enableBackupEncryption: Bool
    let exportDate: Date
    let appVersion: String
}

// MARK: - Notification Names

extension Notification.Name {
    static let authenticationStateChanged = Notification.Name("authenticationStateChanged")
    static let backupSettingsChanged = Notification.Name("backupSettingsChanged")
}
