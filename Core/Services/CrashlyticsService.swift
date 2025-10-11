import FirebaseCrashlytics
import Foundation

// MARK: - CrashlyticsService

/// Wrapper service for Firebase Crashlytics
/// Provides crash reporting and logging for production debugging
class CrashlyticsService {
  // MARK: Lifecycle

  private init() {
    #if DEBUG
    print("🐛 CrashlyticsService: Initialized in DEBUG mode (crashes won't be reported)")
    #else
    print("🐛 CrashlyticsService: Initialized in RELEASE mode")
    #endif
  }

  // MARK: Internal

  static let shared = CrashlyticsService()

  // MARK: - Configuration

  /// Enable crash reporting
  func enableCrashReporting() {
    #if !DEBUG
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    print("✅ Crashlytics: Crash reporting enabled")
    #else
    print("ℹ️ Crashlytics: Disabled in DEBUG mode")
    #endif
  }

  /// Set user identifier for crash reports
  func setUserID(_ userID: String) {
    Crashlytics.crashlytics().setUserID(userID)
    print("👤 Crashlytics: User ID set to \(userID)")
  }

  /// Set custom key-value for crash context
  func setValue(_ value: String, forKey key: String) {
    Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    print("📝 Crashlytics: Custom value '\(value)' set for key '\(key)'")
  }

  // MARK: - Logging

  /// Log a message to Crashlytics (appears in crash reports)
  func log(_ message: String) {
    Crashlytics.crashlytics().log(message)
    #if DEBUG
    print("🐛 Crashlytics log: \(message)")
    #endif
  }

  /// Log a non-fatal error (tracks issues that don't crash the app)
  func recordError(_ error: Error, additionalInfo: [String: Any] = [:]) {
    Crashlytics.crashlytics().record(error: error, userInfo: additionalInfo)
    print("⚠️ Crashlytics: Recorded non-fatal error - \(error.localizedDescription)")
  }

  // MARK: - Critical Flow Logging

  /// Log habit creation flow
  func logHabitCreationStart(habitName: String) {
    log("🎯 Starting habit creation: \(habitName)")
    setValue(habitName, forKey: "last_habit_created")
  }

  func logHabitCreationComplete(habitID: String) {
    log("✅ Habit created successfully: \(habitID)")
  }

  func logHabitCreationFailed(error: Error) {
    log("❌ Habit creation failed: \(error.localizedDescription)")
    recordError(error, additionalInfo: ["flow": "habit_creation"])
  }

  /// Log data migration flow
  func logMigrationStart(migrationName: String) {
    log("🔄 Starting migration: \(migrationName)")
    setValue(migrationName, forKey: "active_migration")
  }

  func logMigrationComplete(migrationName: String) {
    log("✅ Migration completed: \(migrationName)")
    setValue("none", forKey: "active_migration")
  }

  func logMigrationFailed(migrationName: String, error: Error) {
    log("❌ Migration failed: \(migrationName) - \(error.localizedDescription)")
    recordError(error, additionalInfo: ["migration": migrationName])
  }

  /// Log CloudKit sync issues
  func logCloudKitSyncFailed(error: Error) {
    log("❌ CloudKit sync failed: \(error.localizedDescription)")
    recordError(error, additionalInfo: ["sync_type": "cloudkit"])
  }

  /// Log data corruption issues
  func logDataCorruption(description: String, context: [String: Any]) {
    log("🚨 Data corruption detected: \(description)")
    let error = NSError(
      domain: "com.habitto.data",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: description])
    recordError(error, additionalInfo: context)
  }

  // MARK: - Testing

  /// Force a test crash (DEBUG only)
  func testCrash() {
    #if DEBUG
    print("💥 Crashlytics: Test crash triggered (won't actually crash in DEBUG)")
    // Uncomment to test in release build:
    // fatalError("Test crash for Crashlytics")
    #endif
  }
}

