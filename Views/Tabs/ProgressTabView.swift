import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            VStack(spacing: 0) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .frame(alignment: .top)
            .roundedTopBackground()
            
            // Content area
            VStack(spacing: 20) {
                Text("Track your habit progress here")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .roundedTopBackground()
    }
} 