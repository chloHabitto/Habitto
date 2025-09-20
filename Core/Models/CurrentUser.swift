import Foundation

// MARK: - Current User Helper
/// Provides safe user ID management with guest mode support
/// Prevents forgetting to scope queries by providing a single source of truth

struct CurrentUser {
    private let authManager = AuthenticationManager.shared
    
    /// Get the current user ID, or guest identifier if not authenticated
    var id: String {
        if let user = authManager.currentUser {
            return user.uid
        }
        return Self.guestId
    }
    
    /// Get the current user ID or guest identifier (alias for id)
    var idOrGuest: String {
        return id
    }
    
    /// Check if current user is authenticated
    var isAuthenticated: Bool {
        return authManager.currentUser != nil
    }
    
    /// Check if current user is in guest mode
    var isGuest: Bool {
        return !isAuthenticated
    }
    
    /// Get user email if authenticated, nil otherwise
    var email: String? {
        return authManager.currentUser?.email
    }
    
    /// Get display name if authenticated, nil otherwise
    var displayName: String? {
        return authManager.currentUser?.displayName
    }
    
    // MARK: - Constants
    
    /// Guest user identifier - consistent across the app
    static let guestId = ""
    
    /// Check if a user ID represents a guest user
    static func isGuestId(_ userId: String) -> Bool {
        return userId.isEmpty || userId == guestId
    }
    
    /// Get a safe user ID (never nil, falls back to guest)
    static func safeUserId(_ userId: String?) -> String {
        return userId ?? guestId
    }
}

// MARK: - Predicate Helpers for SwiftData

extension CurrentUser {
    /// Create a predicate for filtering by current user (including guest mode)
    static func currentUserPredicate<T>() -> Predicate<T> where T: AnyObject {
        let currentUserId = CurrentUser().idOrGuest
        return #Predicate<T> { item in
            // This assumes the model has a userId property
            // The actual implementation would depend on the model
            return true // Placeholder - would need model-specific implementation
        }
    }
    
    /// Create a predicate for filtering by authenticated users only
    static func authenticatedUserPredicate<T>() -> Predicate<T> where T: AnyObject {
        let currentUserId = CurrentUser().idOrGuest
        return #Predicate<T> { item in
            // Only return items for authenticated users (non-guest)
            return !CurrentUser.isGuestId(currentUserId)
        }
    }
}

// MARK: - Usage Examples and Documentation

/*
 Usage Examples:
 
 // ✅ Correct usage - always scoped to current user
 let currentUserId = CurrentUser().idOrGuest
 let descriptor = FetchDescriptor<HabitData>(
     predicate: #Predicate<HabitData> { habit in
         habit.userId == currentUserId
     }
 )
 
 // ✅ Guest mode handling
 if CurrentUser().isGuest {
     // Show guest-specific UI
 }
 
 // ✅ Safe user ID access
 let userId = CurrentUser.safeUserId(optionalUserId)
 
 // ✅ Check if user is guest
 if CurrentUser.isGuestId(someUserId) {
     // Handle guest data
 }
 
 // ❌ Wrong - forgetting to scope queries
 let descriptor = FetchDescriptor<HabitData>() // Shows all users' data!
 
 // ❌ Wrong - hardcoding guest ID
 let guestId = "" // Use CurrentUser.guestId instead
 
 // ❌ Wrong - not handling nil user ID
 let userId = authManager.currentUser?.uid // Could be nil!
 */
