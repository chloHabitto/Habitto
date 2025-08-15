import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Account Header
                    VStack(spacing: 16) {
                        // Profile Picture
                        Image("Default-Profile@4x")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primaryContainer, lineWidth: 3)
                            )
                        
                        // User Info
                        VStack(spacing: 8) {
                            if let user = authManager.currentUser {
                                if let displayName = user.displayName, !displayName.isEmpty {
                                    Text(displayName)
                                        .font(.appHeadlineMediumEmphasised)
                                        .foregroundColor(.text01)
                                }
                                
                                if let email = user.email {
                                    Text(email)
                                        .font(.appBodyMedium)
                                        .foregroundColor(.text03)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Account Options
                    VStack(spacing: 0) {
                        // Account Settings
                        VStack(spacing: 0) {
                            AccountOptionRow(
                                icon: "person.circle",
                                title: "Personal Information",
                                subtitle: "Manage your personal details",
                                hasChevron: true
                            ) {
                                // TODO: Navigate to personal information
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "lock.shield",
                                title: "Security",
                                subtitle: "Password and authentication",
                                hasChevron: true
                            ) {
                                // TODO: Navigate to security settings
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "bell",
                                title: "Notifications",
                                subtitle: "Manage your notification preferences",
                                hasChevron: true
                            ) {
                                // TODO: Navigate to notification settings
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "icloud",
                                title: "Data & Privacy",
                                subtitle: "Manage your data and privacy settings",
                                hasChevron: true
                            ) {
                                // TODO: Navigate to data & privacy
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Account")
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
        }
        .background(Color.surface2)
    }
}

// MARK: - Account Option Row
struct AccountOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let hasChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appBodyLarge)
                        .foregroundColor(.text01)
                    
                    Text(subtitle)
                        .font(.appBodySmall)
                        .foregroundColor(.text03)
                }
                
                Spacer()
                
                if hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(.text03)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthenticationManager.shared)
}
