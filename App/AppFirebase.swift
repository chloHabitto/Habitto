//
//  AppFirebase.swift
//  Habitto
//
//  Centralized Firebase configuration and initialization
//

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

// MARK: - FirebaseConfiguration

/// Centralized Firebase configuration manager
enum FirebaseConfiguration {
  // MARK: Internal
  
  /// Configure all Firebase services
  @MainActor
  static func configure() {
    debugLog("🔥 FirebaseConfiguration: Starting Firebase initialization...")
    
    // Check if Firebase is already configured
    if FirebaseApp.app() != nil {
      debugLog("✅ FirebaseConfiguration: Firebase already configured")
      configureFirestore()
      return
    }
    
    // Check if GoogleService-Info.plist exists
    guard AppEnvironment.isFirebaseConfigured else {
      debugLog("⚠️ FirebaseConfiguration: Firebase configuration missing")
      debugLog("📝 Add GoogleService-Info.plist to enable Firebase features")
      debugLog("📝 App will run with limited functionality (unit tests will use mocks)")
      return
    }
    
    // Configure Firebase
    FirebaseApp.configure()
    debugLog("✅ FirebaseConfiguration: Firebase Core configured")
    
    // Configure Firestore with offline persistence
    configureFirestore()
    
    // Configure Auth
    configureAuth()
    
    // Log configuration status
    logConfigurationStatus()
  }
  
  /// Configure Firestore settings (offline persistence, emulator, etc.)
  /// ⚠️ IMPORTANT: This must be called BEFORE any other Firestore access in the app
  /// Can be called from any thread - Firestore configuration is thread-safe
  static func configureFirestore() {
    debugLog("🔥 FirebaseConfiguration: Configuring Firestore...")
    
    // Create and configure settings first
    let settings = FirestoreSettings()
    
    // Enable offline persistence
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
    
    // Use emulator if configured
    if AppEnvironment.isUsingEmulator {
      debugLog("🧪 FirebaseConfiguration: Using Firestore Emulator at \(AppEnvironment.firestoreEmulatorHost)")
      let components = AppEnvironment.firestoreEmulatorHost.split(separator: ":")
      if components.count == 2, let port = Int(components[1]) {
        settings.host = "\(components[0]):\(port)"
        settings.isSSLEnabled = false
      }
    }
    
    // Get Firestore instance and apply settings
    // This MUST be the first access to Firestore in the entire app
    let db = Firestore.firestore()
    db.settings = settings
    debugLog("✅ FirebaseConfiguration: Firestore configured with offline persistence")
  }
  
  /// Configure Firebase Auth
  @MainActor
  static func configureAuth() {
    debugLog("🔥 FirebaseConfiguration: Configuring Firebase Auth...")
    
    // Use emulator if configured
    if AppEnvironment.isUsingEmulator {
      debugLog("🧪 FirebaseConfiguration: Using Auth Emulator at \(AppEnvironment.authEmulatorHost)")
      let components = AppEnvironment.authEmulatorHost.split(separator: ":")
      if components.count == 2, let port = Int(components[1]) {
        Auth.auth().useEmulator(withHost: String(components[0]), port: port)
      }
    }
    
    debugLog("✅ FirebaseConfiguration: Firebase Auth configured")
  }
  
  // Note: Anonymous authentication functionality has been removed - can be restored from git history if needed
  
  /// Get current user ID (nil if not authenticated)
  @MainActor
  static var currentUserId: String? {
    Auth.auth().currentUser?.uid
  }
  
  // MARK: Private
  
  @MainActor
  private static func logConfigurationStatus() {
    let status = AppEnvironment.firebaseConfigurationStatus
    debugLog("📊 FirebaseConfiguration Status: \(status.message)")
    
    if AppEnvironment.isRunningTests {
      debugLog("🧪 Running in test environment")
    }
    
    if AppEnvironment.isUsingEmulator {
      debugLog("🧪 Using Firebase Emulator Suite")
      debugLog("   - Firestore: \(AppEnvironment.firestoreEmulatorHost)")
      debugLog("   - Auth: \(AppEnvironment.authEmulatorHost)")
    }
  }
}

// MARK: - FirebaseService

/// Base protocol for all Firebase services
@MainActor
protocol FirebaseService {
  /// Check if Firebase is properly configured
  var isConfigured: Bool { get }
  
  /// Get current authenticated user ID
  var currentUserId: String? { get }
}

extension FirebaseService {
  var isConfigured: Bool {
    AppEnvironment.isFirebaseConfigured
  }
  
  var currentUserId: String? {
    FirebaseConfiguration.currentUserId
  }
}

