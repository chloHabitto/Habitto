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
        HStack(alignment: .top, spacing: 8) {
            // Time Column
            timeColumn
            
            // Spine Column
            spineColumn
            
            // Info Card
            infoCard
        }
    }
    
    // MARK: - Time Column
    
    private var timeColumn: some View {
        VStack {
            Text("Now")
                .font(.appLabelMedium)
                .foregroundColor(.appText04)
        }
        .frame(width: 45, alignment: .trailing)
        .padding(.top, 16)
    }
    
    // MARK: - Spine Column
    
    private var spineColumn: some View {
        VStack(spacing: 0) {
            // Line ABOVE - connects from previous entry
            Rectangle()
                .fill(Color.appPrimaryOpacity10)
                .frame(width: 3, height: 16)
            
            // Pulsing dot
            nowDot
        }
        .frame(width: 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var nowDot: some View {
        Circle()
            .fill(Color.appPrimary)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.appOutline03, lineWidth: 2)
            )
            .shadow(
                color: Color.appPrimary.opacity(isPulsing ? 0.5 : 0),
                radius: isPulsing ? 8 : 0
            )
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
    
    // MARK: - Info Card
            
    private var infoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            // Info icon
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appOutline02)
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
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.appOutline03, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .padding(.top, 16)
    }
}

// MARK: - Preview

#Preview {
    NextActionRow(remainingCount: 3)
        .padding()
        .background(Color.appSurface01Variant02)
}
