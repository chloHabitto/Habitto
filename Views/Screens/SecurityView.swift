import SwiftUI

// import FirebaseAuth // Temporarily commented out due to package dependency issues

struct SecurityView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var showingPersonalInformation = false
  @State private var showingDeleteAccountConfirmation = false
  @State private var showingSignOutAlert = false

  /// Computed property to check if user can change password
  private var canChangePassword: Bool {
    // Temporarily disabled due to Firebase dependency issues
    false
    // guard let firebaseUser = Auth.auth().currentUser,
    //       let providerData = firebaseUser.providerData.first else {
    //     return false
    // }
    // return providerData.providerID == "password"
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Scrollable content
        ScrollView {
          VStack(spacing: 24) {
            // Description text
            Text("Manage your account settings and security")
              .font(.appBodyMedium)
              .foregroundColor(.text05)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 20)
              .padding(.top, 8)

            // Account Options
            VStack(spacing: 0) {
              // Personal Information
              AccountOptionRow(
                icon: "Icon-Profile_Filled",
                title: "Personal Information",
                subtitle: "Manage your personal details",
                hasChevron: true,
                iconColor: .navy200)
              {
                showingPersonalInformation = true
              }

              Divider()
                .padding(.leading, 56)

              // Password Management - Only show for email/password users
              if canChangePassword {
                AccountOptionRow(
                  icon: "Icon-ShieldKeyhole_Filled",
                  title: "Change Password",
                  subtitle: "Update your account password",
                  hasChevron: true)
                {
                  // TODO: Implement change password functionality
                }
              } else {
                // Show info for OAuth users (Google/Apple)
                HStack(spacing: 12) {
                  Image("Icon-LockKeyhold_Filled")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.navy200)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("Password Management")
                      .font(.appBodyLarge)
                      .foregroundColor(.text01)

                    Text("Password changes are managed through your sign-in provider")
                      .font(.appBodySmall)
                      .foregroundColor(.text03)
                  }

                  Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
              }
            }
            .background(Color.surface)
            .cornerRadius(16)
            .padding(.horizontal, 20)
          }
          .padding(.horizontal, 0)
          .padding(.top, 0)
          .padding(.bottom, 20)
        }

        // Fixed bottom section with buttons
        VStack(spacing: 16) {
          // Sign Out Section
          VStack(spacing: 0) {
            HabittoButton(
              size: .large,
              style: .fillTertiary,
              content: .text("Sign Out"),
              action: {
                showingSignOutAlert = true
              })
          }
          .background(Color.surface)
          .cornerRadius(16)
          .padding(.horizontal, 20)

          // Delete Account Section
          VStack(spacing: 0) {
            HabittoButton(
              size: .large,
              style: .fillDestructive,
              content: .text("Delete Account"),
              action: {
                print("🗑️ SecurityView: Delete Account button tapped")
                showingDeleteAccountConfirmation = true
                print(
                  "🗑️ SecurityView: showingDeleteAccountConfirmation set to \(showingDeleteAccountConfirmation)")
              })
          }
          .background(Color.surface)
          .cornerRadius(16)
          .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
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
    .sheet(isPresented: $showingPersonalInformation) {
      PersonalInformationView()
    }
    .sheet(isPresented: $showingDeleteAccountConfirmation) {
      print("🗑️ SecurityView: Presenting AccountDeletionConfirmationView")
      return AccountDeletionConfirmationView()
    }
    .alert("Sign Out", isPresented: $showingSignOutAlert) {
      Button("Cancel", role: .cancel) { }
      Button("Sign Out", role: .destructive) {
        authManager.signOut()
        dismiss()
      }
    } message: {
      Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
    }
  }
}

#Preview {
  SecurityView()
}
