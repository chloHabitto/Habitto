//
//  GoalCompleteCelebration.swift
//  Habitto
//
//  Celebration card shown when daily goal is complete
//

import SwiftUI

struct GoalCompleteCelebration: View {
    let streak: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.system(size: 32))
            
            Text("progress.journey.dailyGoalComplete".localized)
                .font(.appTitleMediumEmphasised)
                .foregroundColor(.appText01)
            
            Text(String(format: "progress.journey.streakKeepItUp".localized, streak))
                .font(.appBodyMedium)
                .foregroundColor(.appText03)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.12), Color.green.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.top, 16)
    }
}

// MARK: - Preview

#Preview {
    GoalCompleteCelebration(streak: 12)
        .padding()
        .background(Color.appSurface01Variant02)
}
