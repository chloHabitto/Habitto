import Combine
import Foundation
import UIKit

// MARK: - Avatar

/// Represents a user avatar with its metadata
struct Avatar: Identifiable, Codable, Equatable {
  // MARK: Lifecycle

  init(
    id: String,
    imageName: String,
    displayName: String,
    isDefault: Bool = false,
    isCustomPhoto: Bool = false,
    customPhotoData: Data? = nil)
  {
    self.id = id
    self.imageName = imageName
    self.displayName = displayName
    self.isDefault = isDefault
    self.isCustomPhoto = isCustomPhoto
    self.customPhotoData = customPhotoData
  }

  // MARK: Internal

  let id: String
  let imageName: String
  let displayName: String
  let isDefault: Bool
  let isCustomPhoto: Bool
  let customPhotoData: Data?

  /// Create a custom photo avatar
  static func customPhoto(id: String, imageData: Data) -> Avatar {
    Avatar(
      id: id,
      imageName: "custom_photo",
      displayName: "Custom Photo",
      isDefault: false,
      isCustomPhoto: true,
      customPhotoData: imageData)
  }
}

// MARK: - AvatarManager

/// Manager for handling avatar selection and persistence
@MainActor
class AvatarManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // Initialize with default avatar
    self.selectedAvatar = AvatarManager.getDefaultAvatar()
    loadSelectedAvatar()

    // Listen for authentication state changes
    authManager.$authState
      .sink { [weak self] authState in
        self?.handleAuthStateChange(authState)
      }
      .store(in: &cancellables)
  }

  // MARK: Internal

  static let shared = AvatarManager()

  @Published var selectedAvatar: Avatar

  /// Get the default avatar (Default-Profile@4x)
  static func getDefaultAvatar() -> Avatar {
    Avatar(
      id: "default",
      imageName: "Default-Profile@4x",
      displayName: "Default",
      isDefault: true)
  }

  /// Get all available avatars
  func getAllAvatars() -> [Avatar] {
    var avatars: [Avatar] = []

    // Add default avatar first
    avatars.append(AvatarManager.getDefaultAvatar())

    // Add emoji avatars (001-emoji@4x through 035-emoji@4x)
    for i in 1 ... 35 {
      let imageName = String(format: "%03d-emoji@4x", i)
      let avatar = Avatar(
        id: "emoji_\(i)",
        imageName: imageName,
        displayName: "Avatar \(i)",
        isDefault: false)
      avatars.append(avatar)
    }

    return avatars
  }

  /// Select a new avatar
  func selectAvatar(_ avatar: Avatar) {
    print("🔄 AvatarManager: Selecting avatar: \(avatar.displayName) (ID: \(avatar.id))")
    selectedAvatar = avatar
    saveSelectedAvatar()

    // If user is authenticated, also save to their account
    if isUserAuthenticated() {
      saveAvatarToUserAccount(avatar)
    }

    print("✅ AvatarManager: Avatar selected and saved successfully")
  }

  /// Select a custom photo as avatar
  func selectCustomPhoto(_ image: UIImage) {
    print("📸 AvatarManager: Selecting custom photo")

    // Convert UIImage to Data
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      print("❌ AvatarManager: Failed to convert image to data")
      return
    }

    // Create custom photo avatar
    let customAvatar = Avatar.customPhoto(id: "custom_\(UUID().uuidString)", imageData: imageData)
    selectAvatar(customAvatar)
  }

  /// Reset to default avatar
  func resetToDefault() {
    selectAvatar(AvatarManager.getDefaultAvatar())
  }

  /// Handle authentication state changes
  func handleAuthStateChange(_ authState: AuthenticationState) {
    print("🔄 AvatarManager: Auth state changed to: \(authState)")
    switch authState {
    case .authenticated:
      // User logged in - load their avatar
      if let user = authManager.currentUser {
        print(
          "👤 AvatarManager: User authenticated - UID: \(user.uid), Email: \(user.email ?? "no-email")")
      }
      print("👤 AvatarManager: User authenticated, loading user avatar")
      loadAvatarFromUserAccount()

    case .authenticating,
         .error,
         .unauthenticated:
      // User logged out or not authenticated - load guest avatar
      print("👤 AvatarManager: User not authenticated, loading guest avatar")
      loadGuestAvatar()
    }
  }

  /// Clear current avatar (useful when switching accounts)
  func clearCurrentAvatar() {
    print("🗑️ AvatarManager: Clearing current avatar")
    selectedAvatar = AvatarManager.getDefaultAvatar()
  }

  /// Migrate guest data to user account
  func migrateGuestDataToUserAccount() {
    guard isUserAuthenticated() else { return }

    // Check if user already has an avatar
    let userKey = getUserSpecificKey()
    if userDefaults.data(forKey: userKey) != nil {
      print("👤 AvatarManager: User already has an avatar, skipping migration")
      return
    }

    // Check if there's guest data to migrate
    guard let guestData = userDefaults.data(forKey: guestAvatarKey),
          let guestAvatar = try? JSONDecoder().decode(Avatar.self, from: guestData) else
    {
      print("👤 AvatarManager: No guest avatar data to migrate")
      return
    }

    // Migrate guest avatar to user account
    userDefaults.set(guestData, forKey: userKey)
    selectedAvatar = guestAvatar
    print("🔄 AvatarManager: Migrated guest avatar to user account: \(guestAvatar.displayName)")
  }

  /// Clear guest data (called when user signs up and chooses to start fresh)
  func clearGuestData() {
    userDefaults.removeObject(forKey: guestAvatarKey)
    print("🗑️ AvatarManager: Cleared guest avatar data")
  }

  /// Debug method to list all stored avatars
  func debugListAllStoredAvatars() {
    // List guest avatar
    if let guestData = userDefaults.data(forKey: guestAvatarKey),
       let guestAvatar = try? JSONDecoder().decode(Avatar.self, from: guestData)
    {
      print("  Guest: \(guestAvatar.displayName) (ID: \(guestAvatar.id))")
    } else {
      print("  Guest: No data")
    }

    // List all user-specific avatars
    let allKeys = userDefaults.dictionaryRepresentation().keys
    let userKeys = allKeys.filter { $0.hasPrefix(selectedAvatarKey + "_") }

    for key in userKeys {
      if let data = userDefaults.data(forKey: key),
         let avatar = try? JSONDecoder().decode(Avatar.self, from: data)
      {
        print("  User (\(key)): \(avatar.displayName) (ID: \(avatar.id))")
      }
    }

    if userKeys.isEmpty {
      print("  Users: No user avatars found")
    }
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let selectedAvatarKey = "SelectedAvatar"
  private let guestAvatarKey = "GuestSelectedAvatar"

  /// Dependencies
  @Published private var authManager = AuthenticationManager.shared

  private var cancellables = Set<AnyCancellable>()

  /// Load the selected avatar from storage
  private func loadSelectedAvatar() {
    if isUserAuthenticated() {
      loadAvatarFromUserAccount()
    } else {
      loadGuestAvatar()
    }
  }

  /// Load avatar for authenticated user
  private func loadAvatarFromUserAccount() {
    // For now, we'll use UserDefaults with user-specific key
    // In a full implementation, this would load from Firebase Storage
    let userKey = getUserSpecificKey()

    guard let data = userDefaults.data(forKey: userKey),
          let avatar = try? JSONDecoder().decode(Avatar.self, from: data) else
    {
      // If no saved avatar for this user, use default
      print("❌ AvatarManager: No saved avatar found for user, using default")
      selectedAvatar = AvatarManager.getDefaultAvatar()
      return
    }

    selectedAvatar = avatar
    print(
      "✅ AvatarManager: Loaded avatar for authenticated user: \(avatar.displayName) (ID: \(avatar.id))")
  }

  /// Load avatar for guest user
  private func loadGuestAvatar() {
    guard let data = userDefaults.data(forKey: guestAvatarKey),
          let avatar = try? JSONDecoder().decode(Avatar.self, from: data) else
    {
      // If no saved guest avatar, use default
      selectedAvatar = AvatarManager.getDefaultAvatar()
      return
    }

    selectedAvatar = avatar
    print("👤 AvatarManager: Loaded guest avatar: \(avatar.displayName)")
  }

  /// Save the selected avatar to appropriate storage
  private func saveSelectedAvatar() {
    guard let data = try? JSONEncoder().encode(selectedAvatar) else {
      print("❌ AvatarManager: Failed to encode selected avatar")
      return
    }

    if isUserAuthenticated() {
      // Save to user-specific storage
      let userKey = getUserSpecificKey()
      userDefaults.set(data, forKey: userKey)
      print(
        "💾 AvatarManager: Saved avatar for authenticated user with key: \(userKey) - \(selectedAvatar.displayName)")
    } else {
      // Save to guest storage
      userDefaults.set(data, forKey: guestAvatarKey)
      print("💾 AvatarManager: Saved guest avatar: \(selectedAvatar.displayName)")
    }
  }

  /// Check if user is currently authenticated
  private func isUserAuthenticated() -> Bool {
    switch authManager.authState {
    case .authenticated:
      true
    case .authenticating,
         .error,
         .unauthenticated:
      false
    }
  }

  /// Get user-specific storage key
  private func getUserSpecificKey() -> String {
    guard let user = authManager.currentUser else {
      return selectedAvatarKey // Fallback to default key
    }
    let userID = user.uid
    let userEmail = user.email ?? "no-email"
    // Use both UID and email to ensure uniqueness across different auth providers
    let uniqueKey = "\(userID)_\(userEmail.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))"
    print("🔑 AvatarManager: Generated unique key for user: \(uniqueKey)")
    return "\(selectedAvatarKey)_\(uniqueKey)"
  }

  /// Save avatar to user's Firebase account
  private func saveAvatarToUserAccount(_: Avatar) {
    // For custom photos, we would upload to Firebase Storage and get a URL
    // For now, we'll just save the avatar data locally with user-specific key
    // In a full implementation, this would:
    // 1. Upload custom photo to Firebase Storage
    // 2. Get the download URL
    // 3. Update user's photoURL in Firebase Auth
    print(
      "🔐 AvatarManager: Would save avatar to user account (Firebase Storage integration needed)")
  }
}
