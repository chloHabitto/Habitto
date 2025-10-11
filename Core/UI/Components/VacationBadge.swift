import SwiftUI

struct VacationBadge: View {
    @EnvironmentObject var vacationManager: VacationManager
    
    var body: some View {
        if vacationManager.isActive {
            VStack(spacing: 4) {
                Image("Icon-Vacation")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundColor(.navy200)
                
                Text("PAUSED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.navy200)
                    .tracking(0.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.navy200.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

#Preview {
    VacationBadge()
        .environmentObject(VacationManager.shared)
}
