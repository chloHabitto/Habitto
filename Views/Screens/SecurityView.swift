import SwiftUI

struct SecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingDeleteAccountAlert = false
    
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
                        Button(action: {
                            showingDeleteAccountAlert = true
                        }) {
                            Text("Delete Account")
                                .font(.appButtonText1)
                                .foregroundColor(.onPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.red500)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                        }
                        .buttonStyle(PlainButtonStyle())
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
    }
}

#Preview {
    SecurityView()
}
