import Foundation
import Security

// MARK: - Keychain Manager
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Keychain Operations
    
    /// Store sensitive data in Keychain with proper accessibility settings
    func store(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add the new item with security settings
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve sensitive data from Keychain
    func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    /// Store a string in Keychain
    func storeString(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return store(key: key, data: data)
    }
    
    /// Retrieve a string from Keychain
    func retrieveString(key: String) -> String? {
        guard let data = retrieve(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete data from Keychain
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    /// Check if a key exists in Keychain
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Keys
extension KeychainManager {
    // Authentication related keys
    static let appleUserDisplayNameKey = "AppleUserDisplayName"
    static let firebaseAuthTokenKey = "FirebaseAuthToken"
    static let googleAuthTokenKey = "GoogleAuthToken"
    
    // User identification keys
    static let userIDKey = "UserID"
    static let userEmailKey = "UserEmail"
    
    // App-specific sensitive data
    static let lastSyncTimestampKey = "LastSyncTimestamp"
    static let deviceIdentifierKey = "DeviceIdentifier"
}

// MARK: - Convenience Methods
extension KeychainManager {
    /// Store Apple user display name securely
    func storeAppleUserDisplayName(_ name: String, for userID: String) -> Bool {
        let key = "\(Self.appleUserDisplayNameKey)_\(userID)"
        return storeString(key: key, string: name)
    }
    
    /// Retrieve Apple user display name securely
    func retrieveAppleUserDisplayName(for userID: String) -> String? {
        let key = "\(Self.appleUserDisplayNameKey)_\(userID)"
        return retrieveString(key: key)
    }
    
    /// Store user ID securely
    func storeUserID(_ userID: String) -> Bool {
        return storeString(key: Self.userIDKey, string: userID)
    }
    
    /// Retrieve user ID securely
    func retrieveUserID() -> String? {
        return retrieveString(key: Self.userIDKey)
    }
    
    /// Store user email securely
    func storeUserEmail(_ email: String) -> Bool {
        return storeString(key: Self.userEmailKey, string: email)
    }
    
    /// Retrieve user email securely
    func retrieveUserEmail() -> String? {
        return retrieveString(key: Self.userEmailKey)
    }
    
    /// Clear all authentication data
    func clearAuthenticationData() {
        _ = delete(key: Self.firebaseAuthTokenKey)
        _ = delete(key: Self.googleAuthTokenKey)
        _ = delete(key: Self.userIDKey)
        _ = delete(key: Self.userEmailKey)
        
        // Clear Apple user display names (we don't know all user IDs, so this is best effort)
        // In a real app, you might want to track user IDs to clean them up properly
    }
}
