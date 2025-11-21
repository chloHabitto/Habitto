import Foundation
import CloudKit
import Combine
import OSLog
import SwiftUI

// MARK: - ICloudStatusManager

/// Manages iCloud account status and sync availability
@MainActor
final class ICloudStatusManager: ObservableObject {
  // MARK: - Published Properties
  
  @Published var isAvailable = false
  @Published var statusMessage = "Checking iCloud status..."
  @Published var accountStatus: CKAccountStatus = .couldNotDetermine
  
  // MARK: - Singleton
  
  static let shared = ICloudStatusManager()
  
  // MARK: - Lifecycle
  
  private init() {
    // Don't check status automatically on init to prevent crashes
    // CloudKit APIs may crash if entitlement is not configured
    // Status will be checked when explicitly requested (e.g., user taps sync status)
    // For now, show default message
    Task { @MainActor in
      self.statusMessage = "Local only"
      self.isAvailable = false
    }
  }
  
  // MARK: - Public Methods
  
  /// Check iCloud account status
  func checkStatus() async {
    let logger = Logger(subsystem: "com.habitto.app", category: "ICloudStatus")
    
    // First check if iCloud Drive is available (prerequisite for CloudKit)
    guard FileManager.default.ubiquityIdentityToken != nil else {
      await MainActor.run {
        self.accountStatus = .couldNotDetermine
        self.isAvailable = false
        self.statusMessage = "Local only"
        logger.info("⚠️ iCloud: iCloud Drive not available - using local storage")
      }
      return
    }
    
    // Try to check CloudKit status - this may fail if entitlement is not configured
    // We'll catch the error and handle it gracefully
    do {
      let container = CKContainer.default()
      let status = try await container.accountStatus()
      
      await MainActor.run {
        self.accountStatus = status
        
        switch status {
        case .available:
          self.isAvailable = true
          self.statusMessage = "Syncing across devices"
          logger.info("✅ iCloud: Account available - sync enabled")
          
        case .noAccount:
          self.isAvailable = false
          self.statusMessage = "Sign into iCloud in Settings to sync"
          logger.info("⚠️ iCloud: No account - user needs to sign in")
          
        case .restricted:
          self.isAvailable = false
          self.statusMessage = "iCloud is restricted"
          logger.info("⚠️ iCloud: Account restricted - sync disabled")
          
        case .couldNotDetermine:
          self.isAvailable = false
          self.statusMessage = "Checking iCloud status..."
          logger.info("⚠️ iCloud: Could not determine account status")
          
        case .temporarilyUnavailable:
          self.isAvailable = false
          self.statusMessage = "iCloud temporarily unavailable"
          logger.info("⚠️ iCloud: Temporarily unavailable")
          
        @unknown default:
          self.isAvailable = false
          self.statusMessage = "iCloud status unknown"
          logger.warning("⚠️ iCloud: Unknown account status")
        }
      }
    } catch {
      // Handle CloudKit errors gracefully
      // The error might be due to missing entitlement or other CloudKit issues
      let errorDescription = error.localizedDescription
      let nsError = error as NSError
      
      // Check if this is an entitlement-related error
      let isEntitlementError = errorDescription.contains("icloud-services entitlement") ||
                               errorDescription.contains("entitlement") ||
                               nsError.domain.contains("CloudKit")
      
      await MainActor.run {
        if isEntitlementError {
          self.accountStatus = .couldNotDetermine
          self.isAvailable = false
          self.statusMessage = "Local only (iCloud not configured)"
          logger.warning("⚠️ iCloud: CloudKit entitlement not configured - using local storage")
        } else {
          self.accountStatus = .couldNotDetermine
          self.isAvailable = false
          self.statusMessage = "Unable to check iCloud status"
          logger.error("❌ iCloud: Error checking status - \(errorDescription)")
        }
      }
    }
  }
  
  /// Get a user-friendly status description
  var statusDescription: String {
    switch accountStatus {
    case .available:
      return "Your habits are automatically syncing across all your devices via iCloud."
    case .noAccount:
      return "Sign into iCloud in Settings to enable automatic sync across your devices."
    case .restricted:
      return "iCloud sync is currently restricted. Check your device settings."
    case .couldNotDetermine:
      return "Unable to determine iCloud status. Sync may not be available."
    case .temporarilyUnavailable:
      return "iCloud is temporarily unavailable. Sync will resume automatically."
    @unknown default:
      return "iCloud status is unknown. Sync may not be available."
    }
  }
  
  /// Get icon name for current status
  var statusIcon: String {
    if isAvailable {
      return "icloud.fill"
    } else {
      return "icloud.slash"
    }
  }
  
  /// Get color for current status
  var statusColor: Color {
    if isAvailable {
      return Color(red: 0.2, green: 0.8, blue: 0.2)
    } else {
      return .gray
    }
  }
}

