import SwiftUI



struct HeaderView: View {
    let onCreateHabit: () -> Void
    let onStreakTap: () -> Void
    let onNotificationTap: () -> Void
    let showProfile: Bool
    let currentStreak: Int
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var vacationManager: VacationManager
    @State private var showingLoginView = false
    @State private var showingProfileView = false
    
    var body: some View {
        HStack(spacing: 0) {
            if showProfile {
                // Profile section for More tab
                HStack(spacing: 12) {
                    // Profile picture
                    Image("Default-Profile@4x")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if isLoggedIn {
                            // User is logged in - show profile info
                            Text(greetingText)
                                .font(.appHeadlineMediumEmphasised)
                                .foregroundColor(.white)
                            
                            // View Profile button with chevron
                            Button(action: {
                                showingProfileView = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("View Profile")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            // User is not logged in - show login prompt
                            Text("Hi there,")
                                .font(.appHeadlineMediumEmphasised)
                                .foregroundColor(.white)
                            
                            // View Profile button with chevron (leads to profile)
                            Button(action: {
                                showingProfileView = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("View Profile")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            } else {
                // Streak pill
                Button(action: onStreakTap) {
                    HStack(spacing: 6) {
                        // Show frozen fire icon when vacation mode is active
                        if VacationManager.shared.isActive {
                            Image("Icon-fire-frozen")
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(.iconFire)
                                .resizable()
                                .frame(width: 32, height: 32)
                        }
                        Text(pluralizeStreak(currentStreak))
                            .font(.appButtonText1)
                            .foregroundColor(.black)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            if showProfile {
                // Only show Login button when user is not signed in
                if !isLoggedIn {
                    HabittoButton(
                        size: .small,
                        style: .fillNeutral,
                        content: .text("Login"),
                        hugging: true
                    ) {
                        showingLoginView = true
                    }
                }
            } else {
                // Add icon for other tabs
                Button(action: onCreateHabit) {
                    Image("Icon-AddCircle_Filled")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.onPrimary)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .sheet(isPresented: $showingLoginView) {
            LoginView()
        }
        .sheet(isPresented: $showingProfileView) {
            ProfileView()
        }
    }
    
    // MARK: - Computed Properties
    private var isLoggedIn: Bool {
        switch authManager.authState {
        case .authenticated:
            return true
        case .unauthenticated, .error:
            return false
        case .authenticating:
            return false
        }
    }
    
    private var greetingText: String {
        if isLoggedIn, let user = authManager.currentUser {
            if let displayName = user.displayName, !displayName.isEmpty {
                // Extract first name from display name
                let firstName = displayName.components(separatedBy: " ").first ?? displayName
                return "Hi \(firstName),"
            } else if let email = user.email, !email.isEmpty {
                // If no display name, use email prefix (capitalize first letter)
                let emailPrefix = email.components(separatedBy: "@").first ?? email
                let capitalizedPrefix = emailPrefix.prefix(1).uppercased() + emailPrefix.dropFirst().lowercased()
                return "Hi \(capitalizedPrefix),"
            }
        }
        // Default greeting for guest users
        return "Hi there,"
    }
    
    // MARK: - Helper Methods
    private func pluralizeStreak(_ streak: Int) -> String {
        if streak == 0 {
            return "0 day"
        } else if streak == 1 {
            return "1 day"
        } else {
            return "\(streak) days"
        }
    }
} 
