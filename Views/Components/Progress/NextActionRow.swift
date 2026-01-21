//
//  NextActionRow.swift
//  Habitto
//
//  Action prompt row showing remaining progress needed and pulsing "Now" indicator
//

import SwiftUI

struct NextActionRow: View {
    let remainingCount: Int
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time Column
            VStack {
                Text("Now")
                    .font(.appLabelMedium)
                    .foregroundColor(.appText04)
            }
            .frame(width: 45)
            .padding(.top, 16)
            
            // Connector with pulsing dot
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                        .scaleEffect(isPulsing ? 1.8 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                }
                .frame(width: 24, height: 24)  // ✅ Explicit container size
                .clipped()  // ✅ Clips ALL content including the animation
                .padding(.top, 18)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
            .frame(width: 24)
            
            // Info Card
            HStack(alignment: .top, spacing: 12) {
                // Info icon
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.blue.opacity(0.15), radius: 4, y: 2)
                    )
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(remainingCount) more to reach your goal")
                        .font(.appLabelLargeEmphasised)
                        .foregroundColor(.appText01)
                    
                    Text("Complete this habit from Home")
                        .font(.appBodySmall)
                        .foregroundColor(.appText03)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText04)
                    .frame(width: 24, height: 24)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .padding(.top, 16)
        }
    }
}

// MARK: - Preview

#Preview {
    NextActionRow(remainingCount: 3)
        .padding()
        .background(Color.appSurface01Variant02)
}
