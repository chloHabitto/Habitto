import SwiftUI

struct TermsConditionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Terms & Conditions",
                    description: "Please read our terms of service carefully"
                ) {
                    dismiss()
                }
                
                // Terms Content will go here
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms and conditions content coming soon...")
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
    TermsConditionsView()
        .environmentObject(AuthenticationManager.shared)
}
