import CryptoKit
import Foundation

// MARK: - MigrationResumeTokenManager

// Handles creation, storage, and validation of migration resume tokens

actor MigrationResumeTokenManager {
  // MARK: Internal

  static let shared = MigrationResumeTokenManager()

  // MARK: - Public Interface

  func createResumeToken(
    migrationVersion: String,
    completedSteps: [String],
    currentStep: String? = nil,
    stepCodeHash: String,
    validationResult: MigrationInvariantsValidator
      .ValidationResult? = nil) async -> MigrationResumeToken
  {
    let stepHash = MigrationResumeToken.StepVersionHash(
      stepName: currentStep ?? "unknown",
      stepCodeHash: stepCodeHash,
      migrationVersion: migrationVersion).generateHash()

    let token = MigrationResumeToken(
      tokenId: UUID(),
      migrationVersion: migrationVersion,
      completedSteps: completedSteps,
      currentStep: currentStep,
      stepVersionHash: stepHash,
      createdAt: Date(),
      lastUpdated: Date(),
      validationResult: validationResult)

    await storeResumeToken(token)
    return token
  }

  func getCurrentResumeToken() async -> MigrationResumeToken? {
    guard let data = userDefaults.data(forKey: resumeTokenKey) else {
      return nil
    }

    return MigrationResumeToken.fromData(data)
  }

  func canResumeMigration(from stepName: String, withCodeHash stepHash: String) async -> Bool {
    guard let token = await getCurrentResumeToken() else {
      return false
    }

    // Check if the step code has changed
    let expectedHash = MigrationResumeToken.StepVersionHash(
      stepName: stepName,
      stepCodeHash: stepHash,
      migrationVersion: token.migrationVersion).generateHash()

    return token.canResumeFromStep(stepName, withHash: expectedHash)
  }

  func markStepCompleted(
    _ stepName: String,
    codeHash: String,
    migrationVersion: String) async throws
  {
    guard let token = await getCurrentResumeToken() else {
      throw MigrationResumeError.noResumeToken
    }

    // Update completed steps
    var completedSteps = token.completedSteps
    if !completedSteps.contains(stepName) {
      completedSteps.append(stepName)
    }

    // Update current step (next step or nil if completed)
    let currentStep = getNextStep(after: stepName, in: completedSteps)

    // Create new token with updated information
    let updatedToken = MigrationResumeToken(
      tokenId: token.tokenId,
      migrationVersion: migrationVersion,
      completedSteps: completedSteps,
      currentStep: currentStep,
      stepVersionHash: MigrationResumeToken.StepVersionHash(
        stepName: currentStep ?? "completed",
        stepCodeHash: codeHash,
        migrationVersion: migrationVersion).generateHash(),
      createdAt: token.createdAt,
      lastUpdated: Date(),
      validationResult: token.validationResult)

    await storeResumeToken(updatedToken)
  }

  func completeMigration() async {
    // Clear the current resume token since migration is complete
    userDefaults.removeObject(forKey: resumeTokenKey)

    // Archive the completed token
    if let token = await getCurrentResumeToken() {
      await archiveResumeToken(token)
    }
  }

  func clearResumeToken() async {
    userDefaults.removeObject(forKey: resumeTokenKey)
  }

  func getResumeTokenHistory() async -> [MigrationResumeToken] {
    let archiveKey = "MigrationResumeTokenArchive"
    guard let data = userDefaults.data(forKey: archiveKey) else {
      return []
    }

    return (try? JSONDecoder().decode([MigrationResumeToken].self, from: data)) ?? []
  }

  func generateStepCodeHash(for stepCode: String) -> String {
    let data = stepCode.data(using: .utf8) ?? Data()
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let resumeTokenKey = "MigrationResumeToken"
  private let maxResumeTokens = 5 // Keep last 5 resume tokens

  // MARK: - Private Methods

  private func storeResumeToken(_ token: MigrationResumeToken) async {
    guard let data = token.toData() else { return }
    userDefaults.set(data, forKey: resumeTokenKey)
  }

  private func archiveResumeToken(_ token: MigrationResumeToken) async {
    var archivedTokens = await getResumeTokenHistory()
    archivedTokens.append(token)

    // Keep only the most recent tokens
    if archivedTokens.count > maxResumeTokens {
      archivedTokens = Array(archivedTokens.suffix(maxResumeTokens))
    }

    if let data = try? JSONEncoder().encode(archivedTokens) {
      userDefaults.set(data, forKey: "MigrationResumeTokenArchive")
    }
  }

  private func getNextStep(after _: String, in _: [String]) -> String? {
    // This would be implemented based on your specific migration step order
    // For now, return nil to indicate migration is complete
    nil
  }
}

// MARK: - MigrationResumeError

enum MigrationResumeError: Error, LocalizedError {
  case noResumeToken
  case invalidResumeToken
  case stepCodeChanged
  case migrationVersionMismatch

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noResumeToken:
      "No resume token found for migration"
    case .invalidResumeToken:
      "Invalid or corrupted resume token"
    case .stepCodeChanged:
      "Migration step code has changed, cannot resume"
    case .migrationVersionMismatch:
      "Migration version mismatch, cannot resume"
    }
  }
}

// MARK: - Migration Step Protocol Enhancement

// Note: MigrationStep protocol is defined in DataMigrationManager.swift

extension MigrationStep {
  var isDestructive: Bool {
    false // Default to non-destructive
  }

  var estimatedDuration: TimeInterval {
    1.0 // Default to 1 second
  }

  func validatePreConditions() async throws {
    // Default implementation - no pre-conditions
  }

  func validatePostConditions() async throws {
    // Default implementation - no post-conditions
  }

  func getCodeHash() async -> String {
    let manager = MigrationResumeTokenManager.shared
    return await manager.generateStepCodeHash(for: description)
  }
}
