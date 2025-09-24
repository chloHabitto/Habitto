import Foundation

// MARK: - Feature Flag Types
enum FeatureFlag: String, CaseIterable {
    case challenges = "challenges"
    case themePersistence = "theme_persistence"
    case i18nLocales = "i18n_locales"
    case streakRulesV2 = "streak_rules_v2"
    case cloudKitSync = "cloudkit_sync"
    case fieldLevelEncryption = "field_level_encryption"
    case advancedAnalytics = "advanced_analytics"
    case migrationKillSwitch = "migration_kill_switch"
    
    var defaultValue: Bool {
        switch self {
        case .challenges: return false
        case .themePersistence: return false
        case .i18nLocales: return false
        case .streakRulesV2: return false
        case .cloudKitSync: return false
        case .fieldLevelEncryption: return false
        case .advancedAnalytics: return false
        case .migrationKillSwitch: return true // Default enabled for safety
        }
    }
    
    var description: String {
        switch self {
        case .challenges: return "Habit Challenges Feature"
        case .themePersistence: return "Theme Persistence"
        case .i18nLocales: return "Internationalization Support"
        case .streakRulesV2: return "Advanced Streak Rules"
        case .cloudKitSync: return "CloudKit Synchronization"
        case .fieldLevelEncryption: return "Field-Level Encryption"
        case .advancedAnalytics: return "Advanced Analytics"
        case .migrationKillSwitch: return "Migration Kill Switch"
        }
    }
}

// MARK: - Feature Flag Configuration
struct FeatureFlagConfig: Codable {
    let flag: String
    let enabled: Bool
    let rolloutPercentage: Double
    let cohorts: [String]?
    let minAppVersion: String?
    let maxAppVersion: String?
    let description: String
}

struct FeatureFlagsResponse: Codable {
    let flags: [FeatureFlagConfig]
    let version: String
    let ttl: Int // Time to live in seconds
    let lastUpdated: Date
}

// MARK: - Feature Flags Manager
@MainActor
class FeatureFlagsManager: ObservableObject {
    static let shared = FeatureFlagsManager()
    
    // MARK: - Properties
    @Published private(set) var isLoaded = false
    @Published private(set) var lastFetchTime: Date?
    
    private let userDefaults = UserDefaults.standard
    private let remoteConfigURL = "https://habitto-config.firebaseapp.com/feature-flags.json"
    private let cacheKey = "FeatureFlagsCache"
    private let cacheTTL: TimeInterval = 3600 // 1 hour
    
    private var cachedFlags: [FeatureFlag: Bool] = [:]
    private var remoteConfig: FeatureFlagsResponse?
    
    private init() {
        loadCachedFlags()
        Task {
            await fetchRemoteFlags()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if a feature flag is enabled for a specific user
    func isEnabled(_ flag: FeatureFlag, forUser userId: String? = nil) -> Bool {
        // 1. Check local override first
        if let localOverride = getLocalOverride(for: flag) {
            return localOverride
        }
        
        // 2. Check cached remote value
        if let cachedValue = cachedFlags[flag] {
            return cachedValue
        }
        
        // 3. Check remote config if available
        if let remoteValue = getRemoteValue(for: flag, userId: userId) {
            return remoteValue
        }
        
        // 4. Fall back to default value
        return flag.defaultValue
    }
    
    /// Set a local override for a feature flag (for testing/debugging)
    func setLocalOverride(_ flag: FeatureFlag, enabled: Bool) {
        let key = "FeatureFlagOverride_\(flag.rawValue)"
        userDefaults.set(enabled, forKey: key)
        
        // Update cached value
        cachedFlags[flag] = enabled
        
        print("🚩 FeatureFlags: Set local override for \(flag.rawValue) = \(enabled)")
    }
    
    /// Clear local override for a feature flag
    func clearLocalOverride(_ flag: FeatureFlag) {
        let key = "FeatureFlagOverride_\(flag.rawValue)"
        userDefaults.removeObject(forKey: key)
        
        // Refresh the flag value
        cachedFlags.removeValue(forKey: flag)
        
        print("🚩 FeatureFlags: Cleared local override for \(flag.rawValue)")
    }
    
    /// Force refresh remote flags
    func refreshFlags() async {
        await fetchRemoteFlags()
    }
    
    /// Get all feature flags status
    func getAllFlagsStatus(forUser userId: String? = nil) -> [FeatureFlag: Bool] {
        var status: [FeatureFlag: Bool] = [:]
        
        for flag in FeatureFlag.allCases {
            status[flag] = isEnabled(flag, forUser: userId)
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    private func loadCachedFlags() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let response = try? JSONDecoder().decode(FeatureFlagsResponse.self, from: data) else {
            print("🚩 FeatureFlags: No cached flags found")
            return
        }
        
        // Check if cache is still valid
        let cacheAge = Date().timeIntervalSince(response.lastUpdated)
        if cacheAge > cacheTTL {
            print("🚩 FeatureFlags: Cache expired (\(cacheAge)s > \(cacheTTL)s)")
            return
        }
        
        remoteConfig = response
        updateCachedFlags(from: response)
        isLoaded = true
        lastFetchTime = response.lastUpdated
        
        print("🚩 FeatureFlags: Loaded \(cachedFlags.count) flags from cache")
    }
    
    private func fetchRemoteFlags() async {
        guard let url = URL(string: remoteConfigURL) else {
            print("🚩 FeatureFlags: Invalid remote config URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🚩 FeatureFlags: Invalid HTTP response")
                return
            }
            
            let flagsResponse = try JSONDecoder().decode(FeatureFlagsResponse.self, from: data)
            
            // Update cache
            remoteConfig = flagsResponse
            updateCachedFlags(from: flagsResponse)
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(flagsResponse) {
                userDefaults.set(encoded, forKey: cacheKey)
            }
            
            isLoaded = true
            lastFetchTime = flagsResponse.lastUpdated
            
            print("🚩 FeatureFlags: Fetched \(cachedFlags.count) flags from remote")
            
        } catch {
            print("🚩 FeatureFlags: Failed to fetch remote flags: \(error.localizedDescription)")
        }
    }
    
    private func updateCachedFlags(from response: FeatureFlagsResponse) {
        cachedFlags.removeAll()
        
        for config in response.flags {
            guard let flag = FeatureFlag(rawValue: config.flag) else {
                continue
            }
            
            cachedFlags[flag] = config.enabled
        }
    }
    
    private func getLocalOverride(for flag: FeatureFlag) -> Bool? {
        let key = "FeatureFlagOverride_\(flag.rawValue)"
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        return userDefaults.bool(forKey: key)
    }
    
    private func getRemoteValue(for flag: FeatureFlag, userId: String?) -> Bool? {
        guard let config = remoteConfig else { return nil }
        
        let flagConfig = config.flags.first { $0.flag == flag.rawValue }
        guard let config = flagConfig else { return nil }
        
        // Check version constraints
        if let minVersion = config.minAppVersion,
           let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if compareVersions(currentVersion, minVersion) < 0 {
                return false
            }
        }
        
        if let maxVersion = config.maxAppVersion,
           let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if compareVersions(currentVersion, maxVersion) > 0 {
                return false
            }
        }
        
        // Check cohort eligibility
        if let cohorts = config.cohorts, let userId = userId {
            let userCohort = getUserCohort(userId: userId)
            if !cohorts.contains(userCohort) {
                return false
            }
        }
        
        // Check rollout percentage
        if let userId = userId {
            let userHash = hashUserId(userId)
            let rolloutThreshold = Int(config.rolloutPercentage * 100)
            if userHash % 100 >= rolloutThreshold {
                return false
            }
        }
        
        return config.enabled
    }
    
    private func getUserCohort(userId: String) -> String {
        let hash = hashUserId(userId)
        return "cohort_\(hash % 10)"
    }
    
    private func hashUserId(_ userId: String) -> Int {
        return abs(userId.hashValue)
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 { return -1 }
            if v1 > v2 { return 1 }
        }
        
        return 0
    }
}

// MARK: - Feature Flag Guards
extension FeatureFlagsManager {
    
    /// Guard that throws an error if a feature is disabled
    func requireFeature(_ flag: FeatureFlag, forUser userId: String? = nil) throws {
        guard isEnabled(flag, forUser: userId) else {
            throw FeatureFlagError.featureDisabled(flag.rawValue)
        }
    }
    
    /// Guard that returns false if a feature is disabled
    func checkFeature(_ flag: FeatureFlag, forUser userId: String? = nil) -> Bool {
        return isEnabled(flag, forUser: userId)
    }
}

// MARK: - Feature Flag Errors
enum FeatureFlagError: LocalizedError {
    case featureDisabled(String)
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled(let flag):
            return "Feature '\(flag)' is disabled"
        }
    }
}

// MARK: - Migration Kill Switch Integration
extension FeatureFlagsManager {
    
    /// Check if migrations are enabled (kill switch)
    func isMigrationEnabled(forUser userId: String? = nil) -> Bool {
        return isEnabled(.migrationKillSwitch, forUser: userId)
    }
    
    /// Guard that prevents migrations if kill switch is disabled
    func requireMigrationEnabled(forUser userId: String? = nil) throws {
        try requireFeature(.migrationKillSwitch, forUser: userId)
    }
}
