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

  var body: some View {
    let _ = {
      #if DEBUG
      print("🔍 HeaderView rendering - isPremium: \(subscriptionManager.isPremium)")
      #endif
    }()
    
    return VStack(spacing: 0) {
      // DEBUG: Visual indicator of isPremium state
      #if DEBUG
      Text("DEBUG: isPremium = \(subscriptionManager.isPremium)")
        .foregroundColor(.red)
        .font(.caption)
        .padding(.top, 4)
      #endif
      
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
              // User is not logged in - show login prompt
              Text("Hi there,")
                .font(.appHeadlineMediumEmphasised)
                .foregroundColor(.white)

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
              .font(.appButtonText1)
              .foregroundColor(.white)
          }
          .padding(.horizontal, 12)
          .frame(height: 44)
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
            .frame(width: 36, height: 36)
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
          .frame(width: 36, height: 36)
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
    .padding(.top, 16)
    .padding(.bottom, 24)
    // CRITICAL: Force view to observe isPremium changes by using it in .id()
    .id("header-premium-\(subscriptionManager.isPremium)")
    .sheet(isPresented: $showingProfileView) {
      ProfileView()
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
    // Default greeting for guest users
    return "Hi there,"
  }

  // MARK: - Helper Methods

  private func pluralizeStreak(_ streak: Int) -> String {
    if streak == 0 {
      "0 day"
    } else if streak == 1 {
      "1 day"
    } else {
      "\(streak) days"
    }
  }
}
