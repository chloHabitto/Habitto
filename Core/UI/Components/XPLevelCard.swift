import SwiftUI

// MARK: - XP Level Card

struct XPLevelCard: View {
  // MARK: Internal

  // ✅ FIX: Direct singleton access as computed property - @Observable tracks reads automatically
  private var xpManager: XPManager { XPManager.shared }

  var body: some View {
    VStack(spacing: 16) {
      // Header with Level Badge
      HStack {
        // Level Badge with enhanced animation
        HStack(spacing: 8) {
          Image(systemName: "star.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.yellow)
            .scaleEffect(levelUpAnimation ? 1.3 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: levelUpAnimation)

          Text("Level \(xpManager.userProgress.currentLevel)")
            .font(.appTitleMediumEmphasised)
            .foregroundColor(.text01)
            .scaleEffect(levelUpAnimation ? 1.1 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: levelUpAnimation)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          Capsule()
            .fill(Color.yellow.opacity(levelUpAnimation ? 0.25 : 0.15))
            .animation(.easeInOut(duration: 0.3), value: levelUpAnimation))

        Spacer()

        // Total XP
        Text("\(xpManager.totalXP) XP")  // ✅ Read from @Published property
          .font(.appLabelMedium)
          .foregroundColor(.text02)
      }

      // XP Progress Section
      VStack(spacing: 8) {
        // Progress Bar
        VStack(spacing: 4) {
          HStack {
            let currentLevelStartXP =
              Int(pow(Double(xpManager.userProgress.currentLevel - 1), 2) *
                300) // Updated to 300 for challenging progression
            let nextLevelStartXP =
              Int(pow(Double(xpManager.userProgress.currentLevel), 2) *
                300) // Updated to 300 for challenging progression

            Text("\(currentLevelStartXP + xpManager.userProgress.xpForCurrentLevel) XP")
              .font(.appLabelSmall)
              .foregroundColor(.text02)

            Spacer()

            Text("\(nextLevelStartXP) XP")
              .font(.appLabelSmall)
              .foregroundColor(.text02)
          }

          ProgressView(value: xpManager.userProgress.levelProgress)
            .progressViewStyle(LinearProgressViewStyle(tint: .primary))
            .scaleEffect(y: 2)
            .animation(.easeInOut(duration: 0.3), value: xpManager.userProgress.levelProgress)
        }

        // Level Progress Text
        if xpManager.userProgress.isCloseToLevelUp {
          HStack(spacing: 4) {
            Image(systemName: "sparkles")
              .font(.system(size: 12))
              .foregroundColor(.yellow)

            Text("Almost level \(xpManager.userProgress.currentLevel + 1)!")
              .font(.appLabelSmall)
              .foregroundColor(.yellow)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(Color.yellow.opacity(0.1)))
        }
      }
    }
    .padding(16)
    .background(Color.white)
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    .scaleEffect(isAnimating ? 1.02 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isAnimating)
    .overlay(
      // XP Gain Animation Overlay
      Group {
        if showXPGain {
          VStack {
            Spacer()
            HStack {
              Spacer()
              Text("+\(xpGainAmount) XP")
                .font(.appTitleSmallEmphasised)
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                  Capsule()
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                      Capsule()
                        .stroke(Color.green, lineWidth: 1)))
                .scaleEffect(showXPGain ? 1.2 : 0.8)
                .opacity(showXPGain ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showXPGain)
              Spacer()
            }
            .padding(.bottom, 8)
          }
        }
      })
    .opacity(cardAppeared ? 1 : 0)
    .scaleEffect(cardAppeared ? 1 : 0.9)
    .offset(y: cardAppeared ? 0 : 15)
    .onAppear {
      // Entrance animation
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
        cardAppeared = true
      }

      withAnimation(.easeInOut(duration: 0.6).delay(0.1)) {
        isAnimating = true
      }
    }
    .onChange(of: xpManager.userProgress.currentLevel) { oldLevel, newLevel in
      // Animate on level up
      if newLevel > oldLevel {
        levelUpAnimation = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
          isAnimating = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          levelUpAnimation = false
          isAnimating = false
        }
      }
    }
    .onChange(of: xpManager.totalXP) { oldXP, newXP in  // ✅ Subscribe to @Published property
      // Show XP gain animation
      if newXP > oldXP {
        xpGainAmount = newXP - oldXP
        showXPGain = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          showXPGain = false
        }
      }
    }
  }

  // MARK: Private

  @State private var isAnimating = false
  @State private var showXPGain = false
  @State private var xpGainAmount = 0
  @State private var levelUpAnimation = false
  @State private var cardAppeared = false
}

// MARK: - XP Level Card Preview

#Preview {
  XPLevelCard()
    .padding()
    .background(Color.primary)
}
