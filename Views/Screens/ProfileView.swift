import FirebaseAuth
import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
  // MARK: Internal

  @EnvironmentObject var authManager: AuthenticationManager

  var body: some View {
    NavigationView {
      ScrollView {
        ZStack {
          // Main Content
          VStack(spacing: 24) {
            // Profile Header
            VStack(spacing: 16) {
              // Profile Picture
              Button(action: {
                showingPhotoOptions = true
              }) {
                ZStack(alignment: .bottomTrailing) {
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
                  .frame(width: 80, height: 80)
                  .clipShape(Circle())
                  .overlay(
                    Circle()
                      .stroke(Color.primaryContainer, lineWidth: 3))
                  .onAppear {
                    print(
                      "🖼️ ProfileView: Displaying avatar: \(avatarManager.selectedAvatar.displayName) (ID: \(avatarManager.selectedAvatar.id))")
                  }

                  // Edit Icon
                  Image("Icon-pen")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primary)
                    .padding(2)
                    .background(Color.primaryContainer)
                    .clipShape(Circle())
                    .overlay(
                      Circle()
                        .stroke(Color.primaryContainer, lineWidth: 2))
                }
              }
              .buttonStyle(PlainButtonStyle())

              // Email display below profile image
              if !email.isEmpty {
                Text(email)
                  .font(.appBodyLarge)
                  .foregroundColor(.text02)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)

            // Name Fields
            VStack(spacing: 16) {
              // Name Field
              VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                  .font(.appBodyMedium)
                  .foregroundColor(.text01)

                TextField("Enter name", text: $firstName)
                  .font(.appBodyLarge)
                  .foregroundColor(.text01)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 16)
                  .background(Color.surface)
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.outline3, lineWidth: 1.5))
                  .cornerRadius(12)
                  .submitLabel(.done)
                  .onSubmit {
                    UIApplication.shared.sendAction(
                      #selector(UIResponder.resignFirstResponder),
                      to: nil,
                      from: nil,
                      for: nil)
                  }
              }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Save Button
            VStack(spacing: 16) {
              HabittoButton(
                size: .large,
                style: .fillPrimary,
                content: .text("Save"),
                hugging: false)
              {
                saveChanges()
              }
              .disabled(!hasChanges)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
          }
        }
      }
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .onAppear {
        loadUserData()
        // Debug: List all stored avatars
        avatarManager.debugListAllStoredAvatars()
      }
      .onChange(of: authManager.authState) { _, authState in
        handleAuthStateChange(authState)
      }
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
    .background(Color.surface2)
    .sheet(isPresented: $showingPhotoOptions) {
      PhotoOptionsBottomSheet(
        onClose: {
          showingPhotoOptions = false
        },
        onAvatarSelection: {
          showingAvatarSelection = true
        },
        onTakePhoto: {
          requestCameraPermissionAndOpen()
        },
        onChooseFromLibrary: {
          requestPhotoLibraryPermissionAndOpen()
        })
    }
    .sheet(isPresented: $showingAvatarSelection) {
      AvatarSelectionView()
        .onDisappear {
          print(
            "🔄 ProfileView: Avatar selection closed, current avatar: \(avatarManager.selectedAvatar.displayName)")
        }
    }
    .sheet(isPresented: $showingCamera) {
      if permissionManager.canUseCamera {
        CameraView { image in
          print("📸 ProfileView: Camera photo selected, updating avatar")
          avatarManager.selectCustomPhoto(image)
        }
      } else {
        VStack(spacing: 20) {
          Image(systemName: "camera.fill")
            .font(.system(size: 60))
            .foregroundColor(.text03)

          Text("Camera Not Available")
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Text("Camera is not available or permission is required.")
            .font(.appBodyMedium)
            .foregroundColor(.text02)
            .multilineTextAlignment(.center)

          Button("OK") {
            showingCamera = false
          }
          .font(.appLabelLarge)
          .foregroundColor(.primary)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(Color.primary.opacity(0.1))
          .cornerRadius(25)
        }
        .padding(40)
      }
    }
    .sheet(isPresented: $showingPhotoLibrary) {
      PhotoLibraryView { image in
        print("📷 ProfileView: Photo library image selected, updating avatar")
        avatarManager.selectCustomPhoto(image)
      }
    }
    .alert("Welcome!", isPresented: $showingMigrationAlert) {
      Button("Start Fresh") {
        avatarManager.clearGuestData()
        hasGuestData = false
      }
      Button("Keep My Data") {
        avatarManager.migrateGuestDataToUserAccount()
        hasGuestData = false
      }
    } message: {
      Text("We found some data from your guest session. Would you like to keep it or start fresh?")
    }
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var avatarManager = AvatarManager.shared
  @ObservedObject private var permissionManager = PermissionManager.shared

  @State private var firstName = ""
  @State private var email = ""
  @State private var isEditingProfile = false
  @State private var originalFirstName = ""
  @State private var originalEmail = ""
  @State private var showingPhotoOptions = false
  @State private var showingAvatarSelection = false
  @State private var showingCamera = false
  @State private var showingPhotoLibrary = false
  @State private var showingMigrationAlert = false
  @State private var hasGuestData = false

  private var isLoggedIn: Bool {
    switch authManager.authState {
    case .authenticated(let user):
      // Check if user is anonymous - anonymous users should be treated as guests
      if let firebaseUser = user as? User {
        return !firebaseUser.isAnonymous
      }
      return true
    case .authenticating,
         .error,
         .unauthenticated:
      return false
    }
  }

  private var hasChanges: Bool {
    firstName != originalFirstName
    // Email is no longer editable, so we don't check for email changes
  }

  // MARK: - Helper Functions

  private func requestCameraPermissionAndOpen() {
    if permissionManager.cameraPermissionStatus == .notDetermined {
      permissionManager.requestCameraPermission { granted in
        if granted {
          showingCamera = true
        }
      }
    } else {
      showingCamera = true
    }
  }

  private func requestPhotoLibraryPermissionAndOpen() {
    if permissionManager.photoLibraryPermissionStatus == .notDetermined {
      permissionManager.requestPhotoLibraryPermission { granted in
        if granted {
          showingPhotoLibrary = true
        }
      }
    } else {
      showingPhotoLibrary = true
    }
  }

  private func handleAuthStateChange(_ authState: AuthenticationState) {
    print("🔄 ProfileView: Auth state changed to: \(authState)")
    switch authState {
    case .authenticated(let user):
      // Check if user is anonymous - if so, treat as guest
      if let firebaseUser = user as? User, firebaseUser.isAnonymous {
        // Anonymous user = guest mode - clear fields
        print("👤 ProfileView: Anonymous user detected, clearing fields")
        firstName = ""
        email = ""
        originalFirstName = ""
        originalEmail = ""
      } else {
        // User logged in - check for guest data and show migration alert
        print("👤 ProfileView: User authenticated, checking for guest data")
        checkForGuestDataAndShowMigration()
        loadUserData()
      }

    case .authenticating,
         .error,
         .unauthenticated:
      // User logged out - clear all fields for guest mode
      print("👤 ProfileView: User not authenticated, clearing fields")
      firstName = ""
      email = ""
      originalFirstName = ""
      originalEmail = ""
    }
  }

  private func checkForGuestDataAndShowMigration() {
    // Check if there's guest data to migrate
    let guestData = UserDefaults.standard.data(forKey: "GuestSelectedAvatar")
    if guestData != nil, !hasGuestData {
      hasGuestData = true
      showingMigrationAlert = true
    } else {
      // No guest data, just migrate normally
      avatarManager.migrateGuestDataToUserAccount()
    }
  }

  private func loadUserData() {
    // Check if user is actually logged in (not anonymous/guest)
    if isLoggedIn, let user = authManager.currentUser {
      // Load display name directly as the name
      if let displayName = user.displayName,
         !displayName.isEmpty
      {
        firstName = displayName
      } else {
        firstName = ""
      }

      // Load email
      email = user.email ?? ""
    } else {
      // User not logged in or is anonymous/guest - load guest name from UserDefaults
      if let guestName = UserDefaults.standard.string(forKey: "GuestName"),
         !guestName.isEmpty
      {
        firstName = guestName
      } else {
        firstName = ""
      }
      email = ""
    }

    // Store original values for change detection
    originalFirstName = firstName
    originalEmail = email
  }

  private func saveChanges() {
    // Dismiss keyboard when Save button is tapped
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil)
    
    if isLoggedIn, let user = Auth.auth().currentUser {
      // Save for logged-in user - update Firebase display name
      let newDisplayName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
      
      // Capture current values before async operations
      let savedFirstName = firstName
      
      // Update display name using Firebase Auth
      let changeRequest = user.createProfileChangeRequest()
      changeRequest.displayName = newDisplayName.isEmpty ? nil : newDisplayName
      
      changeRequest.commitChanges { error in
        DispatchQueue.main.async {
          if let error = error {
            print("❌ Failed to update profile: \(error.localizedDescription)")
          } else {
            // Reload the user to get updated profile information
            user.reload { reloadError in
              DispatchQueue.main.async {
                if let reloadError = reloadError {
                  print("⚠️ Profile updated but failed to reload user: \(reloadError.localizedDescription)")
                } else {
                  print("✅ Profile updated and user reloaded successfully")
                  
                  // ✅ CRITICAL: Update authManager's currentUser to reflect the reloaded user
                  // This ensures HeaderView and other views see the updated displayName
                  if let reloadedUser = Auth.auth().currentUser {
                    authManager.currentUser = reloadedUser
                    print("✅ Updated authManager.currentUser with reloaded user (displayName: \(reloadedUser.displayName ?? "nil"))")
                  }
                }
                
                // Update original values to reflect saved state
                originalFirstName = savedFirstName
                
                // Reload user data to reflect changes (this will get the updated displayName)
                // Inline the logic since we can't call methods from closures in structs
                if isLoggedIn, let updatedUser = authManager.currentUser {
                  // Load display name directly as the name
                  if let displayName = updatedUser.displayName,
                     !displayName.isEmpty
                  {
                    firstName = displayName
                  } else {
                    firstName = ""
                  }
                  
                  // Update original values to match current values
                  originalFirstName = firstName
                }
              }
            }
          }
        }
      }
    } else {
      // Save for guest user - store in UserDefaults
      let guestName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
      UserDefaults.standard.set(guestName, forKey: "GuestName")
      print("✅ Guest name saved: \(guestName)")
      
      // Update original value to reflect saved state
      originalFirstName = firstName
    }
  }
}

// MARK: - PhotoOptionsBottomSheet

struct PhotoOptionsBottomSheet: View {
  let onClose: () -> Void
  let onAvatarSelection: () -> Void
  let onTakePhoto: () -> Void
  let onChooseFromLibrary: () -> Void

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Header
        HStack {
          Text("Change Profile Photo")
            .font(.appTitleMedium)
            .foregroundColor(.text01)

          Spacer()

          Button("Cancel") {
            onClose()
          }
          .font(.appBodyMedium)
          .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)

        Divider()

        // Photo Options
        VStack(spacing: 0) {
          // Avatar Option
          Button(action: {
            onClose()
            onAvatarSelection()
          }) {
            HStack {
              Image(systemName: "person.crop.circle")
                .font(.system(size: 24))
                .foregroundColor(.primary)
                .frame(width: 44)

              Text("Avatar")
                .font(.appBodyLarge)
                .foregroundColor(.text01)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundColor(.text03)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())

          Divider()
            .padding(.leading, 68)

          // Take Photo Option
          Button(action: {
            onClose()
            onTakePhoto()
          }) {
            HStack {
              Image(systemName: "camera")
                .font(.system(size: 24))
                .foregroundColor(.primary)
                .frame(width: 44)

              Text("Take a Photo")
                .font(.appBodyLarge)
                .foregroundColor(.text01)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundColor(.text03)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())

          Divider()
            .padding(.leading, 68)

          // Choose from Library Option
          Button(action: {
            onClose()
            onChooseFromLibrary()
          }) {
            HStack {
              Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(.text01)
                .frame(width: 44)

              Text("Choose from Library")
                .font(.appBodyLarge)
                .foregroundColor(.text01)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundColor(.text03)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.clear)
            .contentShape(Rectangle())
          }
          .buttonStyle(PlainButtonStyle())
        }

        Spacer()
      }
      .background(Color.surface)
      .navigationBarHidden(true)
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }
}

#Preview {
  ProfileView()
    .environmentObject(AuthenticationManager.shared)
}
