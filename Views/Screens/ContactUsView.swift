import SwiftUI

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Contact Us",
                    description: "Get in touch with our support team"
                ) {
                    dismiss()
                }
                
                // Contact Content will go here
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact information coming soon...")
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
    ContactUsView()
        .environmentObject(AuthenticationManager.shared)
}
