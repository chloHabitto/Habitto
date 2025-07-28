import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack {
                Button("Back") {
                    dismiss()
                }
                .font(.appBodyLarge)
                .foregroundColor(.primary)
                
                Spacer()
                
                Text("Streak")
                    .font(.appHeadlineMediumEmphasised)
                    .foregroundColor(.text01)
                
                Spacer()
                
                // Invisible spacer to center the title
                Text("Back")
                    .font(.appBodyLarge)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Empty content
            VStack {
                Spacer()
                
                Text("Streak View")
                    .font(.appTitleMedium)
                    .foregroundColor(.text01)
                
                Text("This is an empty screen for the streak functionality.")
                    .font(.appBodyLarge)
                    .foregroundColor(.text04)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .background(.surface2)
    }
}

#Preview {
    StreakView()
} 