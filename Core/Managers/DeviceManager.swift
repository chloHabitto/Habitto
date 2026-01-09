import Foundation
import FirebaseAuth
import FirebaseFirestore
import OSLog
import UIKit

// MARK: - DeviceManager

/// Actor that manages device registration and tracking for users
///
/// Responsibilities:
/// - Register current device on app launch
/// - Fetch all devices for current user
/// - Update device name
/// - Remove devices (premium only)
/// - Cleanup stale devices (>90 days inactive)
actor DeviceManager {
  // MARK: - Singleton
  
  static let shared = DeviceManager()
  
  // MARK: - Properties
  
  private let firestore: Firestore
  private let logger = Logger(subsystem: "com.habitto.app", category: "DeviceManager")
  
  // MARK: - Initialization
  
  private init() {
    self.firestore = Firestore.firestore()
    logger.info("DeviceManager initialized")
  }
  
  // MARK: - Device Registration
  
  /// Register or update the current device in Firestore
  /// Called on every app launch to update lastLogin timestamp
  func registerCurrentDevice() async {
    guard let userId = await getCurrentUserId() else {
      logger.info("⏭️ Skipping device registration - no authenticated user")
      return
    }
    
    guard !CurrentUser.isGuestId(userId) else {
      logger.info("⏭️ Skipping device registration - guest user")
      return
    }
    
    do {
      let currentDevice = UserDevice.createCurrentDevice()
      let deviceRef = firestore.collection("users")
        .document(userId)
        .collection("devices")
        .document(currentDevice.id)
      
      // Check if document exists first
      let doc = try await deviceRef.getDocument()
      let isNewDevice = !doc.exists
      
      // Update lastLogin and deviceName (merge to preserve existing name if set)
      var updateData: [String: Any] = [
        "id": currentDevice.id,
        "deviceModel": currentDevice.deviceModel,
        "lastLogin": Timestamp(date: Date()),
        "appVersion": currentDevice.appVersion
      ]
      
      // Only update deviceName if it's a new device (preserve user-edited name for existing)
      if isNewDevice {
        updateData["deviceName"] = currentDevice.deviceName
        updateData["createdAt"] = Timestamp(date: Date())
      }
      
      try await deviceRef.setData(updateData, merge: true)
      
      logger.info("✅ Device registered/updated: \(currentDevice.id)")
      
      // Cleanup stale devices as a side effect (fire-and-forget)
      Task {
        await cleanupStaleDevices()
      }
      
    } catch {
      logger.error("❌ Failed to register device: \(error.localizedDescription)")
      // Don't throw - device registration shouldn't block app launch
    }
  }
  
  // MARK: - Device Fetching
  
  /// Fetch all devices for the current user
  func fetchAllDevices() async throws -> [UserDevice] {
    guard let userId = await getCurrentUserId() else {
      throw DeviceManagerError.notAuthenticated
    }
    
    guard !CurrentUser.isGuestId(userId) else {
      throw DeviceManagerError.guestUser
    }
    
    let devicesRef = firestore.collection("users")
      .document(userId)
      .collection("devices")
    
    let snapshot = try await devicesRef.getDocuments()
    
    var devices: [UserDevice] = []
    for document in snapshot.documents {
      if let device = UserDevice(from: document.data()) {
        devices.append(device)
      } else {
        logger.warning("⚠️ Failed to parse device document: \(document.documentID)")
      }
    }
    
    // Sort by lastLogin descending (most recent first)
    devices.sort { $0.lastLogin > $1.lastLogin }
    
    logger.info("✅ Fetched \(devices.count) devices for user: \(userId)")
    return devices
  }
  
  // MARK: - Device Updates
  
  /// Update the name of the current device
  func updateDeviceName(_ newName: String) async throws {
    guard let userId = await getCurrentUserId() else {
      throw DeviceManagerError.notAuthenticated
    }
    
    guard !CurrentUser.isGuestId(userId) else {
      throw DeviceManagerError.guestUser
    }
    
    let deviceId = KeychainManager.shared.getOrCreateDeviceIdentifier()
    let deviceRef = firestore.collection("users")
      .document(userId)
      .collection("devices")
      .document(deviceId)
    
    try await deviceRef.updateData([
      "deviceName": newName
    ])
    
    logger.info("✅ Updated device name: \(newName)")
  }
  
  // MARK: - Device Removal
  
  /// Remove a device (premium users only)
  /// Cannot remove the current device
  func removeDevice(_ deviceId: String) async throws {
    guard let userId = await getCurrentUserId() else {
      throw DeviceManagerError.notAuthenticated
    }
    
    guard !CurrentUser.isGuestId(userId) else {
      throw DeviceManagerError.guestUser
    }
    
    let currentDeviceId = KeychainManager.shared.getOrCreateDeviceIdentifier()
    guard deviceId != currentDeviceId else {
      throw DeviceManagerError.cannotRemoveCurrentDevice
    }
    
    let deviceRef = firestore.collection("users")
      .document(userId)
      .collection("devices")
      .document(deviceId)
    
    try await deviceRef.delete()
    
    logger.info("✅ Removed device: \(deviceId)")
  }
  
  // MARK: - Cleanup
  
  /// Remove devices that haven't logged in for more than 90 days
  func cleanupStaleDevices() async {
    guard let userId = await getCurrentUserId() else {
      return
    }
    
    guard !CurrentUser.isGuestId(userId) else {
      return
    }
    
    do {
      let devicesRef = firestore.collection("users")
        .document(userId)
        .collection("devices")
      
      let snapshot = try await devicesRef.getDocuments()
      let cutoffDate = Date().addingTimeInterval(-90 * 24 * 60 * 60) // 90 days ago
      let currentDeviceId = KeychainManager.shared.getOrCreateDeviceIdentifier()
      
      var removedCount = 0
      for document in snapshot.documents {
        // Never remove current device
        if document.documentID == currentDeviceId {
          continue
        }
        
        if let device = UserDevice(from: document.data()),
           device.lastLogin < cutoffDate {
          try await document.reference.delete()
          removedCount += 1
          logger.info("🗑️ Removed stale device: \(device.deviceName) (last login: \(device.lastLogin))")
        }
      }
      
      if removedCount > 0 {
        logger.info("✅ Cleaned up \(removedCount) stale device(s)")
      }
      
    } catch {
      logger.error("❌ Failed to cleanup stale devices: \(error.localizedDescription)")
      // Don't throw - cleanup is best effort
    }
  }
  
  // MARK: - Helpers
  
  private func getCurrentUserId() async -> String? {
    await MainActor.run {
      return Auth.auth().currentUser?.uid
    }
  }
}

// MARK: - DeviceManagerError

enum DeviceManagerError: LocalizedError {
  case notAuthenticated
  case guestUser
  case cannotRemoveCurrentDevice
  case deviceNotFound
  
  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "User is not authenticated. Please sign in first."
    case .guestUser:
      return "Guest users cannot manage devices."
    case .cannotRemoveCurrentDevice:
      return "Cannot remove the current device."
    case .deviceNotFound:
      return "Device not found."
    }
  }
}
