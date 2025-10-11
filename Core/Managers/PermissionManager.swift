import AVFoundation
import Foundation
import Photos
import UIKit

/// Manager for handling camera and photo library permissions
@MainActor
class PermissionManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    checkPermissions()
  }

  // MARK: Internal

  static let shared = PermissionManager()

  @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
  @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined

  /// Check if camera is available and permission is granted
  var canUseCamera: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera) && cameraPermissionStatus == .authorized
  }

  /// Check if photo library is available and permission is granted
  var canUsePhotoLibrary: Bool {
    photoLibraryPermissionStatus == .authorized || photoLibraryPermissionStatus == .limited
  }

  /// Check current permission status for both camera and photo library
  func checkPermissions() {
    cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    print("🔐 PermissionManager: Camera status: \(cameraPermissionStatus.rawValue)")
    print("🔐 PermissionManager: Photo Library status: \(photoLibraryPermissionStatus.rawValue)")
  }

  /// Request camera permission
  func requestCameraPermission(completion: @escaping (Bool) -> Void) {
    print("📷 PermissionManager: Requesting camera permission...")

    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      DispatchQueue.main.async {
        self?.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if granted {
          print("✅ PermissionManager: Camera permission granted")
        } else {
          print("❌ PermissionManager: Camera permission denied")
        }

        completion(granted)
      }
    }
  }

  /// Request photo library permission
  func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
    print("🖼️ PermissionManager: Requesting photo library permission...")

    PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
      DispatchQueue.main.async {
        self?.photoLibraryPermissionStatus = status

        let granted = (status == .authorized || status == .limited)
        if granted {
          print("✅ PermissionManager: Photo library permission granted")
        } else {
          print("❌ PermissionManager: Photo library permission denied")
        }

        completion(granted)
      }
    }
  }

  /// Get user-friendly permission status message
  func getCameraPermissionMessage() -> String {
    switch cameraPermissionStatus {
    case .authorized:
      return "Camera access granted"
    case .denied:
      return "Camera access denied. Please enable in Settings."
    case .restricted:
      return "Camera access restricted"
    case .notDetermined:
      return "Camera permission needed"
    @unknown default:
      return "Unknown camera permission status"
    }
  }

  /// Get user-friendly photo library permission status message
  func getPhotoLibraryPermissionMessage() -> String {
    switch photoLibraryPermissionStatus {
    case .authorized:
      return "Photo library access granted"
    case .denied:
      return "Photo library access denied. Please enable in Settings."
    case .restricted:
      return "Photo library access restricted"
    case .notDetermined:
      return "Photo library permission needed"
    case .limited:
      return "Photo library access limited"
    @unknown default:
      return "Unknown photo library permission status"
    }
  }

  /// Open app settings for permission management
  func openAppSettings() {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
      print("❌ PermissionManager: Cannot open app settings")
      return
    }

    if UIApplication.shared.canOpenURL(settingsUrl) {
      UIApplication.shared.open(settingsUrl) { success in
        print(success
          ? "✅ PermissionManager: Opened app settings"
          : "❌ PermissionManager: Failed to open app settings")
      }
    }
  }
}
