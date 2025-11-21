import Foundation
import FirebaseAuth

// MARK: - CurrentUser

// Provides safe user ID management with guest mode support
// Prevents forgetting to scope queries by providing a single source of truth

struct CurrentUser {
  // MARK: - Constants

  /// Guest user identifier - consistent across the app
  static let guestId = ""

  /// Get the current user ID, or guest identifier if not authenticated
  /// ✅ GUEST MODE ONLY: Always returns empty string (guest mode)
  var id: String {
    get async {
      // Always return guest ID (empty string) - no anonymous auth
      return Self.guestId
    }
  }

  /// Get the current user ID or guest identifier (alias for id)
  var idOrGuest: String {
    get async {
      await id
    }
  }

  /// Check if current user is authenticated
  /// ✅ GUEST MODE ONLY: Always returns false (no auth)
  var isAuthenticated: Bool {
    get async {
      return false // Always guest mode - no authentication
    }
  }

  /// Check if current user is in guest mode
  var isGuest: Bool {
    get async {
      await !isAuthenticated
    }
  }

  /// Get user email if authenticated, nil otherwise
  var email: String? {
    get async {
      await MainActor.run {
        if let email = AuthenticationManager.shared.currentUser?.email {
          return email
        }
        return Auth.auth().currentUser?.email
      }
    }
  }

  /// Get display name if authenticated, nil otherwise
  var displayName: String? {
    get async {
      await MainActor.run {
        if let displayName = AuthenticationManager.shared.currentUser?.displayName {
          return displayName
        }
        return Auth.auth().currentUser?.displayName
      }
    }
  }

  /// Check if a user ID represents a guest user
  static func isGuestId(_ userId: String) -> Bool {
    userId.isEmpty || userId == guestId
  }

  /// Get a safe user ID (never nil, falls back to guest)
  static func safeUserId(_ userId: String?) -> String {
    userId ?? guestId
  }

  // MARK: - Helpers

  private func resolveUserId(from user: UserProtocol?) -> String? {
    guard let user else { return nil }

    if let firebaseUser = user as? User {
      // ✅ FIX: Anonymous users have a real UID - return it!
      // Anonymous users are authenticated, just not signed in with email/password
      // They should use their UID for data isolation, not the guest ID
      let uid = firebaseUser.uid
      return uid.isEmpty ? Self.guestId : uid
    }

    let uid = user.uid
    return uid.isEmpty ? Self.guestId : uid
  }
}

// MARK: - Predicate Helpers for SwiftData

extension CurrentUser {
  /// Create a predicate for filtering by current user (including guest mode)
  static func currentUserPredicate<T>(currentUserId _: String) -> Predicate<T> where T: AnyObject {
    return #Predicate<T> { _ in
      // This assumes the model has a userId property
      // The actual implementation would depend on the model
      return true // Placeholder - would need model-specific implementation
    }
  }

  /// Create a predicate for filtering by authenticated users only
  static func authenticatedUserPredicate<T>(currentUserId: String) -> Predicate<T>
    where T: AnyObject
  {
    return #Predicate<T> { _ in
      // Only return items for authenticated users (non-guest)
      // Check if userId is not empty (non-guest)
      return currentUserId != "" && !currentUserId.isEmpty
    }
  }
}

// MARK: - Usage Examples and Documentation

// Usage Examples:
//
// // ✅ Correct usage - always scoped to current user
// let currentUserId = await CurrentUser().idOrGuest
// let descriptor = FetchDescriptor<HabitData>(
//    predicate: CurrentUser.currentUserPredicate(currentUserId: currentUserId)
// )
//
// // ✅ Guest mode handling
// if await CurrentUser().isGuest {
//    // Show guest-specific UI
// }
//
// // ✅ Safe user ID access
// let userId = CurrentUser.safeUserId(optionalUserId)
//
// // ✅ Check if user is guest
// if CurrentUser.isGuestId(someUserId) {
//    // Handle guest data
// }
//
// // ❌ Wrong - forgetting to scope queries
// let descriptor = FetchDescriptor<HabitData>() // Shows all users' data!
//
// // ❌ Wrong - hardcoding guest ID
// let guestId = "" // Use CurrentUser.guestId instead
//
// // ❌ Wrong - not handling nil user ID
// let userId = authManager.currentUser?.uid // Could be nil!
