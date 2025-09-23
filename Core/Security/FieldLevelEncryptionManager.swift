import Foundation
import CryptoKit
import Security

// MARK: - Field Level Encryption Manager
// Provides field-level encryption for sensitive data with Keychain storage

actor FieldLevelEncryptionManager {
    static let shared = FieldLevelEncryptionManager()
    
    // MARK: - Properties
    
    private let keychain = EncryptionKeychainManager.shared
    private let encryptionKeyIdentifier = "HabittoFieldEncryptionKey"
    private var cachedEncryptionKey: SymmetricKey?
    
    // MARK: - Encryption Key Management
    
    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        if let cachedKey = cachedEncryptionKey {
            return cachedKey
        }
        
        // Try to load existing key from Keychain
        if let existingKeyData = try await keychain.loadData(forKey: encryptionKeyIdentifier) {
            cachedEncryptionKey = SymmetricKey(data: existingKeyData)
            return cachedEncryptionKey!
        }
        
        // Create new encryption key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store in Keychain with high security
        try await keychain.storeData(keyData, forKey: encryptionKeyIdentifier, 
                                   accessControl: SecAccessControl.biometryAny, 
                                   accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        
        cachedEncryptionKey = newKey
        return newKey
    }
    
    // MARK: - Public Encryption Interface
    
    func encryptField(_ value: String) async throws -> EncryptedField {
        let key = try await getOrCreateEncryptionKey()
        let data = value.data(using: .utf8) ?? Data()
        
        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        return EncryptedField(
            encryptedData: sealedBox.combined ?? Data(),
            algorithm: .aesGCM,
            keyVersion: "1.0",
            createdAt: Date()
        )
    }
    
    func decryptField(_ encryptedField: EncryptedField) async throws -> String {
        let key = try await getOrCreateEncryptionKey()
        
        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedField.encryptedData) else {
            throw EncryptionError.invalidEncryptedData
        }
        
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return decryptedString
    }
    
    func encryptSensitiveFields<T: Codable>(_ object: T, fieldPaths: [String]) async throws -> EncryptedObject<T> {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EncryptionError.serializationFailed
        }
        
        var encryptedFields: [String: EncryptedField] = [:]
        
        for fieldPath in fieldPaths {
            let pathComponents = fieldPath.split(separator: ".")
            if let value = getNestedValue(from: json, path: pathComponents) as? String {
                let encryptedValue = try await encryptField(value)
                encryptedFields[fieldPath] = encryptedValue
                setNestedValue(in: &json, path: pathComponents, value: "[ENCRYPTED]")
            }
        }
        
        return EncryptedObject(
            originalType: String(describing: T.self),
            encryptedFields: encryptedFields,
            serializedData: try JSONSerialization.data(withJSONObject: json)
        )
    }
    
    func decryptSensitiveFields<T: Codable>(_ encryptedObject: EncryptedObject<T>) async throws -> T {
        guard var json = try JSONSerialization.jsonObject(with: encryptedObject.serializedData) as? [String: Any] else {
            throw EncryptionError.deserializationFailed
        }
        
        // Decrypt and restore sensitive fields
        for (fieldPath, encryptedField) in encryptedObject.encryptedFields {
            let pathComponents = fieldPath.split(separator: ".")
            let decryptedValue = try await decryptField(encryptedField)
            setNestedValue(in: &json, path: pathComponents, value: decryptedValue)
        }
        
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Key Rotation
    
    func rotateEncryptionKey() async throws {
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        let newKeyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store new key with incremented version
        let newKeyIdentifier = "\(encryptionKeyIdentifier)_v2"
        try await keychain.storeData(newKeyData, forKey: newKeyIdentifier,
                                   accessControl: SecAccessControl.biometryAny,
                                   accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        
        // Update cached key
        cachedEncryptionKey = newKey
        
        // Store key rotation metadata
        let rotationMetadata = KeyRotationMetadata(
            oldKeyIdentifier: encryptionKeyIdentifier,
            newKeyIdentifier: newKeyIdentifier,
            rotationDate: Date(),
            rotationReason: "scheduled_rotation"
        )
        
        if let metadataData = try? JSONEncoder().encode(rotationMetadata) {
            UserDefaults.standard.set(metadataData, forKey: "KeyRotationMetadata")
        }
        
        // Schedule re-encryption of existing data (background task)
        Task.detached {
            await self.reEncryptExistingData(with: newKey)
        }
        
        print("🔑 FieldLevelEncryptionManager: Encryption key rotated successfully.")
    }
    
    private func reEncryptExistingData(with newKey: SymmetricKey) async {
        // This would iterate through existing encrypted data and re-encrypt with new key
        // Implementation depends on how encrypted data is stored
        print("🔄 FieldLevelEncryptionManager: Starting background re-encryption with new key")
    }
    
    func handleKeychainLoss() async throws -> KeychainLossResponse {
        // Check if we can recover from backup or if we need to generate new key
        let hasBackup = await checkForBackupKey()
        
        if hasBackup {
            // Attempt to recover from backup
            return try await recoverFromBackup()
        } else {
            // Generate new key and mark all encrypted data as needing re-encryption
            return try await handleNewDeviceScenario()
        }
    }
    
    private func checkForBackupKey() async -> Bool {
        // Check if backup key exists (e.g., in iCloud Keychain)
        // This is a simplified check - in production, you'd check multiple sources
        return false
    }
    
    private func recoverFromBackup() async throws -> KeychainLossResponse {
        // Attempt to recover from backup key
        // This would involve fetching from iCloud Keychain or other backup sources
        throw EncryptionError.keyGenerationFailed
    }
    
    private func handleNewDeviceScenario() async throws -> KeychainLossResponse {
        // Generate new key for new device scenario
        let newKey = SymmetricKey(size: .bits256)
        let newKeyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store new key
        try await keychain.storeData(newKeyData, forKey: encryptionKeyIdentifier,
                                   accessControl: SecAccessControl.biometryAny,
                                   accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        
        cachedEncryptionKey = newKey
        
        return KeychainLossResponse(
            recoveryMethod: .newKeyGenerated,
            requiresReEncryption: true,
            affectedRecords: await getAffectedRecordCount()
        )
    }
    
    private func getAffectedRecordCount() async -> Int {
        // Count records that need re-encryption
        // This would query your data store for encrypted records
        return 0
    }
    
    // MARK: - Helper Methods
    
    private func getNestedValue(from json: [String: Any], path: [Substring]) -> Any? {
        var current: Any = json
        for component in path {
            if let dict = current as? [String: Any] {
                current = dict[String(component)] as Any
            } else {
                return nil
            }
        }
        return current
    }
    
    private func setNestedValue(in json: inout [String: Any], path: [Substring], value: Any) {
        guard !path.isEmpty else { return }
        
        // Simplified implementation for single-level paths
        if path.count == 1 {
            json[String(path[0])] = value
        } else {
            // For multi-level paths, we'd need a more complex implementation
            // For now, just set the last component
            json[String(path.last!)] = value
        }
    }
}

// MARK: - Encryption Models

struct EncryptedField: Codable {
    let encryptedData: Data
    let algorithm: EncryptionAlgorithm
    let keyVersion: String
    let createdAt: Date
    
    enum EncryptionAlgorithm: String, Codable {
        case aesGCM = "AES-GCM"
        case aesCBC = "AES-CBC"
    }
}

struct EncryptedObject<T: Codable>: Codable {
    let originalType: String
    let encryptedFields: [String: EncryptedField]
    let serializedData: Data
    
    func decrypt<U: Codable>(as type: U.Type) async throws -> U {
        let manager = FieldLevelEncryptionManager.shared
        return try await manager.decryptSensitiveFields(EncryptedObject<U>(
            originalType: String(describing: U.self),
            encryptedFields: encryptedFields,
            serializedData: serializedData
        ))
    }
}

// MARK: - Encryption Errors

enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case keyStorageFailed
    case keyRetrievalFailed
    case encryptionFailed
    case decryptionFailed
    case invalidEncryptedData
    case serializationFailed
    case deserializationFailed
    case fieldPathNotFound
    case keyRotationFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyStorageFailed:
            return "Failed to store encryption key in Keychain"
        case .keyRetrievalFailed:
            return "Failed to retrieve encryption key from Keychain"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .serializationFailed:
            return "Failed to serialize object for encryption"
        case .deserializationFailed:
            return "Failed to deserialize decrypted object"
        case .fieldPathNotFound:
            return "Field path not found in object"
        case .keyRotationFailed:
            return "Failed to rotate encryption key"
        }
    }
}

// MARK: - Encryption Keychain Manager

actor EncryptionKeychainManager {
    static let shared = EncryptionKeychainManager()
    
    private init() {}
    
    func storeData(_ data: Data, forKey key: String, accessControl: SecAccessControl, accessibility: CFString) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrAccessible as String: accessibility
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keyStorageFailed
        }
    }
    
    func loadData(forKey key: String) async throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionError.keyRetrievalFailed
        }
    }
    
    func deleteData(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keyRetrievalFailed
        }
    }
}

// MARK: - Security Access Control Extensions

extension SecAccessControl {
    static var biometryAny: SecAccessControl {
        return SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryAny, .or, .devicePasscode],
            nil
        )!
    }
    
    static var devicePasscode: SecAccessControl {
        return SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .devicePasscode,
            nil
        )!
    }
}

// MARK: - Key Rotation Metadata

struct KeyRotationMetadata: Codable {
    let oldKeyIdentifier: String
    let newKeyIdentifier: String
    let rotationDate: Date
    let rotationReason: String // "scheduled_rotation", "security_incident", "manual_rotation"
}

// MARK: - Keychain Loss Response

struct KeychainLossResponse {
    let recoveryMethod: RecoveryMethod
    let requiresReEncryption: Bool
    let affectedRecords: Int
    
    enum RecoveryMethod {
        case backupRecovered
        case newKeyGenerated
        case manualInterventionRequired
    }
}

// MARK: - Security Policy Table

struct SecurityPolicyTable {
    static let sensitiveFields: [String] = [
        "notes",
        "personalGoals", 
        "motivation",
        "medicalNotes",
        "financialGoals"
    ]
    
    static let nonSensitiveFields: [String] = [
        "name",
        "description",
        "icon",
        "color",
        "habitType",
        "schedule",
        "goal",
        "reminder",
        "startDate",
        "endDate",
        "isCompleted",
        "streak",
        "createdAt"
    ]
    
    static func isFieldSensitive(_ fieldName: String) -> Bool {
        return sensitiveFields.contains(fieldName)
    }
    
    static func requiresEncryption(_ fieldName: String) -> Bool {
        return isFieldSensitive(fieldName)
    }
    
    static func getEncryptionLevel(_ fieldName: String) -> EncryptionLevel {
        if isFieldSensitive(fieldName) {
            return .fieldLevel
        } else {
            return .none
        }
    }
}

enum EncryptionLevel {
    case none
    case fieldLevel
    case recordLevel
}
