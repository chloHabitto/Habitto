import SwiftUI

struct SecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingDeleteAccountAlert = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Security",
                        description: "Manage your account security and authentication"
                    ) {
                        dismiss()
                    }
                    
                    // Security Options
                    VStack(spacing: 0) {
                        // Password Management
                        AccountOptionRow(
                            icon: "Icon-ShieldKeyhole_Filled",
                            title: "Change Password",
                            subtitle: "Update your account password",
                            hasChevron: true
                        ) {
                            // TODO: Implement change password functionality
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Two-Factor Authentication
                        AccountOptionRow(
                            icon: "Icon-ShieldCheck_Filled",
                            title: "Two-Factor Authentication",
                            subtitle: "Add an extra layer of security",
                            hasChevron: true
                        ) {
                            // TODO: Implement 2FA functionality
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Login Sessions
                        AccountOptionRow(
                            icon: "Icon-Devices_Filled",
                            title: "Active Sessions",
                            subtitle: "Manage your logged-in devices",
                            hasChevron: true
                        ) {
                            // TODO: Implement active sessions functionality
                        }
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Delete Account Section
                    VStack(spacing: 0) {
                        HabittoButton(
                            size: .large,
                            style: .fillTertiary,
                            content: .text("Delete Account"),
                            action: {
                                showingDeleteAccountAlert = true
                            }
                        )
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Sign Out Section
                    VStack(spacing: 0) {
                        HabittoButton(
                            size: .large,
                            style: .fillTertiary,
                            content: .text("Sign Out"),
                            action: {
                                showingSignOutAlert = true
                            }
                        )
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: Implement account deletion
                print("Account deletion requested")
            }
        } message: {
            Text("This action cannot be undone. All your data, habits, and progress will be permanently deleted.")
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
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
