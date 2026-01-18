import Combine
import Foundation
import UIKit

// MARK: - EnhancedMigrationTelemetryManager

// Robust telemetry with Firebase Remote Config, local overrides, and comprehensive monitoring

@MainActor
class EnhancedMigrationTelemetryManager: ObservableObject {
  // MARK: Lifecycle

  // MARK: - Initialization

  private init() {
    loadLocalConfig()
    setupPeriodicConfigFetch()
  }

  // MARK: Internal

  // MARK: - Remote Config Structure

  struct RemoteConfig: Codable {
    // MARK: Lifecycle

    init(
      isMigrationEnabled: Bool,
      minAppVersion: String?,
      maxFailureRate: Double,
      configVersion: String,
      lastUpdated: Date
    ) {
      self.isMigrationEnabled = isMigrationEnabled
      self.minAppVersion = minAppVersion
      self.maxFailureRate = maxFailureRate
      self.configVersion = configVersion
      self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.isMigrationEnabled = try container.decodeIfPresent(
        Bool.self,
        forKey: .isMigrationEnabled) ?? true
      self.minAppVersion = try container.decodeIfPresent(String.self, forKey: .minAppVersion)
      self.maxFailureRate = try container
        .decodeIfPresent(Double.self, forKey: .maxFailureRate) ?? 0.1
      self.configVersion = try container.decodeIfPresent(String.self, forKey: .configVersion) ?? "1.0.0"
      self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
      case isMigrationEnabled
      case minAppVersion
      case maxFailureRate
      case configVersion
      case lastUpdated
    }

    let isMigrationEnabled: Bool
    let minAppVersion: String?
    let maxFailureRate: Double?
    let configVersion: String
    let lastUpdated: Date
  }

  // MARK: - Telemetry Events

  struct TelemetryEvent: Codable, Identifiable {
    // MARK: Lifecycle

    init(
      eventType: EventType,
      timestamp: Date,
      version: String,
      duration: TimeInterval? = nil,
      errorCode: String? = nil,
      datasetSize: Int? = nil,
      success: Bool,
      deviceInfo: DeviceInfo)
    {
      self.id = UUID()
      self.eventType = eventType
      self.timestamp = timestamp
      self.version = version
      self.duration = duration
      self.errorCode = errorCode
      self.datasetSize = datasetSize
      self.success = success
      self.deviceInfo = deviceInfo
    }

    // MARK: Internal

    enum EventType: String, Codable {
      case migrationStart = "migration_start"
      case migrationEndSuccess = "migration_end_success"
      case migrationEndFailure = "migration_end_failure"
      case configFetch = "config_fetch"
      case killSwitchTriggered = "kill_switch_triggered"
    }

    struct DeviceInfo: Codable {
      // MARK: Lifecycle

      @MainActor
      init() {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.iosVersion = Self.getSystemVersion()
        self.deviceModel = Self.getDeviceModel()
        self.freeDiskSpace = Self.getFreeDiskSpace()
      }

      // MARK: Internal

      let appVersion: String
      let iosVersion: String
      let deviceModel: String
      let freeDiskSpace: Int64?

      // MARK: Private

      @MainActor
      private static func getSystemVersion() -> String {
        UIDevice.current.systemVersion
      }

      @MainActor
      private static func getDeviceModel() -> String {
        UIDevice.current.model
      }

      private static func getFreeDiskSpace() -> Int64? {
        do {
          let attributes = try FileManager.default
            .attributesOfFileSystem(forPath: NSHomeDirectory())
          return attributes[.systemFreeSize] as? Int64
        } catch {
          return nil
        }
      }
    }

    let id: UUID
    let eventType: EventType
    let timestamp: Date
    let version: String
    let duration: TimeInterval?
    let errorCode: String?
    let datasetSize: Int?
    let success: Bool
    let deviceInfo: DeviceInfo
  }

  static let shared = EnhancedMigrationTelemetryManager()

  @Published var isMigrationEnabled = true
  @Published var remoteConfigLoaded = false
  @Published var lastConfigUpdate: Date?

  // MARK: - Public Interface

  func checkMigrationEnabled() async -> Bool {
    // Check local override first (highest priority)
    if let localOverride = getLocalOverride() {
      return localOverride
    }

    // Check remote config
    if !remoteConfigLoaded {
      await fetchRemoteConfig()
    }

    // Check failure rate
    if isFailureRateTooHigh() {
      await recordEvent(
        .killSwitchTriggered,
        duration: nil,
        errorCode: "high_failure_rate",
        datasetSize: nil,
        success: false)
      return false
    }

    return isMigrationEnabled
  }

  func recordEvent(
    _ eventType: TelemetryEvent.EventType,
    duration: TimeInterval? = nil,
    errorCode: String? = nil,
    datasetSize: Int? = nil,
    success: Bool) async
  {
    let event = TelemetryEvent(
      eventType: eventType,
      timestamp: Date(),
      version: getCurrentAppVersion(),
      duration: duration,
      errorCode: errorCode,
      datasetSize: datasetSize,
      success: success,
      deviceInfo: TelemetryEvent.DeviceInfo())

    storeEvent(event)
    pruneOldEvents()

    print("📊 Telemetry: \(eventType.rawValue) - \(success ? "SUCCESS" : "FAILURE")")
  }

  func setLocalOverride(_ enabled: Bool?) {
    if let enabled {
      userDefaults.set(enabled, forKey: localOverrideKey)
      print("🔧 Local override set: \(enabled)")
    } else {
      userDefaults.removeObject(forKey: localOverrideKey)
      print("🔧 Local override cleared")
    }
  }

  func getFailureRate() -> Double {
    let events = getStoredEvents()
    let recentEvents = events.filter { Date().timeIntervalSince($0.timestamp) < 3600 } // Last hour

    guard !recentEvents.isEmpty else { return 0.0 }

    let failureCount = recentEvents.filter { !$0.success }.count
    return Double(failureCount) / Double(recentEvents.count)
  }

  // MARK: - Private Methods

  func fetchRemoteConfig() async {
    guard configTask == nil else { return }

    configTask = Task {
      var remoteFetchSuccessful = false

      for urlString in remoteConfigURLs {
        do {
          guard let url = URL(string: urlString) else { continue }
          let (data, _) = try await URLSession.shared.data(from: url)
          let config = try JSONDecoder().decode(RemoteConfig.self, from: data)

          await MainActor.run {
            self.applyRemoteConfig(config)
          }

          await recordEvent(.configFetch, success: true)
          remoteFetchSuccessful = true
          break

        } catch {
          print("⚠️ Failed to fetch config from \(urlString): \(error)")
          await recordEvent(.configFetch, errorCode: error.localizedDescription, success: false)
        }
      }

      // If all remote sources failed, use default config
      if !remoteFetchSuccessful {
        print("⚠️ All remote config sources failed, using default config")
        await MainActor.run {
          self.applyDefaultConfig()
        }
        await recordEvent(.configFetch, errorCode: "All remote sources failed", success: false)
      }

      configTask = nil
    }

    await configTask?.value
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let telemetryKey = "MigrationTelemetryEvents"
  private let configKey = "MigrationConfig"
  private let localOverrideKey = "MigrationLocalOverride"

  /// Remote config endpoints (with fallbacks)
  private let remoteConfigURLs = [
    "https://raw.githubusercontent.com/chloe-lee/Habitto/main/remote_config.json",
    "https://habitto-config.s3.amazonaws.com/remote_config.json",
    "https://habitto-config.firebaseapp.com/remote_config.json"
  ]

  /// Local default config (used when remote fails)
  private let defaultConfig = RemoteConfig(
    isMigrationEnabled: true,
    minAppVersion: nil,
    maxFailureRate: 0.15,
    configVersion: "1.0.0",
    lastUpdated: Date()
  )

  // Local TTL cache
  private let configTTL: TimeInterval = 300 // 5 minutes
  private let maxRetries = 3

  // Kill switch thresholds (documented for support)
  private let criticalFailureThreshold = 0.01 // 1% critical failures
  private let totalFailureThreshold = 0.03 // 3% total failures
  private let evaluationWindow: TimeInterval = 3600 // 1 hour window
  private var configTask: Task<Void, Never>?

  private func applyRemoteConfig(_ config: RemoteConfig) {
    // Check app version compatibility
    if let minVersion = config.minAppVersion {
      if !isAppVersionCompatible(minVersion) {
        print("⚠️ App version too old for remote config")
        return
      }
    }

    // Apply config
    isMigrationEnabled = config.isMigrationEnabled
    remoteConfigLoaded = true
    lastConfigUpdate = config.lastUpdated

    // Store config locally
    if let data = try? JSONEncoder().encode(config) {
      userDefaults.set(data, forKey: configKey)
    }

    print("✅ Remote config applied: migration enabled = \(isMigrationEnabled)")
  }

  private func applyDefaultConfig() {
    // Apply default config when remote sources fail
    isMigrationEnabled = defaultConfig.isMigrationEnabled
    remoteConfigLoaded = false // Mark as not loaded from remote
    lastConfigUpdate = defaultConfig.lastUpdated

    // Store default config locally
    if let data = try? JSONEncoder().encode(defaultConfig) {
      userDefaults.set(data, forKey: configKey)
    }

    print("✅ Default config applied: migration enabled = \(isMigrationEnabled)")
  }

  private func loadLocalConfig() {
    // Load cached remote config
    if let data = userDefaults.data(forKey: configKey),
       let config = try? JSONDecoder().decode(RemoteConfig.self, from: data)
    {
      // Check if config is still fresh
      if Date().timeIntervalSince(config.lastUpdated) < configTTL {
        isMigrationEnabled = config.isMigrationEnabled
        remoteConfigLoaded = true
        lastConfigUpdate = config.lastUpdated
        print("✅ Loaded cached remote config")
      }
    }
  }

  private func setupPeriodicConfigFetch() {
    // Fetch config every 5 minutes
    Timer.scheduledTimer(withTimeInterval: configTTL, repeats: true) { _ in
      Task { @MainActor in
        await self.fetchRemoteConfig()
      }
    }
  }

  private func getLocalOverride() -> Bool? {
    guard userDefaults.object(forKey: localOverrideKey) != nil else { return nil }
    return userDefaults.bool(forKey: localOverrideKey)
  }

  private func isFailureRateTooHigh() -> Bool {
    let failureRate = getFailureRate()
    let criticalRate = getCriticalFailureRate()

    // Check both thresholds: >1% critical failures or >3% total failures in 1h window
    return failureRate > totalFailureThreshold || criticalRate > criticalFailureThreshold
  }

  private func getCriticalFailureRate() -> Double {
    let recentEvents = getStoredEvents().filter {
      Date().timeIntervalSince($0.timestamp) <= evaluationWindow
    }
    let criticalFailures = recentEvents.filter {
      // This would need to be enhanced to check for critical failures specifically
      !$0.success && $0.eventType == .migrationEndFailure
    }
    return Double(criticalFailures.count) / Double(max(recentEvents.count, 1))
  }

  private func isAppVersionCompatible(_ minVersion: String) -> Bool {
    let currentVersion = getCurrentAppVersion()
    return currentVersion.compare(minVersion, options: .numeric) != .orderedAscending
  }

  private func getCurrentAppVersion() -> String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  }

  private func storeEvent(_ event: TelemetryEvent) {
    var events = getStoredEvents()
    events.append(event)

    // Keep only last 1000 events
    if events.count > 1000 {
      events = Array(events.suffix(1000))
    }

    if let data = try? JSONEncoder().encode(events) {
      userDefaults.set(data, forKey: telemetryKey)
    }
  }

  private func getStoredEvents() -> [TelemetryEvent] {
    guard let data = userDefaults.data(forKey: telemetryKey),
          let events = try? JSONDecoder().decode([TelemetryEvent].self, from: data) else
    {
      return []
    }
    return events
  }

  private func pruneOldEvents() {
    var events = getStoredEvents()
    let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days ago

    events = events.filter { $0.timestamp > cutoffDate }

    if let data = try? JSONEncoder().encode(events) {
      userDefaults.set(data, forKey: telemetryKey)
    }
  }
}

// MARK: - Developer Settings Integration

extension EnhancedMigrationTelemetryManager {
  struct DeveloperSettings {
    let telemetryManager: EnhancedMigrationTelemetryManager

    @MainActor
    var failureRate: Double {
      telemetryManager.getFailureRate()
    }

    @MainActor
    var eventCount: Int {
      telemetryManager.getStoredEvents().count
    }

    @MainActor
    var lastConfigUpdate: Date? {
      telemetryManager.lastConfigUpdate
    }

    @MainActor
    var remoteConfigLoaded: Bool {
      telemetryManager.remoteConfigLoaded
    }

    func clearTelemetry() {
      UserDefaults.standard.removeObject(forKey: "MigrationTelemetryEvents")
    }

    func forceConfigRefresh() {
      Task { @MainActor in
        await telemetryManager.fetchRemoteConfig()
      }
    }

    @MainActor
    func setMigrationOverride(_ enabled: Bool?) {
      telemetryManager.setLocalOverride(enabled)
    }
  }

  var developerSettings: DeveloperSettings {
    DeveloperSettings(telemetryManager: self)
  }
}
