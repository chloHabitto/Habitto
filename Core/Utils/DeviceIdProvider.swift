import Foundation
import UIKit

// MARK: - DeviceIdProvider

/// Provides stable device identifier for event sourcing
///
/// Uses identifierForVendor to generate a stable device ID that:
/// - Persists across app reinstalls (on same device)
/// - Changes if app is deleted and reinstalled
/// - Unique per device for conflict resolution
@MainActor
final class DeviceIdProvider {
    // MARK: - Singleton
    
    static let shared = DeviceIdProvider()
    
    // MARK: - Properties
    
    /// Stable device identifier
    /// Format: "iOS_{deviceModel}_{identifierForVendor}"
    private let deviceId: String
    
    // MARK: - Initialization
    
    private init() {
        // Generate stable device ID: "iOS_{model}_{identifierForVendor}"
        let model = UIDevice.current.model.replacingOccurrences(of: " ", with: "_")
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.deviceId = "iOS_\(model)_\(vendorId)"
        
        print("🔧 DeviceIdProvider: Generated deviceId: \(deviceId)")
    }
    
    // MARK: - Public API
    
    /// Get current device ID
    var currentDeviceId: String {
        deviceId
    }
}

