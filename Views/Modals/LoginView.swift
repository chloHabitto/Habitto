import AuthenticationServices
import CryptoKit
import FirebaseAuth
import SwiftUI

// MARK: - LoginField

enum LoginField {
  case email
  case password
}

// MARK: - LoginView

struct LoginView: View {
  // MARK: Internal

  var body: some View {
    NavigationView {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            headerSection
            Spacer(minLength: 40)
            formSection
            Spacer(minLength: 40)
          }
        }
        .background(Color.surface)
        .onChange(of: focusedField) { oldValue, newValue in
          // Scroll to focused field when keyboard appears
          if let field = newValue {
            withAnimation(.easeInOut(duration: 0.3)) {
              switch field {
              case .email:
                proxy.scrollTo("email", anchor: .center)
              case .password:
                proxy.scrollTo("password", anchor: .center)
              }
            }
            
            // Also ensure Sign In button is visible after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("signInButton", anchor: .bottom)
              }
            }
          }
        }
      }
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
        case .authenticated(let user):
          // ✅ FIX: Only dismiss if user is NOT anonymous (real email/Google/Apple account)
          // Anonymous users should stay on login screen to sign up
          if let firebaseUser = user as? User, !firebaseUser.isAnonymous {
            // Real authenticated user - dismiss login screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              dismiss()
            }
          }
          // If anonymous, don't dismiss - let them sign up

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

  // MARK: Private

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
  
  // Focus state for keyboard-aware scrolling
  @FocusState private var focusedField: LoginField?

  // Store delegates to prevent deallocation
  @State private var appleSignInDelegate: AppleSignInDelegate?
  @State private var appleSignInPresentationContextProvider: AppleSignInPresentationContextProvider?

  private var isFormValid: Bool {
    if isSignUp {
      // For sign up: require email format validation and password requirements
      !email.isEmpty && !password.isEmpty && authManager.isValidEmail(email) && authManager
        .isValidPassword(password)
    } else {
      // For sign in: only require both fields to be filled and valid email format
      !email.isEmpty && !password.isEmpty && authManager.isValidEmail(email)
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
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
  }

  // MARK: - Form Section

  private var formSection: some View {
    VStack(spacing: 20) {
      emailField
      
      // Password field and requirements grouped with 8pt spacing
      VStack(spacing: 8) {
        passwordField
        passwordRequirements
      }
      
      forgotPasswordButton
      signInButton
      toggleSignUpButton
      dividerSection
      socialLoginButtons
    }
    .padding(.horizontal, 24)
  }

  // MARK: - Email Field

  private var emailField: some View {
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
        .focused($focusedField, equals: .email)
        .id("email")
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.outline2, lineWidth: 1))
    }
  }

  // MARK: - Password Field

  private var passwordField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Password")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.text01)

      HStack {
        if showPassword {
          TextField("Enter your password", text: $password)
            .textFieldStyle(CustomTextFieldStyle())
            .textContentType(isSignUp ? .newPassword : .password)
            .focused($focusedField, equals: .password)
        } else {
          SwiftUI.SecureField("Enter your password", text: $password)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .focused($focusedField, equals: .password)
        }

        Button(action: {
          showPassword.toggle()
        }) {
          Image(systemName: showPassword ? "eye.slash" : "eye")
            .foregroundColor(.text04)
            .frame(width: 44, height: 44)
        }
      }
      .id("password")
      .background(Color.white)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.outline2, lineWidth: 1))
    }
  }

  // MARK: - Password Requirements

  private var passwordRequirements: some View {
    Group {
      if isSignUp {
        VStack(alignment: .leading, spacing: 8) {
          Text("Password Requirements:")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.text02)

          VStack(alignment: .leading, spacing: 4) {
            PasswordRequirementRow(
              text: "At least 8 characters",
              isMet: password.count >= 8)
            PasswordRequirementRow(
              text: "One uppercase letter",
              isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil)
            PasswordRequirementRow(
              text: "One lowercase letter",
              isMet: password.range(of: "[a-z]", options: .regularExpression) != nil)
            PasswordRequirementRow(
              text: "One number",
              isMet: password.range(of: "\\d", options: .regularExpression) != nil)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("navy50").opacity(0.5))
        .cornerRadius(12)
      }
    }
  }

  // MARK: - Forgot Password Button

  private var forgotPasswordButton: some View {
    Group {
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
    }
  }

  // MARK: - Sign In Button

  private var signInButton: some View {
    HabittoButton(
      size: .large,
      style: .fillPrimary,
      content: .text(isLoading ? "Please wait..." : (isSignUp ? "Create Account" : "Sign In")),
      hugging: false)
    {
      handleEmailAuth()
    }
    .disabled(!isFormValid || isLoading)
    .id("signInButton")
  }

  // MARK: - Toggle Sign Up Button

  private var toggleSignUpButton: some View {
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
  }

  // MARK: - Divider Section

  private var dividerSection: some View {
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
  }

  // MARK: - Social Login Buttons

  private var socialLoginButtons: some View {
    VStack(spacing: 16) {
      appleLoginButton
      googleLoginButton
    }
  }

  // MARK: - Apple Login Button

  private var appleLoginButton: some View {
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
  }

  // MARK: - Google Login Button

  private var googleLoginButton: some View {
    Button(action: handleGoogleLogin) {
      HStack(spacing: 12) {
        Image("GoogleLogo")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 20, height: 20)

        Text("Continue with Google")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(Color(hex: "#1F1F1F"))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(Color.white)
      .cornerRadius(28)
      .overlay(
        RoundedRectangle(cornerRadius: 28)
          .stroke(Color(hex: "#747775"), lineWidth: 1)
      )
    }
    .disabled(isLoading)
  }

  // MARK: - Authentication Handlers

  private func handleEmailAuth() {
    isLoading = true

    if isSignUp {
      authManager.createAccountWithEmail(email: email, password: password) { result in
        DispatchQueue.main.async {
          isLoading = false
          switch result {
          case .success:
            // Success handled by auth state listener
            break
          case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
          }
        }
      }
    } else {
      authManager.signInWithEmail(email: email, password: password) { result in
        DispatchQueue.main.async {
          isLoading = false
          switch result {
          case .success:
            // Success handled by auth state listener
            break
          case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
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
          authManager.signInWithApple(credential: credential, nonce: nonce) { result in
            DispatchQueue.main.async {
              isLoading = false
              switch result {
              case .success:
                // Success handled by auth state listener
                break
              case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
              }
            }
          }
        }
      },
      onFailure: { error in
        DispatchQueue.main.async {
          isLoading = false

          // Provide more specific error messages
          let errorMessage = if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
              "Apple Sign-In was canceled"
            case .failed:
              "Apple Sign-In failed. Please try again."
            case .invalidResponse:
              "Invalid response from Apple. Please try again."
            case .notHandled:
              "Apple Sign-In request not handled. Please try again."
            case .unknown:
              "Unknown error occurred. Please try again."
            case .notInteractive:
              "Apple Sign-In requires user interaction. Please try again."
            case .matchedExcludedCredential:
              "Credential already exists. Please try a different account."
            case .credentialImport:
              "Credential import failed. Please try again."
            case .credentialExport:
              "Credential export failed. Please try again."
            default:
              "Apple Sign-In failed: \(error.localizedDescription)"
            }
          } else {
            "Apple Sign-In failed: \(error.localizedDescription)"
          }

          self.errorMessage = errorMessage
          showError = true
        }
      })

    let presentationContextProvider = AppleSignInPresentationContextProvider()

    // Store references to prevent deallocation
    appleSignInDelegate = delegate
    appleSignInPresentationContextProvider = presentationContextProvider

    authorizationController.delegate = delegate
    authorizationController.presentationContextProvider = presentationContextProvider

    // Perform the request
    authorizationController.performRequests()
  }

  private func handleGoogleLogin() {
    isLoading = true

    authManager.signInWithGoogle { result in
      DispatchQueue.main.async {
        isLoading = false
        switch result {
        case .success:
          // Success handled by auth state listener
          break
        case .failure(let error):
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }
}

// MARK: - CustomTextFieldStyle

struct CustomTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
  }
}

// MARK: - AppleSignInDelegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
  // MARK: Lifecycle

  init(
    onSuccess: @escaping (ASAuthorizationAppleIDCredential) -> Void,
    onFailure: @escaping (Error) -> Void)
  {
    self.onSuccess = onSuccess
    self.onFailure = onFailure
  }

  // MARK: Internal

  let onSuccess: (ASAuthorizationAppleIDCredential) -> Void
  let onFailure: (Error) -> Void

  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization)
  {
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
      onSuccess(appleIDCredential)
    }
  }

  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithError error: Error)
  {
    onFailure(error)
  }
}

// MARK: - AppleSignInPresentationContextProvider

class AppleSignInPresentationContextProvider: NSObject,
  ASAuthorizationControllerPresentationContextProviding
{
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    // Use the key window approach which is more reliable
    if let keyWindow = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })
    {
      return keyWindow
    }

    // Fallback to first available window
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first
    {
      return window
    }

    // Last resort - use the main window (iOS 15+ compatible)
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first
    {
      return window
    }

    // Final fallback
    return UIWindow()
  }
}

// MARK: - PasswordRequirementRow

struct PasswordRequirementRow: View {
  let text: String
  let isMet: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
        .foregroundColor(isMet ? .green : .gray)
        .font(.system(size: 14))

      Text(text)
        .font(.system(size: 12, weight: .regular))
        .foregroundColor(isMet ? .text01 : .text04)
    }
  }
}

#Preview {
  LoginView()
}
