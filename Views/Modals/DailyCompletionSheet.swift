import SwiftUI

// MARK: - Daily Completion Sheet
struct DailyCompletionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var xpManager: XPManager
    let completedHabits: [Habit]
    let xpEarned: Int
    
    @State private var showXPAnimation = false
    @State private var showCelebration = false
    @State private var xpCount = 0
    @State private var showConfetti = false
    @State private var showLevelUp = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Celebration Header with Enhanced Animations
            VStack(spacing: 16) {
                // Fire Icon with Enhanced Animation
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                            .scaleEffect(showCelebration ? 1.3 : 1.0)
                            .opacity(showCelebration ? 0.3 : 0.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: showCelebration)
                    }
                    
                    // Main circle
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(showCelebration ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: showCelebration)
                    
                    // Fire icon
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                        .scaleEffect(showCelebration ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: showCelebration)
                }
                
                // Title with pulse animation
                Text("🎉 All Habits Completed!")
                    .font(.appTitleLargeEmphasised)
                    .foregroundColor(.text01)
                    .multilineTextAlignment(.center)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Subtitle
                Text("Great job completing all \(completedHabits.count) habits today!")
                    .font(.appBodyMedium)
                    .foregroundColor(.text02)
                    .multilineTextAlignment(.center)
                    .opacity(showCelebration ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.3), value: showCelebration)
            }
            
            // XP Earned Section with Enhanced Animations
            VStack(spacing: 12) {
                ZStack {
                    // Background glow
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showXPAnimation ? 1.3 : 1.0)
                        .opacity(showXPAnimation ? 0.6 : 0.0)
                        .animation(.easeInOut(duration: 0.8), value: showXPAnimation)
                    
                    // XP Text with bounce animation
                    Text("+\(xpCount) XP")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                        .scaleEffect(showXPAnimation ? 1.2 : 0.8)
                        .opacity(showXPAnimation ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showXPAnimation)
                }
                
                Text("Experience Points Earned")
                    .font(.appLabelMedium)
                    .foregroundColor(.text02)
                    .opacity(showXPAnimation ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.3), value: showXPAnimation)
                
                // Level up indicator
                if showLevelUp {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("Level Up!")
                            .font(.appTitleSmallEmphasised)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
                    .scaleEffect(showLevelUp ? 1.0 : 0.8)
                    .opacity(showLevelUp ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showLevelUp)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Level Progress (if close to level up)
            if xpManager.userProgress.isCloseToLevelUp {
                LevelUpPreview(
                    currentLevel: xpManager.userProgress.currentLevel,
                    nextLevel: xpManager.userProgress.currentLevel + 1,
                    progress: xpManager.userProgress.levelProgress
                )
            }
            
            // Recent Achievements (if any)
            if !xpManager.recentTransactions.isEmpty {
                RecentAchievementsView(transactions: Array(xpManager.recentTransactions.prefix(3)))
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }) {
                Text("Continue")
                    .font(.appLabelLargeEmphasised)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.primary)
                    .cornerRadius(25)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start celebration animation
        withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
            showCelebration = true
        }
        
        // Start pulse animation
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(1.0)) {
            pulseAnimation = true
        }
        
        // Animate XP counter
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            xpCount = xpEarned
            showXPAnimation = true
        }
        
        // Check for level up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if xpManager.userProgress.isCloseToLevelUp {
                showLevelUp = true
            }
        }
    }
}

// MARK: - Level Up Preview
struct LevelUpPreview: View {
    let currentLevel: Int
    let nextLevel: Int
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                Text("Almost Level \(nextLevel)!")
                    .font(.appLabelMediumEmphasised)
                    .foregroundColor(.text01)
            }
            
            // Progress Bar
            VStack(spacing: 4) {
                HStack {
                    Text("Level \(currentLevel)")
                        .font(.appLabelSmall)
                        .foregroundColor(.text02)
                    
                    Spacer()
                    
                    Text("Level \(nextLevel)")
                        .font(.appLabelSmall)
                        .foregroundColor(.text02)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                    .scaleEffect(y: 1.5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

// MARK: - Recent Achievements View
struct RecentAchievementsView: View {
    let transactions: [XPTransaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Rewards")
                .font(.appLabelMediumEmphasised)
                .foregroundColor(.text01)
            
            ForEach(transactions) { transaction in
                HStack(spacing: 12) {
                    Image(systemName: iconForReason(transaction.reason))
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.description)
                            .font(.appLabelSmall)
                            .foregroundColor(.text01)
                        
                        if let habitName = transaction.habitName {
                            Text(habitName)
                                .font(.appLabelSmall)
                                .foregroundColor(.text02)
                        }
                    }
                    
                    Spacer()
                    
                    Text("+\(transaction.amount) XP")
                        .font(.appLabelSmallEmphasised)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    private func iconForReason(_ reason: XPRewardReason) -> String {
        switch reason {
        case .completeAllHabits:
            return "flame.fill"
        case .completeHabit:
            return "checkmark.circle.fill"
        case .streakBonus:
            return "calendar.badge.clock"
        case .perfectWeek:
            return "star.fill"
        case .levelUp:
            return "arrow.up.circle.fill"
        case .achievement:
            return "trophy.fill"
        case .firstHabit:
            return "sparkles"
        case .comeback:
            return "arrow.clockwise.circle.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    let xpManager = XPManager()
    // Set up preview data
    var previewProgress = UserProgress()
    previewProgress.currentLevel = 3
    previewProgress.totalXP = 450
    previewProgress.xpForCurrentLevel = 150
    previewProgress.xpForNextLevel = 200
    previewProgress.dailyXP = 50
    xpManager.userProgress = previewProgress
    
    return DailyCompletionSheet(
        isPresented: .constant(true),
        xpManager: xpManager,
        completedHabits: [],
        xpEarned: 50
    )
    .background(Color.black.opacity(0.3))
}
