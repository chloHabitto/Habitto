import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        WhiteSheetContainer(
            title: "Progress",
            subtitle: "Track your habit progress"
        ) {
            VStack(spacing: 20) {
                Text("Track your habit progress here")
                    .font(.appTitleMedium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
} 
