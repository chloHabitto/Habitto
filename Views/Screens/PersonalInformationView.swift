import SwiftUI

struct PersonalInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Personal Information",
                        description: "Manage your personal details"
                    ) {
                        dismiss()
                    }
                    
                    // Profile Picture
                    VStack(spacing: 16) {
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
                    .padding(.top, 16)
                    
                    // Personal Information Options
                    VStack(spacing: 0) {
                        // Profile Settings
                        VStack(spacing: 0) {
                            AccountOptionRow(
                                icon: "Icon-Profile_Filled",
                                title: "Edit Profile",
                                subtitle: "Change your profile picture and name",
                                hasChevron: true
                            ) {
                                // TODO: Implement edit profile functionality
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Email_Filled",
                                title: "Change Email",
                                subtitle: "Update your email address",
                                hasChevron: true
                            ) {
                                // TODO: Implement change email functionality
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
}

#Preview {
    PersonalInformationView()
}
