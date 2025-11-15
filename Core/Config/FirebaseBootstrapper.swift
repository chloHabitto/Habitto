import FirebaseCore
import Foundation

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

    debugLog("🔥 FirebaseBootstrapper (\(source)): Configuring Firebase")
    FirebaseApp.configure()
    FirebaseConfiguration.configureFirestore()

    lock.lock()
    didConfigure = true
    lock.unlock()
    debugLog("✅ FirebaseBootstrapper (\(source)): Firebase configured successfully")
  }
}

