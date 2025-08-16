import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "FAQ",
                    description: "Frequently asked questions about Habitto"
                ) {
                    dismiss()
                }
                
                // FAQ Content will go here
                VStack(alignment: .leading, spacing: 16) {
                    Text("FAQ content coming soon...")
                        .font(.appBodyLarge)
                        .foregroundColor(.text05)
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 24)
            }
        }
        .background(Color.surface2)
        .navigationBarHidden(true)
    }
}

#Preview {
    FAQView()
        .environmentObject(AuthenticationManager.shared)
}
