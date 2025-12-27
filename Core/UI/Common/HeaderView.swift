import AuthenticationServices
import FirebaseAuth
import SwiftUI
import UIKit

struct HeaderView: View {
  let onCreateHabit: () -> Void
  let onStreakTap: () -> Void
  let onNotificationTap: () -> Void
  let showProfile: Bool
  let currentStreak: Int

  @EnvironmentObject var authManager: AuthenticationManager
  @EnvironmentObject var vacationManager: VacationManager
  @ObservedObject private var avatarManager = AvatarManager.shared
  @ObservedObject private var subscriptionManager = SubscriptionManager.shared
  @State private var showingProfileView = false
  @State private var showingSubscriptionView = false
  @State private var guestName: String = ""

  var body: some View {
    // Removed verbose debug logging - HeaderView renders frequently
    return VStack(spacing: 0) {
      HStack(spacing: 0) {
      if showProfile {
        // Profile section for More tab
        HStack(spacing: 12) {
          // Profile picture
          Group {
            if avatarManager.selectedAvatar.isCustomPhoto,
               let imageData = avatarManager.selectedAvatar.customPhotoData,
               let uiImage = UIImage(data: imageData)
            {
              Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
            } else {
              Image(avatarManager.selectedAvatar.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
            }
          }
          .frame(width: 56, height: 56)
          .clipShape(Circle())

          VStack(alignment: .leading, spacing: 2) {
            if isLoggedIn {
              // User is logged in - show profile info
              Text(greetingText)
                .font(.appHeadlineMediumEmphasised)
                .foregroundColor(.white)
                .id("greeting-\(authManager.currentUser?.displayName ?? "none")") // Force refresh when displayName changes

              // View Profile button with chevron
              Button(action: {
                showingProfileView = true
              }) {
                HStack(spacing: 4) {
                  Text("View Profile")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)

                  Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                }
              }
            } else {
              // User is not logged in - show greeting with name if available
              Text(greetingText)
                .font(.appHeadlineMediumEmphasised)
                .foregroundColor(.white)
                .id("greeting-guest-\(guestName)") // Force refresh when guest name changes

              // View Profile button with chevron (leads to profile)
              Button(action: {
                showingProfileView = true
              }) {
                HStack(spacing: 4) {
                  Text("View Profile")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)

                  Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                }
              }
            }
          }
          
          Spacer()
          
          // Sign Up/In button for guest mode
          if !isLoggedIn {
            Button(action: {
              handleSignInWithApple()
            }) {
              Text("Sign Up/In")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                  RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                      RoundedRectangle(cornerRadius: 20)
                        .stroke(
                          LinearGradient(
                            stops: [
                              .init(color: Color.white.opacity(0.4), location: 0.0),
                              .init(color: Color.white.opacity(0.1), location: 0.5),
                              .init(color: Color.white.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ),
                          lineWidth: 1.5
                        )
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      } else {
        // Streak pill with advanced glass effect
        Button(action: onStreakTap) {
          HStack(spacing: 6) {
            // Show frozen fire icon when vacation mode is active
            if VacationManager.shared.isActive {
              Image("Icon-fire-frozen")
                .resizable()
                .frame(width: 24, height: 24)
            } else {
              Image(.iconFire)
                .resizable()
                .frame(width: 24, height: 24)
            }
            Text(pluralizeStreak(currentStreak))
              .font(.appTitleMediumEmphasised)
              .foregroundColor(.white)
          }
          .padding(.horizontal, 12)
          .frame(height: 36)
          .background {
            // iOS glass effect using Material
            RoundedRectangle(cornerRadius: 24)
              .fill(.ultraThinMaterial)
              .overlay {
                // Liquid glass effect with gradient opacity stroke
                RoundedRectangle(cornerRadius: 24)
                  .stroke(
                    LinearGradient(
                      stops: [
                        .init(color: Color.white.opacity(0.4), location: 0.0),  // Top-left: stronger
                        .init(color: Color.white.opacity(0.1), location: 0.5),  // Center: weaker
                        .init(color: Color.white.opacity(0.4), location: 1.0)   // Bottom-right: stronger
                      ],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                  )
              }
          }
        }
        .padding(.vertical, 6)  // Maintain 48pt touch target (36pt visual + 6pt top + 6pt bottom)
        .buttonStyle(PlainButtonStyle())
      }

      Spacer()

      if showProfile {
        // Profile button - sign-in functionality removed
      } else {
        // Crown button and Add button with advanced glass effect
        HStack(spacing: 12) {
          // Crown button for subscription - only show for free users
          // CRITICAL: Use .id() to force view recreation when isPremium changes
          if !subscriptionManager.isPremium {
            #if DEBUG
            let _ = print("🔍 HeaderView: Showing crown icon - isPremium: \(subscriptionManager.isPremium)")
            #endif
            Button(action: {
              showingSubscriptionView = true
            }) {
              Image("Icon-crown_Filled")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(Color(hex: "FCD884"))
            }
            .frame(width: 32, height: 32)
            .background {
              // iOS glass effect using Material
              Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                  // Liquid glass effect with gradient opacity stroke
                  Circle()
                    .stroke(
                      LinearGradient(
                        stops: [
                          .init(color: Color.white.opacity(0.4), location: 0.0),  // Top-left: stronger
                          .init(color: Color.white.opacity(0.1), location: 0.5),  // Center: weaker
                          .init(color: Color.white.opacity(0.4), location: 1.0)   // Bottom-right: stronger
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 1.5
                    )
                }
            }
            .id("crown-\(subscriptionManager.isPremium)") // Force recreation when isPremium changes
          }
          
          // Add icon with advanced glass effect
          Button(action: onCreateHabit) {
            Image(systemName: "plus")
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(.white)
          }
          .frame(width: 32, height: 32)
          .background {
            // iOS glass effect using Material
            Circle()
              .fill(.ultraThinMaterial)
              .overlay {
                // Liquid glass effect with gradient opacity stroke
                Circle()
                  .stroke(
                    LinearGradient(
                      stops: [
                        .init(color: Color.white.opacity(0.4), location: 0.0),  // Top-left: stronger
                        .init(color: Color.white.opacity(0.1), location: 0.5),  // Center: weaker
                        .init(color: Color.white.opacity(0.4), location: 1.0)   // Bottom-right: stronger
                      ],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                  )
              }
          }
        }
      }
      }
    }
    .padding(.leading, 20)
    .padding(.trailing, 16)
    .padding(.top, 8)
    .padding(.bottom, 24)
    .background(.headerBackground)
    // CRITICAL: Force view to observe isPremium changes by using it in .id()
    .id("header-premium-\(subscriptionManager.isPremium)")
    .sheet(isPresented: $showingProfileView) {
      AccountView()
    }
    .onAppear {
      loadGuestName()
    }
    .onChange(of: showingProfileView) { _, isShowing in
      // Reload guest name when profile view is dismissed
      if !isShowing {
        loadGuestName()
      }
    }
    .sheet(isPresented: $showingSubscriptionView) {
      SubscriptionView()
    }
  }

  // MARK: - Computed Properties

  private var isLoggedIn: Bool {
    switch authManager.authState {
    case .authenticated(let user):
      // ✅ FIX: Show login button if user is anonymous (not truly logged in)
      // Check if Firebase user is anonymous
      if let firebaseUser = user as? User, firebaseUser.isAnonymous {
        return false  // Anonymous users should see login button
      }
      return true  // Real authenticated users (email, Google, Apple)
    case .error,
         .unauthenticated:
      return false
    case .authenticating:
      return false
    }
  }

  private var greetingText: String {
    if isLoggedIn, let user = authManager.currentUser {
      if let displayName = user.displayName, !displayName.isEmpty {
        // Extract first name from display name
        let firstName = displayName.components(separatedBy: " ").first ?? displayName
        // Only show first name if it's not empty (user has entered a name)
        if !firstName.isEmpty && firstName.trimmingCharacters(in: .whitespaces) != "" {
          return "Hi \(firstName),"
        }
      }
      // For signed-in users without a first name, show "Hi there,"
      return "Hi there,"
    }
    // For guest users, check if they have a saved name
    if !guestName.isEmpty {
      let firstName = guestName.components(separatedBy: " ").first ?? guestName
      if !firstName.isEmpty && firstName.trimmingCharacters(in: .whitespaces) != "" {
        return "Hi \(firstName),"
      }
    }
    // Default greeting for guest users without a name
    return "Hi there,"
  }

  // MARK: - Helper Methods

  private func loadGuestName() {
    if let savedName = UserDefaults.standard.string(forKey: "GuestName"),
       !savedName.isEmpty
    {
      guestName = savedName
    } else {
      guestName = ""
    }
  }

  private func pluralizeStreak(_ streak: Int) -> String {
    if streak == 0 {
      "0 day"
    } else if streak == 1 {
      "1 day"
    } else {
      "\(streak) days"
    }
  }
  
  private func handleSignInWithApple() {
    print("🍎 [HeaderView] Sign in with Apple button tapped")
    
    // Get the authorization request from AuthenticationManager
    let request = authManager.startSignInWithApple()
    
    // Create and store delegate and presentation context provider to prevent deallocation
    let delegate = HeaderSignInWithAppleDelegate(authManager: authManager)
    let presentationContextProvider = HeaderPresentationContextProvider()
    
    // Create authorization controller
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = delegate
    controller.presentationContextProvider = presentationContextProvider
    
    // Store them to prevent deallocation
    signInDelegate = delegate
    signInPresentationContextProvider = presentationContextProvider
    signInController = controller
    
    // Perform the request
    controller.performRequests()
  }
  
  @State private var signInDelegate: HeaderSignInWithAppleDelegate?
  @State private var signInPresentationContextProvider: HeaderPresentationContextProvider?
  @State private var signInController: ASAuthorizationController?
}

// MARK: - Header Sign In Helper Classes

private class HeaderSignInWithAppleDelegate: NSObject, ASAuthorizationControllerDelegate {
  let authManager: AuthenticationManager
  
  init(authManager: AuthenticationManager) {
    self.authManager = authManager
  }
  
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization)
  {
    print("🍎 [HeaderView] Authorization completed successfully")
    Task { @MainActor in
      await authManager.handleSignInWithApple(result: .success(authorization))
    }
  }
  
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error)
  {
    print("🍎 [HeaderView] Authorization failed: \(error.localizedDescription)")
    Task { @MainActor in
      await authManager.handleSignInWithApple(result: .failure(error))
    }
  }
}

private class HeaderPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
      fatalError("No window found for Sign in with Apple presentation")
    }
    return window
  }
}
