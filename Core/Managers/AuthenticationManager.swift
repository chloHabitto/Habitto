import Foundation
// import FirebaseAuth // Temporarily commented out due to package dependency issues
import AuthenticationServices
// import GoogleSignIn // Temporarily commented out due to package dependency issues
import CryptoKit

// MARK: - Authentication State
enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(UserProtocol)
    case error(String)
}

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: UserProtocol?
    
    private var authStateListener: Any? // AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        // Clean up the listener in deinit
        // Temporarily disabled due to Firebase dependency issues
        // if let listener = authStateListener {
        //     Auth.auth().removeStateDidChangeListener(listener)
        // }
    }
    
    // MARK: - Authentication State Listener
    private func setupAuthStateListener() {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Firebase authentication temporarily disabled")
        // authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
        //     DispatchQueue.main.async {
        //         if let user = user {
        //             self?.authState = .authenticated(user)
        //             self?.currentUser = user
        //             print("✅ AuthenticationManager: User authenticated: \(user.email ?? "No email")")
        //         } else {
        //             self?.authState = .unauthenticated
        //             self?.currentUser = nil
        //             print("ℹ️ AuthenticationManager: User in guest mode - no authentication required")
        //         }
        //     }
        // }
    }
    
    // MARK: - Email/Password Authentication
    func signInWithEmail(email: String, password: String, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Firebase sign-in temporarily disabled")
        completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication temporarily disabled"])))
        // authState = .authenticating
        // Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
        //     DispatchQueue.main.async {
        //         if let error = error {
        //             self?.authState = .error(error.localizedDescription)
        //             completion(.failure(error))
        //         } else if let user = result?.user {
        //             self?.authState = .authenticated(user)
        //             self?.currentUser = user
        //             completion(.success(user))
        //         }
        //     }
        // }
    }
    
    func createAccountWithEmail(email: String, password: String, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Firebase account creation temporarily disabled")
        completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication temporarily disabled"])))
        // authState = .authenticating
        // Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
        //     DispatchQueue.main.async {
        //         if let error = error {
        //             self?.authState = .error(error.localizedDescription)
        //             completion(.failure(error))
        //         } else if let user = result?.user {
        //             self?.authState = .authenticated(user)
        //             self?.currentUser = user
        //             completion(.success(user))
        //         }
        //     }
        // }
    }
    
    func signOut() {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Firebase sign-out temporarily disabled")
        authState = .unauthenticated
        currentUser = nil
        // do {
        //     try Auth.auth().signOut()
        //     authState = .unauthenticated
        //     currentUser = nil
        //     print("✅ AuthenticationManager: User signed out successfully")
        // } catch {
        //     authState = .error(error.localizedDescription)
        //     print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
        // }
    }
    
    /// Reset password
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Firebase password reset temporarily disabled")
        completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication temporarily disabled"])))
        // Auth.auth().sendPasswordReset(withEmail: email) { error in
        //     DispatchQueue.main.async {
        //         if let error = error {
        //             completion(.failure(error))
        //         } else {
        //             completion(.success(()))
        //         }
        //     }
        // }
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
    
    // MARK: - Google Sign In
    func signInWithGoogle(completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        // Temporarily disabled due to Firebase dependency issues
        print("⚠️ AuthenticationManager: Google Sign-In temporarily disabled")
        completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication temporarily disabled"])))
        // print("🔐 AuthenticationManager: Starting Google Sign-In process...")
        // authState = .authenticating
        // ... rest of Google Sign-In implementation commented out
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        authState = .authenticating
        
        // For now, create a mock user since Firebase OAuth is not available in this SDK version
        // TODO: Update Firebase SDK to enable proper Apple Sign-In integration
        let mockUser = CustomUser(
            uid: "apple_\(UUID().uuidString)",
            email: credential.email ?? "apple_user@example.com",
            displayName: [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
        )
        
        DispatchQueue.main.async {
            self.authState = .authenticated(mockUser)
            self.currentUser = mockUser
            self.currentNonce = nil // Clear nonce after successful use
            completion(.success(mockUser))
        }
    }
    
    // MARK: - User Profile Management
    func updateUserProfile(displayName: String?, photoURL: URL?, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase disabled - return error
        DispatchQueue.main.async {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication is currently disabled"])))
        }
    }
    
    func updateUserEmail(newEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase disabled - return error
        DispatchQueue.main.async {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase authentication is currently disabled"])))
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

// MARK: - Firebase User Extension (disabled)
// extension User: UserProtocol {}
