import AuthenticationServices
import SwiftUI

// MARK: - SignInWithAppleButton

struct SignInWithAppleButton: View {
  // MARK: Internal

  @EnvironmentObject var authManager: AuthenticationManager
  @State private var authorizationController: ASAuthorizationController?
  @State private var delegate: SignInWithAppleDelegate?
  @State private var presentationContextProvider: PresentationContextProvider?

  var body: some View {
    Button(action: {
      handleSignInWithApple()
    }) {
      HStack(spacing: 12) {
        Image(systemName: "applelogo")
          .font(.system(size: 18, weight: .medium))
        
        Text("Sign in with Apple")
          .font(.system(size: 17, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(Color.black)
      .cornerRadius(12)
    }
  }

  // MARK: Private

  private func handleSignInWithApple() {
    print("🍎 [UI] Sign in with Apple button tapped")
    
    // Get the authorization request from AuthenticationManager
    let request = authManager.startSignInWithApple()
    
    // Create and store delegate and presentation context provider to prevent deallocation
    let newDelegate = SignInWithAppleDelegate(authManager: authManager)
    let newPresentationContextProvider = PresentationContextProvider()
    
    // Store them as state to prevent deallocation
    delegate = newDelegate
    presentationContextProvider = newPresentationContextProvider
    
    // Create authorization controller
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = newDelegate
    controller.presentationContextProvider = newPresentationContextProvider
    
    // Store controller to prevent deallocation
    authorizationController = controller
    
    // Perform the request
    controller.performRequests()
  }
}

// MARK: - SignInWithAppleDelegate

private class SignInWithAppleDelegate: NSObject, ASAuthorizationControllerDelegate {
  let authManager: AuthenticationManager
  
  init(authManager: AuthenticationManager) {
    self.authManager = authManager
  }
  
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization)
  {
    print("🍎 [UI] Authorization completed successfully")
    Task { @MainActor in
      await authManager.handleSignInWithApple(result: .success(authorization))
    }
  }
  
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error)
  {
    print("🍎 [UI] Authorization failed: \(error.localizedDescription)")
    Task { @MainActor in
      await authManager.handleSignInWithApple(result: .failure(error))
    }
  }
}

// MARK: - PresentationContextProvider

private class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
      fatalError("No window found for Sign in with Apple presentation")
    }
    return window
  }
}

