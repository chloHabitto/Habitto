//
//  Env.swift
//  Habitto
//
//  Environment configuration and Firebase guards
//

import Foundation
import FirebaseCore

// MARK: - AppEnvironment

/// Centralized environment configuration for the app
enum AppEnvironment {
  // MARK: Internal
  
  static var isFirebaseConfigured: Bool {
    // Check if GoogleService-Info.plist exists and is readable
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
      print("⚠️ Env: GoogleService-Info.plist not found")
      return false
    }
    
    guard NSDictionary(contentsOfFile: path) != nil else {
      print("⚠️ Env: GoogleService-Info.plist is not readable")
      return false
    }
    
    return true
  }
  
  static var firebaseConfigurationStatus: ConfigurationStatus {
    guard isFirebaseConfigured else {
      return .missing
    }
    
    guard FirebaseBootstrapper.isConfigured else {
      return .invalid("Firebase app not initialized")
    }
    
    return .configured
  }
  
  /// Check if we're running in a test environment
  static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }
  
  /// Check if we're using Firebase Emulator
  static var isUsingEmulator: Bool {
    ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "true"
  }
  
  /// Get emulator host for Firestore (default: localhost:8080)
  static var firestoreEmulatorHost: String {
    ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"] ?? "localhost:8080"
  }
  
  /// Get emulator host for Auth (default: localhost:9099)
  static var authEmulatorHost: String {
    ProcessInfo.processInfo.environment["AUTH_EMULATOR_HOST"] ?? "localhost:9099"
  }
}

// MARK: - ConfigurationStatus

enum ConfigurationStatus: Equatable {
  case configured
  case missing
  case invalid(String)
  
  // MARK: Internal
  
  var isValid: Bool {
    if case .configured = self {
      return true
    }
    return false
  }
  
  var message: String {
    switch self {
    case .configured:
      return "Firebase is properly configured"
    case .missing:
      return "Firebase not configured. Add GoogleService-Info.plist to your project."
    case .invalid(let reason):
      return "Firebase configuration invalid: \(reason)"
    }
  }
}

