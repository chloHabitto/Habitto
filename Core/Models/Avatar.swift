import Foundation
import UIKit

/// Represents a user avatar with its metadata
struct Avatar: Identifiable, Codable, Equatable {
    let id: String
    let imageName: String
    let displayName: String
    let isDefault: Bool
    let isCustomPhoto: Bool
    let customPhotoData: Data?
    
    init(id: String, imageName: String, displayName: String, isDefault: Bool = false, isCustomPhoto: Bool = false, customPhotoData: Data? = nil) {
        self.id = id
        self.imageName = imageName
        self.displayName = displayName
        self.isDefault = isDefault
        self.isCustomPhoto = isCustomPhoto
        self.customPhotoData = customPhotoData
    }
    
    /// Create a custom photo avatar
    static func customPhoto(id: String, imageData: Data) -> Avatar {
        return Avatar(
            id: id,
            imageName: "custom_photo",
            displayName: "Custom Photo",
            isDefault: false,
            isCustomPhoto: true,
            customPhotoData: imageData
        )
    }
}

/// Manager for handling avatar selection and persistence
@MainActor
class AvatarManager: ObservableObject {
    static let shared = AvatarManager()
    
    @Published var selectedAvatar: Avatar
    private let userDefaults = UserDefaults.standard
    private let selectedAvatarKey = "SelectedAvatar"
    
    private init() {
        // Initialize with default avatar
        self.selectedAvatar = AvatarManager.getDefaultAvatar()
        loadSelectedAvatar()
    }
    
    /// Get the default avatar (Default-Profile@4x)
    static func getDefaultAvatar() -> Avatar {
        return Avatar(
            id: "default",
            imageName: "Default-Profile@4x",
            displayName: "Default",
            isDefault: true
        )
    }
    
    /// Get all available avatars
    func getAllAvatars() -> [Avatar] {
        var avatars: [Avatar] = []
        
        // Add default avatar first
        avatars.append(AvatarManager.getDefaultAvatar())
        
        // Add emoji avatars (001-emoji@4x through 035-emoji@4x)
        for i in 1...35 {
            let imageName = String(format: "%03d-emoji@4x", i)
            let avatar = Avatar(
                id: "emoji_\(i)",
                imageName: imageName,
                displayName: "Avatar \(i)",
                isDefault: false
            )
            avatars.append(avatar)
        }
        
        return avatars
    }
    
    /// Select a new avatar
    func selectAvatar(_ avatar: Avatar) {
        print("🔄 AvatarManager: Selecting avatar: \(avatar.displayName) (ID: \(avatar.id))")
        selectedAvatar = avatar
        saveSelectedAvatar()
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
    
    /// Load the selected avatar from UserDefaults
    private func loadSelectedAvatar() {
        guard let data = userDefaults.data(forKey: selectedAvatarKey),
              let avatar = try? JSONDecoder().decode(Avatar.self, from: data) else {
            // If no saved avatar, use default
            selectedAvatar = AvatarManager.getDefaultAvatar()
            return
        }
        
        selectedAvatar = avatar
    }
    
    /// Save the selected avatar to UserDefaults
    private func saveSelectedAvatar() {
        guard let data = try? JSONEncoder().encode(selectedAvatar) else {
            print("❌ AvatarManager: Failed to encode selected avatar")
            return
        }
        
        userDefaults.set(data, forKey: selectedAvatarKey)
        print("💾 AvatarManager: Saved selected avatar to UserDefaults: \(selectedAvatar.displayName) (ID: \(selectedAvatar.id))")
    }
    
    /// Reset to default avatar
    func resetToDefault() {
        selectAvatar(AvatarManager.getDefaultAvatar())
    }
}
