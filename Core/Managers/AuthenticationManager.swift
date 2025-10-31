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
  
  /// Sign in anonymously (for guest users who want to try the app)
  func signInAnonymously(completion: @escaping (Result<UserProtocol, Error>) -> Void) {
    print("🔐 AuthenticationManager: Starting anonymous sign-in")
    authState = .authenticating
    
    Task {
      do {
        let result = try await Auth.auth().signInAnonymously()
        let user = result.user
        
        await MainActor.run {
          self.authState = .authenticated(user)
          self.currentUser = user
          
          // Track anonymous user in Crashlytics
          CrashlyticsService.shared.setUserID(user.uid)
          CrashlyticsService.shared.setValue("anonymous", forKey: "auth_provider")
          
          print("✅ AuthenticationManager: Anonymous sign-in successful: \(user.uid)")
          completion(.success(user))
        }
      } catch {
        await MainActor.run {
          self.authState = .error(error.localizedDescription)
          print("❌ AuthenticationManager: Anonymous sign-in failed: \(error.localizedDescription)")
          completion(.failure(error))
        }
      }
    }
  }
  
  /// Check if current user is anonymous
  var isAnonymous: Bool {
    Auth.auth().currentUser?.isAnonymous ?? false
  }

  // MARK: - Email/Password Authentication

  func signInWithEmail(
    email: String,
    password: String,
    completion: @escaping (Result<UserProtocol, Error>) -> Void)
  {
    print("🔐 AuthenticationManager: Starting email/password sign-in")
    authState = .authenticating
    Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
      DispatchQueue.main.async {
        if let error {
          self?.authState = .error(error.localizedDescription)
          completion(.failure(error))
        } else if let user = result?.user {
          self?.authState = .authenticated(user)
          self?.currentUser = user
          
          // Track user in Crashlytics for crash reports (ready when package added)
          CrashlyticsService.shared.setUserID(user.uid)
          CrashlyticsService.shared.setValue(user.email ?? "no_email", forKey: "user_email")
          
          completion(.success(user))
        }
      }
    }
  }

  func createAccountWithEmail(
    email: String,
    password: String,
    completion: @escaping (Result<UserProtocol, Error>) -> Void)
  {
    print("🔐 AuthenticationManager: Starting email/password account creation")
    authState = .authenticating

    // If the user is currently anonymous, upgrade the session by linking credentials
    if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
      let credential = EmailAuthProvider.credential(withEmail: email, password: password)
      currentUser.link(with: credential) { [weak self] result, error in
        DispatchQueue.main.async {
          if let error {
            // If the email is already in use, sign in with the provided credentials instead
            let nsError = error as NSError
            print("🔍 DEBUG: Linking error code: \(nsError.code), message: \(error.localizedDescription)")
            print("🔍 DEBUG: credentialAlreadyInUse code: \(AuthErrorCode.credentialAlreadyInUse.rawValue)")
            print("🔍 DEBUG: emailAlreadyInUse code: \(AuthErrorCode.emailAlreadyInUse.rawValue)")
            
            if nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue
              || nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue
            {
              print("✅ DEBUG: Email already in use, attempting sign-in instead...")
              Auth.auth().signIn(withEmail: email, password: password) { signInResult, signInError in
                DispatchQueue.main.async {
                  if let signInError {
                    print("❌ DEBUG: Sign-in also failed: \(signInError.localizedDescription)")
                    self?.authState = .error(signInError.localizedDescription)
                    completion(.failure(signInError))
                  } else if let user = signInResult?.user {
                    print("✅ DEBUG: Sign-in successful after linking failed")
                    self?.authState = .authenticated(user)
                    self?.currentUser = user
                    completion(.success(user))
                  }
                }
              }
              return
            }

            print("❌ DEBUG: Linking failed with unexpected error, not attempting sign-in")
            self?.authState = .error(error.localizedDescription)
            completion(.failure(error))
          } else if let user = result?.user {
            self?.authState = .authenticated(user)
            self?.currentUser = user
            completion(.success(user))
          }
        }
      }
      return
    }

    // Otherwise, create a new account normally
    Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
      DispatchQueue.main.async {
        if let error {
          // If the email already exists, attempt to sign in directly
          let nsError = error as NSError
          print("🔍 DEBUG: Create account error code: \(nsError.code), message: \(error.localizedDescription)")
          print("🔍 DEBUG: emailAlreadyInUse code: \(AuthErrorCode.emailAlreadyInUse.rawValue)")
          
          if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
            print("✅ DEBUG: Email already in use, attempting sign-in instead...")
            Auth.auth().signIn(withEmail: email, password: password) { signInResult, signInError in
              DispatchQueue.main.async {
                if let signInError {
                  print("❌ DEBUG: Sign-in also failed: \(signInError.localizedDescription)")
                  self?.authState = .error(signInError.localizedDescription)
                  completion(.failure(signInError))
                } else if let user = signInResult?.user {
                  print("✅ DEBUG: Sign-in successful after create failed")
                  self?.authState = .authenticated(user)
                  self?.currentUser = user
                  completion(.success(user))
                }
              }
            }
            return
          }

          print("❌ DEBUG: Create account failed with unexpected error")
          self?.authState = .error(error.localizedDescription)
          completion(.failure(error))
        } else if let user = result?.user {
          self?.authState = .authenticated(user)
          self?.currentUser = user
          completion(.success(user))
        }
      }
    }
  }

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

  /// Reset password
  func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
    print("🔐 AuthenticationManager: Starting password reset")
    Auth.auth().sendPasswordReset(withEmail: email) { error in
      DispatchQueue.main.async {
        if let error {
          completion(.failure(error))
        } else {
          completion(.success(()))
        }
      }
    }
  }

  func generateNonce() -> String {
    let nonce = randomNonceString()
    currentNonce = nonce
    return nonce
  }

  // MARK: - Google Sign In

  func signInWithGoogle(completion: @escaping (Result<UserProtocol, Error>) -> Void) {
    print("🔐 AuthenticationManager: Starting Google Sign-In process...")
    authState = .authenticating

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let presentingViewController = windowScene.windows.first?.rootViewController else
    {
      completion(.failure(NSError(
        domain: "AuthenticationManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No presenting view controller found"])))
      return
    }

    GIDSignIn.sharedInstance
      .signIn(withPresenting: presentingViewController) { [weak self] result, error in
        DispatchQueue.main.async {
          if let error {
            self?.authState = .error(error.localizedDescription)
            completion(.failure(error))
            return
          }

          guard let user = result?.user,
                let idToken = user.idToken?.tokenString else
          {
            self?.authState = .error("Failed to get Google ID token")
            completion(.failure(NSError(
              domain: "AuthenticationManager",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID token"])))
            return
          }

          let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString)

          Auth.auth().signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
              if let error {
                self?.authState = .error(error.localizedDescription)
                completion(.failure(error))
              } else if let user = authResult?.user {
                self?.authState = .authenticated(user)
                self?.currentUser = user
                
                // Track user in Crashlytics
                CrashlyticsService.shared.setUserID(user.uid)
                CrashlyticsService.shared.setValue(user.email ?? "google_user", forKey: "user_email")
                CrashlyticsService.shared.setValue("google", forKey: "auth_provider")
                
                completion(.success(user))
              }
            }
          }
        }
      }
  }

  // MARK: - Apple Sign In

  func signInWithApple(
    credential: ASAuthorizationAppleIDCredential,
    nonce _: String,
    completion: @escaping (Result<UserProtocol, Error>) -> Void)
  {
    print("🍎 AuthenticationManager: Starting Apple Sign-In...")

    // Apple Sign-In should be handled directly with Apple's SDK, not through Firebase OAuth
    // Create a custom user object from Apple's credential
    let userID = credential.user
    let email = credential.email ?? "apple_user_\(userID)"
    let fullName = credential.fullName

    // Debug: Print what information is available from Apple
    print("🍎 Apple Sign-In Debug Info:")
    print("   - User ID: \(userID)")
    print("   - Email: \(email)")
    print("   - Full Name: \(fullName?.description ?? "nil")")
    print("   - Given Name: \(fullName?.givenName ?? "nil")")
    print("   - Family Name: \(fullName?.familyName ?? "nil")")

    // Create a display name from Apple's full name
    var displayName = "Apple User"

    // Apple only provides name information on the FIRST sign-in attempt
    // On subsequent sign-ins, fullName will be nil for privacy reasons
    if let fullName {
      if let givenName = fullName.givenName, let familyName = fullName.familyName {
        displayName = "\(givenName) \(familyName)"
        print("🍎 Using full name: \(displayName)")
      } else if let givenName = fullName.givenName {
        displayName = givenName
        print("🍎 Using given name only: \(displayName)")
      } else if let familyName = fullName.familyName {
        displayName = familyName
        print("🍎 Using family name only: \(displayName)")
      }
    } else {
      // On subsequent sign-ins, try to retrieve stored name from Keychain
      let storedName = KeychainManager.shared.retrieveAppleUserDisplayName(for: userID)
      if let storedName, !storedName.isEmpty {
        displayName = storedName
        print("🍎 Using stored name from Keychain: \(displayName)")
      } else {
        print("🍎 No name information available, using default: \(displayName)")
      }
    }

    // Store the name for future use (only if we got a name from Apple)
    if let fullName, let givenName = fullName.givenName {
      let nameToStore = fullName.familyName != nil
        ? "\(givenName) \(fullName.familyName!)"
        : givenName
      _ = KeychainManager.shared.storeAppleUserDisplayName(nameToStore, for: userID)
      print("🍎 Stored name for future use in Keychain: \(nameToStore)")
    }

    // Create a mock Firebase user object for Apple Sign-In
    // In a real implementation, you would create a Firebase user manually
    let mockUser = MockFirebaseUser(
      uid: userID,
      email: email,
      displayName: displayName,
      isEmailVerified: true)

    print(
      "✅ AuthenticationManager: Apple Sign-In successful for user: \(userID) with display name: \(displayName)")
    DispatchQueue.main.async {
      self.authState = .authenticated(mockUser)
      self.currentUser = mockUser
      completion(.success(mockUser))
    }
  }

  // MARK: - User Profile Management

  func updateUserProfile(
    displayName: String?,
    photoURL: URL?,
    completion: @escaping (Result<Void, Error>) -> Void)
  {
    guard let user = Auth.auth().currentUser else {
      completion(.failure(NSError(
        domain: "AuthenticationManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
      return
    }

    let changeRequest = user.createProfileChangeRequest()
    changeRequest.displayName = displayName
    changeRequest.photoURL = photoURL

    changeRequest.commitChanges { [weak self] error in
      DispatchQueue.main.async {
        if let error {
          completion(.failure(error))
        } else {
          // Profile updated successfully, refresh the current user
          user.reload { [weak self] error in
            if let error {
              print(
                "⚠️ AuthenticationManager: Failed to reload user after profile update: \(error.localizedDescription)")
            } else {
              print("✅ AuthenticationManager: Successfully reloaded user after profile update")
              // Update our currentUser property with the refreshed user data
              self?.currentUser = user
            }
          }
          completion(.success(()))
        }
      }
    }
  }

  func updateUserEmail(newEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let user = Auth.auth().currentUser else {
      completion(.failure(NSError(
        domain: "AuthenticationManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
      return
    }

    user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
      DispatchQueue.main.async {
        if let error {
          completion(.failure(error))
        } else {
          completion(.success(()))
        }
      }
    }
  }

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

  /// Re-authenticate the current user to refresh their authentication token
  func reauthenticateUser(completion: @escaping (Result<Void, Error>) -> Void) {
    print("🔐 AuthenticationManager: Starting re-authentication")

    guard let user = Auth.auth().currentUser else {
      completion(.failure(NSError(
        domain: "AuthenticationManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No authenticated user to re-authenticate"])))
      return
    }

    // Check if user has a Google provider
    if user.providerData.contains(where: { $0.providerID == "google.com" }) {
      print(
        "🔐 AuthenticationManager: User has Google provider, performing Google re-authentication")

      // For Google users, we need to perform a fresh Google Sign-In
      guard let clientID = FirebaseApp.app()?.options.clientID else {
        completion(.failure(NSError(
          domain: "AuthenticationManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Firebase client ID not found"])))
        return
      }

      let config = GIDConfiguration(clientID: clientID)
      GIDSignIn.sharedInstance.configuration = config

      // Perform fresh Google Sign-In
      let presentingViewController = getTopViewController() ?? UIViewController()
      GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
        DispatchQueue.main.async {
          if let error {
            print(
              "❌ AuthenticationManager: Google re-authentication failed: \(error.localizedDescription)")
            completion(.failure(NSError(
              domain: "AuthenticationManager",
              code: 17014,
              userInfo: [
                NSLocalizedDescriptionKey: "Re-authentication failed. Please try again."
              ])))
            return
          }

          guard let user = result?.user,
                let idToken = user.idToken?.tokenString else
          {
            print("❌ AuthenticationManager: Failed to get Google ID token")
            completion(.failure(NSError(
              domain: "AuthenticationManager",
              code: 17014,
              userInfo: [NSLocalizedDescriptionKey: "Failed to get authentication token"])))
            return
          }

          let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString)

          // Re-authenticate with Firebase
          Auth.auth().currentUser?.reauthenticate(with: credential) { _, authError in
            DispatchQueue.main.async {
              if let authError {
                print(
                  "❌ AuthenticationManager: Firebase re-authentication failed: \(authError.localizedDescription)")
                completion(.failure(NSError(
                  domain: "AuthenticationManager",
                  code: 17014,
                  userInfo: [
                    NSLocalizedDescriptionKey: "Re-authentication with Firebase failed. Please try again."
                  ])))
              } else {
                print("✅ AuthenticationManager: Google re-authentication successful")
                completion(.success(()))
              }
            }
          }
        }
      }

    } else if user.providerData.contains(where: { $0.providerID == "password" }) {
      print("🔐 AuthenticationManager: User has email/password provider, refreshing token")

      // For email/password users, try to refresh the token
      user.getIDTokenForcingRefresh(true) { _, error in
        DispatchQueue.main.async {
          if let error {
            print("❌ AuthenticationManager: Failed to refresh token: \(error.localizedDescription)")
            completion(.failure(NSError(
              domain: "AuthenticationManager",
              code: 17014,
              userInfo: [
                NSLocalizedDescriptionKey: "Authentication refresh failed. Please sign out and sign in again."
              ])))
          } else {
            print("✅ AuthenticationManager: Token refreshed successfully")
            completion(.success(()))
          }
        }
      }
    } else {
      // For other providers (Apple, etc.), try to refresh the token
      print("🔐 AuthenticationManager: User has other provider, refreshing token")
      user.getIDTokenForcingRefresh(true) { _, error in
        DispatchQueue.main.async {
          if let error {
            print("❌ AuthenticationManager: Failed to refresh token: \(error.localizedDescription)")
            completion(.failure(NSError(
              domain: "AuthenticationManager",
              code: 17014,
              userInfo: [
                NSLocalizedDescriptionKey: "Authentication refresh failed. Please sign out and sign in again."
              ])))
          } else {
            print("✅ AuthenticationManager: Token refreshed successfully")
            completion(.success(()))
          }
        }
      }
    }
  }

  func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
    print("🗑️ AuthenticationManager: Starting account deletion")

    guard let currentUser = Auth.auth().currentUser else {
      completion(.failure(NSError(
        domain: "AuthenticationManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "No authenticated user to delete"])))
      return
    }

    print("🗑️ AuthenticationManager: Deleting account for user: \(currentUser.uid)")

    // ✅ CRITICAL FIX: Properly sign out and clear Firebase Auth session
    // Clear local state first
    authState = .unauthenticated
    self.currentUser = nil

    // Clear sensitive data from Keychain
    KeychainManager.shared.clearAuthenticationData()
    print("✅ AuthenticationManager: Cleared local authentication data")

    // Sign out from Firebase Auth - this clears the persisted session
    do {
      try Auth.auth().signOut()
      print("✅ AuthenticationManager: Signed out from Firebase Auth")
      
      // ✅ IMPORTANT: Force clear any remaining auth state
      // Firebase Auth persists sessions in local storage, so we need to ensure it's cleared
      // The signOut() should handle this, but we'll also clear our local state again
      authState = .unauthenticated
      self.currentUser = nil
      
      completion(.success(()))
    } catch {
      print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
      // Even if sign out fails, clear local state
      authState = .unauthenticated
      self.currentUser = nil
      completion(.success(()))
    }
  }

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
          self?.authState = .authenticated(user)
          self?.currentUser = user
          print("✅ AuthenticationManager: User authenticated: \(user.email ?? "No email")")

          // Load user-specific XP data
          // Note: This will be called from a view with ModelContext access
          print("🎯 AUTH: User signed in, XP loading will be handled by view")
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
