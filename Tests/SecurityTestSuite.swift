import Foundation
import CryptoKit

// MARK: - Security Test Suite

@MainActor
class SecurityTestSuite {
    private let encryptionManager = FieldLevelEncryptionManager.shared
    
    // MARK: - Key Rotation Tests
    
    func testKeyRotation() async throws -> TestResult {
        let startTime = Date()
        
        // 1. Create initial encrypted data
        let originalData = "Sensitive habit notes: I want to quit smoking"
        let encryptedField1 = try await encryptionManager.encryptField(originalData)
        
        // 2. Rotate encryption key
        try await encryptionManager.rotateEncryptionKey()
        
        // 3. Create new encrypted data with new key
        let newData = "Updated notes: Day 5 of no smoking!"
        let encryptedField2 = try await encryptionManager.encryptField(newData)
        
        // 4. Verify both can be decrypted
        let decrypted1 = try await encryptionManager.decryptField(encryptedField1)
        let decrypted2 = try await encryptionManager.decryptField(encryptedField2)
        
        let success = decrypted1 == originalData && decrypted2 == newData
        
        return TestResult(
            testName: "Key Rotation",
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Key rotation test failed",
            metrics: SecurityTestMetrics(
                encryptionOperations: 2,
                decryptionOperations: 2,
                keyRotations: 1,
                dataIntegrityChecks: 2
            )
        )
    }
    
    // MARK: - Keychain Loss Tests
    
    func testKeychainLossRecovery() async throws -> TestResult {
        let startTime = Date()
        
        // 1. Create encrypted data
        let sensitiveData = "Personal habit insights and motivations"
        let _ = try await encryptionManager.encryptField(sensitiveData)
        
        // 2. Simulate keychain loss (new device scenario)
        let recoveryResponse = try await encryptionManager.handleKeychainLoss()
        
        // 3. Verify recovery response
        let success = recoveryResponse.recoveryMethod == .newKeyGenerated &&
                     recoveryResponse.requiresReEncryption == true
        
        return TestResult(
            testName: "Keychain Loss Recovery",
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Keychain loss recovery test failed",
            metrics: SecurityTestMetrics(
                encryptionOperations: 1,
                decryptionOperations: 0,
                keyRotations: 0,
                dataIntegrityChecks: 1
            )
        )
    }
    
    // MARK: - Versioned Envelope Tests
    
    func testVersionedEnvelope() async throws -> TestResult {
        let startTime = Date()
        
        // 1. Encrypt data and verify envelope structure
        let data = "Test data for versioned envelope"
        let encryptedField = try await encryptionManager.encryptField(data)
        
        // 2. Verify envelope contains all required fields
        let envelopeValid = !encryptedField.encryptedData.isEmpty &&
                           encryptedField.algorithm == .aesGCM &&
                           !encryptedField.keyVersion.isEmpty &&
                           encryptedField.createdAt <= Date()
        
        // 3. Test decryption with versioned envelope
        let decryptedData = try await encryptionManager.decryptField(encryptedField)
        let dataIntegrity = decryptedData == data
        
        let success = envelopeValid && dataIntegrity
        
        return TestResult(
            testName: "Versioned Envelope",
            startTime: startTime,
            endTime: Date(),
            duration: Date().timeIntervalSince(startTime),
            success: success,
            error: success ? nil : "Versioned envelope test failed",
            metrics: SecurityTestMetrics(
                encryptionOperations: 1,
                decryptionOperations: 1,
                keyRotations: 0,
                dataIntegrityChecks: 2
            )
        )
    }
    
    // MARK: - End-to-End Security Tests
    
    func runCompleteSecurityTest() async throws -> [TestResult] {
        var results: [TestResult] = []
        
        do {
            let keyRotationResult = try await testKeyRotation()
            results.append(keyRotationResult)
        } catch {
            results.append(TestResult(
                testName: "Key Rotation",
                startTime: Date(),
                endTime: Date(),
                duration: 0,
                success: false,
                error: error.localizedDescription,
                metrics: SecurityTestMetrics(encryptionOperations: 0, decryptionOperations: 0, keyRotations: 0, dataIntegrityChecks: 0)
            ))
        }
        
        do {
            let keychainLossResult = try await testKeychainLossRecovery()
            results.append(keychainLossResult)
        } catch {
            results.append(TestResult(
                testName: "Keychain Loss Recovery",
                startTime: Date(),
                endTime: Date(),
                duration: 0,
                success: false,
                error: error.localizedDescription,
                metrics: SecurityTestMetrics(encryptionOperations: 0, decryptionOperations: 0, keyRotations: 0, dataIntegrityChecks: 0)
            ))
        }
        
        do {
            let envelopeResult = try await testVersionedEnvelope()
            results.append(envelopeResult)
        } catch {
            results.append(TestResult(
                testName: "Versioned Envelope",
                startTime: Date(),
                endTime: Date(),
                duration: 0,
                success: false,
                error: error.localizedDescription,
                metrics: SecurityTestMetrics(encryptionOperations: 0, decryptionOperations: 0, keyRotations: 0, dataIntegrityChecks: 0)
            ))
        }
        
        return results
    }
}

// MARK: - Test Result Models

struct TestResult {
    let testName: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let success: Bool
    let error: String?
    let metrics: SecurityTestMetrics
}

struct SecurityTestMetrics {
    let encryptionOperations: Int
    let decryptionOperations: Int
    let keyRotations: Int
    let dataIntegrityChecks: Int
}
