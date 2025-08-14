import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isEditingProfile = false
    @State private var showingSaveAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Picture
                        Image("Default-Profile@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        
                        // User Info
                        VStack(spacing: 8) {
                            if isEditingProfile {
                                // Editable Name Fields
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("First Name")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                                .textCase(.uppercase)
                                            
                                            TextField("First Name", text: $firstName)
                                                .font(.appHeadlineMediumEmphasised)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Last Name")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                                .textCase(.uppercase)
                                            
                                            TextField("Last Name", text: $lastName)
                                                .font(.appHeadlineMediumEmphasised)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                    }
                                    
                                    // Save/Cancel Buttons
                                    HStack(spacing: 12) {
                                        Button("Cancel") {
                                            isEditingProfile = false
                                            loadUserData()
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(8)
                                        
                                        Button("Save") {
                                            saveProfile()
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
                                // Display Name (Read-only)
                                if let user = authManager.currentUser {
                                    if let displayName = user.displayName, !displayName.isEmpty {
                                        Text(displayName)
                                            .font(.appHeadlineMediumEmphasised)
                                            .foregroundColor(.white)
                                    } else if let email = user.email {
                                        Text(email)
                                            .font(.appHeadlineMediumEmphasised)
                                            .foregroundColor(.white)
                                    }
                                    
                                    if let email = user.email {
                                        Text(email)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Profile Options
                    VStack(spacing: 16) {
                        // Edit Profile Button
                        Button(action: {
                            if isEditingProfile {
                                // Already editing, do nothing
                            } else {
                                loadUserData()
                                isEditingProfile = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Edit Profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Settings Button
                        Button(action: {
                            // TODO: Implement settings functionality
                        }) {
                            HStack {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Settings")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Help & Support Button
                        Button(action: {
                            // TODO: Implement help & support functionality
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Help & Support")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // About Button
                        Button(action: {
                            // TODO: Implement about functionality
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("About")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.surface)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
            .alert("Profile Updated", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text("Your profile has been successfully updated.")
            }
        }
    }
    
    // MARK: - Helper Functions
    private func loadUserData() {
        if let user = authManager.currentUser,
           let displayName = user.displayName, !displayName.isEmpty {
            let nameComponents = displayName.components(separatedBy: " ")
            firstName = nameComponents.first ?? ""
            lastName = nameComponents.dropFirst().joined(separator: " ")
        } else {
            firstName = ""
            lastName = ""
        }
    }
    
    private func saveProfile() {
        let newDisplayName = [firstName, lastName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        
        if !newDisplayName.isEmpty {
            authManager.updateUserProfile(displayName: newDisplayName, photoURL: nil) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        showingSaveAlert = true
                        isEditingProfile = false
                    case .failure(let error):
                        print("Failed to update profile: \(error.localizedDescription)")
                        // TODO: Show error alert
                    }
                }
            }
        } else {
            // Show error for empty names
            print("First name and last name cannot be empty")
            // TODO: Show error alert
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager.shared)
}
