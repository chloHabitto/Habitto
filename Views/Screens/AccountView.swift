import SwiftUI
import FirebaseAuth

// MARK: - AccountView

struct AccountView: View {
  // MARK: Internal

  @EnvironmentObject var authManager: AuthenticationManager

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Main content area
        if isLoggedIn {
          // Account Options for authenticated users
          VStack(spacing: 0) {
            ScrollView {
              VStack(spacing: 24) {
                // Signed in status section
                signedInStatusSection

                Spacer(minLength: 40)
              }
              .padding(.bottom, 20)
            }

            // Account Actions Section - Fixed at bottom
            VStack(spacing: 16) {
              // Sign Out Button
              HabittoButton(
                size: .large,
                style: .fillTertiary,
                content: .text("Sign Out"),
                action: {
                  showingSignOutAlert = true
                })

              // Delete Account Button
              HabittoButton(
                size: .large,
                style: .fillDestructive,
                content: .text("Delete Account"),
                action: {
                  showingDeleteAccountAlert = true
                })
                .disabled(isDeletingAccount)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
          }
        } else {
          // Guest mode - Sign in with Apple
          VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
              // Icon
              Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.text04)
              
              // Title
              Text("Sign in to sync across devices")
                .font(.appTitleLarge)
                .foregroundColor(.text01)
                .multilineTextAlignment(.center)
              
              // Description
              Text("Sign in with Apple to enable cross-device sync and keep your habits safe in the cloud.")
                .font(.appBodyMedium)
                .foregroundColor(.text03)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
              
              // Sign in with Apple button
              SignInWithAppleButton()
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            
            Spacer()
          }
        }
      }
      .background(Color.surface2)
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.text01)
          }
        }
      }
    }
    .sheet(isPresented: $showingDataPrivacy) {
      DataPrivacyView()
    }
    .alert("Sign Out", isPresented: $showingSignOutAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Sign Out", role: .destructive) {
        authManager.signOut()
        dismiss()
      }
    } message: {
      Text("Are you sure you want to sign out?")
    }
    .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Delete Account", role: .destructive) {
        Task {
          await performAccountDeletion()
        }
      }
    } message: {
      Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.")
    }
    .alert("Deletion Error", isPresented: $showingDeletionError) {
      Button("OK") {
        deletionError = nil
        showingDeletionError = false
      }
    } message: {
      Text(deletionError ?? "An unknown error occurred")
    }
    .alert("Account Deleted", isPresented: $showingDeletionSuccess) {
      Button("OK") {
        dismiss()
      }
    } message: {
      Text("Your account has been deleted successfully. You have been signed out.")
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  // State variables for showing different screens
  @State private var showingDataPrivacy = false
  @State private var showingSignOutAlert = false
  @State private var showingDeleteAccountAlert = false
  @State private var isDeletingAccount = false
  @State private var deletionError: String?
  @State private var showingDeletionError = false
  @State private var showingDeletionSuccess = false
  
  @StateObject private var deletionService = AccountDeletionService()

  // Signed in status section
  private var signedInStatusSection: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        // Checkmark icon
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 24))
          .foregroundColor(.green)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Signed in with Apple")
            .font(.appBodyLarge)
            .fontWeight(.semibold)
            .foregroundColor(.text01)
          
          Text("Your habits sync across all your devices")
            .font(.appBodySmall)
            .foregroundColor(.text03)
        }
        
        Spacer()
      }
    }
    .padding(20)
    .background(Color.surface)
    .cornerRadius(16)
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }

  private var isLoggedIn: Bool {
    switch authManager.authState {
    case .authenticated(let user):
      // ✅ FIX: Show guest view if user is anonymous (not truly logged in)
      // Check if Firebase user is anonymous
      if let firebaseUser = user as? User, firebaseUser.isAnonymous {
        return false  // Anonymous users should see guest view
      }
      return true  // Real authenticated users (email, Google, Apple)
    case .authenticating,
         .error,
         .unauthenticated:
      return false
    }
  }
  
  private func performAccountDeletion() async {
    isDeletingAccount = true
    deletionError = nil
    
    // Check if re-authentication is needed
    let isAuthFresh = await deletionService.checkAuthenticationFreshness()
    if !isAuthFresh {
      await MainActor.run {
        deletionError = "Your authentication session has expired. Please sign out and sign in again, then try deleting your account."
        showingDeletionError = true
        isDeletingAccount = false
      }
      return
    }
    
    do {
      try await deletionService.deleteAccount()
      
      // Mark deletion as successful
      await MainActor.run {
        isDeletingAccount = false
        showingDeletionSuccess = true
      }
      
      // Sign out after successful deletion
      await MainActor.run {
        authManager.signOut()
      }
      
    } catch {
      print("❌ AccountView: Account deletion failed: \(error)")
      
      await MainActor.run {
        deletionError = error.localizedDescription
        showingDeletionError = true
        isDeletingAccount = false
      }
    }
  }
}

// MARK: - AccountOptionRow

struct AccountOptionRow: View {
  // MARK: Lifecycle

  init(
    icon: String,
    title: String,
    subtitle: String,
    hasChevron: Bool,
    iconColor: Color = .navy200,
    action: @escaping () -> Void)
  {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
    self.hasChevron = hasChevron
    self.iconColor = iconColor
    self.action = action
  }

  // MARK: Internal

  let icon: String
  let title: String
  let subtitle: String
  let hasChevron: Bool
  let iconColor: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if icon.hasPrefix("Icon-") {
          // Custom icon
          Image(icon)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(iconColor)
        } else {
          // System icon
          Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(iconColor)
            .frame(width: 24)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.appBodyLarge)
            .foregroundColor(.text01)

          Text(subtitle)
            .font(.appBodySmall)
            .foregroundColor(.text03)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if hasChevron {
          Image(systemName: "chevron.right")
            .font(.system(size: 16))
            .foregroundColor(.text03)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
  }
}

#Preview {
  AccountView()
    .environmentObject(AuthenticationManager.shared)
}
