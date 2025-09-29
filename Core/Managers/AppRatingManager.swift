import Foundation
import StoreKit
import UIKit

/// Manager for handling app rating requests and App Store navigation
/// 
/// This manager provides a clean interface for requesting app ratings using StoreKit's
/// in-app rating system with automatic fallback to the App Store.
/// 
/// ## Features
/// - Native in-app rating using `SKStoreReviewController`
/// - Automatic fallback to App Store if in-app rating is not available
/// - iOS 14+ window scene support for proper rating requests
/// - Production-ready error handling and logging
/// 
/// ## Usage
/// ```swift
/// // Request rating with automatic fallback
/// AppRatingManager.shared.requestRating()
/// 
/// // Request only in-app rating
/// AppRatingManager.shared.requestInAppRating()
/// 
/// // Open App Store directly
/// AppRatingManager.shared.openAppStoreForRating()
/// ```
/// 
/// ## Important Notes
/// - In-app rating is limited to 3 times per year per app
/// - The system decides when to actually show the rating prompt
/// - Always provide a fallback to App Store for better user experience
@MainActor
class AppRatingManager: ObservableObject {
    static let shared = AppRatingManager()
    
    // MARK: - Configuration
    private let appStoreID = "YOUR_APP_STORE_ID" // TODO: Replace with actual App Store ID
    
    private var appStoreURL: String {
        return "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Request an in-app rating using StoreKit
    /// This will show the native iOS rating prompt if the system allows it
    func requestInAppRating() {
        print("⭐ AppRatingManager: Requesting in-app rating")
        
        // Get the current window scene for iOS 14+
        guard let windowScene = getCurrentWindowScene() else {
            print("⚠️ AppRatingManager: No window scene found, falling back to App Store")
            openAppStoreForRating()
            return
        }
        
        // Request in-app rating using the window scene
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: windowScene)
        } else {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        print("✅ AppRatingManager: In-app rating requested successfully")
    }
    
    /// Open the App Store directly for rating
    /// This is used as a fallback when in-app rating is not available
    func openAppStoreForRating() {
        print("⭐ AppRatingManager: Opening App Store for rating")
        
        guard let url = URL(string: appStoreURL) else {
            print("❌ AppRatingManager: Failed to create App Store URL")
            return
        }
        
        UIApplication.shared.open(url) { success in
            if success {
                print("✅ AppRatingManager: App Store opened successfully")
            } else {
                print("❌ AppRatingManager: Failed to open App Store")
            }
        }
    }
    
    /// Request rating with automatic fallback
    /// This will try in-app rating first, then fall back to App Store if needed
    func requestRating() {
        // Check if we can request in-app rating
        if canRequestInAppRating() {
            requestInAppRating()
        } else {
            print("ℹ️ AppRatingManager: In-app rating not available, opening App Store")
            openAppStoreForRating()
        }
    }
    
    // MARK: - Private Methods
    
    /// Get the current active window scene
    private func getCurrentWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
    
    /// Check if in-app rating can be requested
    /// Note: This is a best-effort check as Apple doesn't provide a direct way to check
    private func canRequestInAppRating() -> Bool {
        // In-app rating has limitations:
        // - Can only be shown 3 times per year per app
        // - User must have used the app for a while
        // - System decides when to show it
        // We'll always try in-app first, then fall back to App Store
        return true
    }
}

// MARK: - Convenience Extensions

extension AppRatingManager {
    /// Check if the app is running on iOS 14 or later
    var isiOS14OrLater: Bool {
        if #available(iOS 14.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// Get the App Store URL for the current app
    var appStoreRatingURL: URL? {
        return URL(string: appStoreURL)
    }
    
    /// Get the App Store ID
    var currentAppStoreID: String {
        return appStoreID
    }
}

// MARK: - Usage Examples

/*
 Example usage in SwiftUI views:
 
 struct SomeView: View {
     var body: some View {
         Button("Rate App") {
             AppRatingManager.shared.requestRating()
         }
     }
 }
 
 Example usage in UIKit:
 
 @IBAction func rateButtonTapped(_ sender: UIButton) {
     AppRatingManager.shared.requestRating()
 }
 
 Example for testing (always opens App Store):
 
 AppRatingManager.shared.openAppStoreForRating()
 */
