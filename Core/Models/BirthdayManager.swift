import Combine
import FirebaseAuth
import Foundation

// MARK: - BirthdayManager

/// Manager for handling birthday storage and persistence
/// Ensures birthday is stored with user-specific keys and synced to Firestore
@MainActor
class BirthdayManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    loadBirthday()

    // Listen for authentication state changes
    authManager.$authState
      .sink { [weak self] authState in
        self?.handleAuthStateChange(authState)
      }
      .store(in: &cancellables)
  }

  // MARK: Internal

  static let shared = BirthdayManager()

  @Published var birthday: Date?
  @Published var hasSetBirthday = false

  /// Save birthday with automatic Firestore sync
  func saveBirthday(_ date: Date) {
    print("🎂 BirthdayManager: Saving birthday: \(date)")
    birthday = date
    hasSetBirthday = true

    // Save to UserDefaults with appropriate key
    if isUserAuthenticated() {
      let userKey = getUserSpecificKey()
      userDefaults.set(date, forKey: userKey)
      print("💾 BirthdayManager: Saved birthday for authenticated user with key: \(userKey)")

      // Also sync to Firestore
      syncBirthdayToFirestore(date)
    } else {
      // Save to guest storage
      userDefaults.set(date, forKey: guestBirthdayKey)
      print("💾 BirthdayManager: Saved guest birthday")
    }
  }

  /// Load birthday from storage
  func loadBirthday() {
    print("🎂 BirthdayManager: Loading birthday...")

    if isUserAuthenticated() {
      loadBirthdayForAuthenticatedUser()
    } else {
      loadGuestBirthday()
    }
  }

  /// Handle authentication state changes
  func handleAuthStateChange(_ authState: AuthenticationState) {
    print("🎂 BirthdayManager: Auth state changed")
    switch authState {
    case .authenticated:
      // User logged in - load their birthday
      loadBirthdayForAuthenticatedUser()

    case .authenticating,
         .error,
         .unauthenticated:
      // User logged out - load guest birthday
      loadGuestBirthday()
    }
  }

  /// Migrate guest birthday to authenticated user
  func migrateGuestBirthdayToUser() {
    guard isUserAuthenticated() else { return }

    // Check if user already has a birthday
    let userKey = getUserSpecificKey()
    if userDefaults.object(forKey: userKey) != nil {
      print("🎂 BirthdayManager: User already has a birthday, skipping migration")
      return
    }

    // Check if there's guest birthday to migrate
    guard let guestBirthday = userDefaults.object(forKey: guestBirthdayKey) as? Date else {
      print("🎂 BirthdayManager: No guest birthday to migrate")
      return
    }

    // Migrate guest birthday to user account
    userDefaults.set(guestBirthday, forKey: userKey)
    birthday = guestBirthday
    hasSetBirthday = true
    print("🎂 BirthdayManager: Migrated guest birthday to user account")

    // Also sync to Firestore
    syncBirthdayToFirestore(guestBirthday)
  }

  /// Clear guest birthday data (called when user signs up and chooses to start fresh)
  func clearGuestData() {
    userDefaults.removeObject(forKey: guestBirthdayKey)
    print("🎂 BirthdayManager: Cleared guest birthday data")
  }

  /// Load birthday from Firestore (for reinstall persistence)
  func loadBirthdayFromFirestore() async {
    guard isUserAuthenticated(), let user = authManager.currentUser else {
      print("🎂 BirthdayManager: Cannot load from Firestore - no authenticated user")
      return
    }

    print("🎂 BirthdayManager: Loading birthday from Firestore...")

    do {
      let db = Firestore.firestore()
      let userProfileDoc = try await db.collection("users")
        .document(user.uid)
        .collection("profile")
        .document("info")
        .getDocument()

      if let data = userProfileDoc.data(),
         let birthdayTimestamp = data["birthday"] as? TimeInterval
      {
        let loadedBirthday = Date(timeIntervalSince1970: birthdayTimestamp)
        
        // Save to local storage
        let userKey = getUserSpecificKey()
        userDefaults.set(loadedBirthday, forKey: userKey)
        
        birthday = loadedBirthday
        hasSetBirthday = true
        print("🎂 BirthdayManager: Loaded birthday from Firestore: \(loadedBirthday)")
      } else {
        print("🎂 BirthdayManager: No birthday found in Firestore")
      }
    } catch {
      print("⚠️ BirthdayManager: Error loading birthday from Firestore: \(error.localizedDescription)")
    }
  }

  // MARK: Private

  private let userDefaults = UserDefaults.standard
  private let birthdayKey = "UserBirthday"
  private let guestBirthdayKey = "GuestUserBirthday"

  /// Dependencies
  @Published private var authManager = AuthenticationManager.shared

  private var cancellables = Set<AnyCancellable>()

  /// Load birthday for authenticated user
  private func loadBirthdayForAuthenticatedUser() {
    let userKey = getUserSpecificKey()

    // First try to load from local storage with user-specific key
    if let savedBirthday = userDefaults.object(forKey: userKey) as? Date {
      birthday = savedBirthday
      hasSetBirthday = true
      print("🎂 BirthdayManager: Loaded birthday for authenticated user: \(savedBirthday)")
      return
    }

    // ✅ BACKWARD COMPATIBILITY: Check for old global "UserBirthday" key and migrate it
    if let oldBirthday = userDefaults.object(forKey: birthdayKey) as? Date {
      print("🎂 BirthdayManager: Found old global birthday key, migrating to user-specific key...")
      userDefaults.set(oldBirthday, forKey: userKey)
      userDefaults.removeObject(forKey: birthdayKey)
      birthday = oldBirthday
      hasSetBirthday = true
      print("✅ BirthdayManager: Migrated birthday to user-specific key: \(oldBirthday)")
      return
    }

    // If not found locally, try to load from Firestore
    Task {
      await loadBirthdayFromFirestore()
    }
  }

  /// Load birthday for guest user
  private func loadGuestBirthday() {
    if let guestBirthday = userDefaults.object(forKey: guestBirthdayKey) as? Date {
      birthday = guestBirthday
      hasSetBirthday = true
      print("🎂 BirthdayManager: Loaded guest birthday: \(guestBirthday)")
    } else {
      birthday = nil
      hasSetBirthday = false
      print("🎂 BirthdayManager: No guest birthday found")
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

  /// Get user-specific storage key for birthday
  private func getUserSpecificKey() -> String {
    guard let user = authManager.currentUser else {
      return birthdayKey // Fallback to default key
    }
    let userID = user.uid
    let userEmail = user.email ?? "no-email"
    // Use both UID and email to ensure uniqueness across different auth providers
    let uniqueKey = "\(userID)_\(userEmail.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))"
    return "\(birthdayKey)_\(uniqueKey)"
  }

  /// Sync birthday to Firestore
  private func syncBirthdayToFirestore(_ date: Date) {
    guard isUserAuthenticated(), let user = authManager.currentUser else {
      print("🎂 BirthdayManager: Cannot sync to Firestore - no authenticated user")
      return
    }

    print("🎂 BirthdayManager: Syncing birthday to Firestore...")

    Task {
      do {
        let db = Firestore.firestore()
        
        // Ensure the profile collection/document exists
        let userProfileRef = db.collection("users")
          .document(user.uid)
          .collection("profile")
          .document("info")

        try await userProfileRef.setData([
          "birthday": date.timeIntervalSince1970,
          "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        print("✅ BirthdayManager: Birthday synced to Firestore successfully")
      } catch {
        print("⚠️ BirthdayManager: Error syncing birthday to Firestore: \(error.localizedDescription)")
      }
    }
  }
}

// MARK: - Firebase imports

import FirebaseFirestore
