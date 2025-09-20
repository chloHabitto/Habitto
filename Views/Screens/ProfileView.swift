import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var isEditingProfile: Bool = false
    @State private var originalFirstName: String = ""
    @State private var originalLastName: String = ""
    @State private var originalEmail: String = ""
    @State private var showingPhotoOptions = false
    @State private var showingSignIn = false
    
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
                                    Image("Default-Profile@4x")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primaryContainer, lineWidth: 3)
                                        )
                                    
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
                                                .stroke(Color.primaryContainer, lineWidth: 2)
                                        )
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
                            // First Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                
                                TextField("Enter first name", text: $firstName)
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text01)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.outline3, lineWidth: 1.5)
                                    )
                                    .cornerRadius(12)
                                    .disabled(!isLoggedIn)
                            }
                            
                            // Last Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.text01)
                                
                                TextField("Enter last name", text: $lastName)
                                    .font(.appBodyLarge)
                                    .foregroundColor(.text01)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.outline3, lineWidth: 1.5)
                                    )
                                    .cornerRadius(12)
                                    .disabled(!isLoggedIn)
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
                                hugging: false
                            ) {
                                saveChanges()
                            }
                            .disabled(!hasChanges || !isLoggedIn)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    
                    // Sign-in Overlay for Guest Users (on top of everything)
                    if !isLoggedIn {
                        // White background rectangle with gradient opacity - full screen
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.7),
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .ignoresSafeArea()
                            .overlay(
                                // Sign-in button centered
                                VStack {
                                    Spacer()
                                    
                                    HabittoButton.largeFillPrimary(
                                        text: "Please sign-in to edit your profile"
                                    ) {
                                        showingSignIn = true
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    Spacer()
                                }
                            )
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                loadUserData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .background(Color.surface2)
        .sheet(isPresented: $showingPhotoOptions) {
            PhotoOptionsBottomSheet(onClose: {
                showingPhotoOptions = false
            })
        }
        .sheet(isPresented: $showingSignIn) {
            LoginView()
        }
    }
    
    // MARK: - Helper Functions
    private var isLoggedIn: Bool {
        switch authManager.authState {
        case .authenticated:
            return true
        case .unauthenticated, .error, .authenticating:
            return false
        }
    }
    
    private var hasChanges: Bool {
        return firstName != originalFirstName || lastName != originalLastName
        // Email is no longer editable, so we don't check for email changes
    }
    
    private func loadUserData() {
        if let user = authManager.currentUser {
            // Load display name
            if let displayName = user.displayName,
               !displayName.isEmpty {
                // Split the display name into first and last name
                let nameComponents = displayName.components(separatedBy: " ")
                if nameComponents.count >= 2 {
                    firstName = nameComponents[0]
                    lastName = nameComponents[1...].joined(separator: " ")
                } else if nameComponents.count == 1 {
                    firstName = nameComponents[0]
                    lastName = ""
                }
            } else {
                firstName = ""
                lastName = ""
            }
            
            // Load email
            email = user.email ?? ""
        } else {
            // User not logged in
            firstName = ""
            lastName = ""
            email = ""
        }
        
        // Store original values for change detection
        originalFirstName = firstName
        originalLastName = lastName
        originalEmail = email
    }
    
    private func saveChanges() {
        // Update the user's display name in Firebase
        let newDisplayName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        
        // Update display name only (email is no longer editable)
        authManager.updateUserProfile(displayName: newDisplayName.isEmpty ? nil : newDisplayName, photoURL: nil) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Update original values to reflect saved state
                    self.originalFirstName = self.firstName
                    self.originalLastName = self.lastName
                    print("✅ Profile updated successfully")
                case .failure(let error):
                    print("❌ Failed to update profile: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Photo Options Bottom Sheet
struct PhotoOptionsBottomSheet: View {
    let onClose: () -> Void
    
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
                        // TODO: Implement avatar selection
                        onClose()
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 68)
                    
                    // Take Photo Option
                    Button(action: {
                        // TODO: Implement camera functionality
                        onClose()
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 68)
                    
                    // Choose from Library Option
                    Button(action: {
                        // TODO: Implement photo library selection
                        onClose()
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
