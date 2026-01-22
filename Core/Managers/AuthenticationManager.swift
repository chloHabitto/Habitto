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
  var isAnonymous: Bool {
    Auth.auth().currentUser?.isAnonymous ?? false
  }
  
  /// Ensure user is signed in anonymously for cloud backup
  /// This runs automatically on app launch to enable invisible cloud backup
  /// Falls back to guest mode if Firebase is not available
  func ensureAnonymousAuth() async {
    // ✅ CRITICAL: Check if Firebase is configured AND GoogleService-Info.plist exists
    guard AppEnvironment.isFirebaseConfigured else {
      print("⚠️ [ANONYMOUS_AUTH] Firebase not configured - GoogleService-Info.plist missing")
      print("ℹ️ [ANONYMOUS_AUTH] App will run in guest mode (offline-only)")
      print("ℹ️ [ANONYMOUS_AUTH] Your existing habits will still be visible")
      return
    }
    
    guard FirebaseApp.app() != nil else {
      print("⚠️ [ANONYMOUS_AUTH] Firebase not initialized, skipping anonymous auth")
      print("ℹ️ [ANONYMOUS_AUTH] App will run in guest mode (offline-only)")
      return
    }
    
    // Check if user is already authenticated (anonymous or otherwise)
    if let currentUser = Auth.auth().currentUser {
      print("✅ [ANONYMOUS_AUTH] User already authenticated")
      print("   User ID: \(currentUser.uid)")
      print("   Is Anonymous: \(currentUser.isAnonymous)")
      
      // Store userId in Keychain for persistence across reinstalls
      if KeychainManager.shared.storeUserID(currentUser.uid) {
        print("✅ [ANONYMOUS_AUTH] Stored userId in Keychain")
      }
      
      print("✅ [ANONYMOUS_AUTH] Cloud backup ready")
      return
    }
    
    // Try to restore from Keychain first (for app reinstalls)
    if let storedUserId = KeychainManager.shared.retrieveUserID(),
       !storedUserId.isEmpty {
      print("🔍 AuthenticationManager: Found stored userId in Keychain: \(storedUserId)")
      // Note: We can't restore the session, but we'll sign in anonymously and migrate data
    }
    
    // Sign in anonymously
    do {
      print("🔐 [ANONYMOUS_AUTH] Starting anonymous authentication...")
      let result = try await Auth.auth().signInAnonymously()
      let userId = result.user.uid
      
      print("✅ [ANONYMOUS_AUTH] SUCCESS - User authenticated anonymously")
      print("   User ID: \(userId)")
      print("   Is Anonymous: \(result.user.isAnonymous)")
      
      // Store userId in Keychain for persistence
      if KeychainManager.shared.storeUserID(userId) {
        print("✅ [ANONYMOUS_AUTH] Stored userId in Keychain for persistence")
      }
      
      // Update auth state (listener will also handle this, but we update immediately)
      authState = .authenticated(result.user)
      currentUser = result.user
      
      print("✅ [ANONYMOUS_AUTH] Anonymous authentication complete - cloud backup enabled")
      
    } catch {
      print("❌ [ANONYMOUS_AUTH] FAILED: \(error.localizedDescription)")
      print("⚠️ [ANONYMOUS_AUTH] Falling back to guest mode (offline-only)")
      // Don't throw - app continues in guest mode
      authState = .unauthenticated
      currentUser = nil
    }
  }

  // MARK: - Email/Password Authentication

  // Note: Email/password sign-in and sign-up functionality has been removed - can be restored from git history if needed

  func signOut() {
    // ✅ CRITICAL FIX: Capture user ID before clearing to clear migration flag
    let userIdToClear = currentUser?.uid
    
    do {
      try Auth.auth().signOut()
      authState = .unauthenticated
      currentUser = nil
      
      // ✅ DEBUG: Log userId after sign-out
      Task {
        let userIdAfterSignOut = await CurrentUser().idOrGuest
        print("🔐 Sign-out: CurrentUser().idOrGuest = '\(userIdAfterSignOut.isEmpty ? "EMPTY" : userIdAfterSignOut)'")
        print("🔐 Sign-out: Auth.auth().currentUser = \(Auth.auth().currentUser?.uid ?? "nil")")
      }

      // Clear sensitive data from Keychain
      KeychainManager.shared.clearAuthenticationData()
      print("✅ AuthenticationManager: Cleared sensitive data from Keychain")

      // Clear XP data to prevent data leakage between users
      XPManager.shared.handleUserSignOut()
      print("✅ AuthenticationManager: Cleared XP data")
      
      // ✅ CRITICAL FIX: Clear migration flag on sign out
      // This ensures if user creates new guest data and signs back in, they see the UI again
      if let userId = userIdToClear {
        let migrationKey = "guest_data_migrated_\(userId)"
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("✅ AuthenticationManager: Cleared migration flag for user: \(userId)")
      }

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

  /// Start Sign in with Apple flow
  /// Generates a nonce and returns a configured ASAuthorizationAppleIDRequest
  /// - Returns: Configured ASAuthorizationAppleIDRequest ready to use
  func startSignInWithApple() -> ASAuthorizationAppleIDRequest {
    print("🍎 [APPLE_SIGN_IN] Starting Sign in with Apple flow...")
    
    // Generate nonce for security
    let nonce = generateNonce()
    let nonceHash = sha256(nonce)
    
    print("🍎 [APPLE_SIGN_IN] Generated nonce: \(nonce.prefix(8))...")
    
    // Create and configure the request
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.email, .fullName]
    request.nonce = nonceHash
    
    print("🍎 [APPLE_SIGN_IN] Request configured with email and fullName scopes")
    
    return request
  }

  /// Handle Sign in with Apple result
  /// This method processes the authorization result and either links to an anonymous account
  /// or signs in normally, preserving user data when linking.
  /// - Parameter result: The authorization result from ASAuthorizationController
  func handleSignInWithApple(result: Result<ASAuthorization, Error>) async {
    print("🍎 [APPLE_SIGN_IN] Handling authorization result...")
    
    // Set authenticating state
    authState = .authenticating
    
    switch result {
    case .success(let authorization):
      guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
        let error = "Invalid credential type"
        print("❌ [APPLE_SIGN_IN] \(error)")
        authState = .error(error)
        return
      }
      
      // Extract identity token
      guard let identityToken = appleIDCredential.identityToken,
            let idTokenString = String(data: identityToken, encoding: .utf8) else {
        let error = "Unable to extract identity token"
        print("❌ [APPLE_SIGN_IN] \(error)")
        authState = .error(error)
        return
      }
      
      // Verify nonce
      guard let nonce = currentNonce else {
        let error = "Nonce not found - security check failed"
        print("❌ [APPLE_SIGN_IN] \(error)")
        authState = .error(error)
        return
      }
      
      // Extract full name if available (only provided on first sign-in)
      let fullName = appleIDCredential.fullName
      
      // Create Firebase credential using the static method
      let credential = OAuthProvider.appleCredential(
        withIDToken: idTokenString,
        rawNonce: nonce,
        fullName: fullName
      )
      
      print("🍎 [APPLE_SIGN_IN] Firebase credential created successfully")
      
      // Check if current user is anonymous
      guard let currentUser = Auth.auth().currentUser else {
        // No current user - perform regular sign in
        print("ℹ️ [APPLE_SIGN_IN] No current user - performing regular sign in")
        await performRegularSignIn(with: credential)
        return
      }
      
      if currentUser.isAnonymous {
        // User is anonymous - link the account to preserve data
        print("📦 [APPLE_SIGN_IN] Attempting to link anonymous account: \(currentUser.uid)")
        await linkAnonymousAccount(currentUser: currentUser, credential: credential)
      } else {
        // User is already signed in with another provider - perform regular sign in
        print("ℹ️ [APPLE_SIGN_IN] Regular sign-in (no anonymous account to link)")
        await performRegularSignIn(with: credential)
      }
      
      // Clear nonce after use
      currentNonce = nil
      
    case .failure(let error):
      print("❌ [APPLE_SIGN_IN] Sign in with Apple failed: \(error.localizedDescription)")
      authState = .error(error.localizedDescription)
      currentNonce = nil
    }
  }
  
  // MARK: - Private Apple Sign In Helpers
  
  /// Link anonymous account to Apple credential
  /// This preserves all user data by linking the anonymous account to the Apple account
  private func linkAnonymousAccount(currentUser: User, credential: AuthCredential) async {
    // ✅ CRITICAL: Capture anonymous userId BEFORE attempting link
    // If linking fails, we'll need this to migrate data to the Apple account
    let anonymousUserId = currentUser.uid
    print("📦 [APPLE_SIGN_IN] Linking anonymous account to Apple credential...")
    print("   Anonymous User ID: \(anonymousUserId)")
    
    do {
      let result = try await currentUser.link(with: credential)
      
      print("✅ [APPLE_SIGN_IN] Account linked successfully - all data preserved!")
      print("   User ID: \(result.user.uid)")
      print("   Email: \(result.user.email ?? "Not provided")")
      print("   Display Name: \(result.user.displayName ?? "Not provided")")
      
      // Update auth state
      authState = .authenticated(result.user)
      self.currentUser = result.user
      
      // Store userId in Keychain
      if KeychainManager.shared.storeUserID(result.user.uid) {
        print("✅ [APPLE_SIGN_IN] Stored userId in Keychain")
      }
      
    } catch {
      // Handle credential already in use error
      if let authError = error as NSError?,
         let errorCode = AuthErrorCode(rawValue: authError.code),
         errorCode == .credentialAlreadyInUse {
        
        print("⚠️ [APPLE_SIGN_IN] Credential already in use - attempting to sign in with existing account")
        print("   Anonymous account has data that needs migration: \(anonymousUserId)")
        
        // Extract the existing user's credential from the error
        if let existingCredential = authError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
          // Sign in with the existing credential
          do {
            let result = try await Auth.auth().signIn(with: existingCredential)
            let appleUserId = result.user.uid
            print("✅ [APPLE_SIGN_IN] Signed in with existing Apple account")
            print("   Apple User ID: \(appleUserId)")
            print("   Anonymous User ID (with data): \(anonymousUserId)")
            
            // ✅ CRITICAL FIX: Migrate data from anonymous account to Apple account
            // The anonymous account has data that needs to be migrated to the Apple account
            if anonymousUserId != appleUserId {
              print("🔄 [APPLE_SIGN_IN] Migrating data from anonymous account to Apple account...")
              print("   From: \(anonymousUserId)")
              print("   To: \(appleUserId)")
              
              do {
                // Use GuestToAuthMigration to migrate all data types
                try await GuestToAuthMigration.shared.migrateGuestDataIfNeeded(
                  from: anonymousUserId,
                  to: appleUserId
                )
                print("✅ [APPLE_SIGN_IN] Data migration completed successfully!")
                print("   All habits, completions, awards, and streak data migrated")
              } catch {
                print("❌ [APPLE_SIGN_IN] Data migration failed: \(error.localizedDescription)")
                // Don't fail sign-in if migration fails - user can still use the app
                // Migration can be retried later if needed
              }
            } else {
              print("ℹ️ [APPLE_SIGN_IN] Anonymous and Apple accounts are the same - no migration needed")
            }
            
            authState = .authenticated(result.user)
            self.currentUser = result.user
            
            // Store userId in Keychain
            if KeychainManager.shared.storeUserID(result.user.uid) {
              print("✅ [APPLE_SIGN_IN] Stored userId in Keychain")
            }
          } catch {
            print("❌ [APPLE_SIGN_IN] Failed to sign in with existing credential: \(error.localizedDescription)")
            authState = .error("This Apple ID is already associated with another account. Please sign in with that account.")
          }
        } else {
          print("❌ [APPLE_SIGN_IN] Credential already in use, but unable to retrieve existing credential")
          authState = .error("This Apple ID is already associated with another account. Please sign in with that account.")
        }
      } else {
        print("❌ [APPLE_SIGN_IN] Failed to link account: \(error.localizedDescription)")
        authState = .error(error.localizedDescription)
      }
    }
  }
  
  /// Perform regular sign in with Apple credential
  /// Used when there's no anonymous account to link
  private func performRegularSignIn(with credential: AuthCredential) async {
    do {
      print("🍎 [APPLE_SIGN_IN] Signing in with Apple credential...")
      
      let result = try await Auth.auth().signIn(with: credential)
      
      print("✅ [APPLE_SIGN_IN] Sign in successful")
      print("   User ID: \(result.user.uid)")
      print("   Email: \(result.user.email ?? "Not provided")")
      print("   Display Name: \(result.user.displayName ?? "Not provided")")
      
      // Update auth state
      authState = .authenticated(result.user)
      self.currentUser = result.user
      
      // Store userId in Keychain
      if KeychainManager.shared.storeUserID(result.user.uid) {
        print("✅ [APPLE_SIGN_IN] Stored userId in Keychain")
      }
      
    } catch {
      print("❌ [APPLE_SIGN_IN] Failed to sign in: \(error.localizedDescription)")
      authState = .error(error.localizedDescription)
    }
  }

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
    
    setupAuthStateListener()
    hasSetupAuthListener = true
  }
  
  private func setupAuthStateListener() {
    // Check if Firebase is configured before accessing Auth
    guard FirebaseApp.app() != nil else {
      print("⚠️ AuthenticationManager: Firebase not configured yet, deferring auth listener setup")
      return
    }
    
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
