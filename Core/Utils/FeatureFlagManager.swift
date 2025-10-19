import Foundation

/// Temporary placeholder for FeatureFlagManager
/// TODO: Implement proper feature flag system or remove references
@MainActor
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()
    
    var provider: FeatureFlagProvider {
        return FeatureFlagProvider()
    }
    
    private init() {}
}

/// Temporary placeholder for FeatureFlagProvider
struct FeatureFlagProvider {
    var useNormalizedDataPath: Bool { return false }
    var useCentralizedXP: Bool { return false }
    var isMigrationEnabled: Bool { return false }
    var forceMigration: Bool { return false }
}

/// Static feature flag properties (temporary placeholders)
enum FeatureFlags {
    static var enableBackfill: Bool { return false }
    static var enableLegacyReadFallback: Bool { return true }
    static var enableFirestoreSync: Bool { return false }
    static var themePersistence: Bool { return false }
    static var allowPastDates: Bool { return false }
}

