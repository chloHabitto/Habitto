import Combine
import FirebaseAuth
import Foundation

// MARK: - AccountDeletionService

/// Service responsible for handling complete account deletion including data cleanup
@MainActor
final class AccountDeletionService: ObservableObject {
  // MARK: Internal

  // Published properties for UI
  @Published var isDeleting = false
  @Published var deletionProgress = 0.0
  @Published var deletionStatus = ""
  @Published var deletionError: String?

  // MARK: - Public Methods

  /// Check if the user needs to re-authenticate before account deletion
  func checkAuthenticationFreshness() async -> Bool {
    guard authManager.currentUser != nil else {
      print("❌ AccountDeletionService: No current user found")
      return false
    }

    print(
      "✅ AccountDeletionService: User found, re-authentication will be handled by AuthenticationManager")
    return true
  }

  /// Delete the current user's account and all associated data
  func deleteAccount() async throws {
    guard let currentUser = authManager.currentUser else {
      throw AccountDeletionError.noAuthenticatedUser
    }

    isDeleting = true
    deletionProgress = 0.0
    deletionStatus = "Starting account deletion..."
    deletionError = nil

    do {
      // Step 1: Delete user data from storage
      deletionStatus = "Clearing user data..."
      deletionProgress = 0.2
      print("🗑️ AccountDeletionService: Step 1 - Deleting user data")
      try await deleteUserData(for: currentUser.uid)
      print("✅ AccountDeletionService: Step 1 completed")

      // Step 2: Delete user backups
      deletionStatus = "Clearing backups..."
      deletionProgress = 0.4
      print("🗑️ AccountDeletionService: Step 2 - Deleting backups")
      try await deleteUserBackups(for: currentUser.uid)
      print("✅ AccountDeletionService: Step 2 completed")

      // Step 3: Clear app data
      deletionStatus = "Clearing app data..."
      deletionProgress = 0.6
      print("🗑️ AccountDeletionService: Step 3 - Clearing app data")
      try await clearAppData()
      print("✅ AccountDeletionService: Step 3 completed")

      // Step 4: Delete Firebase account
      deletionStatus = "Deleting account..."
      deletionProgress = 0.8
      print("🗑️ AccountDeletionService: Step 4 - Deleting Firebase account")
      try await deleteFirebaseAccount()
      print("✅ AccountDeletionService: Step 4 completed")

      // Step 5: Final cleanup
      deletionStatus = "Finalizing deletion..."
      deletionProgress = 1.0
      print("🗑️ AccountDeletionService: Step 5 - Finalizing deletion")
      try await finalizeDeletion()
      print("✅ AccountDeletionService: Step 5 completed")

      deletionStatus = "Account deleted successfully!"
      print("✅ AccountDeletionService: Account deletion completed for user: \(currentUser.uid)")

    } catch {
      print("❌ AccountDeletionService: Account deletion failed at step with error: \(error)")
      print("❌ AccountDeletionService: Error details: \(String(describing: error))")
      let nsError = error as NSError

      // Handle specific authentication errors
      if nsError.code == 17014 || error.localizedDescription
        .contains("requires recent authentication")
      {
        deletionError = "This operation requires recent authentication. Please sign out and sign in again, then try deleting your account."
      } else {
        deletionError = error.localizedDescription
      }

      deletionStatus = "Deletion failed: \(deletionError ?? "Unknown error")"
      throw error
    }

    isDeleting = false
  }

  /// Get a preview of what data will be deleted
  func getDeletionPreview() -> AccountDeletionPreview? {
    guard let currentUser = authManager.currentUser else { return nil }

    // Count user habits
    let userHabitsKey = "\(currentUser.uid)_habits"
    let habitCount = {
      guard let habitsData = userDefaults.data(forKey: userHabitsKey),
            let habits = try? JSONDecoder().decode([Habit].self, from: habitsData) else
      {
        return 0
      }
      return habits.count
    }()

    // Count user backups
    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let userBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent(currentUser.uid)
    var backupCount = 0

    if fileManager.fileExists(atPath: userBackupDir.path) {
      do {
        let contents = try fileManager.contentsOfDirectory(atPath: userBackupDir.path)
        backupCount = contents.count
      } catch {
        print("❌ AccountDeletionService: Error counting user backups: \(error)")
      }
    }

    return AccountDeletionPreview(
      habitCount: habitCount,
      backupCount: backupCount,
      userEmail: currentUser.email ?? "Unknown")
  }

  // MARK: Private

  private let authManager = AuthenticationManager.shared
  private let habitRepository = HabitRepository.shared
  private let userDefaults = UserDefaults.standard
  private let fileManager = FileManager.default

  // MARK: - Private Methods

  private func deleteUserData(for userId: String) async throws {
    print("🗑️ AccountDeletionService: Deleting user data for \(userId)")

    // Delete user-specific habits
    let userHabitsKey = "\(userId)_habits"
    userDefaults.removeObject(forKey: userHabitsKey)

    // Delete user-specific backup metadata
    let userLastBackupKey = "\(userId)_last_backup_date"
    let userBackupCountKey = "\(userId)_backup_count"
    userDefaults.removeObject(forKey: userLastBackupKey)
    userDefaults.removeObject(forKey: userBackupCountKey)

    // Delete user-specific migration flags
    let migrationKey = "guest_data_migrated_\(userId)"
    userDefaults.removeObject(forKey: migrationKey)

    // Clear any other user-specific keys
    let allKeys = userDefaults.dictionaryRepresentation().keys
    for key in allKeys {
      if key.hasPrefix("\(userId)_") {
        userDefaults.removeObject(forKey: key)
      }
    }

    print("✅ AccountDeletionService: User data deleted for \(userId)")
  }

  private func deleteUserBackups(for userId: String) async throws {
    print("🗑️ AccountDeletionService: Deleting user backups for \(userId)")

    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let userBackupDir = documentsPath.appendingPathComponent("Backups")
      .appendingPathComponent(userId)

    if fileManager.fileExists(atPath: userBackupDir.path) {
      try fileManager.removeItem(at: userBackupDir)
      print("✅ AccountDeletionService: User backup directory deleted for \(userId)")
    } else {
      print("ℹ️ AccountDeletionService: No backup directory found for \(userId)")
    }
  }

  private func clearAppData() async throws {
    print("🗑️ AccountDeletionService: Clearing app data")

    // Clear all habits from repository
    try await habitRepository.clearAllHabits()

    // Clear XP and level data
    XPManager.shared.clearXPData()
    print("✅ AccountDeletionService: XP and level data cleared")

    // Clear any cached data
    // Note: The HabitRepository will handle clearing its own cache

    print("✅ AccountDeletionService: App data cleared")
  }

  private func deleteFirebaseAccount() async throws {
    print("🗑️ AccountDeletionService: Deleting Firebase account")

    return try await withCheckedThrowingContinuation { continuation in
      authManager.deleteAccount { result in
        switch result {
        case .success:
          print("✅ AccountDeletionService: Firebase account deleted")
          continuation.resume()

        case .failure(let error):
          print("❌ AccountDeletionService: Failed to delete Firebase account: \(error)")
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func finalizeDeletion() async throws {
    print("🗑️ AccountDeletionService: Finalizing deletion")

    // Clear any remaining app state
    // The AuthenticationManager will handle clearing auth state

    // Clear any remaining user defaults
    let keysToRemove = [
      "last_backup_date",
      "backup_count",
      "guest_data_migrated",
      "CoreDataMigrationCompleted"
    ]

    for key in keysToRemove {
      userDefaults.removeObject(forKey: key)
    }

    print("✅ AccountDeletionService: Deletion finalized")
  }
}

// MARK: - AccountDeletionPreview

struct AccountDeletionPreview {
  let habitCount: Int
  let backupCount: Int
  let userEmail: String
}

// MARK: - AccountDeletionError

enum AccountDeletionError: LocalizedError {
  case noAuthenticatedUser
  case deletionFailed(String)
  case dataCleanupFailed(String)

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .noAuthenticatedUser:
      "No authenticated user found"
    case .deletionFailed(let message):
      "Account deletion failed: \(message)"
    case .dataCleanupFailed(let message):
      "Data cleanup failed: \(message)"
    }
  }
}
