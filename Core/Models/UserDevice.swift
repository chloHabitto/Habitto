import Foundation
import UIKit
import FirebaseFirestore

// MARK: - UserDevice

/// Represents a device registered for a user account
struct UserDevice: Codable, Identifiable {
  // MARK: Internal
  
  let id: String                  // Keychain UUID
  var deviceName: String          // User-editable, defaults to deviceModel
  let deviceModel: String         // UIDevice.current.modelName (e.g., "iPhone 12 Pro")
  var lastLogin: Date
  let createdAt: Date
  let appVersion: String          // Bundle.main app version
  
  var isCurrentDevice: Bool {
    return id == KeychainManager.shared.getOrCreateDeviceIdentifier()
  }
  
  // MARK: - Initialization
  
  init(
    id: String,
    deviceName: String,
    deviceModel: String,
    lastLogin: Date,
    createdAt: Date,
    appVersion: String)
  {
    self.id = id
    self.deviceName = deviceName
    self.deviceModel = deviceModel
    self.lastLogin = lastLogin
    self.createdAt = createdAt
    self.appVersion = appVersion
  }
  
  /// Create a new device for the current device
  static func createCurrentDevice() -> UserDevice {
    let deviceId = KeychainManager.shared.getOrCreateDeviceIdentifier()
    let deviceModel = UIDevice.current.modelName
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let now = Date()
    
    return UserDevice(
      id: deviceId,
      deviceName: deviceModel,  // Default to model name, user can edit
      deviceModel: deviceModel,
      lastLogin: now,
      createdAt: now,
      appVersion: appVersion
    )
  }
}

// MARK: - Firestore Conversion

extension UserDevice {
  /// Convert to Firestore dictionary
  func toFirestoreData() -> [String: Any] {
    return [
      "id": id,
      "deviceName": deviceName,
      "deviceModel": deviceModel,
      "lastLogin": Timestamp(date: lastLogin),
      "createdAt": Timestamp(date: createdAt),
      "appVersion": appVersion
    ]
  }
  
  /// Create from Firestore document
  init?(from firestoreData: [String: Any]) {
    guard let id = firestoreData["id"] as? String,
          let deviceName = firestoreData["deviceName"] as? String,
          let deviceModel = firestoreData["deviceModel"] as? String,
          let lastLoginTimestamp = firestoreData["lastLogin"] as? Timestamp,
          let createdAtTimestamp = firestoreData["createdAt"] as? Timestamp,
          let appVersion = firestoreData["appVersion"] as? String
    else {
      return nil
    }
    
    self.id = id
    self.deviceName = deviceName
    self.deviceModel = deviceModel
    self.lastLogin = lastLoginTimestamp.dateValue()
    self.createdAt = createdAtTimestamp.dateValue()
    self.appVersion = appVersion
  }
}
