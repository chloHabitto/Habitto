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
  
  /// Format date as "Sat, 24 Jan" or "토, 1월 24일"
  func localizedShortDate(for date: Date) -> String {
    let weekday = localizedWeekday(for: date, short: true)
    let month = localizedMonth(for: date, short: true)
    let day = Calendar.current.component(.day, from: date)
    
    if currentLanguage == "ko" {
      return "\(weekday), \(month) \(day)일"
    } else {
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
  func localizedWeekdayArray(shortForm: Bool = true) -> [String] {
    let calendar = Calendar.current
    let firstWeekday = calendar.firstWeekday
    
    // Calendar weekdays: 1=Sunday, 2=Monday, etc.
    var weekdayIndices = Array(1...7)
    
    // Rotate if Monday is first
    if firstWeekday == 2 {
      weekdayIndices = Array(2...7) + [1]
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
