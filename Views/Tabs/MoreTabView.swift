import SwiftUI

struct MoreTabView: View {
    @State private var isVacationModeEnabled = false
    
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
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Vacation Mode Section
    private var vacationModeSection: some View {
        HStack(spacing: 12) {
            // Vacation Icon
            Image("Icon-vacation")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.text01)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Vacation Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.text01)
                
                Text("Pause all habit schedules & reminders")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.text04)
            }
            
            Spacer()
            
            // Toggle Switch
            Toggle("", isOn: $isVacationModeEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Settings Sections
    private var settingsSections: some View {
        VStack(spacing: 0) {
            // General Settings Group
            settingsGroup(
                title: "General Settings",
                items: [
                    SettingItem(title: "Language", value: "English", hasChevron: true),
                    SettingItem(title: "Region", value: "Netherlands", hasChevron: true),
                    SettingItem(title: "Appearance", value: "Light", hasChevron: true)
                ]
            )
            
            // Account/Notifications Group
            settingsGroup(
                title: "Account & Notifications",
                items: [
                    SettingItem(title: "Account", value: nil, hasChevron: true),
                    SettingItem(title: "Notifications", value: nil, hasChevron: true)
                ]
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
            
            // Version Information
            VStack(spacing: 0) {
                Spacer()
                
                Text("Habitto v1")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.text04)
                    .padding(.bottom, 20)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Settings Group Helper
    private func settingsGroup(title: String, items: [SettingItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    // Heart Icon
                    Image(systemName: "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.text01)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.text01)
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
}

// MARK: - Setting Item Model
struct SettingItem {
    let title: String
    let value: String?
    let hasChevron: Bool
    
    init(title: String, value: String? = nil, hasChevron: Bool = false) {
        self.title = title
        self.value = value
        self.hasChevron = hasChevron
    }
}

#Preview {
    MoreTabView()
} 
