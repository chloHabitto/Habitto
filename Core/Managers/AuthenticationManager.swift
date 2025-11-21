import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

// MARK: - AuthenticationState

enum AuthenticationState: Equatable {
  case unauthenticated
  case authenticating
  case authenticated(UserProtocol)
  case error(String)

  // MARK: Internal

  static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
    switch (lhs, rhs) {
    case (.authenticating, .authenticating),
         (.unauthenticated, .unauthenticated):
      true
    case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
      lhsUser.uid == rhsUser.uid
    case (.error(let lhsMessage), .error(let rhsMessage)):
      lhsMessage == rhsMessage
    default:
      false
    }
  }
}

// MARK: - AuthenticationManager

///
/// This manager handles user authentication via Firebase Auth only.
/// It does NOT store or manage habit data - that's handled by HabitRepository.
///
/// Firebase Usage:
/// - Google Sign-In authentication
/// - Apple Sign-In authentication
/// - Email/Password authentication
/// - Session management and token storage
///
/// Data Storage:
/// - Authentication tokens → Keychain
/// - User profile info → Firebase Auth
/// - Habit data → HabitRepository (UserDefaults → Core Data)
///
@MainActor
class AuthenticationManager: ObservableObject {
  // MARK: Lifecycle

  private init() {
    // ✅ FIX: Don't setup auth listener immediately - wait for Firebase to be configured
    // Auth listener will be set up lazily when first needed
    print("🔐 AuthenticationManager: Initialized (Auth listener deferred until Firebase configured)")
  }

  deinit {
    // Clean up the listener in deinit
    if let listener = authStateListener {
      Auth.auth().removeStateDidChangeListener(listener)
    }
  }

  // MARK: Internal

  static let shared = AuthenticationManager()
  
  /// Track if auth listener has been set up
  private var hasSetupAuthListener = false

  @Published var authState: AuthenticationState = .unauthenticated
  @Published var currentUser: UserProtocol?
  
  /// Get current user ID (useful for Firestore queries)
  var currentUserId: String? {
    currentUser?.uid
  }

  // MARK: - Anonymous Authentication
  
  /// Check if current user is anonymous
  /// Note: Anonymous sign-in functionality has been removed - can be restored from git history if needed
  var isAnonymous: Bool {
    Auth.auth().currentUser?.isAnonymous ?? false
  }

  // MARK: - Email/Password Authentication

  // Note: Email/password sign-in and sign-up functionality has been removed - can be restored from git history if needed

  func signOut() {
    print("🔐 AuthenticationManager: Starting sign out")
    do {
      try Auth.auth().signOut()
      authState = .unauthenticated
      currentUser = nil

      // Clear sensitive data from Keychain
      KeychainManager.shared.clearAuthenticationData()
      print("✅ AuthenticationManager: Cleared sensitive data from Keychain")

      // Clear XP data to prevent data leakage between users
      XPManager.shared.handleUserSignOut()
      print("✅ AuthenticationManager: Cleared XP data")

      print("✅ AuthenticationManager: User signed out successfully")
    } catch {
      authState = .error(error.localizedDescription)
      print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
    }
  }

  // Note: Password reset functionality has been removed - can be restored from git history if needed

  func generateNonce() -> String {
    let nonce = randomNonceString()
    currentNonce = nonce
    return nonce
  }

  // MARK: - Google Sign In

  // Note: Google Sign-In functionality has been removed - can be restored from git history if needed

  // MARK: - Apple Sign In

  // Note: Apple Sign-In functionality has been removed - can be restored from git history if needed

  // MARK: - User Profile Management

  // Note: User profile management functionality has been removed - can be restored from git history if needed

  // MARK: - Validation

  func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
  }

  func isValidPassword(_ password: String) -> Bool {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$"
    let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
    return passwordPredicate.evaluate(with: password)
  }

  // MARK: - Account Deletion

  // Note: Account deletion and re-authentication functionality has been removed - can be restored from git history if needed

  // MARK: Private

  private var authStateListener: NSObjectProtocol?

  // MARK: - Apple Sign In Nonce (Security) - Simplified

  private var currentNonce: String?

  // MARK: - Authentication State Listener

  /// ✅ Ensure auth listener is set up (called when Firebase is ready)
  func ensureAuthListenerSetup() {
    guard !hasSetupAuthListener else {
      print("ℹ️ AuthenticationManager: Auth listener already set up, skipping")
      return
    }
    
    print("🔐 AuthenticationManager: Setting up Firebase authentication state listener...")
    setupAuthStateListener()
    hasSetupAuthListener = true
  }
  
  private func setupAuthStateListener() {
    // Check if Firebase is configured before accessing Auth
    guard FirebaseApp.app() != nil else {
      print("⚠️ AuthenticationManager: Firebase not configured yet, deferring auth listener setup")
      return
    }
    
    print("🔐 AuthenticationManager: Adding Firebase Auth state change listener")
    authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      DispatchQueue.main.async {
        if let user {
          // ✅ CRITICAL FIX: Validate that the Firebase account still exists
          // If account was deleted from Firebase Console, this will detect it
          Task { @MainActor in
            do {
              // Refresh the token to verify account still exists
              // If account was deleted, this will fail
              _ = try await user.getIDTokenResult(forcingRefresh: true)
              
              // Account is valid, proceed with authentication
              self?.authState = .authenticated(user)
              self?.currentUser = user
              print("✅ AuthenticationManager: User authenticated: \(user.email ?? "No email")")

              // Load user-specific XP data
              // Note: This will be called from a view with ModelContext access
              print("🎯 AUTH: User signed in, XP loading will be handled by view")
            } catch {
              // Account was deleted or invalid - sign out automatically
              print("⚠️ AuthenticationManager: Account validation failed (account may have been deleted): \(error.localizedDescription)")
              print("🔐 AuthenticationManager: Signing out invalid/deleted account...")
              
              do {
                try Auth.auth().signOut()
                self?.authState = .unauthenticated
                self?.currentUser = nil
                print("✅ AuthenticationManager: Signed out invalid/deleted account")
              } catch {
                print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
                // Force clear local state even if sign out fails
                self?.authState = .unauthenticated
                self?.currentUser = nil
              }
            }
          }
        } else {
          self?.authState = .unauthenticated
          self?.currentUser = nil
          print("ℹ️ AuthenticationManager: User in guest mode - no authentication required")
        }
      }
    }
  }

  private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
      Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
      let randoms: [UInt8] = (0 ..< 16).map { _ in
        var random: UInt8 = 0
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
        if errorCode != errSecSuccess {
          fatalError(
            "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        return random
      }

      for random in randoms {
        if remainingLength == 0 {
          continue
        }

        if random < charset.count {
          result.append(charset[Int(random)])
          remainingLength -= 1
        }
      }
    }

    return result
  }

  private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
      String(format: "%02x", $0)
    }.joined()

    return hashString
  }

  // MARK: - Helper Methods

  /// Gets the top view controller using modern UIWindowScene API
  private func getTopViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else
    {
      return nil
    }
    return window.rootViewController
  }
}

// MARK: - CustomUser

struct CustomUser: UserProtocol {
  let uid: String
  let email: String?
  let displayName: String?
}

// MARK: - UserProtocol

protocol UserProtocol {
  var uid: String { get }
  var email: String? { get }
  var displayName: String? { get }
}

// MARK: - MockFirebaseUser

class MockFirebaseUser: UserProtocol {
  // MARK: Lifecycle

  init(uid: String, email: String?, displayName: String?, isEmailVerified: Bool = false) {
    self.uid = uid
    self.email = email
    self.displayName = displayName
    self.isEmailVerified = isEmailVerified
  }

  // MARK: Internal

  let uid: String
  let email: String?
  let displayName: String?
  let isEmailVerified: Bool
}

// MARK: - User + UserProtocol

extension User: UserProtocol { }
