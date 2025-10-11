import FirebaseRemoteConfig
import Foundation

// MARK: - RemoteConfigService

/// Wrapper service for Firebase Remote Config
/// Provides feature flags and dynamic configuration
class RemoteConfigService: ObservableObject {
  // MARK: Lifecycle

  private init() {
    loadLocalConfig()
    print("🎛️ RemoteConfigService: Initialized")
  }

  // MARK: Internal

  static let shared = RemoteConfigService()

  // MARK: - Published Properties

  @Published var isMigrationEnabled = true
  @Published var minAppVersion = "1.0.0"
  @Published var maxFailureRate = 0.15
  @Published var enableCloudKitSync = false
  @Published var showNewProgressUI = false
  @Published var enableAdvancedAnalytics = false
  @Published var maintenanceMode = false

  // MARK: - Configuration

  /// Fetch and activate remote configuration
  func fetchConfig() async {
    print("🎛️ RemoteConfigService: Fetching remote config...")

    do {
      let remoteConfig = RemoteConfig.remoteConfig()
      _ = try await remoteConfig.fetch()
      try await remoteConfig.activate()

      // Update local values
      updateFromRemoteConfig(remoteConfig)

      print("✅ RemoteConfigService: Config fetched and activated")
    } catch {
      print("❌ RemoteConfigService: Failed to fetch config - \(error.localizedDescription)")
      // Fall back to local config
      loadLocalConfig()
    }
  }

  /// Set default values for Remote Config
  func setDefaults() {
    let remoteConfig = RemoteConfig.remoteConfig()
    remoteConfig.setDefaults([
      "isMigrationEnabled": true as NSObject,
      "minAppVersion": "1.0.0" as NSObject,
      "maxFailureRate": 0.15 as NSObject,
      "enableCloudKitSync": false as NSObject,
      "showNewProgressUI": false as NSObject,
      "enableAdvancedAnalytics": false as NSObject,
      "maintenanceMode": false as NSObject,
    ])

    print("🎛️ RemoteConfigService: Defaults set")
  }

  // MARK: - Getters

  /// Check if a feature is enabled
  func isFeatureEnabled(_ feature: String) -> Bool {
    switch feature {
    case "migration":
      return isMigrationEnabled
    case "cloudkit_sync":
      return enableCloudKitSync
    case "new_progress_ui":
      return showNewProgressUI
    case "advanced_analytics":
      return enableAdvancedAnalytics
    default:
      return false
    }
  }

  /// Get minimum supported app version
  func getMinimumVersion() -> String {
    minAppVersion
  }

  /// Check if app is in maintenance mode
  func isMaintenanceMode() -> Bool {
    maintenanceMode
  }

  // MARK: Private

  // MARK: - Private Methods

  /// Load configuration from local JSON file (fallback)
  private func loadLocalConfig() {
    guard let url = Bundle.main.url(forResource: "remote_config", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      print("⚠️ RemoteConfigService: Failed to load local config, using defaults")
      return
    }

    // Parse local config
    if let enabled = json["isMigrationEnabled"] as? Bool {
      isMigrationEnabled = enabled
    }
    if let version = json["minAppVersion"] as? String {
      minAppVersion = version
    }
    if let rate = json["maxFailureRate"] as? Double {
      maxFailureRate = rate
    }

    print("✅ RemoteConfigService: Loaded local config fallback")
  }

  /// Update properties from Remote Config
  private func updateFromRemoteConfig(_ remoteConfig: RemoteConfig) {
    isMigrationEnabled = remoteConfig["isMigrationEnabled"].boolValue
    minAppVersion = remoteConfig["minAppVersion"].stringValue
    maxFailureRate = remoteConfig["maxFailureRate"].numberValue.doubleValue
    enableCloudKitSync = remoteConfig["enableCloudKitSync"].boolValue
    showNewProgressUI = remoteConfig["showNewProgressUI"].boolValue
    enableAdvancedAnalytics = remoteConfig["enableAdvancedAnalytics"].boolValue
    maintenanceMode = remoteConfig["maintenanceMode"].boolValue

    print("🎛️ RemoteConfigService: Updated from remote config:")
    print("  - Migration enabled: \(isMigrationEnabled)")
    print("  - CloudKit sync: \(enableCloudKitSync)")
    print("  - Maintenance mode: \(maintenanceMode)")
  }
}

// MARK: - Feature Flag Keys

enum RemoteConfigKey: String {
  case isMigrationEnabled = "isMigrationEnabled"
  case minAppVersion = "minAppVersion"
  case maxFailureRate = "maxFailureRate"
  case enableCloudKitSync = "enableCloudKitSync"
  case showNewProgressUI = "showNewProgressUI"
  case enableAdvancedAnalytics = "enableAdvancedAnalytics"
  case maintenanceMode = "maintenanceMode"
}

