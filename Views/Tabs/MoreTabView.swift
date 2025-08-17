import SwiftUI

struct MoreTabView: View {
    @ObservedObject var state: HomeViewState
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var vacationManager: VacationManager
    @State private var showingProfileView = false
    @State private var showingAccountView = false
    @State private var showingVacationModeSheet = false
    @State private var showingVacationSummary = false
    @State private var showingAboutUs = false
    @State private var showingFAQ = false
    @State private var showingContactUs = false
    @State private var showingSendFeedback = false
    @State private var showingTermsConditions = false
    @State private var showingVacationMode = false
    
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
        .sheet(isPresented: $showingAccountView) {
            AccountView()
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
        .sheet(isPresented: $showingTermsConditions) {
            TermsConditionsView()
        }
        .sheet(isPresented: $showingVacationMode) {
            VacationModeView()
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
                    SettingItem(title: "Settings", value: nil, hasChevron: true, action: {
                        showingAccountView = true
                    }),
                    SettingItem(title: "Vacation Mode", value: vacationManager.isActive ? "On" : "Off", hasChevron: true, action: {
                        showingVacationMode = true
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
                        tutorialManager.resetTutorial()
                    }),
                    SettingItem(title: "FAQ", value: nil, hasChevron: true, action: {
                        showingFAQ = true
                    }),
                    SettingItem(title: "Contact us", value: nil, hasChevron: true, action: {
                        showingContactUs = true
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
        case "Vacation Mode":
            return "Icon-Vacation_Filled"
        case "Settings":
            return "Icon-Setting_Filled"
        case "FAQ":
            return "Icon-QuestionCircle_Filled"
        case "Contact us":
            return "Icon-Letter_Filled"
        case "Terms & Conditions":
            return "Icon-DocumentText_Filled"
        case "About us":
            return "Icon-ChatRoundLike_Filled"
        case "Tutorial & Tips":
            return "Icon-Notes_Filled"
        default:
            return "heart"
        }
    }
    
    private func iconColorForSetting(_ title: String) -> Color {
        switch title {
        case "Settings":
            return .navy200
        case "Vacation Mode":
            return .navy200
        case "FAQ":
            return .navy200
        case "Contact us":
            return .navy200
        case "Terms & Conditions":
            return .navy200
        case "About us":
            return .navy200
        default:
            return .navy200
        }
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
