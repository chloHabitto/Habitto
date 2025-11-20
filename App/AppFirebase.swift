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
  
  // DISABLED: Sign-in functionality commented out for future use
  /*
  /// Ensure user is authenticated (sign in anonymously if needed)
  @MainActor
  static func ensureAuthenticated() async throws -> String {
    debugLog("🔐 FirebaseConfiguration: Ensuring user authentication...")
    
    // Check if user is already signed in
    if let currentUser = Auth.auth().currentUser {
      debugLog("✅ FirebaseConfiguration: User already signed in: \(currentUser.uid)")
      return currentUser.uid
    }
    
    // Sign in anonymously
    debugLog("🔐 FirebaseConfiguration: No user signed in, signing in anonymously...")
    let result = try await Auth.auth().signInAnonymously()
    let uid = result.user.uid
    
    debugLog("✅ FirebaseConfiguration: Anonymous sign-in successful: \(uid)")
    return uid
  }
  */
  
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

