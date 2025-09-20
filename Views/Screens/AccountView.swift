import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // State variables for showing different screens
    @State private var showingDataPrivacy = false
    @State private var showingLoginView = false
    @State private var showingPersonalInformation = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Account",
                    description: isLoggedIn ? "Manage your account preferences" : "Sign in to access your account"
                ) {
                    dismiss()
                }
                
                Spacer().frame(height: 16)
                
                // Main content area
                if isLoggedIn {
                    // Account Options for authenticated users
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Personal Information Section
                                VStack(spacing: 0) {
                                    AccountOptionRow(
                                        icon: "Icon-Profile_Filled",
                                        title: "Personal Information",
                                        subtitle: "Manage your personal details",
                                        hasChevron: true,
                                        iconColor: .navy200
                                    ) {
                                        showingPersonalInformation = true
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 56)
                                    
                                    AccountOptionRow(
                                        icon: "Icon-Cloud_Filled",
                                        title: "Data Management",
                                        subtitle: "Manage your data and privacy settings",
                                        hasChevron: true,
                                        iconColor: .navy200
                                    ) {
                                        showingDataPrivacy = true
                                    }
                                }
                                .background(Color.surface)
                                .cornerRadius(16)
                                .padding(.horizontal, 20)
                                
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
                                }
                            )
                            
                            // Delete Account Button
                            HabittoButton(
                                size: .large,
                                style: .fillDestructive,
                                content: .text("Delete Account"),
                                action: {
                                    showingDeleteAccountConfirmation = true
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .background(Color.surface2)
                    }
                } else {
                    // Sign in prompt for unauthenticated users
                    ScrollView {
                        VStack(spacing: 24) {
                            // Sign in illustration
                            VStack(spacing: 16) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.primary)
                                
                                Text("Sign in to Your Account")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.text01)
                                
                                Text("Access your personalized settings, data management, and account preferences.")
                                    .font(.body)
                                    .foregroundColor(.text04)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 40)
                            
                            // Sign in button
                            HabittoButton(
                                size: .large,
                                style: .fillPrimary,
                                content: .text("Sign In"),
                                action: {
                                    showingLoginView = true
                                }
                            )
                            .padding(.horizontal, 20)
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .background(Color.surface2)
        }
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
        }
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
        .sheet(isPresented: $showingPersonalInformation) {
            PersonalInformationView()
        }
        .sheet(isPresented: $showingDeleteAccountConfirmation) {
            AccountDeletionConfirmationView()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Computed Properties
    private var isLoggedIn: Bool {
        switch authManager.authState {
        case .authenticated:
            return true
        case .unauthenticated, .error, .authenticating:
            return false
        }
    }
}

// MARK: - Account Option Row
struct AccountOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let hasChevron: Bool
    let iconColor: Color
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String, hasChevron: Bool, iconColor: Color = .navy200, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.hasChevron = hasChevron
        self.iconColor = iconColor
        self.action = action
    }
    
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
