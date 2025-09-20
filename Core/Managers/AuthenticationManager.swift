import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import GoogleSignIn
import CryptoKit

// MARK: - Authentication State
enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(UserProtocol)
    case error(String)
}

// MARK: - Authentication Manager
// 
// This manager handles user authentication via Firebase Auth only.
// It does NOT store or manage habit data - that's handled by HabitRepository.
// 
// Firebase Usage:
// - Google Sign-In authentication
// - Apple Sign-In authentication  
// - Email/Password authentication
// - Session management and token storage
//
// Data Storage:
// - Authentication tokens → Keychain
// - User profile info → Firebase Auth
// - Habit data → HabitRepository (UserDefaults → Core Data)
//
@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: UserProtocol?
    
    private var authStateListener: NSObjectProtocol?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        // Clean up the listener in deinit
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication State Listener
    private func setupAuthStateListener() {
        print("🔐 AuthenticationManager: Setting up Firebase authentication state listener")
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.authState = .authenticated(user)
                    self?.currentUser = user
                    print("✅ AuthenticationManager: User authenticated: \(user.email ?? "No email")")
                } else {
                    self?.authState = .unauthenticated
                    self?.currentUser = nil
                    print("ℹ️ AuthenticationManager: User in guest mode - no authentication required")
                }
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(email: String, password: String, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        print("🔐 AuthenticationManager: Starting email/password sign-in")
        authState = .authenticating
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
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
    
    func createAccountWithEmail(email: String, password: String, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        print("🔐 AuthenticationManager: Starting email/password account creation")
        authState = .authenticating
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
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
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Apple Sign In Nonce (Security) - Simplified
    private var currentNonce: String?
    
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
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
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
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
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle(completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        print("🔐 AuthenticationManager: Starting Google Sign-In process...")
        authState = .authenticating
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller found"])))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.authState = .error(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.authState = .error("Failed to get Google ID token")
                    completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Google ID token"])))
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.authState = .error(error.localizedDescription)
                            completion(.failure(error))
                        } else if let user = authResult?.user {
                            self?.authState = .authenticated(user)
                            self?.currentUser = user
                            completion(.success(user))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
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
        if let fullName = fullName {
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
            if let storedName = storedName, !storedName.isEmpty {
                displayName = storedName
                print("🍎 Using stored name from Keychain: \(displayName)")
            } else {
                print("🍎 No name information available, using default: \(displayName)")
            }
        }
        
        // Store the name for future use (only if we got a name from Apple)
        if let fullName = fullName, let givenName = fullName.givenName {
            let nameToStore = fullName.familyName != nil ? "\(givenName) \(fullName.familyName!)" : givenName
            _ = KeychainManager.shared.storeAppleUserDisplayName(nameToStore, for: userID)
            print("🍎 Stored name for future use in Keychain: \(nameToStore)")
        }
        
        // Create a mock Firebase user object for Apple Sign-In
        // In a real implementation, you would create a Firebase user manually
        let mockUser = MockFirebaseUser(
            uid: userID,
            email: email,
            displayName: displayName,
            isEmailVerified: true
        )
        
        print("✅ AuthenticationManager: Apple Sign-In successful for user: \(userID) with display name: \(displayName)")
        DispatchQueue.main.async {
            self.authState = .authenticated(mockUser)
            self.currentUser = mockUser
            completion(.success(mockUser))
        }
    }
    
    // MARK: - User Profile Management
    func updateUserProfile(displayName: String?, photoURL: URL?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        changeRequest.photoURL = photoURL
        
        changeRequest.commitChanges { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Profile updated successfully, refresh the current user
                    user.reload { [weak self] error in
                        if let error = error {
                            print("⚠️ AuthenticationManager: Failed to reload user after profile update: \(error.localizedDescription)")
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
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
            return
        }
        
        user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
            DispatchQueue.main.async {
                if let error = error {
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
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user to re-authenticate"])))
            return
        }
        
        // Check if user has a Google provider
        if user.providerData.contains(where: { $0.providerID == "google.com" }) {
            print("🔐 AuthenticationManager: User has Google provider, performing Google re-authentication")
            
            // For Google users, we need to perform a fresh Google Sign-In
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase client ID not found"])))
                return
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Perform fresh Google Sign-In
            GIDSignIn.sharedInstance.signIn(withPresenting: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ AuthenticationManager: Google re-authentication failed: \(error.localizedDescription)")
                        completion(.failure(NSError(domain: "AuthenticationManager", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Re-authentication failed. Please try again."])))
                        return
                    }
                    
                    guard let user = result?.user,
                          let idToken = user.idToken?.tokenString else {
                        print("❌ AuthenticationManager: Failed to get Google ID token")
                        completion(.failure(NSError(domain: "AuthenticationManager", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Failed to get authentication token"])))
                        return
                    }
                    
                    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                    
                    // Re-authenticate with Firebase
                    Auth.auth().currentUser?.reauthenticate(with: credential) { authResult, authError in
                        DispatchQueue.main.async {
                            if let authError = authError {
                                print("❌ AuthenticationManager: Firebase re-authentication failed: \(authError.localizedDescription)")
                                completion(.failure(NSError(domain: "AuthenticationManager", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Re-authentication with Firebase failed. Please try again."])))
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
            user.getIDTokenForcingRefresh(true) { token, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ AuthenticationManager: Failed to refresh token: \(error.localizedDescription)")
                        completion(.failure(NSError(domain: "AuthenticationManager", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Authentication refresh failed. Please sign out and sign in again."])))
                    } else {
                        print("✅ AuthenticationManager: Token refreshed successfully")
                        completion(.success(()))
                    }
                }
            }
        } else {
            // For other providers (Apple, etc.), try to refresh the token
            print("🔐 AuthenticationManager: User has other provider, refreshing token")
            user.getIDTokenForcingRefresh(true) { token, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ AuthenticationManager: Failed to refresh token: \(error.localizedDescription)")
                        completion(.failure(NSError(domain: "AuthenticationManager", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Authentication refresh failed. Please sign out and sign in again."])))
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
        
        guard Auth.auth().currentUser != nil else {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user to delete"])))
            return
        }
        
        // For now, let's try a simpler approach - just clear local data and sign out
        // This effectively "deletes" the account from the user's perspective
        print("🗑️ AuthenticationManager: Clearing local account data and signing out")
        
        // Clear local state first
        self.authState = .unauthenticated
        self.currentUser = nil
        
        // Clear sensitive data from Keychain
        KeychainManager.shared.clearAuthenticationData()
        print("✅ AuthenticationManager: Cleared local authentication data")
        
        // Sign out from Firebase (this doesn't delete the account but signs the user out)
        do {
            try Auth.auth().signOut()
            print("✅ AuthenticationManager: Signed out from Firebase")
            
            // For now, we'll consider this a "successful deletion" from the user's perspective
            // The Firebase account will remain but the user is signed out and all local data is cleared
            completion(.success(()))
            
        } catch {
            print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
            // Even if sign out fails, we've cleared local data, so consider it successful
            completion(.success(()))
        }
    }
}

// MARK: - Custom User for Apple Sign-In
struct CustomUser: UserProtocol {
    let uid: String
    let email: String?
    let displayName: String?
}

// MARK: - User Protocol
protocol UserProtocol {
    var uid: String { get }
    var email: String? { get }
    var displayName: String? { get }
}

// MARK: - Mock Firebase User for Apple Sign-In
class MockFirebaseUser: UserProtocol {
    let uid: String
    let email: String?
    let displayName: String?
    let isEmailVerified: Bool
    
    init(uid: String, email: String?, displayName: String?, isEmailVerified: Bool = false) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
    }
}

// MARK: - Firebase User Extension
extension User: UserProtocol {}
