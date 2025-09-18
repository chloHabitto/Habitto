import Foundation
import FirebaseAuth
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
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Result<UserProtocol, Error>) -> Void) {
        print("🍎 AuthenticationManager: Starting Apple Sign-In...")
        
        guard credential.identityToken != nil else {
            print("❌ AuthenticationManager: Failed to get identity token from Apple")
            let error = NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token from Apple"])
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        // Create OAuth provider for Apple
        let provider = OAuthProvider(providerID: "apple.com")
        
        // Sign in with Firebase using the Apple provider
        provider.getCredentialWith(nil) { [weak self] credential, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("❌ AuthenticationManager: Apple Sign-In failed: \(error.localizedDescription)")
                    self?.authState = .error("Apple Sign-In failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            guard let credential = credential else {
                DispatchQueue.main.async {
                    print("❌ AuthenticationManager: Apple Sign-In failed - no credential")
                    let error = NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In failed - no credential"])
                    self?.authState = .error("Apple Sign-In failed - no credential")
                    completion(.failure(error))
                }
                return
            }
            
            // Sign in with Firebase using the Apple credential
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ AuthenticationManager: Apple Sign-In failed: \(error.localizedDescription)")
                        self?.authState = .error("Apple Sign-In failed: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else if let result = result {
                        print("✅ AuthenticationManager: Apple Sign-In successful for user: \(result.user.uid)")
                        let user = result.user
                        self?.authState = .authenticated(user)
                        self?.currentUser = user
                        completion(.success(user))
                    } else {
                        print("❌ AuthenticationManager: Apple Sign-In failed - no result")
                        let error = NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In failed - no result"])
                        self?.authState = .error("Apple Sign-In failed - no result")
                        completion(.failure(error))
                    }
                }
            }
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
        
        changeRequest.commitChanges { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
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

// MARK: - Firebase User Extension
extension User: UserProtocol {}
