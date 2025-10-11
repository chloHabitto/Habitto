import Foundation

// MARK: - FeatureFlags

/// Central feature flag management for the Habitto app
/// All feature flags are injected via dependency injection for testability
enum FeatureFlags {
  // MARK: Internal

  // MARK: - Data Layer Feature Flags

  /// Enables the new normalized data path with proper user isolation
  /// When false: Uses legacy UserDefaults + SwiftData dual storage
  /// When true: Uses SwiftData-only with proper user scoping
  static var useNormalizedDataPath: Bool = emergencyDisableNormalizedPath ? false : true

  /// Enables the new XPService centralized XP management
  /// When false: Uses legacy XPManager with direct mutations
  /// When true: Uses XPService with proper validation
  static var useCentralizedXP = true

  /// Enables user-specific SwiftData containers
  /// When false: Single shared container for all users
  /// When true: Separate containers per user (guest vs account)
  static var useUserScopedContainers = true

  // MARK: - Migration Feature Flags

  /// Enables automatic migration from legacy storage
  /// When false: No migration runs
  /// When true: Migration runs on first app launch with new data path
  static var enableAutoMigration = true

  /// Enables migration rollback capability
  /// When false: No rollback support
  /// When true: Can rollback to legacy storage if issues occur
  static var enableMigrationRollback = false

  // MARK: - Testing Feature Flags

  /// Forces migration to run even if already completed (for testing)
  static var forceMigration = false

  /// Enables detailed migration logging
  static var verboseMigrationLogging = false

  /// Enables XP mutation violation detection in debug builds
  static var strictXPMutationValidation = true

  /// Enables theme persistence in backup/restore
  static var themePersistence = false

  /// Allows past dates for testing purposes (should be false in production)
  static var allowPastDates = false

  // MARK: - Feature Flag Management

  /// Resets all feature flags to their default values (Phase 4 defaults)
  static func resetToDefaults() {
    // Phase 4 defaults: normalized path enabled by default
    // useNormalizedDataPath is computed from emergency override
    useCentralizedXP = true
    useUserScopedContainers = true
    enableAutoMigration = true
    enableMigrationRollback = false
    forceMigration = false
    verboseMigrationLogging = false
    strictXPMutationValidation = true
    themePersistence = false
    allowPastDates = false
  }

  /// Enables all data layer improvements for testing
  static func enableAllDataImprovements() {
    useNormalizedDataPath = true
    useCentralizedXP = true
    useUserScopedContainers = true
    enableAutoMigration = true
    enableMigrationRollback = true
    verboseMigrationLogging = true
    strictXPMutationValidation = true
  }

  /// Validates feature flag combinations
  static func validateConfiguration() -> [String] {
    var warnings: [String] = []

    if useCentralizedXP, !useNormalizedDataPath {
      warnings.append("useCentralizedXP requires useNormalizedDataPath to be true")
    }

    if useUserScopedContainers, !useNormalizedDataPath {
      warnings.append("useUserScopedContainers requires useNormalizedDataPath to be true")
    }

    if enableAutoMigration, !useNormalizedDataPath {
      warnings.append("enableAutoMigration requires useNormalizedDataPath to be true")
    }

    return warnings
  }

  // MARK: Private

  // MARK: - Emergency Override (Internal Builds Only)

  #if INTERNAL_BUILD
  /// Emergency override to disable normalized data path (internal builds only)
  /// This is a compile-time flag for emergency rollback
  private static let emergencyDisableNormalizedPath = false
  #else
  private static let emergencyDisableNormalizedPath = false
  #endif
}

// MARK: - FeatureFlagProvider

/// Protocol for injecting feature flags (useful for testing)
protocol FeatureFlagProvider {
  var useNormalizedDataPath: Bool { get }
  var useCentralizedXP: Bool { get }
  var useUserScopedContainers: Bool { get }
  var enableAutoMigration: Bool { get }
  var enableMigrationRollback: Bool { get }
  var forceMigration: Bool { get }
  var verboseMigrationLogging: Bool { get }
  var strictXPMutationValidation: Bool { get }
}

// MARK: - DefaultFeatureFlagProvider

struct DefaultFeatureFlagProvider: FeatureFlagProvider {
  var useNormalizedDataPath: Bool { FeatureFlags.useNormalizedDataPath }
  var useCentralizedXP: Bool { FeatureFlags.useCentralizedXP }
  var useUserScopedContainers: Bool { FeatureFlags.useUserScopedContainers }
  var enableAutoMigration: Bool { FeatureFlags.enableAutoMigration }
  var enableMigrationRollback: Bool { FeatureFlags.enableMigrationRollback }
  var forceMigration: Bool { FeatureFlags.forceMigration }
  var verboseMigrationLogging: Bool { FeatureFlags.verboseMigrationLogging }
  var strictXPMutationValidation: Bool { FeatureFlags.strictXPMutationValidation }
}

// MARK: - TestFeatureFlagProvider

/// Test provider that allows easy toggling of feature flags
class TestFeatureFlagProvider: FeatureFlagProvider {
  var useNormalizedDataPath = false
  var useCentralizedXP = false
  var useUserScopedContainers = false
  var enableAutoMigration = false
  var enableMigrationRollback = false
  var forceMigration = false
  var verboseMigrationLogging = false
  var strictXPMutationValidation = true

  /// Convenience method to enable all data improvements for testing
  func enableAllDataImprovements() {
    useNormalizedDataPath = true
    useCentralizedXP = true
    useUserScopedContainers = true
    enableAutoMigration = true
    enableMigrationRollback = true
    verboseMigrationLogging = true
    strictXPMutationValidation = true
  }

  /// Convenience method to disable all data improvements for testing
  func disableAllDataImprovements() {
    useNormalizedDataPath = false
    useCentralizedXP = false
    useUserScopedContainers = false
    enableAutoMigration = false
    enableMigrationRollback = false
    verboseMigrationLogging = false
    strictXPMutationValidation = false
  }
}

// MARK: - FeatureFlagManager

/// Global feature flag provider for dependency injection
class FeatureFlagManager {
  // MARK: Lifecycle

  private init() { }

  // MARK: Internal

  static let shared = FeatureFlagManager()

  var provider: FeatureFlagProvider {
    get { _provider }
    set { _provider = newValue }
  }

  /// Resets to default provider
  func resetToDefault() {
    _provider = DefaultFeatureFlagProvider()
  }

  /// Sets a test provider for testing
  func setTestProvider(_ provider: TestFeatureFlagProvider) {
    _provider = provider
  }

  // MARK: Private

  private var _provider: FeatureFlagProvider = DefaultFeatureFlagProvider()
}

// MARK: - Feature Flag Extensions

extension FeatureFlagProvider {
  /// Returns true if any data improvements are enabled
  var hasDataImprovements: Bool {
    useNormalizedDataPath || useCentralizedXP || useUserScopedContainers
  }

  /// Returns true if migration is enabled
  var isMigrationEnabled: Bool {
    enableAutoMigration || forceMigration
  }

  /// Returns true if strict validation is enabled
  var isStrictValidationEnabled: Bool {
    strictXPMutationValidation
  }
}
