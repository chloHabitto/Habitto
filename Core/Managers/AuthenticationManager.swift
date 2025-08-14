import Foundation
import FirebaseAuth
import AuthenticationServices
import Combine

// MARK: - Authentication State
enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(String)
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: User?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Firebase Auth State Listener
    private func setupAuthStateListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.authState = .authenticated(user)
                    self?.currentUser = user
                    print("✅ AuthenticationManager: User authenticated - \(user.email ?? "No email")")
                } else {
                    // User is not authenticated - this is fine for guest mode
                    self?.authState = .unauthenticated
                    self?.currentUser = nil
                    print("ℹ️ AuthenticationManager: User in guest mode - no authentication required")
                }
            }
        }
    }
    
    // MARK: - Sign In Methods
    
    /// Sign in with Apple ID (simplified implementation)
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Result<User, Error>) -> Void) {
        authState = .authenticating
        
        // For now, create a simple user account with Apple ID
        // TODO: Implement proper Firebase Apple Sign-In when SDK compatibility is resolved
        let error = NSError(domain: "AuthenticationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In is temporarily disabled. Please use email/password authentication."])
        completion(.failure(error))
    }
    
    /// Sign in with Google (currently disabled - SDK not available)
    func signInWithGoogle(completion: @escaping (Result<User, Error>) -> Void) {
        // TODO: Add Google Sign-In SDK to project and implement proper authentication
        let error = NSError(domain: "AuthenticationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In is not currently available. Please use email/password or Apple Sign-In."])
        completion(.failure(error))
    }
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
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
    
    /// Create account with email and password
    func createAccountWithEmail(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
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
    
    /// Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
            authState = .unauthenticated
            currentUser = nil
            print("✅ AuthenticationManager: User signed out successfully")
        } catch {
            authState = .error(error.localizedDescription)
            print("❌ AuthenticationManager: Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    /// Reset password
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
    
    // MARK: - User Profile Management
    func updateUserProfile(displayName: String?, photoURL: URL?, completion: @escaping (Result<Void, Error>) -> Void) {
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = displayName
        changeRequest?.photoURL = photoURL
        
        changeRequest?.commitChanges { error in
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
}
