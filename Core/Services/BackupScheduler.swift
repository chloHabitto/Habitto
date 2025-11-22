import BackgroundTasks
import Foundation
import Network
import OSLog
import UIKit

// MARK: - BackupFrequency

enum BackupFrequency: String, CaseIterable, Codable {
  case manual
  case daily
  case weekly
  case monthly

  // MARK: Internal

  var displayName: String {
    switch self {
    case .manual:
      "Manual Only"
    case .daily:
      "Daily"
    case .weekly:
      "Weekly"
    case .monthly:
      "Monthly"
    }
  }

  var timeInterval: TimeInterval {
    switch self {
    case .manual:
      0 // No automatic scheduling
    case .daily:
      24 * 60 * 60 // 24 hours
    case .weekly:
      7 * 24 * 60 * 60 // 7 days
    case .monthly:
      30 * 24 * 60 * 60 // 30 days (approximate)
    }
  }
}

// MARK: - NetworkCondition

enum NetworkCondition: String, CaseIterable, Codable {
  case any
  case wifiOnly = "wifi_only"

  // MARK: Internal

  var displayName: String {
    switch self {
    case .any:
      "Any Network"
    case .wifiOnly:
      "WiFi Only"
    }
  }
}

// MARK: - BackupScheduleConfig

struct BackupScheduleConfig: Codable {
  // MARK: Lifecycle

  init(
    isEnabled: Bool = true,
    frequency: BackupFrequency = .daily,
    networkCondition: NetworkCondition = .wifiOnly,
    preferredTime: Date = Calendar.current
      .date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date(),
    lastBackupDate: Date? = nil,
    nextScheduledDate: Date? = nil)
  {
    self.isEnabled = isEnabled
    self.frequency = frequency
    self.networkCondition = networkCondition
    self.preferredTime = preferredTime
    self.lastBackupDate = lastBackupDate
    self.nextScheduledDate = nextScheduledDate
  }

  // MARK: Internal

  var isEnabled: Bool
  var frequency: BackupFrequency
  var networkCondition: NetworkCondition
  var preferredTime: Date // Time of day for backups
  var lastBackupDate: Date?
  var nextScheduledDate: Date?
}

// MARK: - Background Task Identifiers

extension String {
  fileprivate static let backupTaskIdentifier = "com.habitto.app.backup"
  fileprivate static let backupRefreshIdentifier = "com.habitto.app.backup.refresh"
}

// MARK: - BackupScheduler

/// Manages automatic backup scheduling using iOS background tasks
@MainActor
class BackupScheduler: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  private init() {
    // Load saved configuration
    self.scheduleConfig = Self.loadScheduleConfig()

    // Start network monitoring
    startNetworkMonitoring()

    // Register background tasks
    registerBackgroundTasks()

    // Update next backup date
    updateNextBackupDate()
  }

  // MARK: Internal

  static let shared = BackupScheduler()

  @Published var scheduleConfig: BackupScheduleConfig
  @Published var isScheduled = false
  @Published var nextBackupDate: Date?
  @Published var lastBackupAttempt: Date?
  @Published var networkStatus: NetworkCondition = .any

  /// Load schedule configuration
  static func loadScheduleConfig() -> BackupScheduleConfig {
    let userDefaults = UserDefaults.standard
    let userId = AuthenticationManager.shared.currentUser?.uid ?? "guest_user"
    let userKey = "\(userId)_BackupScheduleConfig"

    if let data = userDefaults.data(forKey: userKey),
       let config = try? JSONDecoder().decode(BackupScheduleConfig.self, from: data)
    {
      return config
    }

    return BackupScheduleConfig() // Default configuration
  }

  // MARK: - Public Methods

  /// Update backup schedule configuration
  func updateSchedule(
    isEnabled: Bool? = nil,
    frequency: BackupFrequency? = nil,
    networkCondition: NetworkCondition? = nil,
    preferredTime: Date? = nil)
  {
    var config = scheduleConfig

    if let isEnabled {
      config.isEnabled = isEnabled
    }
    if let frequency {
      config.frequency = frequency
    }
    if let networkCondition {
      config.networkCondition = networkCondition
    }
    if let preferredTime {
      config.preferredTime = preferredTime
    }

    scheduleConfig = config
    saveScheduleConfig()

    if config.isEnabled {
      scheduleNextBackup()
    } else {
      cancelScheduledBackup()
    }

    logger
      .info(
        "Backup schedule updated: enabled=\(config.isEnabled), frequency=\(config.frequency.rawValue)")
  }

  /// Check if backup should run now
  func shouldRunBackup() -> Bool {
    guard scheduleConfig.isEnabled else { return false }
    guard scheduleConfig.frequency != .manual else { return false }
    guard authManager.currentUser != nil else { return false }

    // Check if enough time has passed since last backup
    if let lastBackup = scheduleConfig.lastBackupDate {
      let timeSinceLastBackup = Date().timeIntervalSince(lastBackup)
      if timeSinceLastBackup < scheduleConfig.frequency.timeInterval {
        return false
      }
    }

    // Check network condition
    if scheduleConfig.networkCondition == .wifiOnly, networkStatus != .wifiOnly {
      logger.info("Backup skipped: WiFi required but not available")
      return false
    }

    return true
  }

  /// Run backup if conditions are met
  func runScheduledBackup() async -> Bool {
    guard shouldRunBackup() else {
      logger.info("Backup conditions not met, skipping scheduled backup")
      return false
    }

    logger.info("Starting scheduled backup")
    lastBackupAttempt = Date()

    do {
      let snapshot = try await backupManager.createBackup()

      // Update last backup date
      scheduleConfig.lastBackupDate = snapshot.createdAt
      saveScheduleConfig()

      // Schedule next backup
      scheduleNextBackup()

      logger.info("Scheduled backup completed successfully: \(snapshot.id)")
      return true

    } catch {
      logger.error("Scheduled backup failed: \(error.localizedDescription)")

      // Schedule retry for later
      scheduleRetryBackup()

      return false
    }
  }

  /// Schedule next backup based on frequency
  func scheduleNextBackup() {
    guard scheduleConfig.isEnabled, scheduleConfig.frequency != .manual else {
      isScheduled = false
      nextBackupDate = nil
      return
    }

    let nextDate = calculateNextBackupDate()
    scheduleConfig.nextScheduledDate = nextDate
    nextBackupDate = nextDate

    // Schedule background task
    scheduleBackgroundTask(for: nextDate)

    isScheduled = true
    saveScheduleConfig()

    logger.info("Next backup scheduled for: \(nextDate)")
  }

  /// Cancel scheduled backup
  func cancelScheduledBackup() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: .backupTaskIdentifier)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: .backupRefreshIdentifier)

    isScheduled = false
    nextBackupDate = nil
    scheduleConfig.nextScheduledDate = nil
    saveScheduleConfig()

    logger.info("Scheduled backup cancelled")
  }

  /// Force immediate backup (manual)
  func runManualBackup() async -> Bool {
    guard authManager.currentUser != nil else {
      logger.error("Manual backup failed: User not authenticated")
      return false
    }

    logger.info("Starting manual backup")
    lastBackupAttempt = Date()

    do {
      let snapshot = try await backupManager.createBackup()
      logger.info("Manual backup completed successfully: \(snapshot.id)")
      return true
    } catch {
      logger.error("Manual backup failed: \(error.localizedDescription)")
      return false
    }
  }

  /// Save schedule configuration
  func saveScheduleConfig() {
    let userKey = getUserSpecificKey(scheduleConfigKey)
    if let data = try? JSONEncoder().encode(scheduleConfig) {
      userDefaults.set(data, forKey: userKey)
    }
  }

  // MARK: Private

  private let logger = Logger(subsystem: "com.habitto.app", category: "BackupScheduler")
  private let userDefaults = UserDefaults.standard
  private let networkMonitor = NWPathMonitor()
  private let networkQueue = DispatchQueue(label: "NetworkMonitor")
  private let backupManager = BackupManager.shared
  private let authManager = AuthenticationManager.shared

  // MARK: - Keys

  private let scheduleConfigKey = "BackupScheduleConfig"

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

  // MARK: - Private Methods

  /// Calculate next backup date based on frequency and preferred time
  private func calculateNextBackupDate() -> Date {
    let calendar = Calendar.current
    let now = Date()

    // Get preferred time components
    let preferredComponents = calendar.dateComponents(
      [.hour, .minute],
      from: scheduleConfig.preferredTime)

    // Calculate base date (now + frequency interval)
    let baseDate = now.addingTimeInterval(scheduleConfig.frequency.timeInterval)

    // Set to preferred time
    var nextDateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
    nextDateComponents.hour = preferredComponents.hour
    nextDateComponents.minute = preferredComponents.minute
    nextDateComponents.second = 0

    let nextDate = calendar.date(from: nextDateComponents) ?? baseDate

    // If the calculated time is in the past, move to next day
    if nextDate <= now {
      return calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
    }

    return nextDate
  }

  /// Schedule background task for specific date
  private func scheduleBackgroundTask(for date: Date) {
    let request = BGAppRefreshTaskRequest(identifier: .backupTaskIdentifier)
    request.earliestBeginDate = date

    do {
      try BGTaskScheduler.shared.submit(request)
      logger.info("Background task scheduled for: \(date)")
    } catch {
      logger.error("Failed to schedule background task: \(error.localizedDescription)")
    }
  }

  /// Schedule retry backup (exponential backoff)
  private func scheduleRetryBackup() {
    let retryDelay: TimeInterval = 2 * 60 * 60 // 2 hours
    let retryDate = Date().addingTimeInterval(retryDelay)

    let request = BGAppRefreshTaskRequest(identifier: .backupRefreshIdentifier)
    request.earliestBeginDate = retryDate

    do {
      try BGTaskScheduler.shared.submit(request)
      logger.info("Retry backup scheduled for: \(retryDate)")
    } catch {
      logger.error("Failed to schedule retry backup: \(error.localizedDescription)")
    }
  }

  /// Start network monitoring
  private func startNetworkMonitoring() {
    networkMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.updateNetworkStatus(path)
      }
    }
    networkMonitor.start(queue: networkQueue)
  }

  /// Update network status based on current path
  private func updateNetworkStatus(_ path: NWPath) {
    if path.usesInterfaceType(.wifi) {
      self.networkStatus = .wifiOnly
    } else if path.status == .satisfied {
      self.networkStatus = .any
    } else {
      self.networkStatus = .any // Default to any when no connection
    }

    logger.debug("Network status updated: \(self.networkStatus.rawValue)")
  }

  /// Register background tasks
  private func registerBackgroundTasks() {
    BGTaskScheduler.shared
      .register(forTaskWithIdentifier: .backupTaskIdentifier, using: nil) { task in
        self.handleBackupTask(task: task as! BGAppRefreshTask)
      }

    BGTaskScheduler.shared
      .register(forTaskWithIdentifier: .backupRefreshIdentifier, using: nil) { task in
        self.handleBackupRefreshTask(task: task as! BGAppRefreshTask)
      }
  }

  /// Handle main backup task
  private func handleBackupTask(task: BGAppRefreshTask) {
    logger.info("Background backup task started")

    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      self.logger.warning("Background backup task expired")
    }

    Task {
      let success = await runScheduledBackup()
      task.setTaskCompleted(success: success)

      if success {
        self.logger.info("Background backup task completed successfully")
      } else {
        self.logger.error("Background backup task failed")
      }
    }
  }

  /// Handle backup refresh task (retry)
  private func handleBackupRefreshTask(task: BGAppRefreshTask) {
    logger.info("Background backup refresh task started")

    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      self.logger.warning("Background backup refresh task expired")
    }

    Task {
      let success = await runScheduledBackup()
      task.setTaskCompleted(success: success)

      if success {
        self.logger.info("Background backup refresh task completed successfully")
      } else {
        self.logger.error("Background backup refresh task failed")
      }
    }
  }

  /// Update next backup date
  private func updateNextBackupDate() {
    if let nextDate = scheduleConfig.nextScheduledDate, nextDate > Date() {
      nextBackupDate = nextDate
      isScheduled = true
    } else {
      nextBackupDate = nil
      isScheduled = false
    }
  }
}
