import SwiftUI

struct HeaderView: View {
    let onCreateHabit: () -> Void
    
    var body: some View {
        HStack {
            // Streak pill
            HStack(spacing: 6) {
                Image("Icon-fire")
                    .resizable()
                    .frame(width: 32, height: 32)
                Text("Habitto")
                    .font(.title2)
                    .foregroundColor(.text01)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .background(Color.white)
            .clipShape(Capsule())
            
            Spacer()
            
            HStack(spacing: 2) {
                // Notification bell
                Button(action: {}) {
                    Image("Icon-notification")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                
                // Add (+) button
                Button(action: onCreateHabit) {
                    Image("Icon-plusCircle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 28)
        .padding(.bottom, 28)
    }
} 
