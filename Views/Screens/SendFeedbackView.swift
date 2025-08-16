import SwiftUI

struct SendFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Send Feedback",
                    description: "Help us improve Habitto with your suggestions"
                ) {
                    dismiss()
                }
                
                // Feedback Content will go here
                VStack(alignment: .leading, spacing: 16) {
                    Text("Feedback form coming soon...")
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
    SendFeedbackView()
        .environmentObject(AuthenticationManager.shared)
}
