import SwiftUI

struct VacationModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vacationManager: VacationManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header with close button and left-aligned title
                ScreenHeader(
                    title: "Vacation Mode",
                    description: "Manage your vacation periods and settings"
                ) {
                    dismiss()
                }
                
                // Vacation Mode Content will go here
                VStack(alignment: .leading, spacing: 16) {
                    Text("Vacation mode management coming soon...")
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
    VacationModeView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(VacationManager.shared)
}
