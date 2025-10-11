import Foundation
import SwiftUI
import UIKit

// MARK: - I18nPreferences

/// Manages internationalization preferences with BCP-47 compliance
struct I18nPreferences: Codable, Equatable {
  // MARK: - Default Values

  static let `default` = I18nPreferences(
    languageTag: "en",
    regionCode: nil,
    calendarID: "gregorian",
    timeZoneID: nil,
    uses24HourFormat: false,
    firstWeekday: 1)

  let languageTag: String // BCP-47 language tag (e.g., "en-US", "ar-SA")
  let regionCode: String? // ISO 3166-1 alpha-2 country code
  let calendarID: String // Calendar identifier (e.g., "gregorian", "islamic")
  let timeZoneID: String? // TimeZone identifier (e.g., "America/New_York")
  let uses24HourFormat: Bool
  let firstWeekday: Int // 1 = Sunday, 2 = Monday (ISO 8601 uses Monday as 1)

  var locale: Locale {
    Locale(identifier: languageTag)
  }

  var calendar: Calendar {
    let calendarIdentifier: Calendar.Identifier = switch calendarID {
    case "gregorian": .gregorian
    case "islamic": .islamic
    case "buddhist": .buddhist
    case "chinese": .chinese
    case "hebrew": .hebrew
    case "indian": .indian
    case "persian": .persian
    default: .gregorian
    }

    var calendar = Calendar(identifier: calendarIdentifier)
    if let timeZoneID, let timeZone = TimeZone(identifier: timeZoneID) {
      calendar.timeZone = timeZone
    }
    calendar.firstWeekday = firstWeekday
    return calendar
  }

  var timeZone: TimeZone {
    if let timeZoneID, let timeZone = TimeZone(identifier: timeZoneID) {
      return timeZone
    }
    return TimeZone.current
  }

  var isRTL: Bool {
    locale.language.languageCode?.identifier == "ar" ||
      locale.language.languageCode?.identifier == "he" ||
      locale.language.languageCode?.identifier == "fa"
  }

  var isNonGregorianCalendar: Bool {
    calendarID != "gregorian"
  }
}

// MARK: - I18nPreferencesManager

@MainActor
class I18nPreferencesManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Load preferences from UserDefaults or use system defaults
    if let data = userDefaults.data(forKey: preferencesKey),
       let preferences = try? JSONDecoder().decode(I18nPreferences.self, from: data)
    {
      self.preferences = preferences
    } else {
      // Initialize with system preferences
      self.preferences = Self.createSystemPreferences()
    }

    print("🌍 I18nPreferencesManager: Loaded preferences for \(preferences.languageTag)")
  }

  // MARK: Internal

  static let shared = I18nPreferencesManager()

  @Published var preferences: I18nPreferences

  // MARK: - Public Methods

  /// Update language preference
  func setLanguage(_ languageTag: String) {
    preferences = I18nPreferences(
      languageTag: languageTag,
      regionCode: preferences.regionCode,
      calendarID: preferences.calendarID,
      timeZoneID: preferences.timeZoneID,
      uses24HourFormat: preferences.uses24HourFormat,
      firstWeekday: preferences.firstWeekday)
    savePreferences()
  }

  /// Update region preference
  func setRegion(_ regionCode: String?) {
    preferences = I18nPreferences(
      languageTag: preferences.languageTag,
      regionCode: regionCode,
      calendarID: preferences.calendarID,
      timeZoneID: preferences.timeZoneID,
      uses24HourFormat: preferences.uses24HourFormat,
      firstWeekday: preferences.firstWeekday)
    savePreferences()
  }

  /// Update calendar preference
  func setCalendar(_ calendarID: String) {
    preferences = I18nPreferences(
      languageTag: preferences.languageTag,
      regionCode: preferences.regionCode,
      calendarID: calendarID,
      timeZoneID: preferences.timeZoneID,
      uses24HourFormat: preferences.uses24HourFormat,
      firstWeekday: preferences.firstWeekday)
    savePreferences()
  }

  /// Update time zone preference
  func setTimeZone(_ timeZoneID: String?) {
    preferences = I18nPreferences(
      languageTag: preferences.languageTag,
      regionCode: preferences.regionCode,
      calendarID: preferences.calendarID,
      timeZoneID: timeZoneID,
      uses24HourFormat: preferences.uses24HourFormat,
      firstWeekday: preferences.firstWeekday)
    savePreferences()
  }

  /// Update time format preference
  func set24HourFormat(_ uses24Hour: Bool) {
    preferences = I18nPreferences(
      languageTag: preferences.languageTag,
      regionCode: preferences.regionCode,
      calendarID: preferences.calendarID,
      timeZoneID: preferences.timeZoneID,
      uses24HourFormat: uses24Hour,
      firstWeekday: preferences.firstWeekday)
    savePreferences()
  }

  /// Update first weekday preference
  func setFirstWeekday(_ weekday: Int) {
    preferences = I18nPreferences(
      languageTag: preferences.languageTag,
      regionCode: preferences.regionCode,
      calendarID: preferences.calendarID,
      timeZoneID: preferences.timeZoneID,
      uses24HourFormat: preferences.uses24HourFormat,
      firstWeekday: weekday)
    savePreferences()
  }

  /// Reset to system defaults
  func resetToSystemDefaults() {
    preferences = Self.createSystemPreferences()
    savePreferences()
  }

  /// Get available languages
  func getAvailableLanguages() -> [String] {
    [
      "en", "es", "fr", "de", "it", "pt", "ru", "ja", "ko", "zh",
      "ar", "he", "fa", "hi", "th", "vi", "tr", "pl", "nl", "sv"
    ]
  }

  /// Get available calendars
  func getAvailableCalendars() -> [String] {
    [
      "gregorian",
      "islamic",
      "buddhist",
      "chinese",
      "hebrew",
      "indian",
      "persian"
    ]
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let preferencesKey = "I18nPreferences"

  private static func createSystemPreferences() -> I18nPreferences {
    let currentLocale = Locale.current
    let currentCalendar = Calendar.current
    let currentTimeZone = TimeZone.current

    // Extract language tag from current locale
    let languageTag = currentLocale.language.languageCode?.identifier ?? "en"
    let regionCode = currentLocale.region?.identifier

    // Get calendar identifier
    let calendarID = switch currentCalendar.identifier {
    case .gregorian: "gregorian"
    case .islamic: "islamic"
    case .buddhist: "buddhist"
    case .chinese: "chinese"
    case .hebrew: "hebrew"
    case .indian: "indian"
    case .persian: "persian"
    default: "gregorian"
    }

    // Get time zone identifier
    let timeZoneID = currentTimeZone.identifier

    // Determine 24-hour format preference (simplified check)
    let uses24HourFormat = false // Default to 12-hour format

    // Get first weekday
    let firstWeekday = currentCalendar.firstWeekday

    return I18nPreferences(
      languageTag: languageTag,
      regionCode: regionCode,
      calendarID: calendarID,
      timeZoneID: timeZoneID,
      uses24HourFormat: uses24HourFormat,
      firstWeekday: firstWeekday)
  }

  // MARK: - Private Methods

  private func savePreferences() {
    if let data = try? JSONEncoder().encode(preferences) {
      userDefaults.set(data, forKey: preferencesKey)
      print("🌍 I18nPreferencesManager: Saved preferences for \(preferences.languageTag)")
    }
  }
}

// MARK: - Date Formatting Utilities

extension I18nPreferencesManager {
  /// Format date for display using current preferences
  func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter()
    formatter.locale = preferences.locale
    formatter.calendar = preferences.calendar
    formatter.timeZone = preferences.timeZone
    formatter.dateStyle = style

    return formatter.string(from: date)
  }

  /// Format time for display using current preferences
  func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
    let formatter = DateFormatter()
    formatter.locale = preferences.locale
    formatter.calendar = preferences.calendar
    formatter.timeZone = preferences.timeZone
    formatter.timeStyle = style

    if preferences.uses24HourFormat {
      formatter.dateFormat = "HH:mm"
    } else {
      formatter.dateFormat = "h:mm a"
    }

    return formatter.string(from: date)
  }

  /// Format date and time for display using current preferences
  func formatDateTime(
    _ date: Date,
    dateStyle: DateFormatter.Style = .medium,
    timeStyle: DateFormatter.Style = .short) -> String
  {
    let formatter = DateFormatter()
    formatter.locale = preferences.locale
    formatter.calendar = preferences.calendar
    formatter.timeZone = preferences.timeZone
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle

    return formatter.string(from: date)
  }

  /// Get localized string for pluralization
  func getPluralString(for count: Int, singular: String, plural: String) -> String {
    // Simple pluralization logic
    let word = count == 1 ? singular : plural
    return "\(count) \(word)"
  }
}

// MARK: - RTL Support

extension I18nPreferencesManager {
  /// Check if current language is RTL
  var isRTL: Bool {
    preferences.isRTL
  }

  /// Get appropriate text alignment for current language
  var textAlignment: NSTextAlignment {
    isRTL ? .right : .left
  }

  /// Get appropriate layout direction for SwiftUI
  var layoutDirection: LayoutDirection {
    isRTL ? .rightToLeft : .leftToRight
  }
}

// MARK: - Calendar and Time Zone Utilities

extension I18nPreferencesManager {
  /// Get current calendar with preferences applied
  var calendar: Calendar {
    preferences.calendar
  }

  /// Get current time zone with preferences applied
  var timeZone: TimeZone {
    preferences.timeZone
  }

  /// Check if current calendar is non-Gregorian
  var isNonGregorianCalendar: Bool {
    preferences.isNonGregorianCalendar
  }

  /// Get start of day for a date using current preferences
  func startOfDay(for date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  /// Get end of day for a date using current preferences
  func endOfDay(for date: Date) -> Date {
    calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
  }

  /// Add days to a date using current preferences
  func addDays(_ days: Int, to date: Date) -> Date {
    calendar.date(byAdding: .day, value: days, to: date) ?? date
  }

  /// Get days between two dates using current preferences
  func daysBetween(_ startDate: Date, and endDate: Date) -> Int {
    let components = calendar.dateComponents([.day], from: startDate, to: endDate)
    return components.day ?? 0
  }
}
