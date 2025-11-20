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
                // Description text
                Text("Manage your account preferences")
                  .font(.appBodyMedium)
                  .foregroundColor(.text05)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 20)
                  .padding(.top, 8)
                
                // DISABLED: Sign-in functionality commented out for future use
                /*
                // Personal Information Section
                VStack(spacing: 0) {
                  AccountOptionRow(
                    icon: "Icon-Profile_Filled",
                    title: "Personal Information",
                    subtitle: "Manage your personal details",
                    hasChevron: true,
                    iconColor: .navy200)
                  {
                    showingPersonalInformation = true
                  }
                }
                */
                .background(Color.surface)
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Developer Tools Section (DEBUG only)
                #if DEBUG
                VStack(spacing: 0) {
                  AccountOptionRow(
                    icon: "ant.circle.fill",
                    title: "Debug User Statistics",
                    subtitle: "View database and user state analysis",
                    hasChevron: true,
                    iconColor: .orange)
                  {
                    Task {
                      await HabitRepository.shared.debugUserStats()
                      showingDebugAlert = true
                    }
                  }
                  
                  Divider()
                    .padding(.leading, 56)
                  
                  AccountOptionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Migration Debug",
                    subtitle: "Test data migration system",
                    hasChevron: true,
                    iconColor: .blue)
                  {
                    showingMigrationDebug = true
                  }
                  
                  Divider()
                    .padding(.leading, 56)
                  
                  AccountOptionRow(
                    icon: "flag.fill",
                    title: "Feature Flags",
                    subtitle: "Toggle new architecture features",
                    hasChevron: true,
                    iconColor: .green)
                  {
                    showingFeatureFlags = true
                  }
                }
                .background(Color.surface)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                #endif

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
                  showingDeleteAccountConfirmation = true
                })
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .background(Color.surface2)
          }
        } else {
          // DISABLED: Sign-in functionality commented out for future use
          /*
          // Guest mode - simple text prompt with sign in button
            VStack(spacing: 24) {
            Spacer()
            
            Text("Sign in or sign up to access your account")
              .font(.appBodyLarge)
                  .foregroundColor(.text01)
                  .multilineTextAlignment(.center)
              .padding(.horizontal, 40)

              HabittoButton(
                size: .large,
                style: .fillPrimary,
                content: .text("Sign In"),
                action: {
                  showingLoginView = true
                })
                .padding(.horizontal, 20)

            Spacer()
          }
          */
          // Guest mode - empty state
          VStack(spacing: 24) {
            Spacer()
            Text("Account features are currently unavailable")
              .font(.appBodyLarge)
              .foregroundColor(.text01)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
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
    // DISABLED: Sign-in functionality commented out for future use
    /*
    .sheet(isPresented: $showingLoginView) {
      LoginView()
    }
    .sheet(isPresented: $showingPersonalInformation) {
      PersonalInformationView()
    }
    */
    .sheet(isPresented: $showingDeleteAccountConfirmation) {
      AccountDeletionConfirmationView()
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
    .alert("Debug Report Generated", isPresented: $showingDebugAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("Check the Xcode console to see the detailed user statistics report.")
    }
    .sheet(isPresented: $showingMigrationDebug) {
      NavigationStack {
        MigrationDebugView()
      }
    }
    .sheet(isPresented: $showingFeatureFlags) {
      NavigationStack {
        FeatureFlagsDebugView()
      }
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss

  // State variables for showing different screens
  @State private var showingDataPrivacy = false
  @State private var showingLoginView = false
  @State private var showingPersonalInformation = false
  @State private var showingSignOutAlert = false
  @State private var showingDeleteAccountConfirmation = false
  @State private var showingDebugAlert = false
  @State private var showingMigrationDebug = false
  @State private var showingFeatureFlags = false

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
