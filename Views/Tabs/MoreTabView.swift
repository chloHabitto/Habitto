import SwiftUI

struct MoreTabView: View {
    var body: some View {
        WhiteSheetContainer(
            title: "More",
            subtitle: "Manage your app settings"
        ) {
            VStack(spacing: 20) {
                Text("Manage your app settings")
                    .font(.appTitleMedium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
} 
