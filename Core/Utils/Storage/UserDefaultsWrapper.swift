import Foundation

// MARK: - UserDefaultsWrapper

/// Safe wrapper for UserDefaults operations with type safety and error handling
class UserDefaultsWrapper {
  // MARK: Lifecycle

  private init() {
    self.userDefaults = UserDefaults.standard
  }

  // MARK: Internal

  static let shared = UserDefaultsWrapper()

  // MARK: - Generic Value Operations

  /// Set a value for a key with type safety
  func set(_ value: (some Any)?, forKey key: String) {
    userDefaults.set(value, forKey: key)
  }

  /// Get a value for a key with type safety
  func get<T>(_: T.Type, forKey key: String) -> T? {
    userDefaults.object(forKey: key) as? T
  }

  /// Get a value for a key with a default value
  func get<T>(_ type: T.Type, forKey key: String, defaultValue: T) -> T {
    get(type, forKey: key) ?? defaultValue
  }

  /// Check if a key exists
  func exists(forKey key: String) -> Bool {
    userDefaults.object(forKey: key) != nil
  }

  /// Remove a value for a key
  func remove(forKey key: String) {
    userDefaults.removeObject(forKey: key)
  }

  // MARK: - Specific Type Operations

  /// Set a string value
  func setString(_ value: String?, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get a string value
  func getString(forKey key: String) -> String? {
    get(String.self, forKey: key)
  }

  /// Get a string value with default
  func getString(forKey key: String, defaultValue: String) -> String {
    get(String.self, forKey: key, defaultValue: defaultValue)
  }

  /// Set a boolean value
  func setBool(_ value: Bool, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get a boolean value
  func getBool(forKey key: String) -> Bool {
    get(Bool.self, forKey: key, defaultValue: false)
  }

  /// Get a boolean value with default
  func getBool(forKey key: String, defaultValue: Bool) -> Bool {
    get(Bool.self, forKey: key, defaultValue: defaultValue)
  }

  /// Set an integer value
  func setInt(_ value: Int, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get an integer value
  func getInt(forKey key: String) -> Int {
    get(Int.self, forKey: key, defaultValue: 0)
  }

  /// Get an integer value with default
  func getInt(forKey key: String, defaultValue: Int) -> Int {
    get(Int.self, forKey: key, defaultValue: defaultValue)
  }

  /// Set a double value
  func setDouble(_ value: Double, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get a double value
  func getDouble(forKey key: String) -> Double {
    get(Double.self, forKey: key, defaultValue: 0.0)
  }

  /// Get a double value with default
  func getDouble(forKey key: String, defaultValue: Double) -> Double {
    get(Double.self, forKey: key, defaultValue: defaultValue)
  }

  // MARK: - Date Operations

  /// Set a date value (stored as ISO 8601 string)
  func setDate(_ value: Date?, forKey key: String) {
    if let date = value {
      setString(date.iso8601String, forKey: key)
    } else {
      remove(forKey: key)
    }
  }

  /// Get a date value (parsed from ISO 8601 string)
  func getDate(forKey key: String) -> Date? {
    guard let dateString = getString(forKey: key) else { return nil }
    return dateString.iso8601Date
  }

  /// Get a date value with default
  func getDate(forKey key: String, defaultValue: Date) -> Date {
    getDate(forKey: key) ?? defaultValue
  }

  // MARK: - Array Operations

  /// Set an array of strings
  func setStringArray(_ value: [String]?, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get an array of strings
  func getStringArray(forKey key: String) -> [String]? {
    get([String].self, forKey: key)
  }

  /// Get an array of strings with default
  func getStringArray(forKey key: String, defaultValue: [String]) -> [String] {
    get([String].self, forKey: key, defaultValue: defaultValue)
  }

  /// Set an array of dates (stored as ISO 8601 strings)
  func setDateArray(_ value: [Date]?, forKey key: String) {
    if let dates = value {
      let dateStrings = dates.map { $0.iso8601String }
      setStringArray(dateStrings, forKey: key)
    } else {
      remove(forKey: key)
    }
  }

  /// Get an array of dates (parsed from ISO 8601 strings)
  func getDateArray(forKey key: String) -> [Date]? {
    guard let dateStrings = getStringArray(forKey: key) else { return nil }
    let dates = dateStrings.compactMap { $0.iso8601Date }
    return dates.isEmpty ? nil : dates
  }

  /// Get an array of dates with default
  func getDateArray(forKey key: String, defaultValue: [Date]) -> [Date] {
    getDateArray(forKey: key) ?? defaultValue
  }

  // MARK: - Dictionary Operations

  /// Set a dictionary of strings
  func setStringDictionary(_ value: [String: String]?, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get a dictionary of strings
  func getStringDictionary(forKey key: String) -> [String: String]? {
    get([String: String].self, forKey: key)
  }

  /// Get a dictionary of strings with default
  func getStringDictionary(forKey key: String, defaultValue: [String: String]) -> [String: String] {
    get([String: String].self, forKey: key, defaultValue: defaultValue)
  }

  // MARK: - Data Operations

  /// Set data value
  func setData(_ value: Data?, forKey key: String) {
    set(value, forKey: key)
  }

  /// Get data value
  func getData(forKey key: String) -> Data? {
    get(Data.self, forKey: key)
  }

  // MARK: - Codable Operations

  /// Set a Codable object (encoded as JSON data)
  func setCodable(_ value: (some Codable)?, forKey key: String) throws {
    if let value {
      let data = try JSONEncoder().encode(value)
      setData(data, forKey: key)
    } else {
      remove(forKey: key)
    }
  }

  /// Get a Codable object (decoded from JSON data)
  func getCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
    guard let data = getData(forKey: key) else { return nil }
    return try JSONDecoder().decode(type, from: data)
  }

  /// Get a Codable object with default
  func getCodable<T: Codable>(_ type: T.Type, forKey key: String, defaultValue: T) throws -> T {
    try getCodable(type, forKey: key) ?? defaultValue
  }

  // MARK: - Bulk Operations

  /// Get all keys
  func getAllKeys() -> [String] {
    Array(userDefaults.dictionaryRepresentation().keys)
  }

  /// Get all keys with a prefix
  func getKeys(withPrefix prefix: String) -> [String] {
    getAllKeys().filter { $0.hasPrefix(prefix) }
  }

  /// Remove all keys with a prefix
  func removeAllKeys(withPrefix prefix: String) {
    let keys = getKeys(withPrefix: prefix)
    for key in keys {
      remove(forKey: key)
    }
  }

  /// Clear all data (use with caution)
  func clearAll() {
    let domain = Bundle.main.bundleIdentifier!
    userDefaults.removePersistentDomain(forName: domain)
  }

  // MARK: - Synchronization

  /// Force synchronization
  func synchronize() -> Bool {
    userDefaults.synchronize()
  }

  // MARK: Private

  private let userDefaults: UserDefaults
  private let dateHelper = ISO8601DateHelper.shared
}

// MARK: - Convenience Extensions

extension UserDefaultsWrapper {
  /// Set a value with automatic key generation based on type
  func set<T>(_ value: T?, forType type: T.Type) {
    let key = String(describing: type)
    set(value, forKey: key)
  }

  /// Get a value with automatic key generation based on type
  func get<T>(_ type: T.Type) -> T? {
    let key = String(describing: type)
    return get(type, forKey: key)
  }

  /// Get a value with automatic key generation and default
  func get<T>(_ type: T.Type, defaultValue: T) -> T {
    let key = String(describing: type)
    return get(type, forKey: key, defaultValue: defaultValue)
  }
}
