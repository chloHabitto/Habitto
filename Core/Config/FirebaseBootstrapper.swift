import FirebaseCore
import Foundation

enum FirebaseBootstrapper {
  private static var didConfigure = false
  private static let lock = NSLock()

  static func configureIfNeeded(source: String) {
    lock.lock()
    defer { lock.unlock() }

    guard !didConfigure else {
      if FirebaseApp.app() == nil {
        debugLog("⚠️ FirebaseBootstrapper (\(source)): Expected configured app but none found")
      }
      return
    }

    if FirebaseApp.app() == nil {
      debugLog("🔥 FirebaseBootstrapper (\(source)): Configuring Firebase")
      FirebaseApp.configure()
    } else {
      debugLog("ℹ️ FirebaseBootstrapper (\(source)): Firebase already configured")
    }

    FirebaseConfiguration.configureFirestore()
    didConfigure = true
  }
}

