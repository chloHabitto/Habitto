import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // State variables for showing different screens
    @State private var showingDataPrivacy = false
    
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
                                icon: "Icon-Cloud_Filled",
                                title: "Data Management",
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
                    
                    Spacer()
                }
            }
            .background(Color.surface2)
        }
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
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
