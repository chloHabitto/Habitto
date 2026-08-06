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
    // ✅ TESTING: Enable migration for testing (can be disabled later)
    var isMigrationEnabled: Bool { return true }
    // ✅ TESTING: Enable force migration for testing (set to false after testing)
    var forceMigration: Bool { return true }
}

/// Static feature flag properties (temporary placeholders)
enum FeatureFlags {
    static var enableBackfill: Bool { return false }
    static var enableLegacyReadFallback: Bool { return true }
    static var enableFirestoreSync: Bool { return false }
    static var themePersistence: Bool { return false }
    static var allowPastDates: Bool { return false }

    /// In-app language picker + custom .lproj bundle override.
    /// When `false`, strings follow the iPhone system language via Bundle.main
    /// (unless `koreanLocalizationEnabled` is also `false` — see below).
    /// Flip to `true` to restore LanguageView / LocalizationManager.setLanguage().
    static var inAppLanguageSwitchEnabled: Bool { return false }

    /// Ship Korean from `Localizable.xcstrings` when the device language is Korean.
    ///
    /// Set to `false` to temporarily serve **English to everyone** (including Korean
    /// phones), while leaving all `ko` catalog entries and project `knownRegions`
    /// untouched so translation work can resume later.
    ///
    /// **To resume Korean later:** flip this to `true` (one-line change). On next
    /// launch, the process-level English override is cleared automatically.
    static var koreanLocalizationEnabled: Bool { return false }

    /// UserDefaults key used only while `koreanLocalizationEnabled == false`.
    /// Lets us clear our `AppleLanguages` override when Korean is re-enabled,
    /// without clobbering an unrelated override we didn't create.
    static let didForceEnglishLocalizationKey = "HabittoDidForceEnglishLocalization"

    /// Must run at process start (before LocalizationManager / any string lookup).
    /// Forces Bundle.main / `String(localized:)` / `NSLocalizedString` to English
    /// when Korean is paused; clears that override when Korean is re-enabled.
    static func applyLocalizationLanguageOverrideIfNeeded() {
        if koreanLocalizationEnabled {
            if UserDefaults.standard.bool(forKey: didForceEnglishLocalizationKey) {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                UserDefaults.standard.set(false, forKey: didForceEnglishLocalizationKey)
                print("🌍 FeatureFlags: Cleared forced-English AppleLanguages (koreanLocalizationEnabled=true)")
            }
        } else {
            // Same effect as an unsupported system language (e.g. French): English only.
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            UserDefaults.standard.set(true, forKey: didForceEnglishLocalizationKey)
            print("🌍 FeatureFlags: Forcing English via AppleLanguages (koreanLocalizationEnabled=false)")
        }
    }
}

