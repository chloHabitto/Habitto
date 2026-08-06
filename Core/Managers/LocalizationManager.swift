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
    // Ensure process-level English override is applied even if this singleton
    // is touched before HabittoApp.init (e.g. from AppDelegate).
    FeatureFlags.applyLocalizationLanguageOverrideIfNeeded()

    if FeatureFlags.inAppLanguageSwitchEnabled {
      // In-app override: load language from I18nPreferencesManager
      currentLanguage = I18nPreferencesManager.shared.preferences.languageTag
      loadBundle(for: currentLanguage)
    } else if !FeatureFlags.koreanLocalizationEnabled {
      // Temporary: serve English for all users while Korean translations are paused.
      // Flip FeatureFlags.koreanLocalizationEnabled to true to resume system-language Korean.
      currentLanguage = "en"
      loadBundle(for: "en")
    } else {
      // Follow iPhone system language (no .lproj override)
      currentLanguage = Self.systemLanguageCode
      bundle = nil
    }
    
    // Observe language changes (only applied when in-app switch is enabled)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(languageDidChange),
      name: NSNotification.Name("ShowLanguageSavedToast"),
      object: nil
    )
    
    print("🌍 LocalizationManager: Initialized with language \(currentLanguage) (inAppSwitch=\(FeatureFlags.inAppLanguageSwitchEnabled), koreanEnabled=\(FeatureFlags.koreanLocalizationEnabled))")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - Public Methods
  
  /// Get localized string for key
  func localizedString(_ key: String) -> String {
    // In-app language switch, or forced-English while Korean is paused: use explicit bundle
    if (FeatureFlags.inAppLanguageSwitchEnabled || !FeatureFlags.koreanLocalizationEnabled),
       let bundle
    {
      return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    // System-language mode: let iOS pick the matching localization via Bundle.main
    return NSLocalizedString(key, comment: "")
  }
  
  /// Update the current language
  func setLanguage(_ languageCode: String) {
    guard FeatureFlags.inAppLanguageSwitchEnabled else {
      print("🌍 LocalizationManager: setLanguage(\(languageCode)) ignored — inAppLanguageSwitchEnabled=false")
      return
    }
    currentLanguage = languageCode
    loadBundle(for: languageCode)
    objectWillChange.send()
    print("🌍 LocalizationManager: Language changed to \(languageCode)")
  }
  
  // MARK: - Private Methods
  
  private static var systemLanguageCode: String {
    Locale.current.language.languageCode?.identifier ?? "en"
  }
  
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
    guard FeatureFlags.inAppLanguageSwitchEnabled else { return }
    let newLanguage = I18nPreferencesManager.shared.preferences.languageTag
    if newLanguage != currentLanguage {
      setLanguage(newLanguage)
    }
  }
}

// MARK: - Localized Date Formatting

extension LocalizationManager {
  
  /// Get localized month name
  func localizedMonth(for date: Date, short: Bool = false) -> String {
    let month = Calendar.current.component(.month, from: date)
    let keys = short ? [
      "", "date.month.short.jan", "date.month.short.feb", "date.month.short.mar",
      "date.month.short.apr", "date.month.short.may", "date.month.short.jun",
      "date.month.short.jul", "date.month.short.aug", "date.month.short.sep",
      "date.month.short.oct", "date.month.short.nov", "date.month.short.dec"
    ] : [
      "", "date.month.january", "date.month.february", "date.month.march",
      "date.month.april", "date.month.may", "date.month.june",
      "date.month.july", "date.month.august", "date.month.september",
      "date.month.october", "date.month.november", "date.month.december"
    ]
    return localizedString(keys[month])
  }
  
  /// Get localized weekday name (short: 월, 화, 수... or full: 월요일, 화요일...)
  func localizedWeekday(for date: Date, short: Bool = true) -> String {
    let weekday = Calendar.current.component(.weekday, from: date)
    let keys = short ? [
      "", "date.weekday.short.sunday", "date.weekday.short.monday", "date.weekday.short.tuesday",
      "date.weekday.short.wednesday", "date.weekday.short.thursday", "date.weekday.short.friday", "date.weekday.short.saturday"
    ] : [
      "", "home.weekday.sunday", "home.weekday.monday", "home.weekday.tuesday",
      "home.weekday.wednesday", "home.weekday.thursday", "home.weekday.friday", "home.weekday.saturday"
    ]
    return localizedString(keys[weekday])
  }
  
  /// Format date as "Sat, 24 Jan" (English) or "1월 25일 토" (Korean)
  /// For Korean, weekday appears at the end to match the Year/Month/Day format preference
  func localizedShortDate(for date: Date) -> String {
    let weekday = localizedWeekday(for: date, short: true)
    let month = localizedMonth(for: date, short: true)
    let day = Calendar.current.component(.day, from: date)
    
    if currentLanguage == "ko" {
      // Korean: Month Day Weekday (e.g., "1월 25일 토")
      return "\(month) \(day)일 \(weekday)"
    } else {
      // English: Weekday, Day Month (e.g., "Sat, 25 Jan")
      return "\(weekday), \(day) \(month)"
    }
  }
  
  /// Format month and year as "January 2026" or "2026년 1월"
  func localizedMonthYear(for date: Date) -> String {
    let month = localizedMonth(for: date, short: false)
    let year = Calendar.current.component(.year, from: date)
    
    if currentLanguage == "ko" {
      return "\(year)년 \(month)"
    } else {
      return "\(month) \(year)"
    }
  }
  
  /// Format streak days as "6 days" or "6일"
  func localizedStreakDays(_ count: Int) -> String {
    if currentLanguage == "ko" {
      return "\(count)일"
    } else {
      return count == 1 ? "\(count) day" : "\(count) days"
    }
  }
  
  /// Get localized array of weekday names (for calendar headers)
  /// Respects user's first weekday preference from I18nPreferencesManager
  func localizedWeekdayArray(shortForm: Bool = true) -> [String] {
    // Get user's first weekday preference (1 = Sunday, 2 = Monday, etc.)
    let firstWeekday = I18nPreferencesManager.shared.preferences.firstWeekday
    
    // Calendar weekdays: 1=Sunday, 2=Monday, etc.
    var weekdayIndices = Array(1...7)
    
    // Rotate array to start from user's preferred first day
    // If firstWeekday is 2 (Monday), move Sunday (1) to the end
    if firstWeekday > 1 {
      let rotateBy = firstWeekday - 1
      weekdayIndices = Array(weekdayIndices[rotateBy...]) + Array(weekdayIndices[..<rotateBy])
    }
    
    return weekdayIndices.map { weekday in
      let keys = shortForm ? [
        "", "date.weekday.short.sunday", "date.weekday.short.monday", "date.weekday.short.tuesday",
        "date.weekday.short.wednesday", "date.weekday.short.thursday", "date.weekday.short.friday", "date.weekday.short.saturday"
      ] : [
        "", "home.weekday.sunday", "home.weekday.monday", "home.weekday.tuesday",
        "home.weekday.wednesday", "home.weekday.thursday", "home.weekday.friday", "home.weekday.saturday"
      ]
      return localizedString(keys[weekday])
    }
  }
  
  /// Get calendar configured with user's locale and first weekday preference
  func getLocalizedCalendar() -> Calendar {
    let calendar = I18nPreferencesManager.shared.preferences.calendar
    // Ensure the calendar is properly configured
    return calendar
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
