import SwiftUI
import StoreKit

struct MoreTabView: View {
    @ObservedObject var state: HomeViewState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var vacationManager: VacationManager
    @ObservedObject private var xpManager = XPManager.shared
    @State private var showingProfileView = false
    @State private var showingVacationModeSheet = false
    @State private var showingVacationSummary = false
    @State private var showingAboutUs = false
    @State private var showingFAQ = false
    @State private var showingContactUs = false
    @State private var showingSendFeedback = false
    @State private var showingCustomRating = false
    @State private var showingTermsConditions = false
    @State private var showingVacationMode = false
    @State private var showingSecurity = false
    @State private var showingDataPrivacy = false
    @State private var showingDateCalendar = false
    @State private var showingNotifications = false
    // @State private var showingPreferences = false // TODO: Uncomment when Preferences is needed
    @State private var showingLanguageView = false
    @State private var showingThemeView = false
    @State private var showingNotificationsView = false
    @State private var showingDataPrivacyView = false
    @State private var showingAccountView = false
    @State private var showingPreferencesView = false
    @State private var showingFAQView = false
    @State private var showingTermsConditionsView = false
    @State private var showingAboutUsView = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        WhiteSheetContainer(
            headerContent: {
                AnyView(
                    VStack(spacing: 0) {
                        // Trial Banner
                        trialBanner
                        
                        // XP Level Display
                        XPLevelDisplay(xpManager: xpManager)
                            .padding(.bottom, 16)
                    }
                )
            }
        ) {
            // Settings content in main content area
            ScrollView {
                VStack(spacing: 0) {
                    // Settings Sections
                    settingsSections
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingProfileView) {
            ProfileView()
        }
        .sheet(isPresented: $showingVacationModeSheet) {
            VacationModeSheet()
        }
        .sheet(isPresented: $showingVacationSummary) {
            VacationSummaryView()
        }
        .sheet(isPresented: $showingAboutUs) {
            AboutUsView()
        }
        .sheet(isPresented: $showingFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showingContactUs) {
            ContactUsView()
        }
        .sheet(isPresented: $showingSendFeedback) {
            SendFeedbackView()
        }
        .sheet(isPresented: $showingCustomRating) {
            CustomRatingView()
        }
        .sheet(isPresented: $showingTermsConditions) {
            TermsConditionsView()
        }
        .sheet(isPresented: $showingVacationMode) {
            VacationModeView()
        }
        .sheet(isPresented: $showingSecurity) {
            SecurityView()
        }
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
        }
        .sheet(isPresented: $showingDateCalendar) {
            DateCalendarView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        // TODO: Uncomment when Preferences is needed
        // .sheet(isPresented: $showingPreferences) {
        //     PreferencesView()
        // }
        .sheet(isPresented: $showingLanguageView) {
            LanguageView()
        }
        .sheet(isPresented: $showingThemeView) {
            ThemeView()
        }
        .sheet(isPresented: $showingNotificationsView) {
            NotificationsView()
        }
        .sheet(isPresented: $showingDataPrivacyView) {
            DataPrivacyView()
        }
        .sheet(isPresented: $showingAccountView) {
            AccountView()
        }
        .sheet(isPresented: $showingPreferencesView) {
            PreferencesView()
        }
        .sheet(isPresented: $showingFAQView) {
            FAQView()
        }
        .sheet(isPresented: $showingTermsConditionsView) {
            TermsConditionsView()
        }
        .sheet(isPresented: $showingAboutUsView) {
            AboutUsView()
        }
        .alert(isPresented: $showingSignOutAlert) {
            Alert(
                title: Text("Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    authManager.signOut()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Trial Banner
    private var trialBanner: some View {
        HStack {
            Text("Start your 7-day Free Trial!")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.text01)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.text01)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceDim)
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    

    
    // MARK: - Settings Sections
    private var settingsSections: some View {
        VStack(spacing: 0) {
            // General Settings Group
            settingsGroup(
                title: "General Settings",
                items: [
                    SettingItem(title: "Vacation Mode", value: vacationManager.isActive ? "On" : "Off", hasChevron: true, action: {
                        showingVacationMode = true
                    }),
                    SettingItem(title: "Account", value: nil, hasChevron: true, action: {
                        showingAccountView = true
                    }),
                    // SettingItem(title: "Data & Privacy", value: nil, hasChevron: true, action: {
                    //     showingDataPrivacy = true
                    // }),
                    SettingItem(title: "Date & Calendar", value: nil, hasChevron: true, action: {
                        showingDateCalendar = true
                    }),
                    SettingItem(title: "Notifications", value: nil, hasChevron: true, action: {
                        showingNotifications = true
                    })
                    // TODO: Uncomment when Preferences is needed
                    // SettingItem(title: "Preferences", value: nil, hasChevron: true, action: {
                    //     showingPreferences = true
                    // })
                ]
            )
            
            // Data Management Group
            settingsGroup(
                title: "Data Management",
                items: [
                    SettingItem(title: "Data & Privacy", value: nil, hasChevron: true, action: {
                        showingDataPrivacy = true
                    })
                ]
            )
            
            // Support/Legal Group
            settingsGroup(
                title: "Support & Legal",
                items: [
                    SettingItem(title: "About us", value: nil, hasChevron: true, action: {
                        showingAboutUs = true
                    }),
                    SettingItem(title: "Tutorial & Tips", value: nil, hasChevron: true, action: {
                        // Show tutorial directly instead of resetting it
                        tutorialManager.shouldShowTutorial = true
                    }),
                    SettingItem(title: "FAQ", value: nil, hasChevron: true, action: {
                        showingFAQ = true
                    }),
                    // SettingItem(title: "Contact us", value: nil, hasChevron: true, action: {
                    //     showingContactUs = true
                    // }) // Hidden for now, can be used in the future
                    SettingItem(title: "Send Feedback", value: nil, hasChevron: true, action: {
                        showingSendFeedback = true
                    }),
                    SettingItem(title: "Rate Us", value: nil, hasChevron: true, action: {
                        showingCustomRating = true
                    }),
                    SettingItem(title: "Terms & Conditions", value: nil, hasChevron: true, action: {
                        showingTermsConditions = true
                    })
                ]
            )
            
            
            // Version Information
            VStack(spacing: 0) {
                Spacer()
                
                Text("Habitto v1")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.text04)
                    .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Settings Group Helper
    private func settingsGroup(title: String, items: [SettingItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    // Icon based on item type
                    if iconForSetting(item.title).hasPrefix("Icon-") {
                        // Custom icon
                        Image(iconForSetting(item.title))
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(iconColorForSetting(item.title))
                    } else {
                        // System icon
                        Image(systemName: iconForSetting(item.title))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(iconColorForSetting(item.title))
                            .frame(width: 24, height: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(item.title == "Sign Out" ? .red600 : .text01)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if let value = item.value {
                            Text(value)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.text04)
                        }
                        
                        if item.hasChevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.text04)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                .onTapGesture {
                    if let action = item.action {
                        action()
                    }
                }
                
                if index < items.count - 1 {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 56)
                }
                
                // Add divider after the last item if it's the General Settings group
                // Special case: Add thin divider for Notifications row
                if index == items.count - 1 && title == "General Settings" && item.title == "Notifications" {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 56)
                }
                
                // Add divider after the last item if it's the Account & Notifications group
                if index == items.count - 1 && title == "Account & Notifications" {
                    Rectangle()
                        .fill(Color(hex: "F0F0F6"))
                        .frame(height: 8)
                }
                
                // Add divider after the last item if it's the Data Management group
                if index == items.count - 1 && title == "Data Management" {
                    Rectangle()
                        .fill(Color(hex: "F0F0F6"))
                        .frame(height: 8)
                }
            }
        }
    }
    
    // MARK: - Icon Helpers
    private func iconForSetting(_ title: String) -> String {
        switch title {
        case "Vacation Mode":
            return "Icon-Vacation_Filled"
        case "Account":
            return "Icon-Profile_Filled"
        case "Data & Privacy":
            return "Icon-Cloud_Filled"
        case "Date & Calendar":
            return "Icon-Calendar_Filled"
        case "Notifications":
            return "Icon-Bell_Filled"
        case "Preferences":
            return "Icon-Setting_Filled"
        case "FAQ":
            return "Icon-QuestionCircle_Filled"
        case "Contact us":
            return "Icon-Letter_Filled"
        case "Send Feedback":
            return "Icon-Letter_Filled"
        case "Rate Us":
            return "Icon-Hearts_Filled"
        case "Terms & Conditions":
            return "Icon-DocumentText_Filled"
        case "About us":
            return "Icon-ChatRoundLike_Filled"
        case "Tutorial & Tips":
            return "Icon-Notes_Filled"
        case "Time Block Test":
            return "clock.fill"
        default:
            return "heart"
        }
    }
    
    private func iconColorForSetting(_ title: String) -> Color {
        switch themeManager.selectedTheme {
        case .default:
            return Color("navy200")
        case .black:
            return Color("themeBlack200")
        case .purple:
            return Color("themePurple200")
        case .pink:
            return Color("themePink200")
        }
    }
    
    // MARK: - App Rating
    private func requestAppRating() {
        AppRatingManager.shared.requestRating()
    }
}

// MARK: - Setting Item Model
struct SettingItem {
    let title: String
    let value: String?
    let hasChevron: Bool
    let action: (() -> Void)?
    
    init(title: String, value: String? = nil, hasChevron: Bool = false, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.hasChevron = hasChevron
        self.action = action
    }
}

#Preview {
    MoreTabView(state: HomeViewState())
        .environmentObject(VacationManager.shared)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(TutorialManager())
} 
