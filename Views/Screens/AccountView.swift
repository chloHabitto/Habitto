import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // State variables for showing different screens
    @State private var showingPersonalInformation = false
    @State private var showingNotifications = false
    @State private var showingDataPrivacy = false
    @State private var showingLanguage = false
    @State private var showingDateCalendar = false
    @State private var showingTheme = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Settings",
                        description: "Manage your account preferences"
                    ) {
                        dismiss()
                    }
                    
                    // Account Options
                    VStack(spacing: 0) {
                        // Account Settings
                        VStack(spacing: 0) {
                            AccountOptionRow(
                                icon: "Icon-Profile_Filled",
                                title: "Personal Information",
                                subtitle: "Manage your personal details",
                                hasChevron: true
                            ) {
                                showingPersonalInformation = true
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Bell_Filled",
                                title: "Notifications",
                                subtitle: "Manage your notification preferences",
                                hasChevron: true
                            ) {
                                showingNotifications = true
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Cloud_Filled",
                                title: "Data & Privacy",
                                subtitle: "Manage your data and privacy settings",
                                hasChevron: true
                            ) {
                                showingDataPrivacy = true
                            }
                        }
                        .background(Color.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    // App Settings
                    VStack(spacing: 0) {
                        AccountOptionRow(
                            icon: "Icon-Language_Filled",
                            title: "Language",
                            subtitle: "Choose your preferred language",
                            hasChevron: true
                        ) {
                            showingLanguage = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Calendar_Filled",
                            title: "Date & Calendar",
                            subtitle: "Set your date and calendar preferences",
                            hasChevron: true
                        ) {
                            showingDateCalendar = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        AccountOptionRow(
                            icon: "Icon-Palette_Filled",
                            title: "Theme",
                            subtitle: "Choose your preferred app theme",
                            hasChevron: true
                        ) {
                            showingTheme = true
                        }
                    }
                    .background(Color.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(Color.surface2)
        }
        .sheet(isPresented: $showingPersonalInformation) {
            PersonalInformationView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
        }
        .sheet(isPresented: $showingLanguage) {
            LanguageView()
        }
        .sheet(isPresented: $showingDateCalendar) {
            DateCalendarView()
        }
        .sheet(isPresented: $showingTheme) {
            ThemeView()
        }
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
                if icon.hasPrefix("Icon-") {
                    // Custom icon
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(.navy200)
                } else {
                    // System icon
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.navy200)
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
