import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Store delegates to prevent deallocation
    @State private var appleSignInDelegate: AppleSignInDelegate?
    @State private var appleSignInPresentationContextProvider: AppleSignInPresentationContextProvider?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text(isSignUp ? "Create Account" : "Welcome Back")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.text01)
                            
                            Text(isSignUp ? "Start your habit journey today" : "Sign in to continue your progress")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.text04)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.text01)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.outline2, lineWidth: 1)
                                )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.text01)
                            
                            HStack {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .textContentType(isSignUp ? .newPassword : .password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .textContentType(isSignUp ? .newPassword : .password)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.text04)
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.outline2, lineWidth: 1)
                            )
                        }
                        
                        // Forgot Password (only for sign in)
                        if !isSignUp {
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showForgotPassword = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Sign In/Up Button
                        HabittoButton(
                            size: .large,
                            style: .fillPrimary,
                            content: .text(isLoading ? "Please wait..." : (isSignUp ? "Create Account" : "Sign In")),
                            hugging: false
                        ) {
                            handleEmailAuth()
                        }
                        .disabled(!isFormValid || isLoading)
                        
                        // Toggle Sign In/Sign Up (moved below button)
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.text04)
                            
                            Button(isSignUp ? "Sign In" : "Sign Up") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSignUp.toggle()
                                    email = ""
                                    password = ""
                                    errorMessage = ""
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 16)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.outline2)
                            
                            Text("or")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.text04)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.outline2)
                        }
                        .padding(.vertical, 20)
                        
                        // Social Login Buttons
                        VStack(spacing: 16) {
                            // Apple ID Button
                            Button(action: {
                                handleAppleLogin()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Continue with Apple")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .cornerRadius(28)
                            }
                            .disabled(isLoading)
                            
                            // Continue with Google
                            Button(action: handleGoogleLogin) {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Continue with Google")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(28)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Bottom padding
                    Spacer(minLength: 40)
                }
            }
            .background(Color.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.text04)
                }
            }
            .alert("Authentication Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .onReceive(authManager.$authState) { state in
                switch state {
                case .authenticated:
                    // Successfully authenticated, dismiss the view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                case .error(let message):
                    errorMessage = message
                    showError = true
                    isLoading = false
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && authManager.isValidEmail(email) && (isSignUp ? authManager.isValidPassword(password) : true)
    }
    
    // MARK: - Authentication Handlers
    private func handleEmailAuth() {
        isLoading = true
        
        if isSignUp {
            authManager.createAccountWithEmail(email: email, password: password) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success:
                        // Success handled by auth state listener
                        break
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        } else {
            authManager.signInWithEmail(email: email, password: password) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success:
                        // Success handled by auth state listener
                        break
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func handleAppleLogin() {
        isLoading = true
        
        // Generate nonce first
        let nonce = authManager.generateNonce()
        
        // Create the Apple ID provider request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        let delegate = AppleSignInDelegate(
            onSuccess: { credential in
                DispatchQueue.main.async {
                    self.authManager.signInWithApple(credential: credential) { result in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            switch result {
                            case .success:
                                // Success handled by auth state listener
                                break
                            case .failure(let error):
                                self.errorMessage = error.localizedDescription
                                self.showError = true
                            }
                        }
                    }
                }
            },
            onFailure: { error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    // Provide more specific error messages
                    let errorMessage: String
                    if let authError = error as? ASAuthorizationError {
                        switch authError.code {
                        case .canceled:
                            errorMessage = "Apple Sign-In was canceled"
                        case .failed:
                            errorMessage = "Apple Sign-In failed. Please try again."
                        case .invalidResponse:
                            errorMessage = "Invalid response from Apple. Please try again."
                        case .notHandled:
                            errorMessage = "Apple Sign-In request not handled. Please try again."
                        case .unknown:
                            errorMessage = "Unknown error occurred. Please try again."
                        @unknown default:
                            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                    }
                    
                    self.errorMessage = errorMessage
                    self.showError = true
                }
            }
        )
        
        let presentationContextProvider = AppleSignInPresentationContextProvider()
        
        // Store references to prevent deallocation
        self.appleSignInDelegate = delegate
        self.appleSignInPresentationContextProvider = presentationContextProvider
        
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = presentationContextProvider
        
        // Perform the request
        authorizationController.performRequests()
    }
    
    private func handleGoogleLogin() {
        isLoading = true
        
        authManager.signInWithGoogle { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success:
                    // Success handled by auth state listener
                    break
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
    }
}

// MARK: - Apple Sign-In Delegates
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let onSuccess: (ASAuthorizationAppleIDCredential) -> Void
    let onFailure: (Error) -> Void
    
    init(onSuccess: @escaping (ASAuthorizationAppleIDCredential) -> Void, onFailure: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            onSuccess(appleIDCredential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailure(error)
    }
}

class AppleSignInPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use the key window approach which is more reliable
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        // Fallback to first available window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        
        // Last resort - use the main window (iOS 15+ compatible)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        
        // Final fallback
        return UIWindow()
    }
}

#Preview {
    LoginView()
}
