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
    print("🔥 FirebaseConfiguration: Starting Firebase initialization...")
    
    // Check if Firebase is already configured
    if FirebaseApp.app() != nil {
      print("✅ FirebaseConfiguration: Firebase already configured")
      configureFirestore()
      return
    }
    
    // Check if GoogleService-Info.plist exists
    guard AppEnvironment.isFirebaseConfigured else {
      print("⚠️ FirebaseConfiguration: Firebase configuration missing")
      print("📝 Add GoogleService-Info.plist to enable Firebase features")
      print("📝 App will run with limited functionality (unit tests will use mocks)")
      return
    }
    
    // Configure Firebase
    FirebaseApp.configure()
    print("✅ FirebaseConfiguration: Firebase Core configured")
    
    // Configure Firestore with offline persistence
    configureFirestore()
    
    // Configure Auth
    configureAuth()
    
    // Log configuration status
    logConfigurationStatus()
  }
  
  /// Configure Firestore settings (offline persistence, emulator, etc.)
  @MainActor
  static func configureFirestore() {
    print("🔥 FirebaseConfiguration: Configuring Firestore...")
    
    let db = Firestore.firestore()
    let settings = FirestoreSettings()
    
    // Enable offline persistence
    settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
    
    // Use emulator if configured
    if AppEnvironment.isUsingEmulator {
      print("🧪 FirebaseConfiguration: Using Firestore Emulator at \(AppEnvironment.firestoreEmulatorHost)")
      let components = AppEnvironment.firestoreEmulatorHost.split(separator: ":")
      if components.count == 2, let port = Int(components[1]) {
        settings.host = "\(components[0]):\(port)"
        settings.isSSLEnabled = false
      }
    }
    
    db.settings = settings
    print("✅ FirebaseConfiguration: Firestore configured with offline persistence")
  }
  
  /// Configure Firebase Auth
  @MainActor
  static func configureAuth() {
    print("🔥 FirebaseConfiguration: Configuring Firebase Auth...")
    
    // Use emulator if configured
    if AppEnvironment.isUsingEmulator {
      print("🧪 FirebaseConfiguration: Using Auth Emulator at \(AppEnvironment.authEmulatorHost)")
      let components = AppEnvironment.authEmulatorHost.split(separator: ":")
      if components.count == 2, let port = Int(components[1]) {
        Auth.auth().useEmulator(withHost: String(components[0]), port: port)
      }
    }
    
    print("✅ FirebaseConfiguration: Firebase Auth configured")
  }
  
  /// Ensure user is authenticated (sign in anonymously if needed)
  @MainActor
  static func ensureAuthenticated() async throws -> String {
    print("🔐 FirebaseConfiguration: Ensuring user authentication...")
    
    // Check if user is already signed in
    if let currentUser = Auth.auth().currentUser {
      print("✅ FirebaseConfiguration: User already signed in: \(currentUser.uid)")
      return currentUser.uid
    }
    
    // Sign in anonymously
    print("🔐 FirebaseConfiguration: No user signed in, signing in anonymously...")
    let result = try await Auth.auth().signInAnonymously()
    let uid = result.user.uid
    
    print("✅ FirebaseConfiguration: Anonymous sign-in successful: \(uid)")
    return uid
  }
  
  /// Get current user ID (nil if not authenticated)
  @MainActor
  static var currentUserId: String? {
    Auth.auth().currentUser?.uid
  }
  
  // MARK: Private
  
  @MainActor
  private static func logConfigurationStatus() {
    let status = AppEnvironment.firebaseConfigurationStatus
    print("📊 FirebaseConfiguration Status: \(status.message)")
    
    if AppEnvironment.isRunningTests {
      print("🧪 Running in test environment")
    }
    
    if AppEnvironment.isUsingEmulator {
      print("🧪 Using Firebase Emulator Suite")
      print("   - Firestore: \(AppEnvironment.firestoreEmulatorHost)")
      print("   - Auth: \(AppEnvironment.authEmulatorHost)")
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

