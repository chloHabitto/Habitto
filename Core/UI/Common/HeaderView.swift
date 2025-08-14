import SwiftUI

// MARK: - Helper Functions
private func pluralizeStreak(_ count: Int) -> String {
    if count == 0 {
        return "0 streak"
    } else if count == 1 {
        return "1 streak"
    } else {
        return "\(count) streaks"
    }
}

struct HeaderView: View {
    let onCreateHabit: () -> Void
    let onStreakTap: () -> Void
    let onNotificationTap: () -> Void
    let showProfile: Bool
    let currentStreak: Int
    
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingLoginView = false
    
    var body: some View {
        HStack(spacing: 0) {
            if showProfile {
                // Profile section for More tab
                HStack(spacing: 12) {
                    // Profile picture
                    Image("Default-Profile@4x")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if isLoggedIn {
                            // User is logged in - show profile info
                            Text("Hi there,")
                                .font(.appHeadlineMediumEmphasised)
                                .foregroundColor(.white)
                            
                            if let user = authManager.currentUser {
                                Text(user.displayName ?? user.email ?? "User")
                                    .font(.appButtonText1)
                                    .foregroundColor(.white)
                            }
                            
                            // View Profile button with chevron
                            Button(action: {
                                // TODO: Handle profile view action
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
                            
                            // View Profile button with chevron (leads to login)
                            Button(action: {
                                // TODO: Show login modal
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
                        Image(.iconFire)
                            .resizable()
                            .frame(width: 32, height: 32)
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
                // Login/Profile button for More tab
                HabittoButton(
                    size: .small,
                    style: isLoggedIn ? .fillPrimary : .fillNeutral,
                    content: .text(isLoggedIn ? "Profile" : "Login"),
                    hugging: true
                ) {
                    if isLoggedIn {
                        // Sign out
                        authManager.signOut()
                    } else {
                        showingLoginView = true
                    }
                }
            } else {
                // Notification and Add icons for other tabs
                HStack(spacing: 2) {
                    // Notification bell
                    Button(action: onNotificationTap) {
                        Image(.iconNotification)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    
                    // Add (+) button
                    Button(action: onCreateHabit) {
                        Image(.iconPlusCircle)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .sheet(isPresented: $showingLoginView) {
            LoginView()
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
    
    // MARK: - Helper Methods
    private func pluralizeStreak(_ streak: Int) -> String {
        if streak == 1 {
            return "\(streak) day"
        } else {
            return "\(streak) days"
        }
    }
} 
