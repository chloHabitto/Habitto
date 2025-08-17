import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button and left-aligned title
                    ScreenHeader(
                        title: "Data & Privacy",
                        description: "Manage your data and privacy settings"
                    ) {
                        dismiss()
                    }
                    
                    // Privacy Options
                    VStack(spacing: 0) {
                        // Data Collection
                        VStack(spacing: 0) {
                            AccountOptionRow(
                                icon: "Icon-Cloud_Filled",
                                title: "Data Collection",
                                subtitle: "Control what data we collect",
                                hasChevron: true
                            ) {
                                // TODO: Implement data collection settings
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Shield_Filled",
                                title: "Privacy Settings",
                                subtitle: "Manage your privacy preferences",
                                hasChevron: true
                            ) {
                                // TODO: Implement privacy settings
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Download_Filled",
                                title: "Export Data",
                                subtitle: "Download your personal data",
                                hasChevron: true
                            ) {
                                // TODO: Implement data export
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            AccountOptionRow(
                                icon: "Icon-Trash_Filled",
                                title: "Delete Data",
                                subtitle: "Permanently remove your data",
                                hasChevron: true
                            ) {
                                // TODO: Implement data deletion
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
    }
}

#Preview {
    DataPrivacyView()
}
