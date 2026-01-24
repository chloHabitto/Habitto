import Foundation
import SwiftUI

// MARK: - LocalizationManager

/// Manages app localization with runtime language switching support
@MainActor
final class LocalizationManager: ObservableObject {
  
  // MARK: - Singleton
  
  static let shared = LocalizationManager()
  
  // MARK: - Published Properties
  
  @Published private(set) var currentLanguage: String
  
  // MARK: - Private Properties
  
  private var bundle: Bundle?
  
  // MARK: - Initialization
  
  private init() {
    // Load language from I18nPreferencesManager
    currentLanguage = I18nPreferencesManager.shared.preferences.languageTag
    loadBundle(for: currentLanguage)
    
    // Observe language changes
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(languageDidChange),
      name: NSNotification.Name("ShowLanguageSavedToast"),
      object: nil
    )
    
    print("🌍 LocalizationManager: Initialized with language \(currentLanguage)")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - Public Methods
  
  /// Get localized string for key
  func localizedString(_ key: String) -> String {
    guard let bundle = bundle else {
      return NSLocalizedString(key, comment: "")
    }
    return bundle.localizedString(forKey: key, value: nil, table: nil)
  }
  
  /// Update the current language
  func setLanguage(_ languageCode: String) {
    currentLanguage = languageCode
    loadBundle(for: languageCode)
    objectWillChange.send()
    print("🌍 LocalizationManager: Language changed to \(languageCode)")
  }
  
  // MARK: - Private Methods
  
  private func loadBundle(for languageCode: String) {
    if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
       let bundle = Bundle(path: path) {
      self.bundle = bundle
      print("✅ LocalizationManager: Loaded bundle for \(languageCode)")
    } else {
      // Fallback to main bundle (English)
      self.bundle = Bundle.main
      print("⚠️ LocalizationManager: No bundle found for \(languageCode), using default")
    }
  }
  
  @objc private func languageDidChange(_ notification: Notification) {
    let newLanguage = I18nPreferencesManager.shared.preferences.languageTag
    if newLanguage != currentLanguage {
      setLanguage(newLanguage)
    }
  }
}

// MARK: - String Extension for Localization

extension String {
  /// Returns the localized version of this string
  @MainActor
  var localized: String {
    LocalizationManager.shared.localizedString(self)
  }
}

// MARK: - View Extension for Localization

extension View {
  /// Helper to force view refresh when language changes
  func observeLanguageChanges() -> some View {
    self.environmentObject(LocalizationManager.shared)
  }
}
