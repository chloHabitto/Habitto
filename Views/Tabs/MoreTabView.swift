import SwiftUI

struct MoreTabView: View {
    @ObservedObject var state: HomeViewState
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var vacationManager: VacationManager
    @State private var showingDateCalendarSettings = false
    @State private var showingSignOutAlert = false
    @State private var showingProfileView = false
    @State private var showingAccountView = false
    @State private var showingVacationModeSheet = false
    @State private var showingVacationSummary = false
    
    var body: some View {
        WhiteSheetContainer(
            headerContent: {
                AnyView(
                    VStack(spacing: 0) {
                        // Trial Banner
                        trialBanner
                    }
                )
            }
        ) {
            // Settings content in main content area
            ScrollView {
                VStack(spacing: 0) {
                    // Vacation Mode Section
                    vacationModeSection
                    
                    // Divider after vacation mode
                    Rectangle()
                        .fill(Color(hex: "F0F0F6"))
                        .frame(height: 8)
                    
                    // Settings Sections
                    settingsSections
                }
                .padding(.horizontal, 0)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: $showingDateCalendarSettings) {
            DateCalendarSettingsView()
        }
        .sheet(isPresented: $showingProfileView) {
            ProfileView()
        }
        .sheet(isPresented: $showingAccountView) {
            AccountView()
        }
        .sheet(isPresented: $showingVacationModeSheet) {
            VacationModeSheet()
        }
        .sheet(isPresented: $showingVacationSummary) {
            VacationSummaryView()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
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
    
        // MARK: - Vacation Mode Section
    private var vacationModeSection: some View {
        Button(action: {
            showingVacationModeSheet = true
        }) {
            HStack(spacing: 12) {
                // Vacation Icon
                Image(.iconVacation)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.navy200)
                
                // Title
                Text("Vacation Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                
                Spacer()
                
                // Status Text
                Text(vacationManager.isActive ? "On" : "Off")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text04)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.text04)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Settings Sections
    private var settingsSections: some View {
        VStack(spacing: 0) {
            // General Settings Group
            settingsGroup(
                title: "General Settings",
                items: [
                    SettingItem(title: "Account", value: nil, hasChevron: true),
                    SettingItem(title: "Language", value: "English", hasChevron: true),
                    SettingItem(title: "Theme", value: "Light", hasChevron: true),
                    SettingItem(title: "Date & Calendar", value: nil, hasChevron: true)
                ]
            )
            
            // Notifications Group
            settingsGroup(
                title: "Notifications",
                items: notificationsItems
            )
            
            // Support/Legal Group
            settingsGroup(
                title: "Support & Legal",
                items: [
                    SettingItem(title: "FAQ", value: nil, hasChevron: true),
                    SettingItem(title: "Contact us", value: nil, hasChevron: true),
                    SettingItem(title: "Send Feedback", value: nil, hasChevron: true),
                    SettingItem(title: "Terms & Conditions", value: nil, hasChevron: true)
                ]
            )
            
            // Tutorial Group
            settingsGroup(
                title: "Tutorial",
                items: [
                    SettingItem(title: "Show Tutorial Again", value: nil, hasChevron: false, action: {
                        tutorialManager.resetTutorial()
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
                    } else if item.title == "Account" {
                        showingAccountView = true
                    } else if item.title == "Date & Calendar" {
                        showingDateCalendarSettings = true
                    }
                }
                
                if index < items.count - 1 {
                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.leading, 56)
                }
                
                // Add divider after the last item if it's the General Settings group
                if index == items.count - 1 && title == "General Settings" {
                    Rectangle()
                        .fill(Color(hex: "F0F0F6"))
                        .frame(height: 8)
                }
                
                // Add divider after the last item if it's the Account & Notifications group
                if index == items.count - 1 && title == "Account & Notifications" {
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
        case "Language":
            return "Icon-Language_Filled"
        case "Theme":
            return "Icon-Theme_Filled"
        case "Date & Calendar":
            return "Icon-Calendar_Filled"
        case "Account":
            return "Icon-Profile_Filled"
        case "Notifications":
            return "Icon-Bell_Filled"
        case "Sync & Security":
            return "lock.shield"
        case "Sign Out":
            return "rectangle.portrait.and.arrow.right"
        case "FAQ":
            return "Icon-QuestionCircle_Filled"
        case "Contact us":
            return "Icon-Letter_Filled"
        case "Send Feedback":
            return "Icon-ChatRoundLike_Filled"
        case "Terms & Conditions":
            return "Icon-DocumentText_Filled"
        case "Show Tutorial Again":
            return "lightbulb"
        default:
            return "heart"
        }
    }
    
    private func iconColorForSetting(_ title: String) -> Color {
        switch title {
        case "Sign Out":
            return .red600
        case "Sync & Security":
            return .navy200
        case "Notifications":
            return .navy200
        case "Account":
            return .navy200
        case "Language":
            return .navy200
        case "Theme":
            return .navy200
        case "Date & Calendar":
            return .navy200
        case "FAQ":
            return .navy200
        case "Contact us":
            return .navy200
        case "Send Feedback":
            return .navy200
        case "Terms & Conditions":
            return .navy200
        default:
            return .navy200
        }
    }
    
    private var notificationsItems: [SettingItem] {
        var items: [SettingItem] = []
        
        items.append(SettingItem(title: "Notifications", hasChevron: true) {
            // TODO: Navigate to notification settings
        })
        
        return items
    }
    
    private var accountAndNotificationsItems: [SettingItem] {
        var items: [SettingItem] = []
        
        switch authManager.authState {
        case .authenticated:
            // User is logged in - show sign out option
            items.append(SettingItem(title: "Sign Out", hasChevron: false) {
                showingSignOutAlert = true
            })
        case .unauthenticated, .error, .authenticating:
            // User is not logged in - show login option
            items.append(SettingItem(title: "Login", hasChevron: true) {
                // TODO: Show login modal
            })
        }
        
        return items
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
} 
