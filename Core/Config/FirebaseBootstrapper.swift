import FirebaseCore
import Foundation

// AppEnvironment is in Config/Env.swift - accessible from same module

enum FirebaseBootstrapper {
  private static var didConfigure = false
  private static let lock = NSLock()

  static var isConfigured: Bool {
    lock.lock()
    defer { lock.unlock() }
    return didConfigure
  }

  static func configureIfNeeded(source: String) {
    lock.lock()
    if didConfigure {
      lock.unlock()
      debugLog("✅ FirebaseBootstrapper (\(source)): Firebase already configured")
      return
    }
    lock.unlock()

    // ✅ CRITICAL: Check if GoogleService-Info.plist exists before configuring
    guard AppEnvironment.isFirebaseConfigured else {
      debugLog("⚠️ FirebaseBootstrapper (\(source)): GoogleService-Info.plist not found")
      debugLog("📝 App will run in guest mode (offline-only)")
      debugLog("📝 Add GoogleService-Info.plist to enable Firebase features")
      return
    }

    debugLog("🔥 FirebaseBootstrapper (\(source)): Configuring Firebase")
    FirebaseApp.configure()
    FirebaseConfiguration.configureFirestore()

    lock.lock()
    didConfigure = true
    lock.unlock()
    debugLog("✅ FirebaseBootstrapper (\(source)): Firebase configured successfully")
  }
}

